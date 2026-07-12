// Интейк «Фото автомобиля»: staged-файлы черновика + фоновая заливка в
// temp/-хранилище S3 (presigned PUT, 1-дневный lifecycle) под будущую
// ИИ-раскладку по группам осмотра.
//
// Синглтон уровня приложения (паттерн AiQueueOfflineRunner): состояние
// per-draft, персист в черновик через SparkJoyStorage.applyDraftPatch
// (атомарный патч против гонки с автосейвом), UI подписывается на
// ValueNotifier снапшота. Жизненный цикл:
//   hydrateFromDraft → stageFiles/removeFiles → startUpload → пайплайн
//   (сжатие фото → presigned URL → enqueue в транспорт) → апдейты
//   транспорта двигают статусы → uploaded(s3Key, uploadedAtIso).
//
// Файлы живут локально (file:// в Documents/spark_joy_media — как у медиа
// отчёта; на web data:-URL в черновике), в S3 уезжает КОПИЯ во временное
// хранилище. Протухание temp/ через сутки — забота будущего ИИ-шага
// (uploadedAtIso хранится именно для этого).

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_application_1/data/api/ai_queue_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart'
    show StorageApi, SessionExpiredException;
import 'package:flutter_application_1/data/services/ai_queue_cliche_builder.dart';
import 'package:flutter_application_1/data/services/spark_joy_intake_transfer.dart';
import 'package:flutter_application_1/data/services/spark_joy_intake_video_prep.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_doc_scan_ai.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_intake_ai.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_intake_photo_prep.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';

/// Статусы записи. Персистятся только терминальные и staged — промежуточные
/// (compressing/enqueued/uploading) при kill/перезапуске честно означают
/// «не долито», сериализуются как staged и дозаливаются автоматически.
abstract final class SparkIntakeFileStatus {
  static const String staged = 'staged';
  static const String compressing = 'compressing';
  static const String enqueued = 'enqueued';
  static const String uploading = 'uploading';
  static const String uploaded = 'uploaded';
  static const String failed = 'failed';
}

class SparkIntakeFileRecord {
  final String id;
  final String name;
  final String originalName;
  final String displayName;
  final String mimeType;

  /// file://-URI в Documents/spark_joy_media (native) или data:-URL (web).
  final String localPath;
  final int sizeBytes;
  String status;

  /// Случайное имя объекта в S3 (IDOR-гард: temp/ общий для всех юзеров,
  /// предсказуемое имя = перебор чужих файлов; урок скана СТС).
  String remoteName;

  /// Ключ объекта из GetTemporaryUploadUrl — понадобится ИИ-шагу.
  String s3Key;
  String uploadedAtIso;
  String? taskId;

  /// Путь сжатой JPEG-копии (только фото, только native). Лежит в
  /// spark_joy_media — попадание пути в JSON черновика защищает файл от
  /// SparkJoyStorage.gcOrphanedMedia.
  String? compressedPath;
  String? videoThumbPath;
  String? error;

  /// Internal JPEG child produced from a video. Child records participate in
  /// the normal S3 transfer but are hidden from UI and never enter the report.
  String sourceVideoId;
  int videoFrameIndex;
  int videoFrameTimeMs;

  /// Metadata of the original video, persisted for resume/debug/UX.
  int videoDurationMs;
  int videoFrameCount;

  /// sha256 ОРИГИНАЛЬНЫХ байт (hex) — ключ сопоставления вердикта ИИ с
  /// локальным оригиналом (в S3 уезжает сжатая копия) + дедуп вердиктов
  /// между одинаковыми фото.
  String sha256;

  /// Куда положить локальный оригинал: materials / inspection / unknown.
  /// Для materials [aiDocumentKind] отличает СТС/ПТС от прочих документов.
  String aiSection;
  String aiDocumentKind;
  String aiGroup;
  String aiElement;

  /// Для vehicle_doc: JSON шести полей СТС/ПТС (второй вызов — проверенный
  /// 6-польный скан); применяет экран через _applyDocScanResult.
  String aiDocJson;

  SparkIntakeFileRecord({
    required this.id,
    required this.name,
    String? originalName,
    String? displayName,
    required this.mimeType,
    required this.localPath,
    required this.sizeBytes,
    this.status = SparkIntakeFileStatus.staged,
    this.remoteName = '',
    this.s3Key = '',
    this.uploadedAtIso = '',
    this.taskId,
    this.compressedPath,
    this.videoThumbPath,
    this.error,
    this.sourceVideoId = '',
    this.videoFrameIndex = -1,
    this.videoFrameTimeMs = 0,
    this.videoDurationMs = 0,
    this.videoFrameCount = 0,
    this.sha256 = '',
    this.aiSection = '',
    this.aiDocumentKind = '',
    this.aiGroup = '',
    this.aiElement = '',
    this.aiDocJson = '',
  }) : originalName = originalName ?? name,
       displayName = displayName ?? name;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isDocument => !isImage && !isVideo;
  bool get isInternalVideoFrame => sourceVideoId.isNotEmpty;
  bool get isUploaded => status == SparkIntakeFileStatus.uploaded;
  bool get isFailed => status == SparkIntakeFileStatus.failed;
  bool get isTerminal => isUploaded || isFailed;

  /// Обычное фото или исходное видео ждёт вердикта ИИ. Скрытые кадры видео
  /// являются входом vision, но сами отдельного назначения не получают.
  bool get awaitsAiVerdict =>
      ((isImage && !isInternalVideoFrame) || isVideo) &&
      isUploaded &&
      aiSection.isEmpty;

  Map<String, dynamic> toJson() {
    final persistedStatus = switch (status) {
      SparkIntakeFileStatus.uploaded => SparkIntakeFileStatus.uploaded,
      SparkIntakeFileStatus.failed => SparkIntakeFileStatus.failed,
      _ => SparkIntakeFileStatus.staged,
    };
    return <String, dynamic>{
      'id': id,
      'name': name,
      'originalName': originalName,
      'displayName': displayName,
      'mimeType': mimeType,
      'localPath': localPath,
      'sizeBytes': sizeBytes,
      'status': persistedStatus,
      if (remoteName.isNotEmpty) 'remoteName': remoteName,
      if (s3Key.isNotEmpty) 's3Key': s3Key,
      if (uploadedAtIso.isNotEmpty) 'uploadedAtIso': uploadedAtIso,
      if (taskId != null) 'taskId': taskId,
      if (compressedPath != null) 'compressedPath': compressedPath,
      if (videoThumbPath != null) 'videoThumbPath': videoThumbPath,
      if (error != null) 'error': error,
      if (sourceVideoId.isNotEmpty) 'sourceVideoId': sourceVideoId,
      if (videoFrameIndex >= 0) 'videoFrameIndex': videoFrameIndex,
      if (videoFrameTimeMs > 0) 'videoFrameTimeMs': videoFrameTimeMs,
      if (videoDurationMs > 0) 'videoDurationMs': videoDurationMs,
      if (videoFrameCount > 0) 'videoFrameCount': videoFrameCount,
      if (sha256.isNotEmpty) 'sha256': sha256,
      if (aiSection.isNotEmpty) 'aiSection': aiSection,
      if (aiDocumentKind.isNotEmpty) 'aiDocumentKind': aiDocumentKind,
      if (aiGroup.isNotEmpty) 'aiGroup': aiGroup,
      if (aiElement.isNotEmpty) 'aiElement': aiElement,
      if (aiDocJson.isNotEmpty) 'aiDocJson': aiDocJson,
    };
  }

  static SparkIntakeFileRecord? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = raw.map((k, v) => MapEntry(k.toString(), v));
    final id = m['id']?.toString() ?? '';
    final localPath = m['localPath']?.toString() ?? '';
    if (id.isEmpty || localPath.isEmpty) return null;
    final rawStatus = m['status']?.toString() ?? SparkIntakeFileStatus.staged;
    final status = switch (rawStatus) {
      SparkIntakeFileStatus.uploaded => SparkIntakeFileStatus.uploaded,
      SparkIntakeFileStatus.failed => SparkIntakeFileStatus.failed,
      _ => SparkIntakeFileStatus.staged,
    };
    return SparkIntakeFileRecord(
      id: id,
      name: m['name']?.toString() ?? '',
      originalName:
          m['originalName']?.toString() ?? m['name']?.toString() ?? '',
      displayName: m['displayName']?.toString() ?? m['name']?.toString() ?? '',
      mimeType: m['mimeType']?.toString() ?? 'application/octet-stream',
      localPath: localPath,
      sizeBytes: m['sizeBytes'] is int
          ? m['sizeBytes'] as int
          : int.tryParse(m['sizeBytes']?.toString() ?? '') ?? 0,
      status: status,
      remoteName: m['remoteName']?.toString() ?? '',
      s3Key: m['s3Key']?.toString() ?? '',
      uploadedAtIso: m['uploadedAtIso']?.toString() ?? '',
      taskId: m['taskId']?.toString(),
      compressedPath: m['compressedPath']?.toString(),
      videoThumbPath: m['videoThumbPath']?.toString(),
      error: m['error']?.toString(),
      sourceVideoId: m['sourceVideoId']?.toString() ?? '',
      videoFrameIndex:
          int.tryParse(m['videoFrameIndex']?.toString() ?? '') ?? -1,
      videoFrameTimeMs:
          int.tryParse(m['videoFrameTimeMs']?.toString() ?? '') ?? 0,
      videoDurationMs:
          int.tryParse(m['videoDurationMs']?.toString() ?? '') ?? 0,
      videoFrameCount:
          int.tryParse(m['videoFrameCount']?.toString() ?? '') ?? 0,
      sha256: m['sha256']?.toString() ?? '',
      aiSection: _intakeSectionFromJson(m),
      aiDocumentKind: _intakeDocumentKindFromJson(m),
      aiGroup: m['aiGroup']?.toString() ?? '',
      aiElement: m['aiElement']?.toString() ?? '',
      aiDocJson: m['aiDocJson']?.toString() ?? '',
    );
  }
}

String _intakeSectionFromJson(Map<String, dynamic> map) {
  final direct = map['aiSection']?.toString() ?? '';
  if (direct.isNotEmpty) return direct;
  return switch (map['aiCategory']?.toString() ?? '') {
    'inspection' => SparkIntakeAiSection.inspection,
    'document' || 'vehicle_doc' => SparkIntakeAiSection.materials,
    'unknown' => SparkIntakeAiSection.unknown,
    _ => '',
  };
}

String _intakeDocumentKindFromJson(Map<String, dynamic> map) {
  final direct = map['aiDocumentKind']?.toString() ?? '';
  if (direct.isNotEmpty) return direct;
  return switch (map['aiCategory']?.toString() ?? '') {
    'vehicle_doc' => SparkIntakeDocumentKind.vehicleDoc,
    'document' => SparkIntakeDocumentKind.document,
    _ => '',
  };
}

/// Конфиг ИИ-раскладки: клише + допустимая таксономия для валидации
/// вердиктов. Строится экраном отчёта (реестры групп/элементов приватны
/// для его библиотеки) и передаётся сервису через [SparkJoyIntakeUploadService.configureAi].
class SparkIntakeAiConfig {
  final String cliche;
  final String videoCliche;

  /// groupKey → допустимые element id этой группы.
  final Map<String, Set<String>> elementsByGroup;

  const SparkIntakeAiConfig({
    required this.cliche,
    this.videoCliche = '',
    required this.elementsByGroup,
  });
}

enum SparkIntakePhase {
  /// Файлов нет.
  idle,

  /// Файлы добавлены, «Распределить файлы» ещё не нажимали.
  staged,

  /// Заливка запрошена и не вся завершена.
  uploading,

  /// Загрузка завершена, ИИ раскладывает изображения по разделам.
  classifying,

  /// Вердикты готовы, есть что применить к черновику — экран отчёта
  /// подхватывает и раскладывает автоматически.
  classified,

  /// Всё загружено и разложено; в интейке могли остаться только
  /// нераспознанные файлы/видео.
  done,

  /// Заливка запрошена, живых попыток нет, есть ошибки.
  failed,
}

/// Иммутабельный снапшот для UI. [files] — читаемое зеркало живого списка
/// (копия на момент эмита), записи в нём — те же мутабельные объекты, но UI
/// перерисовывается только по нотификациям, так что рассинхрона не видно.
class SparkIntakeSnapshot {
  final String draftId;
  final List<SparkIntakeFileRecord> files;
  final bool uploadRequested;
  final int uploadedCount;
  final int failedCount;
  final double progress;
  final SparkIntakePhase phase;

  /// Прогресс ИИ-классификации: изображений всего к раскладке / уже с
  /// вердиктом (для карточки «ИИ раскладывает · N из M»).
  final int aiTotal;
  final int aiClassified;

  const SparkIntakeSnapshot({
    required this.draftId,
    required this.files,
    required this.uploadRequested,
    required this.uploadedCount,
    required this.failedCount,
    required this.progress,
    required this.phase,
    this.aiTotal = 0,
    this.aiClassified = 0,
  });

  int get total => files.length;

  static SparkIntakeSnapshot empty(String draftId) => SparkIntakeSnapshot(
    draftId: draftId,
    files: const <SparkIntakeFileRecord>[],
    uploadRequested: false,
    uploadedCount: 0,
    failedCount: 0,
    progress: 0,
    phase: SparkIntakePhase.idle,
  );
}

class _IntakeDraftState {
  final String draftId;
  final List<SparkIntakeFileRecord> files = <SparkIntakeFileRecord>[];
  bool uploadRequested = false;
  bool pipelineRunning = false;
  bool classifyRunning = false;

  /// Конфиг ИИ-раскладки (клише + таксономия). In-memory: экран отчёта
  /// передаёт его при инициализации черновика; без него классификация
  /// не стартует.
  SparkIntakeAiConfig? aiConfig;

  /// Прогресс текущей заливки per-record (0..1), только in-memory.
  final Map<String, double> progressById = <String, double>{};

  /// Записи, которые бессмысленно ретраить автоматически (файл пропал).
  final Set<String> noAutoRetry = <String>{};

  /// Записи, уже получившие один бесплатный ре-enqueue по HTTP 403
  /// (протухший presigned URL) — вторые 403 уходят в общий retry-цикл.
  final Set<String> retriedForExpiredUrl = <String>{};

  /// Попытки ИИ-классификации per-record (in-memory): после
  /// [_kIntakeAiMaxAttempts] неудач запись честно уходит в unknown —
  /// платные вызовы не жжём бесконечно.
  final Map<String, int> aiAttemptsById = <String, int>{};

  late final ValueNotifier<SparkIntakeSnapshot> notifier =
      ValueNotifier<SparkIntakeSnapshot>(SparkIntakeSnapshot.empty(draftId));

  _IntakeDraftState(this.draftId);

  SparkIntakeFileRecord? recordById(String id) {
    for (final r in files) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Запись готова к применению к черновику (экран разложит и удалит её
  /// из интейка): документы — детерминированно в «Материалы проверки»,
  /// изображения и видео — по вердикту ИИ. Unknown остаётся в интейке.
  bool recordApplicable(SparkIntakeFileRecord r) {
    if (r.isInternalVideoFrame) return false;
    if (r.isDocument) return r.isUploaded;
    if (!r.isImage && !r.isVideo) return false;
    return switch (r.aiSection) {
      SparkIntakeAiSection.inspection => r.aiGroup.isNotEmpty,
      SparkIntakeAiSection.materials =>
        r.aiDocumentKind != SparkIntakeDocumentKind.vehicleDoc ||
            r.aiDocJson.isNotEmpty,
      _ => false,
    };
  }

  SparkIntakeSnapshot snapshot() {
    final visibleFiles = files
        .where((record) => !record.isInternalVideoFrame)
        .toList(growable: false);
    var uploaded = 0;
    var failed = 0;
    var weightTotal = 0.0;
    var weightDone = 0.0;
    var hasLive = false;
    for (final r in files) {
      // Original video is local-only. Its extracted child frames are the
      // actual upload work and therefore carry progress weight.
      if (r.isVideo && !r.isInternalVideoFrame) {
        if (r.status == SparkIntakeFileStatus.compressing) hasLive = true;
        continue;
      }
      final weight = math.max(r.sizeBytes, 1).toDouble();
      weightTotal += weight;
      switch (r.status) {
        case SparkIntakeFileStatus.uploaded:
          weightDone += weight;
        case SparkIntakeFileStatus.failed:
          break;
        case SparkIntakeFileStatus.uploading ||
            SparkIntakeFileStatus.enqueued ||
            SparkIntakeFileStatus.compressing:
          hasLive = true;
          weightDone += weight * (progressById[r.id] ?? 0).clamp(0.0, 1.0);
        default:
          if (uploadRequested) hasLive = true;
      }
    }
    for (final r in visibleFiles) {
      if (r.isVideo) {
        final frames = files
            .where((frame) => frame.sourceVideoId == r.id)
            .toList(growable: false);
        if (r.isFailed || frames.any((frame) => frame.isFailed)) {
          failed += 1;
        } else if (frames.isNotEmpty &&
            frames.every((frame) => frame.isUploaded)) {
          uploaded += 1;
        }
      } else if (r.isUploaded) {
        uploaded += 1;
      } else if (r.isFailed) {
        failed += 1;
      }
    }
    var aiTotal = 0;
    var aiClassified = 0;
    var aiPending = false;
    var hasApplicable = false;
    for (final r in visibleFiles) {
      if ((r.isImage || r.isVideo) &&
          (r.isUploaded || r.aiSection.isNotEmpty)) {
        aiTotal += 1;
        if (r.aiSection.isNotEmpty) {
          aiClassified += 1;
        } else if (r.isUploaded) {
          if (!r.isVideo || _videoFramesUploaded(r)) aiPending = true;
        }
        if (r.aiSection == SparkIntakeAiSection.materials &&
            r.aiDocumentKind == SparkIntakeDocumentKind.vehicleDoc &&
            r.aiDocJson.isEmpty) {
          aiPending = true;
        }
      }
      if (uploadRequested && recordApplicable(r)) hasApplicable = true;
    }
    final SparkIntakePhase phase;
    if (visibleFiles.isEmpty) {
      phase = SparkIntakePhase.idle;
    } else if (!uploadRequested) {
      phase = SparkIntakePhase.staged;
    } else if (hasLive) {
      phase = SparkIntakePhase.uploading;
    } else if (classifyRunning || aiPending) {
      phase = SparkIntakePhase.classifying;
    } else if (hasApplicable) {
      phase = SparkIntakePhase.classified;
    } else if (failed > 0) {
      phase = SparkIntakePhase.failed;
    } else {
      phase = SparkIntakePhase.done;
    }
    return SparkIntakeSnapshot(
      draftId: draftId,
      files: List<SparkIntakeFileRecord>.unmodifiable(visibleFiles),
      uploadRequested: uploadRequested,
      uploadedCount: uploaded,
      failedCount: failed,
      progress: weightTotal <= 0
          ? 0
          : (weightDone / weightTotal).clamp(0.0, 1.0),
      phase: phase,
      aiTotal: aiTotal,
      aiClassified: aiClassified,
    );
  }

  void emit() {
    notifier.value = snapshot();
  }

  bool _videoFramesUploaded(SparkIntakeFileRecord video) {
    final frames = files
        .where((frame) => frame.sourceVideoId == video.id)
        .toList(growable: false);
    return frames.isNotEmpty &&
        frames.length == video.videoFrameCount &&
        frames.every((frame) => frame.isUploaded);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'files': files.map((f) => f.toJson()).toList(),
    'uploadRequested': uploadRequested,
  };
}

class SparkJoyIntakeUploadService with WidgetsBindingObserver {
  SparkJoyIntakeUploadService._();

  static SparkJoyIntakeUploadService instance = SparkJoyIntakeUploadService._();

  @visibleForTesting
  static void resetSingletonForTest({SparkIntakeTransfer? transfer}) {
    instance._detachLifecycle();
    instance = SparkJoyIntakeUploadService._();
    instance._transferOverride = transfer;
    presignOverride = null;
    aiChatOverride = null;
    viewUrlOverride = null;
    videoFrameExtractorOverride = null;
  }

  /// Тестовый шов выпуска presigned URL (по умолчанию —
  /// StorageApi.getTemporaryUploadUrl с reportNumber: 'temp').
  @visibleForTesting
  static Future<({String url, String key})> Function(String filename)?
  presignOverride;

  /// Тестовый шов вызова ИИ (по умолчанию — AiQueue.ChatCompletions с
  /// одноразовым chatId + clearChatHistory). Возвращает сырой текст модели.
  @visibleForTesting
  static Future<String> Function({
    required String text,
    required String cliche,
    required List<String> fileUrls,
  })?
  aiChatOverride;

  /// Тестовый шов выпуска presigned GET (по умолчанию —
  /// StorageApi.getTemporaryViewUrl с reportNumber: 'temp').
  @visibleForTesting
  static Future<String> Function(String filename)? viewUrlOverride;

  /// Test seam for native video decoding.
  @visibleForTesting
  static Future<SparkIntakeVideoFrameSet> Function({
    required String videoPath,
    required String outputDirectory,
    required String filePrefix,
  })?
  videoFrameExtractorOverride;

  static const Duration _retryInterval = Duration(seconds: 60);

  /// Пачка изображений на один vision-вызов: меньше — надёжнее матчинг
  /// hash↔изображение, больше — дешевле (клише амортизируется).
  static const int _kIntakeAiBatchSize = 4;
  static const int _kIntakeAiMaxAttempts = 2;

  /// temp/-хранилище живёт сутки; старше порога — перезаливаем сжатую
  /// копию перед классификацией (локальный оригинал всегда на месте).
  static const Duration _kTempFreshness = Duration(hours: 20);

  final Map<String, _IntakeDraftState> _states = <String, _IntakeDraftState>{};
  SparkIntakeTransfer? _transferOverride;
  SparkIntakeTransfer? _transferInstance;
  StreamSubscription<SparkIntakeTransferUpdate>? _transferSub;
  Timer? _retryTimer;
  bool _lifecycleAttached = false;

  SparkIntakeTransfer get _transfer {
    final override = _transferOverride;
    if (override != null) return override;
    return _transferInstance ??= kIsWeb
        ? SparkIntakeTransferWeb()
        : SparkIntakeTransferIo();
  }

  // ── Публичное API ─────────────────────────────────────────────────────

  ValueListenable<SparkIntakeSnapshot> watch(String draftId) {
    return _stateFor(draftId).notifier;
  }

  SparkIntakeSnapshot snapshotOf(String draftId) {
    final state = _states[draftId];
    return state?.snapshot() ?? SparkIntakeSnapshot.empty(draftId);
  }

  /// Снапшот для _buildDraftPayload: upsertDraft заменяет весь map черновика,
  /// без этого ключа каждый автосейв стирал бы интейк.
  Map<String, dynamic> snapshotJsonForDraft(String draftId) {
    final state = _states[draftId];
    if (state == null) return const <String, dynamic>{'files': <Object>[]};
    return state.toJson();
  }

  /// Синхронный разбор из черновика (как у AiQueueOfflineRunner: до того,
  /// как UI успеет что-то нагородить для того же draftId). Сверка с БД задач
  /// транспорта и авто-дозаливка — асинхронный хвост.
  void hydrateFromDraft({
    required String draftId,
    required Map<String, dynamic>? rawPhotoIntake,
  }) {
    final state = _stateFor(draftId);
    state.files.clear();
    state.progressById.clear();
    state.noAutoRetry.clear();
    state.retriedForExpiredUrl.clear();
    state.aiAttemptsById.clear();
    state.uploadRequested = false;
    if (rawPhotoIntake != null) {
      final rawFiles = rawPhotoIntake['files'];
      if (rawFiles is List) {
        for (final raw in rawFiles) {
          final record = SparkIntakeFileRecord.tryFromJson(raw);
          if (record != null) state.files.add(record);
        }
      }
      state.uploadRequested = rawPhotoIntake['uploadRequested'] == true;
    }
    // Migration from the pre-video-AI pipeline: old drafts may mark the
    // original video itself as uploaded. New pipeline uploads only frames.
    for (final record in state.files) {
      if (!record.isVideo || record.aiSection.isNotEmpty) continue;
      final hasFrames = state.files.any(
        (frame) => frame.sourceVideoId == record.id,
      );
      if (!hasFrames && record.status == SparkIntakeFileStatus.uploaded) {
        record.status = SparkIntakeFileStatus.staged;
        record.remoteName = '';
        record.s3Key = '';
        record.uploadedAtIso = '';
        record.taskId = null;
      }
    }
    state.emit();
    if (state.files.isNotEmpty) {
      unawaited(_reconcileAndResume(state));
    }
  }

  /// Передаёт клише и таксономию ИИ-раскладки (экран отчёта строит их из
  /// своих реестров). Без конфига классификация не стартует; с появлением
  /// конфига — добираем накопившееся.
  void configureAi(String draftId, SparkIntakeAiConfig config) {
    final state = _stateFor(draftId);
    state.aiConfig = config;
    _maybeStartClassification(state);
  }

  /// Добавляет файлы в интейк и персистит. Файлы уже должны лежать в
  /// локальном хранилище (пикеры экрана копируют их сами).
  Future<void> stageFiles(
    String draftId,
    List<SparkIntakeFileRecord> records,
  ) async {
    if (records.isEmpty) return;
    final state = _stateFor(draftId);
    // Контракт начинается с hash оригинала. Считаем до постановки в очередь
    // и до любого сжатия; последовательно, чтобы несколько больших фото не
    // держались одновременно в памяти.
    for (final record in records) {
      if ((!record.isImage && !record.isVideo) || record.sha256.isNotEmpty) {
        continue;
      }
      if (record.isVideo && !kIsWeb) {
        final path = await _resolveNativePath(record.localPath);
        if (path == null) {
          record.status = SparkIntakeFileStatus.failed;
          record.error = 'Файл недоступен на устройстве';
          continue;
        }
        try {
          record.sha256 = await _sha256File(path);
        } catch (_) {
          record.status = SparkIntakeFileStatus.failed;
          record.error = 'Не удалось прочитать видео на устройстве';
        }
        continue;
      }
      final original = await _readLocalBytes(record.localPath);
      if (original == null || original.isEmpty) {
        record.status = SparkIntakeFileStatus.failed;
        record.error = 'Файл недоступен на устройстве';
        continue;
      }
      record.sha256 = kIsWeb
          ? sparkIntakeSha256Hex(original)
          : await compute(sparkIntakeSha256Hex, original);
    }
    state.files.addAll(records);
    state.emit();
    await _persist(state);
    // Если заливка уже была запрошена — новые файлы едут сразу же.
    if (state.uploadRequested) {
      unawaited(_runPipeline(state));
    }
  }

  Future<void> removeFiles(
    String draftId,
    Set<String> recordIds, {
    bool deleteLocalFiles = true,
  }) async {
    if (recordIds.isEmpty) return;
    final state = _stateFor(draftId);
    final expandedIds = <String>{...recordIds};
    for (final record in state.files) {
      if (recordIds.contains(record.sourceVideoId)) expandedIds.add(record.id);
    }
    final removed = state.files
        .where((record) => expandedIds.contains(record.id))
        .toList();
    if (removed.isEmpty) return;
    state.files.removeWhere((record) => expandedIds.contains(record.id));
    for (final record in removed) {
      state.progressById.remove(record.id);
      state.noAutoRetry.remove(record.id);
      state.retriedForExpiredUrl.remove(record.id);
      final taskId = record.taskId;
      if (taskId != null && !record.isTerminal) {
        unawaited(_transfer.cancel(taskId));
      }
      if (deleteLocalFiles) {
        unawaited(_deleteLocalArtifacts(record));
      }
    }
    state.emit();
    await _persist(state);
  }

  /// Подтверждает, что экран атомарно перенёс оригиналы в модель отчёта.
  /// Оригиналы не удаляем: теперь на них ссылаются media/legalFiles. Сжатые
  /// временные JPEG больше не нужны и удаляются best-effort.
  Future<void> acknowledgeApplied(String draftId, Set<String> recordIds) async {
    if (recordIds.isEmpty) return;
    final state = _states[draftId];
    if (state == null) return;
    final expandedIds = <String>{...recordIds};
    for (final record in state.files) {
      if (recordIds.contains(record.sourceVideoId)) expandedIds.add(record.id);
    }
    final applied = state.files
        .where((record) => expandedIds.contains(record.id))
        .toList(growable: false);
    state.files.removeWhere((record) => expandedIds.contains(record.id));
    for (final record in applied) {
      state.progressById.remove(record.id);
      state.noAutoRetry.remove(record.id);
      state.retriedForExpiredUrl.remove(record.id);
      unawaited(_deleteCompressedCopy(record));
    }
    state.emit();
    await _persist(state);
  }

  Future<void> updateVideoThumb(
    String draftId,
    String recordId,
    String thumbPath,
  ) async {
    final state = _states[draftId];
    final record = state?.recordById(recordId);
    if (state == null || record == null) return;
    record.videoThumbPath = thumbPath;
    state.emit();
    await _persist(state);
  }

  /// «Распределить файлы»: помечает заливку запрошенной (флаг персистится —
  /// после перезапуска дозаливка стартует сама из hydrateFromDraft) и
  /// запускает пайплайн.
  Future<void> startUpload(String draftId) async {
    final state = _stateFor(draftId);
    state.uploadRequested = true;
    // Ручной перезапуск = ещё один шанс и для файлов с ошибками.
    for (final record in state.files) {
      if (record.isFailed && !state.noAutoRetry.contains(record.id)) {
        record.status = SparkIntakeFileStatus.staged;
        record.error = null;
      }
    }
    state.emit();
    await _persist(state);
    unawaited(_runPipeline(state));
  }

  /// Чистит состояние черновика; [deleteLocalFiles] — вместе с локальными
  /// копиями (удаление черновика). S3-копии не трогаем — temp/ сам умрёт
  /// через сутки, метода удаления в API всё равно нет.
  Future<void> dropDraft(
    String draftId, {
    bool deleteLocalFiles = false,
  }) async {
    final state = _states.remove(draftId);
    if (state == null) return;
    for (final record in state.files) {
      final taskId = record.taskId;
      if (taskId != null && !record.isTerminal) {
        unawaited(_transfer.cancel(taskId));
      }
      if (deleteLocalFiles) {
        unawaited(_deleteLocalArtifacts(record));
      }
    }
    state.notifier.dispose();
    _maybeStopTimers();
  }

  /// Разлогин: гасим память и таймеры, файлы и черновики не трогаем —
  /// их судьбу решает общий wipe черновиков.
  Future<void> resetAll() async {
    for (final state in _states.values) {
      for (final record in state.files) {
        final taskId = record.taskId;
        if (taskId != null && !record.isTerminal) {
          unawaited(_transfer.cancel(taskId));
        }
      }
      state.notifier.dispose();
    }
    _states.clear();
    _maybeStopTimers();
  }

  // ── Пайплайн ──────────────────────────────────────────────────────────

  _IntakeDraftState _stateFor(String draftId) {
    _attachLifecycle();
    return _states.putIfAbsent(draftId, () => _IntakeDraftState(draftId));
  }

  bool _isPipelineCandidate(_IntakeDraftState state, SparkIntakeFileRecord r) {
    if (!state.uploadRequested) return false;
    if (state.noAutoRetry.contains(r.id)) return false;
    return r.status == SparkIntakeFileStatus.staged;
  }

  Future<void> _runPipeline(_IntakeDraftState state) async {
    if (state.pipelineRunning) return;
    state.pipelineRunning = true;
    try {
      await _transfer.ensureInitialized();
      _ensureTransferSubscription();
      while (true) {
        SparkIntakeFileRecord? record;
        for (final r in state.files) {
          if (_isPipelineCandidate(state, r)) {
            record = r;
            break;
          }
        }
        if (record == null) break;
        await _processRecord(state, record);
      }
    } on SessionExpiredException {
      // Сессия умерла — глобальный обработчик уведёт на логин; пайплайн
      // просто останавливается, staged-записи дозальются после перелогина.
    } catch (e) {
      _log('pipeline-error', draftId: state.draftId, extra: e.toString());
    } finally {
      state.pipelineRunning = false;
      state.emit();
      _scheduleRetryTimerIfNeeded();
      _maybeStartClassification(state);
    }
  }

  Future<void> _processRecord(
    _IntakeDraftState state,
    SparkIntakeFileRecord record,
  ) async {
    try {
      if (record.isVideo && !record.isInternalVideoFrame) {
        await _prepareVideoFrames(state, record);
        return;
      }
      Uint8List? webBytes;
      // 1. Сжатие фото (требование: «перед отправкой в S3 надо сжатие»).
      if (record.isImage && record.compressedPath == null) {
        record.status = SparkIntakeFileStatus.compressing;
        state.emit();
        final original = await _readLocalBytes(record.localPath);
        if (original == null || original.isEmpty) {
          _failNoRetry(state, record, 'Файл недоступен на устройстве');
          return;
        }
        // На web изолятов нет — жмём синхронно (короткая пауза под
        // спиннером приемлемее незжатого аплоада; решение как в доскане).
        final prepared = kIsWeb
            ? sparkPrepareIntakePhoto(original)
            : await compute(sparkPrepareIntakePhoto, original);
        if (kIsWeb) {
          webBytes = prepared;
        } else {
          final path = await _writeCompressedCopy(record, prepared);
          if (path == null) {
            _failNoRetry(
              state,
              record,
              'Не удалось сохранить сжатую копию изображения',
            );
            return;
          }
          record.compressedPath = path;
          await _persist(state);
        }
      } else if (kIsWeb) {
        webBytes = await _readLocalBytes(record.localPath);
        if (webBytes == null || webBytes.isEmpty) {
          _failNoRetry(state, record, 'Файл недоступен');
          return;
        }
      }

      // 2. Источник байтов проверяем ДО платного похода за presigned URL —
      // пропавший файл не должен жечь RPC (и его бессмысленно ретраить).
      String? filePath;
      if (!kIsWeb) {
        filePath = await _resolveNativePath(
          record.compressedPath ?? record.localPath,
        );
        if (filePath == null) {
          _failNoRetry(state, record, 'Файл недоступен на устройстве');
          return;
        }
      }

      // 3. Presigned URL — непосредственно перед enqueue (ссылки протухают).
      if (record.remoteName.isEmpty) {
        record.remoteName = sparkIntakeRemoteName(
          mimeType: record.mimeType,
          originalName: record.originalName,
          compressed:
              record.compressedPath != null || (kIsWeb && record.isImage),
        );
      }
      final presign = presignOverride;
      final presigned = presign != null
          ? await presign(record.remoteName)
          : await StorageApi.getTemporaryUploadUrl(
              reportNumber: 'temp',
              filename: record.remoteName,
            );
      record.s3Key = presigned.key;

      // 4. Enqueue в транспорт.
      final uploadMime =
          record.compressedPath != null || (kIsWeb && record.isImage)
          ? 'image/jpeg'
          : record.mimeType;
      final taskId = await _transfer.enqueue(
        SparkIntakeUploadPayload(
          draftId: state.draftId,
          recordId: record.id,
          url: presigned.url,
          mimeType: uploadMime,
          filePath: filePath,
          bytes: webBytes,
        ),
      );
      if (taskId == null) {
        _failNoRetry(state, record, 'Не удалось поставить файл в загрузку');
        return;
      }
      record.taskId = taskId;
      record.status = SparkIntakeFileStatus.enqueued;
      record.error = null;
      state.emit();
      await _persist(state);
    } on SessionExpiredException {
      record.status = SparkIntakeFileStatus.staged;
      rethrow;
    } catch (e) {
      // Транзиент (обычно сеть на шаге presigned URL): failed + retry-цикл.
      record.status = SparkIntakeFileStatus.failed;
      record.error = e.toString();
      state.emit();
      await _persist(state);
      _log(
        'record-failed',
        draftId: state.draftId,
        extra: 'id=${record.id} $e',
      );
    }
  }

  Future<void> _prepareVideoFrames(
    _IntakeDraftState state,
    SparkIntakeFileRecord record,
  ) async {
    if (kIsWeb) {
      _failNoRetry(
        state,
        record,
        'Распределение видео пока доступно только в мобильном приложении',
      );
      return;
    }
    final videoPath = await _resolveNativePath(record.localPath);
    if (videoPath == null) {
      _failNoRetry(state, record, 'Видео недоступно на устройстве');
      return;
    }
    record.status = SparkIntakeFileStatus.compressing;
    record.error = null;
    state.emit();

    final staleFrames = state.files
        .where((frame) => frame.sourceVideoId == record.id)
        .toList(growable: false);
    state.files.removeWhere((frame) => frame.sourceVideoId == record.id);
    for (final frame in staleFrames) {
      await _deleteLocalArtifacts(frame);
    }

    try {
      final extractor = videoFrameExtractorOverride;
      final outputDirectory = extractor != null
          ? File(videoPath).parent.path
          : '${(await getApplicationDocumentsDirectory()).path}/'
                '${SparkJoyStorage.mediaSubdirName}';
      final prefix =
          'intake_v_${record.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';
      final frameSet = extractor != null
          ? await extractor(
              videoPath: videoPath,
              outputDirectory: outputDirectory,
              filePrefix: prefix,
            )
          : await sparkExtractIntakeVideoFrames(
              videoPath: videoPath,
              outputDirectory: outputDirectory,
              filePrefix: prefix,
            );
      if (frameSet.frames.isEmpty) {
        throw const FormatException('Из видео не извлечено ни одного кадра');
      }
      final children = <SparkIntakeFileRecord>[];
      for (final frame in frameSet.frames) {
        final frameUri = Uri.file(frame.path).toString();
        children.add(
          SparkIntakeFileRecord(
            id: '${record.id}_frame_${frame.index}',
            name: '${record.displayName} · кадр ${frame.index + 1}',
            originalName: '${record.originalName} · кадр ${frame.index + 1}',
            displayName: '${record.displayName} · кадр ${frame.index + 1}',
            mimeType: 'image/jpeg',
            localPath: frameUri,
            sizeBytes: frame.sizeBytes,
            compressedPath: frameUri,
            sourceVideoId: record.id,
            videoFrameIndex: frame.index,
            videoFrameTimeMs: frame.timeMs,
          ),
        );
      }
      record.videoDurationMs = frameSet.durationMs;
      record.videoFrameCount = children.length;
      record.status = SparkIntakeFileStatus.uploaded;
      record.error = null;
      state.files.addAll(children);
      state.emit();
      await _persist(state);
    } on FormatException catch (e) {
      _failNoRetry(state, record, e.message);
    } catch (e) {
      record.status = SparkIntakeFileStatus.failed;
      record.error = 'Не удалось подготовить видео: $e';
      state.emit();
      await _persist(state);
    }
  }

  void _failNoRetry(
    _IntakeDraftState state,
    SparkIntakeFileRecord record,
    String message,
  ) {
    state.noAutoRetry.add(record.id);
    record.status = SparkIntakeFileStatus.failed;
    record.error = message;
    state.emit();
    unawaited(_persist(state));
  }

  // ── ИИ-классификация ──────────────────────────────────────────────────
  //
  // Стартует автоматически, когда заливка запрошена и все записи в
  // терминальном статусе. Пачками по [_kIntakeAiBatchSize] изображений:
  // текст запроса перечисляет hash каждого изображения (в порядке
  // приложения), модель возвращает {"items":[{hash, category, group,
  // element}]} — hash и есть ключ сопоставления вердикта с локальным
  // оригиналом (сжатая S3-копия оригинал не идентифицирует). Для СТС/ПТС
  // вторым вызовом гоняется проверенный 6-польный скан документа.

  bool _uploadsSettled(_IntakeDraftState state) {
    if (!state.uploadRequested) return false;
    for (final r in state.files) {
      if (!r.isTerminal) return false;
    }
    return true;
  }

  void _maybeStartClassification(_IntakeDraftState state) {
    if (state.aiConfig == null || !_uploadsSettled(state)) return;
    unawaited(_runClassification(state));
  }

  Future<void> _runClassification(_IntakeDraftState state) async {
    if (state.classifyRunning) return;
    final config = state.aiConfig;
    if (config == null || !_uploadsSettled(state)) return;
    state.classifyRunning = true;
    var consecutiveFailures = 0;
    try {
      // Протухшие temp-копии перезаливаем ДО классификации: вернёмся сюда
      // сами, когда аплоад-пайплайн доедет (триггер в _onTransferUpdate).
      var reuploadKicked = false;
      for (final r in state.files) {
        final videoParent = r.isInternalVideoFrame
            ? state.recordById(r.sourceVideoId)
            : null;
        final neededVideoFrame =
            videoParent != null && videoParent.awaitsAiVerdict;
        final standaloneUpload = r.awaitsAiVerdict && !r.isVideo;
        if ((standaloneUpload || neededVideoFrame) && _isTempExpired(r)) {
          r.status = SparkIntakeFileStatus.staged;
          r.remoteName = '';
          r.s3Key = '';
          r.uploadedAtIso = '';
          r.taskId = null;
          reuploadKicked = true;
        }
      }
      if (reuploadKicked) {
        state.emit();
        await _persist(state);
        unawaited(_runPipeline(state));
        return;
      }

      while (true) {
        SparkIntakeFileRecord? pendingVideo;
        var videoDirty = false;
        for (final r in state.files) {
          if (!r.isVideo || !r.awaitsAiVerdict) continue;
          if (!state._videoFramesUploaded(r)) continue;
          if ((state.aiAttemptsById[r.id] ?? 0) >= _kIntakeAiMaxAttempts) {
            r.aiSection = SparkIntakeAiSection.unknown;
            videoDirty = true;
            continue;
          }
          pendingVideo = r;
          break;
        }
        if (videoDirty) {
          state.emit();
          await _persist(state);
        }
        if (pendingVideo != null) {
          final video = pendingVideo;
          if (video.sha256.isEmpty) {
            video.sha256 = await _hashOriginalVideo(video) ?? '';
          }
          SparkIntakeFileRecord? donor;
          if (video.sha256.isNotEmpty) {
            for (final candidate in state.files) {
              if (candidate.id == video.id || candidate.aiSection.isEmpty) {
                continue;
              }
              if (candidate.sha256 == video.sha256) {
                donor = candidate;
                break;
              }
            }
          }
          if (donor != null) {
            video.aiSection = donor.aiSection;
            video.aiDocumentKind = donor.aiDocumentKind;
            video.aiGroup = donor.aiGroup;
            video.aiElement = donor.aiElement;
            video.aiDocJson = donor.aiDocJson;
          } else if (video.sha256.isEmpty) {
            video.aiSection = SparkIntakeAiSection.unknown;
          } else {
            try {
              await _classifyVideo(state, config, video);
              consecutiveFailures = 0;
            } on SessionExpiredException {
              rethrow;
            } catch (e) {
              state.aiAttemptsById[video.id] =
                  (state.aiAttemptsById[video.id] ?? 0) + 1;
              consecutiveFailures += 1;
              _log(
                'classify-video-failed',
                draftId: state.draftId,
                extra: 'id=${video.id} $e',
              );
              await Future<void>.delayed(
                Duration(seconds: math.min(5 * consecutiveFailures, 15)),
              );
            }
          }
          state.emit();
          await _persist(state);
          continue;
        }

        final batch = <SparkIntakeFileRecord>[];
        var dirty = false;
        for (final r in state.files) {
          if (!r.awaitsAiVerdict || r.isVideo) continue;
          if ((state.aiAttemptsById[r.id] ?? 0) >= _kIntakeAiMaxAttempts) {
            // Платные вызовы не жжём бесконечно — честный unknown,
            // файл остаётся в интейке.
            r.aiSection = SparkIntakeAiSection.unknown;
            dirty = true;
            continue;
          }
          batch.add(r);
          if (batch.length == _kIntakeAiBatchSize) break;
        }
        if (dirty) {
          state.emit();
          await _persist(state);
        }
        if (batch.isEmpty) break;

        // Hash оригинала — лениво (старые записи без него) + дедуп: то же
        // фото, добавленное дважды, второй раз не оплачивается.
        for (final r in batch) {
          if (r.sha256.isEmpty) {
            final bytes = await _readLocalBytes(r.localPath);
            if (bytes != null && bytes.isNotEmpty) {
              r.sha256 = kIsWeb
                  ? sparkIntakeSha256Hex(bytes)
                  : await compute(sparkIntakeSha256Hex, bytes);
            }
          }
        }
        var deduped = false;
        for (final r in [...batch]) {
          if (r.sha256.isEmpty) {
            // Оригинал пропал — классифицировать нечего.
            r.aiSection = SparkIntakeAiSection.unknown;
            batch.remove(r);
            deduped = true;
            continue;
          }
          for (final donor in state.files) {
            if (donor.id == r.id || donor.aiSection.isEmpty) continue;
            if (donor.sha256 != r.sha256) continue;
            r.aiSection = donor.aiSection;
            r.aiDocumentKind = donor.aiDocumentKind;
            r.aiGroup = donor.aiGroup;
            r.aiElement = donor.aiElement;
            r.aiDocJson = donor.aiDocJson;
            batch.remove(r);
            deduped = true;
            break;
          }
        }
        if (deduped) {
          state.emit();
          await _persist(state);
        }
        if (batch.isEmpty) continue;

        try {
          await _classifyBatch(state, config, batch);
          consecutiveFailures = 0;
        } on SessionExpiredException {
          rethrow;
        } catch (e) {
          for (final r in batch) {
            state.aiAttemptsById[r.id] = (state.aiAttemptsById[r.id] ?? 0) + 1;
          }
          consecutiveFailures += 1;
          _log(
            'classify-batch-failed',
            draftId: state.draftId,
            extra: e.toString(),
          );
          // Короткий backoff, чтобы транзиент не сжёг обе попытки залпом.
          await Future<void>.delayed(
            Duration(seconds: math.min(5 * consecutiveFailures, 15)),
          );
        }
        state.emit();
        await _persist(state);
      }

      await _runDocScans(state, config);
    } on SessionExpiredException {
      // Сессия умерла — глобальный обработчик уведёт на логин.
    } catch (e) {
      _log('classify-error', draftId: state.draftId, extra: e.toString());
    } finally {
      state.classifyRunning = false;
      state.emit();
    }
  }

  Future<void> _classifyBatch(
    _IntakeDraftState state,
    SparkIntakeAiConfig config,
    List<SparkIntakeFileRecord> batch,
  ) async {
    final urls = <String>[];
    final lines = <String>[];
    for (var i = 0; i < batch.length; i++) {
      final url = await _viewUrlFor(batch[i].remoteName);
      if (url.isEmpty) {
        throw Exception('Не удалось получить ссылку на ${batch[i].remoteName}');
      }
      urls.add(url);
      lines.add('изображение ${i + 1}: hash=${batch[i].sha256}');
    }
    final text = 'Классифицируй приложенные изображения.\n${lines.join('\n')}';
    final raw = await _aiCall(
      text: text,
      cliche: config.cliche,
      fileUrls: urls,
    );
    final verdicts = parseIntakeDistributionResult(raw);
    final byHash = <String, SparkIntakeAiVerdict>{
      for (final v in verdicts) v.hash: v,
    };
    for (final r in batch) {
      final verdict = byHash[r.sha256.toLowerCase()];
      if (verdict == null) {
        // Модель потеряла/исказила hash — считаем попыткой этой записи.
        state.aiAttemptsById[r.id] = (state.aiAttemptsById[r.id] ?? 0) + 1;
        continue;
      }
      _assignVerdict(config, r, verdict);
    }
  }

  Future<void> _classifyVideo(
    _IntakeDraftState state,
    SparkIntakeAiConfig config,
    SparkIntakeFileRecord video,
  ) async {
    final frames =
        state.files
            .where(
              (record) => record.sourceVideoId == video.id && record.isUploaded,
            )
            .toList(growable: false)
          ..sort((a, b) => a.videoFrameIndex.compareTo(b.videoFrameIndex));
    if (frames.isEmpty || frames.length != video.videoFrameCount) {
      throw StateError('Не все кадры видео загружены');
    }
    final urls = <String>[];
    final lines = <String>[
      'hash исходного видео=${video.sha256}',
      'длительность=${video.videoDurationMs} мс',
    ];
    for (final frame in frames) {
      final url = await _viewUrlFor(frame.remoteName);
      if (url.isEmpty) {
        throw Exception('Не удалось получить ссылку на ${frame.remoteName}');
      }
      urls.add(url);
      lines.add(
        'кадр ${frame.videoFrameIndex + 1}: '
        'timeMs=${frame.videoFrameTimeMs}',
      );
    }
    final raw = await _aiCall(
      text:
          'Классифицируй исходное видео по приложенным кадрам.\n'
          '${lines.join('\n')}',
      cliche: config.videoCliche.isEmpty ? config.cliche : config.videoCliche,
      fileUrls: urls,
    );
    final verdicts = parseIntakeDistributionResult(raw);
    SparkIntakeAiVerdict? verdict;
    for (final candidate in verdicts) {
      if (candidate.hash == video.sha256.toLowerCase()) {
        verdict = candidate;
        break;
      }
    }
    if (verdict == null) {
      throw const FormatException('ИИ не вернул hash исходного видео');
    }
    _assignVerdict(config, video, verdict);
  }

  void _assignVerdict(
    SparkIntakeAiConfig config,
    SparkIntakeFileRecord record,
    SparkIntakeAiVerdict verdict,
  ) {
    var section = verdict.section;
    var documentKind = verdict.documentKind;
    var group = verdict.group;
    var element = verdict.element;
    if (section == SparkIntakeAiSection.inspection) {
      // Строгая валидация по таксономии: выдуманная группа = unknown,
      // выдуманный элемент = группа без элемента.
      final allowed = config.elementsByGroup[group];
      if (allowed == null) {
        section = SparkIntakeAiSection.unknown;
        documentKind = '';
        group = '';
        element = '';
      } else if (element.isNotEmpty && !allowed.contains(element)) {
        element = '';
      }
    }
    record.aiSection = section;
    record.aiDocumentKind = documentKind;
    record.aiGroup = group;
    record.aiElement = element;
  }

  /// Для СТС/ПТС — второй вызов: проверенный 6-польный скан документа
  /// (клише и парсер те же, что у ручного скана). Результат кладётся в
  /// aiDocJson; применяет его экран (_applyDocScanResult, only-empty).
  Future<void> _runDocScans(
    _IntakeDraftState state,
    SparkIntakeAiConfig config,
  ) async {
    // Снимок защищает итерацию от будущих изменений списка после завершения
    // классификации и применения результатов экраном.
    for (final r in List<SparkIntakeFileRecord>.of(state.files)) {
      if (r.aiSection != SparkIntakeAiSection.materials ||
          r.aiDocumentKind != SparkIntakeDocumentKind.vehicleDoc) {
        continue;
      }
      if (r.aiDocJson.isNotEmpty) continue;
      final attemptKey = 'doc:${r.id}';
      while (r.aiDocJson.isEmpty &&
          (state.aiAttemptsById[attemptKey] ?? 0) < _kIntakeAiMaxAttempts) {
        try {
          var sourceRemoteName = r.remoteName;
          if (r.isVideo) {
            final frames =
                state.files
                    .where(
                      (frame) =>
                          frame.sourceVideoId == r.id && frame.isUploaded,
                    )
                    .toList(growable: false)
                  ..sort(
                    (a, b) => a.videoFrameIndex.compareTo(b.videoFrameIndex),
                  );
            if (frames.isNotEmpty) {
              sourceRemoteName = frames[frames.length ~/ 2].remoteName;
            }
          }
          final url = await _viewUrlFor(sourceRemoteName);
          if (url.isEmpty) {
            throw Exception('Не удалось получить ссылку на $sourceRemoteName');
          }
          final raw = await _aiCall(
            text: 'Распознай документ на фото.',
            cliche: AiQueueClicheBuilder.buildDocScanCliche(),
            fileUrls: [url],
          );
          final result = parseDocScanAiResult(raw);
          r.aiDocJson = hasAnyDocScanData(result)
              ? jsonEncode(<String, String>{
                  'docType': result.docType,
                  'vin': result.vin,
                  'gosNumber': result.gosNumber,
                  'brand': result.brand,
                  'model': result.model,
                  'year': result.year,
                  'color': result.color,
                })
              : '{}';
        } on SessionExpiredException {
          rethrow;
        } catch (e) {
          final attempts = (state.aiAttemptsById[attemptKey] ?? 0) + 1;
          state.aiAttemptsById[attemptKey] = attempts;
          _log('doc-scan-failed', draftId: state.draftId, extra: e.toString());
          if (attempts < _kIntakeAiMaxAttempts) {
            await Future<void>.delayed(Duration(seconds: attempts * 5));
          }
        }
      }
      // Даже без считанных полей оригинал документа должен попасть в
      // «Материалы проверки»; '{}' — терминальный маркер only-no-data.
      if (r.aiDocJson.isEmpty) r.aiDocJson = '{}';
      state.emit();
      await _persist(state);
    }
  }

  Future<String> _aiCall({
    required String text,
    required String cliche,
    required List<String> fileUrls,
  }) async {
    final override = aiChatOverride;
    if (override != null) {
      return override(text: text, cliche: cliche, fileUrls: fileUrls);
    }
    // Одноразовый chatId + чистка истории: на фото могут быть ПДн
    // (документы), нечего им лежать в серверной истории чата.
    final chatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
    try {
      final result = await AiQueueApi.chatCompletions(
        chatId: chatId,
        text: text,
        cliche: cliche,
        fileUrls: fileUrls,
        // Vision-пачка из 4 фото думает дольше одиночного скана (75с).
        timeout: const Duration(seconds: 150),
      );
      return result.text;
    } finally {
      unawaited(AiQueueApi.clearChatHistory(chatId: chatId).catchError((_) {}));
    }
  }

  Future<String> _viewUrlFor(String remoteName) {
    if (remoteName.isEmpty) return Future.value('');
    final override = viewUrlOverride;
    if (override != null) return override(remoteName);
    return StorageApi.getTemporaryViewUrl(
      reportNumber: 'temp',
      filename: remoteName,
      expiresInSeconds: 600,
      timeout: const Duration(seconds: 30),
    );
  }

  bool _isTempExpired(SparkIntakeFileRecord record) {
    if (!record.isUploaded) return false;
    final uploadedAt = DateTime.tryParse(record.uploadedAtIso);
    if (uploadedAt == null) return true;
    return DateTime.now().difference(uploadedAt) > _kTempFreshness;
  }

  // ── Апдейты транспорта ────────────────────────────────────────────────

  void _ensureTransferSubscription() {
    _transferSub ??= _transfer.updates.listen(_onTransferUpdate);
  }

  void _onTransferUpdate(SparkIntakeTransferUpdate update) {
    final state = _states[update.draftId];
    final record = state?.recordById(update.recordId);
    if (state == null || record == null) return;
    switch (update.kind) {
      case SparkIntakeTransferUpdateKind.progress:
        state.progressById[record.id] = update.progress;
        if (record.status == SparkIntakeFileStatus.enqueued) {
          record.status = SparkIntakeFileStatus.uploading;
        }
        state.emit();
      case SparkIntakeTransferUpdateKind.complete:
        record.status = SparkIntakeFileStatus.uploaded;
        record.uploadedAtIso = DateTime.now().toIso8601String();
        record.error = null;
        state.progressById[record.id] = 1.0;
        state.emit();
        unawaited(_persist(state));
      case SparkIntakeTransferUpdateKind.failed:
        if (update.httpStatusCode == 403 &&
            !state.retriedForExpiredUrl.contains(record.id)) {
          // Протухший presigned URL — единственный некапризный кейс, где
          // немедленный повтор со свежей ссылкой оправдан.
          state.retriedForExpiredUrl.add(record.id);
          record.status = SparkIntakeFileStatus.staged;
          record.taskId = null;
          state.emit();
          unawaited(_runPipeline(state));
          return;
        }
        record.status = SparkIntakeFileStatus.failed;
        record.error = update.error ?? 'Загрузка не удалась';
        state.emit();
        unawaited(_persist(state));
        _scheduleRetryTimerIfNeeded();
      case SparkIntakeTransferUpdateKind.canceled:
        // Отмена задач приходит и после removeFiles (записи уже нет — ветка
        // record==null выше), и на зомби-задачи reconcile: вернуть в staged.
        if (!record.isTerminal) {
          record.status = SparkIntakeFileStatus.staged;
          record.taskId = null;
          state.emit();
        }
    }
    _maybeStartClassification(state);
  }

  // ── Reconcile / авто-возобновление ────────────────────────────────────

  Future<void> _reconcileAndResume(_IntakeDraftState state) async {
    try {
      await _transfer.ensureInitialized();
      _ensureTransferSubscription();
      for (final record in state.files) {
        if (record.isTerminal) continue;
        final taskId = record.taskId;
        if (taskId == null) continue;
        final lookup = await _transfer.lookupTask(taskId);
        switch (lookup) {
          case SparkIntakeTaskLookup.complete:
            record.status = SparkIntakeFileStatus.uploaded;
            if (record.uploadedAtIso.isEmpty) {
              // Задача долетела, пока Dart был мёртв — точный момент неизвестен.
              record.uploadedAtIso = DateTime.now().toIso8601String();
            }
          case SparkIntakeTaskLookup.active:
            // URLSession/WorkManager либо нативный retry всё ещё владеет
            // задачей. Сохраняем taskId и не создаём конкурирующий PUT.
            if (record.status != SparkIntakeFileStatus.uploading) {
              record.status = SparkIntakeFileStatus.enqueued;
            }
          case SparkIntakeTaskLookup.missingOrDead:
            // Только действительно отсутствующую/терминальную задачу
            // выставляем повторно со свежим presigned URL.
            unawaited(_transfer.cancel(taskId));
            record.taskId = null;
            record.status = SparkIntakeFileStatus.staged;
        }
      }
      state.emit();
      await _persist(state);
    } catch (e) {
      _log('reconcile-error', draftId: state.draftId, extra: e.toString());
    }
    if (state.uploadRequested) {
      unawaited(_runPipeline(state));
    }
    _maybeStartClassification(state);
  }

  // ── Retry-цикл (длинные обрывы сети) ──────────────────────────────────
  //
  // Короткие обрывы гасят ретраи транспорта (ОС/backoff). Если сеть пропала
  // надолго, задачи оседают в failed — каждые 60с пробуем снова, пока жив
  // процесс. «Интернет появился — продолжили» без connectivity_plus:
  // неудачная попытка стоит один быстрый RPC-фейл (осознанный отказ от
  // плагина — см. AiQueueOfflineRunner).

  void _scheduleRetryTimerIfNeeded() {
    if (_retryTimer != null) return;
    if (!_hasAutoRetryWork()) return;
    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (!_hasAutoRetryWork()) {
        _maybeStopTimers();
        return;
      }
      for (final state in _states.values) {
        if (!state.uploadRequested) continue;
        var kicked = false;
        for (final record in state.files) {
          if (record.isFailed && !state.noAutoRetry.contains(record.id)) {
            record.status = SparkIntakeFileStatus.staged;
            kicked = true;
          }
        }
        if (kicked) {
          unawaited(_runPipeline(state));
        }
      }
    });
  }

  bool _hasAutoRetryWork() {
    for (final state in _states.values) {
      if (!state.uploadRequested) continue;
      for (final record in state.files) {
        if (record.isFailed && !state.noAutoRetry.contains(record.id)) {
          return true;
        }
      }
    }
    return false;
  }

  void _maybeStopTimers() {
    if (_hasAutoRetryWork()) return;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // ── Жизненный цикл приложения ─────────────────────────────────────────
  //
  // iOS замораживает Dart через ~30с после сворачивания: уже поставленные
  // задачи продолжает URLSession, но пайплайн (сжатие следующих файлов)
  // встаёт. На resume добиваем хвост.

  void _attachLifecycle() {
    if (_lifecycleAttached || kIsWeb) return;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _lifecycleAttached = true;
  }

  void _detachLifecycle() {
    if (!_lifecycleAttached) return;
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleAttached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    for (final draftState in _states.values) {
      if (!draftState.uploadRequested) continue;
      // За время suspension нативная очередь могла завершить несколько PUT,
      // а обычный Dart-listener не обязан получить события немедленно.
      // Сверка БД сама обновит статусы, поставит только потерянный хвост и
      // запустит классификацию без дополнительного действия пользователя.
      unawaited(_reconcileAndResume(draftState));
    }
  }

  // ── Файловая система / персист ────────────────────────────────────────

  Future<Uint8List?> _readLocalBytes(String source) async {
    try {
      final trimmed = source.trim();
      if (trimmed.startsWith('data:')) {
        final comma = trimmed.indexOf(',');
        if (comma <= 0) return null;
        if (!trimmed.substring(0, comma).toLowerCase().contains(';base64')) {
          return null;
        }
        return base64Decode(trimmed.substring(comma + 1));
      }
      if (kIsWeb) return null;
      final path = await _resolveNativePath(trimmed);
      if (path == null) return null;
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// file://-URI → абсолютный путь с iOS-перешивкой: контейнер приложения
  /// (и абсолютный путь к Documents) меняется между запусками, пути из
  /// старых черновиков протухают (копия логики _normalizeDocumentsLocalPath
  /// из spark_joy_storage_helpers.dart — она приватна для экрана).
  Future<String?> _resolveNativePath(String source) async {
    var path = source.trim();
    if (path.isEmpty || path.startsWith('data:')) return null;
    if (path.startsWith('file:')) {
      try {
        path = Uri.parse(path).toFilePath();
      } catch (_) {
        path = path
            .replaceFirst(RegExp(r'^file://'), '')
            .replaceFirst(RegExp(r'^file:'), '');
      }
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      const marker = '/Documents/';
      final markerIndex = path.indexOf(marker);
      if (markerIndex >= 0) {
        try {
          final docs = await getApplicationDocumentsDirectory();
          final relative = path.substring(markerIndex + marker.length).trim();
          if (relative.isNotEmpty) {
            path = '${docs.path}/$relative';
          }
        } catch (_) {
          // path_provider недоступен (тесты) — оставляем как есть.
        }
      }
    }
    if (!await File(path).exists()) return null;
    return path;
  }

  Future<String?> _hashOriginalVideo(SparkIntakeFileRecord record) async {
    if (kIsWeb) {
      final bytes = await _readLocalBytes(record.localPath);
      if (bytes == null || bytes.isEmpty) return null;
      return sparkIntakeSha256Hex(bytes);
    }
    final path = await _resolveNativePath(record.localPath);
    return path == null ? null : _sha256File(path);
  }

  Future<String> _sha256File(String path) async {
    final digest = await crypto.sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  Future<String?> _writeCompressedCopy(
    SparkIntakeFileRecord record,
    Uint8List bytes,
  ) async {
    if (kIsWeb || bytes.isEmpty) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/${SparkJoyStorage.mediaSubdirName}');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final path = '${dir.path}/intake_c_${record.id}.jpg';
      await File(path).writeAsBytes(bytes, flush: true);
      return Uri.file(path).toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteLocalArtifacts(SparkIntakeFileRecord record) async {
    if (kIsWeb) return;
    for (final source in <String?>[record.localPath, record.compressedPath]) {
      if (source == null || source.isEmpty) continue;
      try {
        final path = await _resolveNativePath(source);
        if (path != null) {
          await File(path).delete();
        }
      } catch (_) {
        // Best-effort: не удалилось — подчистит gcOrphanedMedia.
      }
    }
  }

  Future<void> _deleteCompressedCopy(SparkIntakeFileRecord record) async {
    if (kIsWeb) return;
    final source = record.compressedPath;
    if (source == null || source.isEmpty) return;
    try {
      final path = await _resolveNativePath(source);
      if (path != null) await File(path).delete();
    } catch (_) {
      // Regenerable temp copy; общий GC подчистит при следующем запуске.
    }
  }

  Future<void> _persist(_IntakeDraftState state) async {
    // false = черновик ещё не upsert'нут (новый отчёт персистится
    // post-frame): не страшно, экран всегда кладёт snapshotJsonForDraft
    // в _buildDraftPayload, ближайший автосейв довезёт.
    await SparkJoyStorage.applyDraftPatch(
      draftId: state.draftId,
      mutate: (draft) {
        draft['photoIntake'] = state.toJson();
      },
    );
  }

  static void _log(String stage, {required String draftId, String extra = ''}) {
    final suffix = extra.trim().isEmpty ? '' : ' $extra';
    developer.log(
      '[$stage][draft=$draftId]$suffix',
      name: 'SparkJoyIntakeUpload',
    );
  }
}

/// Случайное имя объекта в temp/ S3. Случайный hex обязателен — temp/ общий
/// на всех юзеров, а view-URL подписывается на любое имя без проверки
/// владельца (IDOR-урок скана СТС: `doc_scan_<мс>_<hex>.jpg`).
String sparkIntakeRemoteName({
  required String mimeType,
  required String originalName,
  required bool compressed,
  math.Random? random,
}) {
  final rnd = random ?? math.Random.secure();
  final hex = List<String>.generate(
    8,
    (_) => rnd.nextInt(16).toRadixString(16),
  ).join();
  final ext = compressed
      ? 'jpg'
      : _sparkIntakeExtension(mimeType: mimeType, originalName: originalName);
  return 'intake_${DateTime.now().millisecondsSinceEpoch}_$hex.$ext';
}

/// Русские плюралы для счётчика файлов: 1 файл / 2 файла / 5 файлов.
String sparkIntakeFilesCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final String word;
  if (mod10 == 1 && mod100 != 11) {
    word = 'файл';
  } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    word = 'файла';
  } else {
    word = 'файлов';
  }
  return '$count $word';
}

/// «1,2 МБ» / «640 КБ» — как в макете (десятичная запятая).
String sparkIntakeSizeLabel(int bytes) {
  if (bytes <= 0) return '';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes < kb) return '$bytes Б';
  if (bytes < mb) return '${(bytes / kb).round()} КБ';
  final value = bytes / mb;
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.truncate()
      ? rounded.truncate().toString()
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text МБ';
}

String _sparkIntakeExtension({
  required String mimeType,
  required String originalName,
}) {
  const byMime = <String, String>{
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'image/heif': 'heif',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'video/webm': 'webm',
    'application/pdf': 'pdf',
    'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
  };
  final mapped = byMime[mimeType.toLowerCase().trim()];
  if (mapped != null) return mapped;
  // Расширение из имени: только безопасный ASCII-хвост, без путей.
  final name = originalName.split('/').last.split(r'\').last;
  final dot = name.lastIndexOf('.');
  if (dot > 0 && dot < name.length - 1) {
    final ext = name.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext)) return ext;
  }
  return 'bin';
}

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
import 'package:path_provider/path_provider.dart';

import 'package:flutter_application_1/data/api/storage_api.dart'
    show StorageApi, SessionExpiredException;
import 'package:flutter_application_1/data/services/spark_joy_intake_transfer.dart';
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

  SparkIntakeFileRecord({
    required this.id,
    required this.name,
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
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isDocument => !isImage && !isVideo;
  bool get isUploaded => status == SparkIntakeFileStatus.uploaded;
  bool get isFailed => status == SparkIntakeFileStatus.failed;
  bool get isTerminal => isUploaded || isFailed;

  Map<String, dynamic> toJson() {
    final persistedStatus = switch (status) {
      SparkIntakeFileStatus.uploaded => SparkIntakeFileStatus.uploaded,
      SparkIntakeFileStatus.failed => SparkIntakeFileStatus.failed,
      _ => SparkIntakeFileStatus.staged,
    };
    return <String, dynamic>{
      'id': id,
      'name': name,
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
    );
  }
}

enum SparkIntakePhase {
  /// Файлов нет.
  idle,

  /// Файлы добавлены, «Распределить файлы» ещё не нажимали.
  staged,

  /// Заливка запрошена и не вся завершена.
  uploading,

  /// Всё загружено.
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

  const SparkIntakeSnapshot({
    required this.draftId,
    required this.files,
    required this.uploadRequested,
    required this.uploadedCount,
    required this.failedCount,
    required this.progress,
    required this.phase,
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

  /// Прогресс текущей заливки per-record (0..1), только in-memory.
  final Map<String, double> progressById = <String, double>{};

  /// Записи, которые бессмысленно ретраить автоматически (файл пропал).
  final Set<String> noAutoRetry = <String>{};

  /// Записи, уже получившие один бесплатный ре-enqueue по HTTP 403
  /// (протухший presigned URL) — вторые 403 уходят в общий retry-цикл.
  final Set<String> retriedForExpiredUrl = <String>{};

  late final ValueNotifier<SparkIntakeSnapshot> notifier =
      ValueNotifier<SparkIntakeSnapshot>(SparkIntakeSnapshot.empty(draftId));

  _IntakeDraftState(this.draftId);

  SparkIntakeFileRecord? recordById(String id) {
    for (final r in files) {
      if (r.id == id) return r;
    }
    return null;
  }

  SparkIntakeSnapshot snapshot() {
    var uploaded = 0;
    var failed = 0;
    var weightTotal = 0.0;
    var weightDone = 0.0;
    var hasLive = false;
    for (final r in files) {
      final weight = math.max(r.sizeBytes, 1).toDouble();
      weightTotal += weight;
      switch (r.status) {
        case SparkIntakeFileStatus.uploaded:
          uploaded += 1;
          weightDone += weight;
        case SparkIntakeFileStatus.failed:
          failed += 1;
        case SparkIntakeFileStatus.uploading ||
              SparkIntakeFileStatus.enqueued ||
              SparkIntakeFileStatus.compressing:
          hasLive = true;
          weightDone += weight * (progressById[r.id] ?? 0).clamp(0.0, 1.0);
        default:
          if (uploadRequested) hasLive = true;
      }
    }
    final SparkIntakePhase phase;
    if (files.isEmpty) {
      phase = SparkIntakePhase.idle;
    } else if (!uploadRequested) {
      phase = SparkIntakePhase.staged;
    } else if (uploaded == files.length) {
      phase = SparkIntakePhase.done;
    } else if (hasLive) {
      phase = SparkIntakePhase.uploading;
    } else {
      phase = SparkIntakePhase.failed;
    }
    return SparkIntakeSnapshot(
      draftId: draftId,
      files: List<SparkIntakeFileRecord>.unmodifiable(files),
      uploadRequested: uploadRequested,
      uploadedCount: uploaded,
      failedCount: failed,
      progress: weightTotal <= 0 ? 0 : (weightDone / weightTotal).clamp(0.0, 1.0),
      phase: phase,
    );
  }

  void emit() {
    notifier.value = snapshot();
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
  }

  /// Тестовый шов выпуска presigned URL (по умолчанию —
  /// StorageApi.getTemporaryUploadUrl с reportNumber: 'temp').
  @visibleForTesting
  static Future<({String url, String key})> Function(String filename)?
      presignOverride;

  static const Duration _retryInterval = Duration(seconds: 60);

  final Map<String, _IntakeDraftState> _states = <String, _IntakeDraftState>{};
  SparkIntakeTransfer? _transferOverride;
  SparkIntakeTransfer? _transferInstance;
  StreamSubscription<SparkIntakeTransferUpdate>? _transferSub;
  Timer? _retryTimer;
  bool _lifecycleAttached = false;

  SparkIntakeTransfer get _transfer {
    final override = _transferOverride;
    if (override != null) return override;
    return _transferInstance ??=
        kIsWeb ? SparkIntakeTransferWeb() : SparkIntakeTransferIo();
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
    state.emit();
    if (state.files.isNotEmpty) {
      unawaited(_reconcileAndResume(state));
    }
  }

  /// Добавляет файлы в интейк и персистит. Файлы уже должны лежать в
  /// локальном хранилище (пикеры экрана копируют их сами).
  Future<void> stageFiles(
    String draftId,
    List<SparkIntakeFileRecord> records,
  ) async {
    if (records.isEmpty) return;
    final state = _stateFor(draftId);
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
    final removed = state.files.where((r) => recordIds.contains(r.id)).toList();
    if (removed.isEmpty) return;
    state.files.removeWhere((r) => recordIds.contains(r.id));
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
  Future<void> dropDraft(String draftId, {bool deleteLocalFiles = false}) async {
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
    }
  }

  Future<void> _processRecord(
    _IntakeDraftState state,
    SparkIntakeFileRecord record,
  ) async {
    try {
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
        } else if (!identical(prepared, original)) {
          final path = await _writeCompressedCopy(record, prepared);
          if (path != null) {
            record.compressedPath = path;
            await _persist(state);
          }
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
          originalName: record.name,
          compressed: record.compressedPath != null ||
              (kIsWeb && record.isImage),
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
      final uploadMime = record.compressedPath != null ||
              (kIsWeb && record.isImage)
          ? 'image/jpeg'
          : record.mimeType;
      final taskId = await _transfer.enqueue(SparkIntakeUploadPayload(
        draftId: state.draftId,
        recordId: record.id,
        url: presigned.url,
        mimeType: uploadMime,
        filePath: filePath,
        bytes: webBytes,
      ));
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
      _log('record-failed', draftId: state.draftId, extra: 'id=${record.id} $e');
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
        if (lookup == SparkIntakeTaskLookup.complete) {
          record.status = SparkIntakeFileStatus.uploaded;
          if (record.uploadedAtIso.isEmpty) {
            // Задача долетела, пока Dart был мёртв — точный момент неизвестен.
            record.uploadedAtIso = DateTime.now().toIso8601String();
          }
        } else {
          // Зомби (running/enqueued из прошлой жизни процесса) — судьба
          // непредсказуема: отменяем и перезальём с нуля.
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
      final hasWork =
          draftState.files.any((r) => _isPipelineCandidate(draftState, r));
      if (hasWork) {
        unawaited(_runPipeline(draftState));
      }
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

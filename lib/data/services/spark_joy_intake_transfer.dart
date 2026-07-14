// Транспорт фоновой заливки интейка «Фото автомобиля» в S3.
//
// Два бэкенда за одним интерфейсом, выбор в рантайме по kIsWeb (пакет
// background_downloader и dart:io шьют web-стабы, так что условный импорт
// не нужен — компилируется везде, вызываться web-ветка io-класса не будет):
//  - IO (Android/iOS): background_downloader — iOS background URLSession /
//    Android WorkManager. Загрузка продолжается при свёрнутом приложении;
//    обрыв только при force-kill из шторки или перезагрузке устройства
//    (принятое ограничение). Пропажа сети — пауза/ретраи на уровне ОС.
//  - Web (PWA): foreground-очередь на StorageApi.uploadBytesToPresignedUrl
//    (фоновых трансферов в браузере нет) — живёт, пока открыта страница.
//
// Транспорт тупой: получил presigned URL + источник байтов → грузит →
// стримит апдейты. Сжатие, выбор URL, статусы записей и персист — в
// SparkJoyIntakeUploadService.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_application_1/data/api/storage_api.dart'
    show StorageApi;

/// Группа задач background_downloader, чтобы reconcile по персистентной БД
/// не цеплял чужие трансферы, если они появятся в приложении позже.
const String kSparkIntakeTaskGroup = 'sparkJoyIntake';

/// Событие транспорта. [progress] актуален для kind=progress (0..1).
/// [httpStatusCode] — код терминальной ошибки, если известен (403 = протух
/// presigned URL, сервис перевыпускает ссылку).
class SparkIntakeTransferUpdate {
  final String draftId;
  final String recordId;
  final SparkIntakeTransferUpdateKind kind;
  final double progress;
  final int? httpStatusCode;
  final String? error;

  const SparkIntakeTransferUpdate({
    required this.draftId,
    required this.recordId,
    required this.kind,
    this.progress = 0,
    this.httpStatusCode,
    this.error,
  });
}

enum SparkIntakeTransferUpdateKind { progress, complete, failed, canceled }

/// Результат сверки задачи с персистентной БД транспорта после перезапуска.
enum SparkIntakeTaskLookup {
  /// Задача успешно завершилась, пока основной Dart-isolate был заморожен.
  complete,

  /// Задача всё ещё принадлежит нативной очереди (включая retry/backoff).
  /// Такую задачу нельзя отменять и выставлять повторно при reconcile.
  active,

  /// Задачи нет либо она завершилась терминальной ошибкой.
  missingOrDead,
}

/// Источник байтов: на native — путь к файлу (заливка без чтения байтов в
/// Dart-память), на web — сами байты (файловой системы нет).
class SparkIntakeUploadPayload {
  final String draftId;
  final String recordId;
  final String url;
  final String mimeType;
  final String? filePath;
  final Uint8List? bytes;

  const SparkIntakeUploadPayload({
    required this.draftId,
    required this.recordId,
    required this.url,
    required this.mimeType,
    this.filePath,
    this.bytes,
  });

  String get metaData => '$draftId|$recordId';
}

abstract class SparkIntakeTransfer {
  /// Ленивая инициализация (трекинг задач, подписка на апдейты, доставка
  /// событий, накопившихся в фоне). Повторные вызовы — no-op.
  Future<void> ensureInitialized();

  Stream<SparkIntakeTransferUpdate> get updates;

  /// Ставит загрузку. Возвращает taskId или null, если поставить не удалось.
  Future<String?> enqueue(SparkIntakeUploadPayload payload);

  Future<void> cancel(String taskId);

  /// Смотрит судьбу задачи из прошлого запуска в персистентной БД.
  /// На web всегда [SparkIntakeTaskLookup.missingOrDead] — БД задач нет.
  Future<SparkIntakeTaskLookup> lookupTask(String taskId);
}

/// IO-бэкенд: background_downloader.
class SparkIntakeTransferIo implements SparkIntakeTransfer {
  Future<void>? _initialization;
  final _updates = StreamController<SparkIntakeTransferUpdate>.broadcast();

  @override
  Stream<SparkIntakeTransferUpdate> get updates => _updates.stream;

  @override
  Future<void> ensureInitialized() async {
    final existing = _initialization;
    if (existing != null) return existing;
    final pending = _initialize();
    _initialization = pending;
    try {
      await pending;
    } catch (_) {
      // Не оставляем транспорт навсегда «инициализированным», если первый
      // вызов пришёлся на временную ошибку платформенного канала.
      if (identical(_initialization, pending)) _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    // Ограничение живёт на нативной стороне. Уже подготовленные задачи будут
    // выходить из очереди и при замороженном Dart-isolate.
    await FileDownloader().configure(
      globalConfig: (Config.holdingQueue, (3, 2, 2)),
      // iOS по умолчанию завершает resource timeout через 4 часа. Длинный
      // офлайн-период не должен превращать валидную загрузку в terminal fail.
      iOSConfig: (Config.resourceTimeout, const Duration(hours: 24)),
    );
    // Android 13+: WorkManager-заливка без видимой нотификации не имеет
    // foreground-приоритета — Doze охотно убивает задачи при свёрнутом
    // приложении, и пользователь не видит прогресс. Одна групповая
    // нотификация на всю пачку фото. iOS не трогаем: там фон держит
    // URLSession и системный диалог разрешения нотификаций приложение
    // никогда не показывало.
    if (Platform.isAndroid) {
      FileDownloader().configureNotificationForGroup(
        kSparkIntakeTaskGroup,
        running: const TaskNotification(
          'Загрузка фото автомобиля',
          'Загружено {numFinished} из {numTotal}',
        ),
        complete: const TaskNotification(
          'Фото автомобиля загружены',
          'Все файлы отправлены',
        ),
        error: const TaskNotification(
          'Загрузка не завершена',
          'Часть файлов не отправлена — откройте приложение',
        ),
        progressBar: true,
        groupNotificationId: kSparkIntakeTaskGroup,
      );
      final permissions = FileDownloader().permissions;
      if (await permissions.status(PermissionType.notifications) ==
          PermissionStatus.undetermined) {
        await permissions.request(PermissionType.notifications);
      }
    }
    await FileDownloader().trackTasksInGroup(kSparkIntakeTaskGroup);
    FileDownloader().updates.listen(_onUpdate);
    // Доносит статусы/прогресс задач, завершившихся, пока Dart был мёртв
    // (iOS URLSession будил только нативный слой).
    await FileDownloader().resumeFromBackground();
  }

  void _onUpdate(TaskUpdate update) {
    final task = update.task;
    if (task.group != kSparkIntakeTaskGroup) return;
    final meta = task.metaData.split('|');
    if (meta.length != 2) return;
    final draftId = meta[0];
    final recordId = meta[1];
    switch (update) {
      case TaskProgressUpdate():
        // Отрицательные значения — служебные маркеры bgd (fail/cancel),
        // статусные события придут отдельно.
        if (update.progress >= 0) {
          _emit(
            SparkIntakeTransferUpdate(
              draftId: draftId,
              recordId: recordId,
              kind: SparkIntakeTransferUpdateKind.progress,
              progress: update.progress.clamp(0.0, 1.0),
            ),
          );
        }
      case TaskStatusUpdate():
        switch (update.status) {
          case TaskStatus.complete:
            _emit(
              SparkIntakeTransferUpdate(
                draftId: draftId,
                recordId: recordId,
                kind: SparkIntakeTransferUpdateKind.complete,
              ),
            );
          case TaskStatus.failed || TaskStatus.notFound:
            final exception = update.exception;
            _emit(
              SparkIntakeTransferUpdate(
                draftId: draftId,
                recordId: recordId,
                kind: SparkIntakeTransferUpdateKind.failed,
                httpStatusCode:
                    update.responseStatusCode ??
                    (exception is TaskHttpException
                        ? exception.httpResponseCode
                        : null),
                error: exception?.description ?? 'Загрузка не удалась',
              ),
            );
          case TaskStatus.canceled:
            _emit(
              SparkIntakeTransferUpdate(
                draftId: draftId,
                recordId: recordId,
                kind: SparkIntakeTransferUpdateKind.canceled,
              ),
            );
          // enqueued/running/waitingToRetry/paused — промежуточные, статус
          // записи двигают события прогресса и терминальные исходы.
          default:
            break;
        }
    }
  }

  void _emit(SparkIntakeTransferUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  @override
  Future<String?> enqueue(SparkIntakeUploadPayload payload) async {
    final filePath = payload.filePath;
    if (filePath == null || filePath.isEmpty) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    final task = UploadTask.fromFile(
      file: file,
      url: payload.url,
      httpRequestMethod: 'PUT',
      // 'binary' = тело запроса — сырые байты файла (то, чего ждёт
      // presigned PUT), а не multipart/form-data.
      post: 'binary',
      mimeType: payload.mimeType,
      group: kSparkIntakeTaskGroup,
      updates: Updates.statusAndProgress,
      // Ретраи с backoff на уровне ОС покрывают короткие обрывы сети;
      // длинные покрывает retry-цикл сервиса поверх терминального failed.
      // Максимум, поддерживаемый background_downloader. Ретраи выполняются
      // нативно и поэтому не зависят от Timer в замороженном приложении.
      retries: 10,
      metaData: payload.metaData,
    );
    final ok = await FileDownloader().enqueue(task);
    return ok ? task.taskId : null;
  }

  @override
  Future<void> cancel(String taskId) async {
    try {
      await FileDownloader().cancelTaskWithId(taskId);
    } catch (_) {
      // Задача могла уже завершиться/исчезнуть — не важно.
    }
  }

  @override
  Future<SparkIntakeTaskLookup> lookupTask(String taskId) async {
    try {
      final record = await FileDownloader().database.recordForId(taskId);
      if (record != null) {
        if (record.status == TaskStatus.complete) {
          return SparkIntakeTaskLookup.complete;
        }
        if (!record.status.isFinalState ||
            record.status == TaskStatus.waitingToRetry ||
            record.status == TaskStatus.paused) {
          return SparkIntakeTaskLookup.active;
        }
      }
    } catch (_) {
      // Битая БД задач = «неизвестно» — перезальём файл, это безопасно.
    }
    return SparkIntakeTaskLookup.missingOrDead;
  }
}

/// Web-бэкенд: последовательная foreground-очередь. Прогресс через Dio
/// onSendProgress; ретраи коротких обрывов делает сервис (его retry-цикл),
/// здесь — одна честная попытка на файл.
class SparkIntakeTransferWeb implements SparkIntakeTransfer {
  final _updates = StreamController<SparkIntakeTransferUpdate>.broadcast();
  final List<SparkIntakeUploadPayload> _queue = <SparkIntakeUploadPayload>[];
  final Set<String> _canceled = <String>{};
  bool _draining = false;
  int _seq = 0;

  @override
  Stream<SparkIntakeTransferUpdate> get updates => _updates.stream;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<String?> enqueue(SparkIntakeUploadPayload payload) async {
    final bytes = payload.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    _queue.add(payload);
    final taskId = 'web_${_seq++}_${payload.recordId}';
    _taskIds[payload.recordId] = taskId;
    unawaited(_drain());
    return taskId;
  }

  final Map<String, String> _taskIds = <String, String>{};

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final payload = _queue.removeAt(0);
        final taskId = _taskIds[payload.recordId] ?? '';
        if (_canceled.remove(taskId)) continue;
        try {
          await StorageApi.uploadBytesToPresignedUrl(
            url: payload.url,
            bytes: payload.bytes!,
            contentType: payload.mimeType,
            // Видео с медленного канала может не влезть в дефолтные 60с.
            timeout: const Duration(minutes: 10),
            onProgress: (sent, total) {
              if (total <= 0 || _updates.isClosed) return;
              _updates.add(
                SparkIntakeTransferUpdate(
                  draftId: payload.draftId,
                  recordId: payload.recordId,
                  kind: SparkIntakeTransferUpdateKind.progress,
                  progress: (sent / total).clamp(0.0, 1.0),
                ),
              );
            },
          );
          if (_canceled.remove(taskId)) continue;
          _emit(payload, SparkIntakeTransferUpdateKind.complete);
        } catch (e) {
          if (_canceled.remove(taskId)) continue;
          _emit(
            payload,
            SparkIntakeTransferUpdateKind.failed,
            error: e.toString(),
          );
        }
      }
    } finally {
      _draining = false;
    }
  }

  void _emit(
    SparkIntakeUploadPayload payload,
    SparkIntakeTransferUpdateKind kind, {
    String? error,
  }) {
    if (_updates.isClosed) return;
    _updates.add(
      SparkIntakeTransferUpdate(
        draftId: payload.draftId,
        recordId: payload.recordId,
        kind: kind,
        error: error,
      ),
    );
  }

  @override
  Future<void> cancel(String taskId) async {
    _canceled.add(taskId);
    _queue.removeWhere((p) => _taskIds[p.recordId] == taskId);
  }

  @override
  Future<SparkIntakeTaskLookup> lookupTask(String taskId) async {
    return SparkIntakeTaskLookup.missingOrDead;
  }
}

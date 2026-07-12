import 'dart:async';
import 'dart:io';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/spark_joy_intake_transfer.dart';
import 'package:flutter_application_1/data/services/spark_joy_intake_upload_service.dart';
import 'package:flutter_application_1/data/services/spark_joy_intake_video_prep.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_intake_ai.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTransfer implements SparkIntakeTransfer {
  final StreamController<SparkIntakeTransferUpdate> _updates =
      StreamController<SparkIntakeTransferUpdate>.broadcast();
  final List<SparkIntakeUploadPayload> enqueued = <SparkIntakeUploadPayload>[];
  final List<String> cancelled = <String>[];
  final Map<String, SparkIntakeTaskLookup> lookups =
      <String, SparkIntakeTaskLookup>{};
  bool failEnqueue = false;
  int _seq = 0;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Stream<SparkIntakeTransferUpdate> get updates => _updates.stream;

  @override
  Future<String?> enqueue(SparkIntakeUploadPayload payload) async {
    if (failEnqueue) return null;
    enqueued.add(payload);
    return 'task_${_seq++}';
  }

  @override
  Future<void> cancel(String taskId) async {
    cancelled.add(taskId);
  }

  @override
  Future<SparkIntakeTaskLookup> lookupTask(String taskId) async {
    return lookups[taskId] ?? SparkIntakeTaskLookup.missingOrDead;
  }

  void emitComplete(String draftId, String recordId) {
    _updates.add(
      SparkIntakeTransferUpdate(
        draftId: draftId,
        recordId: recordId,
        kind: SparkIntakeTransferUpdateKind.complete,
      ),
    );
  }

  void emitFailed(String draftId, String recordId, {int? statusCode}) {
    _updates.add(
      SparkIntakeTransferUpdate(
        draftId: draftId,
        recordId: recordId,
        kind: SparkIntakeTransferUpdateKind.failed,
        httpStatusCode: statusCode,
        error: 'boom',
      ),
    );
  }

  void emitProgress(String draftId, String recordId, double progress) {
    _updates.add(
      SparkIntakeTransferUpdate(
        draftId: draftId,
        recordId: recordId,
        kind: SparkIntakeTransferUpdateKind.progress,
        progress: progress,
      ),
    );
  }
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('условие не выполнилось за $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

SparkJoyIntakeUploadService get service => SparkJoyIntakeUploadService.instance;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeTransfer transfer;
  late Directory tempDir;
  var presignCalls = 0;
  const draftId = 'draft_intake_test';

  Future<SparkIntakeFileRecord> makeDocRecord(String id) async {
    final file = File('${tempDir.path}/$id.pdf');
    await file.writeAsBytes(List<int>.filled(100, 7));
    return SparkIntakeFileRecord(
      id: id,
      name: '$id.pdf',
      mimeType: 'application/pdf',
      localPath: file.path,
      sizeBytes: 100,
    );
  }

  Future<SparkIntakeFileRecord> makeImageRecord(String id) async {
    final image = img.Image(width: 64, height: 48);
    img.fill(image, color: img.ColorRgb8(20, 40, 60));
    final original = File('${tempDir.path}/$id.png');
    await original.writeAsBytes(img.encodePng(image));
    final compressed = File('${tempDir.path}/${id}_compressed.jpg');
    await compressed.writeAsBytes(img.encodeJpg(image, quality: 82));
    return SparkIntakeFileRecord(
      id: id,
      name: '$id.png',
      mimeType: 'image/png',
      localPath: original.path,
      compressedPath: compressed.path,
      sizeBytes: await original.length(),
    );
  }

  Future<SparkIntakeFileRecord> makeVideoRecord(String id) async {
    final original = File('${tempDir.path}/$id.mp4');
    await original.writeAsBytes(List<int>.generate(1024, (i) => i % 251));
    return SparkIntakeFileRecord(
      id: id,
      name: '$id.mp4',
      mimeType: 'video/mp4',
      localPath: original.path,
      sizeBytes: await original.length(),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();
    tempDir = await Directory.systemTemp.createTemp('intake_test');
    transfer = _FakeTransfer();
    SparkJoyIntakeUploadService.resetSingletonForTest(transfer: transfer);
    presignCalls = 0;
    SparkJoyIntakeUploadService.presignOverride = (filename) async {
      presignCalls += 1;
      return (url: 'https://s3.example/put/$filename', key: 'temp/$filename');
    };
    await SparkJoyStorage.upsertDraft(<String, dynamic>{'id': draftId});
  });

  tearDown(() async {
    await service.resetAll();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<Map<String, dynamic>?> persistedIntake() async {
    final drafts = await SparkJoyStorage.loadDrafts();
    final draft = drafts.firstWhere((d) => d['id'] == draftId);
    final raw = draft['photoIntake'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  test('пустой черновик без ключа photoIntake → пустой снапшот', () {
    service.hydrateFromDraft(draftId: draftId, rawPhotoIntake: null);
    final snapshot = service.snapshotOf(draftId);
    expect(snapshot.total, 0);
    expect(snapshot.phase, SparkIntakePhase.idle);
  });

  test('stageFiles: staged-фаза + персист в черновик', () async {
    await service.stageFiles(draftId, [await makeDocRecord('a')]);
    final snapshot = service.snapshotOf(draftId);
    expect(snapshot.total, 1);
    expect(snapshot.phase, SparkIntakePhase.staged);
    final persisted = await persistedIntake();
    expect(persisted, isNotNull);
    expect((persisted!['files'] as List).length, 1);
    expect(persisted['uploadRequested'], isFalse);
  });

  test('happy path: startUpload → enqueue со свежим URL → uploaded', () async {
    await service.stageFiles(draftId, [
      await makeDocRecord('a'),
      await makeDocRecord('b'),
    ]);
    await service.startUpload(draftId);
    await _waitFor(() => transfer.enqueued.length == 2);
    expect(presignCalls, 2);
    expect(
      transfer.enqueued.first.url,
      startsWith('https://s3.example/put/intake_'),
    );
    expect(transfer.enqueued.first.filePath, isNotNull);

    // Прогресс двигает фазу и проценты.
    transfer.emitProgress(draftId, 'a', 0.5);
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.uploading,
    );

    transfer.emitComplete(draftId, 'a');
    transfer.emitComplete(draftId, 'b');
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.classified,
    );
    final snapshot = service.snapshotOf(draftId);
    expect(snapshot.uploadedCount, 2);
    expect(snapshot.progress, 1.0);
    final recordA = snapshot.files.firstWhere((r) => r.id == 'a');
    expect(recordA.s3Key, startsWith('temp/intake_'));
    expect(recordA.uploadedAtIso, isNotEmpty);

    final persisted = await persistedIntake();
    expect(persisted!['uploadRequested'], isTrue);
    final statuses = (persisted['files'] as List)
        .map((f) => (f as Map)['status'])
        .toSet();
    expect(statuses, {SparkIntakeFileStatus.uploaded});
  });

  test('терминальная ошибка транспорта → failed-фаза с ошибкой', () async {
    await service.stageFiles(draftId, [await makeDocRecord('a')]);
    await service.startUpload(draftId);
    await _waitFor(() => transfer.enqueued.length == 1);
    transfer.emitFailed(draftId, 'a');
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.failed,
    );
    final record = service.snapshotOf(draftId).files.single;
    expect(record.status, SparkIntakeFileStatus.failed);
    expect(record.error, 'boom');
  });

  test(
    'HTTP 403 (протухший URL) → одно бесплатное перевыставление задачи',
    () async {
      await service.stageFiles(draftId, [await makeDocRecord('a')]);
      await service.startUpload(draftId);
      await _waitFor(() => transfer.enqueued.length == 1);
      transfer.emitFailed(draftId, 'a', statusCode: 403);
      // Свежий URL + новая задача.
      await _waitFor(() => transfer.enqueued.length == 2);
      expect(presignCalls, 2);
      transfer.emitComplete(draftId, 'a');
      await _waitFor(
        () => service.snapshotOf(draftId).phase == SparkIntakePhase.classified,
      );
      // Повторный 403 уже не крутит бесплатный цикл (уйдёт в retry-таймер).
    },
  );

  test('reconcile: complete в БД задач → uploaded без перезаливки', () async {
    transfer.lookups['task_done'] = SparkIntakeTaskLookup.complete;
    final record = await makeDocRecord('a');
    service.hydrateFromDraft(
      draftId: draftId,
      rawPhotoIntake: <String, dynamic>{
        'uploadRequested': true,
        'files': [
          <String, dynamic>{
            ...record.toJson(),
            'taskId': 'task_done',
            's3Key': 'temp/x.pdf',
          },
        ],
      },
    );
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.classified,
    );
    expect(transfer.enqueued, isEmpty, reason: 'файл уже долетел — не грузим');
    final restored = service.snapshotOf(draftId).files.single;
    expect(restored.uploadedAtIso, isNotEmpty);
  });

  test(
    'reconcile: активная фоновая задача не отменяется и не дублируется',
    () async {
      transfer.lookups['task_active'] = SparkIntakeTaskLookup.active;
      final record = await makeDocRecord('a');
      service.hydrateFromDraft(
        draftId: draftId,
        rawPhotoIntake: <String, dynamic>{
          'uploadRequested': true,
          'files': [
            <String, dynamic>{
              ...record.toJson(),
              'taskId': 'task_active',
              'status': SparkIntakeFileStatus.uploading,
            },
          ],
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(transfer.cancelled, isEmpty);
      expect(transfer.enqueued, isEmpty);
      final restored = service.snapshotOf(draftId).files.single;
      expect(restored.taskId, 'task_active');
      expect(restored.status, SparkIntakeFileStatus.enqueued);
    },
  );

  test(
    'resume сверяет завершившуюся в фоне задачу без действия пользователя',
    () async {
      transfer.lookups['task_background'] = SparkIntakeTaskLookup.active;
      final record = await makeDocRecord('a');
      service.hydrateFromDraft(
        draftId: draftId,
        rawPhotoIntake: <String, dynamic>{
          'uploadRequested': true,
          'files': [
            <String, dynamic>{
              ...record.toJson(),
              'taskId': 'task_background',
              'status': SparkIntakeFileStatus.enqueued,
            },
          ],
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      transfer.lookups['task_background'] = SparkIntakeTaskLookup.complete;

      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      await _waitFor(() => service.snapshotOf(draftId).files.single.isUploaded);
      expect(transfer.cancelled, isEmpty);
      expect(transfer.enqueued, isEmpty);
    },
  );

  test('reconcile: зомби-задача отменяется и файл перезаливается', () async {
    final record = await makeDocRecord('a');
    service.hydrateFromDraft(
      draftId: draftId,
      rawPhotoIntake: <String, dynamic>{
        'uploadRequested': true,
        'files': [
          <String, dynamic>{...record.toJson(), 'taskId': 'task_zombie'},
        ],
      },
    );
    await _waitFor(() => transfer.enqueued.length == 1);
    expect(transfer.cancelled, contains('task_zombie'));
  });

  test('removeFiles: отмена живой задачи + удаление записи', () async {
    await service.stageFiles(draftId, [
      await makeDocRecord('a'),
      await makeDocRecord('b'),
    ]);
    await service.startUpload(draftId);
    await _waitFor(() => transfer.enqueued.length == 2);
    await service.removeFiles(draftId, {'a'});
    final snapshot = service.snapshotOf(draftId);
    expect(snapshot.files.map((r) => r.id), ['b']);
    expect(transfer.cancelled, isNotEmpty);
    final persisted = await persistedIntake();
    expect((persisted!['files'] as List).length, 1);
  });

  test('removeFiles с deleteLocalFiles=true удаляет локальную копию', () async {
    final record = await makeDocRecord('a');
    final file = File(record.localPath);
    expect(await file.exists(), isTrue);
    await service.stageFiles(draftId, [record]);
    await service.removeFiles(draftId, {'a'});
    await _waitFor(() => !file.existsSync());
  });

  test('dropDraft гасит задачи и чистит состояние', () async {
    await service.stageFiles(draftId, [await makeDocRecord('a')]);
    await service.startUpload(draftId);
    await _waitFor(() => transfer.enqueued.length == 1);
    await service.dropDraft(draftId);
    expect(transfer.cancelled, isNotEmpty);
    expect(service.snapshotOf(draftId).total, 0);
  });

  test('enqueue-фейл транспорта → failed без ретрая на месте', () async {
    transfer.failEnqueue = true;
    await service.stageFiles(draftId, [await makeDocRecord('a')]);
    await service.startUpload(draftId);
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.failed,
    );
    expect(transfer.enqueued, isEmpty);
  });

  test('пропавший локальный файл → failed без авторетрая', () async {
    final record = SparkIntakeFileRecord(
      id: 'ghost',
      name: 'ghost.pdf',
      mimeType: 'application/pdf',
      localPath: '${tempDir.path}/нет_такого.pdf',
      sizeBytes: 10,
    );
    await service.stageFiles(draftId, [record]);
    await service.startUpload(draftId);
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.failed,
    );
    expect(presignCalls, 0, reason: 'до presigned URL дойти не должны');
    expect(
      service.snapshotOf(draftId).files.single.error,
      contains('недоступен'),
    );
  });

  test('снапшот «N из M» и взвешенный прогресс', () async {
    final small = await makeDocRecord('small'); // 100 байт
    final bigFile = File('${tempDir.path}/big.pdf');
    await bigFile.writeAsBytes(List<int>.filled(300, 1));
    final big = SparkIntakeFileRecord(
      id: 'big',
      name: 'big.pdf',
      mimeType: 'application/pdf',
      localPath: bigFile.path,
      sizeBytes: 300,
    );
    await service.stageFiles(draftId, [small, big]);
    await service.startUpload(draftId);
    await _waitFor(() => transfer.enqueued.length == 2);
    transfer.emitComplete(draftId, 'small');
    await _waitFor(() => service.snapshotOf(draftId).uploadedCount == 1);
    final snapshot = service.snapshotOf(draftId);
    expect(snapshot.total, 2);
    // 100 из 400 байт → 25%.
    expect(snapshot.progress, closeTo(0.25, 0.001));
  });

  test(
    'hash считается до загрузки, а ИИ стартует после последнего complete',
    () async {
      var aiCalls = 0;
      SparkJoyIntakeUploadService.viewUrlOverride = (filename) async =>
          'https://s3.example/get/$filename';
      SparkJoyIntakeUploadService.aiChatOverride =
          ({required text, required cliche, required fileUrls}) async {
            aiCalls += 1;
            final hash = RegExp(
              r'hash=([a-f0-9]{64})',
            ).firstMatch(text)!.group(1)!;
            return '{"items":[{"hash":"$hash","section":"inspection",'
                '"documentKind":"","group":"body","element":"hood"}]}';
          };
      service.configureAi(
        draftId,
        const SparkIntakeAiConfig(
          cliche: 'test {text}',
          elementsByGroup: <String, Set<String>>{
            'body': <String>{'hood'},
          },
        ),
      );
      final record = await makeImageRecord('photo');
      await service.stageFiles(draftId, [record]);
      expect(record.sha256, hasLength(64));
      expect(aiCalls, 0);

      await service.startUpload(draftId);
      await _waitFor(() => transfer.enqueued.length == 1);
      expect(aiCalls, 0, reason: 'до complete vision запускать нельзя');
      transfer.emitComplete(draftId, record.id);

      await _waitFor(() => aiCalls == 1);
      await _waitFor(
        () => service.snapshotOf(draftId).phase == SparkIntakePhase.classified,
      );
      final classified = service.snapshotOf(draftId).files.single;
      expect(classified.aiSection, SparkIntakeAiSection.inspection);
      expect(classified.aiGroup, 'body');
      expect(classified.aiElement, 'hood');
    },
  );

  test(
    'видео 13с → 5 скрытых JPEG-кадров в S3 → один вердикт оригиналу',
    () async {
      SparkJoyIntakeUploadService.videoFrameExtractorOverride =
          ({
            required videoPath,
            required outputDirectory,
            required filePrefix,
          }) async {
            final frames = <SparkIntakeExtractedVideoFrame>[];
            final times = sparkIntakeVideoFrameTimesMs(
              const Duration(seconds: 13),
            );
            for (var i = 0; i < times.length; i++) {
              final file = File('$outputDirectory/${filePrefix}_$i.jpg');
              await file.writeAsBytes(List<int>.filled(80 + i, i + 1));
              frames.add(
                SparkIntakeExtractedVideoFrame(
                  index: i,
                  timeMs: times[i],
                  path: file.path,
                  sizeBytes: await file.length(),
                ),
              );
            }
            return SparkIntakeVideoFrameSet(durationMs: 13000, frames: frames);
          };
      SparkJoyIntakeUploadService.viewUrlOverride = (filename) async =>
          'https://s3.example/get/$filename';
      var aiCalls = 0;
      SparkJoyIntakeUploadService.aiChatOverride =
          ({required text, required cliche, required fileUrls}) async {
            aiCalls += 1;
            expect(fileUrls, hasLength(5));
            expect(text, contains('длительность=13000 мс'));
            final hash = RegExp(
              r'hash исходного видео=([a-f0-9]{64})',
            ).firstMatch(text)!.group(1)!;
            return '{"items":[{"hash":"$hash","section":"inspection",'
                '"documentKind":"","group":"body","element":"hood"}]}';
          };
      service.configureAi(
        draftId,
        const SparkIntakeAiConfig(
          cliche: 'photo {text}',
          videoCliche: 'video {text}',
          elementsByGroup: <String, Set<String>>{
            'body': <String>{'hood'},
          },
        ),
      );

      final video = await makeVideoRecord('walkaround');
      await service.stageFiles(draftId, [video]);
      expect(video.sha256, hasLength(64));
      expect(service.snapshotOf(draftId).total, 1);

      await service.startUpload(draftId);
      await _waitFor(() => transfer.enqueued.length == 5);
      expect(service.snapshotOf(draftId).total, 1);
      expect(
        transfer.enqueued.every((item) => item.mimeType == 'image/jpeg'),
        isTrue,
      );
      expect(
        transfer.enqueued.any((item) => item.filePath == video.localPath),
        isFalse,
        reason: 'оригинальное видео во временный S3 не отправляется',
      );

      for (var i = 0; i < 5; i++) {
        transfer.emitComplete(draftId, 'walkaround_frame_$i');
      }
      await _waitFor(() => aiCalls == 1);
      await _waitFor(
        () => service.snapshotOf(draftId).phase == SparkIntakePhase.classified,
      );

      final classified = service.snapshotOf(draftId).files.single;
      expect(classified.id, 'walkaround');
      expect(classified.videoDurationMs, 13000);
      expect(classified.videoFrameCount, 5);
      expect(classified.aiSection, SparkIntakeAiSection.inspection);
      expect(classified.aiGroup, 'body');
      expect(classified.aiElement, 'hood');

      final persisted = await persistedIntake();
      final persistedFiles = persisted!['files'] as List;
      expect(persistedFiles, hasLength(6));
      expect(
        persistedFiles.where(
          (raw) => (raw as Map)['sourceVideoId'] == 'walkaround',
        ),
        hasLength(5),
      );
    },
  );

  test('ИИ ждёт retry упавшего кадра видео и не ставит unknown', () async {
    SparkJoyIntakeUploadService.videoFrameExtractorOverride =
        ({
          required videoPath,
          required outputDirectory,
          required filePrefix,
        }) async {
          final frames = <SparkIntakeExtractedVideoFrame>[];
          for (var i = 0; i < 5; i++) {
            final file = File('$outputDirectory/${filePrefix}_$i.jpg');
            await file.writeAsBytes(List<int>.filled(32, i));
            frames.add(
              SparkIntakeExtractedVideoFrame(
                index: i,
                timeMs: 1000 + i * 2000,
                path: file.path,
                sizeBytes: 32,
              ),
            );
          }
          return SparkIntakeVideoFrameSet(durationMs: 13000, frames: frames);
        };
    SparkJoyIntakeUploadService.viewUrlOverride = (filename) async =>
        'https://s3.example/get/$filename';
    var aiCalls = 0;
    SparkJoyIntakeUploadService.aiChatOverride =
        ({required text, required cliche, required fileUrls}) async {
          aiCalls += 1;
          final hash = RegExp(
            r'hash исходного видео=([a-f0-9]{64})',
          ).firstMatch(text)!.group(1)!;
          return '{"items":[{"hash":"$hash","section":"inspection",'
              '"documentKind":"","group":"body","element":"hood"}]}';
        };
    service.configureAi(
      draftId,
      const SparkIntakeAiConfig(
        cliche: 'photo {text}',
        videoCliche: 'video {text}',
        elementsByGroup: <String, Set<String>>{
          'body': <String>{'hood'},
        },
      ),
    );

    final video = await makeVideoRecord('retry_video');
    await service.stageFiles(draftId, [video]);
    await service.startUpload(draftId);
    await _waitFor(() => transfer.enqueued.length == 5);
    for (var i = 0; i < 4; i++) {
      transfer.emitComplete(draftId, 'retry_video_frame_$i');
    }
    transfer.emitFailed(draftId, 'retry_video_frame_4');
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.failed,
    );
    expect(aiCalls, 0);
    expect(video.aiSection, isEmpty);

    await service.startUpload(draftId);
    await _waitFor(() => transfer.enqueued.length == 6);
    transfer.emitComplete(draftId, 'retry_video_frame_4');
    await _waitFor(() => aiCalls == 1);
    await _waitFor(
      () => service.snapshotOf(draftId).phase == SparkIntakePhase.classified,
    );
    expect(video.aiSection, SparkIntakeAiSection.inspection);
  });

  test(
    'СТС остаётся classifying до извлечения полей и затем идёт в materials',
    () async {
      final docScanResponse = Completer<String>();
      var aiCalls = 0;
      SparkJoyIntakeUploadService.viewUrlOverride = (filename) async =>
          'https://s3.example/get/$filename';
      SparkJoyIntakeUploadService.aiChatOverride =
          ({required text, required cliche, required fileUrls}) async {
            aiCalls += 1;
            if (aiCalls == 1) {
              final hash = RegExp(
                r'hash=([a-f0-9]{64})',
              ).firstMatch(text)!.group(1)!;
              return '{"items":[{"hash":"$hash","section":"materials",'
                  '"documentKind":"vehicle_doc","group":"","element":""}]}';
            }
            return docScanResponse.future;
          };
      service.configureAi(
        draftId,
        const SparkIntakeAiConfig(
          cliche: 'test {text}',
          elementsByGroup: <String, Set<String>>{},
        ),
      );
      final record = await makeImageRecord('sts');
      await service.stageFiles(draftId, [record]);
      await service.startUpload(draftId);
      await _waitFor(() => transfer.enqueued.length == 1);
      transfer.emitComplete(draftId, record.id);
      await _waitFor(() => aiCalls == 2);
      expect(service.snapshotOf(draftId).phase, SparkIntakePhase.classifying);

      docScanResponse.complete(
        '{"docType":"sts","vin":"XTA210990Y2765432",'
        '"gosNumber":"A123BC77","brand":"Lada","model":"2109",'
        '"year":"2000","color":"белый"}',
      );
      await _waitFor(
        () => service.snapshotOf(draftId).phase == SparkIntakePhase.classified,
      );
      final classified = service.snapshotOf(draftId).files.single;
      expect(classified.aiSection, SparkIntakeAiSection.materials);
      expect(classified.aiDocumentKind, SparkIntakeDocumentKind.vehicleDoc);
      expect(classified.aiDocJson, contains('XTA210990Y2765432'));
    },
  );
}

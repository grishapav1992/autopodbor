import 'package:flutter_application_1/data/services/spark_joy_intake_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SparkIntakeFileRecord JSON', () {
    test('round-trip сохраняет все поля', () {
      final record = SparkIntakeFileRecord(
        id: 'intake_1',
        name: 'Фото 1.jpg',
        originalName: 'image_picker_AABBCCDD.jpg',
        displayName: 'Фото 1.jpg',
        mimeType: 'image/jpeg',
        localPath: 'file:///docs/spark_joy_media/IMG_0001.jpg',
        sizeBytes: 12345,
        status: SparkIntakeFileStatus.uploaded,
        remoteName: 'intake_1_abc.jpg',
        s3Key: 'temp/intake_1_abc.jpg',
        uploadedAtIso: '2026-07-11T12:00:00.000',
        taskId: 'task_9',
        compressedPath: 'file:///docs/spark_joy_media/intake_c_1.jpg',
        videoThumbPath: null,
        error: null,
        sha256: List<String>.filled(64, 'a').join(),
        aiSection: 'inspection',
        aiDocumentKind: '',
        aiGroup: 'body',
        aiElement: 'hood',
        aiDocJson: '{"vin":"XTA210990Y2765432"}',
      );
      final restored = SparkIntakeFileRecord.tryFromJson(record.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, 'intake_1');
      expect(restored.name, 'Фото 1.jpg');
      expect(restored.originalName, 'image_picker_AABBCCDD.jpg');
      expect(restored.displayName, 'Фото 1.jpg');
      expect(restored.mimeType, 'image/jpeg');
      expect(restored.localPath, record.localPath);
      expect(restored.sizeBytes, 12345);
      expect(restored.status, SparkIntakeFileStatus.uploaded);
      expect(restored.remoteName, 'intake_1_abc.jpg');
      expect(restored.s3Key, 'temp/intake_1_abc.jpg');
      expect(restored.uploadedAtIso, '2026-07-11T12:00:00.000');
      expect(restored.taskId, 'task_9');
      expect(restored.compressedPath, record.compressedPath);
      expect(restored.sha256, record.sha256);
      expect(restored.aiSection, 'inspection');
      expect(restored.aiGroup, 'body');
      expect(restored.aiElement, 'hood');
      expect(restored.aiDocJson, contains('XTA210990Y2765432'));
    });

    test('round-trip сохраняет связь скрытого кадра с видео', () {
      final record = SparkIntakeFileRecord(
        id: 'video_1_frame_3',
        name: 'walkaround.mov · кадр 4',
        mimeType: 'image/jpeg',
        localPath: 'file:///docs/spark_joy_media/video_1_3.jpg',
        sizeBytes: 45678,
        sourceVideoId: 'video_1',
        videoFrameIndex: 3,
        videoFrameTimeMs: 9000,
        videoDurationMs: 13000,
        videoFrameCount: 5,
      );

      final restored = SparkIntakeFileRecord.tryFromJson(record.toJson())!;
      expect(restored.isInternalVideoFrame, isTrue);
      expect(restored.sourceVideoId, 'video_1');
      expect(restored.videoFrameIndex, 3);
      expect(restored.videoFrameTimeMs, 9000);
      expect(restored.videoDurationMs, 13000);
      expect(restored.videoFrameCount, 5);
    });

    test(
      'транзиентные статусы сериализуются как staged (kill = дозаливка)',
      () {
        for (final transient in [
          SparkIntakeFileStatus.compressing,
          SparkIntakeFileStatus.enqueued,
          SparkIntakeFileStatus.uploading,
        ]) {
          final record = SparkIntakeFileRecord(
            id: 'r',
            name: 'f',
            mimeType: 'image/jpeg',
            localPath: '/tmp/f.jpg',
            sizeBytes: 1,
            status: transient,
          );
          expect(
            record.toJson()['status'],
            SparkIntakeFileStatus.staged,
            reason: 'статус $transient должен персиститься как staged',
          );
        }
      },
    );

    test('терминальные статусы персистятся как есть', () {
      for (final terminal in [
        SparkIntakeFileStatus.uploaded,
        SparkIntakeFileStatus.failed,
      ]) {
        final record = SparkIntakeFileRecord(
          id: 'r',
          name: 'f',
          mimeType: 'image/jpeg',
          localPath: '/tmp/f.jpg',
          sizeBytes: 1,
          status: terminal,
        );
        expect(record.toJson()['status'], terminal);
      }
    });

    test('толерантный парс: мусор и неполные записи отбрасываются', () {
      expect(SparkIntakeFileRecord.tryFromJson('строка'), isNull);
      expect(SparkIntakeFileRecord.tryFromJson(42), isNull);
      expect(SparkIntakeFileRecord.tryFromJson(null), isNull);
      // Без id.
      expect(
        SparkIntakeFileRecord.tryFromJson({'localPath': '/tmp/f.jpg'}),
        isNull,
      );
      // Без localPath.
      expect(SparkIntakeFileRecord.tryFromJson({'id': 'x'}), isNull);
      // Неизвестный статус деградирует в staged.
      final weird = SparkIntakeFileRecord.tryFromJson({
        'id': 'x',
        'localPath': '/tmp/f.jpg',
        'status': 'скоро_взлетим',
        'sizeBytes': 'не число',
      });
      expect(weird, isNotNull);
      expect(weird!.status, SparkIntakeFileStatus.staged);
      expect(weird.sizeBytes, 0);
    });
  });

  group('sparkIntakeRemoteName', () {
    test('содержит случайный hex и не содержит путей', () {
      final a = sparkIntakeRemoteName(
        mimeType: 'image/jpeg',
        originalName: 'IMG_0001.jpg',
        compressed: true,
      );
      final b = sparkIntakeRemoteName(
        mimeType: 'image/jpeg',
        originalName: 'IMG_0001.jpg',
        compressed: true,
      );
      expect(a, isNot(equals(b)), reason: 'random-компонент обязателен');
      expect(a, matches(RegExp(r'^intake_\d+_[0-9a-f]{8}\.jpg$')));
      expect(a.contains('/'), isFalse);
      expect(a.contains(r'\'), isFalse);
    });

    test('сжатое фото всегда .jpg, остальное — по mime/имени', () {
      expect(
        sparkIntakeRemoteName(
          mimeType: 'image/heic',
          originalName: 'IMG.heic',
          compressed: true,
        ),
        endsWith('.jpg'),
      );
      expect(
        sparkIntakeRemoteName(
          mimeType: 'application/pdf',
          originalName: 'Диагностическая карта.pdf',
          compressed: false,
        ),
        endsWith('.pdf'),
      );
      expect(
        sparkIntakeRemoteName(
          mimeType: 'video/quicktime',
          originalName: 'clip.mov',
          compressed: false,
        ),
        endsWith('.mov'),
      );
      // Неизвестный mime → расширение из имени.
      expect(
        sparkIntakeRemoteName(
          mimeType: 'application/x-unknown',
          originalName: 'файл.docx',
          compressed: false,
        ),
        endsWith('.docx'),
      );
      // Ни mime, ни расширения → .bin; путь в имени не протекает.
      expect(
        sparkIntakeRemoteName(
          mimeType: 'application/x-unknown',
          originalName: '/etc/passwd',
          compressed: false,
        ),
        endsWith('.bin'),
      );
    });
  });

  group('подписи', () {
    test('русские плюралы файлов', () {
      expect(sparkIntakeFilesCountLabel(1), '1 файл');
      expect(sparkIntakeFilesCountLabel(2), '2 файла');
      expect(sparkIntakeFilesCountLabel(4), '4 файла');
      expect(sparkIntakeFilesCountLabel(5), '5 файлов');
      expect(sparkIntakeFilesCountLabel(11), '11 файлов');
      expect(sparkIntakeFilesCountLabel(12), '12 файлов');
      expect(sparkIntakeFilesCountLabel(21), '21 файл');
      expect(sparkIntakeFilesCountLabel(104), '104 файла');
    });

    test('размер файла с десятичной запятой', () {
      expect(sparkIntakeSizeLabel(0), '');
      expect(sparkIntakeSizeLabel(512), '512 Б');
      expect(sparkIntakeSizeLabel(640 * 1024), '640 КБ');
      expect(sparkIntakeSizeLabel((1.2 * 1024 * 1024).round()), '1,2 МБ');
      expect(sparkIntakeSizeLabel(2 * 1024 * 1024), '2 МБ');
    });
  });
}

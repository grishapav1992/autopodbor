import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_file_names.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_create_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sparkJoyUserFacingPickedName', () {
    test('preserves a real original filename', () {
      expect(
        sparkJoyUserFacingPickedName(
          rawName: 'STS owner Ivanov.JPG',
          mimeType: 'image/jpeg',
          pickedAt: DateTime(2026, 7, 12, 15, 4, 9),
        ),
        'STS owner Ivanov.JPG',
      );
    });

    test('replaces an iOS image_picker transport name', () {
      expect(
        sparkJoyUserFacingPickedName(
          rawName: 'image_picker_4F3A51F3-EF24-4311-BBDA-A1B2C3D4E5F6.jpg',
          mimeType: 'image/jpeg',
          pickedAt: DateTime(2026, 7, 12, 15, 4, 9),
        ),
        'Фото 12.07.2026 15-04-09.jpg',
      );
    });

    test('adds a sequence suffix for a multi-selection', () {
      expect(
        sparkJoyUserFacingPickedName(
          rawName: 'video_picker_4F3A51F3-EF24-4311-BBDA-A1B2C3D4E5F6.mov',
          mimeType: 'video/quicktime',
          pickedAt: DateTime(2026, 7, 12, 15, 4, 9),
          sequence: 2,
        ),
        'Видео 12.07.2026 15-04-09 3.mov',
      );
    });
  });

  test('legacy drafts get a readable presentation name', () {
    expect(
      sparkJoyReadableStoredName(
        rawName: 'image_picker_4F3A51F3-EF24-4311-BBDA-A1B2C3D4E5F6.jpg',
        mimeType: 'image/jpeg',
        ordinal: 1,
      ),
      'Фото 2.jpg',
    );
  });

  test('display name removes path, control and bidi spoofing characters', () {
    expect(
      sparkJoySafeDisplayName('/tmp/invoice\u202Efdp.jpg\u0000'),
      'invoicefdp.jpg',
    );
  });

  test('picker MIME wins over a missing filename extension', () {
    expect(
      sparkJoyPreferredPickerMimeType(
        declaredMimeType: 'IMAGE/JPEG',
        fallbackMimeType: 'application/octet-stream',
      ),
      'image/jpeg',
    );
    expect(
      sparkJoyPreferredPickerMimeType(
        declaredMimeType: 'application/octet-stream',
        fallbackMimeType: 'video/quicktime',
      ),
      'video/quicktime',
    );
  });

  test('uploaded item keeps original, display and remote names separately', () {
    const item = UploadedItem(
      id: 'file-1',
      name: 'Фото 1.jpg',
      originalName: 'image_picker_AABBCCDD.jpg',
      displayName: 'Фото 1.jpg',
      remoteName: 'legal_file_file-1.jpg',
      mimeType: 'image/jpeg',
      dataUrl: 'file:///tmp/photo.jpg',
    );
    expect(item.originalName, 'image_picker_AABBCCDD.jpg');
    expect(item.displayName, 'Фото 1.jpg');
    expect(item.remoteName, 'legal_file_file-1.jpg');
    expect(item.copyWith().originalName, item.originalName);
  });
}

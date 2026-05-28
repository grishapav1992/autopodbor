import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_upload_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Spark Joy media identity', () {
    test('edit target matches by primary item id, not shared dataUrl', () {
      const sharedSource = 'file:///tmp/trunk.jpg';
      const targetRef = 'photo_2';

      expect(
        sparkJoyMediaTargetMatches(
          targetRef: targetRef,
          itemId: 'photo_1',
          dataUrl: sharedSource,
        ),
        isFalse,
      );
      expect(
        sparkJoyMediaTargetMatches(
          targetRef: targetRef,
          itemId: 'photo_2',
          dataUrl: sharedSource,
        ),
        isTrue,
      );
    });

    test('all refs still include dataUrl for legacy draft tag lookup', () {
      expect(
        sparkJoyMediaAllRefs(itemId: 'photo_1', dataUrl: 'file:///a.jpg'),
        containsAll(<String>['photo_1', 'file:///a.jpg']),
      );
    });
  });

  group('Spark Joy upload filenames', () {
    test('same source in different contexts gets different server filenames', () {
      final inspection = sparkJoyUploadFilename(
        contextPrefix: 'inspection_media',
        itemId: 'same_id',
        originalName: 'photo.jpg',
        fallbackExtension: 'jpg',
        index: 0,
      );
      final legal = sparkJoyUploadFilename(
        contextPrefix: 'legal_file',
        itemId: 'same_id',
        originalName: 'photo.jpg',
        fallbackExtension: 'jpg',
        index: 0,
      );

      expect(inspection, isNot(legal));
      expect(inspection, startsWith('inspection_media_'));
      expect(legal, startsWith('legal_file_'));
    });

    test('upload state key is filename based', () {
      expect(
        sparkJoyUploadStateKey(
          filename: 'inspection_media_photo_1_photo.jpg',
          source: 'file:///tmp/photo.jpg',
          itemId: 'photo_1',
          index: 0,
        ),
        'filename:inspection_media_photo_1_photo.jpg',
      );
    });
  });
}

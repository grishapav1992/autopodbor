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

  group('Spark Joy video poster filename', () {
    test('appends .thumb.jpg to the video upload filename', () {
      expect(
        sparkJoyVideoPosterFilename('inspection_media_video_1_clip.mov'),
        'inspection_media_video_1_clip.mov.thumb.jpg',
      );
    });

    test('upload side and view side derive the same poster key', () {
      // The whole feature hinges on both sides computing the SAME name from the
      // video filename the server echoes back. This guards that contract.
      final videoFilename = sparkJoyUploadFilename(
        contextPrefix: 'inspection_media',
        itemId: 'vid_42',
        originalName: 'walkaround.mp4',
        fallbackExtension: 'mp4',
        index: 3,
      );
      final uploadSide = sparkJoyVideoPosterFilename(videoFilename);
      final viewSide = sparkJoyVideoPosterFilename(videoFilename);
      expect(uploadSide, viewSide);
      expect(uploadSide, endsWith('.thumb.jpg'));
      expect(uploadSide, startsWith(videoFilename));
    });

    test('empty / whitespace filename yields empty poster name', () {
      expect(sparkJoyVideoPosterFilename(''), '');
      expect(sparkJoyVideoPosterFilename('   '), '');
    });
  });
}

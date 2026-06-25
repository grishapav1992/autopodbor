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
    test('strips the extension before appending .thumb.jpg', () {
      expect(
        sparkJoyVideoPosterFilename('inspection_media_video_1_clip.mov'),
        'inspection_media_video_1_clip.thumb.jpg',
      );
    });

    test('upload (.mov) and view (.m3u8) derive the SAME poster key', () {
      // The bug this guards: the backend transcodes the uploaded video to HLS
      // and swaps its extension (.mov → .m3u8) while keeping the base. The
      // poster is uploaded under the .mov name but the viewer derives from the
      // .m3u8 name — they must still resolve to one key. Stripping the
      // extension is what makes that hold.
      const base = 'inspection_media_vid_42_walkaround';
      final uploadSide = sparkJoyVideoPosterFilename('$base.mov');
      final viewSide = sparkJoyVideoPosterFilename('$base.m3u8');
      expect(uploadSide, '$base.thumb.jpg');
      expect(viewSide, uploadSide);
    });

    test('extension-agnostic across .mp4 / .mov / .m3u8 / uppercase', () {
      const base = 'inspection_media_vid_7_IMG_7061';
      final expected = '$base.thumb.jpg';
      for (final ext in ['mp4', 'mov', 'MOV', 'm3u8', 'webm', 'm4v']) {
        expect(sparkJoyVideoPosterFilename('$base.$ext'), expected);
      }
    });

    test('real upload filename round-trips through the helper', () {
      final videoFilename = sparkJoyUploadFilename(
        contextPrefix: 'inspection_media',
        itemId: 'vid_42',
        originalName: 'walkaround.mp4',
        fallbackExtension: 'mp4',
        index: 3,
      );
      final poster = sparkJoyVideoPosterFilename(videoFilename);
      expect(poster, endsWith('.thumb.jpg'));
      // base preserved, only the trailing extension dropped
      final base = videoFilename.substring(0, videoFilename.lastIndexOf('.'));
      expect(poster, '$base.thumb.jpg');
    });

    test('no-extension name keeps the full base', () {
      expect(sparkJoyVideoPosterFilename('plainname'), 'plainname.thumb.jpg');
    });

    test('empty / whitespace filename yields empty poster name', () {
      expect(sparkJoyVideoPosterFilename(''), '');
      expect(sparkJoyVideoPosterFilename('   '), '');
    });
  });
}

import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_comment_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SparkJoyCommentUtils.isLikelyAudioFileName', () {
    test('accepts supported audio extensions', () {
      expect(SparkJoyCommentUtils.isLikelyAudioFileName('voice.wav'), isTrue);
      expect(SparkJoyCommentUtils.isLikelyAudioFileName('voice.MP3'), isTrue);
      expect(SparkJoyCommentUtils.isLikelyAudioFileName('voice_note.m4a'), isTrue);
      expect(SparkJoyCommentUtils.isLikelyAudioFileName('sample.ogg'), isTrue);
      expect(SparkJoyCommentUtils.isLikelyAudioFileName('rec.caf'), isTrue);
    });

    test('rejects non-audio names', () {
      expect(SparkJoyCommentUtils.isLikelyAudioFileName('photo.jpg'), isFalse);
      expect(SparkJoyCommentUtils.isLikelyAudioFileName('video.mp4'), isFalse);
      expect(SparkJoyCommentUtils.isLikelyAudioFileName(''), isFalse);
    });
  });

  group('SparkJoyCommentUtils.appendRecognizedTranscript', () {
    test('appends transcript to empty previous text', () {
      final next = SparkJoyCommentUtils.appendRecognizedTranscript(
        previous: '',
        transcript: 'Проверка завершена',
      );
      expect(next, 'Проверка завершена');
    });

    test('adds separator when needed', () {
      final next = SparkJoyCommentUtils.appendRecognizedTranscript(
        previous: 'Есть скол',
        transcript: 'на переднем крыле',
      );
      expect(next, 'Есть скол на переднем крыле');
    });

    test('returns original previous when transcript is empty', () {
      final next = SparkJoyCommentUtils.appendRecognizedTranscript(
        previous: 'Без изменений',
        transcript: '   ',
      );
      expect(next, 'Без изменений');
    });
  });

  group('SparkJoyCommentUtils.recordingDurationLabel', () {
    test('formats duration as mm:ss', () {
      expect(SparkJoyCommentUtils.recordingDurationLabel(0), '00:00');
      expect(SparkJoyCommentUtils.recordingDurationLabel(5), '00:05');
      expect(SparkJoyCommentUtils.recordingDurationLabel(65), '01:05');
    });

    test('clamps negative duration to zero', () {
      expect(SparkJoyCommentUtils.recordingDurationLabel(-10), '00:00');
    });
  });
}

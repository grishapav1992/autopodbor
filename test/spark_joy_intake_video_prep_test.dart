import 'package:flutter_application_1/data/services/spark_joy_intake_video_prep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('video frame sampling', () {
    test('13 секунд → 5 кадров', () {
      final times = sparkIntakeVideoFrameTimesMs(const Duration(seconds: 13));
      expect(times, hasLength(5));
      expect(times.first, 650);
      expect(times.last, 12350);
    });

    test('240 секунд → 10 кадров', () {
      final times = sparkIntakeVideoFrameTimesMs(const Duration(seconds: 240));
      expect(times, hasLength(10));
      expect(times.first, 12000);
      expect(times.last, 228000);
    });

    test('среднее видео получает 7 кадров, timestamps строго возрастают', () {
      final times = sparkIntakeVideoFrameTimesMs(const Duration(seconds: 90));
      expect(times, hasLength(7));
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]));
      }
    });

    test('нулевая длительность не создаёт кадров', () {
      expect(sparkIntakeVideoFrameTimesMs(Duration.zero), isEmpty);
    });
  });
}

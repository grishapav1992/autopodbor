import 'dart:io';

import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

const int kIntakeVideoMinFrames = 5;
const int kIntakeVideoMediumFrames = 7;
const int kIntakeVideoMaxFrames = 10;
const int kIntakeVideoFrameMaxSide = 1280;
const int kIntakeVideoFrameJpegQuality = 76;

/// Cost-bounded sampling policy. Short clips still get enough viewpoints to
/// disambiguate a body element; long clips are capped at ten vision images.
int sparkIntakeVideoFrameCount(Duration duration) {
  final seconds = duration.inMilliseconds / 1000;
  if (seconds <= 30) return kIntakeVideoMinFrames;
  if (seconds <= 120) return kIntakeVideoMediumFrames;
  return kIntakeVideoMaxFrames;
}

/// Uniform timestamps excluding the first/last 5%, which are commonly black,
/// blurred, or contain the camera-start/stop gesture.
List<int> sparkIntakeVideoFrameTimesMs(Duration duration) {
  final durationMs = duration.inMilliseconds;
  if (durationMs <= 0) return const <int>[];
  final count = sparkIntakeVideoFrameCount(duration);
  if (count == 1) return <int>[durationMs ~/ 2];
  return List<int>.generate(count, (index) {
    final ratio = 0.05 + (0.90 * index / (count - 1));
    return (durationMs * ratio).round().clamp(0, durationMs - 1);
  }, growable: false);
}

class SparkIntakeExtractedVideoFrame {
  const SparkIntakeExtractedVideoFrame({
    required this.index,
    required this.timeMs,
    required this.path,
    required this.sizeBytes,
  });

  final int index;
  final int timeMs;
  final String path;
  final int sizeBytes;
}

class SparkIntakeVideoFrameSet {
  const SparkIntakeVideoFrameSet({
    required this.durationMs,
    required this.frames,
  });

  final int durationMs;
  final List<SparkIntakeExtractedVideoFrame> frames;
}

/// Extracts JPEG frames sequentially. Native decoders must stay on the main
/// isolate, while sequential processing bounds decoder memory on older iOS
/// devices. The original video is never modified.
Future<SparkIntakeVideoFrameSet> sparkExtractIntakeVideoFrames({
  required String videoPath,
  required String outputDirectory,
  required String filePrefix,
}) async {
  final controller = VideoPlayerController.file(File(videoPath));
  late final Duration duration;
  try {
    await controller.initialize().timeout(const Duration(seconds: 30));
    duration = controller.value.duration;
  } finally {
    await controller.dispose();
  }

  final generatedFiles = <File>[];
  try {
    final times = sparkIntakeVideoFrameTimesMs(duration);
    if (times.isEmpty) {
      throw const FormatException('Не удалось определить длительность видео');
    }

    final directory = Directory(outputDirectory);
    if (!await directory.exists()) await directory.create(recursive: true);
    final frames = <SparkIntakeExtractedVideoFrame>[];
    for (var index = 0; index < times.length; index++) {
      final outputPath = '$outputDirectory/${filePrefix}_$index.jpg';
      final generated = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: outputPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: kIntakeVideoFrameMaxSide,
        maxHeight: kIntakeVideoFrameMaxSide,
        timeMs: times[index],
        quality: kIntakeVideoFrameJpegQuality,
      ).timeout(const Duration(seconds: 30));
      if (generated == null || generated.isEmpty) {
        throw FormatException('Не удалось извлечь кадр ${index + 1}');
      }
      final file = File(generated);
      if (!await file.exists()) {
        throw FormatException('Кадр ${index + 1} не сохранён');
      }
      generatedFiles.add(file);
      frames.add(
        SparkIntakeExtractedVideoFrame(
          index: index,
          timeMs: times[index],
          path: generated,
          sizeBytes: await file.length(),
        ),
      );
    }
    return SparkIntakeVideoFrameSet(
      durationMs: duration.inMilliseconds,
      frames: List<SparkIntakeExtractedVideoFrame>.unmodifiable(frames),
    );
  } catch (_) {
    for (final file in generatedFiles) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    rethrow;
  }
}

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class SparkJoyPickedMediaFile {
  const SparkJoyPickedMediaFile({
    required this.name,
    this.path,
    this.bytes,
    this.mimeType,
  });

  final String name;
  final String? path;
  final Uint8List? bytes;
  final String? mimeType;
}

abstract class SparkJoyCommentAudioPickerPort {
  Future<List<SparkJoyPickedMediaFile>> pickCommentAudioFiles({
    required bool isMobileNative,
  });
}

class SparkJoyPluginCommentAudioPickerPort
    implements SparkJoyCommentAudioPickerPort {
  const SparkJoyPluginCommentAudioPickerPort();

  @override
  Future<List<SparkJoyPickedMediaFile>> pickCommentAudioFiles({
    required bool isMobileNative,
  }) async {
    final allowedAudioExtensions = <String>[
      'wav',
      'mp3',
      'm4a',
      'aac',
      'ogg',
      'oga',
      'webm',
      'caf',
      'flac',
      'aiff',
      'amr',
    ];
    final result = await FilePicker.platform.pickFiles(
      // Всегда открываем файловый браузер (Files/папки), чтобы не уводить в медиатеку.
      type: FileType.custom,
      allowedExtensions: allowedAudioExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return const [];
    return result.files
        .map(
          (file) => SparkJoyPickedMediaFile(
            name: file.name,
            path: file.path,
            bytes: file.bytes,
          ),
        )
        .toList();
  }
}

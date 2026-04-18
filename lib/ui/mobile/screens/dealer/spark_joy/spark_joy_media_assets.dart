part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaAssets on _SparkJoyCreateReportScreenState {
  MediaPartInspection _deriveGroupPartInspection({
    required List<UploadedItem> files,
    String fallbackNote = '',
  }) {
    final normalizedTags = <String, String>{};
    final tagPhotos = <String, List<String>>{};
    final audio = <String>[];
    String? elementType;
    String note = fallbackNote.trim();
    bool anyNoDamage = false;
    bool hasSavedInspection = false;
    double? paintFrom;
    double? paintTo;

    for (final file in files) {
      final inspection = file.inspection;
      if (!inspection.isDraft) {
        hasSavedInspection = true;
      }
      if (inspection.noDamage) {
        anyNoDamage = true;
      }

      final normalizedElement = (inspection.elementType ?? '').trim();
      if (elementType == null && normalizedElement.isNotEmpty) {
        elementType = normalizedElement;
      }
      if (note.isEmpty && inspection.note.trim().isNotEmpty) {
        note = inspection.note.trim();
      }
      if (paintFrom == null &&
          paintTo == null &&
          inspection.paintFrom != null &&
          inspection.paintTo != null) {
        paintFrom = inspection.paintFrom;
        paintTo = inspection.paintTo;
      }

      for (final audioUrl in inspection.audioRecordings) {
        final normalized = audioUrl.trim();
        if (normalized.isEmpty) continue;
        if (!audio.contains(normalized)) {
          audio.add(normalized);
        }
      }

      for (final rawTag in inspection.tags) {
        final tag = rawTag.trim();
        if (tag.isEmpty) continue;
        final marker = tag.toLowerCase();
        final canonical = normalizedTags.putIfAbsent(marker, () => tag);
        final list = tagPhotos.putIfAbsent(canonical, () => <String>[]);
        if (!list.contains(file.dataUrl)) {
          list.add(file.dataUrl);
        }
      }
    }

    final tags = normalizedTags.values.toList();
    final noDamage = tags.isEmpty && anyNoDamage;

    return MediaPartInspection(
      noDamage: noDamage,
      tags: tags,
      note: note,
      elementType: elementType,
      audioRecordings: audio,
      paintFrom: paintFrom,
      paintTo: paintTo,
      tagPhotos: tagPhotos,
      isDraft: !hasSavedInspection,
    );
  }

  MediaPartInspection _syncPartInspectionWithFiles({
    required MediaPartInspection partInspection,
    required List<UploadedItem> files,
    String fallbackNote = '',
  }) {
    if (files.isEmpty) return const MediaPartInspection();
    if (_mediaPartInspectionIsEmpty(partInspection)) {
      return _deriveGroupPartInspection(
        files: files,
        fallbackNote: fallbackNote,
      );
    }

    final existingUrls = files.map((file) => file.dataUrl).toSet();
    final canonicalByLower = <String, String>{};
    final tagPhotosByLower = <String, Set<String>>{};

    for (final rawTag in partInspection.tags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) continue;
      canonicalByLower.putIfAbsent(tag.toLowerCase(), () => tag);
    }

    for (final entry in partInspection.tagPhotos.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      canonicalByLower.putIfAbsent(lower, () => tag);
      final urls = tagPhotosByLower.putIfAbsent(lower, () => <String>{});
      for (final rawUrl in entry.value) {
        final url = rawUrl.trim();
        if (url.isEmpty || !existingUrls.contains(url)) continue;
        urls.add(url);
      }
    }

    final tags = <String>[];
    for (final entry in canonicalByLower.entries) {
      tags.add(entry.value);
    }

    if (partInspection.noDamage) {
      return MediaPartInspection(
        noDamage: true,
        tags: const [],
        note: partInspection.note.trim().isEmpty
            ? fallbackNote.trim()
            : partInspection.note.trim(),
        elementType: (partInspection.elementType ?? '').trim().isEmpty
            ? null
            : partInspection.elementType,
        audioRecordings: [...partInspection.audioRecordings],
        paintFrom: partInspection.paintFrom,
        paintTo: partInspection.paintTo,
        tagPhotos: const {},
        isDraft: partInspection.isDraft,
      );
    }

    final tagPhotos = <String, List<String>>{};
    for (final entry in canonicalByLower.entries) {
      final urls = tagPhotosByLower[entry.key] ?? <String>{};
      if (urls.isNotEmpty) {
        tagPhotos[entry.value] = urls.toList();
      }
    }

    return MediaPartInspection(
      noDamage: false,
      tags: tags,
      note: partInspection.note.trim().isEmpty
          ? fallbackNote.trim()
          : partInspection.note.trim(),
      elementType: (partInspection.elementType ?? '').trim().isEmpty
          ? null
          : partInspection.elementType,
      audioRecordings: [...partInspection.audioRecordings],
      paintFrom: partInspection.paintFrom,
      paintTo: partInspection.paintTo,
      tagPhotos: tagPhotos,
      isDraft: partInspection.isDraft,
    );
  }

  List<UploadedItem> _applyPartInspectionToFiles({
    required List<UploadedItem> files,
    required MediaPartInspection partInspection,
    Set<String>? applyToFileUrls,
  }) {
    if (files.isEmpty) return const <UploadedItem>[];
    final normalizedTargetUrls = applyToFileUrls
        ?.map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    final applyToAll =
        normalizedTargetUrls == null || normalizedTargetUrls.isEmpty;
    final urlsByTagLower = <String, Set<String>>{};
    final canonicalTagByLower = <String, String>{};

    for (final rawTag in partInspection.tags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) continue;
      canonicalTagByLower.putIfAbsent(tag.toLowerCase(), () => tag);
    }
    for (final entry in partInspection.tagPhotos.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      canonicalTagByLower.putIfAbsent(lower, () => tag);
      final urls = urlsByTagLower.putIfAbsent(lower, () => <String>{});
      for (final rawUrl in entry.value) {
        final url = rawUrl.trim();
        if (url.isEmpty) continue;
        urls.add(url);
      }
    }

    final orderedTagLowers = canonicalTagByLower.keys.toList();
    final normalizedElementType = (partInspection.elementType ?? '').trim();
    final normalizedAudio = partInspection.audioRecordings
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final normalizedNote = partInspection.note.trim();

    return files.map((file) {
      final applyForFile =
          applyToAll || normalizedTargetUrls.contains(file.dataUrl);
      final tagsForFile = <String>[];
      if (!partInspection.noDamage) {
        for (final lower in orderedTagLowers) {
          final urls = urlsByTagLower[lower] ?? <String>{};
          if (urls.contains(file.dataUrl)) {
            tagsForFile.add(canonicalTagByLower[lower]!);
          }
        }
      }
      final previous = file.inspection;
      final nextNoDamage = tagsForFile.isEmpty
          ? (applyForFile ? partInspection.noDamage : previous.noDamage)
          : false;
      final inspection = MediaInspection(
        noDamage: nextNoDamage,
        tags: tagsForFile,
        note: applyForFile ? normalizedNote : previous.note,
        elementType: applyForFile
            ? (normalizedElementType.isEmpty ? null : normalizedElementType)
            : previous.elementType,
        audioRecordings: applyForFile
            ? normalizedAudio
            : [...previous.audioRecordings],
        paintFrom: applyForFile ? partInspection.paintFrom : previous.paintFrom,
        paintTo: applyForFile ? partInspection.paintTo : previous.paintTo,
        isDraft: applyForFile ? partInspection.isDraft : previous.isDraft,
      );
      return file.copyWith(inspection: inspection);
    }).toList();
  }

  List<Map<String, dynamic>> _uploadedToJson(List<UploadedItem> items) {
    return items.map((e) {
      return {
        'id': e.id,
        'name': e.name,
        'mimeType': e.mimeType,
        'dataUrl': e.dataUrl,
        'inspection': e.inspection.toJson(),
      };
    }).toList();
  }

  String _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    return 'application/octet-stream';
  }

  Uint8List? _decodeDataUrlImageBytes(String dataUrl) {
    if (!_isDataUrl(dataUrl)) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= dataUrl.length - 1) return null;
    final header = dataUrl.substring(0, commaIndex).toLowerCase();
    if (!header.contains('image/') || !header.contains(';base64')) return null;
    final cached = _dataUrlImageBytesCache[dataUrl];
    if (cached != null) return cached;
    final payload = dataUrl.substring(commaIndex + 1);
    try {
      final decoded = base64Decode(payload);
      _dataUrlImageBytesCache[dataUrl] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadImageBytesFromSource(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) return null;
    if (_isDataUrl(normalized)) {
      final cached = _dataUrlImageBytesCache[normalized];
      if (cached != null) return cached;
    }

    final fromDataUrl = _decodeDataUrlImageBytes(normalized);
    if (fromDataUrl != null) return fromDataUrl;

    final localPath = _extractLocalMediaPath(normalized);
    if (localPath == null) return null;
    try {
      final bytes = await XFile(localPath).readAsBytes();
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Widget _uploadedImageWidget(
    UploadedItem item, {
    BoxFit fit = BoxFit.cover,
    Color errorColor = kGreyColor,
    double errorSize = 28,
    int? cacheWidth,
    int? cacheHeight,
    FilterQuality filterQuality = FilterQuality.low,
  }) {
    final source = item.dataUrl.trim();
    final bytes = _decodeDataUrlImageBytes(source);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: filterQuality,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image_outlined,
          color: errorColor,
          size: errorSize,
        ),
      );
    }

    final localPath = _extractLocalMediaPath(source);
    if (localPath != null) {
      return FutureBuilder<Uint8List?>(
        future: _loadImageBytesFromSource(source),
        builder: (context, snapshot) {
          final localBytes = snapshot.data;
          if (localBytes == null) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Icon(
                Icons.broken_image_outlined,
                color: errorColor,
                size: errorSize,
              );
            }
            return const Center(
              child: SizedBox(
                width: SparkSize.spinner,
                height: SparkSize.spinner,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Image.memory(
            localBytes,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: filterQuality,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.broken_image_outlined,
              color: errorColor,
              size: errorSize,
            ),
          );
        },
      );
    }

    return Image.network(
      source,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.broken_image_outlined, color: errorColor, size: errorSize),
    );
  }

  Widget _uploadedMediaThumbWidget(
    UploadedItem item, {
    BoxFit fit = BoxFit.cover,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    if (item.isImage) {
      return _uploadedImageWidget(
        item,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    }
    if (item.isVideo) {
      return _SparkJoyVideoThumbnail(
        uri: _mediaSourceUri(item.dataUrl),
        fit: fit,
      );
    }
    return const Icon(Icons.insert_drive_file_outlined, color: kGreyColor);
  }
}

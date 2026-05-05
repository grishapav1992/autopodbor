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

    final tagPhotos = <String, List<String>>{};
    for (final entry in canonicalByLower.entries) {
      final urls = tagPhotosByLower[entry.key] ?? <String>{};
      if (urls.isNotEmpty) {
        tagPhotos[entry.value] = urls.toList();
      }
    }

    // Group-level noDamage is now an aggregate of per-file states:
    // true only when EVERY file in the group is marked no-damage. The
    // editor's `partInspection.noDamage` reflects the target file's
    // local toggle (already applied to that file by the caller via
    // `_applyPartInspectionToFiles`), so the aggregate read here is
    // the source of truth for the group. Files with no inspection at
    // all (fresh additions before any edit) are skipped — they don't
    // contribute either way to the «вся часть без повреждений» state.
    final inspectedFiles = files
        .where((file) => _mediaInspectionHasData(file.inspection))
        .toList();
    final aggregateNoDamage = inspectedFiles.isNotEmpty &&
        inspectedFiles.every((file) => file.inspection.noDamage);

    final filteredTags = aggregateNoDamage ? const <String>[] : tags;
    final filteredTagPhotos =
        aggregateNoDamage ? const <String, List<String>>{} : tagPhotos;

    return MediaPartInspection(
      noDamage: aggregateNoDamage,
      tags: filteredTags,
      note: partInspection.note.trim().isEmpty
          ? fallbackNote.trim()
          : partInspection.note.trim(),
      elementType: (partInspection.elementType ?? '').trim().isEmpty
          ? null
          : partInspection.elementType,
      audioRecordings: [...partInspection.audioRecordings],
      paintFrom: partInspection.paintFrom,
      paintTo: partInspection.paintTo,
      tagPhotos: filteredTagPhotos,
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
      // Tag list per file is always derived by URL filter: a file gets
      // a tag iff its URL is in that tag's URL set (group-level
      // tagPhotos mapping). Previously this was gated by
      // `!partInspection.noDamage`, which wiped tags for ALL files
      // (including non-target ones) whenever the editor saved a
      // no-damage toggle for one photo. With per-item noDamage the
      // editor strips only the target's URL from non-selected tags,
      // so the URL filter naturally produces [] for the target while
      // preserving non-target file tags.
      final tagsForFile = <String>[];
      for (final lower in orderedTagLowers) {
        final urls = urlsByTagLower[lower] ?? <String>{};
        if (urls.contains(file.dataUrl)) {
          tagsForFile.add(canonicalTagByLower[lower]!);
        }
      }
      final previous = file.inspection;
      // noDamage is now per-item: only an EXPLICIT per-file edit
      // (applyToFileUrls non-empty AND this file is targeted) picks
      // up the editor's toggle. Apply-to-all calls (delete/add path)
      // keep each file's previous noDamage untouched. Files that
      // ended up with tags get noDamage forced to false to preserve
      // the invariant «tagged file ≠ no-damage».
      final isExplicitEdit = !applyToAll && applyForFile;
      final nextNoDamage = tagsForFile.isNotEmpty
          ? false
          : (isExplicitEdit
              ? partInspection.noDamage
              : previous.noDamage);
      // Per-item semantics: same `isExplicitEdit` gate as noDamage.
      // Delete / add code paths call us with `applyToFileUrls=null`
      // (= applyToAll), and previously that overwrote every file's
      // per-item state (note / elementType / paint / audio / isDraft)
      // with the group-level partInspection. After the per-item-note
      // fix landed earlier, that overwrite became user-visible — e.g.
      // deleting one photo would replace the surviving photos' notes
      // with the last-edited note. Now apply-to-all only refreshes
      // tag URL associations and leaves per-item fields untouched.
      final inspection = MediaInspection(
        noDamage: nextNoDamage,
        tags: tagsForFile,
        note: isExplicitEdit ? normalizedNote : previous.note,
        elementType: isExplicitEdit
            ? (normalizedElementType.isEmpty ? null : normalizedElementType)
            : previous.elementType,
        audioRecordings: isExplicitEdit
            ? normalizedAudio
            : [...previous.audioRecordings],
        paintFrom: isExplicitEdit
            ? partInspection.paintFrom
            : previous.paintFrom,
        paintTo: isExplicitEdit
            ? partInspection.paintTo
            : previous.paintTo,
        isDraft: isExplicitEdit ? partInspection.isDraft : previous.isDraft,
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
    // When both cacheWidth AND cacheHeight are non-null, Flutter
    // decodes the image into *exactly* those dimensions — aspect
    // ratio is forced to cacheWidth/cacheHeight regardless of the
    // source. Downstream BoxFit.cover then paints that already
    // distorted square onto the tile, which is what users were
    // seeing as "мини фото растягивается". Prefer a single
    // dimension so Flutter rescales the other axis proportionally;
    // keep the tighter of the two so memory stays bounded.
    final (int? decodeWidth, int? decodeHeight) = (cacheWidth != null &&
            cacheHeight != null)
        ? (cacheWidth <= cacheHeight ? (cacheWidth, null) : (null, cacheHeight))
        : (cacheWidth, cacheHeight);

    final source = item.dataUrl.trim();
    final bytes = _decodeDataUrlImageBytes(source);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        cacheWidth: decodeWidth,
        cacheHeight: decodeHeight,
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
            cacheWidth: decodeWidth,
            cacheHeight: decodeHeight,
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

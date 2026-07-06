part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaAssets on _SparkJoyCreateReportScreenState {
  String _mediaItemRef(UploadedItem file) {
    return sparkJoyMediaPrimaryRef(itemId: file.id, dataUrl: file.dataUrl);
  }

  Set<String> _mediaItemRefs(UploadedItem file) {
    return sparkJoyMediaAllRefs(itemId: file.id, dataUrl: file.dataUrl);
  }

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
        final ref = _mediaItemRef(file);
        if (ref.isNotEmpty && !list.contains(ref)) {
          list.add(ref);
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
    // True for the add/delete-media paths, where `partInspection` is the
    // stale cached group inspection (not a fresh editor edit). Then the group
    // note must come from the FILES, never from the stale group value or the
    // stale `fallbackNote` — otherwise deleting the photo that carried a note
    // leaves the group note resurrected (B16, delete/add paths).
    bool deriveNoteFromFiles = false,
  }) {
    if (files.isEmpty) return const MediaPartInspection();
    if (_mediaPartInspectionIsEmpty(partInspection)) {
      return _deriveGroupPartInspection(
        files: files,
        fallbackNote: deriveNoteFromFiles ? '' : fallbackNote,
      );
    }

    final existingRefs = <String>{};
    for (final file in files) {
      existingRefs.addAll(_mediaItemRefs(file));
    }
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
        if (url.isEmpty || !existingRefs.contains(url)) continue;
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

    // Group-level noDamage is a STRICT aggregate of per-file states:
    // true only when EVERY file in the group has noDamage=true. The
    // editor's `partInspection.noDamage` reflects the target file's
    // local toggle (already applied to that file by the caller via
    // `_applyPartInspectionToFiles`), so this read is the source of
    // truth for the group.
    //
    // Note: untouched / freshly added files default to noDamage=false,
    // so adding a new photo to a previously-no-damage group resets
    // the aggregate to false. That's intentional — claiming «вся
    // часть без повреждений» requires the user to have explicitly
    // confirmed it for every photo, not just the inspected ones.
    final aggregateNoDamage =
        files.isNotEmpty && files.every((file) => file.inspection.noDamage);

    final filteredTags = aggregateNoDamage ? const <String>[] : tags;
    final filteredTagPhotos =
        aggregateNoDamage ? const <String, List<String>>{} : tagPhotos;

    return MediaPartInspection(
      noDamage: aggregateNoDamage,
      tags: filteredTags,
      // Derive the group note from the editor's explicit value or the files
      // (never the stale group-level `fallbackNote`) — otherwise clearing a
      // photo's note resurrected the previous group note on the next sync
      // (B16). On the add/delete paths we ignore `partInspection.note` too (it's
      // the stale cached value) and derive purely from files. Pure helper so the
      // rule is unit-tested.
      note: sparkJoyDeriveGroupNote(
        deriveNoteFromFiles ? '' : partInspection.note,
        [for (final file in files) file.inspection.note],
      ),
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
    Set<String>? applyToFileRefs,
  }) {
    if (files.isEmpty) return const <UploadedItem>[];
    final normalizedTargetRefs = applyToFileRefs
        ?.map((ref) => ref.trim())
        .where((ref) => ref.isNotEmpty)
        .toSet();
    final applyToAll =
        normalizedTargetRefs == null || normalizedTargetRefs.isEmpty;
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
      final fileRef = _mediaItemRef(file);
      final fileRefs = _mediaItemRefs(file);
      final applyForFile =
          applyToAll || normalizedTargetRefs.contains(fileRef);
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
        if (fileRefs.any(urls.contains)) {
          tagsForFile.add(canonicalTagByLower[lower]!);
        }
      }
      final previous = file.inspection;
      // noDamage is now per-item: only an EXPLICIT per-file edit
      // (applyToFileRefs non-empty AND this file is targeted) picks
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
      // Delete / add code paths call us with `applyToFileRefs=null`
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
        if (e.videoThumbPath != null) 'videoThumbPath': e.videoThumbPath,
        if (e.videoThumbUrl != null) 'videoThumbUrl': e.videoThumbUrl,
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
      // FileImage keys the ImageCache on the file path, so each photo is
      // decoded once and reused across rebuilds. The old path
      // (readAsBytes + Image.memory) keyed the cache on the Uint8List
      // identity, and readAsBytes returned a *fresh* buffer on every
      // rebuild — so each upload-progress tick was a cache miss whose
      // entry retained the full-resolution encoded file. Re-rendering
      // ~20 photos many times during a multipart upload piled up several
      // GB of encoded buffers and OOM-killed the app at the 3.3 GB
      // high-watermark limit. cacheWidth/Height still downsample the
      // decoded bitmap.
      return Image.file(
        File(localPath),
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

    // Удалённые фото (presigned-URL завершённого отчёта) без decode-размера
    // декодировались в ПОЛНОЕ разрешение (12 МП ≈ 45 МБ на кадр) — именно
    // просмотр завершённых отчётов с десятками фото упирался в память.
    // Локальные ветки выше давно декодируют под размер тайла; выравниваем.
    return Image.network(
      source,
      fit: fit,
      cacheWidth: decodeWidth,
      cacheHeight: decodeHeight,
      filterQuality: filterQuality,
      gaplessPlayback: true,
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
      // A poster URL that failed to load (404 — the key may not exist in S3)
      // is treated as absent: the tile falls back to the spinner while the
      // frame-extraction fallback kicked off by _handleVideoPosterError runs.
      final posterFailed = _videoPosterFailed.contains(item.id);
      final hasPoster =
          !posterFailed && (item.videoThumbUrl ?? '').isNotEmpty;
      // No preview yet (no on-disk thumb, no poster URL) and generation hasn't
      // given up → show the loading spinner instead of the "missing" placeholder
      // while `_generateVideoThumbsForGroup` works through it.
      final loading =
          item.videoThumbPath == null &&
          !hasPoster &&
          !_videoThumbsUnavailable.contains(item.id);
      return _SparkJoyVideoThumbnail(
        thumbPath: item.videoThumbPath,
        thumbUrl: hasPoster ? item.videoThumbUrl : null,
        loading: loading,
        fit: fit,
        onThumbUrlError: hasPoster ? () => _handleVideoPosterError(item) : null,
      );
    }
    return const Icon(Icons.insert_drive_file_outlined, color: kGreyColor);
  }

  /// Called by the tile when its remote poster failed to load (usually a 404:
  /// the backend signs view URLs without checking the key exists, so reports
  /// uploaded before the poster feature — or from web, which can't generate
  /// posters — resolve a URL to a missing object). Stops trusting the poster
  /// for this item and falls back to extracting a frame from the video itself,
  /// keeping the tile on the spinner meanwhile instead of silently flipping to
  /// the grey placeholder.
  void _handleVideoPosterError(UploadedItem item) {
    if (!mounted || _videoPosterFailed.contains(item.id)) return;
    _setStateSafely(() => _videoPosterFailed.add(item.id));
    for (final entry in _mediaState.entries) {
      if (entry.value.files.any((f) => f.id == item.id)) {
        unawaited(_generateVideoThumbsForGroup(entry.key, [item]));
        return;
      }
    }
    // The item isn't in any media group (shouldn't happen for video tiles) —
    // nowhere to write a generated preview back to, so mark it unavailable
    // rather than leaving the spinner running forever.
    _setStateSafely(() => _videoThumbsUnavailable.add(item.id));
  }
}

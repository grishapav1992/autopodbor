part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyFilePickerHelpers on _SparkJoyCreateReportScreenState {
  Future<List<UploadedItem>> _pickFiles({
    required FileType type,
    List<String>? allowedExtensions,
    bool allowMultiple = true,
    bool forceReadBytes = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: kIsWeb || forceReadBytes,
    );
    if (result == null || result.files.isEmpty) return const [];

    final items = <UploadedItem>[];
    var skippedBecauseNotPersisted = false;
    for (final file in result.files) {
      final fileName = file.name.trim().isEmpty ? 'picked_file' : file.name;
      final mimeType = _guessMimeType(fileName);
      String? storedSource;

      if (!kIsWeb && file.path != null && file.path!.trim().isNotEmpty) {
        storedSource = await _persistXFileToAppStorage(
          XFile(file.path!.trim()),
          fileName: fileName,
          mimeType: mimeType,
          prefix: 'picked',
        );
      }

      if ((storedSource ?? '').isEmpty) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        if (!kIsWeb) {
          storedSource = await _persistBytesToAppStorage(
            bytes: bytes,
            mimeType: mimeType,
            prefix: 'picked',
            originalFileName: fileName,
          );
        }
        if (kIsWeb && (storedSource ?? '').isEmpty) {
          final data = base64Encode(bytes);
          storedSource = 'data:$mimeType;base64,$data';
        }
      }
      if ((storedSource ?? '').trim().isEmpty) {
        skippedBecauseNotPersisted = true;
        continue;
      }

      items.add(
        UploadedItem(
          id: _nextUploadedItemId(prefix: 'picked'),
          name: fileName,
          mimeType: mimeType,
          dataUrl: storedSource!,
        ),
      );
    }
    if (skippedBecauseNotPersisted) {
      _showErrorSnack('Часть файлов не удалось сохранить локально');
    }
    return items;
  }

  /// Generates video previews for [items] in [groupKey], strictly one decoder
  /// at a time (via the global gate inside [_resolveSparkJoyVideoThumb]), and
  /// writes each resolved path back into the media-group state so the tile
  /// flips from placeholder to thumbnail. Fire-and-forget — never awaited on
  /// the pick path so the picker stays responsive.
  ///
  /// Skips: non-videos, items already resolved (with the JPEG still on disk),
  /// and network/data-url videos (no local file → stays a placeholder). Bails
  /// out the moment the screen is unmounted so we never `setState` after
  /// dispose.
  Future<void> _generateVideoThumbsForGroup(
    String groupKey,
    List<UploadedItem> items,
  ) async {
    for (final item in items) {
      if (!mounted) return;
      if (!item.isVideo) continue;
      final existing = item.videoThumbPath;
      if (existing != null && await File(existing).exists()) continue;
      // Completed-report videos carry a pre-uploaded poster URL that the tile
      // renders directly — skip on-device extraction entirely (iOS can't decode
      // the remote presigned URL, and the poster already covers it).
      if ((item.videoThumbUrl ?? '').isNotEmpty) continue;
      final localPath = _extractLocalMediaPath(item.dataUrl);
      final String? thumb;
      if (localPath != null) {
        thumb = await _resolveSparkJoyVideoThumb(localPath);
      } else if (item.dataUrl.trim().startsWith('http')) {
        // Completed-report video: remote presigned URL. Generate the preview
        // from the URL (AVFoundation streams just the first frame), keyed by the
        // stable filename so the presigned-signature churn doesn't re-decode
        // every session. Without this, completed reports showed videos without
        // any thumbnail.
        thumb = await _resolveSparkJoyVideoThumbRemote(item.dataUrl, item.name);
      } else {
        // Neither a local file nor a remote URL — no way to produce a preview.
        _setStateSafely(() => _videoThumbsUnavailable.add(item.id));
        continue;
      }
      if (!mounted) return;
      if (thumb == null) {
        // Generation gave up (timeout / decode failure): drop the spinner and
        // show the grey placeholder instead of spinning forever.
        _setStateSafely(() => _videoThumbsUnavailable.add(item.id));
        continue;
      }
      _setStateSafely(() {
        final state = _mediaState[groupKey];
        if (state == null) return;
        final idx = state.files.indexWhere((f) => f.id == item.id);
        if (idx < 0) return;
        final updated = [...state.files];
        updated[idx] = updated[idx].copyWith(videoThumbPath: thumb);
        _mediaState[groupKey] = state.copyWith(files: updated);
      });
    }
  }

  Future<List<UploadedItem>> _uploadedItemsFromXFiles(
    List<XFile> files, {
    String prefix = 'picked',
  }) async {
    final items = <UploadedItem>[];
    var skippedBecauseNotPersisted = false;
    for (final file in files) {
      final fileName = file.name.trim().isEmpty ? 'media_file' : file.name;
      final mimeType = _guessMimeType(fileName);
      String? storedSource = await _persistXFileToAppStorage(
        file,
        fileName: fileName,
        mimeType: mimeType,
        prefix: prefix,
      );
      if ((storedSource ?? '').isEmpty) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        if (!kIsWeb) {
          storedSource = await _persistBytesToAppStorage(
            bytes: bytes,
            mimeType: mimeType,
            prefix: prefix,
            originalFileName: fileName,
          );
        }
        if (kIsWeb && (storedSource ?? '').isEmpty) {
          final data = base64Encode(bytes);
          storedSource = 'data:$mimeType;base64,$data';
        }
      }
      if ((storedSource ?? '').trim().isEmpty) {
        skippedBecauseNotPersisted = true;
        continue;
      }
      items.add(
        UploadedItem(
          id: _nextUploadedItemId(prefix: prefix),
          name: fileName,
          mimeType: mimeType,
          dataUrl: storedSource!,
        ),
      );
    }
    if (skippedBecauseNotPersisted) {
      _showErrorSnack('Часть файлов не удалось сохранить локально');
    }
    return items;
  }

  Future<List<UploadedItem>> _pickMediaFromDeviceGallery() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickMultipleMedia();
      if (picked.isNotEmpty) {
        return _uploadedItemsFromXFiles(picked, prefix: 'media');
      }
      // Пользователь открыл галерею и закрыл/снял выбор: это валидная отмена.
      // Не запускаем fallback pickImage, чтобы не зависать во втором вызове.
      return const [];
    } catch (_) {}

    try {
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        return _uploadedItemsFromXFiles([image], prefix: 'media');
      }
    } catch (_) {}

    return const [];
  }

  Future<int> _pickMediaFiles(String groupKey) => _runPickMediaFiles(groupKey);

  Future<void> _pickLegalFiles() async {
    final items = await _pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
        'heif',
      ],
    );
    if (items.isEmpty || !mounted) return;
    _setStateSafely(() {
      _legalFiles = [..._legalFiles, ...items];
    });
    _markDraftDirty();
  }
}

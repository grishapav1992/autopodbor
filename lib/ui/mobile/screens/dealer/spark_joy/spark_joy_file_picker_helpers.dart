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

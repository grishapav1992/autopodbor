part of 'spark_joy_create_report_screen.dart';

/// Экран интейка «Фото автомобиля» (макет «Отчёт - разделы - редизайн»,
/// экран 2a): массовое добавление фото/видео/документов, группировка по
/// формату, мультивыбор с удалением, внизу — «Распределить файлы» (сейчас
/// = фоновая заливка кадров/фото в облако и ИИ-раскладка оригиналов).
///
/// Живёт как третья ветка шелла редактора (наряду с обзором и редактором
/// секции) — файлы и состояние остаются на общем черновике/контроллере.
extension _SparkJoyPhotoIntakeScreen on _SparkJoyCreateReportScreenState {
  void _openPhotoIntake() {
    _setStateSafely(() {
      _intakeSelectedIds.clear();
      _intakePhotosExpanded = false;
      _reportFlowController.openPhotoIntake();
    });
  }

  void _closePhotoIntake() {
    _setStateSafely(() {
      _intakeSelectedIds.clear();
      _intakePhotosExpanded = false;
      _reportFlowController.closePhotoIntake();
    });
  }

  PreferredSizeWidget _photoIntakeAppBar() {
    final snapshot = SparkJoyIntakeUploadService.instance.snapshotOf(_draftId);
    return sparkAppBar(
      title: 'Фото автомобиля',
      subtitle: snapshot.total == 0
          ? 'ИИ разложит файлы по разделу «Осмотр»'
          : '${sparkIntakeFilesCountLabel(snapshot.total)} · '
                'ИИ разложит по разделу «Осмотр»',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _closePhotoIntake,
      ),
      actions: [
        TextButton(
          onPressed: _closePhotoIntake,
          child: const MyText(
            text: 'Отмена',
            size: SparkTextSize.label,
            weight: FontWeight.w700,
            color: kSecondaryColor,
          ),
        ),
        const SizedBox(width: SparkSpace.md),
      ],
    );
  }

  // ── Добавление файлов ────────────────────────────────────────────────

  Future<void> _runIntakePickPhotos() async {
    final items = await _pickMediaFromDeviceGallery();
    await _stageIntakeItems(items);
  }

  Future<void> _runIntakePickFiles() async {
    final items = await _pickFiles(
      type: FileType.custom,
      // Тот же набор, что у «Материалов проверки» (_pickLegalFiles).
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
        'mp4',
        'mov',
        'm4v',
        'webm',
      ],
    );
    await _stageIntakeItems(items);
  }

  Future<void> _stageIntakeItems(List<UploadedItem> items) async {
    if (items.isEmpty) return;
    final records = <SparkIntakeFileRecord>[];
    for (final item in items) {
      records.add(
        SparkIntakeFileRecord(
          id: item.id,
          name: item.name,
          mimeType: item.mimeType,
          localPath: item.dataUrl,
          sizeBytes: await _intakeSourceSizeBytes(item.dataUrl),
        ),
      );
    }
    await SparkJoyIntakeUploadService.instance.stageFiles(_draftId, records);
    _markDraftDirty();
    _setStateSafely(() {});
    unawaited(_generateIntakeVideoThumbs(records));
  }

  Future<int> _intakeSourceSizeBytes(String source) async {
    final trimmed = source.trim();
    if (_isDataUrl(trimmed)) {
      final comma = trimmed.indexOf(',');
      if (comma <= 0) return 0;
      // base64 → байты: 4 символа кодируют 3 байта.
      return ((trimmed.length - comma - 1) * 3) ~/ 4;
    }
    final localPath = _extractLocalMediaPath(trimmed);
    if (localPath == null) return 0;
    try {
      return await File(localPath).length();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _generateIntakeVideoThumbs(
    List<SparkIntakeFileRecord> records,
  ) async {
    for (final record in records) {
      if (!mounted) return;
      if (!record.isVideo || record.videoThumbPath != null) continue;
      final localPath = _extractLocalMediaPath(record.localPath);
      if (localPath == null) continue;
      final thumb = await _resolveSparkJoyVideoThumb(localPath);
      if (!mounted) return;
      if (thumb == null) continue;
      await SparkJoyIntakeUploadService.instance.updateVideoThumb(
        _draftId,
        record.id,
        thumb,
      );
      _setStateSafely(() {});
    }
  }

  // ── Мультивыбор / удаление ───────────────────────────────────────────

  void _toggleIntakeSelection(String recordId) {
    _setStateSafely(() {
      if (!_intakeSelectedIds.remove(recordId)) {
        _intakeSelectedIds.add(recordId);
      }
    });
  }

  Future<void> _deleteSelectedIntakeFiles() async {
    final ids = Set<String>.from(_intakeSelectedIds);
    if (ids.isEmpty) return;
    await SparkJoyIntakeUploadService.instance.removeFiles(_draftId, ids);
    _markDraftDirty();
    _setStateSafely(() => _intakeSelectedIds.clear());
  }

  Future<void> _runStartIntakeUpload() async {
    await SparkJoyIntakeUploadService.instance.startUpload(_draftId);
    // Новый черновик мог ещё не попасть в стор (applyDraftPatch = no-op) —
    // автосейв довезёт снапшот интейка в составе полного payload.
    _markDraftDirty();
    _closePhotoIntake();
  }

  // ── Вёрстка ──────────────────────────────────────────────────────────

  Widget _photoIntakeEditor() {
    return ValueListenableBuilder<SparkIntakeSnapshot>(
      valueListenable: SparkJoyIntakeUploadService.instance.watch(_draftId),
      builder: (context, snapshot, _) {
        // Выбор мог пережить удаление записей извне — не показываем
        // фантомные ид в счётчике.
        final liveIds = snapshot.files.map((r) => r.id).toSet();
        _intakeSelectedIds.retainWhere(liveIds.contains);

        final photos = snapshot.files.where((r) => r.isImage).toList();
        final videos = snapshot.files.where((r) => r.isVideo).toList();
        final documents = snapshot.files.where((r) => r.isDocument).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _sparkIntakeDashedButton(
                    icon: Icons.add_photo_alternate_outlined,
                    label: 'Загрузить фото',
                    vertical: true,
                    onTap: () => unawaited(_runIntakePickPhotos()),
                  ),
                ),
                const SizedBox(width: SparkSpace.lg),
                Expanded(
                  child: _sparkIntakeDashedButton(
                    icon: Icons.upload_file_rounded,
                    label: 'Загрузить файлы',
                    vertical: true,
                    onTap: () => unawaited(_runIntakePickFiles()),
                  ),
                ),
              ],
            ),
            if (snapshot.files.isEmpty) ...[
              const SizedBox(height: SparkSpace.section),
              const MyText(
                text:
                    'Добавьте фото осмотра, видео и документы — после '
                    'загрузки ИИ разложит их по разделу «Осмотр»',
                size: SparkTextSize.body,
                color: kGreyColor,
                lineHeight: 1.4,
                textAlign: TextAlign.center,
              ),
            ],
            if (photos.isNotEmpty) ...[
              const SizedBox(height: SparkSpace.xxl),
              _intakeGroupHeader('ФОТО', photos),
              const SizedBox(height: SparkSpace.md),
              _intakePhotoGrid(photos),
            ],
            if (videos.isNotEmpty) ...[
              const SizedBox(height: SparkSpace.xxl),
              _intakeGroupHeader('ВИДЕО', videos),
              const SizedBox(height: SparkSpace.md),
              _intakeVideoGrid(videos),
            ],
            if (documents.isNotEmpty) ...[
              const SizedBox(height: SparkSpace.xxl),
              _intakeGroupHeader('ДОКУМЕНТЫ', documents),
              const SizedBox(height: SparkSpace.md),
              _intakeDocumentsCard(documents),
            ],
          ],
        );
      },
    );
  }

  Widget _intakeGroupHeader(String title, List<SparkIntakeFileRecord> records) {
    final selected = records
        .where((r) => _intakeSelectedIds.contains(r.id))
        .length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xxs),
      child: Row(
        children: [
          Expanded(
            child: MyText(
              text: '$title · ${records.length}',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
              color: kGreyColor,
              letterSpacing: 0.6,
            ),
          ),
          if (selected > 0)
            MyText(
              text: 'выбрано $selected',
              size: SparkTextSize.body,
              color: kGreyColor,
            ),
        ],
      ),
    );
  }

  Widget _intakePhotoGrid(List<SparkIntakeFileRecord> photos) {
    // Свёртка: первые 7 + тайл «Ещё N» (раскрывается до закрытия экрана).
    const visibleWhenCollapsed = 7;
    final collapsed =
        !_intakePhotosExpanded && photos.length > visibleWhenCollapsed + 1;
    final visible = collapsed
        ? photos.sublist(0, visibleWhenCollapsed)
        : photos;
    final itemCount = visible.length + (collapsed ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: SparkSpace.md,
        crossAxisSpacing: SparkSpace.md,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (collapsed && index == visible.length) {
          return _intakeMoreTile(photos.length - visibleWhenCollapsed);
        }
        return _intakePhotoTile(visible[index]);
      },
    );
  }

  Widget _intakeMoreTile(int hiddenCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setStateSafely(() => _intakePhotosExpanded = true),
        borderRadius: BorderRadius.circular(SparkRadius.md),
        child: DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(SparkRadius.md),
          color: kBorderColor,
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kLightGreyColor,
              borderRadius: BorderRadius.circular(SparkRadius.md),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: kGreyColor,
                    size: SparkSize.iconMd,
                  ),
                  MyText(
                    text: 'Ещё $hiddenCount',
                    size: SparkTextSize.chip,
                    weight: FontWeight.w700,
                    color: kGreyColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intakePhotoTile(SparkIntakeFileRecord record) {
    final selected = _intakeSelectedIds.contains(record.id);
    return GestureDetector(
      onTap: () => _toggleIntakeSelection(record.id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SparkRadius.md),
          border: selected
              ? Border.all(color: kSecondaryColor, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.md - 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _uploadedImageWidget(
                _intakeAsUploadedItem(record),
                cacheWidth: 200,
              ),
              Positioned(
                top: SparkSpace.xs,
                right: SparkSpace.xs,
                child: _intakeSelectionCircle(selected, onImage: true),
              ),
              if (record.isUploaded)
                const Positioned(
                  left: SparkSpace.xs,
                  bottom: SparkSpace.xs,
                  child: _SparkIntakeStatusDot(
                    icon: Icons.cloud_done_rounded,
                    color: kGreenColor,
                  ),
                )
              else if (record.isFailed)
                const Positioned(
                  left: SparkSpace.xs,
                  bottom: SparkSpace.xs,
                  child: _SparkIntakeStatusDot(
                    icon: Icons.error_outline_rounded,
                    color: kRedColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intakeVideoGrid(List<SparkIntakeFileRecord> videos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: SparkSpace.md,
        crossAxisSpacing: SparkSpace.md,
        childAspectRatio: 16 / 10,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final record = videos[index];
        final selected = _intakeSelectedIds.contains(record.id);
        final thumbPath = record.videoThumbPath;
        return GestureDetector(
          onTap: () => _toggleIntakeSelection(record.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SparkRadius.md),
              border: selected
                  ? Border.all(color: kSecondaryColor, width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.md - 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbPath != null && !kIsWeb)
                    Image.file(
                      File(thumbPath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(color: kGreyColor2),
                    )
                  else
                    const ColoredBox(color: kGreyColor2),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white70,
                      size: SparkSize.iconXxl,
                    ),
                  ),
                  Positioned(
                    top: SparkSpace.xs,
                    right: SparkSpace.xs,
                    child: _intakeSelectionCircle(selected, onImage: true),
                  ),
                  if (record.isUploaded)
                    const Positioned(
                      left: SparkSpace.xs,
                      bottom: SparkSpace.xs,
                      child: _SparkIntakeStatusDot(
                        icon: Icons.cloud_done_rounded,
                        color: kGreenColor,
                      ),
                    )
                  else if (record.isFailed)
                    const Positioned(
                      left: SparkSpace.xs,
                      bottom: SparkSpace.xs,
                      child: _SparkIntakeStatusDot(
                        icon: Icons.error_outline_rounded,
                        color: kRedColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _intakeDocumentsCard(List<SparkIntakeFileRecord> documents) {
    return SparkCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SparkRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              for (var i = 0; i < documents.length; i++) ...[
                if (i > 0)
                  Container(
                    height: SparkSpace.hairline,
                    margin: const EdgeInsets.only(
                      left: SparkSpace.xl + 36 + SparkSpace.xl,
                    ),
                    color: kBorderColor.withValues(alpha: 0.6),
                  ),
                _intakeDocumentRow(documents[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _intakeDocumentRow(SparkIntakeFileRecord record) {
    final selected = _intakeSelectedIds.contains(record.id);
    final isPdf =
        record.mimeType == 'application/pdf' ||
        record.name.toLowerCase().endsWith('.pdf');
    return InkWell(
      onTap: () => _toggleIntakeSelection(record.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpace.xl,
          vertical: SparkSpace.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isPdf ? kOrangeColor : kSecondaryColor).withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(SparkRadius.sm),
              ),
              alignment: Alignment.center,
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.description_outlined,
                color: isPdf ? kOrangeColor : kSecondaryColor,
                size: SparkSize.iconMd,
              ),
            ),
            const SizedBox(width: SparkSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: record.name.isEmpty ? 'Документ' : record.name,
                    size: SparkTextSize.label,
                    weight: FontWeight.w600,
                    color: kTertiaryColor,
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: SparkSpace.xxs),
                  MyText(
                    text: record.isFailed
                        ? 'Ошибка загрузки'
                        : sparkIntakeSizeLabel(record.sizeBytes),
                    size: SparkTextSize.caption,
                    color: record.isFailed ? kRedColor : kGreyColor,
                  ),
                ],
              ),
            ),
            if (record.isUploaded) ...[
              const Icon(
                Icons.cloud_done_rounded,
                color: kGreenColor,
                size: SparkSize.iconSm,
              ),
              const SizedBox(width: SparkSpace.md),
            ],
            _intakeSelectionCircle(selected, onImage: false),
          ],
        ),
      ),
    );
  }

  Widget _intakeSelectionCircle(bool selected, {required bool onImage}) {
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: kSecondaryColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.check_rounded,
          color: kWhiteColor,
          size: SparkSize.iconXs,
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onImage ? Colors.black26 : Colors.transparent,
        border: Border.all(
          color: onImage ? Colors.white.withValues(alpha: 0.9) : kBorderColor,
          width: 1.5,
        ),
      ),
    );
  }

  /// Адаптер записи интейка под [_uploadedImageWidget]: рендер тайла умеет
  /// dataUrl/файл/сеть — не дублируем.
  UploadedItem _intakeAsUploadedItem(SparkIntakeFileRecord record) {
    return UploadedItem(
      id: record.id,
      name: record.name,
      mimeType: record.mimeType,
      dataUrl: record.localPath,
      videoThumbPath: record.videoThumbPath,
    );
  }

  // ── Нижняя панель ────────────────────────────────────────────────────

  Widget _photoIntakeBottomBar() {
    return ValueListenableBuilder<SparkIntakeSnapshot>(
      valueListenable: SparkJoyIntakeUploadService.instance.watch(_draftId),
      builder: (context, snapshot, _) {
        final selectedCount = _intakeSelectedIds.length;
        final hasPending = snapshot.files.any((r) => !r.isUploaded);
        return Container(
          decoration: const BoxDecoration(
            color: kPrimaryColor,
            border: Border(
              top: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.section,
            SparkSpace.lg,
            SparkSpace.section,
            SparkSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedCount > 0) ...[
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.xl,
                  ),
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(SparkRadius.md),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_box_rounded,
                        color: kSecondaryColor,
                        size: SparkSize.iconMd,
                      ),
                      const SizedBox(width: SparkSpace.lg),
                      Expanded(
                        child: MyText(
                          text:
                              'Выбрано ${sparkIntakeFilesCountLabel(selectedCount)}',
                          size: SparkTextSize.bodyLg,
                          weight: FontWeight.w600,
                          color: kTertiaryColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => unawaited(_deleteSelectedIntakeFiles()),
                        borderRadius: BorderRadius.circular(SparkRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SparkSpace.xs,
                            vertical: SparkSpace.xs,
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: kRedColor,
                                size: SparkSize.iconMd,
                              ),
                              SizedBox(width: SparkSpace.xs),
                              MyText(
                                text: 'Удалить',
                                size: SparkTextSize.bodyLg,
                                weight: FontWeight.w700,
                                color: kRedColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SparkSpace.lg),
              ],
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: snapshot.files.isEmpty || !hasPending
                      ? null
                      : () => unawaited(_runStartIntakeUpload()),
                  style: FilledButton.styleFrom(
                    backgroundColor: kSecondaryColor,
                    disabledBackgroundColor: kSecondaryColor.withValues(
                      alpha: 0.35,
                    ),
                    foregroundColor: kWhiteColor,
                    disabledForegroundColor: kWhiteColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SparkRadius.md),
                    ),
                    textStyle: const TextStyle(
                      fontSize: SparkTextSize.sectionTitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: SparkSize.iconLg),
                  label: const Text('Распределить файлы'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Мини-бейдж статуса заливки на тайле (облако = загружено, «!» = ошибка).
class _SparkIntakeStatusDot extends StatelessWidget {
  const _SparkIntakeStatusDot({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 13),
    );
  }
}

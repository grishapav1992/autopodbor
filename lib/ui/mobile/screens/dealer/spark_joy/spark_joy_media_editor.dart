part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaEditorMethods on _SparkJoyCreateReportScreenState {
  Future<int> _runPickMediaFiles(String groupKey) async {
    if (_mediaPickerOpening) {
      final startedAt = _mediaPickerStartedAt;
      final isStale =
          startedAt == null ||
          DateTime.now().difference(startedAt) > const Duration(seconds: 25);
      if (!isStale) return 0;
      if (mounted) {
        _setStateSafely(() {
          _mediaPickerOpening = false;
          _mediaPickerGroupKey = null;
          _mediaPickerStartedAt = null;
        });
      } else {
        _mediaPickerOpening = false;
        _mediaPickerGroupKey = null;
        _mediaPickerStartedAt = null;
      }
    }
    if (mounted) {
      _setStateSafely(() {
        _mediaPickerOpening = true;
        _mediaPickerGroupKey = groupKey;
        _mediaPickerStartedAt = DateTime.now();
      });
    } else {
      _mediaPickerOpening = true;
      _mediaPickerGroupKey = groupKey;
      _mediaPickerStartedAt = DateTime.now();
    }
    final nativeGalleryPlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    var timedOut = false;

    try {
      final items = nativeGalleryPlatform
          ? await _pickMediaFromDeviceGallery().timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                timedOut = true;
                return const <UploadedItem>[];
              },
            )
          : await _pickFiles(
              type: FileType.custom,
              allowedExtensions: const [
                'png',
                'jpg',
                'jpeg',
                'webp',
                'heic',
                'heif',
                'mp4',
                'mov',
                'webm',
              ],
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                timedOut = true;
                return const <UploadedItem>[];
              },
            );
      if (timedOut) {
        _showErrorSnack(
          'Галерея не ответила вовремя. Попробуйте снова.',
        );
      }
      if (items.isEmpty || !mounted) return 0;
      _setStateSafely(() {
        final state = _mediaState[groupKey];
        if (state == null) return;
        final currentFiles = [...state.files];
        final nextFiles = [...currentFiles, ...items];
        // Не переносим заметки/теги на новые медиа автоматически.
        // Иначе заметка одного фото "прилипает" ко всем добавленным позже.
        final nextPartInspection = _syncPartInspectionWithFiles(
          partInspection: state.partInspection,
          files: currentFiles,
          fallbackNote: state.note,
        );
        _mediaState[groupKey] = state.copyWith(
          files: nextFiles,
          partInspection: nextPartInspection,
          hasIssue: nextFiles.any(_mediaItemHasIssue),
        );
      });
      return items.length;
    } finally {
      if (mounted) {
        _setStateSafely(() {
          _mediaPickerOpening = false;
          _mediaPickerGroupKey = null;
          _mediaPickerStartedAt = null;
        });
      } else {
        _mediaPickerOpening = false;
        _mediaPickerGroupKey = null;
        _mediaPickerStartedAt = null;
      }
    }
  }

  void _runOpenMediaGroupEditor(String groupKey) {
    final currentOffset = _pageScrollController.hasClients
        ? _pageScrollController.offset
        : null;
    _setStateSafely(() {
      _mediaGroupListScrollOffset = currentOffset;
      _activeMediaGroupKey = groupKey;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      _mediaGroupPressedIndex = null;
      _mediaListPressedGroupKey = null;
    });
  }

  Future<void> _runOpenMediaGroupFlow(String groupKey) async {
    final state = _mediaState[groupKey];
    if (state == null) return;

    if (!mounted) return;
    _openMediaGroupEditor(groupKey);

    if (state.files.isNotEmpty) return;

    try {
      await _runPickMediaFiles(groupKey);
    } catch (error) {
      _showErrorSnack('Не удалось открыть галерею: $error');
    }
  }

  Widget _runMediaMetaPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return SparkChip(
      text: text,
      background: color.withValues(alpha: 0.1),
      color: color,
      icon: icon,
      iconSize: SparkTextSize.body,
      textSize: SparkTextSize.chip,
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.xs,
      ),
    );
  }

  bool _runGroupFullyMarked(MediaGroupState state) {
    if (state.files.isEmpty) return false;
    // `audioRecordings` исключены — см. `_mediaInspectionHasData`.
    return state.files.every((file) {
      final inspection = file.inspection;
      return inspection.noDamage ||
          inspection.tags.isNotEmpty ||
          (inspection.elementType ?? '').trim().isNotEmpty ||
          inspection.note.trim().isNotEmpty ||
          (inspection.paintFrom != null && inspection.paintTo != null);
    });
  }

  Widget _runMediaPaintSummaryBlock({
    required String title,
    required double from,
    required double to,
    required ValueChanged<RangeValues> onChanged,
  }) {
    final safeFrom = from.clamp(50, 1500).toDouble();
    final safeTo = to.clamp(safeFrom, 1500).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.xxxl,
        SparkSpace.xl,
        SparkSpace.xxxl,
        SparkSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: title.toUpperCase(),
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.xs),
          Row(
            children: [
              SizedBox(
                width: 92,
                child: _paintManualValueField(
                  label: 'От',
                  value: safeFrom,
                  showLabel: false,
                  hint: '',
                  onSubmitted: (manualFrom) {
                    final fromValue = manualFrom.toDouble();
                    final toValue = math.max(fromValue, safeTo);
                    onChanged(RangeValues(fromValue, toValue));
                  },
                ),
              ),
              const SizedBox(width: SparkSpace.sm),
              const MyText(
                text: '—',
                size: SparkTextSize.label,
                color: kGreyColor,
              ),
              const SizedBox(width: SparkSpace.sm),
              SizedBox(
                width: 92,
                child: _paintManualValueField(
                  label: 'До',
                  value: safeTo,
                  showLabel: false,
                  hint: '',
                  onSubmitted: (manualTo) {
                    final toValue = manualTo.toDouble();
                    final fromValue = math.min(safeFrom, toValue);
                    onChanged(RangeValues(fromValue, toValue));
                  },
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              const MyText(
                text: 'мкм',
                size: SparkTextSize.body,
                color: kGreyColor,
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          RangeSlider(
            values: RangeValues(safeFrom, safeTo),
            min: 50,
            max: 1500,
            divisions: 145,
            onChanged: onChanged,
          ),
          Row(
            children: const [
              MyText(text: '50', size: SparkTextSize.chip, color: kGreyColor),
              Spacer(),
              MyText(text: '1500', size: SparkTextSize.chip, color: kGreyColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _runMediaGroupListRow(MediaGroupState state) {
    final groupKey = state.config.key;
    final isPressed = _mediaListPressedGroupKey == groupKey;
    final fileCount = state.files.length;
    final hasFiles = fileCount > 0;
    final hasIssue = _groupHasIssue(state);
    final fullyMarked = _runGroupFullyMarked(state);
    final issueCount = state.files.where(_mediaItemHasIssue).length;
    final notesCount = state.files
        .where((file) => _mediaInspectionHasData(file.inspection))
        .length;
    final statusLabel = !hasFiles
        ? 'Пусто'
        : (hasIssue
              ? 'Замечания'
              : (notesCount > 0 ? 'Есть заметки' : 'Готово'));
    final statusColor = !hasFiles
        ? kGreyColor
        : (hasIssue
              ? kRedColor
              : (notesCount > 0 ? kGreenColor : kSecondaryColor));
    final leadBg = hasFiles
        ? (hasIssue
              ? kRedColor.withValues(alpha: 0.1)
              : kSecondaryColor.withValues(alpha: 0.1))
        : kInputBgColor;
    final leadColor = hasFiles
        ? (hasIssue ? kRedColor : kSecondaryColor)
        : kGreyColor;

    Widget? footer;
    if (groupKey == 'body') {
      footer = _runMediaPaintSummaryBlock(
        title: 'ЛКП — кузов',
        from: _bodyPaintFrom,
        to: _bodyPaintTo,
        onChanged: (values) {
          _setStateSafely(() {
            _bodyPaintFrom = values.start.roundToDouble();
            _bodyPaintTo = values.end.roundToDouble();
          });
        },
      );
    } else if (groupKey == 'structural') {
      footer = _runMediaPaintSummaryBlock(
        title: 'ЛКП — силовые',
        from: _structPaintFrom,
        to: _structPaintTo,
        onChanged: (values) {
          _setStateSafely(() {
            _structPaintFrom = values.start.roundToDouble();
            _structPaintTo = values.end.roundToDouble();
          });
        },
      );
    }

    // Визуальная дифференциация заполненных vs пустых секций:
    // 1) Светло-зелёный tint фона карточки → секция взгляду читается
    //    как «✓ done» даже без скролла к правой части карточки.
    // 2) Зелёная рамка чуть плотнее (0.55 vs 0.3) — было слишком
    //    блекло на фоне 8-разделового списка осмотра.
    // 3) Trailing chevron заменяется на ✓ когда секция fullyMarked.
    final cardBackground = isPressed
        ? kSecondaryColor.withValues(alpha: 0.02)
        : (hasIssue
            ? kWhiteColor
            : (fullyMarked ? kGreenColor.withValues(alpha: 0.04) : kWhiteColor));
    final cardBorder = hasIssue
        ? kRedColor.withValues(alpha: 0.3)
        : (fullyMarked
            ? kGreenColor.withValues(alpha: 0.55)
            : (isPressed
                ? kSecondaryColor.withValues(alpha: 0.28)
                : kBorderColor));

    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.lg),
      child: AnimatedScale(
        duration: SparkMotion.fast,
        curve: Curves.easeOut,
        scale: isPressed ? 0.995 : 1.0,
        child: SparkCard(
          radius: SparkRadius.xl,
          padding: EdgeInsets.zero,
          backgroundColor: cardBackground,
          borderColor: cardBorder,
          child: Column(
            children: [
              InkWell(
                onTap: () => _openMediaGroupFlow(groupKey),
                onHighlightChanged: (value) {
                  if (!mounted) return;
                  final next = value ? groupKey : null;
                  if (_mediaListPressedGroupKey == next) return;
                  _setStateSafely(() {
                    _mediaListPressedGroupKey = next;
                  });
                },
                borderRadius: BorderRadius.circular(SparkRadius.xl),
                splashColor: kSecondaryColor.withValues(alpha: 0.12),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.xxl,
                    vertical: SparkSpace.xxl,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: SparkSize.inputHeightLg,
                        height: SparkSize.inputHeightLg,
                        decoration: BoxDecoration(
                          color: leadBg,
                          borderRadius: BorderRadius.circular(SparkRadius.xxl),
                        ),
                        alignment: Alignment.center,
                        child: hasFiles
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasIssue
                                        ? Icons.report_problem_outlined
                                        : Icons.photo_outlined,
                                    size: SparkTextSize.title,
                                    color: leadColor,
                                  ),
                                  const SizedBox(width: SparkSpace.xxs),
                                  MyText(
                                    text: '$fileCount',
                                    size: SparkTextSize.caption,
                                    color: leadColor,
                                    weight: FontWeight.w700,
                                  ),
                                ],
                              )
                            : Icon(
                                Icons.add_rounded,
                                color: leadColor,
                                size: SparkSize.iconXxl,
                              ),
                      ),
                      const SizedBox(width: SparkSpace.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              text: state.config.title,
                              size: SparkTextSize.title,
                              weight: FontWeight.w700,
                            ),
                            if (state.config.description.trim().isNotEmpty) ...[
                              const SizedBox(height: SparkSpace.xxs),
                              MyText(
                                text: state.config.description,
                                size: SparkTextSize.caption,
                                color: kGreyColor,
                                maxLines: 1,
                                textOverflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: SparkSpace.md),
                            Wrap(
                              spacing: SparkSpace.sm,
                              runSpacing: SparkSpace.sm,
                              children: [
                                _runMediaMetaPill(
                                  icon: Icons.photo_library_outlined,
                                  text: 'Файлы $fileCount',
                                  color: kSecondaryColor,
                                ),
                                _runMediaMetaPill(
                                  icon: Icons.radio_button_checked_rounded,
                                  text: statusLabel,
                                  color: statusColor,
                                ),
                                if (notesCount > 0)
                                  _runMediaMetaPill(
                                    icon: Icons.edit_note_rounded,
                                    text: 'С заметкой $notesCount',
                                    color: kGreenColor,
                                  ),
                                if (issueCount > 0)
                                  _runMediaMetaPill(
                                    icon: Icons.report_problem_outlined,
                                    text: 'Замечания $issueCount',
                                    color: kRedColor,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SparkSpace.sm),
                      // Заполненная секция (без замечаний) → зелёный
                      // чек вместо обычного chevron'а. С 8 группами в
                      // списке это самый быстрый способ глазами найти
                      // что ещё не доделано.
                      Column(
                        children: [
                          Icon(
                            (fullyMarked && !hasIssue)
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            color: (fullyMarked && !hasIssue)
                                ? kGreenColor
                                : kGreyColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (footer != null) ...[
                const Divider(height: 1),
                // Изолируем область ЛКП от onTap карточки группы,
                // чтобы ввод ручных значений не открывал галерею.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: footer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _runMediaOverlaySelectionMarker({required bool selected}) {
    return AnimatedContainer(
      duration: SparkMotion.fast,
      width: SparkSize.iconXl,
      height: SparkSize.iconXl,
      decoration: BoxDecoration(
        color: selected ? kSecondaryColor : kWhiteColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        border: Border.all(color: selected ? kSecondaryColor : kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(
              Icons.check_rounded,
              size: SparkTextSize.label,
              color: kWhiteColor,
            )
          : Container(
              width: SparkSpace.sm,
              height: SparkSpace.sm,
              decoration: const BoxDecoration(
                color: kGreyColor,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  Widget _runMediaOverlayCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final fg = destructive ? kRedColor : kSecondaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        child: Ink(
          width: SparkSize.iconState,
          height: SparkSize.iconState,
          decoration: BoxDecoration(
            color: destructive
                ? kWhiteColor.withValues(alpha: 0.94)
                : kWhiteColor.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: destructive
                  ? kRedColor.withValues(alpha: 0.18)
                  : kWhiteColor.withValues(alpha: 0.95),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: SparkTextSize.titleLg, color: fg),
        ),
      ),
    );
  }

  Widget _runMediaOverlayPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final fg = highlighted ? kSecondaryColor : kTertiaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xl,
            vertical: SparkSpace.md,
          ),
          decoration: BoxDecoration(
            color: kWhiteColor.withValues(alpha: highlighted ? 0.94 : 0.9),
            borderRadius: BorderRadius.circular(SparkRadius.pill),
            border: Border.all(
              color: highlighted
                  ? kSecondaryColor.withValues(alpha: 0.22)
                  : kWhiteColor.withValues(alpha: 0.95),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: SparkTextSize.title, color: fg),
              const SizedBox(width: SparkSpace.xs),
              MyText(
                text: label,
                size: SparkTextSize.caption,
                color: fg,
                weight: FontWeight.w700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _runMediaOverlayStatusBadge({
    required IconData icon,
    required String label,
    required Color color,
    bool muted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.lg,
        vertical: SparkSpace.sm,
      ),
      decoration: BoxDecoration(
        color: muted
            ? kWhiteColor.withValues(alpha: 0.9)
            : color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        border: Border.all(
          color: muted
              ? kBorderColor.withValues(alpha: 0.8)
              : color.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: SparkTextSize.label,
            color: muted ? kGreyColor : kWhiteColor,
          ),
          const SizedBox(width: SparkSpace.xs),
          MyText(
            text: label,
            size: SparkTextSize.chip,
            color: muted ? kGreyColor : kWhiteColor,
            weight: FontWeight.w700,
          ),
        ],
      ),
    );
  }

  Widget _runMediaOverlayTypeBadge(UploadedItem item) {
    final isVideo = item.isVideo;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.play_arrow_rounded : Icons.photo_outlined,
            size: SparkTextSize.label,
            color: kWhiteColor,
          ),
          const SizedBox(width: SparkSpace.xxxs),
          MyText(
            text: isVideo ? 'Видео' : 'Фото',
            size: SparkTextSize.chip,
            color: kWhiteColor,
            weight: FontWeight.w700,
          ),
        ],
      ),
    );
  }

  Widget _runMediaAddTile({
    required bool isBusy,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.xl),
        child: Ink(
          decoration: BoxDecoration(
            color: kInputBgColor,
            borderRadius: BorderRadius.circular(SparkRadius.xl),
            border: Border.all(
              color: isBusy
                  ? kSecondaryColor.withValues(alpha: 0.35)
                  : kBorderColor,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: SparkMotion.fast,
              child: isBusy
                  ? const SizedBox(
                      key: ValueKey('media-add-loading'),
                      width: SparkSize.iconXxl,
                      height: SparkSize.iconXxl,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Column(
                      key: const ValueKey('media-add-idle'),
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: SparkSize.icon4xl,
                          color: kGreyColor,
                        ),
                        SizedBox(height: SparkSpace.sm),
                        MyText(
                          text: 'Фото / Видео',
                          size: SparkTextSize.body,
                          color: kGreyColor,
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _runMediaGroupEditor() {
    final groupKey = _activeMediaGroupKey;
    if (groupKey == null) return const SizedBox.shrink();

    final state = _mediaState[groupKey];
    if (state == null) {
      return _card(
        child: const MyText(
          text: 'Группа не найдена',
          size: SparkTextSize.body,
          color: kRedColor,
        ),
      );
    }

    final files = state.files;
    final selectedCount = _mediaGroupSelectedIndexes.length;
    final pickerOpeningForGroup =
        _mediaPickerOpening && _mediaPickerGroupKey == groupKey;
    final notedFiles = files
        .where((file) => _mediaInspectionHasData(file.inspection))
        .length;
    final issueFiles = files.where(_mediaItemHasIssue).length;

    return Column(
      children: [
        SparkCard(
          radius: SparkRadius.xxl,
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xxl,
            vertical: SparkSpace.xl,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MyText(
                      text: state.config.title,
                      size: SparkTextSize.title,
                      weight: FontWeight.w700,
                      maxLines: 2,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: '${files.length} файлов',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                      maxLines: 1,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SparkSpace.sm),
                    Wrap(
                      spacing: SparkSpace.sm,
                      runSpacing: SparkSpace.sm,
                      children: [
                        SparkChip(
                          text: 'Файлы: ${files.length}',
                          background: kSecondaryColor.withValues(alpha: 0.1),
                          color: kSecondaryColor,
                          textSize: SparkTextSize.caption,
                          padding: const EdgeInsets.symmetric(
                            horizontal: SparkSpace.md,
                            vertical: SparkSpace.xxxs,
                          ),
                        ),
                        SparkChip(
                          text: 'С заметкой: $notedFiles',
                          background: kGreenColor.withValues(alpha: 0.12),
                          color: kGreenColor,
                          textSize: SparkTextSize.caption,
                          padding: const EdgeInsets.symmetric(
                            horizontal: SparkSpace.md,
                            vertical: SparkSpace.xxxs,
                          ),
                        ),
                        if (issueFiles > 0)
                          SparkChip(
                            text: 'Замечания: $issueFiles',
                            background: kRedColor.withValues(alpha: 0.12),
                            color: kRedColor,
                            textSize: SparkTextSize.caption,
                            padding: const EdgeInsets.symmetric(
                              horizontal: SparkSpace.md,
                              vertical: SparkSpace.xxxs,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SparkSpace.lg),
        // Unified swap slot: compact select toolbar in multi-select mode,
        // otherwise the "long-press" hint (or nothing when only one file).
        // AnimatedSize smooths height transitions, so switching modes doesn't
        // make the grid jump.
        AnimatedSize(
          duration: SparkMotion.fast,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: SparkMotion.fast,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: (_mediaGroupSelectMode && selectedCount > 0)
                ? Padding(
                    key: const ValueKey('media-select-toolbar'),
                    padding: const EdgeInsets.only(bottom: SparkSpace.lg),
                    child: SparkCard(
                      radius: SparkRadius.lg,
                      backgroundColor: kSecondaryColor.withValues(alpha: 0.08),
                      borderColor: kSecondaryColor.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.md,
                        vertical: SparkSpace.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: kSecondaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: MyText(
                              text: '$selectedCount',
                              color: kWhiteColor,
                              weight: FontWeight.w700,
                              size: SparkTextSize.caption,
                            ),
                          ),
                          const SizedBox(width: SparkSpace.md),
                          const Expanded(
                            child: MyText(
                              text: 'Выбрано',
                              size: SparkTextSize.body,
                              color: kSecondaryColor,
                              weight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Добавить заметку',
                            onPressed: () =>
                                _applyInspectionToSelected(groupKey),
                            icon: const Icon(Icons.edit_note_rounded),
                            color: kSecondaryColor,
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            onPressed: () => _deleteMediaInGroup(
                              groupKey: groupKey,
                              indexes: _mediaGroupSelectedIndexes.toList(),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: kRedColor,
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            tooltip: 'Отмена',
                            onPressed: () {
                              _setStateSafely(() {
                                _mediaGroupSelectMode = false;
                                _mediaGroupSelectedIndexes = <int>{};
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                            color: kGreyColor,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  )
                : (files.length > 1
                      ? const Padding(
                          key: ValueKey('media-select-hint'),
                          padding: EdgeInsets.only(bottom: SparkSpace.lg),
                          child: SparkHintCard(
                            text:
                                'Зажмите фото для выбора нескольких файлов.',
                            icon: Icons.touch_app_outlined,
                          ),
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('media-select-none'),
                        )),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final gridColumns = maxWidth >= 1080
                ? 4
                : (maxWidth >= 760 ? 3 : 2);
            final gridAspectRatio = gridColumns >= 3 ? 1.18 : 1.34;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColumns,
                crossAxisSpacing: SparkSpace.lg,
                mainAxisSpacing: SparkSpace.lg,
                childAspectRatio: gridAspectRatio,
              ),
              itemCount: files.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _runMediaAddTile(
                    isBusy: pickerOpeningForGroup,
                    onTap: pickerOpeningForGroup
                        ? null
                        : () async {
                            try {
                              await _pickMediaFiles(groupKey);
                            } catch (error) {
                              _showErrorSnack(
                                'Не удалось открыть галерею: $error',
                              );
                            }
                          },
                  );
                }

                final fileIndex = index - 1;
                final item = files[fileIndex];
                final selected = _mediaGroupSelectedIndexes.contains(fileIndex);
                final hasInspection = _mediaInspectionHasData(item.inspection);

                final isPressed = _mediaGroupPressedIndex == fileIndex;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('media-item-$groupKey-${item.id}'),
                    onLongPress: () {
                      unawaited(HapticFeedback.selectionClick());
                      if (!_mediaGroupSelectMode) {
                        _setStateSafely(() {
                          _mediaGroupSelectMode = true;
                          _mediaGroupSelectedIndexes = {fileIndex};
                          _mediaGroupPressedIndex = null;
                        });
                        return;
                      }
                      _toggleMediaGroupSelection(fileIndex);
                    },
                    onHighlightChanged: (value) {
                      if (_mediaGroupPressedIndex == fileIndex && !value) {
                        _setStateSafely(() => _mediaGroupPressedIndex = null);
                        return;
                      }
                      if (_mediaGroupPressedIndex != fileIndex && value) {
                        _setStateSafely(
                          () => _mediaGroupPressedIndex = fileIndex,
                        );
                      }
                    },
                    onTap: () {
                      if (_mediaGroupSelectMode) {
                        unawaited(HapticFeedback.selectionClick());
                        _toggleMediaGroupSelection(fileIndex);
                        return;
                      }
                      _openMediaGroupLightbox(
                        groupKey: groupKey,
                        initialIndex: fileIndex,
                      );
                    },
                    borderRadius: BorderRadius.circular(SparkRadius.xl),
                    splashColor: kSecondaryColor.withValues(alpha: 0.12),
                    highlightColor: Colors.transparent,
                    child: AnimatedScale(
                      duration: SparkMotion.fast,
                      curve: Curves.easeOut,
                      scale: isPressed ? 0.985 : 1,
                      child: AnimatedContainer(
                        duration: SparkMotion.fast,
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: selected
                              ? kSecondaryColor.withValues(alpha: 0.08)
                              : (isPressed
                                    ? kSecondaryColor.withValues(alpha: 0.03)
                                    : kWhiteColor),
                          borderRadius: BorderRadius.circular(SparkRadius.xl),
                          border: Border.all(
                            color: selected
                                ? kSecondaryColor.withValues(alpha: 0.45)
                                : (isPressed
                                      ? kSecondaryColor.withValues(alpha: 0.28)
                                      : kBorderColor),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  SparkRadius.xl,
                                ),
                                child: Container(
                                  color: kLightGreyColor,
                                  // BoxFit.cover fills the tile completely
                                  // (slight crop) so photos/videos no longer
                                  // appear stretched or letter-boxed.
                                  child: SizedBox.expand(
                                    child: _uploadedMediaThumbWidget(
                                      item,
                                      fit: BoxFit.cover,
                                      cacheWidth: 720,
                                      cacheHeight: 720,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      SparkRadius.xl,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.12),
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.1),
                                      ],
                                      stops: const [0, 0.18, 0.72, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: SparkSpace.lg,
                              top: SparkSpace.lg,
                              child: AnimatedSwitcher(
                                duration: SparkMotion.fast,
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: _mediaGroupSelectMode
                                    ? KeyedSubtree(
                                        key: ValueKey(
                                          'media-select-${item.id}-$selected',
                                        ),
                                        child: _runMediaOverlaySelectionMarker(
                                          selected: selected,
                                        ),
                                      )
                                    : KeyedSubtree(
                                        key: ValueKey(
                                          'media-delete-${item.id}',
                                        ),
                                        child: _runMediaOverlayCircleButton(
                                          icon: Icons.delete_outline_rounded,
                                          destructive: true,
                                          onTap: () => _deleteMediaInGroup(
                                            groupKey: groupKey,
                                            indexes: [fileIndex],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              right: SparkSpace.lg,
                              top: SparkSpace.lg,
                              child: AnimatedSwitcher(
                                duration: SparkMotion.fast,
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: _mediaGroupSelectMode
                                    ? const SizedBox.shrink(
                                        key: ValueKey('media-note-hidden'),
                                      )
                                    : KeyedSubtree(
                                        key: ValueKey(
                                          'media-note-${item.id}-$hasInspection',
                                        ),
                                        child: _runMediaOverlayPillButton(
                                          icon: hasInspection
                                              ? Icons.edit_note_rounded
                                              : Icons.add_rounded,
                                          label: hasInspection
                                              ? 'Заметка'
                                              : 'Добавить',
                                          highlighted: hasInspection,
                                          onTap: () =>
                                              _openMediaInspectionEditor(
                                                groupKey: groupKey,
                                                index: fileIndex,
                                              ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              left: SparkSpace.lg,
                              bottom: SparkSpace.lg,
                              child: AnimatedSwitcher(
                                duration: SparkMotion.fast,
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: _mediaGroupSelectMode
                                    ? const SizedBox.shrink(
                                        key: ValueKey(
                                          'inspection-badge-hidden-select',
                                        ),
                                      )
                                    : KeyedSubtree(
                                        key: ValueKey(
                                          'inspection-badge-$hasInspection',
                                        ),
                                        child: _runMediaOverlayStatusBadge(
                                          icon: hasInspection
                                              ? Icons
                                                    .check_circle_outline_rounded
                                              : Icons.radio_button_unchecked,
                                          label: hasInspection
                                              ? 'Есть заметка'
                                              : 'Без заметки',
                                          color: kGreenColor,
                                          muted: !hasInspection,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              right: SparkSpace.lg,
                              bottom: SparkSpace.lg,
                              child: AnimatedSwitcher(
                                duration: SparkMotion.fast,
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: _mediaGroupSelectMode
                                    ? const SizedBox.shrink(
                                        key: ValueKey('type-badge-hidden'),
                                      )
                                    : KeyedSubtree(
                                        key: ValueKey('type-badge-${item.id}'),
                                        child: _runMediaOverlayTypeBadge(item),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (files.isEmpty) ...[
          const SizedBox(height: SparkSpace.lg),
          const SparkHintCard(
            text: 'Добавьте фото или видео, затем нажмите «Заметка».',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ],
    );
  }

  void _toggleMediaGroupSelection(int index) {
    _setStateSafely(() {
      final next = <int>{..._mediaGroupSelectedIndexes};
      if (next.contains(index)) {
        next.remove(index);
      } else {
        next.add(index);
      }
      _mediaGroupSelectedIndexes = next;
      if (_mediaGroupSelectedIndexes.isEmpty) {
        _mediaGroupSelectMode = false;
      }
    });
  }

  void _deleteMediaInGroup({
    required String groupKey,
    required List<int> indexes,
  }) {
    if (indexes.isEmpty) return;
    _setStateSafely(() {
      final current = _mediaState[groupKey];
      if (current == null || current.files.isEmpty) return;
      final toDelete = indexes.toSet();
      final next = <UploadedItem>[];
      for (var i = 0; i < current.files.length; i++) {
        if (!toDelete.contains(i)) {
          next.add(current.files[i]);
        }
      }
      final nextPartInspection = _syncPartInspectionWithFiles(
        partInspection: current.partInspection,
        files: next,
        fallbackNote: current.note,
      );
      final nextFiles = _applyPartInspectionToFiles(
        files: next,
        partInspection: nextPartInspection,
      );
      _mediaState[groupKey] = current.copyWith(
        files: nextFiles,
        hasIssue: nextFiles.any(_mediaItemHasIssue),
        partInspection: nextPartInspection,
      );
      _mediaGroupSelectedIndexes = <int>{};
      _mediaGroupSelectMode = false;
      _mediaGroupPressedIndex = null;
      _mediaListPressedGroupKey = null;
    });
  }

  Future<void> _applyInspectionToSelected(String groupKey) async {
    final current = _mediaState[groupKey];
    if (current == null) return;
    final selected = _mediaGroupSelectedIndexes.toList()..sort();
    final targetIndexes = selected.isEmpty
        ? List<int>.generate(current.files.length, (i) => i)
        : selected;
    final validSelected = targetIndexes
        .where((index) => index >= 0 && index < current.files.length)
        .toList();
    if (validSelected.isEmpty) return;
    final templateIndex = validSelected.first;

    final saved = await _openMediaInspectionEditor(
      groupKey: groupKey,
      index: templateIndex,
      applyToIndexes: validSelected,
      saveDraftOnClose: false,
    );
    if (!saved || !mounted) return;

    _setStateSafely(() {
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      _mediaGroupPressedIndex = null;
      _mediaListPressedGroupKey = null;
    });
  }
}

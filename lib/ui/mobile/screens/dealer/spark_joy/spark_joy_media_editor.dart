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
        _showErrorSnack('Галерея не ответила вовремя. Попробуйте снова.');
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
      // Resolve video previews off the render path, one decoder at a time.
      // Not awaited: the grid shows placeholders immediately and tiles flip in
      // as each thumbnail lands.
      unawaited(_generateVideoThumbsForGroup(groupKey, items));
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

  /// Прямой прыжок editor→editor по тапу на шаг в `_runMediaGroupStepper`.
  /// В отличие от `_runOpenMediaGroupEditor`, сохраняет
  /// `_mediaGroupListScrollOffset` — иначе при выходе обычным «назад»
  /// инспектор окажется не там, где оставил список групп. Дополнительно
  /// сбрасывает скролл нового редактора в начало и принудительно
  /// сохраняет черновик (autosave имеет debounce 900мс — без явного
  /// сохранения при крэше есть окно потери данных).
  Future<void> _jumpToMediaGroup(String nextKey) async {
    final preservedListOffset = _mediaGroupListScrollOffset;
    await _saveDraft(showToast: false);
    if (!mounted) return;
    _runOpenMediaGroupEditor(nextKey);
    _mediaGroupListScrollOffset = preservedListOffset;
    _scrollEditorToTop();
  }

  /// Stepper-индикатор для навигации между группами Осмотра. Заменяет
  /// прежнюю chip-row: 8 «шагов» соединены горизонтальной линией, активный
  /// шаг выделен тёмным кругом и bold-label'ом, заполненные — зелёным
  /// checkmark, проблемные — красным priority_high, пустые будущие —
  /// outlined кругом. Соединительные линии-сегменты окрашены по статусу
  /// предыдущего шага (зелёная/красная сплошная для пройденных, серая
  /// для будущих). Тап на любой шаг → `_jumpToMediaGroup`. Auto-scroll
  /// к активному шагу через `Scrollable.ensureVisible` (точное
  /// центрирование, без estimate-based фокусов).
  Widget _runMediaGroupStepper(String currentKey) {
    final groups = _SparkJoyMediaGroupRegistry.groups;
    final currentIndex = groups.indexWhere((g) => g.key == currentKey);

    // Auto-scroll к активному шагу через Scrollable.ensureVisible —
    // точное центрирование на основании реального RenderObject шага,
    // без estimate-based math. Срабатывает только когда активная
    // группа реально сменилась (guard через _mediaGroupChipLastScrolledKey).
    if (currentKey != _mediaGroupChipLastScrolledKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || currentIndex < 0) return;
        final stepKey = _mediaGroupStepKeys[currentKey];
        final keyContext = stepKey?.currentContext;
        if (keyContext == null) return;
        Scrollable.ensureVisible(
          keyContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
        _mediaGroupChipLastScrolledKey = currentKey;
      });
    }

    return SizedBox(
      // 36 (circle) + 6 (gap) + ~28 (2-line label) + 6 (top/bottom padding)
      height: 80,
      child: SingleChildScrollView(
        controller: _mediaGroupChipScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpace.md,
          vertical: SparkSpace.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              _stepNode(
                config: groups[i],
                isCurrent: groups[i].key == currentKey,
                isPast: i < currentIndex,
              ),
              if (i < groups.length - 1)
                _stepConnector(
                  // Сегмент между i и i+1 — пройден если предыдущий шаг
                  // (i) либо текущий, либо левее текущего. Цвет — по
                  // status'у i-го шага.
                  completed: i < currentIndex,
                  hasIssue: _groupHasIssueByKey(groups[i].key),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Один шаг stepper'а: круг (36px) с status-иконкой + короткий label
  /// под ним. Whole-tap-area = переход в группу через `_jumpToMediaGroup`.
  /// GlobalKey берётся из state-map'а `_mediaGroupStepKeys` (создаётся
  /// лениво, чтобы пережил rebuild'ы и `Scrollable.ensureVisible` работал
  /// по стабильному context'у).
  Widget _stepNode({
    required MediaGroupConfig config,
    required bool isCurrent,
    required bool isPast,
  }) {
    final state = _mediaState[config.key];
    final hasIssue = state != null && _groupHasIssue(state);
    final hasFiles = state != null && state.files.isNotEmpty;

    // Стиль кружка по приоритету: active > issue > done > empty.
    final Color circleBg;
    final Color circleBorder;
    final IconData circleIcon;
    final Color iconColor;
    if (isCurrent) {
      circleBg = kTertiaryColor;
      circleBorder = kTertiaryColor;
      // На активном — checkmark если уже заполнено, иначе нейтральный
      // dot, чтобы не ложно говорить «осмотрено».
      circleIcon = hasIssue
          ? Icons.priority_high_rounded
          : (hasFiles ? Icons.check_rounded : Icons.circle);
      iconColor = kWhiteColor;
    } else if (hasIssue) {
      circleBg = kSecondaryColor;
      circleBorder = kSecondaryColor;
      circleIcon = Icons.priority_high_rounded;
      iconColor = kWhiteColor;
    } else if (hasFiles) {
      circleBg = kGreenColor;
      circleBorder = kGreenColor;
      circleIcon = Icons.check_rounded;
      iconColor = kWhiteColor;
    } else {
      circleBg = kWhiteColor;
      circleBorder = isPast ? kBorderColor : kBorderColor;
      circleIcon = Icons.circle_outlined;
      iconColor = kBorderColor;
    }

    final stepKey = _mediaGroupStepKeys.putIfAbsent(
      config.key,
      () => GlobalKey(),
    );

    return InkWell(
      key: stepKey,
      onTap: isCurrent
          ? null
          : () {
              HapticFeedback.selectionClick();
              unawaited(_jumpToMediaGroup(config.key));
            },
      borderRadius: BorderRadius.circular(SparkRadius.md),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: Border.all(color: circleBorder, width: 2),
              ),
              alignment: Alignment.center,
              child: Icon(circleIcon, size: 18, color: iconColor),
            ),
            const SizedBox(height: SparkSpace.xs),
            MyText(
              text: config.shortLabel,
              size: SparkTextSize.caption,
              weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: kTertiaryColor,
              textAlign: TextAlign.center,
              maxLines: 2,
              textOverflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Соединительная линия между двумя шагами stepper'а. Толщина 2px,
  /// ширина 24px, выравнивание по центру круга (top: 17 = 36/2 - 1).
  /// Цвет: зелёный/красный сплошной для пройденных, серый для будущих.
  Widget _stepConnector({required bool completed, required bool hasIssue}) {
    final Color color;
    if (completed) {
      color = hasIssue ? kSecondaryColor : kGreenColor;
    } else {
      color = kBorderColor.withValues(alpha: 0.5);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 17),
      child: Container(width: 24, height: 2, color: color),
    );
  }

  /// Безопасный wrapper над `_groupHasIssue` — обрабатывает null state.
  bool _groupHasIssueByKey(String key) {
    final state = _mediaState[key];
    return state != null && _groupHasIssue(state);
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
    // «С заметкой» считаем строго по наличию текстового комментария.
    // Раньше использовался _mediaInspectionHasData, который true и для
    // тегов / noDamage / толщиномера / типа элемента — поэтому фото
    // только с тегом «Царапина» попадало и в «Замечания», и в
    // «С заметкой», что вводило юзера в заблуждение.
    final notesCount = state.files
        .where((file) => file.inspection.note.trim().isNotEmpty)
        .length;
    final statusLabel = !hasFiles
        ? 'Пусто'
        : (hasIssue
              ? 'Замечания'
              : (notesCount > 0 ? 'Есть заметки' : 'Готово'));
    // «Замечания» сигналим брендовым синим (kSecondaryColor) —
    // «здесь есть данные», без warning-вибраций. Красный остаётся
    // только для блокирующих ошибок (валидация, session expired).
    // Зелёный — для «без замечаний», нормально-OK состояния.
    final statusColor = !hasFiles
        ? kGreyColor
        : (hasIssue
              ? kSecondaryColor
              : (notesCount > 0 ? kGreenColor : kSecondaryColor));
    // leadBg/leadColor — единая брендовая заливка для любой
    // заполненной группы. Дифференциация issue vs ok-with-notes
    // идёт через cardBackground/cardBorder + status pill сверху,
    // дублировать leading-icon цветом смысла нет.
    final leadBg = hasFiles
        ? kSecondaryColor.withValues(alpha: 0.10)
        : kInputBgColor;
    final leadColor = hasFiles ? kSecondaryColor : kGreyColor;

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

    // Визуальная дифференциация секций осмотра:
    // 1) Синий tint фона + рамка → «есть замечания, инспектор
    //    зафиксировал»; нейтральный info-сигнал, не warning.
    // 2) Светло-зелёный tint + плотная зелёная рамка → fullyMarked
    //    без замечаний. Секция взгляду читается как «✓ done».
    // 3) Trailing chevron заменяется на ✓ когда секция fullyMarked.
    final cardBackground = isPressed
        ? kSecondaryColor.withValues(alpha: 0.02)
        : (hasIssue
              ? kSecondaryColor.withValues(alpha: 0.05)
              : (fullyMarked
                    ? kGreenColor.withValues(alpha: 0.04)
                    : kWhiteColor));
    final cardBorder = hasIssue
        ? kSecondaryColor.withValues(alpha: 0.35)
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
                                    icon: Icons.local_offer,
                                    text: 'Замечания $issueCount',
                                    color: kSecondaryColor,
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

  Widget _runMediaOverlayCornerEditButton({
    required bool hasInspection,
    required VoidCallback onTap,
  }) {
    final bgColor = hasInspection
        ? kSecondaryColor
        : Colors.black.withValues(alpha: 0.5);
    final iconData = hasInspection
        ? Icons.edit_note_rounded
        : Icons.add_rounded;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(iconData, size: 20, color: kWhiteColor),
        ),
      ),
    );
  }

  Widget _runMediaOverlayMicroDot({required Color color}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: kWhiteColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _runMediaOverlayVideoBadge(UploadedItem item) {
    if (!item.isVideo) return const SizedBox.shrink();
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
          const Icon(
            Icons.play_arrow_rounded,
            size: SparkTextSize.label,
            color: kWhiteColor,
          ),
          const SizedBox(width: SparkSpace.xxxs),
          MyText(
            text: 'Видео',
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
        child: DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(SparkRadius.xl),
          color: isBusy
              ? kSecondaryColor.withValues(alpha: 0.55)
              : kBorderColor.withValues(alpha: 0.85),
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kLightGreyColor,
              borderRadius: BorderRadius.circular(SparkRadius.xl),
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
                            color: kSecondaryColor,
                          ),
                          SizedBox(height: SparkSpace.sm),
                          MyText(
                            text: 'Фото / Видео',
                            size: SparkTextSize.body,
                            color: kSecondaryColor,
                            weight: FontWeight.w700,
                          ),
                        ],
                      ),
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
    // Та же семантика, что и в карточке группы выше: «С заметкой»
    // — только фото с непустым текстовым комментарием.
    final notedFiles = files
        .where((file) => file.inspection.note.trim().isNotEmpty)
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
                        if (notedFiles > 0)
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
                            background: kSecondaryColor.withValues(alpha: 0.12),
                            color: kSecondaryColor,
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
        const SizedBox(height: SparkSpace.md),
        // Stepper-индикатор прогресса осмотра по 8 группам.
        // Заменяет прежний chip-row + старую кнопку «К следующей
        // группе». Инспектор сразу видит сколько пройдено и куда
        // дальше, тапом по любому шагу прыгает в эту группу.
        _runMediaGroupStepper(groupKey),
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
                      ? Padding(
                          key: const ValueKey('media-select-hint'),
                          padding: const EdgeInsets.only(
                            bottom: SparkSpace.lg,
                            left: SparkSpace.xs,
                            right: SparkSpace.xs,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.touch_app_outlined,
                                size: SparkSize.iconSm,
                                color: kGreyColor,
                              ),
                              const SizedBox(width: SparkSpace.sm),
                              Expanded(
                                child: MyText(
                                  text:
                                      'Зажмите фото для выбора нескольких файлов.',
                                  size: SparkTextSize.bodyLg,
                                  color: kGreyColor,
                                ),
                              ),
                            ],
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
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColumns,
                crossAxisSpacing: SparkSpace.lg,
                mainAxisSpacing: SparkSpace.lg,
                childAspectRatio: 1.0,
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
                            if (_mediaGroupSelectMode)
                              Positioned(
                                left: SparkSpace.lg,
                                top: SparkSpace.lg,
                                child: _runMediaOverlaySelectionMarker(
                                  selected: selected,
                                ),
                              ),
                            if (!_mediaGroupSelectMode)
                              Positioned(
                                right: SparkSpace.lg,
                                top: SparkSpace.lg,
                                child: _runMediaOverlayCornerEditButton(
                                  hasInspection: hasInspection,
                                  onTap: () => _openMediaInspectionEditor(
                                    groupKey: groupKey,
                                    index: fileIndex,
                                  ),
                                ),
                              ),
                            if (!_mediaGroupSelectMode &&
                                (_mediaItemHasIssue(item) || hasInspection))
                              Positioned(
                                left: SparkSpace.lg,
                                bottom: SparkSpace.lg,
                                child: _runMediaOverlayMicroDot(
                                  color: _mediaItemHasIssue(item)
                                      ? kRedColor
                                      : kGreenColor,
                                ),
                              ),
                            if (!_mediaGroupSelectMode && item.isVideo)
                              Positioned(
                                right: SparkSpace.lg,
                                bottom: SparkSpace.lg,
                                child: _runMediaOverlayVideoBadge(item),
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

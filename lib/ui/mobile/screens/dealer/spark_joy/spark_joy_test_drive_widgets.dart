part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyTestDriveWidgetsMethods on _SparkJoyCreateReportScreenState {
  Widget _testDriveSubsystemCard({
    required String sectionLabel,
    required String tagScopeKey,
    required bool ok,
    required ValueChanged<bool> onOkChanged,
    required String okLabel,
    required List<String> selected,
    required ValueChanged<List<String>> onTagsChanged,
  }) {
    final selectedTagsCount = selected.length;
    final sectionInvalid = !ok && selectedTagsCount == 0;
    final statusLabel = ok
        ? 'Без замечаний'
        : sectionInvalid
        ? 'Обязательное поле'
        : 'Замечания: $selectedTagsCount';
    final statusColor = ok
        ? kGreenColor
        : sectionInvalid
        ? kRedColor
        : kYellowColor;
    final managingSeverity = _tdManagingTagSeverityByScope[tagScopeKey];
    final tagGroups = _testDriveTagGroups(
      tagScopeKey,
      includeDisabledDefaults: managingSeverity != null,
    );
    final disabledDefaults =
        (_mediaDisabledDefaultTagsByScope[tagScopeKey] ?? const <String>[])
            .map((tag) => tag.toLowerCase())
            .toSet();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: sectionLabel,
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
              ),
              _mediaMetaPill(
                icon: ok
                    ? Icons.check_circle_outline_rounded
                    : Icons.report_gmailerrorred_rounded,
                text: statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          InkWell(
            onTap: () {
              onOkChanged(!ok);
              _markDraftDirty();
            },
            borderRadius: BorderRadius.circular(SparkRadius.lg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.xl,
                vertical: SparkSpace.xl,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
                border: Border.all(
                  color: ok
                      ? kGreenColor.withValues(alpha: 0.45)
                      : kBorderColor,
                ),
                color: ok ? kGreenColor.withValues(alpha: 0.08) : kWhiteColor,
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SparkRadius.xs),
                      border: Border.all(
                        color: ok ? kGreenColor : kBorderColor,
                        width: 1.6,
                      ),
                      color: ok ? kGreenColor : kWhiteColor,
                    ),
                    child: ok
                        ? const Icon(
                            Icons.check_rounded,
                            size: SparkTextSize.label,
                            color: kWhiteColor,
                          )
                        : null,
                  ),
                  const SizedBox(width: SparkSpace.lg),
                  Expanded(
                    child: MyText(
                      text: okLabel,
                      size: SparkTextSize.body,
                      weight: FontWeight.w600,
                      color: ok ? kGreenColor : kTertiaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!ok) ...[
            const SizedBox(height: SparkSpace.md),
            ...tagGroups.map((group) {
              final isManaging = managingSeverity == group.severity;
              final customTagController = _tdCustomTagController(
                tagScopeKey,
                group.severity,
              );
              final customTagFocusNode = _tdCustomTagFocusNode(
                tagScopeKey,
                group.severity,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: SparkSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: group.title,
                            size: SparkTextSize.body,
                            color: _mediaTagGroupTitleColor(group),
                            weight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _dismissKeyboard();
                            _setStateSafely(() {
                              final current =
                                  _tdManagingTagSeverityByScope[tagScopeKey];
                              _tdManagingTagSeverityByScope[tagScopeKey] =
                                  current == group.severity
                                  ? null
                                  : group.severity;
                            });
                          },
                          icon: Icon(
                            isManaging
                                ? Icons.check_rounded
                                : Icons.settings_rounded,
                            size: SparkTextSize.title,
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                          ),
                          label: Text(
                            isManaging ? 'Готово' : 'Настроить',
                            style: const TextStyle(
                              fontSize: SparkTextSize.caption,
                              fontWeight: FontWeight.w700,
                              color: kSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SparkSpace.sm),
                    if (isManaging)
                      ReorderableListView.builder(
                        key: ValueKey(
                          'td-tag-manage-$tagScopeKey-${group.severity}',
                        ),
                        shrinkWrap: true,
                        buildDefaultDragHandles: false,
                        physics: const NeverScrollableScrollPhysics(),
                        proxyDecorator: _tagReorderProxyDecorator,
                        itemCount: group.options.length,
                        onReorder: (oldIndex, newIndex) {
                          _setStateSafely(() {
                            final adjusted = oldIndex < newIndex
                                ? newIndex - 1
                                : newIndex;
                            if (oldIndex == adjusted) return;

                            final reordered = [
                              ...group.options.map((tag) => tag.label),
                            ];
                            final moved = reordered.removeAt(oldIndex);
                            reordered.insert(adjusted, moved);

                            final baseline = [
                              ...(_mediaTagOrderByScope[tagScopeKey] ??
                                  tagGroups
                                      .expand(
                                        (entry) => entry.options.map(
                                          (tag) => tag.label,
                                        ),
                                      )
                                      .toList()),
                            ];
                            final normalized = <String>[];
                            for (final value in baseline) {
                              if (normalized.any(
                                (item) =>
                                    item.toLowerCase() == value.toLowerCase(),
                              )) {
                                continue;
                              }
                              normalized.add(value);
                            }

                            final groupSet = group.options
                                .map((tag) => tag.label.toLowerCase())
                                .toSet();
                            final withoutGroup = normalized
                                .where(
                                  (value) =>
                                      !groupSet.contains(value.toLowerCase()),
                                )
                                .toList();
                            var insertAt = normalized.indexWhere(
                              (value) => groupSet.contains(value.toLowerCase()),
                            );
                            if (insertAt < 0 ||
                                insertAt > withoutGroup.length) {
                              insertAt = withoutGroup.length;
                            }
                            withoutGroup.insertAll(insertAt, reordered);
                            _mediaTagOrderByScope[tagScopeKey] = withoutGroup;
                          });
                          _markDraftDirty();
                        },
                        itemBuilder: (context, index) {
                          final tag = group.options[index];
                          final lower = tag.label.toLowerCase();
                          final hidden =
                              !tag.isCustom && disabledDefaults.contains(lower);
                          return Container(
                            key: ValueKey(
                              'td-tag-item-$tagScopeKey-${group.severity}-${tag.label}',
                            ),
                            margin: const EdgeInsets.only(
                              bottom: SparkSpace.sm,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: SparkSpace.lg,
                              vertical: SparkSpace.md,
                            ),
                            decoration: BoxDecoration(
                              color: hidden
                                  ? kLightGreyColor.withValues(alpha: 0.55)
                                  : kWhiteColor,
                              borderRadius: BorderRadius.circular(
                                SparkRadius.md,
                              ),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ReorderableDelayedDragStartListener(
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: SparkSpace.xs,
                                        vertical: SparkSpace.xxs,
                                      ),
                                      child: MyText(
                                        text: tag.label,
                                        size: SparkTextSize.body,
                                        color: hidden
                                            ? kGreyColor
                                            : kTertiaryColor,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.drag_indicator_rounded,
                                  size: SparkTextSize.titleLg,
                                  color: kGreyColor,
                                ),
                                const SizedBox(width: SparkSpace.xs),
                                if (tag.isCustom)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(
                                      SparkRadius.pill,
                                    ),
                                    onTap: () {
                                      final nextSelected = selected
                                          .where(
                                            (value) =>
                                                value.toLowerCase() != lower,
                                          )
                                          .toList();
                                      _setStateSafely(() {
                                        final custom =
                                            [
                                              ...(_mediaCustomTagsByScope[tagScopeKey] ??
                                                  const <String>[]),
                                            ]..removeWhere(
                                              (value) =>
                                                  value.toLowerCase() == lower,
                                            );
                                        if (custom.isEmpty) {
                                          _mediaCustomTagsByScope.remove(
                                            tagScopeKey,
                                          );
                                        } else {
                                          _mediaCustomTagsByScope[tagScopeKey] =
                                              custom;
                                        }

                                        final serious =
                                            [
                                              ...(_mediaCustomSeriousTagsByScope[tagScopeKey] ??
                                                  const <String>[]),
                                            ]..removeWhere(
                                              (value) =>
                                                  value.toLowerCase() == lower,
                                            );
                                        if (serious.isEmpty) {
                                          _mediaCustomSeriousTagsByScope.remove(
                                            tagScopeKey,
                                          );
                                        } else {
                                          _mediaCustomSeriousTagsByScope[tagScopeKey] =
                                              serious;
                                        }

                                        final order =
                                            [
                                              ...(_mediaTagOrderByScope[tagScopeKey] ??
                                                  const <String>[]),
                                            ]..removeWhere(
                                              (value) =>
                                                  value.toLowerCase() == lower,
                                            );
                                        if (order.isEmpty) {
                                          _mediaTagOrderByScope.remove(
                                            tagScopeKey,
                                          );
                                        } else {
                                          _mediaTagOrderByScope[tagScopeKey] =
                                              order;
                                        }
                                      });
                                      if (nextSelected.length !=
                                          selected.length) {
                                        onTagsChanged(nextSelected);
                                      } else {
                                        _markDraftDirty();
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(SparkSpace.xs),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: SparkTextSize.title,
                                        color: kGreyColor,
                                      ),
                                    ),
                                  )
                                else
                                  InkWell(
                                    borderRadius: BorderRadius.circular(
                                      SparkRadius.pill,
                                    ),
                                    onTap: () {
                                      List<String>? nextSelected;
                                      _setStateSafely(() {
                                        final disabled = [
                                          ...(_mediaDisabledDefaultTagsByScope[tagScopeKey] ??
                                              const <String>[]),
                                        ];
                                        final disabledLower = disabled
                                            .map((value) => value.toLowerCase())
                                            .toSet();
                                        if (disabledLower.contains(lower)) {
                                          disabled.removeWhere(
                                            (value) =>
                                                value.toLowerCase() == lower,
                                          );
                                        } else {
                                          disabled.add(tag.label);
                                          nextSelected = selected
                                              .where(
                                                (value) =>
                                                    value.toLowerCase() !=
                                                    lower,
                                              )
                                              .toList();
                                        }
                                        if (disabled.isEmpty) {
                                          _mediaDisabledDefaultTagsByScope
                                              .remove(tagScopeKey);
                                        } else {
                                          _mediaDisabledDefaultTagsByScope[tagScopeKey] =
                                              disabled;
                                        }
                                      });
                                      if (nextSelected != null) {
                                        onTagsChanged(nextSelected!);
                                      } else {
                                        _markDraftDirty();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        SparkSpace.xs,
                                      ),
                                      child: Icon(
                                        hidden
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_rounded,
                                        size: SparkTextSize.title,
                                        color: hidden
                                            ? kGreyColor
                                            : kSecondaryColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      )
                    else if (group.options.isEmpty)
                      const MyText(
                        text: 'Теги скрыты в настройке',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: group.options.map((tag) {
                          final lower = tag.label.toLowerCase();
                          final active = selected.any(
                            (value) => value.toLowerCase() == lower,
                          );
                          return _chip(
                            label: tag.label,
                            selected: active,
                            selectedColor: _mediaTagColor(tag.severity),
                            onTap: () {
                              final next = [...selected];
                              if (active) {
                                next.removeWhere(
                                  (value) => value.toLowerCase() == lower,
                                );
                              } else {
                                next.add(tag.label);
                              }
                              onTagsChanged(next);
                            },
                          );
                        }).toList(),
                      ),
                    if (isManaging) ...[
                      const SizedBox(height: SparkSpace.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customTagController,
                              focusNode: customTagFocusNode,
                              textInputAction: TextInputAction.done,
                              onTapOutside: (_) => _dismissKeyboard(),
                              onSubmitted: (_) {
                                _addTestDriveCustomTag(
                                  scopeKey: tagScopeKey,
                                  severity: group.severity,
                                );
                              },
                              decoration: _fieldDecoration('Свой тег').copyWith(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: SparkSpace.sm),
                          SizedBox(
                            height: SparkSize.actionHeightSm,
                            child: OutlinedButton(
                              onPressed: () {
                                _addTestDriveCustomTag(
                                  scopeKey: tagScopeKey,
                                  severity: group.severity,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                side: const BorderSide(color: kBorderColor),
                              ),
                              child: const Text('Добавить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _testDriveConductedSelector() {
    Widget optionButton({
      required String title,
      required String mode,
      required Color activeColor,
      required IconData icon,
    }) {
      final isSelected = _tdMode == mode;
      return OutlinedButton(
        onPressed: () => _selectTdMode(mode),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 42),
          alignment: Alignment.centerLeft,
          side: BorderSide(
            color: isSelected
                ? activeColor.withValues(alpha: 0.55)
                : kBorderColor,
          ),
          backgroundColor: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : kWhiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.md),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: SparkTextSize.title,
              color: isSelected ? activeColor : kGreyColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: SparkTextSize.body,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeColor : kTertiaryColor,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: SparkMotion.fast,
              child: isSelected
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('td-selected'),
                      size: SparkTextSize.titleLg,
                      color: activeColor,
                    )
                  : const SizedBox.shrink(key: ValueKey('td-unselected')),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Тест-драйв проводился?',
            size: SparkTextSize.bodyLg,
            weight: FontWeight.w600,
          ),
          const SizedBox(height: SparkSpace.md),
          optionButton(
            title: 'Да, всё работает исправно',
            mode: _SparkJoyTestDriveRegistry.modeAllGood,
            activeColor: kGreenColor,
            icon: Icons.thumb_up_alt_outlined,
          ),
          const SizedBox(height: SparkSpace.sm),
          optionButton(
            title: 'Да, есть проблемы',
            mode: _SparkJoyTestDriveRegistry.modeProblems,
            activeColor: kYellowColor,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: SparkSpace.sm),
          optionButton(
            title: 'Нет',
            mode: _SparkJoyTestDriveRegistry.modeNotConducted,
            activeColor: kRedColor,
            icon: Icons.block_outlined,
          ),
        ],
      ),
    );
  }

  Widget _testDriveNoteBlock(String placeholder) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: SparkTextSize.label,
                color: kGreyColor,
              ),
              SizedBox(width: SparkSpace.xs + 1),
              MyText(
                text: 'Комментарий',
                size: SparkTextSize.caption,
                color: kGreyColor,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          _commentInputPanel(
            controller: _tdNoteController,
            hint: placeholder,
            isDictating: _tdIsDictating,
            onToggleDictation: () async {
              if (_tdIsDictating) {
                await _stopTdDictation();
              } else {
                await _startTdDictation();
              }
            },
            onAiFormat: () {
              _formatCommentWithAi(_tdNoteController);
              _markDraftDirty();
              _setStateSafely(() {});
            },
          ),
          const SizedBox(height: SparkSpace.md),
          _commentAudioFilesBlock(
            files: _tdCommentAudioFiles,
            playingIndex: _tdCommentPlayingAudioIndex,
            isRecording: _isCommentRecording('td_comment'),
            recordingLabel: _commentRecordingLabel('td_comment'),
            onToggleRecording: _toggleTdCommentRecording,
            onTogglePlay: _toggleTdCommentAudioPlayback,
            onRemoveAt: (index) {
              _setStateSafely(() {
                final next = [..._tdCommentAudioFiles]..removeAt(index);
                _tdCommentAudioFiles = next;
                if (_tdCommentPlayingAudioIndex == index) {
                  _tdCommentPlayingAudioIndex = -1;
                  unawaited(_sectionCommentAudioPlayer.stop());
                } else if (_tdCommentPlayingAudioIndex > index) {
                  _tdCommentPlayingAudioIndex -= 1;
                }
              });
              _markDraftDirty();
            },
          ),
        ],
      ),
    );
  }
}

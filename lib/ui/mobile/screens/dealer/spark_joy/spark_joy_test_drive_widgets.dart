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
    // Picker takes the full catalog (system + custom + previously-
    // disabled defaults) and renders its own filter / search; no need
    // to pre-trim by visibility here.
    final tagGroups =
        _testDriveTagGroups(tagScopeKey, includeDisabledDefaults: true);

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
            Builder(
              builder: (pillCtx) {
                final allOptions = tagGroups
                    .expand((g) => g.options)
                    .toList(growable: false);
                final selectedCount = selected.length;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SparkRadius.lg),
                    onTap: () async {
                      final result = await _showSparkJoyTagPicker(
                        pillCtx,
                        title: 'Повреждения',
                        options: allOptions,
                        initialSelected: List<String>.from(selected),
                        initialOrder: List<String>.from(
                          _mediaTagOrderByScope[tagScopeKey] ??
                              const <String>[],
                        ),
                        onCreateCustom: (name, severity) async {
                          // Server side fires-and-resolves; treat the
                          // create as locally successful even if the
                          // refetch can't pin an id immediately —
                          // _loadTagIdsFromServer will reconcile next
                          // time.
                          await _syncTestDriveCustomTag(
                            tagName: name,
                            severity: severity,
                          );
                          final lower = name.toLowerCase();
                          final next = [
                            ...?_mediaCustomTagsByScope[tagScopeKey],
                          ];
                          if (!next.any(
                            (s) => s.toLowerCase() == lower,
                          )) {
                            next.add(name);
                          }
                          _mediaCustomTagsByScope[tagScopeKey] = next;
                          if (severity == 'serious') {
                            final ns = [
                              ...?_mediaCustomSeriousTagsByScope[tagScopeKey],
                            ];
                            if (!ns.any(
                              (s) => s.toLowerCase() == lower,
                            )) {
                              ns.add(name);
                            }
                            _mediaCustomSeriousTagsByScope[tagScopeKey] =
                                ns;
                          }
                          final order = [
                            ...?_mediaTagOrderByScope[tagScopeKey],
                          ];
                          if (!order.any(
                            (s) => s.toLowerCase() == lower,
                          )) {
                            order.add(name);
                          }
                          _mediaTagOrderByScope[tagScopeKey] = order;
                          return true;
                        },
                        onDeleteCustom: (name) async {
                          final removed = await _removeTestDriveCustomTag(
                            tagName: name,
                          );
                          if (!removed) return false;
                          final lower = name.toLowerCase();
                          final pruned =
                              (_mediaCustomTagsByScope[tagScopeKey] ??
                                      const <String>[])
                                  .where(
                                    (s) => s.toLowerCase() != lower,
                                  )
                                  .toList();
                          if (pruned.isEmpty) {
                            _mediaCustomTagsByScope.remove(tagScopeKey);
                          } else {
                            _mediaCustomTagsByScope[tagScopeKey] = pruned;
                          }
                          final prunedSerious =
                              (_mediaCustomSeriousTagsByScope[tagScopeKey] ??
                                      const <String>[])
                                  .where(
                                    (s) => s.toLowerCase() != lower,
                                  )
                                  .toList();
                          if (prunedSerious.isEmpty) {
                            _mediaCustomSeriousTagsByScope.remove(
                              tagScopeKey,
                            );
                          } else {
                            _mediaCustomSeriousTagsByScope[tagScopeKey] =
                                prunedSerious;
                          }
                          final prunedOrder =
                              (_mediaTagOrderByScope[tagScopeKey] ??
                                      const <String>[])
                                  .where(
                                    (s) => s.toLowerCase() != lower,
                                  )
                                  .toList();
                          if (prunedOrder.isEmpty) {
                            _mediaTagOrderByScope.remove(tagScopeKey);
                          } else {
                            _mediaTagOrderByScope[tagScopeKey] =
                                prunedOrder;
                          }
                          return true;
                        },
                        // Spec: co-occurrence sort is inspection-only.
                        // Server returns alphabetic for test_drive
                        // regardless of selectedTagIds — skip the
                        // refetch entirely (returning null leaves the
                        // sheet's local order untouched).
                        onRefreshOrder: (_) async => null,
                      );
                      if (result == null) return;
                      onTagsChanged(result);
                    },
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: SparkSize.inputHeightLg,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.xl,
                        vertical: SparkSpace.md,
                      ),
                      decoration: BoxDecoration(
                        color: kInputBgColor,
                        border: Border.all(color: kBorderColor),
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            size: SparkSize.iconLg,
                            color: kGreyColor,
                          ),
                          const SizedBox(width: SparkSpace.md),
                          Expanded(
                            child: MyText(
                              text: selectedCount == 0
                                  ? 'Выбрать повреждения'
                                  : 'Повреждения ($selectedCount)',
                              size: SparkTextSize.body,
                              weight: FontWeight.w600,
                              color: selectedCount == 0
                                  ? kGreyColor
                                  : kTertiaryColor,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: kGreyColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
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

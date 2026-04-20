part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaInspectionEditorMethods
    on _SparkJoyCreateReportScreenState {
  String _mediaElementLabel(String groupKey, String? elementType) {
    if (elementType == null || elementType.trim().isEmpty) return '';
    final options = _mediaElementOptions(groupKey);
    for (final option in options) {
      if (option.id == elementType) return option.label;
    }
    return '';
  }

  Future<bool> _runOpenMediaInspectionEditor({
    required String groupKey,
    required int index,
    List<int>? applyToIndexes,
    bool saveDraftOnClose = true,
  }) async {
    // Defense in depth: the lightbox hides the edit-note entry point
    // in read-only mode, but the editor may also be reached via other
    // pathways (bulk-apply, deep-link, future shortcuts). Silently
    // no-op — callers treat `false` as "nothing changed", which is the
    // truthful answer for a finalized report.
    if (widget.readOnly) return false;
    final group = _mediaState[groupKey];
    if (group == null || index < 0 || index >= group.files.length) return false;

    final targetIndexes =
        (applyToIndexes ?? const <int>[])
            .where((value) => value >= 0 && value < group.files.length)
            .toSet()
            .toList()
          ..sort();
    if (targetIndexes.isEmpty) {
      targetIndexes.add(index);
    }

    final item = group.files[index];
    final targetUrls = targetIndexes
        .map((itemIndex) => group.files[itemIndex].dataUrl)
        .where((url) => url.trim().isNotEmpty)
        .toSet();
    final basePartInspection = _mediaPartInspectionIsEmpty(group.partInspection)
        ? _deriveGroupPartInspection(
            files: group.files,
            fallbackNote: group.note,
          )
        : group.partInspection;
    var noDamage = basePartInspection.noDamage;
    var selectedTags = [...item.inspection.tags];
    var elementType = basePartInspection.elementType;
    var audioRecordings = [...basePartInspection.audioRecordings];
    var tagPhotosByTag = <String, List<String>>{
      for (final entry in basePartInspection.tagPhotos.entries)
        entry.key: [...entry.value],
    };
    if (selectedTags.isEmpty && !basePartInspection.noDamage) {
      selectedTags = tagPhotosByTag.entries
          .where((entry) => entry.value.contains(item.dataUrl))
          .map((entry) => entry.key)
          .toList();
    }
    final supportsPaint = _mediaSupportsPaintThickness(groupKey);
    var paintFrom = basePartInspection.paintFrom ?? 80.0;
    var paintTo = basePartInspection.paintTo ?? 200.0;
    var customTagsByScope = <String, List<String>>{
      for (final entry in _mediaCustomTagsByScope.entries)
        entry.key: [...entry.value],
    };
    var customSeriousTagsByScope = <String, List<String>>{
      for (final entry in _mediaCustomSeriousTagsByScope.entries)
        entry.key: [...entry.value],
    };
    var disabledDefaultTagsByScope = <String, List<String>>{
      for (final entry in _mediaDisabledDefaultTagsByScope.entries)
        entry.key: [...entry.value],
    };
    var tagOrderByScope = <String, List<String>>{
      for (final entry in _mediaTagOrderByScope.entries)
        entry.key: [...entry.value],
    };
    var showElementError = false;
    String? managingTagSeverity;
    var isRecording = false;
    var recordingDuration = 0;
    var isDictating = false;
    var speechInitialized = false;
    var speechAvailable = false;
    var playingAudioIndex = -1;
    var dialogActive = true;
    var shouldRecord = false;
    var shouldDictate = false;

    final noteController = TextEditingController(
      text: basePartInspection.note.trim().isEmpty
          ? item.inspection.note
          : basePartInspection.note,
    );
    final customTagControllers = <String, TextEditingController>{
      'serious': TextEditingController(),
      'minor': TextEditingController(),
    };
    final customTagFocusNodes = <String, FocusNode>{
      'serious': FocusNode(),
      'minor': FocusNode(),
    };
    var paintToolsExpanded = false;
    final recorder = AudioRecorder();
    final player = AudioPlayer();
    final speechToText = SpeechToText();
    StreamSubscription<Uint8List>? recordSubscription;
    StreamSubscription<void>? playerCompleteSubscription;
    BytesBuilder? recordBuffer;
    Timer? recordingTimer;

    Future<void> showMessage(String text) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }

    Future<void> startRecording(StateSetter setLocalState) async {
      shouldRecord = true;
      if (isRecording) return;

      final hasPermission =
          _microphonePermissionGranted || await recorder.hasPermission();
      if (!hasPermission) {
        shouldRecord = false;
        await showMessage('Нет доступа к микрофону');
        return;
      }
      _microphonePermissionGranted = true;

      try {
        recordBuffer = BytesBuilder(copy: false);
        await recordSubscription?.cancel();
        recordSubscription =
            (await recorder.startStream(
              const RecordConfig(
                encoder: AudioEncoder.pcm16bits,
                sampleRate: 16000,
                numChannels: 1,
              ),
            )).listen((chunk) {
              recordBuffer?.add(chunk);
            });
        recordingTimer?.cancel();
        recordingDuration = 0;
        recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!dialogActive) return;
          setLocalState(() => recordingDuration += 1);
        });
        if (!shouldRecord) {
          await recorder.stop();
          recordingTimer?.cancel();
          recordingTimer = null;
          await recordSubscription?.cancel();
          recordSubscription = null;
          recordBuffer = null;
          return;
        }
        if (!dialogActive) return;
        setLocalState(() {
          isRecording = true;
        });
      } catch (_) {
        shouldRecord = false;
        await showMessage('Не удалось начать запись');
      }
    }

    Future<void> stopRecording(
      StateSetter setLocalState, {
      bool keepResult = true,
    }) async {
      shouldRecord = false;
      if (!isRecording && recordBuffer == null) return;

      try {
        await recorder.stop();
      } catch (_) {}

      recordingTimer?.cancel();
      recordingTimer = null;
      await recordSubscription?.cancel();
      recordSubscription = null;

      final pcmBytes = recordBuffer?.takeBytes() ?? Uint8List(0);
      recordBuffer = null;

      if (keepResult && pcmBytes.isNotEmpty) {
        final wavBytes = _pcm16ToWav(pcmBytes, sampleRate: 16000);
        String? stored;
        if (kIsWeb) {
          stored = 'data:audio/wav;base64,${base64Encode(wavBytes)}';
        } else {
          stored = await _persistBytesToAppStorage(
            bytes: wavBytes,
            mimeType: 'audio/wav',
            prefix: '${groupKey}_part_audio',
          );
        }
        if ((stored ?? '').trim().isNotEmpty) {
          audioRecordings = [...audioRecordings, stored!.trim()];
        } else {
          await showMessage('Не удалось сохранить аудио локально');
        }
      }

      if (!dialogActive) return;
      setLocalState(() {
        isRecording = false;
        recordingDuration = 0;
      });
    }

    Future<void> ensureSpeech(StateSetter setLocalState) async {
      if (speechInitialized) return;
      speechInitialized = true;
      if (_speechPermissionGranted) {
        speechAvailable = await speechToText.initialize(
          onStatus: (status) {
            if (!dialogActive) return;
            if (status == 'done' || status == 'notListening') {
              setLocalState(() => isDictating = false);
            }
          },
          onError: (_) {
            if (!dialogActive) return;
            setLocalState(() => isDictating = false);
          },
        );
        return;
      }
      speechAvailable = await speechToText.initialize(
        onStatus: (status) {
          if (!dialogActive) return;
          if (status == 'done' || status == 'notListening') {
            setLocalState(() => isDictating = false);
          }
        },
        onError: (_) {
          if (!dialogActive) return;
          setLocalState(() => isDictating = false);
        },
      );
      if (speechAvailable) {
        _speechPermissionGranted = true;
      }
      if (!speechAvailable) {
        await showMessage('Надиктовка недоступна в этом браузере');
      }
    }

    Future<void> startDictation(StateSetter setLocalState) async {
      shouldDictate = true;
      if (isDictating) return;
      await ensureSpeech(setLocalState);
      if (!speechAvailable) return;
      if (!shouldDictate) return;
      try {
        await speechToText.listen(
          localeId: 'ru_RU',
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.dictation,
            partialResults: false,
            cancelOnError: true,
          ),
          onResult: (result) {
            if (!result.finalResult) return;
            final transcript = result.recognizedWords.trim();
            if (transcript.isEmpty) return;

            final previous = noteController.text.trimRight();
            final separator =
                previous.isEmpty ||
                    previous.endsWith(' ') ||
                    previous.endsWith('\n')
                ? ''
                : ' ';
            final next = '$previous$separator$transcript';
            noteController
              ..text = next
              ..selection = TextSelection.collapsed(offset: next.length);
            if (!dialogActive) return;
            setLocalState(() {});
          },
        );
        if (!dialogActive) return;
        setLocalState(() => isDictating = true);
      } catch (_) {
        shouldDictate = false;
        await showMessage('Не удалось запустить надиктовку');
      }
    }

    Future<void> stopDictation(StateSetter setLocalState) async {
      shouldDictate = false;
      if (!isDictating) return;
      try {
        await speechToText.stop();
      } catch (_) {}
      if (!dialogActive) return;
      setLocalState(() => isDictating = false);
    }

    String recordingLabel() {
      final minutes = (recordingDuration ~/ 60).toString();
      final seconds = (recordingDuration % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    void formatNoteWithAi(StateSetter setLocalState) {
      final text = noteController.text.trim();
      if (text.isEmpty) return;
      final sentences = text
          .replaceAll(RegExp(r'([.!?])\s+'), r'$1\n')
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (sentences.isEmpty) return;

      final paragraphs = <String>[];
      final current = <String>[];
      for (var i = 0; i < sentences.length; i++) {
        current.add(sentences[i]);
        if (current.length >= 2 || i == sentences.length - 1) {
          paragraphs.add(current.join(' '));
          current.clear();
        }
      }
      final formatted = paragraphs.join('\n\n');
      noteController
        ..text = formatted
        ..selection = TextSelection.collapsed(offset: formatted.length);
      setLocalState(() {});
    }

    bool? saved;
    try {
      saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setLocalState) {
                playerCompleteSubscription ??= player.onPlayerComplete.listen((
                  _,
                ) {
                  if (!dialogActive) return;
                  setLocalState(() => playingAudioIndex = -1);
                });

                final elementOptions = _mediaElementOptions(groupKey);
                final isKeyboardOpen =
                    MediaQuery.viewInsetsOf(context).bottom > 0;
                final requiresElementType = elementOptions.isNotEmpty;
                final elementChosen =
                    !requiresElementType ||
                    (elementType ?? '').trim().isNotEmpty;
                final canEditDetails = !requiresElementType || elementChosen;
                final scopeKey = _mediaTagScopeKey(
                  groupKey,
                  elementType: elementType,
                );
                final tagGroups = _mediaTagGroups(
                  groupKey,
                  elementType: elementType,
                  customTagsByScope: customTagsByScope,
                  customSeriousTagsByScope: customSeriousTagsByScope,
                  disabledDefaultTagsByScope: disabledDefaultTagsByScope,
                  tagOrderByScope: tagOrderByScope,
                );
                final tagGroupsAll = _mediaTagGroups(
                  groupKey,
                  elementType: elementType,
                  customTagsByScope: customTagsByScope,
                  customSeriousTagsByScope: customSeriousTagsByScope,
                  disabledDefaultTagsByScope: disabledDefaultTagsByScope,
                  tagOrderByScope: tagOrderByScope,
                  includeDisabledDefaults: true,
                );
                final disabledDefaultsInScope =
                    disabledDefaultTagsByScope[scopeKey] ?? const <String>[];
                void addCustomTag(String severity) {
                  final customTagController = customTagControllers[severity];
                  final customTagFocusNode = customTagFocusNodes[severity];
                  if (customTagController == null ||
                      customTagFocusNode == null) {
                    return;
                  }
                  final input = customTagController.text.trim();
                  if (input.isEmpty) return;

                  // Sync the custom tag to the server (fire-and-forget).
                  unawaited(
                    _syncInspectionCustomTag(
                      groupKey: groupKey,
                      tagName: input,
                      severity: severity,
                    ),
                  );

                  final next = customTagsByScope[scopeKey] != null
                      ? [...customTagsByScope[scopeKey]!]
                      : <String>[];

                  String selectedValue = input;
                  final lower = input.toLowerCase();
                  for (final tag in next) {
                    if (tag.toLowerCase() == lower) {
                      selectedValue = tag;
                      break;
                    }
                  }
                  if (!next.any((tag) => tag.toLowerCase() == lower)) {
                    next.add(input);
                    selectedValue = input;
                  }
                  customTagsByScope[scopeKey] = next;
                  final customSerious =
                      customSeriousTagsByScope[scopeKey] != null
                      ? [...customSeriousTagsByScope[scopeKey]!]
                      : <String>[];
                  customSerious.removeWhere(
                    (tag) => tag.toLowerCase() == selectedValue.toLowerCase(),
                  );
                  if (severity == 'serious') {
                    customSerious.add(selectedValue);
                  }
                  if (customSerious.isEmpty) {
                    customSeriousTagsByScope.remove(scopeKey);
                  } else {
                    customSeriousTagsByScope[scopeKey] = customSerious;
                  }
                  disabledDefaultTagsByScope[scopeKey] =
                      (disabledDefaultTagsByScope[scopeKey] ?? const <String>[])
                          .where((tag) => tag.toLowerCase() != lower)
                          .toList();
                  final baselineTagGroups = _mediaTagGroups(
                    groupKey,
                    elementType: elementType,
                    customTagsByScope: customTagsByScope,
                    customSeriousTagsByScope: customSeriousTagsByScope,
                    disabledDefaultTagsByScope: disabledDefaultTagsByScope,
                    tagOrderByScope: tagOrderByScope,
                    includeDisabledDefaults: true,
                  );
                  final baselineOrder = [
                    ...(tagOrderByScope[scopeKey] ??
                        baselineTagGroups
                            .expand(
                              (entry) => entry.options.map((tag) => tag.label),
                            )
                            .toList()),
                  ];
                  final order = <String>[];
                  for (final value in baselineOrder) {
                    if (order.any(
                      (item) => item.toLowerCase() == value.toLowerCase(),
                    )) {
                      continue;
                    }
                    order.add(value);
                  }
                  order.removeWhere(
                    (tag) => tag.toLowerCase() == selectedValue.toLowerCase(),
                  );
                  order.add(selectedValue);
                  tagOrderByScope[scopeKey] = order;
                  if (!selectedTags.any(
                    (tag) => tag.toLowerCase() == selectedValue.toLowerCase(),
                  )) {
                    selectedTags.add(selectedValue);
                  }
                  managingTagSeverity = severity;
                  customTagController.clear();
                  setLocalState(() {});
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dialogActive || !customTagFocusNode.canRequestFocus) {
                      return;
                    }
                    customTagFocusNode.requestFocus();
                  });
                }

                _MediaTagGroup? findGroupBySeverity(
                  List<_MediaTagGroup> groups,
                  String severity,
                ) {
                  for (final group in groups) {
                    if (group.severity == severity) return group;
                  }
                  return null;
                }

                Future<void> closeEditorDiscard() async {
                  await stopDictation(setLocalState);
                  await stopRecording(setLocalState, keepResult: false);
                  await player.stop();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(false);
                }

                Future<void> saveEditor() async {
                  final requiresElementType = _mediaElementOptions(
                    groupKey,
                  ).isNotEmpty;
                  if (requiresElementType &&
                      (elementType ?? '').trim().isEmpty) {
                    setLocalState(() => showElementError = true);
                    return;
                  }
                  await stopDictation(setLocalState);
                  await stopRecording(setLocalState);
                  await player.stop();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);
                }

                return Scaffold(
                  backgroundColor: kWhiteColor,
                  body: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SparkSpace.md,
                            SparkSpace.xs,
                            SparkSpace.md,
                            SparkSpace.sm,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    unawaited(closeEditorDiscard()),
                                icon: const Icon(Icons.arrow_back_rounded),
                                tooltip: 'Назад',
                              ),
                              const SizedBox(width: SparkSpace.sm),
                              const Expanded(
                                child: MyText(
                                  text: 'Заметка элемента',
                                  size: SparkTextSize.titleLg,
                                  weight: FontWeight.w800,
                                  lineHeight: 1.30,
                                  tracking: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SparkSpace.xxxl,
                              SparkSpace.xxl,
                              SparkSpace.xxxl,
                              SparkSpace.md,
                            ),
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: SizedBox(
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      isDense: true,
                                      initialValue: (elementType ?? '').isEmpty
                                          ? null
                                          : elementType,
                                      decoration: _fieldDecoration('Элемент')
                                          .copyWith(
                                            errorText: showElementError
                                                ? 'Выберите тип элемента'
                                                : null,
                                          ),
                                      selectedItemBuilder: (context) {
                                        return elementOptions.map((option) {
                                          return Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              option.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList();
                                      },
                                      items: elementOptions.map((option) {
                                        return DropdownMenuItem<String>(
                                          value: option.id,
                                          child: Text(
                                            option.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setLocalState(() {
                                          elementType = value;
                                          selectedTags = [];
                                          noDamage = false;
                                          managingTagSeverity = null;
                                          showElementError = false;
                                        });
                                      },
                                    ),
                                    if (canEditDetails && supportsPaint) ...[
                                      const SizedBox(height: SparkSpace.lg),
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            SparkRadius.md,
                                          ),
                                          border: Border.all(
                                            color: kBorderColor,
                                          ),
                                        ),
                                        child: ExpansionTile(
                                          key: ValueKey(
                                            'paint-tools-$paintToolsExpanded',
                                          ),
                                          title: const MyText(
                                            text: 'Толщина ЛКП (дополнительно)',
                                            size: SparkTextSize.body,
                                            weight: FontWeight.w700,
                                          ),
                                          initiallyExpanded: paintToolsExpanded,
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: SparkSpace.lg,
                                              ),
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                                SparkSpace.lg,
                                                0,
                                                SparkSpace.lg,
                                                SparkSpace.lg,
                                              ),
                                          onExpansionChanged: (expanded) {
                                            setLocalState(
                                              () =>
                                                  paintToolsExpanded = expanded,
                                            );
                                          },
                                          children: [
                                            _paintRangeBlock(
                                              title: 'Толщина окраса',
                                              from: paintFrom,
                                              to: paintTo,
                                              onChanged: (values) {
                                                setLocalState(() {
                                                  paintFrom = values.start
                                                      .roundToDouble();
                                                  paintTo = values.end
                                                      .roundToDouble();
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (canEditDetails) ...[
                                      const SizedBox(height: SparkSpace.lg),
                                      InkWell(
                                        onTap: () {
                                          setLocalState(() {
                                            noDamage = !noDamage;
                                            if (noDamage) {
                                              selectedTags = [];
                                              managingTagSeverity = null;
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(
                                          SparkRadius.md,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              SparkRadius.md,
                                            ),
                                            border: Border.all(
                                              color: noDamage
                                                  ? kGreenColor
                                                  : kBorderColor,
                                            ),
                                            color: noDamage
                                                ? kGreenColor.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : kWhiteColor,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                noDamage
                                                    ? Icons.check_box
                                                    : Icons
                                                          .check_box_outline_blank,
                                                color: noDamage
                                                    ? kGreenColor
                                                    : kGreyColor,
                                              ),
                                              const SizedBox(
                                                width: SparkSpace.md,
                                              ),
                                              Expanded(
                                                child: MyText(
                                                  text: _mediaNoDamageLabel(
                                                    groupKey,
                                                  ),
                                                  size: SparkTextSize.body,
                                                  weight: FontWeight.w600,
                                                  color: noDamage
                                                      ? kGreenColor
                                                      : kTertiaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (canEditDetails && !noDamage) ...[
                                      const SizedBox(height: SparkSpace.lg),
                                      if (tagGroupsAll.isEmpty)
                                        const MyText(
                                          text:
                                              'Для выбранного элемента теги не заданы',
                                          size: SparkTextSize.caption,
                                          color: kGreyColor,
                                        )
                                      else
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: tagGroupsAll.map((group) {
                                            final groupTags = group.options;
                                            if (groupTags.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            final visibleGroup =
                                                findGroupBySeverity(
                                                  tagGroups,
                                                  group.severity,
                                                );
                                            final visibleOptions =
                                                visibleGroup?.options ??
                                                const <_MediaTagOption>[];
                                            final isManaging =
                                                managingTagSeverity ==
                                                group.severity;
                                            final customTagController =
                                                customTagControllers[group
                                                    .severity];
                                            final customTagFocusNode =
                                                customTagFocusNodes[group
                                                    .severity];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: MyText(
                                                          text: group.title,
                                                          size: SparkTextSize
                                                              .body,
                                                          color:
                                                              _mediaTagGroupTitleColor(
                                                                group,
                                                              ),
                                                          weight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      TextButton.icon(
                                                        onPressed: () {
                                                          setLocalState(() {
                                                            if (isManaging) {
                                                              managingTagSeverity =
                                                                  null;
                                                            } else {
                                                              managingTagSeverity =
                                                                  group
                                                                      .severity;
                                                            }
                                                          });
                                                        },
                                                        icon: Icon(
                                                          isManaging
                                                              ? Icons
                                                                    .check_rounded
                                                              : Icons
                                                                    .settings_rounded,
                                                          size: SparkTextSize
                                                              .title,
                                                        ),
                                                        label: Text(
                                                          isManaging
                                                              ? 'Готово'
                                                              : 'Настроить',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: SparkSpace.sm,
                                                  ),
                                                  if (isManaging) ...[
                                                    ReorderableListView.builder(
                                                      key: ValueKey(
                                                        'tag-manage-$scopeKey-${group.severity}',
                                                      ),
                                                      shrinkWrap: true,
                                                      buildDefaultDragHandles:
                                                          false,
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      proxyDecorator:
                                                          _tagReorderProxyDecorator,
                                                      itemCount:
                                                          groupTags.length,
                                                      onReorder: (oldIndex, newIndex) {
                                                        setLocalState(() {
                                                          final adjusted =
                                                              oldIndex <
                                                                  newIndex
                                                              ? newIndex - 1
                                                              : newIndex;
                                                          if (oldIndex ==
                                                              adjusted) {
                                                            return;
                                                          }

                                                          final reordered = [
                                                            ...groupTags.map(
                                                              (tag) =>
                                                                  tag.label,
                                                            ),
                                                          ];
                                                          final moved =
                                                              reordered
                                                                  .removeAt(
                                                                    oldIndex,
                                                                  );
                                                          reordered.insert(
                                                            adjusted,
                                                            moved,
                                                          );

                                                          final baseline = [
                                                            ...(tagOrderByScope[scopeKey] ??
                                                                tagGroupsAll
                                                                    .expand(
                                                                      (
                                                                        entry,
                                                                      ) => entry
                                                                          .options
                                                                          .map(
                                                                            (
                                                                              tag,
                                                                            ) =>
                                                                                tag.label,
                                                                          ),
                                                                    )
                                                                    .toList()),
                                                          ];
                                                          final normalized =
                                                              <String>[];
                                                          for (final value
                                                              in baseline) {
                                                            if (normalized.any(
                                                              (item) =>
                                                                  item
                                                                      .toLowerCase() ==
                                                                  value
                                                                      .toLowerCase(),
                                                            )) {
                                                              continue;
                                                            }
                                                            normalized.add(
                                                              value,
                                                            );
                                                          }

                                                          final groupSet = groupTags
                                                              .map(
                                                                (tag) => tag
                                                                    .label
                                                                    .toLowerCase(),
                                                              )
                                                              .toSet();
                                                          final withoutGroup =
                                                              normalized
                                                                  .where(
                                                                    (
                                                                      value,
                                                                    ) => !groupSet
                                                                        .contains(
                                                                          value
                                                                              .toLowerCase(),
                                                                        ),
                                                                  )
                                                                  .toList();
                                                          var insertAt = normalized
                                                              .indexWhere(
                                                                (
                                                                  value,
                                                                ) => groupSet
                                                                    .contains(
                                                                      value
                                                                          .toLowerCase(),
                                                                    ),
                                                              );
                                                          if (insertAt < 0 ||
                                                              insertAt >
                                                                  withoutGroup
                                                                      .length) {
                                                            insertAt =
                                                                withoutGroup
                                                                    .length;
                                                          }
                                                          withoutGroup
                                                              .insertAll(
                                                                insertAt,
                                                                reordered,
                                                              );
                                                          tagOrderByScope[scopeKey] =
                                                              withoutGroup;
                                                        });
                                                      },
                                                      itemBuilder: (context, index) {
                                                        final tag =
                                                            groupTags[index];
                                                        final hidden =
                                                            !tag.isCustom &&
                                                            disabledDefaultsInScope.any(
                                                              (value) =>
                                                                  value
                                                                      .toLowerCase() ==
                                                                  tag.label
                                                                      .toLowerCase(),
                                                            );

                                                        return Container(
                                                          key: ValueKey(
                                                            'tag-item-$scopeKey-${group.severity}-${tag.label}',
                                                          ),
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 6,
                                                              ),
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 6,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            border: Border.all(
                                                              color:
                                                                  kBorderColor,
                                                            ),
                                                            color: hidden
                                                                ? kInputBgColor
                                                                : kWhiteColor,
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: ReorderableDelayedDragStartListener(
                                                                  index: index,
                                                                  child: Padding(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          4,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    child: MyText(
                                                                      text: tag
                                                                          .label,
                                                                      size: SparkTextSize
                                                                          .body,
                                                                      color:
                                                                          hidden
                                                                          ? kGreyColor
                                                                          : kTertiaryColor,
                                                                      weight: FontWeight
                                                                          .w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const Icon(
                                                                Icons
                                                                    .drag_indicator_rounded,
                                                                size:
                                                                    SparkTextSize
                                                                        .titleLg,
                                                                color:
                                                                    kGreyColor,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              if (tag.isCustom)
                                                                InkWell(
                                                                  onTap: () {
                                                                    unawaited(
                                                                      _removeInspectionCustomTag(
                                                                        groupKey: groupKey,
                                                                        tagName: tag.label,
                                                                      ),
                                                                    );
                                                                    setLocalState(() {
                                                                      final next =
                                                                          (customTagsByScope[scopeKey] ??
                                                                                  const <String>[])
                                                                              .where(
                                                                                (
                                                                                  value,
                                                                                ) =>
                                                                                    value.toLowerCase() !=
                                                                                    tag.label.toLowerCase(),
                                                                              )
                                                                              .toList();
                                                                      if (next
                                                                          .isEmpty) {
                                                                        customTagsByScope.remove(
                                                                          scopeKey,
                                                                        );
                                                                      } else {
                                                                        customTagsByScope[scopeKey] =
                                                                            next;
                                                                      }
                                                                      final order =
                                                                          (tagOrderByScope[scopeKey] ??
                                                                                  const <String>[])
                                                                              .where(
                                                                                (
                                                                                  value,
                                                                                ) =>
                                                                                    value.toLowerCase() !=
                                                                                    tag.label.toLowerCase(),
                                                                              )
                                                                              .toList();
                                                                      if (order
                                                                          .isEmpty) {
                                                                        tagOrderByScope.remove(
                                                                          scopeKey,
                                                                        );
                                                                      } else {
                                                                        tagOrderByScope[scopeKey] =
                                                                            order;
                                                                      }
                                                                      selectedTags.removeWhere(
                                                                        (
                                                                          value,
                                                                        ) =>
                                                                            value.toLowerCase() ==
                                                                            tag.label.toLowerCase(),
                                                                      );
                                                                    });
                                                                  },
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        999,
                                                                      ),
                                                                  child: const Padding(
                                                                    padding:
                                                                        EdgeInsets.all(
                                                                          4,
                                                                        ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .delete_outline_rounded,
                                                                      size: SparkTextSize
                                                                          .title,
                                                                      color:
                                                                          kGreyColor,
                                                                    ),
                                                                  ),
                                                                )
                                                              else
                                                                InkWell(
                                                                  onTap: () {
                                                                    setLocalState(() {
                                                                      final next = [
                                                                        ...(disabledDefaultTagsByScope[scopeKey] ??
                                                                            const <
                                                                              String
                                                                            >[]),
                                                                      ];
                                                                      next.removeWhere(
                                                                        (
                                                                          value,
                                                                        ) =>
                                                                            value.toLowerCase() ==
                                                                            tag.label.toLowerCase(),
                                                                      );
                                                                      if (!hidden) {
                                                                        next.add(
                                                                          tag.label,
                                                                        );
                                                                        selectedTags.removeWhere(
                                                                          (
                                                                            value,
                                                                          ) =>
                                                                              value.toLowerCase() ==
                                                                              tag.label.toLowerCase(),
                                                                        );
                                                                      }
                                                                      if (next
                                                                          .isEmpty) {
                                                                        disabledDefaultTagsByScope.remove(
                                                                          scopeKey,
                                                                        );
                                                                      } else {
                                                                        disabledDefaultTagsByScope[scopeKey] =
                                                                            next;
                                                                      }
                                                                    });
                                                                  },
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        999,
                                                                      ),
                                                                  child: Padding(
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          4,
                                                                        ),
                                                                    child: Icon(
                                                                      hidden
                                                                          ? Icons.visibility_off_outlined
                                                                          : Icons.visibility_rounded,
                                                                      size: SparkTextSize
                                                                          .title,
                                                                      color:
                                                                          hidden
                                                                          ? kGreyColor
                                                                          : kSecondaryColor,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    if (customTagController !=
                                                            null &&
                                                        customTagFocusNode !=
                                                            null) ...[
                                                      const SizedBox(
                                                        height: SparkSpace.md,
                                                      ),
                                                      Container(
                                                        width: double.infinity,
                                                        padding:
                                                            const EdgeInsets.all(
                                                              10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color: kBorderColor,
                                                          ),
                                                          color: kInputBgColor,
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: TextField(
                                                                focusNode:
                                                                    customTagFocusNode,
                                                                controller:
                                                                    customTagController,
                                                                textInputAction:
                                                                    TextInputAction
                                                                        .done,
                                                                onSubmitted: (_) =>
                                                                    addCustomTag(
                                                                      group
                                                                          .severity,
                                                                    ),
                                                                onTapOutside: (_) =>
                                                                    _dismissKeyboard(),
                                                                decoration:
                                                                    _fieldDecoration(
                                                                      'Свой тег (${group.title.toLowerCase()})',
                                                                    ).copyWith(
                                                                      contentPadding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8,
                                                                      ),
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            OutlinedButton(
                                                              onPressed: () =>
                                                                  addCustomTag(
                                                                    group
                                                                        .severity,
                                                                  ),
                                                              child: const Text(
                                                                'Добавить',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ] else ...[
                                                    if (visibleOptions.isEmpty)
                                                      const MyText(
                                                        text:
                                                            'Теги скрыты в настройке',
                                                        size: SparkTextSize
                                                            .caption,
                                                        color: kGreyColor,
                                                      )
                                                    else
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: visibleOptions.map((
                                                          tag,
                                                        ) {
                                                          final selected =
                                                              selectedTags
                                                                  .contains(
                                                                    tag.label,
                                                                  );
                                                          return _chip(
                                                            label: tag.label,
                                                            selected: selected,
                                                            selectedColor:
                                                                _mediaTagColor(
                                                                  tag.severity,
                                                                ),
                                                            onTap: () {
                                                              setLocalState(() {
                                                                if (selected) {
                                                                  selectedTags
                                                                      .remove(
                                                                        tag.label,
                                                                      );
                                                                } else {
                                                                  selectedTags
                                                                      .add(
                                                                        tag.label,
                                                                      );
                                                                }
                                                              });
                                                            },
                                                          );
                                                        }).toList(),
                                                      ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                    ],
                                    if (canEditDetails) ...[
                                      const SizedBox(height: SparkSpace.lg),
                                      const SparkSectionTitle('Комментарий'),
                                      SparkJoyCommentInputPanel(
                                        controller: noteController,
                                        isDictating: isDictating,
                                        onDismissKeyboard: _dismissKeyboard,
                                        onToggleDictation: () async {
                                          if (isDictating) {
                                            await stopDictation(setLocalState);
                                          } else {
                                            await startDictation(setLocalState);
                                          }
                                        },
                                        onAiFormat: () =>
                                            formatNoteWithAi(setLocalState),
                                        hint: 'Добавьте комментарий',
                                      ),
                                      const SizedBox(height: SparkSpace.md),
                                      SparkJoyCommentAudioBlock(
                                        items: List.generate(
                                          audioRecordings.length,
                                          (
                                            audioIndex,
                                          ) => SparkJoyCommentAudioItemView(
                                            name:
                                                'Аудиозапись ${audioIndex + 1}',
                                            isPlaying:
                                                playingAudioIndex == audioIndex,
                                          ),
                                        ),
                                        isRecording: isRecording,
                                        recordingLabel: recordingLabel(),
                                        onToggleRecording: () async {
                                          if (isRecording) {
                                            await stopRecording(setLocalState);
                                          } else {
                                            await startRecording(setLocalState);
                                          }
                                        },
                                        onTogglePlay: (audioIndex) async {
                                          try {
                                            final playing =
                                                playingAudioIndex == audioIndex;
                                            if (playing) {
                                              await player.stop();
                                              if (!dialogActive) return;
                                              setLocalState(
                                                () => playingAudioIndex = -1,
                                              );
                                            } else {
                                              await player.stop();
                                              await _playAudioSource(
                                                player,
                                                audioRecordings[audioIndex],
                                              );
                                              if (!dialogActive) return;
                                              setLocalState(
                                                () => playingAudioIndex =
                                                    audioIndex,
                                              );
                                            }
                                          } catch (_) {
                                            await showMessage(
                                              'Не удалось воспроизвести аудио',
                                            );
                                          }
                                        },
                                        onRemoveAt: (audioIndex) {
                                          if (playingAudioIndex == audioIndex) {
                                            unawaited(player.stop());
                                          }
                                          setLocalState(() {
                                            if (playingAudioIndex ==
                                                audioIndex) {
                                              playingAudioIndex = -1;
                                            } else if (playingAudioIndex >
                                                audioIndex) {
                                              playingAudioIndex -= 1;
                                            }
                                            audioRecordings.removeAt(
                                              audioIndex,
                                            );
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              SparkSpace.xxxl,
                              SparkSpace.md,
                              SparkSpace.xxxl,
                              SparkSpace.md,
                            ),
                            child: SparkStepActionBar(
                              secondaryLabel: 'Отмена',
                              onSecondaryTap: () =>
                                  unawaited(closeEditorDiscard()),
                              primaryLabel: 'Готово',
                              onPrimaryTap: () => unawaited(saveEditor()),
                              primaryDisabled: isKeyboardOpen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    } finally {
      dialogActive = false;
      recordingTimer?.cancel();
      await recordSubscription?.cancel();
      try {
        if (await recorder.isRecording()) {
          await recorder.stop();
        }
      } catch (_) {}
      try {
        await speechToText.stop();
      } catch (_) {}
      await playerCompleteSubscription?.cancel();
      try {
        await player.stop();
      } catch (_) {}
      await player.dispose();
      await recorder.dispose();
    }
    final noteValue = noteController.text.trim();
    noteController.dispose();
    for (final controller in customTagControllers.values) {
      controller.dispose();
    }
    for (final focusNode in customTagFocusNodes.values) {
      focusNode.dispose();
    }
    if (!mounted) return false;

    final selectedByLower = <String, String>{};
    for (final rawTag in selectedTags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) continue;
      selectedByLower.putIfAbsent(tag.toLowerCase(), () => tag);
    }
    selectedTags = selectedByLower.values.toList();

    final normalizedTagPhotosByLower = <String, Set<String>>{};
    final tagDisplayByLower = <String, String>{};
    for (final entry in tagPhotosByTag.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      tagDisplayByLower.putIfAbsent(lower, () => tag);
      final urls = normalizedTagPhotosByLower.putIfAbsent(
        lower,
        () => <String>{},
      );
      for (final rawUrl in entry.value) {
        final url = rawUrl.trim();
        if (url.isEmpty) continue;
        urls.add(url);
      }
    }
    for (final entry in selectedByLower.entries) {
      tagDisplayByLower[entry.key] = entry.value;
      final urls = normalizedTagPhotosByLower.putIfAbsent(
        entry.key,
        () => <String>{},
      );
      urls.addAll(targetUrls);
    }
    for (final entry in normalizedTagPhotosByLower.entries) {
      if (selectedByLower.containsKey(entry.key)) continue;
      entry.value.removeWhere(targetUrls.contains);
    }

    final nextTagPhotos = <String, List<String>>{};
    if (!noDamage) {
      for (final entry in normalizedTagPhotosByLower.entries) {
        final label = tagDisplayByLower[entry.key] ?? entry.key;
        final urls = entry.value.where((url) => url.trim().isNotEmpty).toList();
        if (urls.isNotEmpty) {
          nextTagPhotos[label] = urls;
        }
      }
    }

    final partInspection = MediaPartInspection(
      noDamage: noDamage,
      tags: noDamage ? const [] : nextTagPhotos.keys.toList(),
      note: noteValue,
      elementType: (elementType ?? '').trim().isEmpty ? null : elementType,
      audioRecordings: [
        ...audioRecordings
            .map((audio) => audio.trim())
            .where((audio) => audio.isNotEmpty),
      ],
      paintFrom: supportsPaint ? paintFrom : null,
      paintTo: supportsPaint ? paintTo : null,
      tagPhotos: noDamage ? const {} : nextTagPhotos,
      isDraft: saved == true ? false : true,
    );

    final shouldPersist =
        saved == true ||
        (saveDraftOnClose && _mediaPartInspectionHasData(partInspection));
    if (!shouldPersist) return false;

    _setStateSafely(() {
      _mediaCustomTagsByScope = _readStringListMap(customTagsByScope);
      _mediaCustomSeriousTagsByScope = _readStringListMap(
        customSeriousTagsByScope,
      );
      _mediaDisabledDefaultTagsByScope = _readStringListMap(
        disabledDefaultTagsByScope,
      );
      _mediaTagOrderByScope = _readStringListMap(tagOrderByScope);
      final current = _mediaState[groupKey];
      if (current == null || index >= current.files.length) return;
      final nextPartInspection = _syncPartInspectionWithFiles(
        partInspection: partInspection,
        files: current.files,
        fallbackNote: current.note,
      );
      final nextFiles = _applyPartInspectionToFiles(
        files: current.files,
        partInspection: nextPartInspection,
        applyToFileUrls: targetUrls,
      );
      final hasIssue = nextFiles.any(_mediaItemHasIssue);
      _mediaState[groupKey] = current.copyWith(
        note: nextPartInspection.note.trim().isEmpty
            ? current.note
            : nextPartInspection.note.trim(),
        files: nextFiles,
        hasIssue: hasIssue,
        partInspection: nextPartInspection,
      );
    });
    return true;
  }
}

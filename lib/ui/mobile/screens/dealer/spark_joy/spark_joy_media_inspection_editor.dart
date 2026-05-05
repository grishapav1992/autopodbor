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
    var isDictating = false;
    var speechInitialized = false;
    var speechAvailable = false;
    var dialogActive = true;
    var shouldDictate = false;

    // Заметки строго per-item. Новое фото открывается с пустым полем,
    // ранее отредактированное — со своей сохранённой заметкой. Раньше
    // здесь был fallback на basePartInspection.note (group-level), но
    // group.partInspection обновляется на каждом save: после первого
    // фото с заметкой все следующие НОВЫЕ фото в группе наследовали
    // её при открытии редактора, хотя у самого item.inspection.note
    // было пусто. Bug-report 2026-05-05 (chrome).
    final noteController = TextEditingController(
      text: item.inspection.note,
    );
    var paintToolsExpanded = false;
    final speechToText = SpeechToText();

    Future<void> showMessage(String text) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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


    var aiInflight = false;
    Future<void> formatNoteWithAi(StateSetter setLocalState) async {
      if (aiInflight) return;
      aiInflight = true;
      if (dialogActive) setLocalState(() {});

      try {
        final elementLabel = _mediaElementLabel(groupKey, elementType);
        final scopeKeyForAi = (elementType ?? '').trim();
        final cliche = AiQueueClicheBuilder.buildElementClicheFromLabels(
          elementLabel: elementLabel,
          selectedTagLabels: selectedTags,
          // Anything custom-marked as "serious" in the current scope plus
          // tags coming from the serious group of the registry. The
          // registry-level severity is folded into selectedTags by label,
          // so we only need to surface the user-defined customs here.
          seriousTagLabels: <String>{
            ...(customSeriousTagsByScope[
                    _mediaTagScopeKey(groupKey, elementType: elementType)] ??
                const <String>[]),
          },
          existingNote: noteController.text.trim(),
        );

        final sourceKey = SparkJoyReportController.aiSourceKey(
          groupKey: groupKey,
          elementType: scopeKeyForAi,
          itemDataUrl: item.dataUrl,
        );
        final chatId = _reportController.ensureAiChatId(sourceKey);

        final reportNumber = _backendReportNumber();
        final fileRefs = <AiQueueFileRef>[];
        if (reportNumber.isNotEmpty) {
          final filename =
              _preferredUploadFileNameForItem(item, index).trim();
          if (filename.isNotEmpty) {
            fileRefs.add(AiQueueFileRef(
              reportNumber: reportNumber,
              filename: filename,
            ));
          }
        }

        final input = noteController.text.trim();
        final op = AiQueuePendingOp(
          opId: '${DateTime.now().microsecondsSinceEpoch}-$chatId',
          chatId: chatId,
          sourceKey: sourceKey,
          text: input.isEmpty
              ? 'Сформулируй замечание на основе тегов и фото.'
              : input,
          cliche: cliche,
          fileRefs: fileRefs,
        );
        final text = await AiQueueOfflineRunner.instance.enqueue(
          draftId: _draftId,
          op: op,
        );
        // Persist the result on the controller BEFORE the dialog-active
        // guard — closing the editor mid-flight should not lose the
        // response. The next time the same element is opened the editor
        // can re-hydrate it via aiResultBySourceKey.
        if (text != null && text.isNotEmpty) {
          _reportController.rememberAiResult(sourceKey, text);
        }
        if (!dialogActive) return;
        if (text != null && text.isNotEmpty) {
          noteController
            ..text = text
            ..selection = TextSelection.collapsed(offset: text.length);
          await showMessage('AI-описание готово');
        } else {
          await showMessage(
            'AI-запрос добавлен в очередь и отправится при появлении сети',
          );
        }
      } on storage_api.SessionExpiredException {
        if (dialogActive) {
          await showMessage('Сессия истекла — войдите заново');
        }
      } catch (e) {
        if (dialogActive) {
          await showMessage('Не удалось вызвать AI: $e');
        }
      } finally {
        aiInflight = false;
        if (dialogActive) setLocalState(() {});
      }
    }

    bool? saved;
    try {
      saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setLocalState) {
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
                final tagGroupsAll = _mediaTagGroups(
                  groupKey,
                  elementType: elementType,
                  customTagsByScope: customTagsByScope,
                  customSeriousTagsByScope: customSeriousTagsByScope,
                  disabledDefaultTagsByScope: disabledDefaultTagsByScope,
                  tagOrderByScope: tagOrderByScope,
                  includeDisabledDefaults: true,
                );
                Future<void> closeEditorDiscard() async {
                  // Flip dialogActive *before* the await chain — Navigator
                  // tears the StatefulBuilder down asynchronously, and any
                  // in-flight tag-refetch callback that resumes during the
                  // teardown window would otherwise call setLocalState on
                  // a stale state and trigger a "_dependents.isEmpty" /
                  // disposed-controller assertion.
                  dialogActive = false;
                  await stopDictation(setLocalState);
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
                  // Same race-guard rationale as closeEditorDiscard above.
                  dialogActive = false;
                  await stopDictation(setLocalState);
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
                                              'Для выбранного элемента повреждения не заданы',
                                          size: SparkTextSize.caption,
                                          color: kGreyColor,
                                        )
                                      else
                                        Builder(
                                          builder: (pillCtx) {
                                            final allOptions = tagGroupsAll
                                                .expand((g) => g.options)
                                                .toList(growable: false);
                                            final selectedCount =
                                                selectedTags.length;
                                            return Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      SparkRadius.lg,
                                                    ),
                                                onTap: () async {
                                                  final result =
                                                      await _showSparkJoyTagPicker(
                                                        pillCtx,
                                                        title: 'Повреждения',
                                                        options: allOptions,
                                                        initialSelected:
                                                            List<String>.from(
                                                              selectedTags,
                                                            ),
                                                        initialOrder:
                                                            List<String>.from(
                                                              tagOrderByScope[scopeKey] ??
                                                                  const <
                                                                    String
                                                                  >[],
                                                            ),
                                                        onCreateCustom:
                                                            (
                                                              name,
                                                              severity,
                                                            ) async {
                                                              // Server side fires-and-resolves;
                                                              // we don't gate UI on its id
                                                              // because the local catalog is
                                                              // already updated below and
                                                              // _loadTagIdsFromServer reconciles
                                                              // ids on the next open.
                                                              await _syncInspectionCustomTag(
                                                                groupKey:
                                                                    groupKey,
                                                                tagName: name,
                                                                severity:
                                                                    severity,
                                                              );
                                                              final lower =
                                                                  name
                                                                      .toLowerCase();
                                                              final next = [
                                                                ...?customTagsByScope[scopeKey],
                                                              ];
                                                              if (!next.any(
                                                                (s) =>
                                                                    s.toLowerCase() ==
                                                                    lower,
                                                              )) {
                                                                next.add(name);
                                                              }
                                                              customTagsByScope[scopeKey] =
                                                                  next;
                                                              if (severity ==
                                                                  'serious') {
                                                                final ns = [
                                                                  ...?customSeriousTagsByScope[scopeKey],
                                                                ];
                                                                if (!ns.any(
                                                                  (s) =>
                                                                      s.toLowerCase() ==
                                                                      lower,
                                                                )) {
                                                                  ns.add(name);
                                                                }
                                                                customSeriousTagsByScope[scopeKey] =
                                                                    ns;
                                                              }
                                                              final order = [
                                                                ...?tagOrderByScope[scopeKey],
                                                              ];
                                                              if (!order.any(
                                                                (s) =>
                                                                    s.toLowerCase() ==
                                                                    lower,
                                                              )) {
                                                                order.add(
                                                                  name,
                                                                );
                                                              }
                                                              tagOrderByScope[scopeKey] =
                                                                  order;
                                                              // Локальные карты обновлены —
                                                              // тег пользователю виден в
                                                              // каталоге сразу. Серверный id
                                                              // мог не вернуться (тайм-аут
                                                              // refetch), но _loadTagIdsFromServer
                                                              // дочинит при следующем открытии.
                                                              // Sheet'у возвращаем true чтобы
                                                              // не показывать ложный «не
                                                              // удалось создать тег» тост.
                                                              return true;
                                                            },
                                                        onDeleteCustom:
                                                            (name) async {
                                                              final ok =
                                                                  await _removeInspectionCustomTag(
                                                                    groupKey:
                                                                        groupKey,
                                                                    tagName:
                                                                        name,
                                                                  );
                                                              if (!ok) {
                                                                return false;
                                                              }
                                                              final lower =
                                                                  name
                                                                      .toLowerCase();
                                                              final pruned =
                                                                  (customTagsByScope[scopeKey] ??
                                                                          const <
                                                                            String
                                                                          >[])
                                                                      .where(
                                                                        (s) =>
                                                                            s.toLowerCase() !=
                                                                            lower,
                                                                      )
                                                                      .toList();
                                                              if (pruned
                                                                  .isEmpty) {
                                                                customTagsByScope.remove(
                                                                  scopeKey,
                                                                );
                                                              } else {
                                                                customTagsByScope[scopeKey] =
                                                                    pruned;
                                                              }
                                                              final prunedSerious =
                                                                  (customSeriousTagsByScope[scopeKey] ??
                                                                          const <
                                                                            String
                                                                          >[])
                                                                      .where(
                                                                        (s) =>
                                                                            s.toLowerCase() !=
                                                                            lower,
                                                                      )
                                                                      .toList();
                                                              if (prunedSerious
                                                                  .isEmpty) {
                                                                customSeriousTagsByScope.remove(
                                                                  scopeKey,
                                                                );
                                                              } else {
                                                                customSeriousTagsByScope[scopeKey] =
                                                                    prunedSerious;
                                                              }
                                                              final prunedOrder =
                                                                  (tagOrderByScope[scopeKey] ??
                                                                          const <
                                                                            String
                                                                          >[])
                                                                      .where(
                                                                        (s) =>
                                                                            s.toLowerCase() !=
                                                                            lower,
                                                                      )
                                                                      .toList();
                                                              if (prunedOrder
                                                                  .isEmpty) {
                                                                tagOrderByScope.remove(
                                                                  scopeKey,
                                                                );
                                                              } else {
                                                                tagOrderByScope[scopeKey] =
                                                                    prunedOrder;
                                                              }
                                                              return true;
                                                            },
                                                        onRefreshOrder:
                                                            (selectedSnapshot) {
                                                              // Sheet debounces internally
                                                              // and applies the returned
                                                              // order to its own state —
                                                              // host just forwards.
                                                              return _refreshInspectionTagOrder(
                                                                groupKey:
                                                                    groupKey,
                                                                selectedTagNames:
                                                                    selectedSnapshot,
                                                              );
                                                            },
                                                      );
                                                  if (result == null ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  setLocalState(() {
                                                    selectedTags = result;
                                                  });
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal:
                                                            SparkSpace.xl,
                                                        vertical:
                                                            SparkSpace.md,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: kInputBgColor,
                                                    border: Border.all(
                                                      color: kBorderColor,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          SparkRadius.lg,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .local_offer_outlined,
                                                        size:
                                                            SparkSize.iconLg,
                                                        color: kGreyColor,
                                                      ),
                                                      const SizedBox(
                                                        width: SparkSpace.md,
                                                      ),
                                                      Expanded(
                                                        child: MyText(
                                                          text:
                                                              selectedCount ==
                                                                  0
                                                              ? 'Выбрать повреждения'
                                                              : 'Повреждения ($selectedCount)',
                                                          size: SparkTextSize
                                                              .body,
                                                          weight: FontWeight
                                                              .w600,
                                                          color:
                                                              selectedCount ==
                                                                  0
                                                              ? kGreyColor
                                                              : kTertiaryColor,
                                                        ),
                                                      ),
                                                      const Icon(
                                                        Icons
                                                            .chevron_right_rounded,
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
                                    if (canEditDetails) ...[
                                      const SizedBox(height: SparkSpace.lg),
                                      const SparkSectionTitle('Комментарий'),
                                      SparkJoyCommentInputPanel(
                                        controller: noteController,
                                        isDictating: isDictating,
                                        aiBusy: aiInflight,
                                        onDismissKeyboard: _dismissKeyboard,
                                        onToggleDictation: () async {
                                          if (isDictating) {
                                            await stopDictation(setLocalState);
                                          } else {
                                            await startDictation(setLocalState);
                                          }
                                        },
                                        onAiFormat: () {
                                          unawaited(
                                            formatNoteWithAi(setLocalState),
                                          );
                                        },
                                        hint: 'Добавьте комментарий',
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
      try {
        await speechToText.stop();
      } catch (_) {}
    }
    final noteValue = noteController.text.trim();
    noteController.dispose();
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
      // Audio recordings retired in favour of dictation-only flow:
      // any pre-existing per-element audio in old drafts is dropped on
      // the next save by passing an empty list.
      audioRecordings: const <String>[],
      paintFrom: supportsPaint ? paintFrom : null,
      paintTo: supportsPaint ? paintTo : null,
      tagPhotos: noDamage ? const {} : nextTagPhotos,
      isDraft: saved == true ? false : true,
    );

    // No-op-save guard: dismiss-without-changes БОЛЬШЕ не персистит
    // черновик. Раньше открыть inspection editor и нажать «Назад»
    // (saved=false) всё равно сохраняло partInspection с дефолтным
    // `noDamage`, и пользователь видел badge «Есть заметка» хотя
    // ничего не вводил. Сравниваем serialised baseline vs current —
    // если совпадают, ничего не делаем.
    final partInspectionUnchanged =
        json.encode(partInspection.toJson()) ==
        json.encode(basePartInspection.toJson());
    final shouldPersist =
        saved == true ||
        (saveDraftOnClose &&
            _mediaPartInspectionHasData(partInspection) &&
            !partInspectionUnchanged);
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

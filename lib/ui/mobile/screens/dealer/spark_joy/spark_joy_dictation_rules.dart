part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyDictationRulesMethods on _SparkJoyCreateReportScreenState {
  Future<void> _ensureTdSpeech() async {
    if (_tdSpeechAvailable) return;
    if (_tdSpeechInitializing) return;
    _tdSpeechInitializing = true;

    try {
      _tdSpeechAvailable = await _tdSpeechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            _resetDictationFlags();
          }
        },
        onError: (_) {
          if (!mounted) return;
          _resetDictationFlags();
        },
      );
      if (_tdSpeechAvailable) {
        _speechPermissionGranted = true;
      } else {
        _showErrorSnack(
          'Надиктовка недоступна. Проверьте доступ к микрофону и распознаванию речи.',
        );
      }
    } catch (_) {
      _tdSpeechAvailable = false;
      _showErrorSnack('Не удалось инициализировать распознавание речи');
    } finally {
      _tdSpeechInitializing = false;
    }
  }

  void _resetDictationFlags() {
    _setStateSafely(() {
      _tdIsDictating = false;
      _docsIsDictating = false;
      _legalIsDictating = false;
      _summaryIsDictating = false;
    });
  }

  void _appendRecognizedText(
    TextEditingController controller,
    String transcript,
  ) {
    final next = SparkJoyCommentUtils.appendRecognizedTranscript(
      previous: controller.text,
      transcript: transcript,
    );
    if (next == controller.text) return;
    controller
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    _markDraftDirty();
    _setStateSafely(() {});
  }

  Future<void> _startDocsDictation() async {
    _docsShouldDictate = true;
    if (_docsIsDictating) return;
    if (_tdIsDictating) await _stopTdDictation();
    if (_legalIsDictating) await _stopLegalDictation();
    if (_summaryIsDictating) await _stopSummaryDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_docsShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(
            _docsMismatchCommentController,
            result.recognizedWords,
          );
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _docsIsDictating = true);
    } catch (_) {
      _docsShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopDocsDictation() async {
    _docsShouldDictate = false;
    if (!_docsIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _docsIsDictating = false);
  }

  Future<void> _startLegalDictation() async {
    _legalShouldDictate = true;
    if (_legalIsDictating) return;
    if (_tdIsDictating) await _stopTdDictation();
    if (_docsIsDictating) await _stopDocsDictation();
    if (_summaryIsDictating) await _stopSummaryDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_legalShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(_legalNoteController, result.recognizedWords);
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _legalIsDictating = true);
    } catch (_) {
      _legalShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopLegalDictation() async {
    _legalShouldDictate = false;
    if (!_legalIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _legalIsDictating = false);
  }

  Future<void> _startTdDictation() async {
    _tdShouldDictate = true;
    if (_tdIsDictating) return;
    if (_docsIsDictating) await _stopDocsDictation();
    if (_legalIsDictating) await _stopLegalDictation();
    if (_summaryIsDictating) await _stopSummaryDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_tdShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(_tdNoteController, result.recognizedWords);
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _tdIsDictating = true);
    } catch (_) {
      _tdShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopTdDictation() async {
    _tdShouldDictate = false;
    if (!_tdIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _tdIsDictating = false);
  }

  /// Dictation for the unified «Итог осмотра» field — replaced the
  /// old expert dictation after the «Сводка» + «Итог специалиста»
  /// cards were merged. Writes recognized text into `_summaryController`.
  Future<void> _startSummaryDictation() async {
    _summaryShouldDictate = true;
    if (_summaryIsDictating) return;
    if (_tdIsDictating) await _stopTdDictation();
    if (_docsIsDictating) await _stopDocsDictation();
    if (_legalIsDictating) await _stopLegalDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_summaryShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(_summaryController, result.recognizedWords);
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _summaryIsDictating = true);
    } catch (_) {
      _summaryShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopSummaryDictation() async {
    _summaryShouldDictate = false;
    if (!_summaryIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _summaryIsDictating = false);
  }


  /// AI-fill for the «Комментарий по расхождениям» field in the
  /// docs check step. The three yes/no values above are baked into
  /// the prompt via `buildDocsCheckCommentCliche` so the model sees
  /// which fields are mismatching even when the typed comment is
  /// short. Result lands in `_docsMismatchCommentController`.
  Future<void> _generateDocsCommentWithAi() async {
    if (_docsCommentAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _docsCommentAiBusy = true);
    try {
      final cliche = AiQueueClicheBuilder.buildDocsCheckCommentCliche(
        ownerMatch: _docsOwnerMatch,
        vinMatch: _docsVinMatch,
        engineMatch: _docsEngineMatch,
      );
      final inputText = _docsMismatchCommentController.text.trim();
      // Fresh chatId — no carry-over of prior turns.
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: inputText.isEmpty ? '—' : inputText,
        cliche: cliche,
      );
      final text = result.text.trim();
      if (text.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _docsMismatchCommentController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _docsCommentAiBusy = false);
      }
    }
  }

  /// AI-fill for the «Комментарий специалиста» field on the «Материалы
  /// проверки» step. Names of attached documents (with count) are
  /// baked into the prompt via `buildLegalCommentCliche` so the model
  /// can reference them in the answer even when the typed comment is
  /// short. Result lands in `_legalNoteController`.
  Future<void> _generateLegalCommentWithAi() async {
    if (_legalCommentAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _legalCommentAiBusy = true);
    try {
      final fileNames = _legalFiles
          .map((file) => file.name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      final cliche = AiQueueClicheBuilder.buildLegalCommentCliche(
        filesCount: _legalFiles.length,
        fileNames: fileNames,
      );
      final inputText = _legalNoteController.text.trim();
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: inputText.isEmpty ? '—' : inputText,
        cliche: cliche,
      );
      final text = result.text.trim();
      if (text.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _legalNoteController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
      _markDraftDirty();
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _legalCommentAiBusy = false);
      }
    }
  }

  /// AI-fill for the «Комментарий по тест-драйву» field. The mode
  /// (всё ок / есть проблемы / не проводился) plus per-subsystem
  /// yes/no answers and selected tags are baked into the prompt via
  /// `buildTdCommentCliche` so the model sees the structured findings
  /// regardless of how short the typed comment is.
  Future<void> _generateTdCommentWithAi() async {
    if (_tdCommentAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _tdCommentAiBusy = true);
    try {
      final cliche = AiQueueClicheBuilder.buildTdCommentCliche(
        tdMode: _tdMode ?? '',
        subsystemStatus: <String, bool?>{
          'engine': _tdEngineOk,
          'gearbox': _tdGearboxOk,
          'steering': _tdSteeringOk,
          'ride': _tdRideOk,
          'brake': _tdBrakeOk,
        },
        subsystemTags: <String, List<String>>{
          'engine': _tdEngineTags,
          'gearbox': _tdGearboxTags,
          'steering': _tdSteeringTags,
          'ride': _tdRideTags,
          'brake': _tdBrakeTags,
        },
        carContext: _carContextForAi(),
      );
      final inputText = _tdNoteController.text.trim();
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: inputText.isEmpty ? '—' : inputText,
        cliche: cliche,
      );
      final text = result.text.trim();
      if (text.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _tdNoteController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
      _markDraftDirty();
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _tdCommentAiBusy = false);
      }
    }
  }

  /// AI-fill for the «Сводка по данным осмотра» card. Fact-only —
  /// no buy/don't-buy advice (that role belongs to the expert
  /// conclusion generator above). The user-text payload combines
  /// the deterministic rule-based summary template (always
  /// available) with the per-element AI chat histories when
  /// present, so the model sees both raw fields and assistant
  /// interpretations and can produce a single readable recap.
  /// Result lands in `_summaryController` so autosave persists it
  /// to the draft and it ships to the server with the report.
  Future<void> _generateSummaryNoteWithAi() async {
    if (_summaryNoteAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _summaryNoteAiBusy = true);
    try {
      final summary = _calculateSummary();
      final structured = _summaryTemplate(summary).trim();

      final chatIds = _reportController.aiChatIdBySourceKey.values
          .where((id) => id > 0)
          .toSet()
          .toList();

      final historyChunks = <String>[];
      if (chatIds.isNotEmpty) {
        try {
          final histories = await AiQueueApi.getChatHistories(ids: chatIds);
          for (final session in histories.chats.values) {
            final assistantTurns = session.messages
                .where((m) => m.role.toLowerCase() == 'assistant')
                .map((m) => m.content.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (assistantTurns.isEmpty) continue;
            historyChunks.add(assistantTurns.join('\n'));
          }
        } catch (_) {
          // Non-fatal: structured rule-based dump alone is enough
          // context for the model.
        }
      }

      final contextParts = <String>[];
      if (structured.isNotEmpty) {
        contextParts.add(
          '=== Структурированные данные осмотра ===\n$structured',
        );
      }
      if (historyChunks.isNotEmpty) {
        contextParts.add(
          '=== AI-комментарии по элементам ===\n'
          '${historyChunks.join('\n---\n')}',
        );
      }
      // Inspector's current text — feed it back to the model as
      // «previous draft» so regeneration preserves their manual edits
      // (corrections, dictation notes, deletions). Without this block
      // the AI overwrites their work each time the button is pressed.
      // Goes LAST in the context so the model treats it as the most
      // recent state and the structured/AI blocks as supporting info.
      final previousDraft = _summaryController.text.trim();
      if (previousDraft.isNotEmpty) {
        contextParts.add(
          '=== Предыдущий черновик инспектора (сохрани факты и правки '
          'инспектора, но переоформи в шаблон с заголовками) ===\n'
          '$previousDraft',
        );
      }
      if (contextParts.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Заполните хотя бы один раздел осмотра, чтобы AI было из чего собирать сводку.',
            ),
          ),
        );
        return;
      }

      final cliche = AiQueueClicheBuilder.buildReportFactsCliche(
        reportLabel: _reportNameController.text.trim(),
        carContext: _carContextForAi(),
      );
      // Fresh chatId per generation so the model gets a clean slate
      // and doesn't keep "polishing" the same answer.
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: contextParts.join('\n\n'),
        cliche: cliche,
      );
      final note = result.text.trim();
      if (note.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _summaryController
        ..text = note
        ..selection = TextSelection.collapsed(offset: note.length);
      // Autosave listener attached to `_summaryController` already
      // marks the draft dirty, no explicit _markDraftDirty needed.
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _summaryNoteAiBusy = false);
      }
    }
  }

  Widget _commentInputPanel({
    required TextEditingController controller,
    required bool isDictating,
    required VoidCallback onToggleDictation,
    required VoidCallback onAiFormat,
    String hint = 'Добавьте комментарий',
    bool aiBusy = false,
    bool suppressOnboarding = false,
  }) {
    return SparkJoyCommentInputPanel(
      controller: controller,
      isDictating: isDictating,
      onToggleDictation: onToggleDictation,
      onAiFormat: onAiFormat,
      aiBusy: aiBusy,
      onDismissKeyboard: _dismissKeyboard,
      hint: hint,
      suppressOnboarding: suppressOnboarding,
    );
  }

}

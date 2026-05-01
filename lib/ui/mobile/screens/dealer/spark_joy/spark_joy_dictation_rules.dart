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
      _expertIsDictating = false;
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
    if (_expertIsDictating) await _stopExpertDictation();
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
    if (_expertIsDictating) await _stopExpertDictation();
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
    if (_expertIsDictating) await _stopExpertDictation();
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

  Future<void> _startExpertDictation() async {
    _expertShouldDictate = true;
    if (_expertIsDictating) return;
    if (_tdIsDictating) await _stopTdDictation();
    if (_docsIsDictating) await _stopDocsDictation();
    if (_legalIsDictating) await _stopLegalDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_expertShouldDictate) return;

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
          _appendRecognizedText(_expertController, result.recognizedWords);
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _expertIsDictating = true);
    } catch (_) {
      _expertShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopExpertDictation() async {
    _expertShouldDictate = false;
    if (!_expertIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _expertIsDictating = false);
  }

  void _formatCommentWithAi(TextEditingController controller) {
    final text = controller.text.trim();
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
    controller
      ..text = formatted
      ..selection = TextSelection.collapsed(offset: formatted.length);
  }

  /// Real AI summary via AiQueue: pulls every per-element chat
  /// history accumulated by the inspection editor, builds a single
  /// context block from the assistant turns, opens a fresh chatId and
  /// asks the model for a section-structured conclusion. Result lands
  /// directly in the expert-conclusion field.
  Future<void> _generateExpertSummaryWithAi() async {
    if (_expertSummaryAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _expertSummaryAiBusy = true);
    try {
      final chatIds = _reportController.aiChatIdBySourceKey.values
          .where((id) => id > 0)
          .toSet()
          .toList();
      if (chatIds.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'AI пока не из чего собирать заключение — сначала отформатируйте заметки по элементам через ИИ-кнопку в осмотре.',
            ),
          ),
        );
        return;
      }

      final histories = await AiQueueApi.getChatHistories(ids: chatIds);
      final contextChunks = <String>[];
      for (final session in histories.chats.values) {
        final assistantTurns = session.messages
            .where((m) => m.role.toLowerCase() == 'assistant')
            .map((m) => m.content.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (assistantTurns.isEmpty) continue;
        contextChunks.add(assistantTurns.join('\n'));
      }
      if (contextChunks.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI ещё не сформулировал замечаний по элементам.'),
          ),
        );
        return;
      }

      final summaryCliche = AiQueueClicheBuilder.buildSummaryCliche(
        reportLabel: _reportNameController.text.trim(),
      );
      final newChatId = SparkJoyReportController.aiSourceKey(
        groupKey: '__summary',
        elementType: _draftId,
      ).hashCode.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: contextChunks.join('\n\n---\n\n'),
        cliche: summaryCliche,
      );
      final summary = result.text.trim();
      if (summary.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('AI вернул пустой ответ. Попробуйте ещё раз.')),
        );
        return;
      }
      _expertController
        ..text = summary
        ..selection = TextSelection.collapsed(offset: summary.length);
      _markDraftDirty();
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('AI-помощник недоступен. Попробуйте позже.')),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _expertSummaryAiBusy = false);
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
  }) {
    return SparkJoyCommentInputPanel(
      controller: controller,
      isDictating: isDictating,
      onToggleDictation: onToggleDictation,
      onAiFormat: onAiFormat,
      aiBusy: aiBusy,
      onDismissKeyboard: _dismissKeyboard,
      hint: hint,
    );
  }

}

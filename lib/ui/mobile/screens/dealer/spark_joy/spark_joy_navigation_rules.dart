part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyNavigationRulesMethods on _SparkJoyCreateReportScreenState {
  Future<void> _openSection(int index) async {
    _dismissKeyboard();
    _setStateSafely(() {
      _reportFlowController.openSection(
        index,
        totalSteps: _SparkJoyStepRegistry.steps.length,
      );
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      _mediaGroupPressedIndex = null;
      _mediaListPressedGroupKey = null;
      if (_reportFlowController.isSummaryStep(
        totalSteps: _SparkJoyStepRegistry.steps.length,
      )) {
        _ensureSummaryAutofill();
      }
    });
    _scrollEditorToTop();
  }

  int _stepIndexById(String stepId) {
    return _SparkJoyStepRegistry.indexById(stepId);
  }

  void _navigateToStepFromSummary(String stepId, {String? mediaGroupKey}) {
    final nextIndex = _stepIndexById(stepId);
    if (nextIndex < 0) return;
    final summaryIndex = _stepIndexById(_SparkJoyStepRegistry.idSummary);

    _dismissKeyboard();
    _setStateSafely(() {
      _reportFlowController.openFromSummary(
        nextIndex: nextIndex,
        summaryIndex: summaryIndex,
        totalSteps: _SparkJoyStepRegistry.steps.length,
      );
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      _mediaGroupPressedIndex = null;
      _mediaListPressedGroupKey = null;
      if (stepId == _SparkJoyStepRegistry.idMedia) {
        _activeMediaGroupKey = mediaGroupKey;
      } else {
        _activeMediaGroupKey = null;
      }
      if (_reportFlowController.isSummaryStep(
        totalSteps: _SparkJoyStepRegistry.steps.length,
      )) {
        _ensureSummaryAutofill();
      }
    });
    _scrollEditorToTop();
  }

  void _openMediaGroupEditor(String groupKey) =>
      _runOpenMediaGroupEditor(groupKey);

  Future<void> _openMediaGroupFlow(String groupKey) =>
      _runOpenMediaGroupFlow(groupKey);

  void _closeMediaGroupEditor() {
    final restoreOffset = _mediaGroupListScrollOffset;
    _setStateSafely(() {
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      _mediaGroupPressedIndex = null;
      _mediaListPressedGroupKey = null;
      _mediaGroupListScrollOffset = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageScrollController.hasClients) return;
      final maxOffset = _pageScrollController.position.maxScrollExtent;
      final targetOffset = (restoreOffset ?? 0).clamp(0.0, maxOffset);
      _pageScrollController.jumpTo(targetOffset);
    });
  }

  Future<void> _saveAndOpenNextSection() async {
    await _stopTdDictation();
    await _stopDocsDictation();
    await _stopLegalDictation();
    await _stopSummaryDictation();
    _dismissKeyboard();
    await _saveDraft(showToast: false);
    if (!mounted) return;
    if (!_reportFlowController.moveToNext(
      totalSteps: _SparkJoyStepRegistry.steps.length,
    )) {
      return;
    }
    _setStateSafely(() {
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      if (_reportFlowController.isSummaryStep(
        totalSteps: _SparkJoyStepRegistry.steps.length,
      )) {
        _ensureSummaryAutofill();
      }
    });
    _scrollEditorToTop();
  }

  Future<void> _closeSection({bool save = false}) async {
    await _stopTdDictation();
    await _stopDocsDictation();
    await _stopLegalDictation();
    await _stopSummaryDictation();
    _dismissKeyboard();
    if (save) {
      await _saveDraft(showToast: false);
      if (!mounted) return;
    }
    _setStateSafely(() {
      _reportFlowController.closeSection();
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
    });
  }

  Future<void> _handleSectionBack() async {
    if (_returnToSummaryOnBack) {
      await _saveDraft(showToast: false);
      if (!mounted) return;
      final summaryIndex = _stepIndexById(_SparkJoyStepRegistry.idSummary);
      if (_reportFlowController.returnToSummary(
        summaryIndex: summaryIndex,
        totalSteps: _SparkJoyStepRegistry.steps.length,
      )) {
        _setStateSafely(() {
          _activeMediaGroupKey = null;
          _mediaGroupSelectMode = false;
          _mediaGroupSelectedIndexes = <int>{};
          _ensureSummaryAutofill();
        });
        _scrollEditorToTop();
        return;
      }
    }
    if (_SparkJoyStepRegistry.isMediaStepId(
          _SparkJoyStepRegistry.idAt(_stepIndex),
        ) &&
        _activeMediaGroupKey != null) {
      await _saveDraft(showToast: false);
      if (!mounted) return;
      _closeMediaGroupEditor();
      return;
    }
    await _closeSection(save: true);
  }
}

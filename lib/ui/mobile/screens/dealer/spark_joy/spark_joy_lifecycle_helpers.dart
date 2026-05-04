part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyLifecycleHelpers on _SparkJoyCreateReportScreenState {
  // Аудио-запись комментариев убрана из UI — никаких активных
  // recording-сессий быть не может; функция оставлена как noop, чтобы
  // не переписывать каскад вызовов из lifecycle observer.
  Future<void> _stopActiveCommentRecordingOnPause() async {}

  Future<void> _handleAppPausedOrInactive() async {
    if (_appPauseHandlingInProgress) return;
    _appPauseHandlingInProgress = true;

    try {
      _draftAutosaveDebounce?.cancel();

      await _stopTdDictation();
      await _stopDocsDictation();
      await _stopLegalDictation();
      await _stopExpertDictation();
      await _stopActiveCommentRecordingOnPause();

      if (_hasUnsavedDraftChanges || _draftSaveFailed) {
        await _saveDraft(showToast: false, fromAutosave: true);
      }
    } catch (e, st) {
      debugPrint('App lifecycle pause handling failed: $e');
      debugPrint(st.toString());
    } finally {
      _appPauseHandlingInProgress = false;
    }
  }

  void _attachAutosaveListeners() {
    _autosaveControllers
      ..clear()
      ..addAll([
        _reportNameController,
        _vinController,
        _plateController,
        _brandController,
        _modelController,
        _generationController,
        _adLinkController,
        _mileageController,
        _engineVolumeController,
        _engineTypeController,
        _gearboxTypeController,
        _driveTypeController,
        _colorController,
        _trimController,
        _ownersCountController,
        _inspectionCityController,
        _inspectionDateController,
        _docsMismatchCommentController,
        _legalNoteController,
        _tdNoteController,
        _summaryController,
        _expertController,
        _inspectorController,
      ]);
    for (final controller in _autosaveControllers) {
      controller.addListener(_onAutosaveInputChanged);
    }
    // VIN decoder hook — fires the NHTSA decoder on focus loss when
    // the inspector finishes typing. Paired with `_applyVinScannerResult`
    // for the OCR path. Detached in `_disposeInputResources` *before*
    // `_vinFocusNode.dispose()` to avoid post-dispose listener calls.
    _vinFocusNode.addListener(_handleVinFocusChange);
  }

  void _detachAutosaveListeners() {
    for (final controller in _autosaveControllers) {
      controller.removeListener(_onAutosaveInputChanged);
    }
    _autosaveControllers.clear();
  }

  void _onAutosaveInputChanged() {
    _markDraftDirty();
  }
}

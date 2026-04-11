part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyInitDisposeHelpers on _SparkJoyCreateReportScreenState {
  void _finalizeInitializationAfterDraftLoad() {
    if (_SparkJoyStepRegistry.isSummaryStepId(
      _SparkJoyStepRegistry.idAt(_stepIndex),
    )) {
      _ensureSummaryAutofill(force: true);
    }
    _attachAutosaveListeners();
    _sectionCommentAudioCompleteSub = _sectionCommentAudioPlayer
        .onPlayerComplete
        .listen((_) {
          if (!mounted) return;
          _setStateSafely(() {
            _docsCommentPlayingAudioIndex = -1;
            _legalCommentPlayingAudioIndex = -1;
            _tdCommentPlayingAudioIndex = -1;
            _expertCommentPlayingAudioIndex = -1;
          });
        });
  }

  void _disposeInputResources() {
    _pageScrollController.dispose();
    _vinFocusNode.dispose();
    _plateFocusNode.dispose();
    _adLinkFocusNode.dispose();
    _mileageFocusNode.dispose();
    _inspectionCityFocusNode.dispose();
    _reportNameController.dispose();
    _vinController.dispose();
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _generationController.dispose();
    _adLinkController.dispose();
    _mileageController.dispose();
    _engineVolumeController.dispose();
    _engineTypeController.dispose();
    _gearboxTypeController.dispose();
    _driveTypeController.dispose();
    _colorController.dispose();
    _trimController.dispose();
    _ownersCountController.dispose();
    _inspectionCityController.dispose();
    _inspectionDateController.dispose();
    _docsMismatchCommentController.dispose();
    _legalNoteController.dispose();
    _tdNoteController.dispose();
    _summaryController.dispose();
    _expertController.dispose();
    _inspectorController.dispose();
    for (final controller in _tdCustomTagControllersByScope.values) {
      controller.dispose();
    }
    for (final focusNode in _tdCustomTagFocusNodesByScope.values) {
      focusNode.dispose();
    }
  }

  void _disposeRuntimeResources() {
    _sectionCommentAudioCompleteSub?.cancel();
    unawaited(_sectionCommentAudioPlayer.stop());
    unawaited(_sectionCommentAudioPlayer.dispose());
    _sectionCommentRecordTimer?.cancel();
    unawaited(_sectionCommentRecordSub?.cancel() ?? Future.value());
    unawaited(_sectionCommentRecorder.stop());
    unawaited(_sectionCommentRecorder.dispose());
    unawaited(_tdSpeechToText.stop());
    _dataUrlImageBytesCache.clear();
    _resolvedAudioPlaybackSources.clear();
  }
}

part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyLifecycleHelpers on _SparkJoyCreateReportScreenState {
  Future<void> _stopActiveCommentRecordingOnPause() async {
    final activeKey = _activeSectionCommentRecordingKey;
    if (activeKey == null) return;
    switch (activeKey) {
      case 'docs_comment':
        await _stopSectionCommentRecording(
          key: 'docs_comment',
          files: _docsCommentAudioFiles,
          setFiles: (next) => _docsCommentAudioFiles = next,
          keepResult: true,
        );
        break;
      case 'legal_comment':
        await _stopSectionCommentRecording(
          key: 'legal_comment',
          files: _legalCommentAudioFiles,
          setFiles: (next) => _legalCommentAudioFiles = next,
          keepResult: true,
        );
        break;
      case 'td_comment':
        await _stopSectionCommentRecording(
          key: 'td_comment',
          files: _tdCommentAudioFiles,
          setFiles: (next) => _tdCommentAudioFiles = next,
          keepResult: true,
        );
        break;
      case 'expert_comment':
        await _stopSectionCommentRecording(
          key: 'expert_comment',
          files: _expertAudioFiles,
          setFiles: (next) => _expertAudioFiles = next,
          keepResult: true,
        );
        break;
      default:
        break;
    }
  }

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
      try {
        await _sectionCommentAudioPlayer.stop();
      } catch (_) {}

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

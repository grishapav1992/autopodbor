part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyScreenHelpers on _SparkJoyCreateReportScreenState {
  String _backendReportNumber() {
    final raw = _backendUploadState['reportNumber'];
    if (raw == null) return '';
    return raw.toString().trim();
  }

  String _currentReportCode() {
    final backendNumber = _backendReportNumber();
    if (backendNumber.isNotEmpty) return backendNumber;
    return _reportCode.trim();
  }

  String _reportTitle() {
    final value = _reportNameController.text.trim();
    if (value.isNotEmpty) return value;
    final car = _carName().trim();
    if (car.isNotEmpty) return car;
    return 'Новый отчет';
  }

  Future<void> _editReportTitle() async {
    // Read-only views of completed reports must never mutate the
    // reportName — swallow the tap silently so the editor-shell code
    // paths that always wire this callback don't accidentally pop a
    // rename dialog on top of the recap.
    if (widget.readOnly) return;
    final controller = TextEditingController(text: _reportNameController.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xxxl,
              SparkSpace.xxxl,
              SparkSpace.xxxl,
              SparkSpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MyText(
                  text: 'Название отчета',
                  size: SparkTextSize.titleLg,
                  weight: FontWeight.w800,
                  lineHeight: 1.30,
                  tracking: true,
                ),
                const SizedBox(height: SparkSpace.lg),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onTapOutside: (_) => _dismissKeyboard(),
                  decoration: _fieldDecoration('Например: Тойота для Михаила'),
                ),
                const SizedBox(height: SparkSpace.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: SparkSpace.sm),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true || !mounted) return;
    _setStateSafely(() {
      _reportNameController.text = controller.text.trim();
    });
    await _saveDraft(showToast: false);
  }

  void _scrollEditorToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageScrollController.hasClients) return;
      _pageScrollController.jumpTo(0);
    });
  }

  void _dismissKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.hasFocus) {
      focus.unfocus();
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleVehicleContinue() async {
    if (!_isVehicleReadyForContinue()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите VIN-номер или отметьте как нечитаемый'),
        ),
      );
      return;
    }

    final plateError = _plateError();
    if (plateError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(plateError)));
      return;
    }

    final duplicateDraft = await _findDuplicateVinDraft();
    if (duplicateDraft != null) {
      final openExisting = await _showDuplicateVinDialog(duplicateDraft);
      if (openExisting == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SparkJoyCreateReportScreen(
              initialReportName:
                  (duplicateDraft['reportName'] ?? '').toString().trim().isEmpty
                  ? null
                  : (duplicateDraft['reportName'] ?? '').toString().trim(),
              draft: duplicateDraft,
              assignment: widget.assignment,
            ),
          ),
        );
        return;
      }
    }

    await _saveAndOpenNextSection();
  }

  Widget _stepVehicle() => _buildSparkJoyStepVehicle(
    this,
    setStateFn: _setStateSafely,
    ownersCounts: _SparkJoyVehicleRegistry.ownersCounts,
  );

  Widget _stepParams() {
    return _buildSparkJoyStepParams(
      this,
      engineVolumes: _SparkJoyVehicleRegistry.engineVolumeOptions,
      colors: _SparkJoyVehicleRegistry.colors,
      engineTypes: _SparkJoyVehicleRegistry.engineTypes,
      gearboxTypes: _SparkJoyVehicleRegistry.gearboxTypes,
      driveTypes: _SparkJoyVehicleRegistry.driveTypes,
    );
  }

  Widget _stepDocsCheck() {
    final hasMismatch = _docsAnyMismatch();

    return _buildSparkJoyStepDocsCheck(
      this,
      hasMismatch: hasMismatch,
      setStateFn: _setStateSafely,
    );
  }

  Widget _stepLegal() =>
      _buildSparkJoyStepLegal(this, setStateFn: _setStateSafely);

  Widget _stepMedia() => _buildSparkJoyStepMedia(this);

  Widget _stepTestDrive() => _buildSparkJoyStepTestDrive(
    this,
    setStateFn: _setStateSafely,
    modeAllGood: _SparkJoyTestDriveRegistry.modeAllGood,
    modeProblems: _SparkJoyTestDriveRegistry.modeProblems,
    scopeEngine: _SparkJoyTestDriveRegistry.scopeEngine,
    scopeGearbox: _SparkJoyTestDriveRegistry.scopeGearbox,
    scopeSteering: _SparkJoyTestDriveRegistry.scopeSteering,
    scopeRide: _SparkJoyTestDriveRegistry.scopeRide,
    scopeBrake: _SparkJoyTestDriveRegistry.scopeBrake,
  );

  void _openSummarySectionEditor(String title) {
    final stepId = _SparkJoySummaryRegistry.titleToStepId[title];
    if (stepId == null || stepId.trim().isEmpty) return;
    final mediaGroup = stepId == _SparkJoyStepRegistry.idMedia
        ? _SparkJoySummaryRegistry.titleToGroupKey[title]
        : null;
    _navigateToStepFromSummary(stepId, mediaGroupKey: mediaGroup);
  }

  Color _summarySectionStatusColor(String status) {
    return _sparkSummarySectionStatusColor(status);
  }

  bool _isAttachmentSourceLikelyValid(String source) {
    final value = source.trim().toLowerCase();
    if (value.isEmpty) return false;
    return value.startsWith('data:') ||
        value.startsWith('blob:') ||
        value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('file://') ||
        value.startsWith('/');
  }

  _SummaryAttachmentStats _summaryAttachmentStats() {
    var images = 0;
    var videos = 0;
    var audios = 0;
    var files = 0;
    var broken = 0;
    var total = 0;

    void consume(UploadedItem item) {
      total += 1;
      if (item.isImage) {
        images += 1;
      } else if (item.isVideo) {
        videos += 1;
      } else if (item.isAudio) {
        audios += 1;
      } else {
        files += 1;
      }
      if (!_isAttachmentSourceLikelyValid(item.dataUrl)) {
        broken += 1;
      }
    }

    for (final group in _mediaState.values) {
      for (final item in group.files) {
        consume(item);
      }
    }
    for (final item in _legalFiles) {
      consume(item);
    }
    for (final item in _docsCommentAudioFiles) {
      consume(item);
    }
    for (final item in _legalCommentAudioFiles) {
      consume(item);
    }
    for (final item in _tdCommentAudioFiles) {
      consume(item);
    }
    for (final item in _expertAudioFiles) {
      consume(item);
    }

    return _SummaryAttachmentStats(
      total: total,
      imageCount: images,
      videoCount: videos,
      audioCount: audios,
      fileCount: files,
      brokenCount: broken,
    );
  }
}

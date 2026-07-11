part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyInitDisposeHelpers on _SparkJoyCreateReportScreenState {
  void _finalizeInitializationAfterDraftLoad() {
    _reportNameFocusNode.addListener(_handleInlineReportNameFocusChanged);
    if (_SparkJoyStepRegistry.isSummaryStepId(
      _SparkJoyStepRegistry.idAt(_stepIndex),
    )) {
      _ensureSummaryAutofill();
    }
    _attachAutosaveListeners();
    // Восстановленный черновик/назначение могли принести готовый VIN, а
    // listener'ы цепляются только сейчас (после конструктора) → авто-триггер
    // дозаполнения «Параметров» на init делаем явно. Only-empty + дедуп
    // делают повторное открытие заполненного черновика no-op'ом. Пост-фрейм —
    // нужен живой context для снэкбара.
    if (!widget.readOnly) {
      _initializePhotoIntakeAi();
      // Легаси-черновик со свободным текстом марки/модели (до строгого
      // режима) → фоновая привязка к каталогу; новые черновики всегда
      // несут ID и выходят из ре-байнда сразу.
      unawaited(_rebindCarFromCatalogIfNeeded());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeResolveFromVin();
      });
    }
    // Audio recording / playback инфраструктура удалена; раньше здесь
    // монтировался onPlayerComplete listener для синка playing-index.
  }

  void _disposeInputResources() {
    _pageScrollController.dispose();
    _mediaGroupChipScrollController.dispose();
    _vinFocusNode.dispose();
    _plateFocusNode.dispose();
    _adLinkFocusNode.dispose();
    _mileageFocusNode.dispose();
    _inspectionCityFocusNode.dispose();
    _reportNameFocusNode
      ..removeListener(_handleInlineReportNameFocusChanged)
      ..dispose();
    _inlineReportNameController.dispose();
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
    _inspectorController.dispose();
  }

  void _disposeRuntimeResources() {
    // Audio recorder / player удалены вместе с UI; остаётся только
    // dictation speech-to-text + кэш картинок.
    unawaited(_tdSpeechToText.stop());
    _dataUrlImageBytesCache.clear();
    _disposePhotoIntakeAi();
  }
}

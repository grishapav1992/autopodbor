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
      await _stopSummaryDictation();
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
    // VIN мог измениться из любого источника (ручной ввод, OCR-сканер,
    // конвертер) — все они дёргают этот listener. Дешёвый guard + дедуп
    // живут внутри конвейера _resolveAllFromVin.
    _maybeResolveFromVin();
  }

  /// Единый дебаунс-вход VIN→всё: запускает конвейер `_resolveAllFromVin`
  /// (идентификация → параметры). Шаги конвейера сами дедупят/гейтят/мьютят,
  /// поэтому здесь только дешёвые проверки + дебаунс (гасит посимвольный ввод
  /// и двойные `.text=` конвертера). Безопасно звать на любое изменение поля.
  /// (Реюзаем _vinParamsAutofillDebounce — один таймер на весь конвейер.)
  void _maybeResolveFromVin() {
    if (widget.readOnly) return;
    final vin = _sanitizeVin(_vinController.text);
    if (vin.length != 17 || !_isStrictVin(vin)) return; // полный валидный VIN
    // Оба шага уже терминально отработали этот VIN → даже таймер не заводим,
    // иначе каждый кейстрок в ЛЮБОМ поле формы гонял бы пустой конвейер.
    if (vin == _lastVinIdentityResolved && vin == _lastVinAutofilled) return;
    _vinParamsAutofillDebounce?.cancel();
    _vinParamsAutofillDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final current = _sanitizeVin(_vinController.text);
      if (current.length == 17 && _isStrictVin(current)) {
        unawaited(_resolveAllFromVin(current));
      }
    });
  }

  /// 5 целевых полей «Параметров» по стабильным ключам (совпадают с ключами
  /// `parseVinParamsAiResult` / `_vinAutofilledValues`). Единый источник для
  /// проверки пустоты, очистки stale-значений и записи.
  Map<String, TextEditingController> _vinParamTargetsByKey() => {
    'engineVolume': _engineVolumeController,
    'engineType': _engineTypeController,
    'transmission': _gearboxTypeController,
    'driveType': _driveTypeController,
    'equipment': _trimController,
  };

  /// Есть ли среди целевых полей хоть одно пустое. Если нет (и нет stale
  /// ИИ-значений у вызывающего) — сеть не трогаем, повторное открытие
  /// заполненного черновика бесплатно.
  bool _hasAnyEmptyParamTarget() =>
      _vinParamTargetsByKey().values.any((c) => c.text.trim().isEmpty);
}

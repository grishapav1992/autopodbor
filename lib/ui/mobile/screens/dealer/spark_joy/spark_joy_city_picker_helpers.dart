part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCityPickerHelpers on _SparkJoyCreateReportScreenState {
  /// Opens the modal city picker. Idempotent — re-entry while a sheet
  /// is already open is a no-op (mirrors `_carPickerOpening` guard for
  /// the brand-model dialog).
  ///
  /// On selection the city's Russian name is written into
  /// `_inspectionCityController`, which automatically pings the
  /// autosave listener (`_onAutosaveInputChanged`). The validity flag
  /// `_isInspectionCityValid` is flipped to `true` so the spark_joy
  /// completion rule lets the inspector proceed.
  ///
  /// On dismiss without selection (`null` returned) we leave the
  /// existing controller text untouched. If that text was already
  /// out-of-list, the warning banner re-appears next time the picker
  /// is opened — and `_isInspectionCityValid` stays `false`, blocking
  /// submit.
  Future<void> _openCityPicker() async {
    if (_cityPickerOpening) return;
    _cityPickerOpening = true;
    try {
      // Make sure the dataset is ready before the picker tries to
      // search; the bottom sheet has its own loader spinner but we
      // also want `findByExactRu` for the out-of-list banner to be
      // valid synchronously when the sheet first paints.
      await CityRepository.instance.init();
      if (!mounted) return;

      final picked = await showCityPickerBottomSheet(
        context,
        currentValue: _inspectionCityController.text.trim(),
      );
      if (!mounted || picked == null) return;
      _setStateSafely(() {
        // Write the full "Country, Region, City" label so the report
        // payload (`cityInspection`) and the picker tile read the
        // same string. `findByExactRu` recognises both this form and
        // the bare `nameRu` for back-compat with older drafts.
        _inspectionCityController.text = picked.displayLabel;
        _isInspectionCityValid = true;
      });
    } finally {
      _cityPickerOpening = false;
    }
  }

  /// Recomputes `_isInspectionCityValid` against the current
  /// controller text. Used after draft hydration when we want to know
  /// whether the value rehydrated from the server is still in-list.
  /// Async because the repository may need to load on first call;
  /// callers `unawaited(...)` it so it doesn't block the UI build.
  Future<void> _refreshInspectionCityValidity() async {
    if (!CityRepository.instance.isReady) {
      await CityRepository.instance.init();
    }
    if (!mounted) return;
    final ok = CityRepository.instance.findByExactRu(
          _inspectionCityController.text.trim(),
        ) !=
        null;
    if (ok != _isInspectionCityValid) {
      _setStateSafely(() => _isInspectionCityValid = ok);
    }
  }
}

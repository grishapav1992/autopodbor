part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyVinActionsHelpers on _SparkJoyCreateReportScreenState {
  Uint8List _cropVinGuideArea(Uint8List bytes) =>
      _sparkCropVinGuideArea(this, bytes);

  Future<void> _openVinScannerSourceModal() async {
    await _sparkOpenVinScannerSourceModal(this);
  }

  Future<void> _openVinScannerDialog({
    required ImageSource initialSource,
  }) async {
    await _sparkOpenVinScannerDialog(this, initialSource: initialSource);
  }

  void _applyVinScannerResult(String vin) {
    if (!mounted) return;
    _setStateSafely(() {
      _vinUnreadable = false;
      _vinController.text = vin;
    });
    // Fire-and-forget: OCR delivered a finalized VIN, kick off the
    // decoder right away so the «Параметры» step is prefilled by the
    // time the inspector navigates there. Errors are swallowed inside
    // the service and surfaced silently — see `_decodeAndApplyVin`.
    unawaited(_decodeAndApplyVin(vin));
  }

  /// Listener for `_vinFocusNode`. Triggered when the inspector tabs
  /// or taps away from the manual VIN input. We only act on focus
  /// **loss** (`!hasFocus`) to avoid running the decoder on every
  /// keystroke — the user explicitly finished typing the VIN.
  ///
  /// Strict validation reuses `_isStrictVin` (17 chars, regex, both
  /// letters & digits) from `spark_joy_vehicle_business_helpers.dart`
  /// so we never hit the network with garbage. The
  /// `_lastDecodedVin` guard prevents redundant work when focus
  /// bounces in/out without a value change.
  void _handleVinFocusChange() {
    if (_vinFocusNode.hasFocus) return;
    final vin = _vinController.text.trim().toUpperCase();
    if (vin.isEmpty) return;
    if (!_isStrictVin(vin)) return;
    if (vin == _lastDecodedVin) return;
    unawaited(_decodeAndApplyVin(vin));
  }

  /// Calls `VinDecoderService.decode(vin)` and applies the resulting
  /// characteristicsStep patch onto the four target controllers.
  ///
  /// UX rules (locked in via planning conversation):
  ///   • Always overwrite existing values when the decoder returns a
  ///     non-null field — simpler than per-field merge logic and
  ///     matches the user's stated preference.
  ///   • Empty NHTSA response (typical for X9F/Z94/XTA Russian
  ///     manufacturing) — silent no-op. The inspector fills fields
  ///     manually as before, no toast, no indicator.
  ///
  /// Race protection: if the user changes the VIN while we're
  /// awaiting NHTSA, the controller text will no longer match `vin`
  /// and we discard the response.
  ///
  /// `_lastDecodedVin` is set **before** awaiting so that two near-
  /// simultaneous triggers (OCR result + focus loss firing back-to-
  /// back) do not both reach the network. On transient network failures
  /// (`result.isNetworkFailure`) we **roll it back** so the inspector
  /// can retry simply by tapping out of the VIN field again — without
  /// having to edit the value.
  Future<void> _decodeAndApplyVin(String vin) async {
    final canonical = vin.trim().toUpperCase();
    if (canonical.isEmpty) return;
    if (canonical == _lastDecodedVin) return;
    final previousDecodedVin = _lastDecodedVin;
    _lastDecodedVin = canonical;

    final result = await VinDecoderService.decode(canonical);
    if (!mounted) return;
    // The user might have edited the VIN while we were waiting —
    // bail out so we don't apply stale data.
    if (_vinController.text.trim().toUpperCase() != canonical) return;

    // Distinguish three outcomes:
    //   1. result == null  — VIN failed strict validation inside the
    //      service. Should not happen because we pre-validate via
    //      _isStrictVin/OCR, but if it does, treat as a transient
    //      failure so retries are possible.
    //   2. result.isNetworkFailure — timeout, socket error, malformed
    //      JSON, non-200. Roll back the dedup marker.
    //   3. result.hasAnyCharacteristic == false but no network failure
    //      — legitimate "NHTSA does not know this VIN" (X9F/Z94/XTA
    //      Russian builds). Keep the marker, silently no-op.
    //   4. result.hasAnyCharacteristic == true — apply patch.
    if (result == null || result.isNetworkFailure) {
      _lastDecodedVin = previousDecodedVin;
      return;
    }
    if (!result.hasAnyCharacteristic) return;

    final patch = result.toCharacteristicsStepPatch();
    _setStateSafely(() {
      final volume = patch['engineVolume'];
      if (volume is num) {
        // `_engineVolumeController` holds a free-form decimal string;
        // `_buildCharacteristicsStepPayload` re-parses it via
        // `_parseDecimal` before sending. Stringify with the locale-
        // neutral default toString — `1.6` not `1,6`.
        _engineVolumeController.text = volume.toString();
      }
      final engineType = patch['engineType'];
      if (engineType is String && engineType.isNotEmpty) {
        _engineTypeController.text = engineType;
      }
      final transmission = patch['transmission'];
      if (transmission is String && transmission.isNotEmpty) {
        _gearboxTypeController.text = transmission;
      }
      final driveType = patch['driveType'];
      if (driveType is String && driveType.isNotEmpty) {
        _driveTypeController.text = driveType;
      }
    });
    // Autosave listeners on the four controllers will fire on `.text =`
    // assignments and call `_markDraftDirty()` automatically, so we
    // don't need to mark dirty explicitly.
  }
}

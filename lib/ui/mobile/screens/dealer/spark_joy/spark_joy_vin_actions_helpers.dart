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
  }
}

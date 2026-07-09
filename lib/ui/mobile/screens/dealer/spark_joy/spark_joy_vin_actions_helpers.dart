part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyVinActionsHelpers on _SparkJoyCreateReportScreenState {
  Uint8List _cropVinGuideArea(Uint8List bytes) =>
      _sparkCropVinGuideArea(this, bytes);

  // Точка входа отдельного OCR-сканера VIN. Со шага «Автомобиль» больше не
  // вызывается — скан VIN слит с автозаполнением в единую кнопку (см.
  // _openAutofillScan). Оставлено в кодовой базе для возможного переиспользования;
  // полное удаление подсистемы сканера — отдельная зачистка.
  // ignore: unused_element
  Future<void> _openVinScannerSourceModal() async {
    if (mounted) {
      await SparkJoyOnboarding.showOnce(
        context,
        flagKey: UserSimplePreferences.sparkOnbVinScannerKey,
        titleI18nKey: 'spark.onboarding.vinScanner.title',
        titleFallback: 'Сканирование VIN',
        bullets: const [
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.vinScanner.b1',
            fallback:
                'Поднесите камеру к VIN-коду на кузове или ПТС — он распознается автоматически.',
            icon: Icons.center_focus_strong_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.vinScanner.b2',
            fallback:
                'Совместите рамку с VIN: подсветка и резкость фокусируются на области внутри неё.',
            icon: Icons.crop_free_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.vinScanner.b3',
            fallback:
                'Если распознать не удалось — введите VIN вручную, ничего не потеряется.',
            icon: Icons.keyboard_alt_outlined,
          ),
        ],
      );
      if (!mounted) return;
    }
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

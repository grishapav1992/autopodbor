part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepVehicle(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
  required List<String> ownersCounts,
}) {
  final vinError = s._vinError();
  final plateError = s._plateError();

  return Column(
    children: [
      _buildConverterDevHelper(s),
      s._sectionHeading(
        'Обязательные данные',
        icon: Icons.fact_check_outlined,
        subtitle: 'VIN для идентификации автомобиля',
      ),
      const SizedBox(height: SparkSpace.md),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'VIN-номер *',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: s._vinController,
                    focusNode: s._vinFocusNode,
                    enabled: !s._vinUnreadable,
                    maxLength: 17,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(s.context).requestFocus(s._plateFocusNode);
                    },
                    onTapOutside: (_) => s._dismissKeyboard(),
                    onChanged: (value) {
                      final sanitized = s._sanitizeVin(value);
                      if (sanitized == value) {
                        setStateFn(() {});
                        return;
                      }
                      s._vinController.value = TextEditingValue(
                        text: sanitized,
                        selection: TextSelection.collapsed(
                          offset: sanitized.length,
                        ),
                      );
                      setStateFn(() {});
                    },
                    decoration: s
                        ._fieldDecoration('XW7BF4FK10S012345')
                        .copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: s._vinUnreadable
                        ? null
                        : s._openVinScannerSourceModal,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: kBorderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                      ),
                    ),
                    child: const Icon(Icons.document_scanner_outlined),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                setStateFn(() {
                  s._vinUnreadable = !s._vinUnreadable;
                });
                s._markDraftDirty();
              },
              borderRadius: BorderRadius.circular(SparkRadius.md),
              child: Row(
                children: [
                  Checkbox(
                    value: s._vinUnreadable,
                    onChanged: (value) {
                      setStateFn(() {
                        s._vinUnreadable = value ?? false;
                      });
                      s._markDraftDirty();
                    },
                    activeColor: kSecondaryColor,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MyText(
                          text: 'Нечитабельный VIN',
                          size: SparkTextSize.body,
                          color: kTertiaryColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (vinError != null)
              MyText(
                text: vinError,
                size: SparkTextSize.caption,
                color: kRedColor,
              ),
            const SizedBox(height: SparkSpace.md),
            _buildConverterLookupButton(
              s,
              source: _ConverterSource.vin,
              enabled: s._canLookupByVin() && !s._converterLoading,
              label: 'Подтянуть ГРЗ и данные авто',
            ),
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.xl),
      s._sectionHeading(
        'Дополнительно',
        icon: Icons.add_chart_rounded,
        subtitle: 'Номер, ссылка, владельцы и город осмотра',
      ),
      const SizedBox(height: SparkSpace.lg),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Госномер',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            TextField(
              controller: s._plateController,
              focusNode: s._plateFocusNode,
              maxLength: 12,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                FocusScope.of(s.context).requestFocus(s._adLinkFocusNode);
              },
              onTapOutside: (_) => s._dismissKeyboard(),
              onChanged: (value) {
                final sanitized = s._sanitizePlate(value);
                final formatted = s._formatPlate(sanitized);
                if (formatted != value) {
                  s._plateController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                    composing: TextRange.empty,
                  );
                }
                setStateFn(() {});
              },
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              textAlign: TextAlign.center,
              decoration: s
                  ._fieldDecoration('А 000 АА 000')
                  .copyWith(counterText: ''),
            ),
            if (plateError != null) ...[
              const SizedBox(height: SparkSpace.sm),
              MyText(
                text: plateError,
                size: SparkTextSize.caption,
                color: kRedColor,
              ),
            ],
            const SizedBox(height: SparkSpace.md),
            _buildConverterLookupButton(
              s,
              source: _ConverterSource.plate,
              enabled: s._canLookupByPlate() && !s._converterLoading,
              label: 'Подтянуть VIN и данные авто',
            ),
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Ссылка на объявление',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            s._input(
              s._adLinkController,
              'https://auto.ru/...',
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              focusNode: s._adLinkFocusNode,
              onSubmitted: (_) {
                FocusScope.of(
                  s.context,
                ).requestFocus(s._inspectionCityFocusNode);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Количество владельцев',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            s._dropdownField(
              s._ownersCountController,
              'Выберите количество',
              ownersCounts,
            ),
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Город осмотра',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            s._input(
              s._inspectionCityController,
              'Город осмотра',
              textInputAction: TextInputAction.done,
              focusNode: s._inspectionCityFocusNode,
              onSubmitted: (_) => s._dismissKeyboard(),
            ),
          ],
        ),
      ),
    ],
  );
}

// Кнопка «Подтянуть VIN/ГРЗ и данные авто» — единый стиль для обеих
// точек входа. Спиннер на месте иконки во время запроса, disabled при
// невалидном поле-источнике или параллельном запросе.
Widget _buildConverterLookupButton(
  _SparkJoyCreateReportScreenState s, {
  required _ConverterSource source,
  required bool enabled,
  required String label,
}) {
  final loading = s._converterLoading;
  return SizedBox(
    width: double.infinity,
    height: 44,
    child: OutlinedButton.icon(
      onPressed: enabled ? () => s._lookupByVinOrPlate(source) : null,
      icon: loading
          ? const SizedBox(
              width: SparkSize.iconSm,
              height: SparkSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.travel_explore, size: SparkSize.iconSm),
      label: Text(loading ? 'Запрос в ФНС…' : label),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: kBorderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkRadius.md),
        ),
      ),
    ),
  );
}

// DEV-хелпер: тестовые VIN/ГРЗ для мок-проверки converter-API.
// Видимо только при FeatureFlags.useConverterMock == true. При
// переключении на реальный API исчезнет автоматически. Перед
// релизом (с живым токеном) удалить — grep «DEV-хелпер» найдёт
// эту функцию и её вызов в _buildSparkJoyStepVehicle.
Widget _buildConverterDevHelper(_SparkJoyCreateReportScreenState s) {
  if (!FeatureFlags.useConverterMock) return const SizedBox.shrink();

  // Все триггеры — валидные 17-символьные VIN'ы (проходят полевой
  // валидатор VIN, [A-HJ-NPR-Z0-9]{17}), чтобы кнопка «Подтянуть …»
  // активировалась. Плюс один ГРЗ для плейт-флоу. Значения взяты из
  // [ConverterApiMock] — общий источник истины.
  const cases = <List<String>>[
    <String>[ConverterApiMock.triggerDocVin,
        'VIN из доки → PEUGEOT 308, 2008, ГРЗ С812МУ93'],
    <String>[ConverterApiMock.triggerDocPlateCyr,
        'ГРЗ из доки → тот же Peugeot'],
    <String>['XWEGH81BBM0012345',
        'Любой валидный VIN → заглушка Toyota Camry'],
    <String>['А001АА777', 'Любой валидный ГРЗ → заглушка VW Polo'],
    <String>[ConverterApiMock.triggerNotFound,
        'Не найдено (found: false)'],
    <String>[ConverterApiMock.triggerError498,
        'Ошибка API (admin): «временно недоступен»'],
    <String>[ConverterApiMock.triggerOffline,
        'Эмуляция отсутствия интернета'],
  ];

  return Container(
    margin: const EdgeInsets.only(bottom: SparkSpace.md),
    decoration: BoxDecoration(
      color: kYellowColor.withValues(alpha: 0.08),
      border: Border.all(color: kYellowColor.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(SparkRadius.md),
    ),
    child: Theme(
      data: Theme.of(s.context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: SparkSpace.md),
        childrenPadding: const EdgeInsets.only(
          left: SparkSpace.md,
          right: SparkSpace.md,
          bottom: SparkSpace.md,
        ),
        leading: const Icon(
          Icons.science_outlined,
          size: SparkSize.iconMd,
          color: kYellowColor,
        ),
        title: const MyText(
          text: 'Тестовые VIN/ГРЗ (DEV)',
          size: SparkTextSize.caption,
          weight: FontWeight.w700,
        ),
        subtitle: const MyText(
          text: 'Удалить перед релизом',
          size: SparkTextSize.caption,
          color: kGreyColor,
        ),
        children: <Widget>[
          for (final c in cases)
            _buildConverterDevRow(s, inn: c[0], description: c[1]),
        ],
      ),
    ),
  );
}

Widget _buildConverterDevRow(
  _SparkJoyCreateReportScreenState s, {
  required String inn,
  required String description,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(SparkRadius.xs),
    onTap: () async {
      await Clipboard.setData(ClipboardData(text: inn));
      HapticFeedback.selectionClick();
      if (!s.mounted) return;
      ScaffoldMessenger.of(s.context).showSnackBar(
        SnackBar(
          content: Text('Скопировано: $inn'),
          duration: const Duration(seconds: 2),
        ),
      );
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xs,
        vertical: SparkSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  inn,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: <String>['Courier', 'Menlo'],
                    fontWeight: FontWeight.w700,
                    fontSize: SparkTextSize.body,
                  ),
                ),
                const SizedBox(height: SparkSpace.xxs),
                MyText(
                  text: description,
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          const Icon(
            Icons.copy_outlined,
            size: SparkSize.iconSm,
            color: kGreyColor,
          ),
        ],
      ),
    ),
  );
}

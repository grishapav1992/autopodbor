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

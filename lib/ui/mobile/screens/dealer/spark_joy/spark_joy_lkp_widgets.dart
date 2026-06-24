part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyLkpWidgets on _SparkJoyCreateReportScreenState {
  Widget _paintRangeBlock({
    required String title,
    required double from,
    required double to,
    required ValueChanged<RangeValues> onChanged,
  }) {
    final safeFrom = from.clamp(50, 1500).toDouble();
    final safeTo = to.clamp(safeFrom, 1500).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MyText(
                text: title,
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 82,
              child: _paintManualValueField(
                label: 'От',
                value: safeFrom,
                showLabel: false,
                hint: '',
                onSubmitted: (manualFrom) {
                  final fromValue = manualFrom.toDouble();
                  final toValue = math.max(fromValue, safeTo);
                  onChanged(RangeValues(fromValue, toValue));
                },
              ),
            ),
            const SizedBox(width: SparkSpace.sm),
            const MyText(
              text: '—',
              size: SparkTextSize.label,
              color: kGreyColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            SizedBox(
              width: 82,
              child: _paintManualValueField(
                label: 'До',
                value: safeTo,
                showLabel: false,
                hint: '',
                onSubmitted: (manualTo) {
                  final toValue = manualTo.toDouble();
                  final fromValue = math.min(safeFrom, toValue);
                  onChanged(RangeValues(fromValue, toValue));
                },
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            const MyText(
              text: 'мкм',
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.xs),
        RangeSlider(
          values: RangeValues(safeFrom, safeTo),
          min: 50,
          max: 1500,
          divisions: 29,
          onChanged: onChanged,
        ),
        const Row(
          children: [
            MyText(text: '50', size: SparkTextSize.chip, color: kGreyColor),
            Spacer(),
            MyText(text: '1500', size: SparkTextSize.chip, color: kGreyColor),
          ],
        ),
      ],
    );
  }

  Widget _paintManualValueField({
    required String label,
    required double value,
    required ValueChanged<int> onSubmitted,
    bool showLabel = true,
    String hint = 'мкм',
  }) {
    var rawValue = value.round().toString();
    void submitRawValue() {
      final parsed = int.tryParse(rawValue.trim());
      if (parsed == null) return;
      onSubmitted(parsed.clamp(50, 1500));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          MyText(text: label, size: SparkTextSize.chip, color: kGreyColor),
          const SizedBox(height: SparkSpace.xs),
        ],
        TextFormField(
          key: ValueKey('$label-${value.round()}'),
          initialValue: value.round().toString(),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            rawValue = value;
            final parsed = int.tryParse(value.trim());
            if (parsed == null) return;
            if (parsed < 50) return;
            onSubmitted(parsed.clamp(50, 1500));
          },
          onEditingComplete: submitRawValue,
          onTapOutside: (_) {
            _dismissKeyboard();
          },
          decoration: _fieldDecoration(hint).copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          onFieldSubmitted: (_) => submitRawValue(),
        ),
      ],
    );
  }

  Widget _mediaMileageBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Пробег (км)',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
            requiredMark: true,
          ),
          const SizedBox(height: SparkSpace.md),
          TextField(
            controller: _mileageController,
            focusNode: _mileageFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _dismissKeyboard(),
            onTapOutside: (_) => _dismissKeyboard(),
            onChanged: (value) {
              final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
              if (cleaned == value) return;
              _mileageController.value = TextEditingValue(
                text: cleaned,
                selection: TextSelection.collapsed(offset: cleaned.length),
              );
            },
            // Заголовок «Пробег (км)» уже стоит над полем (line 149);
            // дублировать его как hint в decoration не нужно.
            decoration: _fieldDecoration('Введите пробег'),
          ),
          const SizedBox(height: SparkSpace.lg),
          _yesNoSelector(
            title: 'Пробег соответствует состоянию?',
            value: _mileageMismatch == null ? null : !_mileageMismatch!,
            allowClear: false,
            positiveLabel: 'Да',
            negativeLabel: 'Нет',
            compact: true,
            wrapWithCard: false,
            onChanged: (v) =>
                _setStateSafely(() => _mileageMismatch = v == null ? null : !v),
          ),
        ],
      ),
    );
  }
}

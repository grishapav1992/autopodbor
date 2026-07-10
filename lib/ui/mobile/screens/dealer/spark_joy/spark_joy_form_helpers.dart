part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyFormHelpersMethods on _SparkJoyCreateReportScreenState {
  Widget _card({
    required Widget child,
    EdgeInsets? padding,
    Color? borderColor,
    Color? backgroundColor,
  }) {
    return SparkCard(
      padding: padding ?? const EdgeInsets.all(SparkSpace.xl),
      borderColor: borderColor ?? kBorderColor,
      backgroundColor: backgroundColor ?? kWhiteColor,
      child: child,
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    FocusNode? focusNode,
    bool readOnly = false,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      focusNode: focusNode,
      readOnly: readOnly,
      onTap: onTap,
      onTapOutside: (_) => _dismissKeyboard(),
      onSubmitted: onSubmitted,
      decoration: _fieldDecoration(hint).copyWith(
        contentPadding: EdgeInsets.symmetric(
          horizontal: SparkSpace.xl,
          vertical: minLines > 1 ? SparkSpace.xl : SparkSpace.lg,
        ),
      ),
    );
  }

  Widget _dropdownField(
    TextEditingController controller,
    String hint,
    List<String> options, {
    bool clearable = false,
  }) {
    final selected = options.contains(controller.text.trim())
        ? controller.text.trim()
        : null;
    return DropdownButtonFormField<String>(
      // FormField берёт `initialValue` только при первом построении и
      // игнорирует его при rebuild → программная установка `controller.text`
      // (ИИ-автозаполнение по VIN, конвертер) НЕ отображалась бы в дропдауне.
      // Ключ, завязанный на текущее значение, пересоздаёт FormField при смене →
      // выбор виден. Hint в ключе — чтобы соседние дропдауны не коллизили.
      key: ValueKey('$hint::${selected ?? ''}'),
      initialValue: selected,
      // Cap the popup height so long option lists (e.g. 43 engine volumes
      // from 0.8→7.0L) don't render near-full-screen. Short lists like
      // engine type / gearbox sit well under this ceiling already, so
      // their behaviour is unchanged.
      menuMaxHeight: 320,
      decoration: _fieldDecoration(hint).copyWith(
        suffixIcon: clearable && selected != null
            ? IconButton(
                onPressed: () {
                  _setStateSafely(() {
                    controller.text = '';
                  });
                  _markDraftDirty();
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: SparkTextSize.titleLg,
                  color: kGreyColor,
                ),
                tooltip: 'Очистить',
              )
            : null,
      ),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: (value) {
        _setStateSafely(() {
          controller.text = value ?? '';
        });
        _markDraftDirty();
      },
    );
  }

  Widget _yesNoSelector({
    required String title,
    required bool? value,
    required ValueChanged<bool?> onChanged,
    String? subtitle,
    Color subtitleColor = kGreyColor,
    String positiveLabel = 'Да',
    String negativeLabel = 'Нет',
    bool allowClear = false,
    String clearLabel = 'Сбросить выбор',
    bool compact = false,
    bool wrapWithCard = true,
    bool required = false,
  }) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SparkRadius.lg),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyText(
          text: title,
          size: compact ? 12 : 13,
          weight: FontWeight.w700,
          requiredMark: required,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: SparkSpace.xxxs),
          MyText(text: subtitle, size: compact ? 10 : 11, color: subtitleColor),
        ],
        SizedBox(height: compact ? 6 : 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  onChanged(allowClear && value == true ? null : true);
                  _markDraftDirty();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: value == true ? kGreenColor : kBorderColor,
                  ),
                  backgroundColor: value == true
                      ? kGreenColor.withValues(alpha: 0.1)
                      : kWhiteColor,
                  minimumSize: Size(
                    0,
                    compact ? SparkSize.actionHeightMd : SparkSize.inputHeight,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 8 : 10,
                  ),
                  shape: buttonShape,
                ),
                child: Text(
                  positiveLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: value == true ? kGreenColor : kGreyColor,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  onChanged(allowClear && value == false ? null : false);
                  _markDraftDirty();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: value == false ? kRedColor : kBorderColor,
                  ),
                  backgroundColor: value == false
                      ? kRedColor.withValues(alpha: 0.1)
                      : kWhiteColor,
                  minimumSize: Size(
                    0,
                    compact ? SparkSize.actionHeightMd : SparkSize.inputHeight,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 8 : 10,
                  ),
                  shape: buttonShape,
                ),
                child: Text(
                  negativeLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: value == false ? kRedColor : kGreyColor,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (allowClear) ...[
          const SizedBox(height: SparkSpace.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: value == null
                  ? null
                  : () {
                      onChanged(null);
                      _markDraftDirty();
                    },
              child: Text(clearLabel),
            ),
          ),
        ],
      ],
    );

    if (!wrapWithCard) return content;
    return _card(child: content);
  }
}

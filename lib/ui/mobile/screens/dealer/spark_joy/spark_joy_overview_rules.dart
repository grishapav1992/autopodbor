part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyOverviewRulesMethods on _SparkJoyCreateReportScreenState {
  Widget _sectionHeading(
    String title, {
    required IconData icon,
    String subtitle = '',
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.md),
      child: Row(
        children: [
          Container(
            width: SparkSize.navStepBadge,
            height: SparkSize.navStepBadge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SparkRadius.sm),
              color: kSecondaryColor.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: SparkSize.iconSm, color: kSecondaryColor),
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: title,
                  size: SparkTextSize.sectionTitle,
                  weight: FontWeight.w700,
                  requiredMark: required,
                ),
                if (subtitle.trim().isNotEmpty)
                  MyText(
                    text: subtitle,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Лёгкий подзаголовок блока внутри шага: жирный [title], опционально
  /// серым « · [hint]». Используется в шаге «Автомобиль» вместо иконочного
  /// [_sectionHeading] для компактных секций («Модель», «Состояние»).
  Widget _lightSectionHeading(String title, [String hint = '']) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          MyText(
            text: title,
            size: SparkTextSize.sectionTitle,
            weight: FontWeight.w700,
          ),
          if (hint.trim().isNotEmpty)
            Flexible(
              child: MyText(
                text: '  ·  $hint',
                size: SparkTextSize.caption,
                color: kGreyColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(int index, {required _SparkJoyOverviewState overview}) {
    final step = _SparkJoyStepRegistry.steps[index];
    final value = overview.sectionValues[step.id] ?? '';
    final fillState =
        overview.sectionFillStates[step.id] ?? SparkJoySectionFillState.empty;
    return SparkSectionNavCard(
      index: index,
      title: step.title,
      icon: _overviewController.sectionIcon(step.id),
      description: step.description,
      value: value,
      fillState: fillState,
      required: _SparkJoyStepRegistry.isRequiredStep(step.id),
      onTap: () => _openSection(index),
    );
  }

  Widget _sectionsOverview() {
    final overview = _overviewController.build(this);
    final total = _SparkJoyStepRegistry.steps.length;
    final filled = overview.sectionFillStates.values.where((state) {
      return state != SparkJoySectionFillState.empty;
    }).length;
    final progress = total == 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SparkCard(
          radius: SparkRadius.md,
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.xl,
            SparkSpace.lg,
            SparkSpace.xl,
            SparkSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: 'Прогресс отчёта',
                size: SparkTextSize.body,
                weight: FontWeight.w700,
                color: kTertiaryColor,
              ),
              const SizedBox(height: SparkSpace.xxs),
              MyText(
                text: 'Заполнено разделов: $filled из $total',
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
              const SizedBox(height: SparkSpace.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(SparkRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: SparkSize.progress,
                  backgroundColor: kLightGreyColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    kSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SparkSpace.lg),
        _requiredLegend('— обязательный раздел'),
        ...List.generate(_SparkJoyStepRegistry.steps.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: SparkSpace.lg),
            child: _sectionCard(index, overview: overview),
          );
        }),
      ],
    );
  }
}

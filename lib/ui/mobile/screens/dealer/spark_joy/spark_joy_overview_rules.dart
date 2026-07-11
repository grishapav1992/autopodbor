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

  Widget _sectionRow(int index, {required _SparkJoyOverviewState overview}) {
    final step = _SparkJoyStepRegistry.steps[index];
    final fillState =
        overview.sectionFillStates[step.id] ?? SparkJoySectionFillState.empty;
    return SparkSectionStatusRow(
      title: step.title,
      description: step.description,
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
                size: SparkTextSize.sectionTitle,
                weight: FontWeight.w700,
                color: kTertiaryColor,
              ),
              const SizedBox(height: SparkSpace.xxs),
              MyText(
                text: 'Заполнено разделов: $filled из $total',
                size: SparkTextSize.body,
                color: kGreyColor,
              ),
              const SizedBox(height: SparkSpace.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(SparkRadius.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: SparkSize.progress,
                  backgroundColor: kLightGreyColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(kGreenColor),
                ),
              ),
            ],
          ),
        ),
        // Интейк «Фото автомобиля» — между прогрессом и списком разделов
        // (макет «Отчёт - разделы - редизайн», экраны 1a/2b).
        const SizedBox(height: SparkSpace.lg),
        _photoIntakeCard(),
        const SparkSectionTitle('Разделы', top: SparkSpace.xxl),
        SparkCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            // SparkCard не клипует содержимое — без ClipRRect ripple строк
            // вылезал бы за скругления карточки.
            borderRadius: BorderRadius.circular(SparkRadius.lg),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  for (var index = 0; index < total; index++) ...[
                    if (index > 0) const SparkSectionRowDivider(),
                    _sectionRow(index, overview: overview),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepMedia(_SparkJoyCreateReportScreenState s) {
  final requiredGroups = _SparkJoyMediaGroupRegistry.groups
      .where((config) => config.required)
      .toList();
  final optionalGroups = _SparkJoyMediaGroupRegistry.groups
      .where((config) => !config.required)
      .toList();
  final requiredFilled = requiredGroups.where((config) {
    final state = s._mediaState[config.key];
    return state != null && s._groupHasCoverage(state);
  }).length;
  final requiredRemaining = (requiredGroups.length - requiredFilled).clamp(
    0,
    requiredGroups.length,
  );
  final hasRequiredGroups = requiredGroups.isNotEmpty;
  if (s._activeMediaGroupKey != null) {
    return s._mediaGroupEditor();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      s._sectionHeading('Пробег и соответствие', icon: Icons.speed_rounded),
      s._mediaMileageBlock(),
      const SizedBox(height: SparkSpace.lg),
      if (hasRequiredGroups && requiredRemaining > 0) ...[
        SparkHintCard(
          text:
              'Для завершения осмотра заполните ещё $requiredRemaining обязательн${requiredRemaining == 1 ? 'ую' : 'ых'} групп${requiredRemaining == 1 ? 'у' : 'ы'}.',
          icon: Icons.error_outline_rounded,
          textColor: kTertiaryColor,
        ),
        const SizedBox(height: SparkSpace.lg),
      ],
      if (hasRequiredGroups)
        s._sectionHeading(
          'Обязательные · $requiredFilled/${requiredGroups.length}',
          icon: Icons.checklist_rounded,
          subtitle: 'Минимальный набор для завершения осмотра',
        ),
      if (hasRequiredGroups)
        SparkCard(
          radius: SparkRadius.md,
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.md,
            SparkSpace.md,
            SparkSpace.md,
            SparkSpace.xs,
          ),
          child: Column(
            children: requiredGroups.map((config) {
              final state = s._mediaState[config.key]!;
              return s._mediaGroupListRow(state);
            }).toList(),
          ),
        ),
      if (hasRequiredGroups) const SizedBox(height: SparkSpace.md),
      s._sectionHeading(
        hasRequiredGroups ? 'Дополнительные' : 'Разделы осмотра',
        icon: Icons.photo_library_outlined,
      ),
      if (optionalGroups.isEmpty)
        const SparkHintCard(
          text: 'Дополнительные группы не настроены.',
          icon: Icons.info_outline_rounded,
        )
      else
        SparkCard(
          radius: SparkRadius.md,
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.md,
            SparkSpace.md,
            SparkSpace.md,
            SparkSpace.xs,
          ),
          child: Column(
            children: optionalGroups.map((config) {
              final state = s._mediaState[config.key]!;
              return s._mediaGroupListRow(state);
            }).toList(),
          ),
        ),
    ],
  );
}

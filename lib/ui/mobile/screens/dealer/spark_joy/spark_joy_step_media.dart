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

  // Обе группы (обязательные + дополнительные) живут в общей
  // рамке-зоне «Осмотр». `_mediaGroupListRow` сам возвращает
  // SparkCard, поэтому средний card-обёртки не нужен (иначе выходит
  // каскад «frame → card → card на каждый ряд»). Цвет фона без
  // border — Сам lightGrey достаточно отделяет зону.
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
      Container(
        padding: const EdgeInsets.fromLTRB(
          SparkSpace.md,
          SparkSpace.md,
          SparkSpace.md,
          SparkSpace.xs,
        ),
        decoration: BoxDecoration(
          color: kLightGreyColor,
          borderRadius: BorderRadius.circular(SparkRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasRequiredGroups) ...[
              s._sectionHeading(
                'Обязательные · $requiredFilled/${requiredGroups.length}',
                icon: Icons.checklist_rounded,
                subtitle: 'Минимальный набор для завершения осмотра',
              ),
              ...requiredGroups.map((config) {
                final state = s._mediaState[config.key]!;
                return s._mediaGroupListRow(state);
              }),
              const SizedBox(height: SparkSpace.sm),
            ],
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
              ...optionalGroups.map((config) {
                final state = s._mediaState[config.key]!;
                return s._mediaGroupListRow(state);
              }),
          ],
        ),
      ),
    ],
  );
}

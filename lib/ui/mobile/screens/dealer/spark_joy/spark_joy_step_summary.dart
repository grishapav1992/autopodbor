part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepSummary(_SparkJoyCreateReportScreenState s) {
  if (!s.widget.readOnly) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!s.mounted) return;
      SparkJoyOnboarding.showOnce(
        s.context,
        flagKey: UserSimplePreferences.sparkOnbSummaryStepKey,
        titleI18nKey: 'spark.onboarding.summaryStep.title',
        titleFallback: 'Итог осмотра',
        bullets: const [
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.summaryStep.b1',
            fallback:
                'Это финальный итог всего осмотра — сводка по всем разделам отчёта в одном месте.',
            icon: Icons.fact_check_outlined,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.summaryStep.b2',
            fallback:
                'Проверьте, что все обязательные поля заполнены — нехватка показана в чек-листе ниже.',
            icon: Icons.checklist_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.summaryStep.b3',
            fallback:
                'Тапните «Завершить и выгрузить» — после загрузки отчёт переедет в раздел «Завершённые».',
            icon: Icons.cloud_upload_outlined,
          ),
        ],
      );
    });
  }

  final summary = s._calculateSummary();
  // Attention highlights are work-in-progress signals: they turn
  // section cards yellow and drive the "Дополнить: N" chip. A
  // read-only completed report must not show them — pretend every
  // section is complete.
  final isReadOnly = s.widget.readOnly;
  final missingReasons = isReadOnly
      ? const <String>[]
      : s._summaryMissingReasons();
  final attentionStepIds = <String>{};
  final attentionGroupKeys = <String>{};
  for (final reason in missingReasons) {
    final stepId = s._summaryReasonStepId(reason);
    if (stepId != null) {
      // Раньше здесь выставлялся флаг expertNeedsAttention для жёлтой
      // подсветки карточки «Итог специалиста». После слияния в единый
      // «Итог осмотра» отдельной карточки нет — её missing-reasons
      // показываются в общей gap-сводке выше.
      if (!_SparkJoySummaryRegistry.isSummaryStep(stepId) &&
          !_SparkJoySummaryRegistry.isMediaStep(stepId)) {
        attentionStepIds.add(stepId);
      }
    }
    final mediaGroupKey = s._summaryReasonMediaGroupKey(reason);
    if (mediaGroupKey != null) {
      attentionGroupKeys.add(mediaGroupKey);
    }
  }

  return Column(
    children: [
      s._summaryHeaderCard(),
      const SizedBox(height: SparkSpace.lg),
      s._summaryNoDamageMediaCard(),
      if (s._mediaState.values.any(
        (state) => state.files.any((file) => !s._mediaItemHasIssue(file)),
      ))
        const SizedBox(height: SparkSpace.lg),
      s._summarySectionsList(
        summary,
        attentionStepIds: attentionStepIds,
        attentionGroupKeys: attentionGroupKeys,
      ),
      const SizedBox(height: SparkSpace.lg),
      // Единый блок «Итог осмотра» — заменил пару карточек «Сводка по
      // данным осмотра» + «Итог специалиста». ИИ + надиктовка + ручной
      // ввод в одном поле. См. _buildSparkSummaryNoteCard.
      s._summaryNoteCard(),
    ],
  );
}

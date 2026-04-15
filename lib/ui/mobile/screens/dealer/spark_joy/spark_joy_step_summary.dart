part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepSummary(_SparkJoyCreateReportScreenState s) {
  final summary = s._calculateSummary();
  final missingReasons = s._summaryMissingReasons();
  final attentionStepIds = <String>{};
  final attentionGroupKeys = <String>{};
  var expertNeedsAttention = false;
  for (final reason in missingReasons) {
    final stepId = s._summaryReasonStepId(reason);
    if (stepId != null) {
      if (_SparkJoySummaryRegistry.isSummaryStep(stepId)) {
        expertNeedsAttention = true;
      } else if (!_SparkJoySummaryRegistry.isMediaStep(stepId)) {
        attentionStepIds.add(stepId);
      } else {
        // For "Осмотр" highlight only конкретные группы по ключу.
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
      s._summaryNoteCard(),
      const SizedBox(height: SparkSpace.lg),
      s._summaryExpertConclusionCard(needsAttention: expertNeedsAttention),
    ],
  );
}

part of 'spark_joy_create_report_screen.dart';

extension _SparkJoySummaryAdapters on _SparkJoyCreateReportScreenState {
  Color _summaryDetailSeverityColor(String severity) {
    return _sparkSummaryDetailSeverityColor(severity);
  }

  Widget _summarySectionMediaPreview(String title) {
    return _buildSparkSummarySectionMediaPreview(this, title);
  }

  Widget _summaryNoDamageMediaCard() {
    return _buildSparkSummaryNoDamageMediaCard(this);
  }

  Widget _summarySectionCard(
    Map<String, dynamic> section, {
    bool clientPreview = false,
    bool needsAttention = false,
    bool compactDetails = false,
  }) {
    return _buildSparkSummarySectionCard(
      this,
      section,
      clientPreview: clientPreview,
      needsAttention: needsAttention,
      compactDetails: compactDetails,
    );
  }

  Widget _summarySectionsList(
    _CalculatedSummary summary, {
    required Set<String> attentionStepIds,
    required Set<String> attentionGroupKeys,
  }) {
    return _buildSparkSummarySectionsList(
      this,
      summary,
      attentionStepIds: attentionStepIds,
      attentionGroupKeys: attentionGroupKeys,
    );
  }

  Widget _summaryNoteCard() {
    return _buildSparkSummaryNoteCard(this);
  }

  Widget _stepSummary() => _buildSparkJoyStepSummary(this);

  Widget _sectionEditor() => _buildSparkJoySectionEditor(this);
}

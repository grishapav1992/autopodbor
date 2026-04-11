part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyOverviewRulesMethods on _SparkJoyCreateReportScreenState {
  Widget _sectionHeading(
    String title, {
    required IconData icon,
    String subtitle = '',
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

  Widget _sectionCard(int index, {required _SparkJoyOverviewState overview}) {
    final step = _SparkJoyStepRegistry.steps[index];
    final isSummary = _SparkJoyStepRegistry.isSummaryStepId(step.id);
    final value = overview.sectionValues[step.id] ?? '';
    final done = value.isNotEmpty;
    return SparkSectionNavCard(
      index: index,
      title: step.title,
      icon: _overviewController.sectionIcon(step.id),
      description: step.description,
      value: value,
      done: done,
      isSummary: isSummary,
      onTap: () => _openSection(index),
    );
  }

  Widget _sectionsOverview() {
    final overview = _overviewController.build(this);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SparkReportOverviewHeaderCard(
          title: _reportTitle(),
          meta: sjFormatReportMeta(_reportCode, _createdAt),
          draftStatusText: _draftSaveStatusText(),
          draftStatusColor: _draftSaveStatusColor(),
          currentStepPrefix: _SparkJoyOverviewController.currentStepPrefix,
          currentStepTitle: overview.currentTitle,
        ),
        const SizedBox(height: SparkSpace.lg),
        Row(
          children: [
            Expanded(
              child: SparkStatTile(
                title: _SparkJoyOverviewController.completedStatTitle,
                value: '${overview.completed}/${overview.total}',
                icon: Icons.task_alt_rounded,
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: SparkStatTile(
                title: _SparkJoyOverviewController.remainingStatTitle,
                value: '${overview.remaining}',
                icon: Icons.pending_actions_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.lg),
        SparkProgressSummaryCard(
          completed: overview.completed,
          total: overview.total,
          progress: overview.progress,
        ),
        const SizedBox(height: SparkSpace.section),
        const MyText(
          text: _SparkJoyOverviewController.sectionsHeaderTitle,
          size: SparkTextSize.sectionTitle,
          weight: FontWeight.w700,
        ),
        const SizedBox(height: SparkSpace.lg),
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

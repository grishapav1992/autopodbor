part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepContent(_SparkJoyCreateReportScreenState s) {
  switch (_SparkJoyStepRegistry.idAt(s._stepIndex)) {
    case _SparkJoyStepRegistry.idVehicle:
      return s._stepVehicle();
    case _SparkJoyStepRegistry.idParams:
      return s._stepParams();
    case _SparkJoyStepRegistry.idDocsCheck:
      return s._stepDocsCheck();
    case _SparkJoyStepRegistry.idLegal:
      return s._stepLegal();
    case _SparkJoyStepRegistry.idMedia:
      return s._stepMedia();
    case _SparkJoyStepRegistry.idTestDrive:
      return s._stepTestDrive();
    default:
      return s._stepSummary();
  }
}

Widget _buildSparkJoyStepHero(
  _SparkJoyCreateReportScreenState s, {
  required _SparkJoyStepActionState actionState,
}) {
  final statusColor = actionState.isDone ? kGreenColor : kYellowColor;

  return SparkStepHeroCard(
    icon: s._overviewController.sectionIcon(actionState.step.id),
    currentStep: actionState.currentStep,
    totalSteps: actionState.totalSteps,
    title: actionState.step.title,
    description: actionState.step.description,
    statusText: actionState.statusText,
    statusColor: statusColor,
    stepProgress: actionState.stepProgress,
    currentValue: actionState.currentValue,
    hideProgressBar: actionState.hideProgressBar,
  );
}

Widget _buildSparkJoyValidationHint(String text) {
  return SparkCard(
    padding: const EdgeInsets.symmetric(
      horizontal: SparkSpace.xl,
      vertical: SparkSpace.lg,
    ),
    borderColor: kRedColor2.withValues(alpha: 0.35),
    backgroundColor: kRedColor2.withValues(alpha: 0.06),
    radius: SparkRadius.md,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: kRedColor,
          size: SparkSize.iconSm,
        ),
        const SizedBox(width: SparkSpace.sm),
        Expanded(
          child: MyText(
            text: text,
            size: SparkTextSize.caption,
            color: kRedColor,
            weight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSparkJoySectionEditor(_SparkJoyCreateReportScreenState s) {
  final actionState = s._stepActionController.build(s);

  return Column(
    children: [
      if (!actionState.inMediaGroupEditor)
        _buildSparkJoyStepHero(s, actionState: actionState),
      if (!actionState.inMediaGroupEditor)
        const SizedBox(height: SparkSpace.xl),
      _buildSparkJoyStepContent(s),
      if (!actionState.inMediaGroupEditor &&
          actionState.isDocsCheckStep &&
          !actionState.canDocsCheckContinue) ...[
        const SizedBox(height: SparkSpace.md),
        _buildSparkJoyValidationHint(actionState.docsCheckReasons.join(' · ')),
      ],
      if (!actionState.inMediaGroupEditor &&
          actionState.isMediaStep &&
          !actionState.canMediaContinue) ...[
        const SizedBox(height: SparkSpace.md),
        _buildSparkJoyValidationHint(
          'Добавьте фото: ${actionState.missingMediaGroups.join(', ')}',
        ),
      ],
      if (!actionState.inMediaGroupEditor &&
          actionState.isTestDriveStep &&
          !actionState.canTestDriveContinue) ...[
        const SizedBox(height: SparkSpace.md),
        _buildSparkJoyValidationHint(actionState.testDriveReasons.join(' · ')),
      ],
      if (!actionState.inMediaGroupEditor &&
          actionState.isSummaryStep &&
          !actionState.canSummaryFinish) ...[
        const SizedBox(height: SparkSpace.md),
        _buildSparkJoyValidationHint(actionState.summaryReasons.join(' · ')),
      ],
      if (!actionState.inMediaGroupEditor) ...[
        const SizedBox(height: SparkSpace.xl),
        SparkStepActionBar(
          secondaryLabel: 'К разделам',
          onSecondaryTap: () => s._closeSection(save: true),
          primaryLabel: actionState.isLast
              ? 'Завершить и выгрузить'
              : 'Продолжить',
          primaryDisabled: actionState.continueButtonDisabled,
          onPrimaryTap: () =>
              s._stepActionController.handlePrimaryTap(s, actionState),
        ),
      ],
    ],
  );
}

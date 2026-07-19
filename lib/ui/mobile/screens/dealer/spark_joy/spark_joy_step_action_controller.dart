part of 'spark_joy_create_report_screen.dart';

class _SparkJoyStepActionState {
  const _SparkJoyStepActionState({
    required this.step,
    required this.totalSteps,
    required this.currentStep,
    required this.isLast,
    required this.isVehicleStep,
    required this.isDocsCheckStep,
    required this.isMediaStep,
    required this.inMediaGroupEditor,
    required this.isTestDriveStep,
    required this.isSummaryStep,
    required this.vehicleMissingReasons,
    required this.canVehicleContinue,
    required this.missingMediaGroups,
    required this.canMediaContinue,
    required this.docsCheckReasons,
    required this.canDocsCheckContinue,
    required this.testDriveReasons,
    required this.canTestDriveContinue,
    required this.summaryReasons,
    required this.canSummaryFinish,
    required this.continueButtonDisabled,
    required this.isDone,
    required this.statusText,
  });

  final _StepConfig step;
  final int totalSteps;
  final int currentStep;
  final bool isLast;
  final bool isVehicleStep;
  final bool isDocsCheckStep;
  final bool isMediaStep;
  final bool inMediaGroupEditor;
  final bool isTestDriveStep;
  final bool isSummaryStep;
  final List<String> vehicleMissingReasons;
  final bool canVehicleContinue;
  final List<String> missingMediaGroups;
  final bool canMediaContinue;
  final List<String> docsCheckReasons;
  final bool canDocsCheckContinue;
  final List<String> testDriveReasons;
  final bool canTestDriveContinue;
  final List<String> summaryReasons;
  final bool canSummaryFinish;
  final bool continueButtonDisabled;
  final bool isDone;
  final String statusText;
}

class _SparkJoyStepActionController {
  const _SparkJoyStepActionController();

  _SparkJoyStepActionState build(_SparkJoyCreateReportScreenState s) {
    final step = _SparkJoyStepRegistry.steps[s._stepIndex];
    final totalSteps = _SparkJoyStepRegistry.steps.length;
    final currentStep = s._stepIndex + 1;
    final isLast = _SparkJoyStepRegistry.isSummaryStepId(step.id);
    final isVehicleStep = step.id == _SparkJoyStepRegistry.idVehicle;
    final isDocsCheckStep = step.id == _SparkJoyStepRegistry.idDocsCheck;
    final isMediaStep = step.id == _SparkJoyStepRegistry.idMedia;
    final inMediaGroupEditor = isMediaStep && s._activeMediaGroupKey != null;
    final isTestDriveStep = step.id == _SparkJoyStepRegistry.idTestDrive;
    final isSummaryStep = _SparkJoyStepRegistry.isSummaryStepId(step.id);
    final vehicleMissingReasons = isVehicleStep
        ? s._vehicleMissingReasons()
        : const <String>[];
    final canVehicleContinue = vehicleMissingReasons.isEmpty;
    final missingMediaGroups = isMediaStep
        ? s._missingRequiredMediaGroups().map((e) => e.title).toList()
        : const <String>[];
    final canMediaContinue = missingMediaGroups.isEmpty;
    final docsCheckReasons = isDocsCheckStep
        ? s._docsCheckMissingReasons()
        : const <String>[];
    final canDocsCheckContinue = docsCheckReasons.isEmpty;
    final testDriveReasons = isTestDriveStep
        ? s._testDriveMissingReasons()
        : const <String>[];
    final canTestDriveContinue = testDriveReasons.isEmpty;
    final summaryReasons = isSummaryStep
        ? s._summaryMissingReasons()
        : const <String>[];
    final canSummaryFinish = summaryReasons.isEmpty;
    final canContinueCurrentStep =
        (!isVehicleStep || canVehicleContinue) &&
        (!isDocsCheckStep || canDocsCheckContinue) &&
        (!isMediaStep || canMediaContinue) &&
        (!isTestDriveStep || canTestDriveContinue);
    final continueButtonDisabled = isLast
        ? !canSummaryFinish
        : !canContinueCurrentStep;
    final fillState = s._overviewController.sectionFillState(s, step.id);
    final isDone = fillState == SparkJoySectionFillState.done;
    final statusText = isDone ? 'Заполнено' : 'В работе';

    return _SparkJoyStepActionState(
      step: step,
      totalSteps: totalSteps,
      currentStep: currentStep,
      isLast: isLast,
      isVehicleStep: isVehicleStep,
      isDocsCheckStep: isDocsCheckStep,
      isMediaStep: isMediaStep,
      inMediaGroupEditor: inMediaGroupEditor,
      isTestDriveStep: isTestDriveStep,
      isSummaryStep: isSummaryStep,
      vehicleMissingReasons: vehicleMissingReasons,
      canVehicleContinue: canVehicleContinue,
      missingMediaGroups: missingMediaGroups,
      canMediaContinue: canMediaContinue,
      docsCheckReasons: docsCheckReasons,
      canDocsCheckContinue: canDocsCheckContinue,
      testDriveReasons: testDriveReasons,
      canTestDriveContinue: canTestDriveContinue,
      summaryReasons: summaryReasons,
      canSummaryFinish: canSummaryFinish,
      continueButtonDisabled: continueButtonDisabled,
      isDone: isDone,
      statusText: statusText,
    );
  }

  Future<void> handlePrimaryTap(
    _SparkJoyCreateReportScreenState s,
    _SparkJoyStepActionState state,
  ) async {
    if (state.isLast) {
      if (!state.canSummaryFinish) {
        _showValidationSnack(
          s.context,
          'Заполните данные в блоке «Что заполнить».',
        );
        _scrollToSummaryRequiredActions(s);
        return;
      }
      await s._finishReport();
      return;
    }

    if (state.isVehicleStep) {
      await s._handleVehicleContinue();
      return;
    }
    if (state.isMediaStep) {
      if (!state.canMediaContinue) {
        _showValidationSnack(
          s.context,
          'Добавьте фото в группы: ${state.missingMediaGroups.join(', ')}',
        );
        return;
      }
      await s._saveAndOpenNextSection();
      return;
    }
    if (state.isDocsCheckStep) {
      if (!state.canDocsCheckContinue) {
        _showValidationSnack(s.context, state.docsCheckReasons.join('\n'));
        return;
      }
      await s._saveAndOpenNextSection();
      return;
    }
    if (state.isTestDriveStep) {
      if (!state.canTestDriveContinue) {
        _showValidationSnack(s.context, state.testDriveReasons.join('\n'));
        return;
      }
      await s._saveAndOpenNextSection();
      return;
    }
    await s._saveAndOpenNextSection();
  }

  void _showValidationSnack(BuildContext context, String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _scrollToSummaryRequiredActions(_SparkJoyCreateReportScreenState s) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!s.mounted || !s._pageScrollController.hasClients) return;
      unawaited(
        s._pageScrollController.animateTo(
          s._pageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }
}

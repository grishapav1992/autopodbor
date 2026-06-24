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
    description: '',
    statusText: actionState.statusText,
    statusColor: statusColor,
    stepProgress: actionState.stepProgress,
    currentValue: '',
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

Color _sparkJoyUploadStatusColor(BackendUploadFileStatus status) {
  switch (status) {
    case BackendUploadFileStatus.uploaded:
      return kGreenColor;
    case BackendUploadFileStatus.failed:
      return kRedColor;
    case BackendUploadFileStatus.uploading:
      return kSecondaryColor;
    case BackendUploadFileStatus.pending:
      return kGreyColor;
  }
}

IconData _sparkJoyUploadStatusIcon(BackendUploadFileStatus status) {
  switch (status) {
    case BackendUploadFileStatus.uploaded:
      return Icons.check_circle_rounded;
    case BackendUploadFileStatus.failed:
      return Icons.error_rounded;
    case BackendUploadFileStatus.uploading:
      return Icons.cloud_upload_rounded;
    case BackendUploadFileStatus.pending:
      return Icons.schedule_rounded;
  }
}

String _sparkJoyUploadStatusText(BackendUploadFileProgress file) {
  switch (file.status) {
    case BackendUploadFileStatus.uploaded:
      return 'Загружен';
    case BackendUploadFileStatus.failed:
      return 'Ошибка';
    case BackendUploadFileStatus.uploading:
      final percent = (file.progress * 100).round().clamp(0, 100);
      return '$percent%';
    case BackendUploadFileStatus.pending:
      return 'Ожидание';
  }
}

Widget _buildSparkJoyUploadFileRow(BackendUploadFileProgress file) {
  final statusColor = _sparkJoyUploadStatusColor(file.status);
  final statusText = _sparkJoyUploadStatusText(file);
  final showProgress =
      file.status == BackendUploadFileStatus.uploading ||
      (file.status == BackendUploadFileStatus.failed && file.progress > 0);
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: SparkSpace.md,
      vertical: SparkSpace.sm,
    ),
    decoration: BoxDecoration(
      color: kWhiteColor.withValues(alpha: 0.66),
      borderRadius: BorderRadius.circular(SparkRadius.sm),
      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              _sparkJoyUploadStatusIcon(file.status),
              size: SparkSize.iconSm,
              color: statusColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            Expanded(
              child: MyText(
                text: '${file.index}. ${file.fileName}',
                size: SparkTextSize.body,
                color: kPrimaryColor,
                weight: FontWeight.w600,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: SparkSpace.sm),
            MyText(
              text: statusText,
              size: SparkTextSize.caption,
              color: statusColor,
              weight: FontWeight.w700,
            ),
          ],
        ),
        if (showProgress) ...[
          const SizedBox(height: SparkSpace.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(SparkRadius.pill),
            child: LinearProgressIndicator(
              value: file.progress.clamp(0.0, 1.0),
              minHeight: SparkSpace.xs,
              backgroundColor: statusColor.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
        if (file.totalParts > 0) ...[
          const SizedBox(height: SparkSpace.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: MyText(
              text:
                  'часть ${file.uploadedParts.clamp(0, file.totalParts)}/${file.totalParts}',
              size: SparkTextSize.caption,
              color: kGreyColor,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildSparkJoyUploadHint(
  String text, {
  // null → индетерминированный (анимированный) бар: используется на фазах без
  // пофайлового процента (флаш AI, серверная подготовка, превью, финализация),
  // чтобы бар не «застывал» на 0% и не выглядел как зависание.
  required double? progress,
  required List<BackendUploadFileProgress> files,
}) {
  return SparkCard(
    padding: const EdgeInsets.symmetric(
      horizontal: SparkSpace.xl,
      vertical: SparkSpace.lg,
    ),
    borderColor: kSecondaryColor.withValues(alpha: 0.24),
    backgroundColor: kSecondaryColor.withValues(alpha: 0.06),
    radius: SparkRadius.md,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: SparkSize.iconSm,
              height: SparkSize.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(kSecondaryColor),
              ),
            ),
            const SizedBox(width: SparkSpace.sm),
            Expanded(
              child: MyText(
                text: text,
                size: SparkTextSize.caption,
                color: kSecondaryColor,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.pill),
          child: LinearProgressIndicator(
            value: progress?.clamp(0.0, 1.0),
            minHeight: SparkSize.progressThin,
            backgroundColor: kSecondaryColor.withValues(alpha: 0.14),
            valueColor: const AlwaysStoppedAnimation<Color>(kSecondaryColor),
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          ...files.map(
            (file) => Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.xs),
              child: _buildSparkJoyUploadFileRow(file),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildSparkJoyUploadErrorHint(
  _SparkJoyCreateReportScreenState s, {
  required String text,
}) {
  return SparkCard(
    padding: const EdgeInsets.symmetric(
      horizontal: SparkSpace.xl,
      vertical: SparkSpace.lg,
    ),
    borderColor: kRedColor2.withValues(alpha: 0.35),
    backgroundColor: kRedColor2.withValues(alpha: 0.06),
    radius: SparkRadius.md,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
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
        const SizedBox(height: SparkSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => s._finishReport(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kRedColor2),
              foregroundColor: kRedColor,
              backgroundColor: kWhiteColor.withValues(alpha: 0.75),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: SparkSize.iconSm),
            label: const Text(
              'Повторить выгрузку',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSparkJoySectionEditor(_SparkJoyCreateReportScreenState s) {
  final actionState = s._stepActionController.build(s);
  final uploadInSummary =
      actionState.isSummaryStep && s._backendUploadInProgress;
  final uploadErrorInSummary =
      actionState.isSummaryStep &&
      !s._backendUploadInProgress &&
      s._backendUploadFailed;

  return Column(
    children: [
      if (!actionState.inMediaGroupEditor)
        _buildSparkJoyStepHero(s, actionState: actionState),
      if (!actionState.inMediaGroupEditor)
        const SizedBox(height: SparkSpace.lg),
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
      // Completed reports are shown read-only: validation hints belong
      // to the edit flow (block the user from continuing / submitting)
      // and are noise when the report is finalized. The hidden-by-
      // readOnly guard mirrors the step-action-bar suppression below.
      if (!s.widget.readOnly &&
          !actionState.inMediaGroupEditor &&
          actionState.isTestDriveStep &&
          !actionState.canTestDriveContinue) ...[
        const SizedBox(height: SparkSpace.md),
        _buildSparkJoyValidationHint(actionState.testDriveReasons.join(' · ')),
      ],
      if (!s.widget.readOnly &&
          !actionState.inMediaGroupEditor &&
          actionState.isSummaryStep &&
          !actionState.canSummaryFinish) ...[
        const SizedBox(height: SparkSpace.md),
        _buildSparkSummaryRequiredMissingActionsCard(
          s,
          actionState.summaryReasons,
        ),
      ],
      // In read-only mode the section editor renders a completed report
      // for inspection only — upload hints and the step action bar
      // (which control edit-flow navigation / submission) don't belong
      // here. The AppBar already exposes back + share actions.
      if (!actionState.inMediaGroupEditor && !s.widget.readOnly) ...[
        const SizedBox(height: SparkSpace.xl),
        if (uploadInSummary) ...[
          _buildSparkJoyUploadHint(
            s._backendUploadStatusLabel(),
            // Точный процент только на фазе заливки медиа (totalFiles > 0);
            // на безфайловых серверных фазах — индетерминированный бар.
            progress: s._backendUploadTotalFiles > 0
                ? s._backendUploadProgressValue()
                : null,
            files: s._backendUploadFilesProgress,
          ),
          const SizedBox(height: SparkSpace.sm),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => s._requestUploadCancel(),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Отменить выгрузку'),
              style: TextButton.styleFrom(foregroundColor: kRedColor),
            ),
          ),
          const SizedBox(height: SparkSpace.md),
        ] else if (uploadErrorInSummary) ...[
          _buildSparkJoyUploadErrorHint(
            s,
            text: s._backendUploadErrorText.trim().isNotEmpty
                ? 'Ошибка выгрузки: ${s._backendUploadErrorText.trim()}'
                : s._backendUploadStatusLabel(),
          ),
          const SizedBox(height: SparkSpace.md),
        ],
        SparkStepActionBar(
          secondaryLabel: 'К разделам',
          secondaryDisabled: uploadInSummary,
          onSecondaryTap: () => s._closeSection(save: true),
          primaryLabel: uploadInSummary
              ? 'Выгрузка...'
              : actionState.isLast
              ? 'Завершить и выгрузить'
              : 'Продолжить',
          primaryDisabled:
              uploadInSummary ||
              (!actionState.isSummaryStep &&
                  actionState.continueButtonDisabled),
          primaryBusy: uploadInSummary,
          onPrimaryTap: () =>
              s._stepActionController.handlePrimaryTap(s, actionState),
        ),
      ],
    ],
  );
}

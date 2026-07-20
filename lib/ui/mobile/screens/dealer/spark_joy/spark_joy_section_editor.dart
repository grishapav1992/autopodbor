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
    statusText: actionState.statusText,
    statusColor: statusColor,
  );
}

Widget _buildSparkJoyValidationHint(String text) {
  return SparkCard(
    padding: const EdgeInsets.symmetric(
      horizontal: SparkSpace.xl,
      vertical: SparkSpace.lg,
    ),
    borderColor: kRedColor.withValues(alpha: 0.35),
    backgroundColor: kRedColor.withValues(alpha: 0.06),
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

// Выгрузка подаётся как ОДИН процесс: статус + крупный процент + общий
// бар (взвешенный по байтам) + счётчик готовых файлов. Пофайловый список
// карточек убран сознательно: одновременно грузятся максимум
// _kFileConcurrency файлов, и стена из десятков строк с техническими
// S3-именами хоронила единственно важное — общий ход выгрузки.
Widget _buildSparkJoyUploadHint(
  String text, {
  // null → индетерминированный (анимированный) бар: используется на фазах без
  // пофайлового процента (флаш AI, серверная подготовка, превью, финализация),
  // чтобы бар не «застывал» на 0% и не выглядел как зависание.
  required double? progress,
  int completedFiles = 0,
  int totalFiles = 0,
}) {
  final percent = progress == null
      ? null
      : (progress.clamp(0.0, 1.0) * 100).round();
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
            if (percent != null) ...[
              const SizedBox(width: SparkSpace.sm),
              MyText(
                text: '$percent%',
                size: SparkTextSize.title,
                color: kSecondaryColor,
                weight: FontWeight.w700,
              ),
            ],
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
        if (totalFiles > 0) ...[
          const SizedBox(height: SparkSpace.xs),
          MyText(
            text:
                'Готово ${completedFiles.clamp(0, totalFiles)} из $totalFiles файлов',
            size: SparkTextSize.caption,
            color: kGreyColor,
            weight: FontWeight.w500,
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
  final errorCode = s._backendUploadErrorCode.trim();
  final supportText = s._backendUploadErrorSupportText.trim();
  return SparkCard(
    padding: const EdgeInsets.symmetric(
      horizontal: SparkSpace.xl,
      vertical: SparkSpace.lg,
    ),
    borderColor: kRedColor.withValues(alpha: 0.35),
    backgroundColor: kRedColor.withValues(alpha: 0.06),
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
            const SizedBox(width: SparkSpace.sm),
            IconButton(
              tooltip: 'Скопировать ошибку',
              onPressed: () {
                // Support-текст содержит код, номер отчёта, этап и техническую
                // ошибку; для старых состояний без него копируем видимый текст.
                Clipboard.setData(
                  ClipboardData(text: supportText.isEmpty ? text : supportText),
                );
                ScaffoldMessenger.of(s.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Детали ошибки скопированы — отправьте их в поддержку',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              color: kRedColor,
              iconSize: SparkSize.iconSm,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        if (errorCode.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.xs),
          Padding(
            padding: const EdgeInsets.only(
              left: SparkSize.iconSm + SparkSpace.sm,
            ),
            child: MyText(
              text: 'Код ошибки: $errorCode — назовите его поддержке',
              size: SparkTextSize.caption,
              color: kRedColor,
            ),
          ),
        ],
        const SizedBox(height: SparkSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => s._finishReport(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kRedColor),
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

/// Confirm + запрос кооперативной отмены чужой выгрузки через глобальный
/// гейт. Owner-check гейта делает запрос безопасным к гонке «выгрузка
/// успела завершиться, пока висел диалог» — requestCancel станет no-op.
Future<void> _confirmCancelForeignReportUpload(
  _SparkJoyCreateReportScreenState s,
  SparkJoyActiveReportUpload activeUpload,
) async {
  final confirmed = await showDialog<bool>(
    context: s.context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Отменить выгрузку?'),
      content: Text(
        'Выгрузка отчёта «${activeUpload.reportName}» будет остановлена, '
        'её можно будет запустить заново из черновика.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Продолжить выгрузку'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: kRedColor),
          child: const Text('Да, отменить'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  SparkJoyReportUploadGate.instance.requestCancel();
}

Widget _buildSparkJoySectionEditor(_SparkJoyCreateReportScreenState s) {
  final actionState = s._stepActionController.build(s);
  final uploadInSummary =
      actionState.isSummaryStep && s._backendUploadInProgress;
  // Глобальный гейт занят, а своя выгрузка не идёт — значит, выгружается
  // другой черновик (или этот же из другого, уже закрытого инстанса
  // редактора): «Завершить и выгрузить» дизейблим, причину показываем хинтом.
  final activeUpload = SparkJoyReportUploadGate.instance.active.value;
  final blockedByOtherUpload =
      actionState.isSummaryStep &&
      !s._backendUploadInProgress &&
      activeUpload != null;
  final blockedBySameDraft =
      blockedByOtherUpload && activeUpload.draftId == s._draftId;
  final uploadErrorInSummary =
      actionState.isSummaryStep &&
      !s._backendUploadInProgress &&
      // Retry-хинт с активной «Повторить выгрузку» прячем на время чужой
      // выгрузки — иначе он противоречит задизейбленной primary-кнопке.
      !blockedByOtherUpload &&
      s._backendUploadFailed;

  return Column(
    children: [
      if (!actionState.inMediaGroupEditor)
        _buildSparkJoyStepHero(s, actionState: actionState),
      if (!actionState.inMediaGroupEditor)
        const SizedBox(height: SparkSpace.lg),
      _buildSparkJoyStepContent(s),
      if (!s.widget.readOnly &&
          !actionState.inMediaGroupEditor &&
          actionState.isVehicleStep &&
          !actionState.canVehicleContinue) ...[
        const SizedBox(height: SparkSpace.md),
        _buildSparkJoyValidationHint(
          actionState.vehicleMissingReasons.join(' · '),
        ),
      ],
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
            completedFiles: s._backendUploadCurrentFile,
            totalFiles: s._backendUploadTotalFiles,
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
        ] else if (blockedByOtherUpload) ...[
          SparkHintCard(
            icon: Icons.cloud_upload_outlined,
            text: activeUpload.cancelRequested
                ? 'Отменяем выгрузку…'
                : blockedBySameDraft
                ? kSparkReportUploadSameDraftBusyText
                : 'Идёт выгрузка отчёта «${activeUpload.reportName}» — '
                      'дождитесь завершения',
          ),
          // Отмена ЧУЖОЙ выгрузки: её экран-владелец мёртв вместе со своим
          // крестиком отмены, и без этой кнопки долгая выгрузка на плохой
          // сети блокировала бы все черновики без какого-либо выхода,
          // кроме убийства приложения. Через confirm — в отличие от
          // владельца, здесь пользователь не видит прогресс и не должен
          // сбрасывать почти долитый отчёт случайным тапом.
          if (!activeUpload.cancelRequested) ...[
            const SizedBox(height: SparkSpace.sm),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () =>
                    _confirmCancelForeignReportUpload(s, activeUpload),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Отменить выгрузку'),
                style: TextButton.styleFrom(foregroundColor: kRedColor),
              ),
            ),
          ],
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
              blockedByOtherUpload ||
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

part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyLegalFilesCard(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
}) {
  return s._card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.attach_file_rounded,
              size: SparkTextSize.title,
              color: kGreyColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            MyText(
              text: 'Файлы: ${s._legalFiles.length}',
              size: SparkTextSize.caption,
              color: kTertiaryColor,
              weight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.sm),
        OutlinedButton.icon(
          onPressed: s._pickLegalFiles,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Добавить документ'),
        ),
        if (s._legalFiles.isEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          const SparkHintCard(
            text: 'Документы не добавлены. Прикрепите при необходимости.',
            icon: Icons.folder_open_outlined,
          ),
        ],
        if (s._legalFiles.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          ...List.generate(s._legalFiles.length, (index) {
            final file = s._legalFiles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.lg,
                  vertical: SparkSpace.md,
                ),
                decoration: BoxDecoration(
                  color: kInputBgColor,
                  borderRadius: BorderRadius.circular(SparkRadius.md),
                  border: Border.all(color: kBorderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: SparkTextSize.title,
                      color: kSecondaryColor,
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: MyText(
                        text: file.name,
                        size: SparkTextSize.caption,
                        maxLines: 1,
                        color: kTertiaryColor,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setStateFn(() {
                          final next = [...s._legalFiles]..removeAt(index);
                          s._legalFiles = next;
                        });
                        s._markDraftDirty();
                      },
                      borderRadius: BorderRadius.circular(SparkRadius.pill),
                      child: Container(
                        width: SparkSize.iconXxl,
                        height: SparkSize.iconXxl,
                        decoration: BoxDecoration(
                          color: kWhiteColor,
                          borderRadius: BorderRadius.circular(SparkRadius.pill),
                          border: Border.all(color: kBorderColor),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: SparkTextSize.label,
                          color: kGreyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    ),
  );
}

/// Feature flag for the «Сформировать отчёт» card on the Материалы
/// проверки step. Off by default — backend integration for legal-report
/// formation is paused; we keep all the supporting state (legalLoading
/// / Loaded / Skipped / TimedOut / Purchased) in the controller and
/// draft so existing reports load without losing their status, but the
/// card itself is hidden. Flip to true to bring the UI back unchanged.
const bool _kShowLegalReportCard = false;

Widget _buildSparkJoyStepLegal(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
}) {
  final statusColor = s._legalLoading
      ? kSecondaryColor
      : (s._legalLoaded
            ? kGreenColor
            : (s._legalTimedOut
                  ? kRedColor
                  : (s._legalSkipped ? kYellowColor : kGreyColor)));
  final statusSubtitle = s._legalLoading
      ? 'Формируем отчёт…'
      : (s._legalLoaded
            ? 'Отчёт сформирован'
            : (s._legalTimedOut
                  ? 'Автопроверка не завершилась'
                  : (s._legalSkipped
                        ? 'Раздел отложен'
                        : 'Отчёт ещё не сформирован')));

  return Column(
    children: [
      if (_kShowLegalReportCard) ...[
        s._card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: statusSubtitle,
                      size: SparkTextSize.caption,
                      color: kTertiaryColor,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    width: SparkSize.iconSm,
                    height: SparkSize.iconSm,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SparkSpace.md),
              if (s._legalLoading) ...[
                const SizedBox(height: SparkSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(SparkRadius.pill),
                  child: const LinearProgressIndicator(
                    minHeight: SparkSize.progressThin,
                  ),
                ),
              ],
              const SizedBox(height: SparkSpace.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: s._legalLoading ? null : s._startLegalLoading,
                  icon: Icon(
                    s._legalLoaded ? Icons.refresh_rounded : Icons.gavel_rounded,
                    size: SparkSize.iconSm,
                  ),
                  label: Text(
                    s._legalLoaded
                        ? 'Обновить отчет'
                        : (s._legalLoading
                              ? 'Формирование...'
                              : 'Сформировать отчет'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      s._sectionHeading('Файлы специалиста', icon: Icons.folder_open_outlined),
      const SizedBox(height: SparkSpace.lg),
      _buildSparkJoyLegalFilesCard(s, setStateFn: setStateFn),
      s._sectionHeading(
        'Комментарий специалиста',
        icon: Icons.comment_bank_outlined,
      ),
      const SizedBox(height: SparkSpace.lg),
      // Без обёрточной `_card` — _commentInputPanel сам по себе уже
      // декорирован, дополнительная карточка дублировала рамку.
      s._commentInputPanel(
        controller: s._legalNoteController,
        isDictating: s._legalIsDictating,
        onToggleDictation: () async {
          if (s._legalIsDictating) {
            await s._stopLegalDictation();
          } else {
            await s._startLegalDictation();
          }
        },
        onAiFormat: () {
          s._formatCommentWithAi(s._legalNoteController);
          s._markDraftDirty();
          setStateFn(() {});
        },
      ),
    ],
  );
}

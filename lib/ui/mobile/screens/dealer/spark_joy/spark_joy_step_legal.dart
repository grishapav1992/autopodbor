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
            const Expanded(
              child: MyText(
                text: 'Файлы специалиста',
                size: SparkTextSize.body,
                weight: FontWeight.w700,
              ),
            ),
            SparkChip(
              text: '${s._legalFiles.length}',
              background: kSecondaryColor.withValues(alpha: 0.1),
              color: kSecondaryColor,
              textSize: SparkTextSize.caption,
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.md),
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

Widget _buildSparkJoyStepLegal(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
}) {
  final hasManualData =
      s._legalFiles.isNotEmpty || s._legalNoteController.text.trim().isNotEmpty;
  final statusLabel = s._legalLoading
      ? 'В процессе'
      : (s._legalLoaded
            ? 'Готов'
            : (s._legalTimedOut
                  ? 'Ошибка'
                  : (s._legalSkipped ? 'Отложено' : 'Не готов')));
  final statusColor = s._legalLoading
      ? kSecondaryColor
      : (s._legalLoaded
            ? kGreenColor
            : (s._legalTimedOut
                  ? kRedColor
                  : (s._legalSkipped ? kYellowColor : kGreyColor)));
  final statusSubtitle = s._legalLoading
      ? 'Формируем отчёт, обычно это занимает несколько секунд.'
      : (s._legalLoaded
            ? 'Отчёт сформирован, можно продолжать заполнение.'
            : (s._legalTimedOut
                  ? 'Автопроверка не завершилась. Запустите ещё раз.'
                  : (s._legalSkipped
                        ? 'Раздел отложен, вы можете вернуться к нему позже.'
                        : 'Запустите формирование отчёта или добавьте документы вручную.')));
  final statusIcon = s._legalLoading
      ? Icons.hourglass_top_rounded
      : (s._legalLoaded
            ? Icons.check_circle_rounded
            : (s._legalTimedOut
                  ? Icons.error_outline_rounded
                  : (s._legalSkipped
                        ? Icons.pause_circle_outline_rounded
                        : Icons.description_outlined)));

  return Column(
    children: [
      s._sectionHeading(
        'Юридическая проверка',
        icon: Icons.gavel_rounded,
        subtitle: 'Запустите формирование юридического отчёта',
      ),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: SparkTextSize.title, color: statusColor),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: MyText(
                    text: statusSubtitle,
                    size: SparkTextSize.body,
                    color: kTertiaryColor,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SparkSpace.md),
            Wrap(
              spacing: SparkSpace.sm,
              runSpacing: SparkSpace.sm,
              children: [
                SparkChip(
                  text: 'Статус: $statusLabel',
                  background: statusColor.withValues(alpha: 0.12),
                  color: statusColor,
                  textSize: SparkTextSize.caption,
                ),
                SparkChip(
                  text: 'Файлы: ${s._legalFiles.length}',
                  background: kSecondaryColor.withValues(alpha: 0.1),
                  color: kSecondaryColor,
                  textSize: SparkTextSize.caption,
                ),
              ],
            ),
            if (s._legalLoading) ...[
              const SizedBox(height: SparkSpace.md),
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
      if (!s._legalLoading && !s._legalLoaded && !hasManualData) ...[
        const SizedBox(height: SparkSpace.lg),
        const SparkHintCard(
          text: 'Сформируйте отчёт или добавьте документы вручную.',
          icon: Icons.info_outline_rounded,
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
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: SparkSpace.md),
            s._commentAudioFilesBlock(
              files: s._legalCommentAudioFiles,
              playingIndex: s._legalCommentPlayingAudioIndex,
              isRecording: s._isCommentRecording('legal_comment'),
              recordingLabel: s._commentRecordingLabel('legal_comment'),
              onToggleRecording: s._toggleLegalCommentRecording,
              onTogglePlay: (index) => s._toggleCommentAudioPlayback(
                docsComment: false,
                index: index,
              ),
              onRemoveAt: (index) {
                setStateFn(() {
                  final next = [...s._legalCommentAudioFiles]..removeAt(index);
                  s._legalCommentAudioFiles = next;
                  if (s._legalCommentPlayingAudioIndex == index) {
                    s._legalCommentPlayingAudioIndex = -1;
                    unawaited(s._sectionCommentAudioPlayer.stop());
                  } else if (s._legalCommentPlayingAudioIndex > index) {
                    s._legalCommentPlayingAudioIndex -= 1;
                  }
                });
                s._markDraftDirty();
              },
            ),
          ],
        ),
      ),
    ],
  );
}

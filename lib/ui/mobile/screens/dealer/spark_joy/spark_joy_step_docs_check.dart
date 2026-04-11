part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepDocsCheck(
  _SparkJoyCreateReportScreenState s, {
  required bool hasMismatch,
  required void Function(VoidCallback fn) setStateFn,
}) {
  final checks = <bool?>[
    s._docsOwnerMatch,
    s._docsVinMatch,
    s._docsEngineMatch,
  ];
  final checkedCount = checks.where((value) => value != null).length;
  final mismatchCount = checks.where((value) => value == false).length;
  final totalChecks = checks.length;
  final isCompleted = checkedCount == totalChecks;
  final statusColor = mismatchCount > 0
      ? kYellowColor
      : (isCompleted ? kGreenColor : kGreyColor);
  final statusText = mismatchCount > 0
      ? 'Есть расхождения'
      : (isCompleted ? 'Проверка завершена' : 'Нужно заполнить поля');

  return Column(
    children: [
      s._sectionHeading(
        'Сверка документов',
        icon: Icons.policy_outlined,
        subtitle: 'Сравните данные документов и автомобиля',
      ),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: SparkSize.iconMd,
                  color: kSecondaryColor,
                ),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: MyText(
                    text: statusText,
                    size: SparkTextSize.body,
                    weight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SparkSpace.sm),
            Wrap(
              spacing: SparkSpace.sm,
              runSpacing: SparkSpace.sm,
              children: [
                SparkChip(
                  text: 'Заполнено: $checkedCount/$totalChecks',
                  background: kSecondaryColor.withValues(alpha: 0.1),
                  color: kSecondaryColor,
                  textSize: SparkTextSize.caption,
                ),
                SparkChip(
                  text: 'Расхождения: $mismatchCount',
                  background: mismatchCount > 0
                      ? kYellowColor.withValues(alpha: 0.16)
                      : kGreenColor.withValues(alpha: 0.12),
                  color: mismatchCount > 0 ? kTertiaryColor : kGreenColor,
                  textSize: SparkTextSize.caption,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
      if (!isCompleted) ...[
        const SparkHintCard(
          text: 'Выберите статус в каждом пункте сверки.',
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: SparkSpace.lg),
      ],
      s._yesNoSelector(
        title: 'Данные владельца',
        value: s._docsOwnerMatch,
        subtitle: s._docsOwnerMatch == null
            ? null
            : s._docsStateLabel(s._docsOwnerMatch),
        subtitleColor: s._docsStateColor(s._docsOwnerMatch),
        positiveLabel: 'Соответствует',
        negativeLabel: 'Не соответствует',
        onChanged: (v) => setStateFn(() => s._docsOwnerMatch = v),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._yesNoSelector(
        title: 'Идентификационные номера',
        value: s._docsVinMatch,
        subtitle: s._docsVinMatch == null
            ? null
            : s._docsStateLabel(s._docsVinMatch),
        subtitleColor: s._docsStateColor(s._docsVinMatch),
        positiveLabel: 'Соответствует',
        negativeLabel: 'Не соответствует',
        onChanged: (v) => setStateFn(() => s._docsVinMatch = v),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._yesNoSelector(
        title: 'Модель двигателя',
        value: s._docsEngineMatch,
        subtitle: s._docsEngineMatch == null
            ? null
            : s._docsStateLabel(s._docsEngineMatch),
        subtitleColor: s._docsStateColor(s._docsEngineMatch),
        positiveLabel: 'Соответствует',
        negativeLabel: 'Не соответствует',
        onChanged: (v) => setStateFn(() => s._docsEngineMatch = v),
      ),
      if (hasMismatch) ...[
        const SizedBox(height: SparkSpace.lg),
        s._sectionHeading(
          'Комментарий по расхождениям',
          icon: Icons.edit_note_rounded,
          subtitle: 'Уточните, что именно не совпадает',
        ),
        s._card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              s._commentInputPanel(
                controller: s._docsMismatchCommentController,
                hint: 'Опишите, что не совпадает',
                isDictating: s._docsIsDictating,
                onToggleDictation: () async {
                  if (s._docsIsDictating) {
                    await s._stopDocsDictation();
                  } else {
                    await s._startDocsDictation();
                  }
                },
                onAiFormat: () {
                  s._formatCommentWithAi(s._docsMismatchCommentController);
                  s._markDraftDirty();
                  setStateFn(() {});
                },
              ),
              const SizedBox(height: SparkSpace.md),
              s._commentAudioFilesBlock(
                files: s._docsCommentAudioFiles,
                playingIndex: s._docsCommentPlayingAudioIndex,
                isRecording: s._isCommentRecording('docs_comment'),
                recordingLabel: s._commentRecordingLabel('docs_comment'),
                onToggleRecording: s._toggleDocsCommentRecording,
                onTogglePlay: (index) => s._toggleCommentAudioPlayback(
                  docsComment: true,
                  index: index,
                ),
                onRemoveAt: (index) {
                  setStateFn(() {
                    final next = [...s._docsCommentAudioFiles]..removeAt(index);
                    s._docsCommentAudioFiles = next;
                    if (s._docsCommentPlayingAudioIndex == index) {
                      s._docsCommentPlayingAudioIndex = -1;
                      unawaited(s._sectionCommentAudioPlayer.stop());
                    } else if (s._docsCommentPlayingAudioIndex > index) {
                      s._docsCommentPlayingAudioIndex -= 1;
                    }
                  });
                  s._markDraftDirty();
                },
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

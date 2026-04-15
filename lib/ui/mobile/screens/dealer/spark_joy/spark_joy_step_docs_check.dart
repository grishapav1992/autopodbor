part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepDocsCheck(
  _SparkJoyCreateReportScreenState s, {
  required bool hasMismatch,
  required void Function(VoidCallback fn) setStateFn,
}) {
  return Column(
    children: [
      s._yesNoSelector(
        title: 'Данные владельца',
        value: s._docsOwnerMatch,
        positiveLabel: 'Соответствует',
        negativeLabel: 'Не соответствует',
        onChanged: (v) => setStateFn(() => s._docsOwnerMatch = v),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._yesNoSelector(
        title: 'Идентификационные номера',
        value: s._docsVinMatch,
        positiveLabel: 'Соответствует',
        negativeLabel: 'Не соответствует',
        onChanged: (v) => setStateFn(() => s._docsVinMatch = v),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._yesNoSelector(
        title: 'Модель двигателя',
        value: s._docsEngineMatch,
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

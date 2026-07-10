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
        required: true,
        onChanged: (v) => setStateFn(() => s._docsOwnerMatch = v),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._yesNoSelector(
        title: 'Идентификационные номера',
        value: s._docsVinMatch,
        positiveLabel: 'Соответствует',
        negativeLabel: 'Не соответствует',
        required: true,
        onChanged: (v) => setStateFn(() => s._docsVinMatch = v),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._yesNoSelector(
        title: 'Модель двигателя',
        value: s._docsEngineMatch,
        positiveLabel: 'Соответствует',
        negativeLabel: 'Не соответствует',
        required: true,
        onChanged: (v) => setStateFn(() => s._docsEngineMatch = v),
      ),
      if (hasMismatch) ...[
        const SizedBox(height: SparkSpace.lg),
        s._sectionHeading(
          'Комментарий по расхождениям',
          icon: Icons.edit_note_rounded,
          subtitle: 'Уточните, что именно не совпадает',
        ),
        // Без обёрточной `_card` — у `_commentInputPanel` свой
        // внутренний фон/decoration; внешняя рамка читалась как
        // двойная граница и зрительно ломала ритм формы.
        s._commentInputPanel(
          controller: s._docsMismatchCommentController,
          hint: 'Опишите, что не совпадает',
          isDictating: s._docsIsDictating,
          aiBusy: s._docsCommentAiBusy,
          onToggleDictation: () async {
            if (s._docsIsDictating) {
              await s._stopDocsDictation();
            } else {
              await s._startDocsDictation();
            }
          },
          // Real AI through AiQueue: cliche bakes in the three
          // yes/no answers above so the model sees which fields are
          // mismatching even when the typed comment is short.
          onAiFormat: () => unawaited(s._generateDocsCommentWithAi()),
        ),
      ],
    ],
  );
}

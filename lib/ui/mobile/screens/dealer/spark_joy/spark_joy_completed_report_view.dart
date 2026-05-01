part of 'spark_joy_create_report_screen.dart';

// Read-only "итоговый отчёт" view shown when SparkJoyCreateReportScreen is
// opened with readOnly: true (from the "Завершённые" tab). Replaces the
// edit-flow shell: no step hero, no overview progress bar, no action bar —
// only what the dealer needs to verify before sharing the report link with
// the buyer.

Widget _buildSparkJoyCompletedReportView(_SparkJoyCreateReportScreenState s) {
  final summary = s._calculateSummary();
  final sections = summary.sections.toList(growable: false);

  final hasCleanMedia = s._mediaState.values.any(
    (state) => state.files.any((file) => !s._mediaItemHasIssue(file)),
  );
  final note = s._summaryController.text.trim();
  final showNoteCard = note.isNotEmpty;

  // Layout (per dealer feedback):
  //   1. «Сводка по данным осмотра» (вверху — сразу видно главное)
  //   2. Раздел-карточки (раскрывающиеся)
  //   3. «Обзор авто» (фото без замечаний), если есть
  //   4. «Итог специалиста»
  //
  // Verdict banner + checklist «Что важно знать» намеренно НЕ
  // отрисовываются: они вычисляются локально и НЕ уходят на сервер,
  // так что во внешнем web-вьюере покупатель их всё равно не видел —
  // показывать дилеру было бы вводить в заблуждение.
  final blocks = <Widget>[
    if (showNoteCard) s._summaryNoteCard(),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections.asMap().entries.map((entry) {
        final last = entry.key == sections.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : SparkSpace.lg),
          child: _CompletedReportSectionCard(
            state: s,
            section: entry.value,
          ),
        );
      }).toList(growable: false),
    ),
    if (hasCleanMedia) s._summaryNoDamageMediaCard(),
    s._summaryExpertConclusionCard(),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < blocks.length; i++) ...[
        if (i > 0) const SizedBox(height: SparkSpace.lg),
        blocks[i],
      ],
    ],
  );
}

class _CompletedReportSectionCard extends StatefulWidget {
  const _CompletedReportSectionCard({
    required this.state,
    required this.section,
  });

  final _SparkJoyCreateReportScreenState state;
  final Map<String, dynamic> section;

  @override
  State<_CompletedReportSectionCard> createState() =>
      _CompletedReportSectionCardState();
}

class _CompletedReportSectionCardState
    extends State<_CompletedReportSectionCard> {
  bool _expanded = false;

  String _statusLabel(String status) {
    switch (status) {
      case 'ok':
        return 'В порядке';
      case 'bad':
      case 'danger':
      case 'error':
        return 'Критично';
      case 'warn':
        return 'Требует внимания';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (_expanded) {
      // Кнопка-«×» в правом верхнем углу карточки: всегда видна,
      // не требует скролла к низу для длинных секций (медиа-блоков).
      // Stack поверх _summarySectionCard, чтоб не лезть в общий
      // card-builder, который шарится с edit-режимом.
      return Stack(
        children: [
          s._summarySectionCard(widget.section),
          Positioned(
            top: SparkSpace.md,
            right: SparkSpace.md,
            child: Material(
              color: kWhiteColor,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _expanded = false),
                child: const Padding(
                  padding: EdgeInsets.all(SparkSpace.xs),
                  child: Icon(
                    Icons.close_rounded,
                    size: SparkSize.iconSm,
                    color: kSecondaryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final section = widget.section;
    final title = (section['title'] ?? '').toString().trim();
    final stepId = _SparkJoySummaryRegistry.titleToStepId[title];
    final status = (section['status'] ?? '').toString().trim();
    final statusColor = s._summarySectionStatusColor(status);
    final statusLabel = _statusLabel(status);

    return InkWell(
      onTap: () => setState(() => _expanded = true),
      borderRadius: BorderRadius.circular(SparkRadius.lg),
      child: s._card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: SparkSize.stepBadge,
              height: SparkSize.stepBadge,
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(SparkRadius.sm),
              ),
              alignment: Alignment.center,
              child: Icon(
                s._overviewController.sectionIcon(stepId),
                size: SparkSize.iconSm,
                color: kSecondaryColor,
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: title.isEmpty ? 'Раздел' : title,
                    size: SparkTextSize.sectionTitle,
                    weight: FontWeight.w700,
                  ),
                  if (statusLabel.isNotEmpty) ...[
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: statusLabel,
                      size: SparkTextSize.caption,
                      color: statusColor,
                      weight: FontWeight.w600,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            const Icon(
              Icons.chevron_right_rounded,
              size: SparkSize.iconLg,
              color: kGreyColor,
            ),
          ],
        ),
      ),
    );
  }
}

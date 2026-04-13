part of 'spark_joy_create_report_screen.dart';

Color _sparkSummarySectionStatusColor(String status) {
  switch (status) {
    case 'ok':
      return kGreenColor;
    case 'bad':
    case 'danger':
    case 'error':
      return kRedColor;
    default:
      return kYellowColor;
  }
}

Color _sparkSummaryDetailSeverityColor(String severity) {
  switch (severity) {
    case 'ok':
      return kGreenColor;
    case 'serious':
    case 'critical':
      return kRedColor;
    case 'minor':
      return kYellowColor;
    default:
      return kGreyColor;
  }
}

Widget _buildSparkSummaryHeaderCard(_SparkJoyCreateReportScreenState s) {
  final reportName = s._reportTitle().trim();
  final reportMeta = sjFormatReportMeta(s._currentReportCode(), s._createdAt);

  return s._card(
    padding: const EdgeInsets.fromLTRB(
      SparkSpace.xxl,
      SparkSpace.xxl,
      SparkSpace.xxl,
      SparkSpace.xl,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => unawaited(s._editReportTitle()),
          borderRadius: BorderRadius.circular(SparkRadius.lg),
          child: SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xl,
              vertical: SparkSpace.xl,
            ),
            backgroundColor: kInputBgColor,
            child: Row(
              children: [
                Expanded(
                  child: MyText(
                    text: reportName.isEmpty ? 'Без названия' : reportName,
                    size: SparkTextSize.titleLg,
                    weight: FontWeight.w700,
                    maxLines: 2,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                const Icon(
                  Icons.edit_outlined,
                  size: SparkSize.iconMd,
                  color: kGreyColor,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SparkSpace.lg),
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: SparkSize.iconXs,
              color: kGreyColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            Expanded(
              child: MyText(
                text: reportMeta,
                size: SparkTextSize.bodyLg,
                color: kGreyColor,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSparkSummarySectionMediaPreview(
  _SparkJoyCreateReportScreenState s,
  String title,
) {
  final groupKey = _SparkJoySummaryRegistry.titleToGroupKey[title];
  if (groupKey == null) return const SizedBox.shrink();

  final state = s._mediaState[groupKey];
  final files = state?.files ?? const <_UploadedItem>[];
  if (files.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: SparkSpace.md),
    child: Wrap(
      spacing: SparkSpace.sm,
      runSpacing: SparkSpace.sm,
      children: files.asMap().entries.map((entry) {
        final index = entry.key;
        final file = entry.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.sm),
          child: InkWell(
            onTap: () => s._openMediaGroupLightbox(
              groupKey: groupKey,
              initialIndex: index,
            ),
            child: Container(
              width: SparkSize.mediaThumb,
              height: SparkSize.mediaThumb,
              color: kLightGreyColor,
              child: s._uploadedMediaThumbWidget(
                file,
                fit: BoxFit.cover,
                cacheWidth: 220,
                cacheHeight: 220,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

Widget _buildSparkSummaryNoDamageMediaCard(_SparkJoyCreateReportScreenState s) {
  final cleanItems = <Map<String, dynamic>>[];
  for (final entry in s._mediaState.entries) {
    final groupKey = entry.key;
    final state = entry.value;
    for (var index = 0; index < state.files.length; index++) {
      final file = state.files[index];
      if (s._mediaItemHasIssue(file)) continue;
      cleanItems.add({'groupKey': groupKey, 'index': index, 'file': file});
    }
  }
  if (cleanItems.isEmpty) return const SizedBox.shrink();

  return s._card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: SparkSize.iconSm,
              color: kSecondaryColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            const Expanded(
              child: MyText(
                text: 'Обзор авто',
                size: SparkTextSize.sectionTitle,
                weight: FontWeight.w700,
              ),
            ),
            SparkChip(
              text: '${cleanItems.length} фото',
              background: kGreenColor.withValues(alpha: 0.12),
              color: kGreenColor,
              textSize: SparkTextSize.caption,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.sm,
                vertical: SparkSpace.xxxs,
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.sm),
        const MyText(
          text: 'Элементы без выявленных повреждений и нераспределённые фото',
          size: SparkTextSize.bodyLg,
          color: kGreyColor,
        ),
        const SizedBox(height: SparkSpace.md),
        Wrap(
          spacing: SparkSpace.sm,
          runSpacing: SparkSpace.sm,
          children: cleanItems.map((entry) {
            final file = entry['file'] as _UploadedItem;
            final groupKey = (entry['groupKey'] ?? '').toString();
            final index = entry['index'] as int? ?? 0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.sm),
              child: InkWell(
                onTap: () => s._openMediaGroupLightbox(
                  groupKey: groupKey,
                  initialIndex: index,
                ),
                child: Container(
                  width: SparkSize.mediaThumb,
                  height: SparkSize.mediaThumb,
                  color: kLightGreyColor,
                  child: s._uploadedMediaThumbWidget(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 220,
                    cacheHeight: 220,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

Widget _buildSparkSummarySectionCard(
  _SparkJoyCreateReportScreenState s,
  Map<String, dynamic> section, {
  bool clientPreview = false,
  bool needsAttention = false,
}) {
  final title = (section['title'] ?? '').toString().trim();
  final stepId = _SparkJoySummaryRegistry.titleToStepId[title];
  final status = (section['status'] ?? '').toString().trim();
  final statusColor = s._summarySectionStatusColor(status);
  final editable = stepId != null;

  final detailLines = <String>[];
  final detailMaps = <Map<String, dynamic>>[];
  final detailsRaw = section['details'];
  if (detailsRaw is List) {
    for (final detail in detailsRaw) {
      if (detail is String) {
        if (detail.trim().isNotEmpty) detailLines.add(detail.trim());
        continue;
      }
      if (detail is Map) {
        detailMaps.add(
          detail.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    }
  }

  return s._card(
    borderColor: needsAttention ? kYellowColor.withValues(alpha: 0.6) : null,
    backgroundColor: needsAttention
        ? kYellowColor.withValues(alpha: 0.06)
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              child: MyText(
                text: title.isEmpty ? 'Раздел' : title,
                size: SparkTextSize.sectionTitle,
                weight: FontWeight.w700,
              ),
            ),
            if (editable && !clientPreview)
              TextButton(
                onPressed: () => s._openSummarySectionEditor(title),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.sm,
                    vertical: SparkSpace.xxs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: SparkSize.iconXs,
                      color: kSecondaryColor,
                    ),
                    SizedBox(width: SparkSpace.xs),
                    Text(
                      'Открыть',
                      style: TextStyle(
                        fontSize: SparkTextSize.caption,
                        fontWeight: FontWeight.w700,
                        color: kSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            if (!clientPreview) ...[
              if (editable) const SizedBox(width: SparkSpace.xs),
              if (needsAttention)
                Padding(
                  padding: const EdgeInsets.only(right: SparkSpace.xs),
                  child: SparkChip(
                    text: 'дополнить',
                    background: kYellowColor.withValues(alpha: 0.18),
                    color: kTertiaryColor,
                    textSize: SparkTextSize.caption,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.sm,
                      vertical: SparkSpace.xxxs,
                    ),
                  ),
                ),
            ],
          ],
        ),
        if (status.isNotEmpty && !clientPreview) ...[
          const SizedBox(height: SparkSpace.sm),
          SparkChip(
            text: status == 'ok'
                ? 'В порядке'
                : (status == 'bad' || status == 'danger' || status == 'error'
                      ? 'Критично'
                      : 'Требует внимания'),
            background: statusColor.withValues(alpha: 0.1),
            color: statusColor,
            textSize: SparkTextSize.caption,
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.xs,
            ),
          ),
        ],
        if (detailLines.isNotEmpty || detailMaps.isNotEmpty)
          const SizedBox(height: SparkSpace.md),
        ...detailLines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: SparkSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: SparkSpace.xxs),
                  child: Icon(
                    Icons.circle,
                    size: SparkSpace.sm,
                    color: kGreyColor,
                  ),
                ),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: MyText(
                    text: line,
                    size: SparkTextSize.bodyLg,
                    color: kGreyColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        ...detailMaps.map((detail) {
          final label = (detail['label'] ?? '').toString().trim();
          final value = (detail['value'] ?? '').toString().trim();
          final severity = (detail['severity'] ?? '').toString().trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: SparkSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: SparkSpace.xxs),
                  child: Icon(
                    Icons.circle,
                    size: SparkSpace.sm,
                    color: kGreyColor,
                  ),
                ),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: SparkTextSize.bodyLg),
                      children: [
                        TextSpan(
                          text: '${label.isEmpty ? 'Пункт' : label}: ',
                          style: const TextStyle(color: kGreyColor),
                        ),
                        TextSpan(
                          text: value.isEmpty ? '-' : value,
                          style: TextStyle(
                            color: s._summaryDetailSeverityColor(severity),
                            decoration: value.startsWith('http')
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        s._summarySectionMediaPreview(title),
      ],
    ),
  );
}

Widget _buildSparkSummarySectionsList(
  _SparkJoyCreateReportScreenState s,
  _CalculatedSummary summary, {
  required Set<String> attentionStepIds,
  required Set<String> attentionGroupKeys,
}) {
  final items = summary.sections.toList(growable: false);
  var attentionCount = 0;
  for (final section in items) {
    final title = (section['title'] ?? '').toString().trim();
    final stepId = _SparkJoySummaryRegistry.titleToStepId[title];
    final groupKey = _SparkJoySummaryRegistry.titleToGroupKey[title];
    final needsAttention =
        (stepId != null && attentionStepIds.contains(stepId)) ||
        (groupKey != null && attentionGroupKeys.contains(groupKey));
    if (needsAttention) {
      attentionCount += 1;
    }
  }

  return s._card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: SparkSize.navStepBadge,
              height: SparkSize.navStepBadge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SparkRadius.sm),
                color: kSecondaryColor.withValues(alpha: 0.08),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.dashboard_customize_outlined,
                size: SparkSize.iconSm,
                color: kSecondaryColor,
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: 'Разделы отчёта',
                    size: SparkTextSize.sectionTitle,
                    weight: FontWeight.w700,
                  ),
                  MyText(
                    text: 'Проверьте заполнение перед выгрузкой',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                ],
              ),
            ),
            SparkChip(
              text: '${items.length}',
              background: kSecondaryColor.withValues(alpha: 0.1),
              color: kSecondaryColor,
              textSize: SparkTextSize.caption,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.xxxs,
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
              text: 'Заполнено: ${items.length - attentionCount}',
              background: kGreenColor.withValues(alpha: 0.12),
              color: kGreenColor,
              textSize: SparkTextSize.caption,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.xxxs,
              ),
            ),
            SparkChip(
              text: 'Дополнить: $attentionCount',
              background: attentionCount > 0
                  ? kYellowColor.withValues(alpha: 0.18)
                  : kLightGreyColor,
              color: attentionCount > 0 ? kTertiaryColor : kGreyColor,
              textSize: SparkTextSize.caption,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.xxxs,
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.xl),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final title = (section['title'] ?? '').toString().trim();
          final stepId = _SparkJoySummaryRegistry.titleToStepId[title];
          final groupKey = _SparkJoySummaryRegistry.titleToGroupKey[title];
          final needsAttention =
              (stepId != null && attentionStepIds.contains(stepId)) ||
              (groupKey != null && attentionGroupKeys.contains(groupKey));
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : SparkSpace.xl,
            ),
            child: s._summarySectionCard(
              section,
              clientPreview: false,
              needsAttention: needsAttention,
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildSparkSummaryNoteCard(_SparkJoyCreateReportScreenState s) {
  final note = s._summaryController.text.trim();
  return s._card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        s._sectionHeading(
          'Сводка по данным осмотра',
          icon: Icons.summarize_outlined,
          subtitle: 'Формируется на основе заполненных разделов',
        ),
        SparkCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.lg,
            vertical: SparkSpace.lg,
          ),
          radius: SparkRadius.md,
          backgroundColor: kInputBgColor,
          child: MyText(
            text: note.isEmpty
                ? 'Заполните разделы осмотра для формирования сводки.'
                : note,
            size: SparkTextSize.bodyLg,
            color: note.isEmpty ? kGreyColor : kTertiaryColor,
            lineHeight: 1.35,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSparkSummaryExpertConclusionCard(
  _SparkJoyCreateReportScreenState s, {
  bool needsAttention = false,
}) {
  return s._card(
    borderColor: needsAttention ? kYellowColor.withValues(alpha: 0.6) : null,
    backgroundColor: needsAttention
        ? kYellowColor.withValues(alpha: 0.06)
        : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        s._sectionHeading(
          'Итог специалиста',
          icon: Icons.rate_review_outlined,
          subtitle: 'Финальный комментарий перед выгрузкой отчёта',
        ),
        s._commentInputPanel(
          controller: s._expertController,
          hint:
              'Ваш вывод, рекомендации, условия сделки, комментарий для клиента...',
          isDictating: s._expertIsDictating,
          onToggleDictation: () async {
            if (s._expertIsDictating) {
              await s._stopExpertDictation();
            } else {
              await s._startExpertDictation();
            }
          },
          onAiFormat: () {
            s._formatCommentWithAi(s._expertController);
            s._markDraftDirty();
            s._setStateSafely(() {});
          },
        ),
        const SizedBox(height: SparkSpace.md),
        s._commentAudioFilesBlock(
          files: s._expertAudioFiles,
          playingIndex: s._expertCommentPlayingAudioIndex,
          isRecording: s._isCommentRecording('expert_comment'),
          recordingLabel: s._commentRecordingLabel('expert_comment'),
          onToggleRecording: s._toggleExpertCommentRecording,
          onTogglePlay: s._toggleExpertCommentAudioPlayback,
          onRemoveAt: (index) {
            s._setStateSafely(() {
              final next = [...s._expertAudioFiles]..removeAt(index);
              s._expertAudioFiles = next;
              if (s._expertCommentPlayingAudioIndex == index) {
                s._expertCommentPlayingAudioIndex = -1;
                unawaited(s._sectionCommentAudioPlayer.stop());
              } else if (s._expertCommentPlayingAudioIndex > index) {
                s._expertCommentPlayingAudioIndex -= 1;
              }
            });
            s._markDraftDirty();
          },
        ),
      ],
    ),
  );
}

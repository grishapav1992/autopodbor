part of 'spark_joy_create_report_screen.dart';

Color _sparkSummarySectionStatusColor(String status) {
  switch (status) {
    case 'ok':
      return kGreenColor;
    case 'bad':
    case 'danger':
    case 'error':
      return kRedColor;
    case 'warn':
      return kChipInProgressFg;
    case 'empty':
    case 'info':
    case 'minor':
      return kGreyColor;
    default:
      return kChipInProgressFg;
  }
}

Color _sparkSummarySectionStatusTextColor(String status) {
  switch (status) {
    case 'ok':
      return kGreenColor;
    case 'bad':
    case 'danger':
    case 'error':
      return kRedColor;
    case 'warn':
      return kChipInProgressFg;
    case 'empty':
    case 'info':
    case 'minor':
      return kGreyColor;
    default:
      return kTertiaryColor;
  }
}

String _sparkSummarySectionStatusLabel(String status) {
  switch (status) {
    case 'ok':
      return 'Заполнено';
    case 'bad':
    case 'danger':
    case 'error':
      return 'Критично';
    case 'empty':
    case 'info':
      return 'Не заполнено';
    default:
      return 'Требует внимания';
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
      return kTertiaryColor;
    default:
      return kGreyColor;
  }
}

String _sparkSummaryUpperFirst(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

String _sparkSummaryPointWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return 'пункт';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'пункта';
  }
  return 'пунктов';
}

class _SparkSummaryActionItem {
  const _SparkSummaryActionItem({
    required this.title,
    required this.subtitle,
    this.stepId,
    this.mediaGroupKey,
    this.scrollToSummaryBottom = false,
  });

  final String title;
  final String subtitle;
  final String? stepId;
  final String? mediaGroupKey;
  final bool scrollToSummaryBottom;
}

List<_SparkSummaryActionItem> _sparkSummaryActionItemsFromReasons(
  _SparkJoyCreateReportScreenState s,
  List<String> reasons,
) {
  final grouped = <String, _SparkSummaryActionItem>{};
  final subtitlesByKey = <String, List<String>>{};

  for (final reason in reasons) {
    final value = reason.trim();
    if (value.isEmpty) continue;

    final separator = value.indexOf('—');
    final section = separator > 0 ? value.substring(0, separator).trim() : '';
    var action = separator > 0 ? value.substring(separator + 1).trim() : value;
    var title = section.isEmpty ? 'Раздел отчёта' : section;
    var stepId = s._summaryReasonStepId(value);
    final mediaGroupKey = s._summaryReasonMediaGroupKey(value);
    var scrollToSummaryBottom = false;

    if (mediaGroupKey != null) {
      title =
          _SparkJoySummaryRegistry.mediaGroupLabelByKey[mediaGroupKey] ?? title;
      action = 'Добавьте фото';
    }

    if (stepId == null &&
        (section == 'Отчёт' || section == 'Итог' || section == 'Вложения')) {
      stepId = _SparkJoyStepRegistry.idSummary;
      scrollToSummaryBottom = section != 'Отчёт';
    }
    if (stepId == null && section == 'Юр. проверка') {
      stepId = _SparkJoyStepRegistry.idLegal;
    }

    final key = '${stepId ?? section}|${mediaGroupKey ?? ''}|$title';
    subtitlesByKey.putIfAbsent(key, () => <String>[]);
    subtitlesByKey[key]!.add(_sparkSummaryUpperFirst(action));
    grouped.putIfAbsent(
      key,
      () => _SparkSummaryActionItem(
        title: title,
        subtitle: '',
        stepId: stepId,
        mediaGroupKey: mediaGroupKey,
        scrollToSummaryBottom: scrollToSummaryBottom,
      ),
    );
  }

  return grouped.entries
      .map((entry) {
        final item = entry.value;
        final subtitles = subtitlesByKey[entry.key] ?? const <String>[];
        return _SparkSummaryActionItem(
          title: item.title,
          subtitle: subtitles.join(' · '),
          stepId: item.stepId,
          mediaGroupKey: item.mediaGroupKey,
          scrollToSummaryBottom: item.scrollToSummaryBottom,
        );
      })
      .toList(growable: false);
}

List<_SparkSummaryActionItem> _sparkSummaryRequiredActionItemsFromReasons(
  _SparkJoyCreateReportScreenState s,
  List<String> reasons,
) {
  const requiredPrefixes = {
    'Отчёт',
    'Автомобиль',
    'Итог',
    'Сверка документов',
    'Тест-драйв',
    'Осмотр',
  };

  final filteredReasons = reasons
      .where((reason) {
        final value = reason.trim();
        if (value.isEmpty) return false;
        if (value.contains('недопустимые слова')) return false;
        if (value.startsWith('Вложения —')) return false;
        final separator = value.indexOf('—');
        final prefix = separator > 0
            ? value.substring(0, separator).trim()
            : '';
        return requiredPrefixes.contains(prefix);
      })
      .toList(growable: false);

  return _sparkSummaryActionItemsFromReasons(s, filteredReasons);
}

void _openSparkSummaryActionItem(
  _SparkJoyCreateReportScreenState s,
  _SparkSummaryActionItem item,
) {
  final stepId = item.stepId;
  if (stepId == null || stepId.trim().isEmpty) return;

  if (stepId == _SparkJoyStepRegistry.idSummary) {
    if (!s._pageScrollController.hasClients) return;
    final position = s._pageScrollController.position;
    final target = item.scrollToSummaryBottom ? position.maxScrollExtent : 0.0;
    unawaited(
      s._pageScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
    );
    return;
  }

  s._navigateToStepFromSummary(stepId, mediaGroupKey: item.mediaGroupKey);
}

Widget _buildSparkSummaryMissingActionsCard(
  _SparkJoyCreateReportScreenState s,
  List<_SparkSummaryActionItem> items,
) {
  if (items.isEmpty) return const SizedBox.shrink();

  return SparkCard(
    borderColor: kChipInProgressFg.withValues(alpha: 0.24),
    backgroundColor: kWhiteColor,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: SparkSize.stepBadge,
              height: SparkSize.stepBadge,
              decoration: BoxDecoration(
                color: kChipInProgressBg,
                borderRadius: BorderRadius.circular(SparkRadius.sm),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.playlist_add_check_rounded,
                size: SparkSize.iconSm,
                color: kTertiaryColor,
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            const Expanded(
              child: MyText(
                text: 'Что заполнить',
                size: SparkTextSize.sectionTitle,
                weight: FontWeight.w800,
              ),
            ),
            SparkChip(
              text: '${items.length}',
              background: kChipInProgressBg,
              color: kTertiaryColor,
              textSize: SparkTextSize.caption,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.xxxs,
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.md),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final canOpen = item.stepId != null && item.stepId!.trim().isNotEmpty;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : SparkSpace.sm,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canOpen
                    ? () => _openSparkSummaryActionItem(s, item)
                    : null,
                borderRadius: BorderRadius.circular(SparkRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                    vertical: SparkSpace.md,
                  ),
                  decoration: BoxDecoration(
                    color: kWhiteColor.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(SparkRadius.md),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: SparkSize.iconXs,
                        color: kTertiaryColor,
                      ),
                      const SizedBox(width: SparkSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              text: item.title,
                              size: SparkTextSize.bodyLg,
                              weight: FontWeight.w700,
                              lineHeight: 1.2,
                            ),
                            if (item.subtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: SparkSpace.xxxs),
                              MyText(
                                text: item.subtitle,
                                size: SparkTextSize.caption,
                                color: kGreyColor,
                                lineHeight: 1.25,
                                maxLines: 2,
                                textOverflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canOpen) ...[
                        const SizedBox(width: SparkSpace.sm),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: SparkSize.iconSm,
                          color: kGreyColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildSparkSummaryRequiredMissingActionsCard(
  _SparkJoyCreateReportScreenState s,
  List<String> reasons,
) {
  final items = _sparkSummaryRequiredActionItemsFromReasons(s, reasons);
  return _buildSparkSummaryMissingActionsCard(s, items);
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
        SparkCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xl,
            vertical: SparkSpace.xl,
          ),
          backgroundColor: kInputBgColor,
          child: MyText(
            text: reportName.isEmpty ? 'Без названия' : reportName,
            size: SparkTextSize.titleLg,
            weight: FontWeight.w800,
            lineHeight: 1.30,
            tracking: true,
            maxLines: 2,
            textOverflow: TextOverflow.ellipsis,
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
  final files = state?.files ?? const <UploadedItem>[];
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
          children: () {
            // Flat-lightbox: swiping should flip across every clean
            // file regardless of its source section. Build parallel
            // files / groupKeys lists so the lightbox keeps per-item
            // labels (element name, no-damage copy, tag colors) right.
            final flatFiles = <UploadedItem>[
              for (final entry in cleanItems) entry['file'] as UploadedItem,
            ];
            final flatGroupKeys = <String>[
              for (final entry in cleanItems)
                (entry['groupKey'] ?? '').toString(),
            ];
            return List<Widget>.generate(cleanItems.length, (flatIndex) {
              final file = flatFiles[flatIndex];
              return ClipRRect(
                borderRadius: BorderRadius.circular(SparkRadius.sm),
                child: InkWell(
                  onTap: () => s._openFlatMediaLightbox(
                    files: flatFiles,
                    groupKeyPerFile: flatGroupKeys,
                    initialIndex: flatIndex,
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
            });
          }(),
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
  bool compactDetails = false,
}) {
  final title = (section['title'] ?? '').toString().trim();
  final stepId = _SparkJoySummaryRegistry.titleToStepId[title];
  final status = (section['status'] ?? '').toString().trim();
  final statusColor = s._summarySectionStatusColor(status);
  final statusTextColor = _sparkSummarySectionStatusTextColor(status);
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

  // Чип раздела уже показывает статус («Не заполнено»/«Заполнено»), поэтому
  // детальная строка «Статус» рядом с ним — дубль (фидбек 2026-07-10:
  // «Материалы проверки» показывали «Не заполнено» дважды). Прячем её везде,
  // где чип виден; в clientPreview чип скрыт — там строка «Статус» остаётся
  // единственным индикатором и нужна.
  if (status.isNotEmpty && !clientPreview) {
    detailMaps.removeWhere(
      (detail) => (detail['label'] ?? '').toString().trim() == 'Статус',
    );
  }

  final detailLimit = compactDetails ? (needsAttention ? 3 : 2) : null;
  final visibleDetailLines = detailLimit == null
      ? detailLines
      : detailLines.take(detailLimit).toList(growable: false);
  final visibleMapLimit = detailLimit == null
      ? detailMaps.length
      : (detailLimit - visibleDetailLines.length).clamp(0, detailMaps.length);
  final visibleDetailMaps = detailLimit == null
      ? detailMaps
      : detailMaps.take(visibleMapLimit).toList(growable: false);
  final hiddenDetailCount =
      detailLines.length +
      detailMaps.length -
      visibleDetailLines.length -
      visibleDetailMaps.length;
  final canOpenCompactSection =
      editable && !clientPreview && !s.widget.readOnly && compactDetails;

  return SparkCard(
    onTap: canOpenCompactSection
        ? () => s._openSummarySectionEditor(title)
        : null,
    borderColor: needsAttention
        ? kChipInProgressFg.withValues(alpha: 0.28)
        : kBorderColor,
    backgroundColor: kWhiteColor,
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
            if (editable && !clientPreview && !s.widget.readOnly)
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
            if (!clientPreview && editable)
              const SizedBox(width: SparkSpace.xs),
          ],
        ),
        if (status.isNotEmpty && !clientPreview) ...[
          const SizedBox(height: SparkSpace.sm),
          SparkChip(
            text: _sparkSummarySectionStatusLabel(status),
            background: statusColor.withValues(alpha: 0.1),
            color: statusTextColor,
            textSize: SparkTextSize.caption,
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.xs,
            ),
          ),
        ],
        if (visibleDetailLines.isNotEmpty || visibleDetailMaps.isNotEmpty)
          const SizedBox(height: SparkSpace.md),
        ...visibleDetailLines.map(
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
        ...visibleDetailMaps.map((detail) {
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
        if (hiddenDetailCount > 0) ...[
          const SizedBox(height: SparkSpace.xs),
          MyText(
            text:
                'Ещё $hiddenDetailCount ${_sparkSummaryPointWord(hiddenDetailCount)} внутри раздела',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
        ],
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
  final isReadOnly = s.widget.readOnly;
  final items = summary.sections.toList(growable: false);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xs),
        child: Row(
          children: [
            Expanded(
              child: MyText(
                text: isReadOnly ? 'Разделы отчёта' : 'Обзор разделов',
                size: SparkTextSize.sectionTitle,
                weight: FontWeight.w800,
              ),
            ),
            if (isReadOnly) ...[
              const SizedBox(width: SparkSpace.md),
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
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
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
            bottom: index == items.length - 1 ? 0 : SparkSpace.lg,
          ),
          child: s._summarySectionCard(
            section,
            clientPreview: false,
            needsAttention: needsAttention,
            compactDetails: !isReadOnly,
          ),
        );
      }),
    ],
  );
}

/// Unified «Итог осмотра» card — supersedes the old two-card layout
/// («Сводка по данным осмотра» + «Итог специалиста»). One AI button,
/// one dictation toggle, one source of truth. AI regeneration treats
/// the inspector's current text as a «previous draft» so manual edits
/// survive perigeneration.
Widget _buildSparkSummaryNoteCard(_SparkJoyCreateReportScreenState s) {
  final note = s._summaryController.text.trim();
  // Read-only completed view: nothing useful when the dealer didn't
  // fill the conclusion — collapse the card so the buyer doesn't see
  // an empty placeholder.
  if (s.widget.readOnly && note.isEmpty) return const SizedBox.shrink();
  final isReadOnly = s.widget.readOnly;
  return s._card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        s._sectionHeading(
          'Итог осмотра',
          icon: Icons.rate_review_outlined,
          required: !isReadOnly,
          subtitle: isReadOnly
              ? 'Финальный итог по результатам осмотра'
              : 'Соберите итог через ИИ или введите вручную; ваши правки '
                    'сохранятся при перегенерации',
        ),
        if (isReadOnly)
          SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.lg,
              vertical: SparkSpace.lg,
            ),
            radius: SparkRadius.md,
            backgroundColor: kInputBgColor,
            child: MyText(
              text: note,
              size: SparkTextSize.bodyLg,
              color: kTertiaryColor,
              lineHeight: 1.35,
            ),
          )
        else
          s._commentInputPanel(
            controller: s._summaryController,
            hint: 'Итог по разделам — нажмите ИИ или введите вручную.',
            isDictating: s._summaryIsDictating,
            aiBusy: s._summaryNoteAiBusy,
            // Шаг «Итог» имеет свой собственный онбординг про выгрузку
            // и обязательные поля — не показываем дублирующий шит
            // «Голос и ИИ-помощник» поверх него.
            suppressOnboarding: true,
            onToggleDictation: () async {
              if (s._summaryIsDictating) {
                await s._stopSummaryDictation();
              } else {
                await s._startSummaryDictation();
              }
            },
            onAiFormat: () => unawaited(s._generateSummaryNoteWithAi()),
          ),
      ],
    ),
  );
}

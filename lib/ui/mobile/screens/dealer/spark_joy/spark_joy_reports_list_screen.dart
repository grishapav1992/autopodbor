import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_new_report_name_screen.dart';
import 'spark_joy_report_detail_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyReportsListScreen extends StatefulWidget {
  const SparkJoyReportsListScreen({super.key, this.companyMode = false});

  final bool companyMode;

  @override
  State<SparkJoyReportsListScreen> createState() =>
      _SparkJoyReportsListScreenState();
}

class _SparkJoyReportsListScreenState extends State<SparkJoyReportsListScreen> {
  late final _SparkJoyReportsListController _controller;
  final Set<String> _sharingReportKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = _SparkJoyReportsListController(
      companyMode: widget.companyMode,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.load();

  Future<void> _openNewReport() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SparkJoyNewReportNameScreen(companyMode: widget.companyMode),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openDraft(Map<String, dynamic> draft) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(draft: draft),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openCompleted(Map<String, dynamic> report) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyReportDetailScreen(report: report),
      ),
    );
  }

  int? _reportId(Map<String, dynamic> report) {
    return storage_api.StorageApi.readSpecialistReportId(report);
  }

  String _reportNumber(Map<String, dynamic> report) {
    return storage_api.StorageApi.readSpecialistReportNumber(report);
  }

  Future<int?> _ensureReportId(Map<String, dynamic> report) async {
    final directId = _reportId(report);
    if (directId != null) return directId;
    try {
      final resolved = await storage_api.StorageApi.resolveSpecialistReportId(
        report: report,
      );
      if (resolved == null) return null;
      report['id'] = resolved.toString();
      final updated = <String, dynamic>{...report, 'id': resolved.toString()};
      await SparkJoyStorage.upsertCompleted(updated);
      return resolved;
    } catch (_) {
      return null;
    }
  }

  String _reportIdentityKey(Map<String, dynamic> report) {
    return (report['id'] ??
            report['reportId'] ??
            report['reportNumber'] ??
            report['reportName'] ??
            '')
        .toString();
  }

  Future<void> _openShareUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Некорректная ссылка')));
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку')));
  }

  Future<void> _showShareLinkSheet(String url) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(SparkSpace.xl),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(SparkRadius.xl),
              border: Border.all(color: kBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(SparkSpace.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MyText(
                    text: 'Ссылка на отчёт',
                    size: SparkTextSize.title,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: SparkSpace.md),
                  SparkHintCard(text: url, icon: Icons.link_rounded),
                  const SizedBox(height: SparkSpace.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ссылка скопирована'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Копировать'),
                        ),
                      ),
                      const SizedBox(width: SparkSpace.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _openShareUrl(url);
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Открыть'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createAndCopyReportShareLink(
    Map<String, dynamic> report,
  ) async {
    final reportId = await _ensureReportId(report);
    if (!mounted) return;
    if (reportId == null) {
      final reportNumber = _reportNumber(report);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reportNumber.isEmpty
                ? 'Не удалось определить ID отчёта'
                : 'Не удалось определить ID отчёта для №$reportNumber',
          ),
        ),
      );
      return;
    }
    final key = _reportIdentityKey(report);
    if (key.isEmpty || _sharingReportKeys.contains(key)) return;
    setState(() => _sharingReportKeys.add(key));
    try {
      final generated = await storage_api
          .StorageApi.createSpecialistReportShareUrl(reportId: reportId);
      final url = generated.url.trim();
      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ссылка не была сгенерирована')),
        );
        return;
      }
      final updated = <String, dynamic>{
        ...report,
        'shareUrl': url,
        'shareUrlCreatedAt': DateTime.now().toIso8601String(),
      };
      await SparkJoyStorage.upsertCompleted(updated);
      _controller.patchCompletedReportById(reportId, updated);
      if (!mounted) return;
      await _showShareLinkSheet(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сгенерировать ссылку')),
      );
    } finally {
      if (mounted) {
        setState(() => _sharingReportKeys.remove(key));
      }
    }
  }

  Future<void> _deleteDraft(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkRadius.lg),
        ),
        title: const Text('Удалить черновик?'),
        content: const Text(
          'Черновик будет удалён без возможности восстановления. '
          'Все данные и загруженные медиа будут потеряны.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          SparkSpace.md,
          0,
          SparkSpace.md,
          SparkSpace.md,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: kGreyColor),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: kRedColor,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SparkJoyStorage.deleteDraft(id);
    if (!mounted) return;
    await _load();
  }

  /// Computes real per-section completion for a draft. Returns the ordered
  /// list of 7 sections with their "filled" state so the card UI can:
  ///   • render a progress bar proportional to completion,
  ///   • count filled / total,
  ///   • surface the names of empty sections so users know what's missing.
  ///
  /// Completion rules target *meaningful* user input, not just step
  /// navigation — visiting a step without typing anything does NOT mark it
  /// as filled.
  List<_DraftSectionStatus> _computeDraftCompletion(Map<String, dynamic> draft) {
    bool hasText(String key) => sjRead(draft, key).trim().isNotEmpty;

    bool isTrue(Object? value) => value == true;

    bool anyNonNull(List<String> keys) {
      for (final key in keys) {
        if (draft.containsKey(key) && draft[key] != null) return true;
      }
      return false;
    }

    bool hasUploadedList(String key) {
      final value = draft[key];
      return value is List && value.isNotEmpty;
    }

    bool anyMediaHasFiles() {
      final raw = draft['mediaGroupsState'];
      if (raw is! Map) return false;
      for (final entry in raw.values) {
        if (entry is Map) {
          final files = entry['files'];
          if (files is List && files.isNotEmpty) return true;
        }
      }
      return false;
    }

    return <_DraftSectionStatus>[
      // 1) Авто — any car-picker selection (brand/model/…) or any text
      //    identity field counts. Per step description "VIN, госномер,
      //    марка/модель, пробег, владельцы и город осмотра".
      _DraftSectionStatus(
        label: 'Авто',
        filled: hasText('brand') ||
            hasText('model') ||
            hasText('generation') ||
            hasText('restyling') ||
            hasText('make') ||
            hasText('car') ||
            hasText('vin') ||
            isTrue(draft['vinUnreadable']) ||
            hasText('plate') ||
            hasText('adLink') ||
            hasText('mileage') ||
            hasText('ownersCount') ||
            hasText('owners') ||
            hasText('inspectionCity') ||
            hasText('inspectionDate'),
      ),
      // 2) Параметры — powertrain / comfort fields. Drafts persist with
      //    `engineVolume`, `engineType`, `gearboxType`, `driveType`,
      //    `color`, `trim`, but the init helper also accepts legacy
      //    aliases (`engine`, `transmission`, `drive`) for drafts
      //    imported from completed reports. Match both sets so the
      //    section doesn't get counted as empty when the data lives
      //    under the legacy key.
      _DraftSectionStatus(
        label: 'Параметры',
        filled: hasText('engineVolume') ||
            hasText('engineType') ||
            hasText('engine') ||
            hasText('gearboxType') ||
            hasText('transmission') ||
            hasText('driveType') ||
            hasText('drive') ||
            hasText('color') ||
            hasText('trim'),
      ),
      // 3) Документы — any tri-state toggled, any mismatch comment, or
      //    any audio attachment. Previously only tri-states counted, so
      //    a user who typed a comment saw the section as "empty".
      _DraftSectionStatus(
        label: 'Документы',
        filled: anyNonNull([
              'docsOwnerMatch',
              'docsVinMatch',
              'docsEngineMatch',
            ]) ||
            hasText('docsMismatchComment') ||
            hasUploadedList('docsCommentAudioFiles'),
      ),
      // 4) Юр. проверка — explicit skip / purchase, any uploaded file,
      //    any note typed, or an attached audio comment.
      _DraftSectionStatus(
        label: 'Юр. проверка',
        filled: isTrue(draft['legalSkipped']) ||
            isTrue(draft['legalPurchased']) ||
            hasUploadedList('legalFiles') ||
            hasText('legalNote') ||
            hasUploadedList('legalCommentAudioFiles'),
      ),
      // 5) Осмотр — at least one media group has an uploaded file.
      _DraftSectionStatus(
        label: 'Осмотр',
        filled: anyMediaHasFiles(),
      ),
      // 6) Тест-драйв — user explicitly answered the "был ли тест-драйв"
      //    question, or picked any tag / uploaded any comment audio.
      _DraftSectionStatus(
        label: 'Тест-драйв',
        filled: draft['tdConducted'] != null ||
            hasUploadedList('tdEngineTags') ||
            hasUploadedList('tdGearboxTags') ||
            hasUploadedList('tdSteeringTags') ||
            hasUploadedList('tdRideTags') ||
            hasUploadedList('tdBrakeTags') ||
            hasUploadedList('tdCommentAudioFiles'),
      ),
      // 7) Итог — user's summary text field, expert-conclusion text
      //    field, or uploaded expert-comment audio. Drafts store these
      //    as `summaryNote` and `expertConclusion`; the old bare
      //    `summary` / `verdict` keys only exist on completed reports,
      //    never in drafts — that's why this step was rendering empty
      //    even when the user had typed a summary.
      _DraftSectionStatus(
        label: 'Итог',
        filled: hasText('summaryNote') ||
            hasText('expertConclusion') ||
            isTrue(draft['expertConclusionTouched']) ||
            hasUploadedList('expertAudioFiles'),
      ),
    ];
  }

  Widget _buildDraftCard(Map<String, dynamic> draft) {
    final title = [
      sjRead(draft, 'reportName'),
      sjRead(draft, 'car'),
      sjRead(draft, 'vin'),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Новый отчёт');

    final sections = _computeDraftCompletion(draft);
    final filled = sections.where((s) => s.filled).length;
    final total = sections.length;
    final progress = total == 0 ? 0.0 : filled / total;

    // Each draft card carries a shadow + a rounded clip (Stage 2 A+ token
    // bump), both of which otherwise force the whole list layer to repaint
    // on every scroll frame. The RepaintBoundary isolates each card into
    // its own raster cache — scrolled cards stay static and only newly
    // revealed ones actually get painted.
    return RepaintBoundary(
      child: SparkListCard(
      onTap: () => _openDraft(draft),
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1) Title (left) + 3) icon-only delete button (top-right).
          //
          // Placement follows Material 3 ListTile.trailing + iOS cell
          // accessory conventions: secondary destructive action sits in
          // the top-right corner, well away from the primary "continue"
          // tap target that covers the rest of the card. IconButton
          // renders a 48×48 logical-px tap area by default, so the icon
          // can stay visually small (22 pt) without shrinking the hit
          // zone.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  // Nudge the title down so it visually aligns with the
                  // centre of the 48-pt IconButton on the right.
                  padding: const EdgeInsets.only(top: SparkSpace.xs),
                  child: MyText(
                    text: title,
                    size: SparkTextSize.title,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: SparkSpace.sm),
              IconButton(
                onPressed: () => _deleteDraft(sjRead(draft, 'id')),
                tooltip: 'Удалить черновик',
                icon: const Icon(Icons.delete_outline_rounded),
                color: kRedColor,
                iconSize: 22,
                visualDensity: VisualDensity.compact,
                // Keep the IconButton tight to the card edge so it
                // doesn't steal vertical height but still has the
                // Material 48×48 minimum tap area via the default
                // constraints.
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ],
          ),
          // 2) Last-modified date as a subtitle under the title.
          MyText(
            text: 'Изменён ${sjFormatDate(sjRead(draft, 'updatedAt'))}',
            size: SparkTextSize.caption,
            color: kGreyColor,
            paddingTop: SparkSpace.xxs,
          ),
          const SizedBox(height: SparkSpace.md),
          // Single-colour progress bar — just "filled / total" sections with
          // no required/optional distinction.
          //
          // Wrapped in Semantics so VoiceOver / TalkBack announce the
          // progress as a single coherent node ("Прогресс заполнения,
          // заполнено X из Y, Z процентов") instead of reading the bare
          // counter text next to a silent progress bar. `container: true`
          // promotes this into its own a11y element; `excludeSemantics`
          // on the children prevents the MyText counter from being read
          // a second time.
          Semantics(
            container: true,
            label: 'Прогресс заполнения отчёта',
            value: 'Заполнено $filled из $total',
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(SparkRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: kSecondaryColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        filled == total ? kGreenColor : kSecondaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                MyText(
                  text: 'Заполнено $filled из $total',
                  size: SparkTextSize.chip,
                  color: kGreyColor,
                  weight: FontWeight.w600,
                  tabularFigures: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> report) {
    final car = [
      sjRead(report, 'car'),
      [
        sjRead(report, 'make'),
        sjRead(report, 'model'),
      ].where((e) => e.isNotEmpty).join(' '),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Отчёт');

    final title = sjRead(report, 'reportName', fallback: car);
    final verdict = sjRead(report, 'verdict');
    final score = sjRead(report, 'score');
    final reportKey = _reportIdentityKey(report);
    final shareLoading =
        reportKey.isNotEmpty && _sharingReportKeys.contains(reportKey);

    final metaParts = <String>[
      if (car != title && car.isNotEmpty) car,
      if (sjRead(report, 'vin').isNotEmpty) sjRead(report, 'vin'),
      if (sjRead(report, 'mileage').isNotEmpty)
        sjFormatMileage(sjRead(report, 'mileage')),
    ];

    // Same RepaintBoundary reasoning as _buildDraftCard — keeps scrolled
    // completed cards out of the repaint queue.
    return RepaintBoundary(
      child: SparkListCard(
      onTap: () => _openCompleted(report),
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: title + meta on the left, date on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: title,
                      size: SparkTextSize.bodyLg,
                      weight: FontWeight.w700,
                    ),
                    if (metaParts.isNotEmpty)
                      MyText(
                        text: metaParts.join(' · '),
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              MyText(
                text: sjFormatDate(sjRead(report, 'createdAt')),
                size: SparkTextSize.chip,
                color: kGreyColor,
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          // Verdict + score chips on the left, share button on the right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: SparkSpace.sm,
                  runSpacing: SparkSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SparkChip(
                      text: sparkVerdictLabel(verdict),
                      background:
                          sparkVerdictColor(verdict).withValues(alpha: 0.12),
                      color: sparkVerdictColor(verdict),
                    ),
                    if (score.isNotEmpty && score != '—')
                      SparkChip(
                        text: score,
                        background: kSecondaryColor.withValues(alpha: 0.08),
                        color: kSecondaryColor,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              InkWell(
                onTap: shareLoading
                    ? null
                    : () => _createAndCopyReportShareLink(report),
                borderRadius: BorderRadius.circular(SparkRadius.pill),
                child: Padding(
                  padding: const EdgeInsets.all(SparkSpace.sm),
                  child: shareLoading
                      ? const SizedBox(
                          width: SparkSize.iconSm,
                          height: SparkSize.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.share_outlined,
                          size: SparkSize.iconMd,
                          color: kSecondaryColor,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final drafts = _controller.filteredDrafts;
        final completed = _controller.filteredCompleted;

        return SparkScreenList(
          bottomInset: 56,
          onRefresh: _load,
          children: [
            SparkPrimaryActionButton(
              label: 'Создать новый отчёт',
              onTap: _openNewReport,
            ),
            const SizedBox(height: SparkSpace.xl),
            SparkSearchField(
              hint: 'Поиск по марке, модели, VIN...',
              onChanged: _controller.setSearch,
            ),
            const SizedBox(height: SparkSpace.lg),
            SparkSegmentedTabs(
              items: [
                SparkSegmentedTabItem(
                  value: 'drafts',
                  label: 'Черновики',
                  count: drafts.length,
                ),
                SparkSegmentedTabItem(
                  value: 'completed',
                  label: 'Завершённые',
                  count: completed.length,
                ),
              ],
              value: _controller.tab,
              onChanged: _controller.setTab,
            ),
            const SizedBox(height: SparkSpace.lg),
            if (_controller.loading)
              SparkLoadingState(
                message: sjT(
                  'spark.state.loading.reports',
                  fallback: 'Загрузка отчётов...',
                ),
              )
            else if (_controller.loadError != null)
              SparkErrorState(
                title: sjT(
                  'spark.state.error.title',
                  fallback: 'Ошибка загрузки',
                ),
                subtitle: _controller.loadError!,
                onRetry: _load,
              )
            else if (_controller.tab == 'drafts')
              if (drafts.isEmpty)
                SparkEmptyState(
                  icon: Icons.edit_note,
                  title: sjT(
                    'spark.empty.noDrafts.title',
                    fallback: 'Нет черновиков',
                  ),
                  subtitle: sjT(
                    'spark.empty.noDrafts.subtitle',
                    fallback: 'Начните новый отчёт, чтобы увидеть его здесь',
                  ),
                  topPadding: SparkSpace.xxxl,
                )
              else
                ...drafts.map(_buildDraftCard)
            else if (completed.isEmpty)
              ...[
                SparkEmptyState(
                  icon: Icons.check_circle_outline,
                  title: sjT(
                    'spark.empty.noCompleted.title',
                    fallback: 'Нет завершённых отчётов',
                  ),
                  subtitle: _controller.completedSyncFailed
                      ? 'Не удалось обновить список. Проверьте интернет и повторите.'
                      : sjT(
                          'spark.empty.noCompleted.subtitle',
                          fallback: 'Завершите осмотр, чтобы увидеть результат',
                        ),
                  topPadding: SparkSpace.xxxl,
                ),
                if (_controller.completedSyncFailed) ...[
                  const SizedBox(height: SparkSpace.xl),
                  SizedBox(
                    width: double.infinity,
                    height: SparkSize.actionHeightMd,
                    child: OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Повторить'),
                    ),
                  ),
                ],
              ]
            else
              ...completed.map(_buildCompletedCard),
          ],
        );
      },
    );
  }
}

class _SparkJoyReportsListController extends ChangeNotifier {
  _SparkJoyReportsListController({required this.companyMode});

  final bool companyMode;
  String _search = '';
  String _tab = 'drafts';
  bool _loading = true;
  String? _loadError;
  bool _completedSyncFailed = false;
  int _loadToken = 0;
  bool _disposed = false;

  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _completed = <Map<String, dynamic>>[];

  String _completedIdentity(Map<String, dynamic> report) {
    for (final key in const [
      'id',
      'reportId',
      'report_id',
      'reportNumber',
      'number',
      'reportCode',
    ]) {
      final value = report[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return '$key:$value';
    }
    final name = sjRead(report, 'reportName');
    final date = sjRead(report, 'createdAt', fallback: sjRead(report, 'date'));
    if (name.isNotEmpty || date.isNotEmpty) {
      return 'fallback:${name}_$date';
    }
    return '';
  }

  List<Map<String, dynamic>> _mergeCompletedReports({
    required List<Map<String, dynamic>> cached,
    required List<Map<String, dynamic>> remote,
  }) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final report in cached) {
      final key = _completedIdentity(report);
      if (key.isEmpty) continue;
      byKey[key] = Map<String, dynamic>.from(report);
    }
    for (final report in remote) {
      final key = _completedIdentity(report);
      if (key.isEmpty) continue;
      final previous = byKey[key];
      byKey[key] = previous == null
          ? Map<String, dynamic>.from(report)
          : <String, dynamic>{...previous, ...report};
    }
    final merged = byKey.values.toList();
    merged.sort((a, b) {
      final ad = sjRead(a, 'updatedAt', fallback: sjRead(a, 'createdAt'));
      final bd = sjRead(b, 'updatedAt', fallback: sjRead(b, 'createdAt'));
      if (ad.isEmpty && bd.isEmpty) return 0;
      if (ad.isEmpty) return 1;
      if (bd.isEmpty) return -1;
      return bd.compareTo(ad);
    });
    return merged;
  }

  String get tab => _tab;
  bool get loading => _loading;
  String? get loadError => _loadError;
  bool get completedSyncFailed => _completedSyncFailed;
  List<Map<String, dynamic>> get drafts => _drafts;
  List<Map<String, dynamic>> get completed => _completed;

  List<Map<String, dynamic>> get filteredDrafts {
    if (_search.trim().isEmpty) return _drafts;
    final query = _search.toLowerCase();
    return _drafts.where((d) {
      final text = [
        sjRead(d, 'reportName'),
        sjRead(d, 'car'),
        sjRead(d, 'brand'),
        sjRead(d, 'model'),
        sjRead(d, 'vin'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredCompleted {
    if (_search.trim().isEmpty) return _completed;
    final query = _search.toLowerCase();
    return _completed.where((r) {
      final text = [
        sjRead(r, 'reportName'),
        sjRead(r, 'car'),
        sjRead(r, 'make'),
        sjRead(r, 'model'),
        sjRead(r, 'vin'),
        sjRead(r, 'plate'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    _safeNotify();
  }

  void setTab(String value) {
    if (_tab == value) return;
    _tab = value;
    _safeNotify();
  }

  void patchCompletedReportById(int reportId, Map<String, dynamic> next) {
    var changed = false;
    _completed = _completed.map((report) {
      final rawId = report['id'] ?? report['reportId'] ?? report['report_id'];
      final parsedId = int.tryParse(rawId?.toString() ?? '');
      if (parsedId == null || parsedId != reportId) return report;
      changed = true;
      return Map<String, dynamic>.from(next);
    }).toList();
    if (changed) _safeNotify();
  }

  Future<void> load() async {
    final token = ++_loadToken;
    _loading = true;
    _loadError = null;
    _completedSyncFailed = false;
    _safeNotify();
    try {
      final allDrafts = await SparkJoyStorage.loadDrafts();
      final cachedCompleted = await SparkJoyStorage.loadCompleted();
      if (_disposed || token != _loadToken) return;
      _drafts = allDrafts.where(_isVisibleDraft).toList();
      _completed = cachedCompleted;
      _loading = false;
      _loadError = null;
      _safeNotify();

      try {
        final remoteCompleted =
            await storage_api.StorageApi.getSpecialistReport(
              page: 1,
              limit: 100,
              isDraft: false,
            );
        if (_disposed || token != _loadToken) return;
        _completed = _mergeCompletedReports(
          cached: cachedCompleted,
          remote: remoteCompleted,
        );
        _loadError = null;
        _completedSyncFailed = false;
        _safeNotify();
        await SparkJoyStorage.replaceCompleted(_completed);
      } catch (_) {
        if (_disposed || token != _loadToken) return;
        _completedSyncFailed = true;
        _safeNotify();
      }
    } catch (_) {
      if (_disposed || token != _loadToken) return;
      _loading = false;
      _loadError = sjT(
        'spark.state.error.reports',
        fallback:
            'Не удалось загрузить отчёты. Проверьте локальные данные и повторите.',
      );
      _safeNotify();
    }
  }

  bool _isVisibleDraft(Map<String, dynamic> draft) {
    if (companyMode) {
      final companyId = sjRead(draft, 'companyId');
      final businessType = sjRead(draft, 'businessType');
      if (companyId.isNotEmpty) return companyId == kSparkCompanyId;
      return businessType == 'company' || businessType == 'ip';
    }

    final assignedSpecialistId = sjRead(
      draft,
      'assignedSpecialistId',
      fallback: sjRead(draft, 'specialistId'),
    );
    if (assignedSpecialistId.isEmpty) return true;
    return assignedSpecialistId == kSparkSpecialistId;
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Per-section status inside a draft — used by the draft card to render a
/// real completion progress (count of filled sections, not just the
/// current step index). `label` stays on the record so future work can
/// resurface section names without re-introducing the classifier.
class _DraftSectionStatus {
  const _DraftSectionStatus({required this.label, required this.filled});

  // ignore: unused_field
  final String label;
  final bool filled;
}


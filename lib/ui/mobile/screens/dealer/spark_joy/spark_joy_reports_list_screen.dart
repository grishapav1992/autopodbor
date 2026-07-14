import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';

import 'package:flutter_application_1/data/services/spark_joy_intake_upload_service.dart';
import 'package:flutter_application_1/data/services/spark_joy_tag_service.dart';

import 'spark_joy_completed_report_hydrator.dart';
import 'spark_joy_create_report_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_new_report_name_screen.dart';
import 'spark_joy_onboarding.dart';
import 'spark_joy_report_context.dart';
import 'spark_joy_request_detail_ui.dart';
import 'spark_joy_share.dart';
import 'spark_joy_specialist_public_profile_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyReportsListScreen extends StatefulWidget {
  const SparkJoyReportsListScreen({
    super.key,
    this.active = false,
    this.companyMode = false,
    this.tabRequest,
  });

  final bool active;
  final bool companyMode;

  /// Optional external trigger the shell can push into to switch the
  /// segmented tab (e.g. profile deep-link to "Завершённые"). The
  /// request is consumed exactly once per emitted value — the listener
  /// resets it back to null so the same request can fire again later.
  final ValueListenable<String?>? tabRequest;

  @override
  State<SparkJoyReportsListScreen> createState() =>
      _SparkJoyReportsListScreenState();
}

class _SparkJoyReportsListScreenState extends State<SparkJoyReportsListScreen> {
  late final _SparkJoyReportsListController _controller;
  final Set<String> _sharingReportKeys = <String>{};

  // Черновики, смахнутые влево и ждущие коммита удаления: карточка уже
  // скрыта из списка, но данные остаются в storage, пока не истечёт окно
  // отмены (см. _onDraftSwiped).
  final Set<String> _pendingDraftDeletionIds = <String>{};
  final Map<String, Timer> _pendingDraftDeletionTimers = <String, Timer>{};
  static const Duration _draftUndoWindow = Duration(seconds: 5);

  // Completed-report tap is async (we fetch the full payload via
  // Storage.ViewSpecialistReport before opening). Track the identity keys
  // currently loading so the completed card can show a spinner and block
  // duplicate taps — otherwise mashing the card spawns parallel RPCs.
  final Set<String> _openingReportKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = _SparkJoyReportsListController(
      companyMode: widget.companyMode,
    );
    _controller.load();
    widget.tabRequest?.addListener(_handleExternalTabRequest);
    if (widget.active) _showReportsOnboarding();
  }

  @override
  void didUpdateWidget(covariant SparkJoyReportsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _showReportsOnboarding();
    }
  }

  @override
  void dispose() {
    // Уходим с экрана — коммитим отложенные удаления сразу (fire-and-forget,
    // storage-операции переживают dispose), иначе смахнутые карточки
    // воскреснут при следующем входе.
    for (final id in _pendingDraftDeletionTimers.keys.toList()) {
      unawaited(_commitDraftDeletion(id));
    }
    widget.tabRequest?.removeListener(_handleExternalTabRequest);
    _controller.dispose();
    super.dispose();
  }

  void _showReportsOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      SparkJoyOnboarding.showOnce(
        context,
        flagKey: UserSimplePreferences.sparkOnbReportsListKey,
        titleI18nKey: 'spark.onboarding.reportsList.title',
        titleFallback: 'Отчёты осмотров',
        bullets: const [
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.reportsList.b1',
            fallback:
                'Здесь вы видите свои черновики и завершённые отчёты по всем машинам.',
            icon: Icons.list_alt_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.reportsList.b2',
            fallback:
                'Чтобы создать новый отчёт — нажмите «+» и заполните VIN или госномер.',
            icon: Icons.add_circle_outline_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.reportsList.b3',
            fallback:
                'Завершённый отчёт можно открыть в просмотре или поделиться им по ссылке.',
            icon: Icons.ios_share_rounded,
          ),
        ],
      );
    });
  }

  void _handleExternalTabRequest() {
    final requested = widget.tabRequest?.value;
    if (requested == null || requested.isEmpty) return;
    _controller.setTab(requested);
    if (requested == 'drafts') {
      unawaited(_load());
    }
    // Reset the notifier so an identical request later (e.g. user taps
    // "Отчётов" again after a manual tab switch) still triggers the
    // listener. Only the shell owns the notifier so this is safe.
    final notifier = widget.tabRequest;
    if (notifier is ValueNotifier<String?>) {
      notifier.value = null;
    }
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

  /// True when the current user is a company AND the draft has an
  /// external assignee — i.e. the work belongs to someone else and the
  /// company is only tracking it. Company cannot edit such drafts;
  /// tapping opens the status sheet, not the stepper.
  bool _isAssignedCompanyDraft(Map<String, dynamic> draft) {
    if (!widget.companyMode) return false;
    final assigneeId = sjRead(
      draft,
      'assignedSpecialistId',
      fallback: sjRead(draft, 'specialistId'),
    ).trim();
    final inviteLink = sjRead(draft, 'staffInviteLink').trim();
    return assigneeId.isNotEmpty || inviteLink.isNotEmpty;
  }

  Widget _statusPill({required String label, IconData? icon}) {
    final text = MyText(
      text: label,
      size: SparkTextSize.caption,
      weight: FontWeight.w600,
      color: kSecondaryColor,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.xs,
      ),
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: kSecondaryColor),
                const SizedBox(width: SparkSpace.xs),
                text,
              ],
            ),
    );
  }

  /// Human-readable status for an assigned company draft. Falls back
  /// to the raw `status` field (`assigned` / `awaiting_invite` /
  /// `in_progress` set in the create flow + future backend updates).
  String _assignedStatusLabel(Map<String, dynamic> draft) {
    final status = sjRead(draft, 'status');
    final assigneeName = sjRead(
      draft,
      'assignedSpecialistName',
      fallback: sjRead(draft, 'specialistName'),
    ).trim();
    switch (status) {
      case 'in_progress':
        return assigneeName.isEmpty ? 'В работе' : '$assigneeName · в работе';
      case 'awaiting_invite':
        return 'Ожидает приглашения';
      case 'assigned':
      default:
        return assigneeName.isEmpty
            ? 'Отправлен исполнителю'
            : 'Отправлен: $assigneeName';
    }
  }

  Future<void> _openDraft(Map<String, dynamic> draft) async {
    // Company users cannot open/edit drafts that are being worked on
    // by someone else — we show a status-only detail sheet instead.
    if (_isAssignedCompanyDraft(draft)) {
      await _showAssignedDetailSheet(draft);
      if (!mounted) return;
      await _load();
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(draft: draft),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _unassignDraft(Map<String, dynamic> draft) async {
    // Keeps the draft but strips the assignment — company becomes the
    // editor again. Other fields (name, vin, progress) survive so the
    // company doesn't lose intermediate context if they want to
    // reassign or take over the work.
    final next = Map<String, dynamic>.from(draft);
    next['assignedSpecialistId'] = '';
    next['assignedSpecialistName'] = '';
    next['specialistId'] = '';
    next['specialistName'] = '';
    next['staffInviteLink'] = '';
    next['status'] = 'draft';
    await SparkJoyStorage.upsertDraft(next);
  }

  Future<void> _showAssignedDetailSheet(Map<String, dynamic> draft) async {
    final title = [
      sjRead(draft, 'reportName'),
      sjRead(draft, 'car'),
      sjRead(draft, 'vin'),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Отчёт');
    final assigneeName = sjRead(
      draft,
      'assignedSpecialistName',
      fallback: sjRead(draft, 'specialistName'),
    ).trim();
    final assigneeId = int.tryParse(
      sjRead(
        draft,
        'assignedSpecialistId',
        fallback: sjRead(draft, 'specialistId'),
      ).trim(),
    );
    final inviteLink = sjRead(draft, 'staffInviteLink').trim();
    final createdAt = sjFormatDate(
      sjRead(draft, 'createdAt', fallback: sjRead(draft, 'updatedAt')),
    );
    final statusLabel = _assignedStatusLabel(draft);

    await showAppAdaptiveBottomSheet<void>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.xl,
            0,
            SparkSpace.xl,
            SparkSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBottomSheetHeader(title: title),
              const SizedBox(height: SparkSpace.md),
              Align(
                alignment: Alignment.centerLeft,
                child: _statusPill(label: statusLabel),
              ),
              const SizedBox(height: SparkSpace.lg),
              if (assigneeName.isNotEmpty)
                SparkInfoRow(
                  label: 'Исполнитель',
                  value: assigneeName,
                  onTap: () => _openSpecialistProfile(
                    SparkJoyReportRequestContext(
                      specialistId: assigneeId,
                      specialistName: assigneeName,
                    ),
                  ),
                ),
              if (inviteLink.isNotEmpty) ...[
                const SizedBox(height: SparkSpace.md),
                const MyText(
                  text: 'Ссылка приглашения',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
                const SizedBox(height: SparkSpace.xxs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                    vertical: SparkSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: kInputBgColor,
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(SparkRadius.md),
                  ),
                  child: MyText(
                    text: inviteLink,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                ),
              ],
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: SparkSpace.md),
                SparkInfoRow(label: 'Создан', value: createdAt),
              ],
              const SizedBox(height: SparkSpace.xl),
              OutlinedButton.icon(
                // Await the storage write BEFORE popping so the outer
                // `_openDraft → _load()` doesn't race the unassignment
                // and show a stale list for a frame. Capture the
                // Navigator + Messenger refs before the await so we
                // don't touch a (possibly stale) BuildContext across
                // the async gap.
                onPressed: () async {
                  final sheetNavigator = Navigator.of(sheetCtx);
                  final messenger = ScaffoldMessenger.of(context);
                  await _unassignDraft(draft);
                  if (!mounted) return;
                  sheetNavigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Назначение снято. Черновик снова редактируется.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Отменить назначение'),
              ),
              const SizedBox(height: SparkSpace.sm),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _deleteDraft(sjRead(draft, 'id'));
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Удалить отчёт'),
                style: OutlinedButton.styleFrom(foregroundColor: kRedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCompleted(Map<String, dynamic> report) async {
    final key = _reportIdentityKey(report);
    if (key.isEmpty || _openingReportKeys.contains(key)) return;
    setState(() => _openingReportKeys.add(key));

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Map<String, dynamic>? fetched;
    try {
      final reportId = await _ensureReportId(report);
      if (reportId == null) {
        throw StateError('reportId missing');
      }
      final remote = await storage_api.StorageApi.viewSpecialistReport(
        reportId: reportId,
      );
      if (remote.isEmpty) {
        throw StateError('empty payload');
      }
      // Online-only path: server response is the source of truth. Hydrate
      // into editor draft-shape with presigned view URLs + tag names.
      final tagService = SparkJoyTagService();
      await tagService.hydrateFromCache();
      fetched = await hydrateCompletedReport(
        server: remote,
        tagService: tagService,
      );
    } catch (_) {
      fetched = null;
    } finally {
      if (mounted) {
        setState(() => _openingReportKeys.remove(key));
      }
    }

    if (!mounted) return;
    if (fetched == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось загрузить отчёт с сервера. Проверьте соединение и повторите.',
          ),
        ),
      );
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SparkJoyCreateReportScreen(draft: fetched, readOnly: true),
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
      // Completed reports are online-only — keep the share URL in
      // in-memory controller state only. A later pull-to-refresh or cold
      // start will re-resolve via Storage.CreateSpecialistReportShareUrl.
      _controller.patchCompletedReportById(reportId, updated);
      if (!mounted) return;
      await shareSpecialistReportUrl(
        context,
        url: url,
        subject: sjRead(report, 'reportName', fallback: sjRead(report, 'car')),
      );
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
    await _performDraftDeletion(id);
    if (!mounted) return;
    await _load();
  }

  Future<void> _performDraftDeletion(String id) async {
    // Сначала гасим фоновую заливку интейка и её локальные копии — после
    // deleteDraft ссылок на файлы уже не будет и их подобрал бы только GC.
    await SparkJoyIntakeUploadService.instance.dropDraft(
      id,
      deleteLocalFiles: true,
    );
    await SparkJoyStorage.deleteDraft(id);
  }

  /// Полный свайп-влево по карточке черновика. Вместо диалога подтверждения —
  /// отложенный коммит: карточка сразу прячется (id попадает в
  /// [_pendingDraftDeletionIds]), но в storage черновик живёт ещё
  /// [_draftUndoWindow] — пока открыт снекбар с «Отменить». Отмена = просто
  /// снова показать карточку, откатывать нечего.
  ///
  /// Коммит привязан к собственному таймеру, а не к `closed`-future
  /// снекбара: жизненный цикл снекбара (persist-поведение, замещение
  /// следующим, ручной dismiss) не должен управлять безвозвратным
  /// удалением данных.
  void _onDraftSwiped(String id) {
    setState(() => _pendingDraftDeletionIds.add(id));
    final messenger = ScaffoldMessenger.of(context);
    // Серия свайпов не должна копить очередь снекбаров: показываем только
    // последний, у предыдущих продолжают тикать их таймеры коммита.
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Черновик удалён'),
        duration: _draftUndoWindow,
        // Со Flutter 3.41 снекбар с action по умолчанию persist == true и
        // не закрывается по таймауту — а окно отмены должно совпадать со
        // временем жизни снекбара.
        persist: false,
        action: SnackBarAction(
          label: 'Отменить',
          textColor: kWhiteColor,
          onPressed: () => _undoDraftDeletion(id),
        ),
      ),
    );
    _pendingDraftDeletionTimers[id] = Timer(
      _draftUndoWindow,
      () => _commitDraftDeletion(id),
    );
  }

  void _undoDraftDeletion(String id) {
    _pendingDraftDeletionTimers.remove(id)?.cancel();
    _pendingDraftDeletionIds.remove(id);
    if (mounted) setState(() {});
  }

  Future<void> _commitDraftDeletion(String id) async {
    _pendingDraftDeletionTimers.remove(id)?.cancel();
    // Уже отменили — коммитить нечего.
    if (!_pendingDraftDeletionIds.contains(id)) return;
    // Коммитим независимо от mounted: пользователь мог уйти с экрана,
    // но смахнутый черновик обязан удалиться.
    await _performDraftDeletion(id);
    _pendingDraftDeletionIds.remove(id);
    if (!mounted) return;
    await _load();
  }

  // ————— Redesign helpers (макет «Отчёты - редизайн») —————

  /// 54×54 плитка со значком слева от карточки, тон — по акцентному цвету.
  Widget _leadingTile({required IconData icon, required Color accent}) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SparkRadius.md),
      ),
      child: Icon(icon, size: SparkSize.iconXxl, color: accent),
    );
  }

  /// Сегментированный прогресс-бар: [total] равных сегментов, первые [filled]
  /// закрашены navy, остальные — бледные.
  Widget _segmentedProgress(int filled, int total) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: SparkSpace.xs),
          Expanded(
            child: Container(
              height: SparkSize.progressThin,
              decoration: BoxDecoration(
                color: i < filled
                    ? kSecondaryColor
                    : kSecondaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SparkRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 36×36 квадратная кнопка с рамкой (например, «Поделиться»).
  Widget _squareIconButton({
    required Widget child,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: kWhiteColor,
      borderRadius: BorderRadius.circular(SparkRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SparkRadius.sm),
            border: Border.all(color: kBorderColor),
          ),
          child: child,
        ),
      ),
    );
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
  List<_DraftSectionStatus> _computeDraftCompletion(
    Map<String, dynamic> draft,
  ) {
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
        filled:
            hasText('brand') ||
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
        filled:
            hasText('engineVolume') ||
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
        filled:
            anyNonNull(['docsOwnerMatch', 'docsVinMatch', 'docsEngineMatch']) ||
            hasText('docsMismatchComment') ||
            hasUploadedList('docsCommentAudioFiles'),
      ),
      // 4) Юр. проверка — explicit skip / purchase, any uploaded file,
      //    any note typed, or an attached audio comment.
      _DraftSectionStatus(
        label: 'Юр. проверка',
        filled:
            isTrue(draft['legalSkipped']) ||
            isTrue(draft['legalPurchased']) ||
            hasUploadedList('legalFiles') ||
            hasText('legalNote') ||
            hasUploadedList('legalCommentAudioFiles'),
      ),
      // 5) Осмотр — at least one media group has an uploaded file.
      _DraftSectionStatus(label: 'Осмотр', filled: anyMediaHasFiles()),
      // 6) Тест-драйв — user explicitly answered the "был ли тест-драйв"
      //    question, or picked any tag / uploaded any comment audio.
      _DraftSectionStatus(
        label: 'Тест-драйв',
        filled:
            draft['tdConducted'] != null ||
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
        filled:
            hasText('summaryNote') ||
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

    // Assigned drafts in company mode get a different card shape: no
    // progress bar (not the company's work to track progress on), a
    // status chip instead, and no swipe-to-delete (deletion lives in
    // the status sheet with a confirm dialog). Tap opens the sheet via
    // _openDraft.
    if (_isAssignedCompanyDraft(draft)) {
      return _buildAssignedDraftCard(draft, title);
    }

    final sections = _computeDraftCompletion(draft);
    final filled = sections.where((s) => s.filled).length;
    final total = sections.length;
    final id = sjRead(draft, 'id');

    // Each draft card carries a shadow + a rounded clip (Stage 2 A+ token
    // bump), both of which otherwise force the whole list layer to repaint
    // on every scroll frame. The RepaintBoundary isolates each card into
    // its own raster cache — scrolled cards stay static and only newly
    // revealed ones actually get painted.
    //
    // Удаление — полный свайп влево. Порог 0.7 ширины: короткий случайный
    // свайп возвращает карточку на место, диалога подтверждения нет —
    // страховка от промаха живёт в undo-снекбаре (_onDraftSwiped).
    return Dismissible(
      key: ValueKey('draft-$id'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.7},
      background: Padding(
        // Повторяет нижний зазор SparkListCard, чтобы красная подложка не
        // светилась в промежутке между карточками.
        padding: const EdgeInsets.only(bottom: SparkSpace.lg),
        child: Container(
          decoration: BoxDecoration(
            color: kRedColor,
            borderRadius: BorderRadius.circular(SparkRadius.lg),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: SparkSpace.xl),
          child: const Icon(Icons.delete_outline_rounded, color: kWhiteColor),
        ),
      ),
      onDismissed: (_) => _onDraftSwiped(id),
      child: RepaintBoundary(
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
              Row(
                children: [
                  _leadingTile(
                    icon: Icons.edit_outlined,
                    accent: kSecondaryColor,
                  ),
                  const SizedBox(width: SparkSpace.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MyText(
                          text: title,
                          size: SparkTextSize.title,
                          weight: FontWeight.w700,
                          maxLines: 1,
                          textOverflow: TextOverflow.ellipsis,
                        ),
                        MyText(
                          text:
                              'Изменён ${sjFormatDate(sjRead(draft, 'updatedAt'))}',
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                          paddingTop: SparkSpace.xxs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SparkSpace.sm),
                  const Icon(Icons.chevron_right_rounded, color: kBorderColor),
                ],
              ),
              const SizedBox(height: SparkSpace.xxl),
              // Сегментированный прогресс — filled / total секций.
              //
              // Обёрнут в Semantics, чтобы VoiceOver / TalkBack озвучивали
              // прогресс единым узлом ("Прогресс заполнения, заполнено X из Y")
              // вместо чтения голого счётчика рядом с немой полосой.
              Semantics(
                container: true,
                label: 'Прогресс заполнения отчёта',
                value: 'Заполнено $filled из $total',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Expanded(child: _segmentedProgress(filled, total)),
                    const SizedBox(width: SparkSpace.md),
                    MyText(
                      text: '$filled из $total',
                      size: SparkTextSize.body,
                      color: kGreyColor,
                      weight: FontWeight.w700,
                      tabularFigures: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card for drafts assigned to someone else (company view). Shows
  /// the current status in place of the "Заполнено X из Y" progress
  /// row and a chevron instead of swipe-to-delete — the delete +
  /// unassign actions live in the detail sheet.
  Widget _buildAssignedDraftCard(Map<String, dynamic> draft, String title) {
    final statusLabel = _assignedStatusLabel(draft);
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
            Row(
              children: [
                _leadingTile(
                  icon: Icons.assignment_ind_outlined,
                  accent: kSecondaryColor,
                ),
                const SizedBox(width: SparkSpace.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MyText(
                        text: title,
                        size: SparkTextSize.title,
                        weight: FontWeight.w700,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                      MyText(
                        text:
                            'Изменён ${sjFormatDate(sjRead(draft, 'updatedAt'))}',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SparkSpace.sm),
                const Icon(Icons.chevron_right_rounded, color: kBorderColor),
              ],
            ),
            const SizedBox(height: SparkSpace.xxl),
            Align(
              alignment: Alignment.centerLeft,
              child: _statusPill(label: statusLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> report) {
    final requestContext = sparkJoyReportRequestContext(report);
    const carFallback = 'Отчёт';
    final car = [
      sjRead(report, 'car'),
      [
        sjRead(report, 'make'),
        sjRead(report, 'model'),
      ].where((e) => e.isNotEmpty).join(' '),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => carFallback);

    final title = sjRead(report, 'reportName', fallback: car);
    // Имя авто — первично в заголовке (как в макете); reportName только как
    // фолбэк, когда данных об авто нет.
    final displayTitle = car != carFallback ? car : title;
    // «Номер уже в заголовке» считаем по РЕАЛЬНО показываемому заголовку
    // (displayTitle), а не по reportName: иначе, когда номер сидит в
    // reportName, а в заголовке отображается имя авто, строку-источник
    // скрыли бы — и номер заявки исчез бы с карточки вовсе.
    final requestNumberInTitle =
        requestContext.requestNumber.trim().isNotEmpty &&
        displayTitle.toLowerCase().contains(
          requestContext.requestNumber.trim().toLowerCase(),
        );
    final reportKey = _reportIdentityKey(report);
    final shareLoading =
        reportKey.isNotEmpty && _sharingReportKeys.contains(reportKey);
    final openLoading =
        reportKey.isNotEmpty && _openingReportKeys.contains(reportKey);

    final reportNumber = _reportNumber(report);
    final vin = sjRead(report, 'vin');
    final createdDate = sjFormatDate(sjRead(report, 'createdAt'));
    final metaLine = [
      if (reportNumber.isNotEmpty) 'Отчёт №$reportNumber',
      if (createdDate.isNotEmpty) createdDate,
    ].join(' · ');

    // Same RepaintBoundary reasoning as _buildDraftCard — keeps scrolled
    // completed cards out of the repaint queue.
    return RepaintBoundary(
      child: SparkListCard(
        onTap: openLoading ? null : () => _openCompleted(report),
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpace.xl,
          vertical: SparkSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Плитка + авто/№/дата/VIN слева, кнопка «Поделиться» справа.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leadingTile(
                  icon: Icons.directions_car_rounded,
                  accent: kSecondaryColor,
                ),
                const SizedBox(width: SparkSpace.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: displayTitle,
                        size: SparkTextSize.title,
                        weight: FontWeight.w700,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                      if (metaLine.isNotEmpty)
                        MyText(
                          text: metaLine,
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                          paddingTop: SparkSpace.xxs,
                        ),
                      if (vin.isNotEmpty)
                        MyText(
                          text: 'VIN · $vin',
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                          tabularFigures: true,
                          paddingTop: SparkSpace.xxs,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                if (openLoading)
                  const SizedBox(
                    width: SparkSize.spinner,
                    height: SparkSize.spinner,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _squareIconButton(
                    onTap: shareLoading
                        ? null
                        : () => _createAndCopyReportShareLink(report),
                    child: shareLoading
                        ? const SizedBox(
                            width: SparkSize.iconSm,
                            height: SparkSize.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.share_outlined,
                            size: SparkSize.iconMd,
                            color: kSecondaryColor,
                          ),
                  ),
              ],
            ),
            if (requestContext.hasAny &&
                !(requestNumberInTitle && !requestContext.hasSpecialist)) ...[
              const SizedBox(height: SparkSpace.xl),
              _buildCompletedRequestContext(
                requestContext,
                hideRequestLabel: requestNumberInTitle,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Открывает публичный профиль исполнителя: показываем сразу то, что
  /// уже знаем из отчёта, RPC доложит остальное (если есть id).
  Future<void> _openSpecialistProfile(
    SparkJoyReportRequestContext requestContext,
  ) async {
    final name = requestContext.specialistName.trim();
    final phone = requestContext.specialistPhone.trim();
    final avatar = requestContext.specialistAvatarUrl.trim();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoySpecialistPublicProfileScreen(
          specialistId: requestContext.specialistId,
          initialProfile: {
            if (name.isNotEmpty) 'name': name,
            if (phone.isNotEmpty) 'phone': phone,
            if (avatar.isNotEmpty) 'urlAvatar': avatar,
          },
        ),
      ),
    );
  }

  Widget _buildCompletedRequestContext(
    SparkJoyReportRequestContext requestContext, {
    bool hideRequestLabel = false,
  }) {
    final specialist = requestContext.specialistLabel;
    final phone = requestContext.specialistPhone.trim();
    final canOpenSpecialist =
        requestContext.specialistId != null || requestContext.hasSpecialist;
    final content = Row(
      children: [
        if (requestContext.hasSpecialist)
          SparkInitialsAvatar(
            name: specialist.isEmpty ? 'Специалист' : specialist,
            imageUrl: requestContext.specialistAvatarUrl,
            size: 34,
            textSize: SparkTextSize.caption,
          )
        else
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 18,
              color: kSecondaryColor,
            ),
          ),
        const SizedBox(width: SparkSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (requestContext.hasRequest && !hideRequestLabel)
                MyText(
                  text: requestContext.requestLabel,
                  size: SparkTextSize.caption,
                  weight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              if (specialist.isNotEmpty)
                MyText(
                  text: 'Исполнитель: $specialist',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  paddingTop: requestContext.hasRequest && !hideRequestLabel
                      ? 2
                      : 0,
                ),
              if (phone.isNotEmpty)
                // Вложенный тап: номер звонит, остальная плашка ведёт
                // в профиль исполнителя.
                GestureDetector(
                  onTap: () => sparkLaunchPhone(context, phone),
                  child: MyText(
                    text: phone,
                    size: SparkTextSize.caption,
                    color: kSecondaryColor,
                    paddingTop: 2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(SparkSpace.md),
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(SparkRadius.md),
        border: Border.all(color: kSecondaryColor.withValues(alpha: 0.08)),
      ),
      child: !canOpenSpecialist
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openSpecialistProfile(requestContext),
                borderRadius: BorderRadius.circular(SparkRadius.md),
                child: content,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Смахнутые черновики, ждущие коммита удаления, скрываем сразу —
        // Dismissible требует, чтобы dismissed-виджет ушёл из дерева на
        // первом же ребилде (данные при этом ещё в storage — см.
        // _onDraftSwiped). Счётчик вкладки тоже считается без них.
        final drafts = _controller.filteredDrafts
            .where((d) => !_pendingDraftDeletionIds.contains(sjRead(d, 'id')))
            .toList();
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
              hint: _controller.tab == 'completed'
                  ? 'Поиск по авто, VIN, № заявки, исполнителю...'
                  : 'Поиск по марке, модели, VIN...',
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
            else if (_controller.completedLoading && completed.isEmpty)
              SparkLoadingState(
                message: sjT(
                  'spark.state.loading.reports',
                  fallback: 'Загрузка отчётов...',
                ),
              )
            else if (completed.isEmpty) ...[
              SparkEmptyState(
                icon: Icons.check_circle_outline,
                title: _controller.hasSearch
                    ? 'Ничего не найдено'
                    : sjT(
                        'spark.empty.noCompleted.title',
                        fallback: 'Нет завершённых отчётов',
                      ),
                subtitle: _controller.completedSyncFailed
                    ? 'Не удалось обновить список. Проверьте интернет и повторите.'
                    : (_controller.hasSearch
                          ? 'Попробуйте номер заявки, имя исполнителя, телефон, VIN или модель.'
                          : sjT(
                              'spark.empty.noCompleted.subtitle',
                              fallback:
                                  'Завершите осмотр, чтобы увидеть результат',
                            )),
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
            ] else ...[
              // Subtle in-band hint when we're showing cached data because
              // the revalidation failed. Users can still open existing
              // reports + share links, and one tap on "Обновить" re-runs
              // the RPC.
              if (_controller.completedSyncFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: SparkSpace.md),
                  child: SparkHintCard(
                    icon: Icons.cloud_off_rounded,
                    text:
                        'Список не обновлён — показана последняя сохранённая версия.',
                    trailing: TextButton(
                      onPressed: _load,
                      child: const Text('Обновить'),
                    ),
                  ),
                ),
              ...completed.map(_buildCompletedCard),
            ],
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
  // True while the Storage.GetSpecialistReport RPC is in flight. Tracked
  // separately from [_loading] so the drafts tab (local-only data)
  // doesn't block on the ~12s server fetch — users who only came back
  // to change a draft name used to sit through the whole RPC before the
  // list re-appeared.
  bool _completedLoading = false;
  int _loadToken = 0;
  bool _disposed = false;

  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _completed = <Map<String, dynamic>>[];

  // Мемо фильтрации: экран перестраивается на КАЖДЫЙ notify контроллера
  // (поиск, спиннеры карточек, фоновая синхронизация), и каждый build гонял
  // .where() + sparkJoyReportRequestContext() по всем отчётам заново.
  // _drafts/_completed заменяются целиком (см. load()/_sortCompleted), так
  // что identical() по источнику — честный ключ инвалидации.
  List<Map<String, dynamic>>? _filteredDraftsMemo;
  Object? _filteredDraftsMemoSource;
  String _filteredDraftsMemoQuery = '';
  List<Map<String, dynamic>>? _filteredCompletedMemo;
  Object? _filteredCompletedMemoSource;
  String _filteredCompletedMemoQuery = '';

  String get tab => _tab;
  bool get loading => _loading;
  String? get loadError => _loadError;
  bool get completedSyncFailed => _completedSyncFailed;
  bool get completedLoading => _completedLoading;
  List<Map<String, dynamic>> get drafts => _drafts;
  List<Map<String, dynamic>> get completed => _completed;
  bool get hasSearch => _search.trim().isNotEmpty;

  List<Map<String, dynamic>> get filteredDrafts {
    if (_search.trim().isEmpty) return _drafts;
    final query = _search.toLowerCase();
    if (_filteredDraftsMemo != null &&
        identical(_filteredDraftsMemoSource, _drafts) &&
        _filteredDraftsMemoQuery == query) {
      return _filteredDraftsMemo!;
    }
    final result = _drafts.where((d) {
      final text = [
        sjRead(d, 'reportName'),
        sjRead(d, 'car'),
        sjRead(d, 'brand'),
        sjRead(d, 'model'),
        sjRead(d, 'vin'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
    _filteredDraftsMemo = result;
    _filteredDraftsMemoSource = _drafts;
    _filteredDraftsMemoQuery = query;
    return result;
  }

  List<Map<String, dynamic>> get filteredCompleted {
    if (_search.trim().isEmpty) return _completed;
    final query = _search.toLowerCase();
    if (_filteredCompletedMemo != null &&
        identical(_filteredCompletedMemoSource, _completed) &&
        _filteredCompletedMemoQuery == query) {
      return _filteredCompletedMemo!;
    }
    final result = _completed.where((r) {
      final text = [
        sjRead(r, 'reportName'),
        sjRead(r, 'reportNumber'),
        sjRead(r, 'report_number'),
        sjRead(r, 'car'),
        sjRead(r, 'make'),
        sjRead(r, 'model'),
        sjRead(r, 'vin'),
        sjRead(r, 'plate'),
        ...sparkJoyReportRequestContext(r).searchTokens,
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
    _filteredCompletedMemo = result;
    _filteredCompletedMemoSource = _completed;
    _filteredCompletedMemoQuery = query;
    return result;
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
    // Refresh the completed list every time the user lands on its tab so
    // they never see stale data. Draft-edit roundtrips already call load()
    // via _openDraft, but bare tab switches used to skip the RPC — users
    // would get different freshness depending on how they arrived.
    if (value == 'completed' && !_completedLoading) {
      unawaited(_refreshCompleted());
    }
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
      // Drafts still live locally (they're work-in-progress). Completed
      // reports are online-only now — no local cache fallback, no stale-
      // while-revalidate. If the network is down the completed list is
      // empty and the user gets a retry hint.
      _drafts = (await SparkJoyStorage.loadDrafts())
          .where(_isVisibleDraft)
          .toList();
      if (_disposed || token != _loadToken) return;
      _completed = const <Map<String, dynamic>>[];
      _loading = false;
      _loadError = null;
      _safeNotify();

      unawaited(_refreshCompleted(token: token));
    } catch (_) {
      if (_disposed || token != _loadToken) return;
      _loading = false;
      _completedLoading = false;
      _loadError = sjT(
        'spark.state.error.reports',
        fallback:
            'Не удалось загрузить отчёты. Проверьте соединение и повторите.',
      );
      _safeNotify();
    }
  }

  /// Re-fetches completed reports from Storage.GetSpecialistReport.
  ///
  /// Stale-while-revalidate: never clears the in-memory list on failure,
  /// and never hides the cached list behind a full-page spinner while
  /// the fetch is in flight. The existing list stays tappable; only the
  /// [_completedLoading] flag flips so the UI can render a small
  /// background indicator if it wants to.
  ///
  /// Called from both the initial [load] and from [setTab] when the user
  /// switches to the completed tab, so navigating directly into that tab
  /// from a cold start yields the same freshness as returning to it after
  /// editing a draft. Pass [token] to piggy-back the outer [load] cycle;
  /// omit it for a standalone refresh that uses a fresh [_loadToken].
  Future<void> _refreshCompleted({int? token}) async {
    final effectiveToken = token ?? ++_loadToken;
    _completedLoading = true;
    _completedSyncFailed = false;
    _safeNotify();
    try {
      final remoteCompleted = await storage_api
          .StorageApi.getAllSpecialistReports(limit: 100, isDraft: false);
      if (_disposed || effectiveToken != _loadToken) return;
      _completed = _sortCompleted(remoteCompleted);
      _completedLoading = false;
      _completedSyncFailed = false;
      _safeNotify();
    } catch (_) {
      if (_disposed || effectiveToken != _loadToken) return;
      // Online-only: no cached fallback. Clear the list so we don't show
      // stale data from a prior run, and surface the failure via
      // [_completedSyncFailed] so the UI can render a retry hint.
      _completed = const <Map<String, dynamic>>[];
      _completedLoading = false;
      _completedSyncFailed = true;
      _safeNotify();
    }
  }

  List<Map<String, dynamic>> _sortCompleted(
    List<Map<String, dynamic>> reports,
  ) {
    final result = reports.map(Map<String, dynamic>.from).toList();
    result.sort((a, b) {
      final ad = sjRead(a, 'updatedAt', fallback: sjRead(a, 'createdAt'));
      final bd = sjRead(b, 'updatedAt', fallback: sjRead(b, 'createdAt'));
      if (ad.isEmpty && bd.isEmpty) return 0;
      if (ad.isEmpty) return 1;
      if (bd.isEmpty) return -1;
      return bd.compareTo(ad);
    });
    return result;
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

  final String label;
  final bool filled;
}

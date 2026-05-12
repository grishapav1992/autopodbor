import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_staff_detail_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_onboarding.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Membership kind used to render the chip on each person card.
/// Kept local to this screen — the rest of the app doesn't care
/// about this distinction.
enum _StaffKind { staff, external, pendingInvite }

class _StaffEntry {
  const _StaffEntry({
    required this.kind,
    required this.data,
    this.assignedDraftCount = 0,
  });

  final _StaffKind kind;

  /// Payload depends on [kind]:
  ///   • staff / external → specialist map from `sparkSpecialists`
  ///   • pendingInvite    → `{id, reportName, vin, staffInviteLink, updatedAt}`
  final Map<String, dynamic> data;

  /// Only meaningful for `staff` / `external` — how many of the
  /// company's drafts are assigned to this person.
  final int assignedDraftCount;
}

class SparkJoyCompanyStaffScreen extends StatefulWidget {
  const SparkJoyCompanyStaffScreen({super.key});

  @override
  State<SparkJoyCompanyStaffScreen> createState() =>
      _SparkJoyCompanyStaffScreenState();
}

class _SparkJoyCompanyStaffScreenState
    extends State<SparkJoyCompanyStaffScreen> {
  bool _loading = true;
  String? _loadError;
  String _search = '';
  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];
  List<String> _hiddenStaffIds = <String>[];
  List<String> _promotedStaffIds = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SparkJoyOnboarding.showOnce(
        context,
        flagKey: UserSimplePreferences.sparkOnbStaffKey,
        titleI18nKey: 'spark.onboarding.staff.title',
        titleFallback: 'Сотрудники компании',
        allowedRoles: const ['company'],
        bullets: const [
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.staff.b1',
            fallback:
                'Здесь видны ваши штатные специалисты, внешние исполнители и приглашения, которые ждут отклика.',
            icon: Icons.groups_2_outlined,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.staff.b2',
            fallback:
                'Чтобы пригласить нового сотрудника — отправьте ему ссылку-приглашение из любого черновика отчёта.',
            icon: Icons.send_to_mobile_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.staff.b3',
            fallback:
                'Внешнего специалиста, который выполнил вашу задачу, можно перевести в штат кнопкой «Добавить в штат».',
            icon: Icons.person_add_alt_1_outlined,
          ),
        ],
      );
    });
  }

  bool _isCompanyDraft(Map<String, dynamic> draft) {
    final companyId = sjRead(draft, 'companyId');
    final businessType = sjRead(draft, 'businessType');
    if (companyId.isNotEmpty) return companyId == kSparkCompanyId;
    return businessType == 'company' || businessType == 'ip';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final drafts = await SparkJoyStorage.loadDrafts();
      final hiddenIds = await SparkJoyStorage.loadHiddenCompanyStaffIds();
      final promotedIds = await SparkJoyStorage.loadPromotedCompanyStaffIds();
      if (!mounted) return;
      setState(() {
        _drafts = drafts.where(_isCompanyDraft).toList();
        _hiddenStaffIds = hiddenIds;
        _promotedStaffIds = promotedIds;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = sjT(
          'spark.state.error.staff',
          fallback:
              'Не удалось загрузить список сотрудников. Проверьте локальные данные и повторите.',
        );
      });
    }
  }

  // ── Category computation ───────────────────────────────────────────

  bool _isStaff(Map<String, dynamic> specialist) {
    final id = sjRead(specialist, 'id');
    final companyId = sjRead(specialist, 'companyId');
    final status = sjRead(specialist, 'status');
    if (status == 'blocked') return false;
    if (_hiddenStaffIds.contains(id)) return false;
    return companyId == kSparkCompanyId || _promotedStaffIds.contains(id);
  }

  /// Indexes drafts by assignee id once so the entry builder can hit
  /// O(1) count + list lookups instead of scanning the full draft list
  /// per specialist. Recomputed whenever the cache is invalidated
  /// (drafts reload, filters change).
  Map<String, List<Map<String, dynamic>>> _buildDraftsByAssignee() {
    final index = <String, List<Map<String, dynamic>>>{};
    for (final d in _drafts) {
      final id = sjRead(d, 'assignedSpecialistId',
          fallback: sjRead(d, 'specialistId'));
      if (id.isEmpty) continue;
      (index[id] ??= <Map<String, dynamic>>[]).add(d);
    }
    return index;
  }

  List<Map<String, dynamic>> _draftsListForId(String id) {
    if (id.isEmpty) return const <Map<String, dynamic>>[];
    return _drafts
        .where((d) =>
            sjRead(d, 'assignedSpecialistId',
                fallback: sjRead(d, 'specialistId')) ==
            id)
        .map(cloneMap)
        .toList();
  }

  List<_StaffEntry> _buildEntries() {
    final draftsByAssignee = _buildDraftsByAssignee();
    final out = <_StaffEntry>[];

    // 1. Staff (native to company + promoted externals).
    for (final s in sparkSpecialists) {
      if (!_isStaff(s)) continue;
      final id = sjRead(s, 'id');
      out.add(_StaffEntry(
        kind: _StaffKind.staff,
        data: cloneMap(s),
        assignedDraftCount: draftsByAssignee[id]?.length ?? 0,
      ));
    }

    // 2. Externals: ids seen in drafts, known in the specialist
    // directory, but not part of the company's staff.
    for (final id in draftsByAssignee.keys) {
      if (_isStaffById(id)) continue;
      final spec = sparkSpecialists.firstWhere(
        (s) => sjRead(s, 'id') == id,
        orElse: () => const <String, dynamic>{},
      );
      if (spec.isEmpty) continue; // unknown user — skip
      out.add(_StaffEntry(
        kind: _StaffKind.external,
        data: cloneMap(spec),
        assignedDraftCount: draftsByAssignee[id]?.length ?? 0,
      ));
    }

    // 3. Pending link invites — drafts with an invite link but no
    // concrete assignee yet. These pre-existed before the 3-mode
    // picker; still show them here so the company can copy/revoke.
    for (final d in _drafts) {
      final link = sjRead(d, 'staffInviteLink').trim();
      if (link.isEmpty) continue;
      final assigned = sjRead(d, 'assignedSpecialistId',
          fallback: sjRead(d, 'specialistId'));
      if (assigned.isNotEmpty) continue;
      out.add(_StaffEntry(
        kind: _StaffKind.pendingInvite,
        data: <String, dynamic>{
          'id': sjRead(d, 'id'),
          'reportName': sjRead(d, 'reportName'),
          'vin': sjRead(d, 'vin'),
          'updatedAt': sjRead(d, 'updatedAt'),
          'staffInviteLink': link,
        },
      ));
    }

    return out;
  }

  bool _isStaffById(String id) {
    if (id.isEmpty) return false;
    final spec = sparkSpecialists.firstWhere(
      (s) => sjRead(s, 'id') == id,
      orElse: () => const <String, dynamic>{},
    );
    if (spec.isEmpty) return false;
    return _isStaff(spec);
  }

  // ── Filtering ──────────────────────────────────────────────────────

  List<_StaffEntry> _filter(List<_StaffEntry> all) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all.where((e) {
      switch (e.kind) {
        case _StaffKind.staff:
        case _StaffKind.external:
          final text = [
            sjRead(e.data, 'name'),
            sjRead(e.data, 'phone'),
            sjRead(e.data, 'specialization'),
          ].join(' ').toLowerCase();
          return text.contains(query);
        case _StaffKind.pendingInvite:
          final text = [
            sjRead(e.data, 'reportName'),
            sjRead(e.data, 'vin'),
            sjRead(e.data, 'staffInviteLink'),
          ].join(' ').toLowerCase();
          return text.contains(query);
      }
    }).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────

  Future<void> _openSpecialist(Map<String, dynamic> specialist) async {
    final id = sjRead(specialist, 'id');
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCompanyStaffDetailScreen(
          specialist: specialist,
          currentDrafts: _draftsListForId(id),
        ),
      ),
    );
    await _load();
  }

  Future<void> _removeSpecialist(Map<String, dynamic> specialist) async {
    final id = sjRead(specialist, 'id');
    final name = sjRead(specialist, 'name', fallback: 'Сотрудник');
    final ok = await _confirm(
      title: 'Удалить сотрудника',
      message:
          'Сотрудник "$name" будет удалён из раздела компании. Назначения в черновиках будут сняты.',
      action: 'Удалить',
    );
    if (ok != true) return;

    // Native staff → hide. Promoted external → demote (restores the
    // "external" badge with all their work history intact).
    final companyId = sjRead(specialist, 'companyId');
    if (companyId == kSparkCompanyId) {
      await SparkJoyStorage.hideCompanyStaffId(id);
    } else {
      await SparkJoyStorage.demotePromotedStaffId(id);
    }
    for (final draft in _draftsListForId(id)) {
      final next = cloneMap(draft);
      next['assignedSpecialistId'] = '';
      next['assignedSpecialistName'] = '';
      next['specialistId'] = '';
      next['specialistName'] = '';
      await SparkJoyStorage.upsertDraft(next);
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Сотрудник "$name" удалён')));
  }

  Future<void> _promoteExternal(Map<String, dynamic> specialist) async {
    final id = sjRead(specialist, 'id');
    final name = sjRead(specialist, 'name', fallback: 'Сотрудник');
    await SparkJoyStorage.promoteExternalStaffId(id);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$name" добавлен в штат')),
    );
  }

  Future<void> _clearPendingInvite(Map<String, dynamic> invite) async {
    final link = sjRead(invite, 'staffInviteLink').trim();
    if (link.isEmpty) return;
    for (final draft in _drafts) {
      if (sjRead(draft, 'staffInviteLink').trim() != link) continue;
      final next = cloneMap(draft);
      next['staffInviteLink'] = '';
      await SparkJoyStorage.upsertDraft(next);
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Приглашение удалено')));
  }

  Future<void> _copyInvite(String link) async {
    if (link.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.xxxl,
            SparkSpace.xxxl,
            SparkSpace.xxxl,
            SparkSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyText(
                text: title,
                size: SparkTextSize.title,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: SparkSpace.md),
              MyText(
                text: message,
                size: SparkTextSize.body,
                color: kGreyColor,
              ),
              const SizedBox(height: SparkSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: SparkSpace.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      child: Text(action),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Rendering ──────────────────────────────────────────────────────

  /// Monochrome kind-chip. We intentionally don't use the palette-
  /// colored `kChip*Bg`/`kChip*Fg` tokens here — the design calls for
  /// a single neutral accent (brand blue at 8% alpha) across all kinds
  /// so the screen reads as one unified list. Differentiation happens
  /// through the leading icon + label.
  Widget _kindChip(_StaffKind kind) {
    final (icon, label) = switch (kind) {
      _StaffKind.staff => (Icons.badge_outlined, 'В штате'),
      _StaffKind.external => (Icons.person_outline, 'Внешний'),
      _StaffKind.pendingInvite => (Icons.link_rounded, 'Приглашение'),
    };
    return SparkChip(
      text: label,
      icon: icon,
      background: kSecondaryColor.withValues(alpha: 0.08),
      color: kSecondaryColor,
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: SparkCard(
        padding: const EdgeInsets.all(SparkSpace.lg),
        radius: SparkRadius.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: SparkSize.iconSm, color: kSecondaryColor),
            const SizedBox(height: SparkSpace.xs),
            MyText(
              text: value,
              size: SparkTextSize.title,
              weight: FontWeight.w700,
            ),
            MyText(
              text: title,
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(_StaffEntry entry) {
    switch (entry.kind) {
      case _StaffKind.pendingInvite:
        return _buildPendingInviteCard(entry.data);
      case _StaffKind.staff:
      case _StaffKind.external:
        return _buildPersonCard(entry);
    }
  }

  Widget _buildPersonCard(_StaffEntry entry) {
    final specialist = entry.data;
    final phone = sjRead(specialist, 'phone');
    final specialization = sjRead(specialist, 'specialization');
    final isExternal = entry.kind == _StaffKind.external;

    return SparkListCard(
      onTap: () => _openSpecialist(specialist),
      child: Column(
        children: [
          Row(
            children: [
              SparkInitialsAvatar(
                name: sjRead(specialist, 'name'),
                size: SparkSize.avatarSm,
                textSize: SparkTextSize.label,
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: sjRead(specialist, 'name'),
                            size: SparkTextSize.bodyLg,
                            weight: FontWeight.w700,
                            maxLines: 1,
                          ),
                        ),
                        _kindChip(entry.kind),
                      ],
                    ),
                    if (specialization.trim().isNotEmpty)
                      MyText(
                        text: specialization,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      ),
                    if (phone.trim().isNotEmpty)
                      MyText(
                        text: phone,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: SparkSize.iconMd,
                color: kGreyColor,
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          Row(
            children: [
              SparkChip(
                text: 'Текущих отчётов: ${entry.assignedDraftCount}',
                background: kSecondaryColor.withValues(alpha: 0.08),
                color: kSecondaryColor,
              ),
              const Spacer(),
              if (isExternal)
                SizedBox(
                  height: SparkSize.actionCompactHeight,
                  child: OutlinedButton.icon(
                    onPressed: () => _promoteExternal(specialist),
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      size: SparkTextSize.title,
                    ),
                    label: const Text('Добавить в штат'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kSecondaryColor,
                      side: const BorderSide(color: kBorderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.lg,
                        vertical: SparkSpace.xs,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.pill),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: SparkSize.actionCompactHeight,
                  child: OutlinedButton.icon(
                    onPressed: () => _removeSpecialist(specialist),
                    icon: const Icon(
                      Icons.person_remove_outlined,
                      size: SparkTextSize.title,
                    ),
                    label: const Text('Удалить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRedColor,
                      side: const BorderSide(color: kRedColor2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.lg,
                        vertical: SparkSpace.xs,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.pill),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInviteCard(Map<String, dynamic> invite) {
    final link = sjRead(invite, 'staffInviteLink').trim();
    final title = sjRead(invite, 'reportName', fallback: 'Черновик отчёта');

    return SparkListCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: SparkSize.avatarSm,
                height: SparkSize.avatarSm,
                decoration: const BoxDecoration(
                  color: kLightGreyColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: SparkSize.iconMd,
                  color: kGreyColor,
                ),
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: title,
                            size: SparkTextSize.bodyLg,
                            weight: FontWeight.w700,
                            maxLines: 1,
                          ),
                        ),
                        _kindChip(_StaffKind.pendingInvite),
                      ],
                    ),
                    if (sjRead(invite, 'vin').isNotEmpty)
                      MyText(
                        text: sjRead(invite, 'vin'),
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.lg,
              vertical: SparkSpace.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SparkRadius.md),
              border: Border.all(color: kBorderColor),
              color: kInputBgColor,
            ),
            child: MyText(
              text: link,
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ),
          const SizedBox(height: SparkSpace.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyInvite(link),
                  icon: const Icon(Icons.copy_rounded, size: SparkSize.iconSm),
                  label: const Text('Копировать ссылку'),
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              SizedBox(
                height: SparkSize.actionHeightMd,
                child: OutlinedButton.icon(
                  onPressed: () => _clearPendingInvite(invite),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: SparkSize.iconSm,
                  ),
                  label: const Text('Удалить'),
                  style: OutlinedButton.styleFrom(foregroundColor: kRedColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Build the full list once per render — the previous shape called
    // `_buildEntries()` four times (3x `_countOf` + `_visibleEntries`),
    // scanning `sparkSpecialists` + all drafts each time.
    final all = _buildEntries();
    var staffCount = 0;
    var externalCount = 0;
    var pendingCount = 0;
    for (final e in all) {
      switch (e.kind) {
        case _StaffKind.staff:
          staffCount++;
          break;
        case _StaffKind.external:
          externalCount++;
          break;
        case _StaffKind.pendingInvite:
          pendingCount++;
          break;
      }
    }
    final entries = _filter(all);

    return SparkScreenList(
      bottomInset: 56,
      children: [
        Row(
          children: [
            _buildStatTile(
              title: 'В штате',
              value: '$staffCount',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(width: SparkSpace.md),
            _buildStatTile(
              title: 'Внешние',
              value: '$externalCount',
              icon: Icons.person_outline,
            ),
            const SizedBox(width: SparkSpace.md),
            _buildStatTile(
              title: 'Приглашения',
              value: '$pendingCount',
              icon: Icons.link_rounded,
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.xl),
        SparkSearchField(
          hint: 'Поиск по имени, телефону или ссылке',
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: SparkSpace.xl),
        if (_loading)
          SparkLoadingState(
            message: sjT(
              'spark.state.loading.staff',
              fallback: 'Загрузка сотрудников...',
            ),
          )
        else if (_loadError != null)
          SparkErrorState(
            title: sjT('spark.state.error.title', fallback: 'Ошибка загрузки'),
            subtitle: _loadError!,
            onRetry: _load,
          )
        else if (entries.isEmpty)
          SparkHintCard(
            text: sjT(
              'spark.empty.noStaff',
              fallback: 'В штате пока нет сотрудников',
            ),
          )
        else
          ...entries.map(_buildEntryCard),
      ],
    );
  }
}

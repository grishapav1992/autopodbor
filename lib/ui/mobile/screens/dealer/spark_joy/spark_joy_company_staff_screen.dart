import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_staff_detail_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
      if (!mounted) return;
      setState(() {
        _drafts = drafts.where(_isCompanyDraft).toList();
        _hiddenStaffIds = hiddenIds;
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

  List<Map<String, dynamic>> get _confirmedStaff {
    final base = sparkSpecialists
        .where((specialist) {
          final id = sjRead(specialist, 'id');
          final companyId = sjRead(specialist, 'companyId');
          final status = sjRead(specialist, 'status');
          return companyId == kSparkCompanyId &&
              status != 'blocked' &&
              !_hiddenStaffIds.contains(id);
        })
        .map(cloneMap)
        .toList();
    if (_search.trim().isEmpty) return base;
    final query = _search.toLowerCase();
    return base.where((specialist) {
      final text = [
        sjRead(specialist, 'name'),
        sjRead(specialist, 'phone'),
        sjRead(specialist, 'specialization'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _pendingInvites {
    final pending = <Map<String, dynamic>>[];
    for (final draft in _drafts) {
      final link = sjRead(draft, 'staffInviteLink').trim();
      if (link.isEmpty) continue;
      final assigned = sjRead(
        draft,
        'assignedSpecialistId',
        fallback: sjRead(draft, 'specialistId'),
      ).trim();
      if (assigned.isNotEmpty) continue;
      pending.add({
        'id': sjRead(draft, 'id'),
        'reportName': sjRead(draft, 'reportName'),
        'vin': sjRead(draft, 'vin'),
        'updatedAt': sjRead(draft, 'updatedAt'),
        'staffInviteLink': link,
      });
    }
    if (_search.trim().isEmpty) return pending;
    final query = _search.toLowerCase();
    return pending.where((invite) {
      final text = [
        sjRead(invite, 'reportName'),
        sjRead(invite, 'vin'),
        sjRead(invite, 'staffInviteLink'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _draftsForSpecialist(String specialistId) {
    final id = specialistId.trim();
    if (id.isEmpty) return const <Map<String, dynamic>>[];
    return _drafts
        .where((draft) {
          final assigned = sjRead(
            draft,
            'assignedSpecialistId',
            fallback: sjRead(draft, 'specialistId'),
          );
          return assigned == id;
        })
        .map(cloneMap)
        .toList();
  }

  Future<void> _openSpecialist(Map<String, dynamic> specialist) async {
    final specialistId = sjRead(specialist, 'id');
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCompanyStaffDetailScreen(
          specialist: specialist,
          currentDrafts: _draftsForSpecialist(specialistId),
        ),
      ),
    );
    await _load();
  }

  Future<void> _removeSpecialist(Map<String, dynamic> specialist) async {
    final specialistId = sjRead(specialist, 'id');
    final specialistName = sjRead(specialist, 'name', fallback: 'Сотрудник');
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
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
                const MyText(
                  text: 'Удалить сотрудника',
                  size: SparkTextSize.title,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: SparkSpace.md),
                MyText(
                  text:
                      'Сотрудник "$specialistName" будет удалён из раздела компании. Назначения в черновиках будут сняты.',
                  size: SparkTextSize.body,
                  color: kGreyColor,
                ),
                const SizedBox(height: SparkSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (shouldRemove != true) return;

    await SparkJoyStorage.hideCompanyStaffId(specialistId);
    for (final draft in _draftsForSpecialist(specialistId)) {
      final next = cloneMap(draft);
      next['assignedSpecialistId'] = '';
      next['assignedSpecialistName'] = '';
      next['specialistId'] = '';
      next['specialistName'] = '';
      await SparkJoyStorage.upsertDraft(next);
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сотрудник "$specialistName" удалён')),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Приглашение удалено')));
  }

  Future<void> _copyInvite(String link) async {
    if (link.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: SparkCard(
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpace.xl,
          vertical: SparkSpace.xl,
        ),
        radius: SparkRadius.md,
        child: Row(
          children: [
            Container(
              width: SparkSize.navStepBadge,
              height: SparkSize.navStepBadge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SparkRadius.sm),
                color: kSecondaryColor.withValues(alpha: 0.08),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: SparkSize.iconSm, color: kSecondaryColor),
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
          ],
        ),
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> invite) {
    final title = sjRead(
      invite,
      'reportName',
      fallback: 'Приглашение к отчёту',
    ).trim();
    final link = sjRead(invite, 'staffInviteLink').trim();

    return SparkListCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: SparkSize.iconSm,
                color: kGreyColor,
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: MyText(
                  text: title,
                  size: SparkTextSize.bodyLg,
                  weight: FontWeight.w700,
                ),
              ),
              SparkChip(
                text: sjT('spark.status.pending', fallback: 'Ожидает'),
                background: kChipInProgressBg,
                color: kChipInProgressFg,
              ),
            ],
          ),
          if (sjRead(invite, 'vin').isNotEmpty)
            MyText(
              text: sjRead(invite, 'vin'),
              size: SparkTextSize.caption,
              color: kGreyColor,
              paddingTop: SparkSpace.xxxs,
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

  Widget _staffCard(Map<String, dynamic> specialist) {
    final specialistId = sjRead(specialist, 'id');
    final assignedCount = _draftsForSpecialist(specialistId).length;
    final phone = sjRead(specialist, 'phone');
    final specialization = sjRead(specialist, 'specialization');

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
                    MyText(
                      text: sjRead(specialist, 'name'),
                      size: SparkTextSize.bodyLg,
                      weight: FontWeight.w700,
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
                text: 'Текущих отчётов: $assignedCount',
                background: kSecondaryColor.withValues(alpha: 0.08),
                color: kSecondaryColor,
              ),
              const Spacer(),
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

  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmedStaff;
    final pending = _pendingInvites;
    return SparkScreenList(
      bottomInset: 56,
      children: [
        // SparkPageHeader removed — the shell's AppBar already shows
        // "Сотрудники" as the tab title. Avoids the duplicate greeting
        // that crowded the profile screen.
        Row(
          children: [
            _buildStatTile(
              title: 'Подтверждённые',
              value: '${confirmed.length}',
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(width: SparkSpace.md),
            _buildStatTile(
              title: 'Ожидают',
              value: '${pending.length}',
              icon: Icons.hourglass_top_rounded,
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.xl),
        SparkSearchField(
          hint: 'Поиск сотрудника или приглашения',
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
        else ...[
          const SparkSectionTitle('Ожидают подтверждения'),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.lg),
              child: SparkHintCard(
                text: sjT(
                  'spark.empty.noPendingInvites',
                  fallback: 'Нет активных приглашений',
                ),
              ),
            )
          else
            ...pending.map(_pendingCard),
          const SizedBox(height: SparkSpace.md),
          const SparkSectionTitle('Подтверждённые сотрудники'),
          if (confirmed.isEmpty)
            SparkHintCard(
              text: sjT(
                'spark.empty.noStaff',
                fallback: 'В штате пока нет сотрудников',
              ),
            )
          else
            ...confirmed.map(_staffCard),
        ],
      ],
    );
  }
}

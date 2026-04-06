import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_staff_detail_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_storage.dart';
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
    setState(() => _loading = true);
    final drafts = await SparkJoyStorage.loadDrafts();
    final hiddenIds = await SparkJoyStorage.loadHiddenCompanyStaffIds();
    if (!mounted) return;
    setState(() {
      _drafts = drafts.where(_isCompanyDraft).toList();
      _hiddenStaffIds = hiddenIds;
      _loading = false;
    });
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
        return AlertDialog(
          title: const Text('Удалить сотрудника'),
          content: Text(
            'Сотрудник "$specialistName" будет удалён из раздела компании. Назначения в черновиках будут сняты.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить'),
            ),
          ],
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

  Widget _pendingCard(Map<String, dynamic> invite) {
    final title = sjRead(
      invite,
      'reportName',
      fallback: 'Приглашение к отчёту',
    ).trim();
    final link = sjRead(invite, 'staffInviteLink').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 16,
                  color: kGreyColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MyText(text: title, size: 13, weight: FontWeight.w700),
                ),
                SparkChip(
                  text: 'Ожидает',
                  background: const Color(0xFFFFF4D8),
                  color: const Color(0xFFA87300),
                ),
              ],
            ),
            if (sjRead(invite, 'vin').isNotEmpty)
              MyText(
                text: sjRead(invite, 'vin'),
                size: 11,
                color: kGreyColor,
                paddingTop: 3,
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderColor),
                color: kInputBgColor,
              ),
              child: MyText(text: link, size: 11, color: kGreyColor),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyInvite(link),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Копировать ссылку'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () => _clearPendingInvite(invite),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Удалить'),
                    style: OutlinedButton.styleFrom(foregroundColor: kRedColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _staffCard(Map<String, dynamic> specialist) {
    final specialistId = sjRead(specialist, 'id');
    final assignedCount = _draftsForSpecialist(specialistId).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => _openSpecialist(specialist),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kSecondaryColor.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: MyText(
                text: sjInitials(sjRead(specialist, 'name')),
                size: 14,
                weight: FontWeight.w700,
                color: kSecondaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: sjRead(specialist, 'name'),
                    size: 13,
                    weight: FontWeight.w700,
                  ),
                  MyText(
                    text: 'Текущих отчётов: $assignedCount',
                    size: 11,
                    color: kGreyColor,
                    paddingTop: 2,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Удалить сотрудника',
              onPressed: () => _removeSpecialist(specialist),
              icon: const Icon(
                Icons.person_remove_outlined,
                size: 18,
                color: kRedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmedStaff;
    final pending = _pendingInvites;
    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        const MyText(text: 'Сотрудники', size: 22, weight: FontWeight.w700),
        const MyText(
          text: 'Штат компании и приглашения',
          size: 12,
          color: kGreyColor,
          paddingTop: 2,
          paddingBottom: 10,
        ),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            hintText: 'Поиск сотрудника или приглашения',
            prefixIcon: const Icon(Icons.search, color: kGreyColor, size: 18),
            filled: true,
            fillColor: kWhiteColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kSecondaryColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 30),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          const MyText(
            text: 'Ожидают подтверждения',
            size: 13,
            weight: FontWeight.w700,
            color: kGreyColor,
            paddingBottom: 8,
          ),
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SparkCard(
                child: MyText(
                  text: 'Нет активных приглашений',
                  size: 12,
                  color: kGreyColor,
                ),
              ),
            )
          else
            ...pending.map(_pendingCard),
          const SizedBox(height: 8),
          const MyText(
            text: 'Подтверждённые сотрудники',
            size: 13,
            weight: FontWeight.w700,
            color: kGreyColor,
            paddingBottom: 8,
          ),
          if (confirmed.isEmpty)
            const SparkCard(
              child: MyText(
                text: 'В штате пока нет сотрудников',
                size: 12,
                color: kGreyColor,
              ),
            )
          else
            ...confirmed.map(_staffCard),
        ],
      ],
    );
  }
}

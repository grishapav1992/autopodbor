import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_staff_detail_screen.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class _StaffEntry {
  const _StaffEntry({required this.data, this.assignedDraftCount = 0});

  final Map<String, dynamic> data;
  final int assignedDraftCount;
}

class _InviteSpecialistByPhoneDialog extends StatefulWidget {
  const _InviteSpecialistByPhoneDialog({required this.onInvite});

  final Future<String> Function(String phone) onInvite;

  @override
  State<_InviteSpecialistByPhoneDialog> createState() =>
      _InviteSpecialistByPhoneDialogState();
}

class _InviteSpecialistByPhoneDialogState
    extends State<_InviteSpecialistByPhoneDialog> {
  final _phoneController = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final name = await widget.onInvite(_phoneController.text);
      if (!mounted) return;
      Navigator.of(context).pop(name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              text: 'Пригласить в штат',
              size: SparkTextSize.title,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            const MyText(
              text:
                  'Введите телефон зарегистрированного специалиста. Он получит приглашение и после принятия появится в штате компании.',
              size: SparkTextSize.body,
              color: kGreyColor,
            ),
            const SizedBox(height: SparkSpace.lg),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [RuPhoneFormatter()],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: sparkInputDecoration(
                '+7___-___-__-__',
                prefixIcon: const Icon(Icons.phone_outlined, color: kGreyColor),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: SparkSpace.md),
              MyText(
                text: _error!,
                size: SparkTextSize.caption,
                color: kRedColor,
              ),
            ],
            const SizedBox(height: SparkSpace.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop<String>(),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(
                            width: SparkSize.spinner,
                            height: SparkSize.spinner,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kWhiteColor,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Отправляем...' : 'Отправить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SparkJoyCompanyStaffScreen extends StatefulWidget {
  const SparkJoyCompanyStaffScreen({super.key});

  @override
  State<SparkJoyCompanyStaffScreen> createState() =>
      _SparkJoyCompanyStaffScreenState();
}

class _SparkJoyCompanyStaffScreenState
    extends State<SparkJoyCompanyStaffScreen> {
  static const int _pageLimit = 100;

  bool _loading = true;
  String? _loadError;
  String _search = '';
  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];
  List<SpecialistItem> _staff = const <SpecialistItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isCompanyDraft(Map<String, dynamic> draft) {
    final businessType = sjRead(draft, 'businessType').toLowerCase();
    final companyId = sjRead(draft, 'companyId');
    return businessType == 'company' ||
        businessType == 'ip' ||
        companyId.isNotEmpty;
  }

  Future<List<SpecialistItem>> _loadCompanyStaff() async {
    var pageNumber = 1;
    var totalPages = 1;
    final staff = <SpecialistItem>[];

    do {
      final page = await storage_api.StorageApi.getCompanySpecialistsPage(
        page: pageNumber,
        limit: _pageLimit,
      );
      staff.addAll(page.specialists);
      totalPages = page.pages <= 0 ? 1 : page.pages;
      pageNumber += 1;
    } while (pageNumber <= totalPages);

    return staff;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        SparkJoyStorage.loadDrafts(),
        _loadCompanyStaff(),
      ]);
      final drafts = (result[0] as List<Map<String, dynamic>>)
          .where(_isCompanyDraft)
          .toList();
      final staff = result[1] as List<SpecialistItem>;
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _staff = staff;
        _loading = false;
      });
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Сессия истекла. Войдите заново.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = sjT(
          'spark.state.error.staff',
          fallback:
              'Не удалось загрузить список сотрудников. Проверьте подключение и повторите.',
        );
      });
    }
  }

  Map<String, dynamic> _specialistMap(SpecialistItem specialist) {
    return <String, dynamic>{
      'id': specialist.id.toString(),
      'name': specialist.displayName,
      'phone': specialist.phone ?? '',
      'email': specialist.email ?? '',
      'city': specialist.city ?? '',
      'urlAvatar': specialist.urlAvatar ?? '',
      'specialization': specialist.description ?? '',
      'rating': specialist.rating,
      'likeUp': specialist.likeUp,
      'likeDown': specialist.likeDown,
    };
  }

  Map<String, List<Map<String, dynamic>>> _buildDraftsByAssignee() {
    final index = <String, List<Map<String, dynamic>>>{};
    for (final d in _drafts) {
      final id = sjRead(
        d,
        'assignedSpecialistId',
        fallback: sjRead(d, 'specialistId'),
      );
      if (id.isEmpty) continue;
      (index[id] ??= <Map<String, dynamic>>[]).add(d);
    }
    return index;
  }

  List<Map<String, dynamic>> _draftsListForId(String id) {
    if (id.isEmpty) return const <Map<String, dynamic>>[];
    return _drafts
        .where(
          (d) =>
              sjRead(
                d,
                'assignedSpecialistId',
                fallback: sjRead(d, 'specialistId'),
              ) ==
              id,
        )
        .map((draft) => Map<String, dynamic>.from(draft))
        .toList();
  }

  List<_StaffEntry> _buildEntries() {
    final draftsByAssignee = _buildDraftsByAssignee();
    return _staff.map((specialist) {
      final id = specialist.id.toString();
      return _StaffEntry(
        data: _specialistMap(specialist),
        assignedDraftCount: draftsByAssignee[id]?.length ?? 0,
      );
    }).toList();
  }

  List<_StaffEntry> _filter(List<_StaffEntry> all) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all.where((entry) {
      final text = [
        sjRead(entry.data, 'name'),
        sjRead(entry.data, 'phone'),
        sjRead(entry.data, 'email'),
        sjRead(entry.data, 'city'),
        sjRead(entry.data, 'specialization'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

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

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return '';
    final tail = digits.substring(digits.length - 10);
    return '+7$tail';
  }

  Future<String> _sendStaffInvitationByPhone(String rawPhone) async {
    final phone = _normalizePhone(rawPhone);
    if (phone.isEmpty) {
      throw Exception('Введите полный номер телефона');
    }

    final page = await storage_api.StorageApi.getSpecialists(
      search: phone,
      limit: 20,
    );
    final phoneTail = phone.replaceAll(RegExp(r'\D'), '').substring(1);
    final exact = page.specialists.where((specialist) {
      final candidate = (specialist.phone ?? '').replaceAll(RegExp(r'\D'), '');
      final candidateTail = candidate.length >= 10
          ? candidate.substring(candidate.length - 10)
          : candidate;
      return candidateTail == phoneTail;
    }).toList();

    if (exact.isEmpty) {
      throw Exception(
        'Специалист с этим номером не найден. Сейчас можно пригласить только зарегистрированного специалиста.',
      );
    }

    final specialist = exact.first;
    if (_staff.any((staff) => staff.id == specialist.id)) {
      throw Exception('${specialist.displayName} уже в штате компании');
    }

    await NotificationApi.sendNotification(
      type: NotificationType.invitation,
      recipientId: specialist.id,
      title: 'Приглашение в штат',
      body:
          'Компания приглашает вас присоединиться к штату специалистов в Autopodbor.',
      payload: <String, dynamic>{
        'source': 'spark_joy_company_staff',
        'phone': phone,
      },
    );
    return specialist.displayName;
  }

  Future<void> _openInviteByPhoneDialog() async {
    final invitedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _InviteSpecialistByPhoneDialog(onInvite: _sendStaffInvitationByPhone),
    );
    if (invitedName == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          invitedName.isEmpty
              ? 'Приглашение отправлено'
              : 'Приглашение отправлено: $invitedName',
        ),
      ),
    );
    await _load();
  }

  Widget _staffChip() {
    return SparkChip(
      text: 'В штате',
      icon: Icons.badge_outlined,
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
            MyText(text: title, size: SparkTextSize.caption, color: kGreyColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard(_StaffEntry entry) {
    final specialist = entry.data;
    final phone = sjRead(specialist, 'phone');
    final email = sjRead(specialist, 'email');
    final city = sjRead(specialist, 'city');
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
                        _staffChip(),
                      ],
                    ),
                    if (specialization.trim().isNotEmpty)
                      MyText(
                        text: specialization,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                        maxLines: 2,
                      ),
                    if (phone.trim().isNotEmpty)
                      MyText(
                        text: phone,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      )
                    else if (email.trim().isNotEmpty)
                      MyText(
                        text: email,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      ),
                    if (city.trim().isNotEmpty)
                      MyText(
                        text: city,
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
          Align(
            alignment: Alignment.centerLeft,
            child: SparkChip(
              text: 'Текущих отчётов: ${entry.assignedDraftCount}',
              background: kSecondaryColor.withValues(alpha: 0.08),
              color: kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _buildEntries();
    final entries = _filter(all);
    final assignedCount = all.fold<int>(
      0,
      (sum, entry) => sum + entry.assignedDraftCount,
    );

    return SparkScreenList(
      bottomInset: 56,
      children: [
        Row(
          children: [
            _buildStatTile(
              title: 'Сотрудников',
              value: '${all.length}',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(width: SparkSpace.md),
            _buildStatTile(
              title: 'Текущих отчётов',
              value: '$assignedCount',
              icon: Icons.description_outlined,
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.lg),
        SizedBox(
          height: SparkSize.actionHeight,
          child: FilledButton.icon(
            onPressed: _loading ? null : _openInviteByPhoneDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Пригласить по телефону'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
            ),
          ),
        ),
        const SizedBox(height: SparkSpace.xl),
        SparkSearchField(
          hint: 'Поиск по имени, телефону или городу',
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
            text: _search.trim().isEmpty
                ? sjT(
                    'spark.empty.noStaff',
                    fallback:
                        'В штате пока нет сотрудников, привязанных к компании',
                  )
                : 'По запросу ничего не найдено',
          )
        else
          ...entries.map(_buildPersonCard),
      ],
    );
  }
}

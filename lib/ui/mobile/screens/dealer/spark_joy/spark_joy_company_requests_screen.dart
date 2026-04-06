import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_new_report_name_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyRequestsScreen extends StatefulWidget {
  const SparkJoyCompanyRequestsScreen({super.key});

  @override
  State<SparkJoyCompanyRequestsScreen> createState() =>
      _SparkJoyCompanyRequestsScreenState();
}

class _SparkJoyCompanyRequestsScreenState
    extends State<SparkJoyCompanyRequestsScreen> {
  bool _loading = true;
  String _search = '';
  String _inviteLink = '';
  bool _inviteBuilding = false;
  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _companyName() {
    final match = sparkCompanies.firstWhere(
      (company) => sjRead(company, 'id') == kSparkCompanyId,
      orElse: () => const {'name': 'Компания'},
    );
    return sjRead(match, 'name', fallback: 'Компания');
  }

  List<Map<String, dynamic>> get _staff {
    return sparkSpecialists
        .where((specialist) {
          final companyId = sjRead(specialist, 'companyId');
          final status = sjRead(specialist, 'status');
          return companyId == kSparkCompanyId && status != 'blocked';
        })
        .map(cloneMap)
        .toList();
  }

  bool _isCompanyDraft(Map<String, dynamic> draft) {
    final companyId = sjRead(draft, 'companyId');
    final businessType = sjRead(draft, 'businessType');
    if (companyId.isNotEmpty) return companyId == kSparkCompanyId;
    return businessType == 'company' || businessType == 'ip';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final allDrafts = await SparkJoyStorage.loadDrafts();
    final companyDrafts = allDrafts.where(_isCompanyDraft).toList();
    if (!mounted) return;
    setState(() {
      _drafts = companyDrafts;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredDrafts {
    if (_search.trim().isEmpty) return _drafts;
    final query = _search.trim().toLowerCase();
    return _drafts.where((draft) {
      final text = [
        sjRead(draft, 'reportName'),
        sjRead(draft, 'car'),
        sjRead(draft, 'vin'),
        sjRead(draft, 'assignedSpecialistName'),
        sjRead(draft, 'specialistName'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Future<void> _openNewRequest() async {
    final setup = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const SparkJoyNewReportNameScreen(companyMode: true),
      ),
    );
    final reportName = sjRead(setup, 'reportName').trim();
    if (!mounted || reportName.isEmpty) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(
          initialReportName: reportName,
          initialAssignedSpecialistId: sjRead(setup, 'assignedSpecialistId'),
          initialAssignedSpecialistName: sjRead(
            setup,
            'assignedSpecialistName',
          ),
          initialStaffInviteLink: sjRead(setup, 'staffInviteLink'),
        ),
      ),
    );
    await _load();
  }

  Future<void> _openDraft(Map<String, dynamic> draft) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(draft: draft),
      ),
    );
    await _load();
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> _saveAssignee({
    required Map<String, dynamic> draft,
    required String specialistId,
    required String specialistName,
  }) async {
    final next = cloneMap(draft);
    next['companyId'] = kSparkCompanyId;
    next['companyName'] = _companyName();
    next['businessType'] = 'company';
    next['assignedSpecialistId'] = specialistId;
    next['assignedSpecialistName'] = specialistName;
    next['specialistId'] = specialistId;
    next['specialistName'] = specialistName;
    next['updatedAt'] = _dateLabel(DateTime.now());
    await SparkJoyStorage.upsertDraft(next);
    await _load();
  }

  Future<void> _chooseAssignee(Map<String, dynamic> draft) async {
    final staff = _staff;
    if (staff.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет сотрудников в штате компании')),
      );
      return;
    }

    String selectedId = sjRead(
      draft,
      'assignedSpecialistId',
      fallback: sjRead(draft, 'specialistId'),
    );
    String selectedName = sjRead(
      draft,
      'assignedSpecialistName',
      fallback: sjRead(draft, 'specialistName'),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MyText(
                      text: 'Назначить сотрудника',
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedId.isEmpty ? '' : selectedId,
                      decoration: InputDecoration(
                        hintText: 'Выберите сотрудника',
                        filled: true,
                        fillColor: kWhiteColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
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
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Без исполнителя'),
                        ),
                        ...staff.map((specialist) {
                          final id = sjRead(specialist, 'id');
                          final name = sjRead(specialist, 'name');
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        final nextId = value ?? '';
                        final specialist = staff.firstWhere(
                          (item) => sjRead(item, 'id') == nextId,
                          orElse: () => const {},
                        );
                        setModalState(() {
                          selectedId = nextId;
                          selectedName = sjRead(specialist, 'name');
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _saveAssignee(
                                draft: draft,
                                specialistId: selectedId,
                                specialistName: selectedName,
                              );
                            },
                            child: const Text('Сохранить'),
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
      },
    );
  }

  String _buildInviteToken() {
    final source = '${DateTime.now().microsecondsSinceEpoch}|$kSparkCompanyId';
    final encoded = base64Url.encode(utf8.encode(source)).replaceAll('=', '');
    if (encoded.length <= 18) return encoded;
    return encoded.substring(0, 18);
  }

  Future<void> _buildInviteLink() async {
    if (_inviteBuilding) return;
    setState(() => _inviteBuilding = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final link = Uri.https('app.autocheck.local', '/invite/staff', {
      'companyId': kSparkCompanyId,
      'token': _buildInviteToken(),
      'source': 'company_requests',
    }).toString();
    if (!mounted) return;
    setState(() {
      _inviteLink = link;
      _inviteBuilding = false;
    });
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка приглашения скопирована')),
    );
  }

  Future<void> _copyInviteLink() async {
    final link = _inviteLink.trim();
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  Widget _inviteCard() {
    final hasLink = _inviteLink.trim().isNotEmpty;
    return SparkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_add_outlined, size: 16, color: kSecondaryColor),
              SizedBox(width: 6),
              MyText(
                text: 'Пригласить сотрудника в штат',
                size: 13,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 6),
          MyText(
            text: 'Ссылка подходит и для уже зарегистрированных специалистов.',
            size: 11,
            color: kGreyColor,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _inviteBuilding ? null : _buildInviteLink,
                  icon: Icon(
                    hasLink ? Icons.refresh_rounded : Icons.link_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _inviteBuilding
                        ? 'Формируем...'
                        : hasLink
                        ? 'Обновить ссылку'
                        : 'Сформировать ссылку',
                  ),
                ),
              ),
              if (hasLink) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: _copyInviteLink,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Копия'),
                  ),
                ),
              ],
            ],
          ),
          if (hasLink) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kInputBgColor,
                border: Border.all(color: kBorderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: MyText(text: _inviteLink, size: 11, color: kGreyColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _draftCard(Map<String, dynamic> draft) {
    final title = [
      sjRead(draft, 'reportName'),
      sjRead(draft, 'car'),
      sjRead(draft, 'vin'),
    ].firstWhere((item) => item.trim().isNotEmpty, orElse: () => 'Заявка');
    final assignedName = sjRead(
      draft,
      'assignedSpecialistName',
      fallback: sjRead(draft, 'specialistName'),
    );
    final step = int.tryParse(sjRead(draft, 'currentStep')) ?? 1;
    final total = int.tryParse(sjRead(draft, 'totalSteps')) ?? 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => _openDraft(draft),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(text: title, size: 13, weight: FontWeight.w700),
                      if (sjRead(draft, 'vin').isNotEmpty)
                        MyText(
                          text: sjRead(draft, 'vin'),
                          size: 11,
                          color: kGreyColor,
                          paddingTop: 2,
                        ),
                      MyText(
                        text: 'Шаг $step из $total',
                        size: 11,
                        color: kGreyColor,
                        paddingTop: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MyText(
                  text: sjRead(draft, 'updatedAt'),
                  size: 10,
                  color: kGreyColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SparkChip(
                    text: assignedName.isEmpty
                        ? 'Исполнитель не назначен'
                        : 'Исполнитель: $assignedName',
                    background: assignedName.isEmpty
                        ? kLightGreyColor
                        : kSecondaryColor.withValues(alpha: 0.1),
                    color: assignedName.isEmpty ? kGreyColor : kSecondaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _chooseAssignee(draft),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: Text(
                      assignedName.isEmpty
                          ? 'Назначить сотрудника'
                          : 'Изменить исполнителя',
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
    final drafts = _filteredDrafts;
    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        const MyText(
          text: 'Заявки компании',
          size: 22,
          weight: FontWeight.w700,
        ),
        MyText(
          text: _companyName(),
          size: 12,
          color: kGreyColor,
          paddingTop: 2,
          paddingBottom: 10,
        ),
        MyButton(
          buttonText: 'Создать заявку',
          onTap: _openNewRequest,
          customChild: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: kWhiteColor, size: 20),
              SizedBox(width: 6),
              MyText(
                text: 'Создать заявку',
                size: 14,
                weight: FontWeight.w700,
                color: kWhiteColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _inviteCard(),
        const SizedBox(height: 10),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            hintText: 'Поиск по заявкам',
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
        else if (drafts.isEmpty)
          const _SparkCompanyEmptyState()
        else
          ...drafts.map(_draftCard),
      ],
    );
  }
}

class _SparkCompanyEmptyState extends StatelessWidget {
  const _SparkCompanyEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 34, color: kGreyColor),
          SizedBox(height: 8),
          MyText(text: 'Заявок пока нет', size: 14, weight: FontWeight.w700),
          SizedBox(height: 4),
          MyText(
            text: 'Создайте первую заявку и назначьте сотрудника',
            size: 11,
            color: kGreyColor,
          ),
        ],
      ),
    );
  }
}

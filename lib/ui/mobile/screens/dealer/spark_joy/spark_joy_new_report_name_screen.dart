import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';

import 'spark_joy_data.dart';
import 'spark_joy_create_report_screen.dart';
import 'spark_joy_ui.dart';

class SparkJoyNewReportNameScreen extends StatefulWidget {
  const SparkJoyNewReportNameScreen({super.key, this.companyMode = false});

  final bool companyMode;

  @override
  State<SparkJoyNewReportNameScreen> createState() =>
      _SparkJoyNewReportNameScreenState();
}

class _SparkJoyNewReportNameScreenState
    extends State<SparkJoyNewReportNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  String _assignedSpecialistId = '';
  String _assignedSpecialistName = '';
  String _inviteLink = '';
  bool _inviteBuilding = false;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buildInviteToken() {
    final source =
        '${DateTime.now().microsecondsSinceEpoch}|${_controller.text.trim()}';
    final encoded = base64Url.encode(utf8.encode(source)).replaceAll('=', '');
    if (encoded.length <= 18) return encoded;
    return encoded.substring(0, 18);
  }

  Future<void> _generateInviteLink() async {
    if (_inviteBuilding) return;
    setState(() => _inviteBuilding = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final link = Uri.https('app.autocheck.local', '/invite/staff', {
      'companyId': kSparkCompanyId,
      'token': _buildInviteToken(),
      'source': 'new_report',
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

  Future<void> _create() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final name = _controller.text.trim();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(
          initialReportName: name,
          initialAssignedSpecialistId: _assignedSpecialistId.trim(),
          initialAssignedSpecialistName: _assignedSpecialistName.trim(),
          initialStaffInviteLink: _inviteLink.trim(),
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(created == true);
  }

  @override
  Widget build(BuildContext context) {
    final staff = _staff;
    final enabled = _controller.text.trim().isNotEmpty;
    return SparkPageScaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Новый отчёт')),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SparkCard(
                padding: const EdgeInsets.all(SparkSpace.xl),
                radius: SparkRadius.md,
                backgroundColor: kWhiteColor,
                child: Row(
                  children: [
                    Container(
                      width: SparkSize.navStepBadge,
                      height: SparkSize.navStepBadge,
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(SparkRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.description_outlined,
                        color: kSecondaryColor,
                        size: SparkSize.iconSm,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: MyText(
                        text: widget.companyMode
                            ? 'Создайте отчёт и назначьте исполнителя'
                            : 'Введите название и начните осмотр',
                        size: SparkTextSize.body,
                        color: kGreyColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SparkSpace.xl),
              SparkCard(
                padding: const EdgeInsets.fromLTRB(
                  SparkSpace.xl,
                  SparkSpace.xl,
                  SparkSpace.xl,
                  SparkSpace.md,
                ),
                radius: SparkRadius.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MyText(
                      text: 'Название отчёта',
                      size: SparkTextSize.title,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: SparkSpace.md),
                    TextFormField(
                      controller: _controller,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => unawaited(_create()),
                      validator: (value) {
                        final normalized = (value ?? '').trim();
                        if (normalized.isEmpty) {
                          return 'Введите название отчёта';
                        }
                        return null;
                      },
                      decoration: sparkInputDecoration(
                        'Например: Toyota Camry для клиента',
                      ),
                    ),
                    const SizedBox(height: SparkSpace.sm),
                    const MyText(
                      text: 'Название поможет быстро найти отчёт в списке',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
              if (widget.companyMode) ...[
                const SizedBox(height: SparkSpace.xl),
                SparkCard(
                  padding: const EdgeInsets.all(SparkSpace.xl),
                  radius: SparkRadius.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: 'Назначить сотрудника',
                        size: SparkTextSize.title,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: SparkSpace.md),
                      DropdownButtonFormField<String>(
                        initialValue: _assignedSpecialistId.isEmpty
                            ? ''
                            : _assignedSpecialistId,
                        decoration: sparkInputDecoration('Выберите сотрудника'),
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
                          final id = value ?? '';
                          final specialist = staff.firstWhere(
                            (item) => sjRead(item, 'id') == id,
                            orElse: () => const {},
                          );
                          setState(() {
                            _assignedSpecialistId = id;
                            _assignedSpecialistName = sjRead(
                              specialist,
                              'name',
                            );
                          });
                        },
                      ),
                      const SizedBox(height: SparkSpace.xl),
                      const MyText(
                        text: 'Приглашение сотрудника',
                        size: SparkTextSize.label,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: SparkSpace.sm),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _inviteBuilding
                                  ? null
                                  : _generateInviteLink,
                              icon: Icon(
                                _inviteLink.trim().isNotEmpty
                                    ? Icons.refresh_rounded
                                    : Icons.link_rounded,
                                size: SparkSize.iconSm,
                              ),
                              label: Text(
                                _inviteBuilding
                                    ? 'Формируем...'
                                    : _inviteLink.trim().isNotEmpty
                                    ? 'Обновить ссылку'
                                    : 'Сформировать ссылку',
                              ),
                            ),
                          ),
                          if (_inviteLink.trim().isNotEmpty) ...[
                            const SizedBox(width: SparkSpace.sm),
                            SizedBox(
                              height: SparkSize.actionHeightMd,
                              child: OutlinedButton.icon(
                                onPressed: _copyInviteLink,
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: SparkSize.iconSm,
                                ),
                                label: const Text('Копия'),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_inviteLink.trim().isNotEmpty) ...[
                        const SizedBox(height: SparkSpace.sm),
                        SparkCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SparkSpace.lg,
                            vertical: SparkSpace.md,
                          ),
                          child: MyText(
                            text: _inviteLink,
                            size: SparkTextSize.caption,
                            color: kGreyColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: SparkSpace.section),
              IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.55,
                  child: SparkPrimaryActionButton(
                    label: 'Создать отчёт',
                    showIcon: false,
                    onTap: () => unawaited(_create()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

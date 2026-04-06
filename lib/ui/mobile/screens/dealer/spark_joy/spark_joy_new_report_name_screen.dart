import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
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

  void _create() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(<String, dynamic>{
      'reportName': name,
      'assignedSpecialistId': _assignedSpecialistId.trim(),
      'assignedSpecialistName': _assignedSpecialistName.trim(),
      'staffInviteLink': _inviteLink.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = _staff;
    final enabled = _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Новый отчёт')),
      body: ListView(
        padding: AppSizes.DEFAULT,
        children: [
          const MyText(
            text: 'Название отчёта',
            size: 14,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              hintText: 'Например: Toyota Camry для клиента',
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
          ),
          const SizedBox(height: 6),
          const MyText(
            text: 'Название поможет быстро найти отчёт в списке',
            size: 11,
            color: kGreyColor,
          ),
          if (widget.companyMode) ...[
            const SizedBox(height: 16),
            const MyText(
              text: 'Назначить сотрудника',
              size: 14,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _assignedSpecialistId.isEmpty
                  ? ''
                  : _assignedSpecialistId,
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
                  return DropdownMenuItem<String>(value: id, child: Text(name));
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
                  _assignedSpecialistName = sjRead(specialist, 'name');
                });
              },
            ),
            const SizedBox(height: 16),
            const MyText(
              text: 'Или пригласить сотрудника по ссылке',
              size: 14,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _inviteBuilding ? null : _generateInviteLink,
                    icon: Icon(
                      _inviteLink.trim().isNotEmpty
                          ? Icons.refresh_rounded
                          : Icons.link_rounded,
                      size: 16,
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
            if (_inviteLink.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kWhiteColor,
                  border: Border.all(color: kBorderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MyText(text: _inviteLink, size: 11, color: kGreyColor),
              ),
            ],
          ],
          const SizedBox(height: 18),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.55,
              child: MyButton(buttonText: 'Создать отчёт', onTap: _create),
            ),
          ),
        ],
      ),
    );
  }
}

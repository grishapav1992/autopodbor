import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';

class SparkJoySpecialistInviteScreen extends StatefulWidget {
  const SparkJoySpecialistInviteScreen({super.key});

  @override
  State<SparkJoySpecialistInviteScreen> createState() =>
      _SparkJoySpecialistInviteScreenState();
}

class _SparkJoySpecialistInviteScreenState
    extends State<SparkJoySpecialistInviteScreen> {
  String? _inviteType;
  String _generatedLink = '';
  bool _copied = false;

  String _buildLink(String type) {
    return 'https://autocheck.app/join/$kSparkCompanyId/$type';
  }

  void _generate(String type) {
    setState(() {
      _inviteType = type;
      _generatedLink = _buildLink(type);
      _copied = false;
    });
  }

  Future<void> _copy() async {
    if (_generatedLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _generatedLink));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пригласить специалиста')),
      body: ListView(
        padding: AppSizes.DEFAULT.copyWith(bottom: 24),
        children: [
          if (_inviteType == null) ...[
            const MyText(
              text: 'Выберите тип приглашения:',
              size: 13,
              color: kGreyColor,
            ),
            const SizedBox(height: 10),
            SparkInviteTypeCard(
              title: 'В штат',
              subtitle: 'Постоянное сотрудничество с компанией',
              onTap: () => _generate('staff'),
            ),
            const SizedBox(height: 10),
            SparkInviteTypeCard(
              title: 'На разовый осмотр',
              subtitle: 'Одноразовое приглашение на конкретный осмотр',
              onTap: () => _generate('one_time'),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.link, color: kSecondaryColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: MyText(
                    text: _inviteType == 'staff'
                        ? 'Приглашение в штат'
                        : 'Приглашение на разовый осмотр',
                    size: 13,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const MyText(
              text:
                  'Скопируйте ссылку и отправьте специалисту в мессенджере. Ссылка постоянная и привязана к вашей компании.',
              size: 11,
              color: kGreyColor,
              lineHeight: 1.35,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: _generatedLink),
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kLightGreyColor,
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
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  width: 42,
                  child: OutlinedButton(
                    onPressed: _copy,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Icon(
                      _copied ? Icons.check : Icons.copy,
                      size: 18,
                      color: _copied ? kGreenColor : kSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: MyBorderButton(
                buttonText: 'Выбрать другой тип',
                textSize: 12,
                onTap: () {
                  setState(() {
                    _inviteType = null;
                    _generatedLink = '';
                    _copied = false;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SparkInviteTypeCard extends StatelessWidget {
  const SparkInviteTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(text: title, size: 13, weight: FontWeight.w700),
              const SizedBox(height: 2),
              MyText(text: subtitle, size: 11, color: kGreyColor),
            ],
          ),
        ),
      ),
    );
  }
}

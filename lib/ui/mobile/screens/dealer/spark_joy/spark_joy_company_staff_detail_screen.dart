import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyStaffDetailScreen extends StatelessWidget {
  const SparkJoyCompanyStaffDetailScreen({
    super.key,
    required this.specialist,
    required this.currentDrafts,
  });

  final Map<String, dynamic> specialist;
  final List<Map<String, dynamic>> currentDrafts;

  Future<void> _openDraft(
    BuildContext context,
    Map<String, dynamic> draft,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(draft: draft),
      ),
    );
  }

  Widget _draftCard(BuildContext context, Map<String, dynamic> draft) {
    final title = [
      sjRead(draft, 'reportName'),
      sjRead(draft, 'car'),
      sjRead(draft, 'vin'),
    ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => 'Отчёт');
    final step = int.tryParse(sjRead(draft, 'currentStep')) ?? 1;
    final total = int.tryParse(sjRead(draft, 'totalSteps')) ?? 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => _openDraft(context, draft),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.description_outlined, size: 16, color: kGreyColor),
            const SizedBox(width: 8),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffName = sjRead(specialist, 'name', fallback: 'Сотрудник');
    final specialization = sjRead(specialist, 'specialization');

    return Scaffold(
      appBar: AppBar(title: Text(staffName)),
      body: ListView(
        padding: AppSizes.DEFAULT.copyWith(bottom: 24),
        children: [
          SparkCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kSecondaryColor.withValues(alpha: 0.1),
                  ),
                  alignment: Alignment.center,
                  child: MyText(
                    text: sjInitials(staffName),
                    size: 16,
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
                        text: staffName,
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                      if (specialization.isNotEmpty)
                        MyText(
                          text: specialization,
                          size: 11,
                          color: kGreyColor,
                          paddingTop: 2,
                        ),
                    ],
                  ),
                ),
                SparkChip(
                  text: 'Подтверждён',
                  background: const Color(0xFFE8F6EC),
                  color: const Color(0xFF1C7C3D),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const MyText(
            text: 'Текущие отчёты',
            size: 14,
            weight: FontWeight.w700,
            paddingBottom: 8,
          ),
          if (currentDrafts.isEmpty)
            const SparkCard(
              child: MyText(
                text: 'Назначенных отчётов пока нет',
                size: 12,
                color: kGreyColor,
              ),
            )
          else
            ...currentDrafts.map((draft) => _draftCard(context, draft)),
        ],
      ),
    );
  }
}

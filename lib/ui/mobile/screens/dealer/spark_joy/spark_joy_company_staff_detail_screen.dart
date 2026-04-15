import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_tokens.dart';
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

    return SparkListCard(
      onTap: () => _openDraft(context, draft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.description_outlined,
            size: SparkSize.iconSm,
            color: kGreyColor,
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: title,
                  size: SparkTextSize.bodyLg,
                  weight: FontWeight.w700,
                ),
                if (sjRead(draft, 'vin').isNotEmpty)
                  MyText(
                    text: sjRead(draft, 'vin'),
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                  ),
                const SizedBox(height: SparkSpace.xs),
                SparkChip(
                  text: 'Шаг $step/$total',
                  background: kSecondaryColor.withValues(alpha: 0.1),
                  color: kSecondaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MyText(
                text: sjFormatDate(sjRead(draft, 'updatedAt')),
                size: SparkTextSize.chip,
                color: kGreyColor,
              ),
              const SizedBox(height: SparkSpace.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: SparkSize.iconMd,
                color: kGreyColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffName = sjRead(specialist, 'name', fallback: 'Сотрудник');
    final specialization = sjRead(specialist, 'specialization');
    final phone = sjRead(specialist, 'phone');
    final city = sjRead(specialist, 'city');

    return SparkPageScaffold(
      appBar: AppBar(centerTitle: false, title: Text(staffName)),
      bottomInset: SparkSpace.xl,
      children: [
        SparkPageHeader(
          title: 'Профиль сотрудника',
          subtitle: specialization.isEmpty
              ? 'Данные сотрудника и назначенные отчёты'
              : specialization,
        ),
        SparkCard(
          child: Row(
            children: [
              SparkInitialsAvatar(
                name: staffName,
                size: SparkSize.inputHeight,
                textSize: SparkTextSize.title,
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: staffName,
                      size: SparkTextSize.label,
                      weight: FontWeight.w700,
                    ),
                    if (specialization.isNotEmpty)
                      MyText(
                        text: specialization,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                  ],
                ),
              ),
              SparkChip(
                text: sjT('spark.status.confirmed', fallback: 'Подтверждён'),
                background: const Color(0xFFE8F6EC),
                color: const Color(0xFF1C7C3D),
              ),
            ],
          ),
        ),
        if (phone.isNotEmpty || city.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.lg),
          SparkCard(
            child: Column(
              children: [
                if (phone.isNotEmpty)
                  SparkInfoRow(label: 'Телефон', value: phone),
                if (city.isNotEmpty) SparkInfoRow(label: 'Город', value: city),
              ],
            ),
          ),
        ],
        const SizedBox(height: SparkSpace.xl),
        const SparkSectionTitle('Текущие отчёты'),
        if (currentDrafts.isEmpty)
          SparkHintCard(
            text: sjT(
              'spark.empty.noAssignedReports',
              fallback: 'Назначенных отчётов пока нет',
            ),
          )
        else
          ...currentDrafts.map((draft) => _draftCard(context, draft)),
      ],
    );
  }
}

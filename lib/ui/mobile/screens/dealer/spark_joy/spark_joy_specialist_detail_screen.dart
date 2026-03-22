import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoySpecialistDetailScreen extends StatelessWidget {
  const SparkJoySpecialistDetailScreen({
    super.key,
    required this.specialist,
    required this.onCreateAssignment,
    required this.onOpenReport,
  });

  final Map<String, dynamic> specialist;
  final VoidCallback onCreateAssignment;
  final ValueChanged<Map<String, dynamic>> onOpenReport;

  List<Map<String, dynamic>> _assignments() {
    return sparkAssignments
        .where(
          (a) =>
              sjRead(a, 'specialistId') == sjRead(specialist, 'id') &&
              sjRead(a, 'companyId') == kSparkCompanyId,
        )
        .map(cloneMap)
        .toList();
  }

  List<Map<String, dynamic>> _reports() {
    return sparkPlatformReports
        .where(
          (r) =>
              sjRead(r, 'specialistId') == sjRead(specialist, 'id') &&
              sjRead(r, 'companyId') == kSparkCompanyId,
        )
        .map(cloneMap)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final assignments = _assignments();
    final reports = _reports();

    return Scaffold(
      appBar: AppBar(
        title: Text(sjRead(specialist, 'name', fallback: 'Специалист')),
      ),
      body: ListView(
        padding: AppSizes.DEFAULT.copyWith(bottom: 24),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kSecondaryColor.withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: MyText(
                  text: sjInitials(sjRead(specialist, 'name')),
                  size: 18,
                  color: kSecondaryColor,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SparkChip(
                    text:
                        sparkFormatLabels[sjRead(specialist, 'format')] ??
                        'Спец',
                    background: kSecondaryColor.withValues(alpha: 0.08),
                    color: kSecondaryColor,
                  ),
                  const SizedBox(height: 4),
                  MyText(
                    text: sjRead(specialist, 'status') == 'active'
                        ? 'Активен'
                        : 'Неактивен',
                    size: 11,
                    color: kGreyColor,
                  ),
                ],
              ),
            ],
          ),
          const SparkSectionTitle('Информация', top: 14),
          SparkCard(
            child: Column(
              children: [
                SparkInfoRow(
                  label: 'Город',
                  value: sjRead(specialist, 'city', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Телефон',
                  value: sjRead(specialist, 'phone', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Email',
                  value: sjRead(specialist, 'email', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Специализация',
                  value: sjRead(specialist, 'specialization', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Опыт',
                  value: sjRead(specialist, 'experience', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Рейтинг',
                  value: '⭐ ${sjRead(specialist, 'rating', fallback: '-')}',
                ),
                SparkInfoRow(
                  label: 'Отчётов',
                  value: sjRead(specialist, 'reportCount', fallback: '0'),
                ),
                SparkInfoRow(
                  label: 'Активных осмотров',
                  value: sjRead(specialist, 'activeInspections', fallback: '0'),
                ),
                SparkInfoRow(
                  label: 'Последняя активность',
                  value: sjRead(specialist, 'lastActive', fallback: '-'),
                ),
              ],
            ),
          ),
          const SparkSectionTitle('Связанные осмотры', top: 14),
          if (assignments.isEmpty)
            const MyText(text: 'Нет осмотров', size: 12, color: kGreyColor)
          else
            ...assignments.map((assignment) {
              final status = sjRead(assignment, 'status');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SparkCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              text: sjRead(assignment, 'title'),
                              size: 12,
                              weight: FontWeight.w700,
                            ),
                            MyText(
                              text:
                                  sparkAssignmentStatusLabels[status] ?? status,
                              size: 10,
                              color: kGreyColor,
                            ),
                          ],
                        ),
                      ),
                      SparkChip(
                        text: sparkAssignmentStatusLabels[status] ?? status,
                        background: sparkAssignmentChipBackground(status),
                        color: sparkAssignmentChipColor(status),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SparkSectionTitle('Отчёты', top: 14),
          if (reports.isEmpty)
            const MyText(text: 'Нет отчётов', size: 12, color: kGreyColor)
          else
            ...reports.map((report) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SparkCard(
                  onTap: () {
                    final vehicle = sjRead(report, 'vehicle');
                    onOpenReport({
                      'id': sjRead(report, 'id'),
                      'reportName': vehicle,
                      'car': vehicle,
                      'vin': sjRead(report, 'vin'),
                      'createdAt': sjRead(report, 'createdAt'),
                      'score':
                          '${((double.tryParse(sjRead(report, 'score')) ?? 0) * 10).round()}/100',
                      'verdict': 'with_reservations',
                      'sections': [
                        {
                          'title': 'Автомобиль',
                          'status': 'ok',
                          'details': [
                            {
                              'label': 'Модель',
                              'value': vehicle,
                              'severity': 'ok',
                            },
                            {
                              'label': 'VIN',
                              'value': sjRead(report, 'vin'),
                              'severity': 'ok',
                            },
                          ],
                        },
                      ],
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: sjRead(report, 'vehicle'),
                        size: 12,
                        weight: FontWeight.w700,
                      ),
                      MyText(
                        text:
                            '${sjRead(report, 'createdAt')} • ${sjRead(report, 'status') == 'completed' ? 'Готов' : 'Черновик'}',
                        size: 10,
                        color: kGreyColor,
                        paddingTop: 2,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: MyButton(
              buttonText: 'Назначить на осмотр',
              textSize: 12,
              onTap: onCreateAssignment,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Деактивация сотрудничества')),
                );
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: kRedColor,
                side: const BorderSide(color: kRedColor2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Деактивировать'),
            ),
          ),
        ],
      ),
    );
  }
}

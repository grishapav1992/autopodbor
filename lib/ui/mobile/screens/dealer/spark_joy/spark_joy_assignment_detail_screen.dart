import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoyAssignmentDetailScreen extends StatelessWidget {
  const SparkJoyAssignmentDetailScreen({
    super.key,
    required this.assignment,
    required this.onEdit,
    required this.onOpenReport,
  });

  final Map<String, dynamic> assignment;
  final VoidCallback onEdit;
  final VoidCallback onOpenReport;

  bool get _canModify {
    final status = sjRead(assignment, 'status');
    return status == 'new' || status == 'assigned';
  }

  @override
  Widget build(BuildContext context) {
    final status = sjRead(assignment, 'status');

    return Scaffold(
      appBar: AppBar(
        title: Text(sjRead(assignment, 'title', fallback: 'Заявка')),
      ),
      body: ListView(
        padding: AppSizes.DEFAULT.copyWith(bottom: 24),
        children: [
          SparkCard(
            child: Column(
              children: [
                SparkInfoRow(
                  label: 'Автомобиль',
                  value: sjRead(assignment, 'vehicle', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'VIN',
                  value: sjRead(assignment, 'vin', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Дата',
                  value: sjRead(assignment, 'date', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Специалист',
                  value: sjRead(
                    assignment,
                    'specialistName',
                    fallback: 'Не назначен',
                  ),
                ),
                SparkInfoRow(
                  label: 'Телефон',
                  value: sjRead(assignment, 'contactPhone', fallback: '-'),
                ),
              ],
            ),
          ),
          if (sjRead(assignment, 'listingUrl').isNotEmpty) ...[
            const SparkSectionTitle('Ссылка', top: 14),
            SparkCard(
              child: SparkInfoRow(
                label: 'Объявление',
                value: sjRead(assignment, 'listingUrl'),
              ),
            ),
          ],
          if (sjRead(assignment, 'comment').isNotEmpty) ...[
            const SparkSectionTitle('Комментарий', top: 14),
            SparkCard(
              child: Text(
                sjRead(assignment, 'comment'),
                style: const TextStyle(
                  fontSize: 12,
                  color: kGreyColor,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SparkSectionTitle('Статус', top: 14),
          SparkCard(
            child: Row(
              children: [
                SparkChip(
                  text: sparkAssignmentStatusLabels[status] ?? status,
                  background: sparkAssignmentChipBackground(status),
                  color: sparkAssignmentChipColor(status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (status == 'completed' &&
              sjRead(assignment, 'reportId').isNotEmpty)
            SizedBox(
              height: 40,
              child: MyButton(
                buttonText: 'Открыть отчёт',
                textSize: 12,
                onTap: onOpenReport,
              ),
            ),
          if (_canModify) ...[
            SizedBox(
              height: 40,
              child: MyBorderButton(
                buttonText: 'Редактировать',
                textSize: 12,
                onTap: onEdit,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Удалить заявку?'),
                        content: Text(
                          'Заявка на осмотр "${sjRead(assignment, 'vehicle')}" будет удалена. Это действие нельзя отменить.',
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

                  if (confirmed != true || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заявка удалена')),
                  );
                  Navigator.of(context).pop(true);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRedColor,
                  side: const BorderSide(color: kRedColor2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Удалить заявку'),
              ),
            ),
          ],
          if (status == 'in_progress')
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Заявка в работе у специалиста. Только специалист может отменить осмотр.',
                style: TextStyle(fontSize: 12, color: kGreyColor),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

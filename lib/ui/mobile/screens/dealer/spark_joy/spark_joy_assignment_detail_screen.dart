import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_tokens.dart';
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

    return SparkPageScaffold(
      appBar: AppBar(
        title: Text(sjRead(assignment, 'title', fallback: 'Заявка')),
      ),
      bottomInset: SparkSpace.xl,
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
          const SparkSectionTitle('Ссылка', top: SparkSpace.xxl),
          SparkCard(
            child: SparkInfoRow(
              label: 'Объявление',
              value: sjRead(assignment, 'listingUrl'),
            ),
          ),
        ],
        if (sjRead(assignment, 'comment').isNotEmpty) ...[
          const SparkSectionTitle('Комментарий', top: SparkSpace.xxl),
          SparkCard(
            child: Text(
              sjRead(assignment, 'comment'),
              style: const TextStyle(
                fontSize: SparkTextSize.body,
                color: kGreyColor,
                height: 1.35,
              ),
            ),
          ),
        ],
        const SparkSectionTitle('Статус', top: SparkSpace.xxl),
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
        const SparkSectionTitle('Действия', top: SparkSpace.xxl),
        if (status == 'completed' && sjRead(assignment, 'reportId').isNotEmpty)
          SparkCard(
            child: SizedBox(
              width: double.infinity,
              height: SparkSize.actionHeightMd,
              child: FilledButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Открыть отчёт'),
              ),
            ),
          ),
        if (_canModify) ...[
          SparkCard(
            child: SizedBox(
              width: double.infinity,
              height: SparkSize.actionHeightMd,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Редактировать'),
              ),
            ),
          ),
          const SizedBox(height: SparkSpace.lg),
          SizedBox(
            height: SparkSize.actionHeightMd,
            child: OutlinedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) {
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
                              text: 'Удалить заявку?',
                              size: SparkTextSize.title,
                              weight: FontWeight.w700,
                            ),
                            const SizedBox(height: SparkSpace.md),
                            MyText(
                              text:
                                  'Заявка на осмотр "${sjRead(assignment, 'vehicle')}" будет удалена. Это действие нельзя отменить.',
                              size: SparkTextSize.body,
                              color: kGreyColor,
                            ),
                            const SizedBox(height: SparkSpace.xl),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Отмена'),
                                  ),
                                ),
                                const SizedBox(width: SparkSpace.md),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Удалить'),
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

                if (confirmed != true || !context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Заявка удалена')));
                Navigator.of(context).pop(true);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: kRedColor,
                side: const BorderSide(color: kRedColor2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.sm),
                ),
              ),
              child: const Text('Удалить заявку'),
            ),
          ),
        ],
        if (status == 'in_progress')
          const Padding(
            padding: EdgeInsets.only(top: SparkSpace.lg),
            child: SparkHintCard(
              text:
                  'Заявка в работе у специалиста. Только специалист может отменить осмотр.',
            ),
          ),
      ],
    );
  }
}

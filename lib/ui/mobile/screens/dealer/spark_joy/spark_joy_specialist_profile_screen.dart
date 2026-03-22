import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoySpecialistProfileScreen extends StatelessWidget {
  const SparkJoySpecialistProfileScreen({super.key});

  Map<String, dynamic> _specialist() {
    return cloneMap(
      sparkSpecialists.firstWhere(
        (s) => sjRead(s, 'id') == kSparkSpecialistId,
        orElse: () => sparkSpecialists.first,
      ),
    );
  }

  Map<String, dynamic>? _company(Map<String, dynamic> specialist) {
    final companyId = sjRead(specialist, 'companyId');
    if (companyId.isEmpty) {
      return null;
    }
    final company = sparkCompanies.where((c) => sjRead(c, 'id') == companyId);
    if (company.isEmpty) return null;
    return cloneMap(company.first);
  }

  @override
  Widget build(BuildContext context) {
    final specialist = _specialist();
    final company = _company(specialist);

    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        const MyText(text: 'Мой профиль', size: 22, weight: FontWeight.w700),
        const SizedBox(height: 12),
        SparkCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kSecondaryColor.withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: MyText(
                  text: sjInitials(sjRead(specialist, 'name')),
                  size: 20,
                  weight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: sjRead(specialist, 'name', fallback: 'Специалист'),
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SparkChip(
                          text:
                              sparkFormatLabels[sjRead(specialist, 'format')] ??
                              'Специалист',
                          background: kSecondaryColor.withValues(alpha: 0.1),
                          color: kSecondaryColor,
                        ),
                        SparkChip(
                          text: sjRead(specialist, 'status') == 'active'
                              ? 'Активен'
                              : 'Неактивен',
                          background: sjRead(specialist, 'status') == 'active'
                              ? kGreenColor.withValues(alpha: 0.15)
                              : kGreyColor.withValues(alpha: 0.15),
                          color: sjRead(specialist, 'status') == 'active'
                              ? kGreenColor
                              : kGreyColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                label: 'Телефон',
                value: sjRead(specialist, 'phone', fallback: '-'),
              ),
              SparkInfoRow(
                label: 'Email',
                value: sjRead(specialist, 'email', fallback: '-'),
              ),
            ],
          ),
        ),
        const SparkSectionTitle('Статистика', top: 14),
        Row(
          children: [
            Expanded(
              child: SparkCard(
                child: Column(
                  children: [
                    MyText(
                      text: sjRead(specialist, 'reportCount', fallback: '0'),
                      size: 24,
                      weight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                    const MyText(text: 'Отчётов', size: 11, color: kGreyColor),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SparkCard(
                child: Column(
                  children: [
                    MyText(
                      text: sjRead(
                        specialist,
                        'activeInspections',
                        fallback: '0',
                      ),
                      size: 24,
                      weight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                    const MyText(
                      text: 'Активных осмотров',
                      size: 11,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (company != null) ...[
          const SparkSectionTitle('Связь с компанией', top: 14),
          SparkCard(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.business_outlined,
                    color: kSecondaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: sjRead(company, 'name'),
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      MyText(
                        text:
                            '${sparkFormatLabels[sjRead(specialist, 'format')] ?? ''} · ${sjRead(company, 'city')}',
                        size: 11,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: MyBorderButton(
            buttonText: 'Редактировать профиль',
            textSize: 12,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Редактирование профиля в разработке'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

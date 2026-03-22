import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyProfileScreen extends StatelessWidget {
  const SparkJoyCompanyProfileScreen({super.key});

  Map<String, dynamic> _company() {
    return cloneMap(
      sparkCompanies.firstWhere(
        (c) => sjRead(c, 'id') == kSparkCompanyId,
        orElse: () => sparkCompanies.first,
      ),
    );
  }

  List<Map<String, dynamic>> _representatives() {
    return const [
      {
        'name': 'Алексей Петров',
        'role': 'Директор',
        'email': 'petrov@autoexpert-msk.ru',
      },
      {
        'name': 'Мария Иванова',
        'role': 'Менеджер',
        'email': 'ivanova@autoexpert-msk.ru',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final company = _company();
    final cities =
        (company['cities'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль компании')),
      body: ListView(
        padding: AppSizes.DEFAULT.copyWith(bottom: 24),
        children: [
          SparkCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: kSecondaryColor.withValues(alpha: 0.1),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.business_outlined,
                    color: kSecondaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: sjRead(company, 'name', fallback: 'Компания'),
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 4),
                      SparkChip(
                        text: sjRead(company, 'status') == 'active'
                            ? 'Активна'
                            : 'Неактивна',
                        background: sjRead(company, 'status') == 'active'
                            ? kGreenColor.withValues(alpha: 0.15)
                            : kGreyColor.withValues(alpha: 0.15),
                        color: sjRead(company, 'status') == 'active'
                            ? kGreenColor
                            : kGreyColor,
                      ),
                      MyText(
                        text: sjRead(company, 'description', fallback: '-'),
                        size: 11,
                        color: kGreyColor,
                        lineHeight: 1.35,
                        paddingTop: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SparkSectionTitle('Контакты и география', top: 14),
          SparkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SparkInfoRow(
                  label: 'Email',
                  value: sjRead(company, 'contactEmail', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Телефон',
                  value: sjRead(company, 'contactPhone', fallback: '-'),
                ),
                const SizedBox(height: 4),
                const MyText(
                  text: 'Города',
                  size: 12,
                  weight: FontWeight.w600,
                  color: kGreyColor,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cities
                      .map(
                        (city) => SparkChip(
                          text: city,
                          background: kSecondaryColor.withValues(alpha: 0.08),
                          color: kSecondaryColor,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SparkSectionTitle('Настройки работы', top: 14),
          SparkCard(
            child: Column(
              children: const [
                SparkInfoRow(
                  label: 'Кто видит отчёты',
                  value: 'Все сотрудники',
                ),
                SparkInfoRow(
                  label: 'Подтверждение отчёта компанией',
                  value: 'Выключено',
                ),
                SparkInfoRow(
                  label: 'Привлечение внештатных спецов',
                  value: 'Включено',
                ),
                SparkInfoRow(
                  label: 'Бренд компании в отчёте',
                  value: 'Включено',
                ),
              ],
            ),
          ),
          const SparkSectionTitle('Представители', top: 14),
          ..._representatives().map((rep) {
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
                            text: sjRead(rep, 'name'),
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                          MyText(
                            text:
                                '${sjRead(rep, 'role')} · ${sjRead(rep, 'email')}',
                            size: 11,
                            color: kGreyColor,
                            paddingTop: 2,
                          ),
                        ],
                      ),
                    ),
                    SparkChip(
                      text: sjRead(rep, 'role'),
                      background: kSecondaryColor.withValues(alpha: 0.08),
                      color: kSecondaryColor,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
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
      ),
    );
  }
}

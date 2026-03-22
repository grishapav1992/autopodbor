import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyDashboardScreen extends StatelessWidget {
  const SparkJoyCompanyDashboardScreen({
    super.key,
    required this.onOpenCreateAssignment,
    required this.onOpenInviteSpecialist,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenCreateAssignment;
  final VoidCallback onOpenInviteSpecialist;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final specs = sparkSpecialists
        .where((s) => sjRead(s, 'companyId') == kSparkCompanyId)
        .toList();

    final activeSpecs = specs
        .where((s) => sjRead(s, 'status') == 'active')
        .length;
    final guestSpecs = specs
        .where((s) => sjRead(s, 'format') == 'guest')
        .length;

    final assignments = sparkAssignments
        .where((a) => sjRead(a, 'companyId') == kSparkCompanyId)
        .toList();

    final activeAssignments = assignments.where((a) {
      final status = sjRead(a, 'status');
      return status == 'new' || status == 'assigned' || status == 'in_progress';
    }).length;

    final completedAssignments = assignments
        .where((a) => sjRead(a, 'status') == 'completed')
        .length;

    final cards = [
      _SummaryCardData(
        icon: Icons.groups_2_outlined,
        label: 'Всего специалистов',
        value: specs.length,
        color: kSecondaryColor,
      ),
      _SummaryCardData(
        icon: Icons.verified_user_outlined,
        label: 'Активных',
        value: activeSpecs,
        color: kGreenColor,
      ),
      _SummaryCardData(
        icon: Icons.person_add_alt_1_outlined,
        label: 'Внештат',
        value: guestSpecs,
        color: kYellowColor,
      ),
      _SummaryCardData(
        icon: Icons.assignment_outlined,
        label: 'Заявок в работе',
        value: activeAssignments,
        color: kSecondaryColor,
      ),
      _SummaryCardData(
        icon: Icons.task_alt_outlined,
        label: 'Завершённых',
        value: completedAssignments,
        color: kGreenColor,
      ),
    ];

    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        const MyText(
          text: 'Дашборд компании',
          size: 22,
          weight: FontWeight.w700,
        ),
        const MyText(
          text: 'АвтоЭксперт Москва',
          size: 12,
          color: kGreyColor,
          paddingTop: 2,
          paddingBottom: 12,
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, i) {
            final item = cards[i];
            return SparkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, size: 18, color: item.color),
                  const SizedBox(height: 8),
                  MyText(
                    text: '${item.value}',
                    size: 24,
                    weight: FontWeight.w700,
                    color: item.color,
                  ),
                  const SizedBox(height: 3),
                  MyText(text: item.label, size: 11, color: kGreyColor),
                ],
              ),
            );
          },
        ),
        const SparkSectionTitle('Быстрые действия', top: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: MyBorderButton(
                  buttonText: 'Новая заявка',
                  textSize: 12,
                  onTap: onOpenCreateAssignment,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: MyBorderButton(
                  buttonText: 'Пригласить спеца',
                  textSize: 12,
                  onTap: onOpenInviteSpecialist,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: MyButton(
            buttonText: 'Профиль компании',
            textSize: 12,
            onTap: onOpenProfile,
          ),
        ),
      ],
    );
  }
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
}

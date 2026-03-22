import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:get/get.dart';

class ChooseUserType extends StatefulWidget {
  const ChooseUserType({super.key});

  @override
  State<ChooseUserType> createState() => _ChooseUserTypeState();
}

class _ChooseUserTypeState extends State<ChooseUserType> {
  int _currentIndex = 1;

  Future<void> _continue() async {
    final role = _currentIndex == 0 ? 'company' : 'specialist';
    await UserSimplePreferences.setUserRole(role);
    if (!mounted) return;
    Get.offAllNamed(AppLinks.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 44),
            Center(child: Image.asset(Assets.imagesLogo, height: 58)),
            const Spacer(flex: 5),
            const MyText(
              text: 'Выберите роль',
              size: 18,
              weight: FontWeight.w700,
              textAlign: TextAlign.center,
              paddingBottom: 22,
            ),
            Row(
              children: [
                _roleCard(
                  index: 0,
                  icon: Icons.business_outlined,
                  title: 'Компания',
                  subtitle: 'Рабочее место компании',
                ),
                const SizedBox(width: 14),
                _roleCard(
                  index: 1,
                  icon: Icons.handyman_outlined,
                  title: 'Специалист',
                  subtitle: 'Рабочее место автоподборщика',
                ),
              ],
            ),
            const Spacer(flex: 4),
            MyButton(buttonText: 'Продолжить', onTap: _continue),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _roleCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          height: 188,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected ? kSecondaryColor : kWhiteColor,
            border: Border.all(
              color: selected
                  ? kSecondaryColor
                  : kTertiaryColor.withValues(alpha: 0.1),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      offset: const Offset(0, 6),
                      blurRadius: 14,
                      color: kTertiaryColor.withValues(alpha: 0.12),
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? kWhiteColor.withValues(alpha: 0.18)
                      : kSecondaryColor.withValues(alpha: 0.08),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 30,
                  color: selected ? kWhiteColor : kSecondaryColor,
                ),
              ),
              MyText(
                text: title,
                size: 17,
                weight: FontWeight.w700,
                color: selected ? kWhiteColor : kTertiaryColor,
                textAlign: TextAlign.center,
                paddingTop: 14,
              ),
              MyText(
                text: subtitle,
                size: 11,
                color: selected
                    ? kWhiteColor.withValues(alpha: 0.85)
                    : kGreyColor,
                textAlign: TextAlign.center,
                paddingTop: 6,
                lineHeight: 1.25,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

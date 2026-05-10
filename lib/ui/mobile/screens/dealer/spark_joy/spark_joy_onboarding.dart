import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:get/get.dart';

import 'spark_joy_i18n.dart';

class SparkJoyOnboardingBullet {
  const SparkJoyOnboardingBullet({
    required this.i18nKey,
    required this.fallback,
    required this.icon,
  });

  final String i18nKey;
  final String fallback;
  final IconData icon;
}

class SparkJoyOnboarding {
  // In-memory dedup so a single screen rebuild burst can't queue two sheets
  // before the SharedPreferences write completes.
  static final Set<String> _shownThisSession = <String>{};

  static Future<void> showOnce(
    BuildContext context, {
    required String flagKey,
    required String titleI18nKey,
    required String titleFallback,
    required List<SparkJoyOnboardingBullet> bullets,
    String buttonI18nKey = 'spark.onboarding.cta',
    String buttonFallback = 'Понятно',
  }) async {
    if (_shownThisSession.contains(flagKey)) return;
    _shownThisSession.add(flagKey);

    if (!Get.isRegistered<UserController>()) {
      _shownThisSession.remove(flagKey);
      return;
    }
    final userController = Get.find<UserController>();
    if (userController.role != UserRole.dealer) {
      _shownThisSession.remove(flagKey);
      return;
    }

    final alreadySeen =
        await UserSimplePreferences.isSparkOnboardingSeen(flagKey);
    if (alreadySeen) return;

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _SparkJoyOnboardingSheet(
        title: sjT(titleI18nKey, fallback: titleFallback),
        bullets: bullets,
        buttonText: sjT(buttonI18nKey, fallback: buttonFallback),
        onDismiss: () => Navigator.of(sheetContext).pop(),
      ),
    );

    await UserSimplePreferences.setSparkOnboardingSeen(flagKey);
  }

  static Future<void> resetAll() async {
    _shownThisSession.clear();
    await UserSimplePreferences.resetSparkOnboarding();
  }
}

class _SparkJoyOnboardingSheet extends StatelessWidget {
  const _SparkJoyOnboardingSheet({
    required this.title,
    required this.bullets,
    required this.buttonText,
    required this.onDismiss,
  });

  final String title;
  final List<SparkJoyOnboardingBullet> bullets;
  final String buttonText;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
          SparkSpace.xxxl,
          SparkSpace.md,
          SparkSpace.xxxl,
          SparkSpace.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 60,
                margin: const EdgeInsets.only(bottom: SparkSpace.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: kGreyColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            MyText(
              text: title,
              size: SparkTextSize.modalTitle,
              weight: FontWeight.w700,
              color: kBlackColor,
            ),
            const SizedBox(height: SparkSpace.lg),
            ...bullets.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(bottom: SparkSpace.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: SparkSize.iconState,
                      height: SparkSize.iconState,
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(SparkRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        bullet.icon,
                        size: SparkSize.iconMd,
                        color: kSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: SparkSpace.sm),
                        child: MyText(
                          text: sjT(bullet.i18nKey, fallback: bullet.fallback),
                          size: SparkTextSize.bodyLg,
                          color: kBlackColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SparkSpace.lg),
            MyButton(buttonText: buttonText, onTap: onDismiss),
          ],
        ),
      ),
    );
  }
}

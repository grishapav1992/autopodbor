import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChooseUserType extends StatefulWidget {
  const ChooseUserType({super.key});

  @override
  State<ChooseUserType> createState() => _ChooseUserTypeState();
}

class _ChooseUserTypeState extends State<ChooseUserType> {
  int currentIndex = 0;
  final UserController _userController = Get.find<UserController>();
  bool _navigating = false;

  Future<void> _selectRoleAndContinue(int index) async {
    if (_navigating) return;
    setState(() {
      currentIndex = index;
    });
    final role = index == 0 ? UserRole.user : UserRole.dealer;
    _userController.chooseRole(role);
    UserSimplePreferences.setUserRole(role == UserRole.user ? 'user' : 'dealer');
    setState(() {
      _navigating = true;
    });
    final hasSession = await StorageApi.hasSavedSession(
      probeWithGetBrand: true,
    );
    if (!mounted) return;
    if (hasSession) {
      Get.offAllNamed(role == UserRole.user ? AppLinks.userHome : AppLinks.dealerHome);
      return;
    }
    Get.offAllNamed(AppLinks.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: AppSizes.DEFAULT,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                Column(children: [Image.asset(Assets.imagesLogo, height: 60)]),
                const Spacer(flex: 5),
                Column(
                  children: [
                    MyText(
                      text: "continueAs".tr,
                      size: 16,
                      weight: FontWeight.w600,
                      textAlign: TextAlign.center,
                      paddingBottom: 30,
                    ),
                    Row(
                      children: [
                        userTypeButton(
                          onTap: () => _selectRoleAndContinue(0),
                          icon: Assets.imagesAppUser,
                          title: "user".tr,
                          index: 0,
                        ),
                        const SizedBox(width: 16),
                        userTypeButton(
                          onTap: () => _selectRoleAndContinue(1),
                          icon: Assets.imagesCarDealer,
                          title: "dealer".tr,
                          index: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    const SizedBox(height: 60),
                  ],
                ),
                const Spacer(flex: 4),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_navigating)
            Positioned.fill(
              child: Container(
                color: kWhiteColor.withValues(alpha: 0.8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    MyText(
                      text: 'Проверяем доступ...',
                      size: 12,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget userTypeButton({
    required VoidCallback onTap,
    required String icon,
    required String title,
    required int index,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeIn,
          height: 161,
          decoration: BoxDecoration(
            boxShadow: currentIndex == index
                ? [
                    BoxShadow(
                      offset: const Offset(0, 4),
                      blurRadius: 10,
                      color: kTertiaryColor.withValues(alpha: 0.1),
                    ),
                  ]
                : [],
            border: Border.all(
              width: 1.0,
              color: currentIndex == index
                  ? kSecondaryColor
                  : kTertiaryColor.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(24),
            color: currentIndex == index ? kSecondaryColor : kWhiteColor,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 55,
                width: 55,
                child: Center(
                  child: Image.asset(icon, height: index == 1 ? 50 : 40),
                ),
              ),
              MyText(
                text: title,
                size: 18,
                weight: FontWeight.w600,
                color: currentIndex == index ? kPrimaryColor : kTertiaryColor,
                paddingTop: 16,
                maxLines: 2,
                textAlign: TextAlign.center,
                textOverflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

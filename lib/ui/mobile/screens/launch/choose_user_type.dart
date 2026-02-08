import 'dart:async';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
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

  void getCurrentIndex(int index) {
    setState(() {
      currentIndex = index;
    });
    _userController.chooseRole(index == 0 ? UserRole.user : UserRole.dealer);
    UserSimplePreferences.setUserRole(index == 0 ? 'user' : 'dealer');
    unawaited(StorageApi.hasSavedSession(probeWithGetBrand: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
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
                      onTap: () => getCurrentIndex(0),
                      icon: Assets.imagesAppUser,
                      title: "user".tr,
                      index: 0,
                    ),
                    const SizedBox(width: 16),
                    userTypeButton(
                      onTap: () => getCurrentIndex(1),
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
            MyButton(
              buttonText: "continue".tr,
              onTap: () async {
                final role = currentIndex == 0
                    ? UserRole.user
                    : UserRole.dealer;
                _userController.chooseRole(role);
                UserSimplePreferences.setUserRole(
                  role == UserRole.user ? 'user' : 'dealer',
                );
                final hasSession = await StorageApi.hasSavedSession(
                  probeWithGetBrand: true,
                );
                if (hasSession) {
                  if (role == UserRole.user) {
                    Get.offAllNamed(AppLinks.userHome);
                  } else {
                    Get.offAllNamed(AppLinks.dealerHome);
                  }
                  return;
                }
                Get.offAllNamed(AppLinks.login);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/choose_user_type.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/user_nav_bar.dart';
import 'package:get/get.dart';

class PhoneVerification extends StatelessWidget {
  const PhoneVerification({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final phoneText = phone.isEmpty
        ? "callVerifySubtitle".tr
        : "callVerifySubtitleWithPhone".tr.replaceAll('{phone}', phone);

    return Scaffold(
      appBar: simpleAppBar(title: "callVerifyTitle".tr),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: AppSizes.listPaddingWithBottomBar(),
              physics: const BouncingScrollPhysics(),
              children: [
                AuthHeading(title: "callVerifyTitle".tr, subTitle: phoneText),
                const SizedBox(height: 16),
                MyText(
                  text: "callVerifyHint".tr,
                  textAlign: TextAlign.center,
                  color: kQuaternaryColor,
                  size: 15,
                  weight: FontWeight.w500,
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSizes.DEFAULT,
            child: MyButton(
              onTap: () {
                final controller = Get.find<UserController>();
                if (controller.isDealer) {
                  Get.offAll(() => const DealerNavBar());
                } else if (controller.isUser) {
                  Get.offAll(() => const UserNavBar());
                } else {
                  Get.offAll(() => ChooseUserType());
                }
              },
              buttonText: "continue".tr,
            ),
          ),
        ],
      ),
    );
  }
}

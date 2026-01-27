import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/forgot_pass/forgot_password.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/sign_up/sign_up.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/choose_user_type.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/user_nav_bar.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: ''),
      body: ListView(
        shrinkWrap: true,
        physics: BouncingScrollPhysics(),
        padding: AppSizes.DEFAULT,
        children: [
          AuthHeading(
            textAlign: TextAlign.center,
            title: "loginToYourAccount".tr,
            subTitle: "pleaseEnterYourCredentialsToGetStarted".tr,
          ),
          MyTextField(
            hintText: "username".tr,
            prefix: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Image.asset(Assets.imagesUserName, height: 24)],
            ),
          ),
          MyTextField(
            hintText: "password".tr,
            prefix: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Image.asset(Assets.imagesLock, height: 24)],
            ),
            suffix: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Assets.imagesVisiblity,
                  height: 24,
                  color: kBorderColor,
                ),
              ],
            ),
            isObSecure: true,
          ),
          Row(
            children: [
              CustomCheckBox(isActive: true, onTap: () {}),
              Expanded(
                child: MyText(
                  paddingLeft: 12,
                  text: "rememberMe".tr,
                  size: 15,
                  weight: FontWeight.w600,
                ),
              ),
              MyText(
                onTap: () => Get.to(() => ForgotPassword()),
                text: "forgotPassword".tr,
                size: 15,
                weight: FontWeight.bold,
                textAlign: TextAlign.end,
                color: kSecondaryColor,
              ),
            ],
          ),
          SizedBox(height: 40),
          MyButton(
            onTap: () {
              final controller = Get.find<UserController>();
              if (!controller.hasRole) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => ChooseUserType()),
                );
                return;
              }
              final target =
                  controller.isDealer ? DealerNavBar() : UserNavBar();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => target),
              );
            },
            buttonText: "login".tr,
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 5,
            alignment: WrapAlignment.center,
            children: [
              MyText(text: "don’tHaveAnAccount".tr),
              MyText(
                onTap: () => Get.to(() => SignUp()),
                text: "register".tr,
                color: kSecondaryColor,
                weight: FontWeight.bold,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


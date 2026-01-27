import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/login.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/sign_up/phone_verification.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignUp extends StatelessWidget {
  const SignUp({super.key});

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
            marginTop: 40,
            title: "signUp".tr,
            textAlign: TextAlign.center,
            subTitle: "pleaseSignUpToCreateYourAccount".tr,
          ),
          MyTextField(
            prefix: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Image.asset(Assets.imagesUserName, height: 24)],
            ),
            hintText: "username".tr,
          ),
          PhoneField(),
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
          MyTextField(
            hintText: "confirmPassword".tr,
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
            marginBottom: 40,
            isObSecure: true,
          ),
          MyButton(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PhoneVerification()),
              );
            },
            buttonText: "continue".tr,
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 5,
            alignment: WrapAlignment.center,
            children: [
              MyText(text: "alreadyHaveAnAccount".tr),
              MyText(
                onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => Login()),
                  (route) => false,
                ),
                text: "logIn".tr,
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

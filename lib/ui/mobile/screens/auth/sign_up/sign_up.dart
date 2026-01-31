import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/login.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/sign_up/phone_verification.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: ''),
      body: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: AppSizes.DEFAULT,
        children: [
          const AuthHeading(
            marginTop: 40,
            title: 'Регистрация',
            textAlign: TextAlign.center,
            subTitle: 'Введите телефон и пароль',
          ),
          PhoneField(controller: _phoneController),
          MyTextField(
            hintText: 'Пароль',
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
            hintText: 'Повторите пароль',
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
                MaterialPageRoute(
                  builder: (_) =>
                      PhoneVerification(phone: _phoneController.text.trim()),
                ),
              );
            },
            buttonText: 'Продолжить',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 5,
            alignment: WrapAlignment.center,
            children: [
              const MyText(text: 'Уже есть аккаунт?'),
              MyText(
                onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const Login()),
                  (route) => false,
                ),
                text: 'Войти',
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

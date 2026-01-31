import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_fonts.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/forgot_pass/create_password.dart';
import 'package:pinput/pinput.dart';

class ForgotPassVerification extends StatelessWidget {
  const ForgotPassVerification({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final defaultTheme = PinTheme(
      width: 72,
      height: 60,
      margin: EdgeInsets.zero,
      textStyle: TextStyle(
        fontSize: 20,
        height: 0.0,
        fontWeight: FontWeight.bold,
        color: kSecondaryColor,
        fontFamily: AppFonts.URBANIST,
      ),
      decoration: BoxDecoration(
        border: Border.all(width: 1.0, color: kBorderColor),
        color: kInputBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    final phoneText = phone.isEmpty
        ? 'Мы отправили SMS с кодом на указанный номер.'
        : 'Мы отправили SMS с кодом на номер $phone.';

    return Scaffold(
      appBar: simpleAppBar(title: 'Подтверждение кода'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: AppSizes.listPaddingWithBottomBar(),
              physics: const BouncingScrollPhysics(),
              children: [
                AuthHeading(title: 'Введите код', subTitle: phoneText),
                const SizedBox(height: 10),
                Pinput(
                  length: 4,
                  onChanged: (value) {},
                  pinContentAlignment: Alignment.center,
                  defaultPinTheme: defaultTheme,
                  focusedPinTheme: defaultTheme.copyWith(
                    decoration: BoxDecoration(
                      border: Border.all(width: 1.0, color: kSecondaryColor),
                      color: kSecondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  submittedPinTheme: defaultTheme.copyWith(
                    decoration: BoxDecoration(
                      border: Border.all(width: 1.0, color: kSecondaryColor),
                      color: kSecondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  mainAxisAlignment: MainAxisAlignment.center,
                  separatorBuilder: (index) {
                    return const SizedBox(width: 0);
                  },
                  onCompleted: (pin) => print(pin),
                ),
                const SizedBox(height: 35),
                MyText(
                  text: 'Не получили код?',
                  textAlign: TextAlign.center,
                  color: kQuaternaryColor,
                  size: 15,
                  weight: FontWeight.w500,
                  paddingBottom: 12,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    MyText(
                      text: 'Можно запросить повторно через ',
                      color: kQuaternaryColor,
                      size: 15,
                      weight: FontWeight.w500,
                    ),
                    MyText(
                      text: '60 c',
                      size: 15,
                      weight: FontWeight.bold,
                      color: kSecondaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSizes.DEFAULT,
            child: MyButton(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatePassword()),
                );
              },
              buttonText: 'Продолжить',
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter_application_1/core/constants/app_colors.dart';



import 'package:flutter_application_1/core/constants/app_fonts.dart';



import 'package:flutter_application_1/core/constants/app_images.dart';



import 'package:flutter_application_1/core/constants/app_sizes.dart';



import 'package:flutter_application_1/state/user_controller.dart';



import 'package:flutter_application_1/ui/mobile/screens/launch/choose_user_type.dart';



import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';



import 'package:flutter_application_1/ui/mobile/screens/nav_bar/user_nav_bar.dart';



import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';



import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';



import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';



import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';



import 'package:flutter/material.dart';



import 'package:get/get.dart';







import 'package:pinput/pinput.dart';







class PhoneVerification extends StatelessWidget {



  const PhoneVerification({super.key});







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



    return Scaffold(



      appBar: simpleAppBar(title: "otpVerification".tr),



      body: Column(



        children: [



          Expanded(



            child: ListView(



              shrinkWrap: true,



              padding: AppSizes.DEFAULT,



              physics: BouncingScrollPhysics(),



              children: [



                AuthHeading(



                  title: "enterCode".tr,



                  subTitle:



                      "we’veSentAnSmsWithAnActivationCodeToYourPhone33294278411"



                          .tr,



                ),



                SizedBox(height: 10),



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



                    return SizedBox(width: 0);



                  },



                  // ignore: avoid_print



                  onCompleted: (pin) => print(pin),



                ),



                SizedBox(height: 35),



                MyText(



                  text: 'didntReceiveEmail'.tr,



                  textAlign: TextAlign.center,



                  color: kQuaternaryColor,



                  size: 15,



                  weight: FontWeight.w500,



                  paddingBottom: 12,



                ),



                Row(



                  mainAxisAlignment: MainAxisAlignment.center,



                  children: [



                    MyText(



                      text: "youCanResendCodeIn".tr,



                      color: kQuaternaryColor,



                      size: 15,



                      weight: FontWeight.w500,



                    ),



                    MyText(



                      text: '55?',



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



                Get.dialog(_SuccessDialog());



              },



              buttonText: "continue".tr,



            ),



          ),



        ],



      ),



    );



  }



}







class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          margin: AppSizes.DEFAULT,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(Assets.imagesCongrats, height: 118),
                MyText(
                  paddingTop: 24,
                  text: 'Проверка пройдена',
                  size: 20,
                  weight: FontWeight.bold,
                  color: kSecondaryColor,
                  textAlign: TextAlign.center,
                  paddingBottom: 14,
                ),
                MyText(
                  text:
                      'Аккаунт подтвержден. Можно переходить к работе в приложении.',
                  size: 14,
                  color: kGreyColor,
                  lineHeight: 1.5,
                  paddingLeft: 10,
                  paddingRight: 10,
                  textAlign: TextAlign.center,
                  paddingBottom: 20,
                ),
                MyButton(
                  buttonText: 'Продолжить',
                  onTap: () {
                    Get.back();
                    final controller = Get.find<UserController>();
                    if (!controller.hasRole) {
                      Navigator.of(context, rootNavigator: true)
                          .pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => ChooseUserType()),
                        (route) => false,
                      );
                      return;
                    }
                    final target = controller.isDealer
                        ? DealerNavBar()
                        : UserNavBar();
                    Navigator.of(context, rootNavigator: true)
                        .pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => target),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

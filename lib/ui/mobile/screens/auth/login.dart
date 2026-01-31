import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/choose_user_type.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/user_nav_bar.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  static const String _callMeNumber = '+7 000 000 00 00';
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _makeCall() async {
    final uri = Uri(
      scheme: 'tel',
      path: _callMeNumber.replaceAll(RegExp(r'\s+'), ''),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("callMeError".tr),
        backgroundColor: kSecondaryColor,
      ),
    );
  }

  void _proceedAfterCheck() {
    final controller = Get.find<UserController>();
    if (controller.isDealer) {
      Get.offAll(() => const DealerNavBar());
    } else if (controller.isUser) {
      Get.offAll(() => const UserNavBar());
    } else {
      Get.offAll(() => ChooseUserType());
    }
  }

  void _checkNumber() {
    _proceedAfterCheck();
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
          AuthHeading(
            textAlign: TextAlign.center,
            title: "callMeTitle".tr,
            subTitle: "callMeSubtitle".tr,
          ),
          PhoneField(controller: _phoneController),
          MyButton(onTap: _makeCall, buttonText: "callMeButton".tr),
          const SizedBox(height: 12),
          MyBorderButton(
            onTap: _checkNumber,
            buttonText: "checkNumberButton".tr,
          ),
        ],
      ),
    );
  }
}

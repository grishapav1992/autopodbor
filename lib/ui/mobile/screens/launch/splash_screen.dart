import 'dart:async';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_fonts.dart';
import 'package:flutter_application_1/core/localization/localization_controller/localization_controller.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/core/utils/global_instances.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/login.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/choose_user_type.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/user_nav_bar.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    getIsFirstLaunch();
    setRussian();
    _splashHandler();
  }

  void getIsFirstLaunch() async {
    isFirstLaunch = await UserSimplePreferences.getIsFirstLaunch() ?? true;
  }

  void setRussian() {
    languageController.currentIndex.value = 0;
    languageController.isEnglish.value = false;
    Localization().selectedLocale('Русский');
  }

  void _splashHandler() {
    Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;
      final access = await UserSimplePreferences.getAccessToken();
      final refresh = await UserSimplePreferences.getRefreshToken();
      final role = await UserSimplePreferences.getUserRole();
      if (!mounted) return;
      final hasSession =
          (access != null && access.isNotEmpty) &&
          (refresh != null && refresh.isNotEmpty);
      final Widget target;
      if (hasSession) {
        if (role == 'dealer') {
          target = const DealerNavBar();
        } else if (role == 'user') {
          target = const UserNavBar();
        } else {
          target = const ChooseUserType();
        }
      } else {
        target = const Login();
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => target),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSecondaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Spacer(),

          MyText(
            text: 'АВТОХАБ',
            size: 48,
            color: kPrimaryColor,
            fontFamily: AppFonts.GLACIAL_INDIFFERENCE,
            weight: FontWeight.w700,
            textAlign: TextAlign.center,
          ),
          MyText(
            text: 'Единый сервис для подбора,\nпокупки и продажи авто'
                .toUpperCase(),
            size: 16,
            color: kPrimaryColor,
            fontFamily: AppFonts.GLACIAL_INDIFFERENCE,
            textAlign: TextAlign.center,
            weight: FontWeight.w500,
          ),
          Spacer(),
          MyText(
            textAlign: TextAlign.center,
            paddingBottom: 25,
            text: 'Автохаб © ${DateTime.now().year}. Все права защищены'
                .toUpperCase(),
            size: 10,
            weight: FontWeight.w600,
            color: kPrimaryColor,
            fontFamily: AppFonts.GLACIAL_INDIFFERENCE,
          ),
        ],
      ),
    );
  }
}

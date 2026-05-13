import 'dart:async';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_fonts.dart';
import 'package:flutter_application_1/core/localization/localization_controller/localization_controller.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/core/utils/global_instances.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/login.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
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
      final hasSession = await StorageApi.hasSavedSession();
      if (!mounted) return;
      final Widget target;
      if (hasSession) {
        // Синкаем роль с сервера ДО показа nav-bar, чтобы AppBar и
        // tab-set отражали актуальную роль с первого фрейма. Без этого
        // если бэк перевёл пользователя specialist→company между
        // запусками — nav-bar бы открылся в старом режиме до первого
        // open profile screen. Offline-фолбэк уже внутри метода.
        await SparkJoyStorage.syncRoleFromServer();
        if (!mounted) return;
        target = const DealerNavBar();
      } else {
        target = const Login();
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => target));
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

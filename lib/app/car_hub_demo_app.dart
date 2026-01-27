import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/core/config/theme/light_theme.dart';
import 'package:flutter_application_1/core/localization/localization_controller/localization_controller.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

class CarHubDemoApp extends StatelessWidget {
  const CarHubDemoApp({super.key});

  static const routeName = '/car-hub-demo';

  Future<void> _init() async {
    WidgetsFlutterBinding.ensureInitialized();
    Get.put(LanguageController());
    await UserSimplePreferences.init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Material(
            color: Colors.white,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        return GetMaterialApp(
          locale: Localization.currentLocale,
          fallbackLocale: Localization.fallBackLocale,
          translations: Localization(),
          debugShowCheckedModeBanner: false,
          debugShowMaterialGrid: false,
          title: 'АВТОХАБ',
          theme: lightTheme,
          themeMode: ThemeMode.light,
          initialRoute: AppLinks.splashScreen,
          getPages: AppRoutes.pages,
          defaultTransition: Transition.fadeIn,
        );
      },
    );
  }
}


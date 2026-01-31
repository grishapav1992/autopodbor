/*
 * В© 2024 K-Tonix Solutions. All rights reserved.
 * Licensed under the K-Tonix Flutter UI Kit License Agreement.
 * Redistribution, resale, or public sharing of this source code is strictly prohibited.
 * For licensing inquiries, contact: babaa336@gmail.com
 * LinkedIn: https://www.linkedin.com/company/ktonixsolutions/
 */
import 'package:flutter_application_1/core/localization/localization_controller/localization_controller.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/core/config/theme/light_theme.dart';
import 'package:flutter_application_1/ui/common/responsive/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(LanguageController());
  Get.put(UserController());
  await UserSimplePreferences.init();
  await UserSimplePreferences.clearBrandCache();
  runApp(MyApp());
}

//DO NOT REMOVE Unless you find their usage.
String dummyImg =
    'https://images.unsplash.com/photo-1558507652-2d9626c4e67a?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=687&q=80';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      initialRoute: AppLinks.landing,
      getPages: AppRoutes.pages,
      defaultTransition: Transition.fadeIn,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final media = MediaQuery.of(context);
        final scaled = media.textScaleFactor * 1.1;
        final scale = scaled < 1.0 ? 1.0 : (scaled > 1.3 ? 1.3 : scaled);
        return MediaQuery(
          data: media.copyWith(textScaleFactor: scale),
          child: ResponsiveLayout(child: child),
        );
      },
    );
  }
}


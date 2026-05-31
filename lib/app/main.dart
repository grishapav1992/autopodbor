/*
 * В© 2024 K-Tonix Solutions. All rights reserved.
 * Licensed under the K-Tonix Flutter UI Kit License Agreement.
 * Redistribution, resale, or public sharing of this source code is strictly prohibited.
 * For licensing inquiries, contact: babaa336@gmail.com
 * LinkedIn: https://www.linkedin.com/company/ktonixsolutions/
 */
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter_application_1/core/localization/localization_controller/localization_controller.dart';
import 'package:flutter_application_1/data/api/storage_api.dart'
    show sessionExpiredTicker;
import 'package:flutter_application_1/state/notification_controller.dart';
import 'package:flutter_application_1/state/permissions_controller.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/core/config/theme/light_theme.dart';
import 'package:flutter_application_1/ui/common/responsive/responsive_layout.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installCrashBoundary();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    Get.put(LanguageController());
    Get.put(UserController());
    await UserSimplePreferences.init();
    // RBAC permissions controller, registered eagerly so any screen can gate
    // via Get.find. Seeded from the local cache now (instant, last-known
    // rights); the authoritative refetch is fired from the role-sync
    // bootstrap (SparkJoyStorage.syncRoleFromServer).
    final permissions = Get.put(PermissionsController(), permanent: true);
    unawaited(permissions.seedFromCache());
    // Notification controller is registered eagerly so any screen can
    // resolve it via Get.find. Bootstrap (WS connect + first fetch) is
    // a no-op if there's no persisted notification token, so this is
    // safe before login.
    final notifications = Get.put(NotificationController(), permanent: true);
    unawaited(notifications.bootstrap());
    runApp(const MyApp());
  }, _logUnhandledError);
}

void _installCrashBoundary() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logUnhandledError(details.exception, details.stack ?? StackTrace.current);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _logUnhandledError(error, stack);
    return true;
  };
}

void _logUnhandledError(Object error, StackTrace stack) {
  developer.log(
    'Unhandled app error',
    name: 'AppCrashBoundary',
    error: error,
    stackTrace: stack,
  );
}

//DO NOT REMOVE Unless you find their usage.
String dummyImg =
    'https://images.unsplash.com/photo-1558507652-2d9626c4e67a?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=687&q=80';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Session-expiry listener. `storage_api` bumps this ticker whenever
    // an authenticated RPC hits a dead-token path it can't recover
    // from (refresh failed or refresh echoed an expired access token).
    // We redirect the whole stack to the login route — any screen open
    // at the moment loses context, which is intentional: its data is
    // unauthenticated and shouldn't stay on screen.
    sessionExpiredTicker.addListener(_handleSessionExpired);
  }

  @override
  void dispose() {
    sessionExpiredTicker.removeListener(_handleSessionExpired);
    super.dispose();
  }

  void _handleSessionExpired() {
    // GetX navigator may not be attached yet during very-early boot;
    // guard so the listener doesn't crash on first-ever tick.
    if (!Get.isRegistered<GetMaterialController>()) return;
    // Tear down the notification WS before navigating — the persisted
    // notification token is dead alongside access/refresh tokens.
    if (Get.isRegistered<NotificationController>()) {
      unawaited(Get.find<NotificationController>().shutdown());
    }
    Get.offAllNamed(AppLinks.login);
    // Небольшой snackbar чтобы юзер понимал, почему его выкинуло.
    Get.snackbar(
      'Сессия истекла',
      'Пожалуйста, войдите снова.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        final scaled = media.textScaler.scale(1.0);
        final scale = scaled.clamp(0.95, 1.15);
        void dismissKeyboard() {
          FocusManager.instance.primaryFocus?.unfocus();
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: dismissKeyboard,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              dismissKeyboard();
              return false;
            },
            child: MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(scale)),
              child: ResponsiveLayout(child: child),
            ),
          ),
        );
      },
    );
  }
}

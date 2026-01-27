import 'package:get/get.dart';

import 'package:flutter_application_1/ui/mobile/screens/auth/login.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/sign_up/phone_verification.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/sign_up/sign_up.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/choose_user_type.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/landing.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/splash_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/user_nav_bar.dart';

class AppRoutes {
  static final List<GetPage> pages = [
    GetPage(
      name: AppLinks.splashScreen,
      page: () => SplashScreen(),
    ),
    GetPage(
      name: AppLinks.landing,
      page: () => LandingScreen(),
    ),
    GetPage(
      name: AppLinks.login,
      page: () => Login(),
    ),
    GetPage(
      name: AppLinks.signUp,
      page: () => SignUp(),
    ),
    GetPage(
      name: AppLinks.phoneVerification,
      page: () => PhoneVerification(),
    ),
    GetPage(
      name: AppLinks.chooseUserType,
      page: () => ChooseUserType(),
    ),
    GetPage(
      name: AppLinks.userHome,
      page: () => UserNavBar(),
    ),
    GetPage(
      name: AppLinks.dealerHome,
      page: () => DealerNavBar(),
    ),
  ];
}

class AppLinks {
  // ignore: constant_identifier_names
  static const splashScreen = '/splash_screen';
  static const landing = '/landing';
  static const login = '/login';
  static const signUp = '/sign_up';
  static const phoneVerification = '/phone_verification';
  static const chooseUserType = '/choose_user_type';
  static const userHome = '/user_home';
  static const dealerHome = '/dealer_home';
}

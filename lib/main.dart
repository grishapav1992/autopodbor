import 'package:flutter/material.dart';

import 'auto_request_mock/auto_request_mock_screen.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'landing/landing_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),
      initialRoute: LandingScreen.routeName,
      routes: {
        LandingScreen.routeName: (_) => const LandingScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        '/app': (_) => AutoRequestMockScreen(),
        '/app-guest': (_) =>
            const AutoRequestMockScreen(requireAuthOnSubmit: true),
      },
    );
  }
}

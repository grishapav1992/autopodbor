import 'package:flutter/material.dart';

import '../auto_request_mock/data.dart';
import '../auto_request_mock/widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.returnResult = false});

  static const routeName = '/login';
  final bool returnResult;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String login = '';
  String password = '';
  String? loginError;
  String? passwordError;

  void _submit() {
    setState(() {
      loginError = login.trim().isEmpty ? 'Введите логин' : null;
      passwordError = password.trim().isEmpty ? 'Введите пароль' : null;
    });
    if (loginError != null || passwordError != null) return;

    if (widget.returnResult) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushReplacementNamed('/app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [uiTokens.gray50, Colors.white],
            begin: Alignment.topCenter,
            end: const Alignment(0, 0.6),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Вход',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: uiTokens.gray900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppField(
                        label: 'Логин',
                        required: true,
                        hint: loginError,
                        child: AppInput(
                          value: login,
                          placeholder: 'Логин',
                          onChanged: (v) => setState(() => login = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppField(
                        label: 'Пароль',
                        required: true,
                        hint: passwordError,
                        child: AppInput(
                          value: password,
                          placeholder: 'Пароль',
                          obscureText: true,
                          onChanged: (v) => setState(() => password = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Войти',
                        onTap: _submit,
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Создать аккаунт',
                        variant: ButtonVariant.secondary,
                        onTap: () => Navigator.of(context)
                            .pushReplacementNamed(RegisterScreen.routeName),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

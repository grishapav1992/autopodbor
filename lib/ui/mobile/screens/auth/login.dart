import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_data.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _phoneController = TextEditingController();
  static const String _techCodePassword = '12112016';
  static const String _techAccessToken =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpYXQiOjE3NzA0MTAyOTMuNTU1NzQ0LCJleHAiOjE3NzA0NTM0OTMuNTU1NzQ0LCJzdWIiOiIyOCIsInR5cGUiOiJhdXRoIn0.aqlVCZtLzKWXCNoOXJOYxYdgY0cxX-LLKyH4aMil8Pkz3eNibKtnUuba017tfzY150Ov52ZCe6FMO5UH0spBUTR9aNYsb-KSemTECEGQvoqOvHQQmtoOV0bBYsa1WNprkbXnhPmQmdgmuCv9ss7RcHk9Uq758_3xS1kI9-y06OVHjNe8fyBInzF6ThxFQwfk24Ntcn2bBsssAEzZHTD1tOfTR5NcwdlNxuX5MQ-Z8t1drNVKm5nn32r4clwwoFmnYNmN0e90kh-NiXVO6i37AE9jTtyJo8jaM2rXu2MGGTz3oYnZS_w_yRM9pikaN5pMBsE0G-N1OkWJE3Acr9Ptug';
  static const String _techRefreshToken =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpYXQiOjE3NzAyMjk0MjYuMzc5Mjk5LCJleHAiOjE3NzI4MjE0MjYuMzc5Mjk5LCJzdWIiOiIyOCIsInR5cGUiOiJyZWZyZXNoIn0.lueu7sU6ZR3rgbsB1Q1r1ryX0hnP68wlMSqaH6sI4IMs1AaEQUAtguFKJhAuFYEz8ay-ruLHMXw_-v413bgl6jsqP3RTlZ04JY2RCpuPScADY1w9R6o9tixfLjuSH572JkEHgHnCSxbx5UKuR-NOlkLvweRhjSesRCQBy2CMy8chUJX7cbPmyXe3fnaYUjzo-mVWkva2ZBab6fu1QPf-8O9pj2DXWAbpHisvdUJDArhUVQKZm3GSch56MZzG8C-3GSEyrRTQ-SN5AqgXMH0KPiiw6pOmaKlDkEklRHF-ZO9kzIv7lLo8Vy-EIzz3dBDb78ih-nQtvbrOhzSBkZbdyw';

  String _callPhone = '';
  String? _sessionId;
  String _statusText = '';
  bool _isAuthLoading = false;
  bool _isVerifyLoading = false;
  int _opId = 0;

  @override
  void dispose() {
    _opId++;
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('8') && digits.length == 11) {
      return '+7${digits.substring(1)}';
    }
    if (digits.startsWith('7') && digits.length == 11) return '+$digits';
    if (digits.length == 10) return '+7$digits';
    return '+$digits';
  }

  String _normalizeCallPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (trimmed.startsWith('+')) return '+$digits';
    if (digits.startsWith('8') && digits.length == 11) {
      return '+7${digits.substring(1)}';
    }
    if (digits.startsWith('7') && digits.length == 11) return '+$digits';
    if (digits.length == 10) return '+7$digits';
    return '+$digits';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kSecondaryColor),
    );
  }

  Future<void> _startAuth() async {
    if (_isAuthLoading || _isVerifyLoading) return;
    final phone = _normalizePhone(_phoneController.text.trim());
    final digitsLen = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitsLen < 11) {
      _showError('Введите корректный номер телефона.');
      return;
    }

    final currentOp = ++_opId;
    setState(() {
      _isAuthLoading = true;
      _callPhone = '';
      _sessionId = null;
      _statusText = 'Запрашиваем номер для звонка...';
    });

    try {
      final result = await StorageApi.auth(phone: phone);
      if (!mounted || currentOp != _opId) return;
      final callPhone = _normalizeCallPhone(result.callPhone);
      setState(() {
        _callPhone = callPhone;
        _sessionId = result.sessionId;
        _statusText = 'Позвоните на номер выше. Проверка займет до 3 минут.';
      });
      unawaited(_startAutoVerify(phone, currentOp));
    } catch (err, stack) {
      if (!mounted || currentOp != _opId) return;
      // DIAG (revert before merge): surface the real error so we can
      // tell apart network/ATS/backend issues instead of swallowing.
      debugPrint('auth start failed: $err\n$stack');
      _showError('Auth error: $err');
      setState(() {
        _statusText = '';
      });
    } finally {
      if (mounted && currentOp == _opId) {
        setState(() => _isAuthLoading = false);
      }
    }
  }

  Future<void> _openDialer() async {
    final target = _callPhone.trim();
    if (target.isEmpty) {
      _showError('Сначала нажмите "Далее", чтобы получить номер для звонка.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: target.replaceAll(RegExp(r'\s+'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    _showError('Не удалось открыть приложение для звонка.');
  }

  Future<void> _startAutoVerify(String phone, int startOp) async {
    if (!mounted || startOp != _opId || _callPhone.isEmpty) return;
    setState(() {
      _isVerifyLoading = true;
      _statusText = 'Проверяем звонок...';
    });

    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (mounted && startOp == _opId && DateTime.now().isBefore(deadline)) {
      try {
        final verify = await StorageApi.authVerify(
          phone: phone,
          sessionId: _sessionId,
        );
        if (verify.hasTokens) {
          await UserSimplePreferences.setAuthTokens(
            accessToken: verify.accessToken!,
            refreshToken: verify.refreshToken!,
          );
          if (!mounted || startOp != _opId) return;
          setState(() {
            _isVerifyLoading = false;
            _statusText = 'Статус проверки: все OK. Выполняем вход...';
          });
          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted || startOp != _opId) return;
          await _proceedAfterCheck();
          return;
        }
      } catch (_) {}

      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted || startOp != _opId) return;
    setState(() {
      _isVerifyLoading = false;
      _statusText =
          'Статус проверки: не OK. Не удалось подтвердить звонок автоматически. Нажмите «Проверить статус звонка» после вызова.';
    });
  }

  Future<void> _verifyOnceManually() async {
    if (_isAuthLoading || _isVerifyLoading) return;
    final phone = _normalizePhone(_phoneController.text.trim());
    final digitsLen = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitsLen < 11) {
      _showError('Введите корректный номер телефона.');
      return;
    }

    final currentOp = _opId;
    if (mounted) {
      setState(() {
        _isVerifyLoading = true;
        _statusText = 'Проверяем статус звонка...';
      });
    }

    try {
      final verify = await StorageApi.authVerify(
        phone: phone,
        sessionId: _sessionId,
      );
      if (!mounted || currentOp != _opId) return;
      if (verify.hasTokens) {
        await UserSimplePreferences.setAuthTokens(
          accessToken: verify.accessToken!,
          refreshToken: verify.refreshToken!,
        );
        if (!mounted || currentOp != _opId) return;
        setState(() {
          _statusText = 'Статус проверки: все OK. Выполняем вход...';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted || currentOp != _opId) return;
        await _proceedAfterCheck();
        return;
      }
      setState(() {
        _statusText =
            'Звонок пока не подтверждён. Выполните звонок на выданный номер и повторите проверку.';
      });
    } catch (_) {
      if (!mounted || currentOp != _opId) return;
      setState(() {
        _statusText =
            'Не удалось проверить статус звонка. Повторите через несколько секунд.';
      });
    } finally {
      if (mounted && currentOp == _opId) {
        setState(() => _isVerifyLoading = false);
      }
    }
  }

  Future<void> _techSignIn() async {
    await UserSimplePreferences.setAuthTokens(
      accessToken: _techAccessToken,
      refreshToken: _techRefreshToken,
    );
    if (!mounted) return;
    setState(() {
      _statusText =
          'Технический вход активирован. Используем фиксированный токен.';
    });
    await _proceedAfterCheck();
  }

  Future<void> _promptTechPasswordAndSignIn() async {
    if (_isAuthLoading || _isVerifyLoading) return;

    var passwordValue = '';
    String? passwordError;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            void submit() {
              final value = passwordValue.trim();
              if (value != _techCodePassword) {
                setLocalState(() {
                  passwordError = 'Неверный пароль';
                });
                return;
              }
              Navigator.of(dialogContext).pop(true);
            }

            return AlertDialog(
              title: const Text('Технический код'),
              content: TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Введите пароль',
                  errorText: passwordError,
                ),
                onChanged: (value) {
                  passwordValue = value;
                  if (passwordError == null) return;
                  setLocalState(() {
                    passwordError = null;
                  });
                },
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(onPressed: submit, child: const Text('Войти')),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _techSignIn();
  }

  Future<void> _proceedAfterCheck() async {
    final sparkRole = await SparkJoyStorage.currentRole();
    await SparkJoyStorage.login(sparkRole);
    await UserSimplePreferences.setUserRole(
      sparkRole == SparkJoyRole.company ? 'company' : 'specialist',
    );
    if (!mounted) return;
    Get.offAll(() => const DealerNavBar());
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
          const AuthHeading(
            textAlign: TextAlign.center,
            title: 'Авторизация',
            subTitle:
                'Введите номер телефона. Затем позвоните на выданный номер для автоматической проверки.',
          ),
          PhoneField(controller: _phoneController),
          if (_callPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: _openDialer,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: kSecondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.call_outlined,
                          color: kSecondaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MyText(
                              text: 'Номер для звонка',
                              size: 12,
                              color: kGreyColor,
                            ),
                            const SizedBox(height: 4),
                            MyText(
                              text: _callPhone,
                              size: 21,
                              weight: FontWeight.w700,
                              color: kTertiaryColor,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: kSecondaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const MyText(
                          text: 'Позвонить',
                          size: 11,
                          color: kSecondaryColor,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_isAuthLoading || _isVerifyLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_statusText.isNotEmpty)
            MyText(
              text: _statusText,
              size: 12,
              color: kGreyColor,
              paddingBottom: 12,
            ),
          if (_callPhone.isEmpty)
            MyButton(
              onTap: _startAuth,
              buttonText: _isAuthLoading ? 'Загрузка...' : 'Далее',
              bgColor: _isAuthLoading ? kGreyColor : kSecondaryColor,
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MyBorderButton(
                onTap: _verifyOnceManually,
                buttonText: _isVerifyLoading
                    ? 'Проверка...'
                    : 'Проверить статус звонка',
                textSize: 12,
              ),
            ),
          const SizedBox(height: 14),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const MyText(
              text: 'Технический вход',
              size: 12,
              color: kGreyColor,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 4),
            children: [
              MyBorderButton(
                onTap: _promptTechPasswordAndSignIn,
                buttonText: 'Войти по техническому коду',
                textSize: 12,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/state/notification_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/privacy_policy.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _phoneController = TextEditingController();

  String _callPhone = '';
  String? _sessionId;
  String _statusText = '';
  bool _isAuthLoading = false;
  bool _isVerifyLoading = false;
  bool _pdnConsentAccepted = false;
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
    if (!_pdnConsentAccepted) {
      _showError('Подтвердите согласие на обработку персональных данных.');
      return;
    }
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
      // Persist the notification token early — backend issues it from
      // both Storage.Auth and Storage.AuthVerify, so the WebSocket can
      // connect while the user is still on the dialer screen. Safe even
      // if AuthVerify never completes — token gets cleared on logout.
      if (result.notificationToken != null &&
          result.notificationToken!.isNotEmpty) {
        await UserSimplePreferences.setNotificationToken(
          result.notificationToken!,
        );
      }
      if (!mounted || currentOp != _opId) return;
      final callPhone = _normalizeCallPhone(result.callPhone);
      setState(() {
        _callPhone = callPhone;
        _sessionId = result.sessionId;
        _statusText = 'Позвоните на номер выше. Проверка займет до 3 минут.';
      });
      unawaited(_startAutoVerify(phone, currentOp));
    } catch (e, st) {
      debugPrint('[AUTH] _startAuth EXCEPTION: $e\n$st');
      if (!mounted || currentOp != _opId) return;
      _showError('Не удалось начать авторизацию. Попробуйте еще раз.');
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
          if (verify.hasNotificationToken) {
            await UserSimplePreferences.setNotificationToken(
              verify.notificationToken!,
            );
          }
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
    if (!_pdnConsentAccepted) {
      _showError('Подтвердите согласие на обработку персональных данных.');
      return;
    }
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
        if (verify.hasNotificationToken) {
          await UserSimplePreferences.setNotificationToken(
            verify.notificationToken!,
          );
        }
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


  void _openPersonalDataConsent() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicy()));
  }

  Future<void> _proceedAfterCheck() async {
    // Server — source of truth для role. GetProfile внутри
    // syncRoleFromServer ловит offline и фолбэк-ит на локальный кэш,
    // так что вход не блокируется отсутствием сети.
    await SparkJoyStorage.syncRoleFromServer();
    // (Re)bootstrap the realtime notification channel with the freshly
    // persisted notification token. No-op if the controller wasn't
    // registered yet (very early launch path) or no token exists.
    if (Get.isRegistered<NotificationController>()) {
      unawaited(Get.find<NotificationController>().rebootstrap());
    }
    if (!mounted) return;
    Get.offAll(() => const DealerNavBar());
  }

  /// Прерывает ожидание/поллинг звонка и возвращает к вводу номера.
  /// Инкремент `_opId` отменяет активный цикл `_startAutoVerify` и любые
  /// in-flight ответы (они проверяют `currentOp != _opId`). Без этого, если
  /// со звонком что-то пошло не так, экран висел в «Проверяем звонок…» без
  /// ручного выхода.
  void _cancelVerification() {
    _opId++;
    setState(() {
      _isAuthLoading = false;
      _isVerifyLoading = false;
      _callPhone = '';
      _sessionId = null;
      _statusText = '';
    });
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
          _PersonalDataConsentCheckbox(
            value: _pdnConsentAccepted,
            onChanged: (value) {
              setState(() => _pdnConsentAccepted = value ?? false);
            },
            onOpenConsent: _openPersonalDataConsent,
          ),
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
              bgColor: _isAuthLoading || !_pdnConsentAccepted
                  ? kGreyColor
                  : kSecondaryColor,
            )
          else ...[
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
            // Ручной выход из ожидания звонка (если со звонком что-то пошло
            // не так) — прерывает поллинг и возвращает к вводу номера.
            Center(
              child: TextButton(
                onPressed: _cancelVerification,
                child: const MyText(
                  text: 'Отменить и ввести номер заново',
                  size: 12,
                  color: kGreyColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonalDataConsentCheckbox extends StatelessWidget {
  const _PersonalDataConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.onOpenConsent,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenConsent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
          decoration: BoxDecoration(
            color: kWhiteColor,
            border: Border.all(color: kBorderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: kSecondaryColor,
                  side: const BorderSide(color: kBorderColor),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: kGreyColor,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'Согласен на обработку '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: onOpenConsent,
                            child: const Text(
                              'персональных данных',
                              style: TextStyle(
                                color: kSecondaryColor,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

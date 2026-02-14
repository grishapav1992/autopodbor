import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/state/user_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/headings_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/launch/choose_user_type.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/dealer_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/nav_bar/user_nav_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/pep_consent.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/privacy_policy.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/terms.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _phoneController = TextEditingController();

  String _requestPhone = '';
  String _callPhone = '';
  String? _sessionId;
  String _statusText = '';
  bool _isAuthLoading = false;
  bool _isVerifyLoading = false;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _pepAccepted = false;
  int _opId = 0;

  bool get _hasAcceptedAllConsents =>
      _termsAccepted && _privacyAccepted && _pepAccepted;

  @override
  void dispose() {
    _opId++;
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    String normalizedDigits = digits;
    if (digits.startsWith('8') && digits.length == 11) {
      normalizedDigits = '7${digits.substring(1)}';
    } else if (!digits.startsWith('7') && digits.length == 10) {
      normalizedDigits = '7$digits';
    }
    return '+$normalizedDigits';
  }

  bool _isValidPhoneForAuth(String normalizedPhone) {
    return RegExp(r'^\+7\d{10}$').hasMatch(normalizedPhone);
  }

  String _normalizeCallPhoneForDisplay(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('+')) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '+$trimmed';
    return '+$digits';
  }

  String _normalizeCallPhoneForDial(String raw) {
    final normalized = _normalizeCallPhoneForDisplay(raw);
    return normalized.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kSecondaryColor),
    );
  }

  Future<void> _startAuth() async {
    if (_isAuthLoading || _isVerifyLoading) return;
    if (!_hasAcceptedAllConsents) {
      _showError('Подтвердите все согласия перед продолжением.');
      return;
    }
    final phone = _normalizePhone(_phoneController.text.trim());
    if (!_isValidPhoneForAuth(phone)) {
      _showError('Введите корректный номер телефона.');
      return;
    }

    final currentOp = ++_opId;
    setState(() {
      _isAuthLoading = true;
      _requestPhone = phone;
      _callPhone = '';
      _sessionId = null;
      _statusText = 'Запрашиваем номер для звонка...';
    });

    try {
      final result = await StorageApi.auth(phone: phone);
      if (!mounted || currentOp != _opId) return;
      final callPhone = _normalizeCallPhoneForDisplay(result.callPhone);
      setState(() {
        _callPhone = callPhone;
        _sessionId = result.sessionId;
        _statusText =
            'Ожидаем звонок с номера $_requestPhone на $_callPhone. Проверка выполняется автоматически до 3 минут.';
      });
      unawaited(_startAutoVerify(phone, currentOp));
    } catch (_) {
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
    final target = _normalizeCallPhoneForDial(_callPhone);
    if (target.isEmpty) {
      _showError('Сначала нажмите "Далее", чтобы получить номер для звонка.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: target);
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
      _statusText = 'Ждем звонок и проверяем автоматически...';
    });

    final deadline = DateTime.now().add(const Duration(minutes: 3));
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
          _proceedAfterCheck();
          return;
        }
      } catch (_) {}

      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted || startOp != _opId) return;
    setState(() {
      _isVerifyLoading = false;
      _statusText =
          'Статус проверки: не OK. Не удалось подтвердить звонок за 3 минуты.';
    });
  }

  void _proceedAfterCheck() {
    final controller = Get.find<UserController>();
    if (controller.isDealer) {
      UserSimplePreferences.setUserRole('dealer');
      Get.offAll(() => const DealerNavBar());
    } else if (controller.isUser) {
      UserSimplePreferences.setUserRole('user');
      Get.offAll(() => const UserNavBar());
    } else {
      Get.offAll(() => const ChooseUserType());
    }
  }

  void _openTerms() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const Terms()));
  }

  void _openPrivacyPolicy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicy()));
  }

  void _openPepConsent() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PepConsent()));
  }

  Widget _buildConsentTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String plainTextBeforeLink,
    required String linkText,
    required VoidCallback onLinkTap,
    String plainTextAfterLink = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: kSecondaryColor,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  if (plainTextBeforeLink.isNotEmpty)
                    MyText(
                      text: plainTextBeforeLink,
                      size: 12,
                      color: kTertiaryColor,
                      lineHeight: 1.4,
                    ),
                  MyText(
                    text: linkText,
                    size: 12,
                    color: kSecondaryColor,
                    weight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    lineHeight: 1.4,
                    onTap: onLinkTap,
                  ),
                  if (plainTextAfterLink.isNotEmpty)
                    MyText(
                      text: plainTextAfterLink,
                      size: 12,
                      color: kTertiaryColor,
                      lineHeight: 1.4,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(
        title: '',
        onLeadingTap: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
            return;
          }
          Get.offAll(() => const ChooseUserType());
        },
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: AppSizes.DEFAULT,
        children: [
          const AuthHeading(
            textAlign: TextAlign.center,
            title: 'Авторизация',
            subTitle:
                'Введите номер телефона и нажмите "Далее". Затем позвоните на выданный номер — проверка пройдет автоматически.',
          ),
          PhoneField(controller: _phoneController),
          if (_requestPhone.isNotEmpty)
            MyText(
              text: 'Ваш номер: $_requestPhone',
              size: 12,
              color: kGreyColor,
              paddingBottom: 8,
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
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: kSecondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.call_outlined,
                          color: kSecondaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MyText(
                              text: 'Номер для звонка',
                              size: 11,
                              color: kGreyColor,
                            ),
                            const SizedBox(height: 2),
                            MyText(
                              text: _callPhone,
                              size: 16,
                              weight: FontWeight.w700,
                              color: kTertiaryColor,
                            ),
                            const SizedBox(height: 2),
                            const MyText(
                              text: 'Нажмите, чтобы открыть звонок',
                              size: 10,
                              color: kGreyColor,
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
                          size: 10,
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
            Column(
              children: [
                _buildConsentTile(
                  value: _termsAccepted,
                  onChanged: (value) {
                    setState(() => _termsAccepted = value ?? false);
                  },
                  plainTextBeforeLink: 'Принимаю',
                  linkText: 'Пользовательское соглашение',
                  onLinkTap: _openTerms,
                ),
                _buildConsentTile(
                  value: _privacyAccepted,
                  onChanged: (value) {
                    setState(() => _privacyAccepted = value ?? false);
                  },
                  plainTextBeforeLink: 'Подтверждаю согласие с',
                  linkText: 'Политикой ПДн',
                  onLinkTap: _openPrivacyPolicy,
                ),
                _buildConsentTile(
                  value: _pepAccepted,
                  onChanged: (value) {
                    setState(() => _pepAccepted = value ?? false);
                  },
                  plainTextBeforeLink: 'Даю',
                  linkText: 'Согласие на ПЭП',
                  onLinkTap: _openPepConsent,
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: _hasAcceptedAllConsents ? 1 : 0.7,
                  child: MyButton(
                    onTap: _startAuth,
                    buttonText: _isAuthLoading ? 'Загрузка...' : 'Далее',
                    bgColor: _isAuthLoading
                        ? kGreyColor
                        : (_hasAcceptedAllConsents
                              ? kSecondaryColor
                              : kGreyColor),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderColor),
              ),
              child: const MyText(
                text: 'Нажмите на номер выше и выполните звонок.',
                size: 11,
                color: kGreyColor,
              ),
            ),
        ],
      ),
    );
  }
}

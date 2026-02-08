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
    if (digits.startsWith('8') && digits.length == 11) return '+7${digits.substring(1)}';
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
      _showError('Р’РІРµРґРёС‚Рµ РєРѕСЂСЂРµРєС‚РЅС‹Р№ РЅРѕРјРµСЂ С‚РµР»РµС„РѕРЅР°.');
      return;
    }

    final currentOp = ++_opId;
    setState(() {
      _isAuthLoading = true;
      _requestPhone = phone;
      _callPhone = '';
      _sessionId = null;
      _statusText = 'Р—Р°РїСЂР°С€РёРІР°РµРј РЅРѕРјРµСЂ РґР»СЏ Р·РІРѕРЅРєР°...';
    });

    try {
      final result = await StorageApi.auth(phone: phone);
      if (!mounted || currentOp != _opId) return;
      setState(() {
        _callPhone = result.callPhone;
        _sessionId = result.sessionId;
        _statusText =
            'РћР¶РёРґР°РµРј Р·РІРѕРЅРѕРє СЃ РЅРѕРјРµСЂР° $_requestPhone РЅР° $_callPhone. РџСЂРѕРІРµСЂРєР° РІС‹РїРѕР»РЅСЏРµС‚СЃСЏ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё РґРѕ 3 РјРёРЅСѓС‚.';
      });
      unawaited(_startAutoVerify(phone, currentOp));
    } catch (_) {
      if (!mounted || currentOp != _opId) return;
      _showError('РќРµ СѓРґР°Р»РѕСЃСЊ РЅР°С‡Р°С‚СЊ Р°РІС‚РѕСЂРёР·Р°С†РёСЋ. РџРѕРїСЂРѕР±СѓР№С‚Рµ РµС‰Рµ СЂР°Р·.');
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
      _showError('РЎРЅР°С‡Р°Р»Р° РЅР°Р¶РјРёС‚Рµ "Р”Р°Р»РµРµ", С‡С‚РѕР±С‹ РїРѕР»СѓС‡РёС‚СЊ РЅРѕРјРµСЂ РґР»СЏ Р·РІРѕРЅРєР°.');
      return;
    }
    final uri = Uri(
      scheme: 'tel',
      path: target.replaceAll(RegExp(r'\s+'), ''),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    _showError('РќРµ СѓРґР°Р»РѕСЃСЊ РѕС‚РєСЂС‹С‚СЊ РїСЂРёР»РѕР¶РµРЅРёРµ РґР»СЏ Р·РІРѕРЅРєР°.');
  }

  Future<void> _startAutoVerify(String phone, int startOp) async {
    if (!mounted || startOp != _opId || _callPhone.isEmpty) return;
    setState(() {
      _isVerifyLoading = true;
      _statusText = 'Р–РґРµРј Р·РІРѕРЅРѕРє Рё РїСЂРѕРІРµСЂСЏРµРј Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё...';
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
            _statusText = 'РЎС‚Р°С‚СѓСЃ РїСЂРѕРІРµСЂРєРё: РІСЃРµ OK. Р’С‹РїРѕР»РЅСЏРµРј РІС…РѕРґ...';
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
          'РЎС‚Р°С‚СѓСЃ РїСЂРѕРІРµСЂРєРё: РЅРµ OK. РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕРґС‚РІРµСЂРґРёС‚СЊ Р·РІРѕРЅРѕРє Р·Р° 3 РјРёРЅСѓС‚С‹.';
    });
  }\n
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
            title: 'РђРІС‚РѕСЂРёР·Р°С†РёСЏ',
            subTitle:
                'Р’РІРµРґРёС‚Рµ РЅРѕРјРµСЂ С‚РµР»РµС„РѕРЅР° Рё РЅР°Р¶РјРёС‚Рµ "Р”Р°Р»РµРµ". Р—Р°С‚РµРј РїРѕР·РІРѕРЅРёС‚Рµ РЅР° РІС‹РґР°РЅРЅС‹Р№ РЅРѕРјРµСЂ вЂ” РїСЂРѕРІРµСЂРєР° РїСЂРѕР№РґРµС‚ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё.',
          ),
          PhoneField(controller: _phoneController),
          if (_requestPhone.isNotEmpty)
            MyText(
              text: 'Р’Р°С€ РЅРѕРјРµСЂ: $_requestPhone',
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                        child: const Icon(Icons.call_outlined, color: kSecondaryColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MyText(text: 'РќРѕРјРµСЂ РґР»СЏ Р·РІРѕРЅРєР°', size: 11, color: kGreyColor),
                            const SizedBox(height: 2),
                            MyText(
                              text: _callPhone,
                              size: 16,
                              weight: FontWeight.w700,
                              color: kTertiaryColor,
                            ),
                            const SizedBox(height: 2),
                            const MyText(
                              text: 'РќР°Р¶РјРёС‚Рµ, С‡С‚РѕР±С‹ РѕС‚РєСЂС‹С‚СЊ Р·РІРѕРЅРѕРє',
                              size: 10,
                              color: kGreyColor,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: kSecondaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const MyText(
                          text: 'РџРѕР·РІРѕРЅРёС‚СЊ',
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
            MyButton(
              onTap: _startAuth,
              buttonText: _isAuthLoading ? 'Р—Р°РіСЂСѓР·РєР°...' : 'Р”Р°Р»РµРµ',
              bgColor: _isAuthLoading ? kGreyColor : kSecondaryColor,
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
                text: 'РќР°Р¶РјРёС‚Рµ РЅР° РЅРѕРјРµСЂ РІС‹С€Рµ Рё РІС‹РїРѕР»РЅРёС‚Рµ Р·РІРѕРЅРѕРє.',
                size: 11,
                color: kGreyColor,
              ),
            ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_specialist_profile_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/privacy_policy.dart';

class UDrawer extends StatefulWidget {
  const UDrawer({super.key});

  @override
  State<UDrawer> createState() => _UDrawerState();
}

class _UDrawerState extends State<UDrawer> {
  String _name = '';
  String _email = '';
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Seed instantly from the last cached snapshot so the header doesn't
    // flash empty, then refresh from the server. Before this the header
    // showed hard-coded mock data («Мелиса Томас» / mock email) (B1).
    final cached = await SparkJoyStorage.loadSpecialistProfileOrNull();
    if (cached != null) _applyProfile(cached);
    try {
      final profile = await StorageApi.getProfile();
      _applyProfile(profile);
    } catch (_) {
      // Offline / session issue — keep whatever the cache gave us.
    }
  }

  void _applyProfile(Map<String, dynamic> profile) {
    if (!mounted) return;
    String str(String key) => (profile[key] ?? '').toString().trim();
    final first = str('firstName');
    final last = str('lastName');
    final composed = [last, first].where((p) => p.isNotEmpty).join(' ');
    setState(() {
      _name = composed.isNotEmpty ? composed : str('name');
      _email = str('email');
      final avatar = str('urlAvatar');
      if (avatar.isNotEmpty) _avatarUrl = avatar;
    });
  }

  /// Opens the shared, API-backed profile (name, описание услуг, email с
  /// верификацией, название компании, аватар; телефон read-only). Reuses
  /// [SparkJoySpecialistProfileScreen] instead of the old mock screens so
  /// real data loads and edits actually persist via UpdateProfile (B1/B2).
  void _openProfile() {
    Get.to(
      () => Scaffold(
        appBar: AppBar(title: Text('userProfile'.tr)),
        body: SparkJoySpecialistProfileScreen(onLogout: _logout),
      ),
    );
  }

  Future<void> _logout() async {
    await SparkJoyStorage.logout();
    await UserSimplePreferences.clearAuthTokens();
    Get.offAllNamed(AppLinks.login);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kPrimaryColor,
      width: Get.width * 0.7,
      child: Column(
        children: [
          Container(
            height: 215,
            padding: AppSizes.DEFAULT,
            decoration: BoxDecoration(color: kSecondaryColor),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CommonImageView(
                      height: 58,
                      width: 58,
                      radius: 100.0,
                      url: _avatarUrl.isNotEmpty ? _avatarUrl : dummyImg,
                    ),
                  ],
                ),
                SizedBox(height: 10),
                MyText(
                  text: _name.isNotEmpty ? _name : 'Профиль',
                  size: 18,
                  color: kWhiteColor,
                  weight: FontWeight.w500,
                  paddingRight: 4,
                ),
                if (_email.isNotEmpty)
                  MyText(
                    paddingTop: 6,
                    text: _email,
                    size: 14,
                    color: kWhiteColor.withValues(alpha: 0.7),
                    paddingBottom: 6,
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero.copyWith(bottom: 96),
              physics: BouncingScrollPhysics(),
              children: [
                _DrawerTile(
                  icon: Assets.imagesUserProfileIconNew,
                  title: "userProfile".tr,
                  onTap: _openProfile,
                ),
                _DrawerTile(
                  icon: Assets.imagesPrivacyPolicyIcon,
                  title: "privacyPolicy".tr,
                  onTap: () {
                    Get.to(() => PrivacyPolicy());
                  },
                ),
              ],
            ),
          ),
          _DrawerTile(
            icon: Assets.imagesLogoutIcon,
            title: "logout".tr,
            onTap: _logout,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: kTertiaryColor.withValues(alpha: 0.1),
        highlightColor: kTertiaryColor.withValues(alpha: 0.1),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Image.asset(icon, height: 32),
              Expanded(child: MyText(paddingLeft: 8, text: title, size: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

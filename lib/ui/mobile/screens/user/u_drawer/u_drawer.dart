import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/edit_profile.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/privacy_policy.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/profile.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UDrawer extends StatelessWidget {
  const UDrawer({super.key});

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
                      url: dummyImg,
                    ),
                  ],
                ),
                SizedBox(height: 10),
                MyText(
                  text: 'Мелиса Томас',
                  size: 18,
                  color: kWhiteColor,
                  weight: FontWeight.w500,
                  paddingRight: 4,
                ),
                MyText(
                  paddingTop: 6,
                  text: 'пользователь@почта.рф',
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
                  onTap: () {
                    Get.to(() => Profile());
                  },
                ),
                _DrawerTile(
                  icon: Assets.imagesSettingsIconNew,
                  title: "settings".tr,
                  onTap: () {
                    Get.to(() => EditProfile());
                  },
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
            onTap: () {},
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

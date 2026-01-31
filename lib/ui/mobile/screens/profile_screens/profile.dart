import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/edit_profile.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/privacy_policy.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/terms.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(haveLeading: true, title: "userProfile".tr),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.HORIZONTAL.copyWith(bottom: 96),
        physics: BouncingScrollPhysics(),
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kWhiteColor,
              border: Border.all(width: 1.0, color: kBorderColor),
            ),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CommonImageView(
                        height: 80,
                        width: 80,
                        radius: 100.0,
                        url: dummyImg,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Image.asset(Assets.imagesCamera, height: 24),
                      ),
                    ],
                  ),
                ),
                MyText(
                  paddingTop: 8,
                  size: 18,
                  textAlign: TextAlign.center,
                  weight: FontWeight.w600,
                  text: 'Амелия Джейкоб',
                ),
                MyText(
                  paddingTop: 6,
                  size: 14,
                  textAlign: TextAlign.center,
                  weight: FontWeight.w500,
                  color: kGreyColor,
                  text: 'пользователь@почта.рф',
                  paddingBottom: 20,
                ),
                MyButton(
                  buttonText: '',
                  onTap: () {
                    Get.to(() => EditProfile());
                  },
                  customChild: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(Assets.imagesNewEdit, height: 18),
                      MyText(
                        paddingLeft: 4,
                        paddingRight: 4,
                        text: "editProfile".tr,
                        size: 14,
                        weight: FontWeight.w600,
                        color: kWhiteColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kWhiteColor,
              border: Border.all(width: 1.0, color: kBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileTile(
                  icon: Assets.imagesSp,
                  title: "privacyPolicy".tr,
                  onTap: () {
                    Get.to(() => PrivacyPolicy());
                  },
                ),
                _Divider(),
                _ProfileTile(
                  icon: Assets.imagesTermsIcon,
                  title: "termsConditions".tr,
                  onTap: () {
                    Get.to(() => Terms());
                  },
                ),
                _Divider(),
                _ProfileTile(
                  icon: Assets.imagesHelpCenterIcon,
                  title: "helpCenter".tr,
                  onTap: () {},
                ),
                _Divider(),
                _ProfileTile(
                  icon: Assets.imagesLogoutIconNew,
                  title: "logout".tr,
                  onTap: () {},
                ),
              ],
            ),
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: kBorderColor,
      margin: EdgeInsets.symmetric(vertical: 12),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Image.asset(icon, height: 32, width: 32),
          Expanded(
            child: MyText(
              paddingLeft: 8,
              paddingRight: 8,
              text: title,
              size: 16,
              weight: FontWeight.w500,
            ),
          ),
          Image.asset(Assets.imagesRoundedNextArrow, height: 24),
        ],
      ),
    );
  }
}

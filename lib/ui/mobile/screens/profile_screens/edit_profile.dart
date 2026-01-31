import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditProfile extends StatelessWidget {
  const EditProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: "editProfile".tr),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: AppSizes.listPaddingWithBottomBar(),
              physics: BouncingScrollPhysics(),
              children: [
                _Heading(title: "avatar".tr),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: kWhiteColor,
                    border: Border.all(width: 1.0, color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      CommonImageView(
                        height: 54,
                        width: 54,
                        radius: 100.0,
                        url: dummyImg,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                MyText(
                                  text: "browse".tr,
                                  size: 16,
                                  color: kSecondaryColor,
                                  weight: FontWeight.bold,
                                ),
                                MyText(text: "yourProfilePicture".tr),
                              ],
                            ),
                            MyText(
                              paddingTop: 8,
                              text: "jpegsOrPngsOnly".tr,
                              size: 14,
                              color: kGreyColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                _Heading(title: "personalInformation".tr),
                SizedBox(height: 16),
                MyTextField(labelText: "name".tr, hintText: "kevinBacker".tr),
                MyTextField(
                  labelText: "emailAddress".tr,
                  hintText: "kevinbacker34gmailcom".tr,
                ),
                MyTextField(labelText: "password".tr, hintText: "".tr),
                MyText(
                  text: "phoneNumber".tr,
                  size: 14,
                  weight: FontWeight.w600,
                  paddingBottom: 6,
                ),
                PhoneField(),
              ],
            ),
          ),
          Padding(
            padding: AppSizes.DEFAULT,
            child: MyButton(buttonText: "save".tr, onTap: () {}),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Image.asset(
            Assets.imagesProfileHeading,
            height: 24,
            color: kSecondaryColor,
          ),
          MyText(
            paddingLeft: 10,
            text: title,
            size: 16,
            weight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

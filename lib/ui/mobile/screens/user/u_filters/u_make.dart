import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_filters/u_filter.dart';
import 'package:flutter_application_1/ui/common/widgets/bottom_sheets/custom_bottom_sheet_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UMake extends StatelessWidget {
  const UMake({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> items = [
      "abarth".tr,
      "aixam".tr,
      "alpina".tr,
      "bentley".tr,
      "bugatti".tr,
      "abarth".tr,
      "aixam".tr,
      "alpina".tr,
      "bentley".tr,
      "bugatti".tr,
      "abarth".tr,
      "aixam".tr,
      "alpina".tr,
      "bentley".tr,
      "bugatti".tr,
    ];
    return CustomBottomSheet(
      height: Get.height * 0.9,
      buttonText: "done".tr,
      onTap: () {
        Get.back();
        Get.bottomSheet(UFilter(), isScrollControlled: true);
      },
      child: Column(
        children: [
          MyText(
            paddingTop: 8,
            text: "whatAreYouLookingFor".tr,
            size: 18,
            weight: FontWeight.w600,
            paddingBottom: 20,
            textAlign: TextAlign.center,
          ),
          Expanded(
            child: ListView(
              padding: AppSizes.DEFAULT,
              physics: BouncingScrollPhysics(),
              shrinkWrap: true,
              children: [
                MyTextField(
                  hintText: "searchMake".tr,
                  suffix: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Image.asset(Assets.imagesSearch, height: 20)],
                  ),
                  onTap: () {},
                  marginBottom: 20.0,
                ),
                Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: "popularMakes".tr,
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                    MyText(
                      text: "selectAll".tr,
                      size: 12,
                      decoration: TextDecoration.underline,
                      color: kSecondaryColor,
                      weight: FontWeight.w600,
                    ),
                  ],
                ),
                SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return Container(
                      height: 48,
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: kWhiteColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: MyText(
                              text: items[index],
                              size: 14,
                              weight: FontWeight.w500,
                            ),
                          ),
                          CustomRadio(isActive: index == 0, onTap: () {}),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

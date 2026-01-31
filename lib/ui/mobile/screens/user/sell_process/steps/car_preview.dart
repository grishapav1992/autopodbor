import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_home/all_features.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CarPreview extends StatelessWidget {
  const CarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(
        title: "carDetails".tr,
        actions: [
          Center(child: Image.asset(Assets.imagesHeart, height: 24)),
          SizedBox(width: 20),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero.copyWith(bottom: 96),
              physics: BouncingScrollPhysics(),
              children: [
                CommonImageView(height: 200, width: Get.width, url: dummyImg),
                Padding(
                  padding: AppSizes.DEFAULT,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MyText(
                        text: 'Вортекс',
                        paddingBottom: 6,
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                      MyText(
                        text: 'ПОС 2018',
                        size: 19,
                        weight: FontWeight.w700,
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 10),
                        height: 1,
                        color: kBorderColor,
                      ),
                      MyText(
                        text:
                            'Описание автомобиля и основные детали для предпросмотра.',
                        weight: FontWeight.w500,
                        lineHeight: 1.4,
                        color: kGreyColor,
                        paddingBottom: 16,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: MyText(
                              text: "features".tr,
                              size: 16,
                              weight: FontWeight.w600,
                            ),
                          ),
                          MyText(
                            onTap: () => Get.to(() => AllFeatures()),
                            text: "seeMore".tr,
                            size: 12,
                            weight: FontWeight.w600,
                            color: kSecondaryColor,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      GridView.builder(
                        itemCount: 4,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          mainAxisExtent: 76,
                        ),
                        itemBuilder: (context, index) {
                          final List<Map<String, dynamic>> items = [
                            {
                              'icon': Assets.imagesEngine,
                              'title': "engine".tr,
                              'subTitle': '500 л.с.',
                            },
                            {
                              'icon': Assets.imagesMaxSpeed,
                              'title': "speed".tr,
                              'subTitle': '500 км/ч',
                            },
                            {
                              'icon': Assets.imagesGasoline,
                              'title': "gasoline".tr,
                              'subTitle': '100 км/ч',
                            },
                            {
                              'icon': Assets.imagesCapacity,
                              'title': "capacity".tr,
                              'subTitle': '6 мест',
                            },
                          ];
                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(width: 1, color: kBorderColor),
                              color: kGreyColor2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Image.asset(items[index]['icon'], height: 26),
                                  MyText(
                                    text: items[index]['title'],
                                    size: 10,
                                    color: kGreyColor,
                                    weight: FontWeight.w600,
                                  ),
                                  MyText(
                                    text: items[index]['subTitle'],
                                    size: 10,
                                    color: kSecondaryColor,
                                    weight: FontWeight.w600,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      MyText(
                        paddingTop: 16,
                        text: "seller".tr,
                        size: 16,
                        weight: FontWeight.w600,
                        paddingBottom: 8,
                      ),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: kWhiteColor,
                          border: Border.all(width: 1.0, color: kBorderColor),
                        ),
                        child: Row(
                          children: [
                            CommonImageView(
                              height: 45,
                              width: 45,
                              radius: 8,
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
                                        text: "caropedia".tr,
                                        size: 17,
                                        weight: FontWeight.w600,
                                        paddingRight: 6,
                                      ),
                                      Image.asset(
                                        Assets.imagesVerified,
                                        height: 20,
                                        color: kSecondaryColor,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Image.asset(
                                        Assets.imagesLocation,
                                        color: kRedColor,
                                        height: 14,
                                      ),
                                      MyText(
                                        paddingLeft: 4,
                                        text: "baghdad".tr,
                                        size: 12,
                                        color: kHintColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Image.asset(Assets.imagesWhatsapp, height: 38),
                            SizedBox(width: 6),
                            Image.asset(Assets.imagesCall, height: 38),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSizes.DEFAULT,
            child: MyButton(
              buttonText: "done".tr,
              onTap: () {
                Get.dialog(_SuccessDialog());
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          margin: AppSizes.DEFAULT,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(Assets.imagesSuccessLogo, height: 130),
                MyText(
                  paddingTop: 24,
                  text: "carAddedSuccessfully".tr,
                  size: 20,
                  color: kSecondaryColor,
                  weight: FontWeight.bold,
                  textAlign: TextAlign.center,
                  paddingBottom: 12,
                ),
                MyText(
                  text: "yourCarHasBeenAddedSuccessfully".tr,
                  size: 14,
                  color: kGreyColor,
                  lineHeight: 1.5,
                  paddingLeft: 10,
                  paddingRight: 10,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

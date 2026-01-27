import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/pricing/piricing_details.dart';
import 'package:flutter_application_1/ui/mobile/screens/notifications/notifications.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class PricingTools extends StatelessWidget {
  const PricingTools({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(
        title: "pricingTool".tr,
        actions: [
          Center(
            child: GestureDetector(
              onTap: () {
                Get.to(() => Notifications());
              },
              child: Image.asset(Assets.imagesNotificationIcon, height: 40),
            ),
          ),
          SizedBox(width: 20),
        ],
      ),
      body: ListView(
        padding: AppSizes.DEFAULT,
        physics: BouncingScrollPhysics(),
        shrinkWrap: true,
        children: [
          MyTextField(
            labelText: "makeModelStockNo".tr,
            prefix: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Assets.imagesSearch,
                  height: 20,
                  color: kSecondaryColor,
                ),
              ],
            ),
            hintText: "searchMakeModelStockNo".tr,
          ),
          MyTextField(
            labelText: "sortInventory".tr,
            prefix: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Assets.imagesSearch,
                  height: 20,
                  color: kSecondaryColor,
                ),
              ],
            ),
            hintText: "bestDealsFirst".tr,
          ),
          MyText(
            text: "showing50Vehicles".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 6,
          ),
          ListView.builder(
            itemCount: 5,
            physics: BouncingScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (context, index) {
              return _VehicleCard();
            },
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  _VehicleCard();

  final PageController _controller = PageController();
  @override
  Widget build(BuildContext context) {
    List<Segment> segments = [
      Segment(value: 20, color: Color(0xff026A00)),
      Segment(value: 20, color: Color(0xff029800)),
      Segment(value: 20, color: Color(0xff00BD04)),
      Segment(value: 20, color: Color(0xffFF8300)),
      Segment(value: 20, color: Color(0xffF60001)),
    ];
    return GestureDetector(
      onTap: () {
        Get.to(() => PricingDetails());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(width: 1, color: kBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 204,
                        child: PageView.builder(
                          itemCount: 3,
                          controller: _controller,
                          physics: BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            return CommonImageView(
                              url: dummyImg,
                              height: 204,
                              width: Get.width,
                              radius: 0,
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      right: 16,
                      child: Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(width: 1.0, color: kBorderColor),
                          color: kWhiteColor,
                        ),
                        child: Center(
                          child: Image.asset(
                            Assets.imagesEditIcon,
                            height: 20,
                            color: kSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: SmoothPageIndicator(
                        controller: _controller,
                        count: 3,
                        effect: ExpandingDotsEffect(
                          dotHeight: 5,
                          dotWidth: 5,
                          activeDotColor: kSecondaryColor,
                          dotColor: kWhiteColor,
                          expansionFactor: 5,
                          spacing: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                MyText(
                  paddingTop: 20,
                  text: "greatDeal".tr,
                  size: 18,
                  weight: FontWeight.w700,
                  color: kSecondaryColor,
                  paddingBottom: 4,
                ),
                MyText(
                  paddingBottom: 4,
                  text: '₽ 899',
                  size: 20,
                  weight: FontWeight.w500,
                  color: kHintColor,
                ),
                MyText(
                  text: 'Тойота Камри',
                  size: 18,
                  weight: FontWeight.w700,
                  paddingBottom: 8,
                ),
                Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: 'А123ВС77',
                        weight: FontWeight.w500,
                        color: kHintColor,
                      ),
                    ),
                    MyText(
                      text: '82 дня на рынке',
                      weight: FontWeight.w500,
                      color: kHintColor,
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Image.asset(
                      Assets.imagesLocation,
                      height: 16,
                      color: kSecondaryColor,
                    ),
                    Expanded(
                      child: MyText(
                        text: 'ул. Стрит 315, дом 10',
                        weight: FontWeight.w500,
                        color: kHintColor,
                        paddingLeft: 5,
                      ),
                    ),
                  ],
                ),
                MyText(
                  paddingTop: 8,
                  text: "newPrice".tr,
                  size: 12,
                  weight: FontWeight.w600,
                  paddingBottom: 6,
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 8,
                      child: MyTextField(marginBottom: 0.0, hintText: '₽'),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: MyButton(
                        textSize: 14,
                        buttonText: "update".tr,
                        onTap: () {
                          Get.to(() => PricingDetails());
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              MyText(
                text: "dealRanking".tr,
                size: 14,
                weight: FontWeight.w500,
                color: kHintColor,
              ),
              MyText(
                text: '120 из 400 ',
                size: 14,
                weight: FontWeight.w600,
              ),
            ],
          ),
          SizedBox(height: 10),
          PrimerProgressBar(
            segments: segments,
            showLegend: false,
            legendItemBuilder: (segment) {
              return LegendItem(segment: segment, style: LegendItemStyle());
            },
            barStyle: SegmentedBarStyle(padding: EdgeInsets.zero, gap: 0.1),
          ),
          SizedBox(height: 14),
        ],
      ),
    );
  }
}



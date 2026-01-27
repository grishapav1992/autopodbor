import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_tile_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class PricingDetails extends StatelessWidget {
  PricingDetails({super.key});
  final PageController _controller = PageController();

  final List<String> _items = [
    "satelliteNavigation".tr,
    "isofix".tr,
    "parkingAssist".tr,
    "auxusbConnectivity".tr,
    "airConditioning".tr,
    "alarmimmobiliser".tr,
    "dabRadio".tr,
    "privacyGlasstintedWindows".tr,
    "bluetooth".tr,
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: "pricingTool".tr),
      body: ListView(
        padding: AppSizes.DEFAULT,
        physics: BouncingScrollPhysics(),
        shrinkWrap: true,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
            paddingTop: 14,
            text: 'Тойота Камри',
            size: 22,
            weight: FontWeight.w700,
            paddingBottom: 10,
          ),
          MyText(
            text: 'Рег: А123ВС77',
            weight: FontWeight.w500,
            color: kHintColor,
          ),
          MyText(
            paddingTop: 10,
            text: 'Склад №: 62868181',
            weight: FontWeight.w500,
            color: kHintColor,
          ),
          MyText(
            paddingTop: 10,
            text: 'Пробег: 6 283 км',
            weight: FontWeight.w500,
            color: kHintColor,
          ),
          MyText(
            paddingTop: 10,
            text: 'Цена: ₽45,010',
            weight: FontWeight.w500,
            color: kHintColor,
          ),
          MyText(
            paddingTop: 14,
            text: "editVehicle".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 12,
          ),
          MyText(
            text: 'Тойота Камри',
            size: 16,
            weight: FontWeight.w400,
            paddingBottom: 12,
          ),
          CustomDropDown(
            labelText: "variant".tr,

            hint: '1.6 MT',
            items: ['1.6 MT'],
            selectedValue: '1.6 MT',
            onChanged: (v) {},
          ),
          CustomDropDown(
            labelText: "gearboxType".tr,
            hint: 'Механика',
            items: ["manual".tr],
            selectedValue: 'Механика',
            onChanged: (v) {},
          ),
          CustomDropDown(
            labelText: "engine".tr,
            hint: '2.0 TDI',
            items: ['2.0 TDI'],
            selectedValue: '2.0 TDI',
            onChanged: (v) {},
          ),
          MyText(
            text: "majorOptions".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 12,
          ),
          ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: BouncingScrollPhysics(),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              return CustomCheckBoxTile(
                isActive: index == 0,
                onTap: () {},
                title: _items[index],
              );
            },
          ),
          SizedBox(height: 12),
          CustomDropDown(
            labelText: "wheels".tr,
            hint: 'Литые диски',
            items: ['Литые диски'],
            selectedValue: 'Литые диски',
            onChanged: (v) {},
          ),
          SizedBox(height: 40),
          MyButton(buttonText: "save".tr, onTap: () {}),
          SizedBox(height: 6),
          MyBorderButton(buttonText: "cancel".tr, onTap: () {}),
        ],
      ),
    );
  }
}



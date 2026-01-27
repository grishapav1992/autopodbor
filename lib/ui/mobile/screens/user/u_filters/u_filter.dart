import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_filters/u_make.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_filters/u_model.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_filters/u_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/bottom_sheets/custom_bottom_sheet_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_slider_thumb_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_slider_tool_tip.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:get/get.dart';

class UFilter extends StatefulWidget {
  const UFilter({super.key});

  @override
  State<UFilter> createState() => _UFilterState();
}

class _UFilterState extends State<UFilter> {
  double _min = 16;

  double _max = 65;

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      height: Get.height * 0.9,
      buttonText: "search".tr,
      onTap: () {},
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
                NextButton(
                  labelText: "make".tr,
                  hint: "selectMake".tr,
                  onTap: () {
                    Get.back();
                    Get.bottomSheet(UMake(), isScrollControlled: true);
                  },
                ),
                SizedBox(height: 16),
                NextButton(
                  labelText: "model".tr,
                  hint: 'Выберите модель',
                  onTap: () {
                    Get.back();
                    Get.bottomSheet(UModel(), isScrollControlled: true);
                  },
                ),
                SizedBox(height: 16),
                MyText(
                  text: "price".tr,
                  size: 14,
                  color: kTertiaryColor,
                  paddingBottom: 6,
                  weight: FontWeight.bold,
                ),
                FlutterSlider(
                  values: [_min, _max],
                  rangeSlider: true,
                  min: 16,
                  max: 65,
                  tooltip: CustomSliderToolTip(),
                  // handlerWidth: Get.width * 0.03,
                  handlerHeight: 18,
                  handler: FlutterSliderHandler(
                    decoration: BoxDecoration(),
                    child: CustomSliderThumb(),
                  ),
                  rightHandler: FlutterSliderHandler(
                    decoration: BoxDecoration(),
                    child: CustomSliderThumb(),
                  ),
                  trackBar: FlutterSliderTrackBar(
                    activeTrackBarHeight: 8,
                    inactiveTrackBarHeight: 10,
                    activeTrackBar: BoxDecoration(
                      color: kSecondaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    inactiveTrackBar: BoxDecoration(
                      color: kWhiteColor,
                      border: Border.all(width: 1.0, color: kBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onDragging: (handlerIndex, lowerValue, upperValue) {
                    setState(() {
                      _min = lowerValue;
                      _max = upperValue;
                    });
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: MyTextField(
                        textAlign: TextAlign.center,
                        labelText: "min".tr,
                        hintText: 'Любой',
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: MyTextField(
                        textAlign: TextAlign.center,
                        labelText: "max".tr,
                        hintText: '₽23146',
                      ),
                    ),
                  ],
                ),
                NextButton(
                  labelText: "preferences".tr,
                  hint: 'Выберите параметры',
                  onTap: () {
                    Get.to(() => UPreferences());
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


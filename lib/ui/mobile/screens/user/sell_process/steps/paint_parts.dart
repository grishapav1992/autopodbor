import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PaintParts extends StatelessWidget {
  const PaintParts({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> items = [
      "cleanTitle".tr,
      "noPaint".tr,
      "1Part".tr,
      "2Parts".tr,
      "3Parts".tr,
      "3Parts".tr,
      "4Parts".tr,
      "5Parts".tr,
      "6Parts".tr,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          text: "plateType".tr,
          size: 14,
          paddingBottom: 8,
          weight: FontWeight.w600,
        ),
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: kWhiteColor,
                border: Border.all(width: 1.0, color: kBorderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: MyText(
                      text: items[index],
                      size: 12,
                      weight: FontWeight.w500,
                      color: kBlackColor,
                    ),
                  ),
                  CustomRadio(isActive: index == 0, onTap: () {}),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ignore: must_be_immutable, unused_element
class _PlateTypeBorder extends StatelessWidget {
  _PlateTypeBorder();
  String? title;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(width: 2, color: kBorderColor),
      ),
      child: Padding(
        padding: AppSizes.HORIZONTAL,
        child: Row(
          children: [
            Expanded(child: MyText(text: '$title')),
            Container(
              height: 19,
              width: 19,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(width: 2, color: kBorderColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


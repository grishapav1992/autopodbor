import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CarLocation extends StatelessWidget {
  CarLocation({super.key});

  final List<String> _items = [
    "Багдад".tr,
    "mosul".tr,
    "basra".tr,
    "kirkuk".tr,
    "erbil".tr,
    "najaf".tr,
    "yusufiya".tr,
    "radwaniyah".tr,
    "taji".tr,
    "rasheed".tr,
    "mahmudiyah".tr,
  ];
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomDropDown(
          labelText: "governorate".tr,
          hint: 'Багдад',
          items: ['Багдад'],
          selectedValue: 'Багдад',
          onChanged: (v) {},
        ),
        MyText(
          text: "citydistrict".tr,
          size: 12,
          paddingBottom: 6,
          weight: FontWeight.bold,
        ),
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: BouncingScrollPhysics(),
          itemCount: _items.length,
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
                      text: _items[index],
                      size: 12,
                      weight: FontWeight.w500,
                      color: kBlackColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AllFeatures extends StatelessWidget {
  const AllFeatures({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> items = [
      "airConditioning".tr,
      "alarm".tr,
      "digitalRadio".tr,
      "audioRemoteControl".tr,
      "airConditioning".tr,
      "alarm".tr,
      "digitalRadio".tr,
      "audioRemoteControl".tr,
      "airConditioning".tr,
      "alarm".tr,
      "digitalRadio".tr,
      "audioRemoteControl".tr,
      "airConditioning".tr,
      "alarm".tr,
      "digitalRadio".tr,
      "audioRemoteControl".tr,
      "airConditioning".tr,
      "alarm".tr,
      "digitalRadio".tr,
      "audioRemoteControl".tr,
      "airConditioning".tr,
      "alarm".tr,
      "digitalRadio".tr,
      "audioRemoteControl".tr,
    ];
    return Scaffold(
      appBar: simpleAppBar(title: "features".tr),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.DEFAULT,
        physics: BouncingScrollPhysics(),
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(items.length, (index) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: kWhiteColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(width: 1.0, color: kBorderColor),
                ),
                child: MyText(text: items[index], size: 12),
              );
            }),
          ),
        ],
      ),
    );
  }
}

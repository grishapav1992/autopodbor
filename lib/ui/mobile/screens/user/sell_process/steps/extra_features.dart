import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ExtraFeatures extends StatelessWidget {
  const ExtraFeatures({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> items = [
      "airConditioning".tr,
      "audioRemoteControl".tr,
      "bluetoothInterface".tr,
      "heatedDoorMirrors".tr,
      "immobilizer".tr,
      "3ZoneClimate".tr,
      "alarm".tr,
      "digitalRadio".tr,
      "frontFogLights".tr,
      "parkingSensors".tr,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          text: "carFeatures".tr,
          size: 14,
          paddingBottom: 8,
          weight: FontWeight.w600,
        ),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(items.length, (index) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: kWhiteColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(width: 1.0, color: kBorderColor),
              ),
              child: MyText(
                text: items[index],
                size: 12,
                weight: FontWeight.w500,
              ),
            );
          }),
        ),
      ],
    );
  }
}

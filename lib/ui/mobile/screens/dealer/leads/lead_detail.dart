import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LeadDetail extends StatelessWidget {
  const LeadDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: "leadsDetails".tr),
      body: ListView(
        padding: AppSizes.DEFAULT,
        physics: BouncingScrollPhysics(),
        shrinkWrap: true,
        children: [
          MyText(
            text: "contactDetails".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 12,
          ),
          Container(
            padding: AppSizes.DEFAULT,
            decoration: BoxDecoration(
              border: Border.all(color: kBorderColor, width: 1.0),
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                customColum(title: "name".tr, subtitle: 'Alaxandar John'),
                customColum(
                  title: "email".tr,
                  subtitle: 'пользователь@почта.рф',
                ),
                customColum(title: "postcode".tr, subtitle: 'IYE 4859'),
                customColum(
                  title: "phone".tr,
                  subtitle: '035689899098',
                  haveBorder: false,
                ),
              ],
            ),
          ),
          MyText(
            text: "leadDetails".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 12,
            paddingTop: 22,
          ),
          Container(
            padding: AppSizes.DEFAULT,
            decoration: BoxDecoration(
              border: Border.all(color: kBorderColor, width: 1.0),
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                customColum(title: "date".tr, subtitle: '08/08/2024'),
                customColum(title: "type".tr, subtitle: 'РџРѕС‡С‚Р°'),
                customColum(title: "leadSource".tr, subtitle: 'РџСЂРѕРґР°Р¶Рё Р°РІС‚Рѕ'),
                customColum(
                  title: "phone".tr,
                  subtitle: '035689899098',
                  haveBorder: false,
                ),
              ],
            ),
          ),
          MyText(
            text: "leadDetails".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 12,
            paddingTop: 22,
          ),
          Container(
            padding: AppSizes.DEFAULT,
            decoration: BoxDecoration(
              border: Border.all(color: kBorderColor, width: 1.0),
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                customColum(title: "date".tr, subtitle: '08/08/2024'),
                customColum(title: "type".tr, subtitle: 'РџРѕС‡С‚Р°'),
                customColum(title: "leadSource".tr, subtitle: 'РџСЂРѕРґР°Р¶Рё Р°РІС‚Рѕ'),
                customColum(
                  title: "phone".tr,
                  subtitle: '035689899098',
                  haveBorder: false,
                ),
              ],
            ),
          ),
          MyText(
            text: "vehicleSummary".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 12,
            paddingTop: 22,
          ),
          Container(
            padding: AppSizes.DEFAULT,
            decoration: BoxDecoration(
              border: Border.all(color: kBorderColor, width: 1.0),
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MyText(
                  text: 'Тойота Камри',
                  size: 16,
                  weight: FontWeight.w600,
                  paddingBottom: 7,
                ),
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  height: 1,
                  color: kBorderColor,
                ),
                customColum(
                  title: "reg".tr,
                  subtitle: 'E462634',
                  haveBorder: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Column customColum({
    String? title,
    String? subtitle,
    final bool? haveBorder = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          text: title ?? '',
          size: 16,
          paddingBottom: 6,
          weight: FontWeight.w600,
        ),
        MyText(
          text: subtitle ?? '',
          size: 14,
          weight: FontWeight.w500,
          color: kHintColor,
        ),
        if (haveBorder!)
          Container(
            height: 1,
            color: kBorderColor,
            margin: EdgeInsets.symmetric(vertical: 10),
          ),
      ],
    );
  }
}


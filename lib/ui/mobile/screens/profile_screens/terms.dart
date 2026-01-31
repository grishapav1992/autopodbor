import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Terms extends StatelessWidget {
  const Terms({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: "termsAndConditions".tr),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.listPaddingWithBottomBar(),
        physics: BouncingScrollPhysics(),
        children: [
          MyText(
            text: "introduction".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 8,
          ),
          MyText(
            text:
                "loremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididuntUtLaboreEtDoloreMagnaAliq"
                    .tr,
            size: 12,
            weight: FontWeight.w500,
            color: kGreyColor,
            lineHeight: 1.5,
            paddingBottom: 14,
          ),
          ...List.generate(3, (index) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  paddingTop: 3,
                  text: "".tr,
                  size: 12,
                  weight: FontWeight.w500,
                  color: kGreyColor,
                  lineHeight: 1.5,
                ),
                Expanded(
                  child: MyText(
                    paddingLeft: 10,
                    paddingBottom: 8,
                    text:
                        "loremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididunt"
                            .tr,
                    size: 12,
                    weight: FontWeight.w500,
                    color: kGreyColor,
                    lineHeight: 1.5,
                  ),
                ),
              ],
            );
          }),
          MyText(
            paddingTop: 10,
            text: "informationWeCollect".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 8,
          ),
          MyText(
            text:
                "loremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididuntUtLaboreEtDoloreMagnaAliq"
                    .tr,
            size: 12,
            weight: FontWeight.w500,
            color: kGreyColor,
            lineHeight: 1.5,
            paddingBottom: 14,
          ),
          ...List.generate(1, (index) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  paddingTop: 3,
                  text: "".tr,
                  size: 12,
                  weight: FontWeight.w500,
                  color: kGreyColor,
                  lineHeight: 1.5,
                ),
                Expanded(
                  child: MyText(
                    paddingLeft: 10,
                    paddingBottom: 8,
                    text:
                        "loremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididunt"
                            .tr,
                    size: 12,
                    weight: FontWeight.w500,
                    color: kGreyColor,
                    lineHeight: 1.5,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

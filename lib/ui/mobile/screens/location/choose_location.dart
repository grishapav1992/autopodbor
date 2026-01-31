import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/auth/login.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChooseLocation extends StatelessWidget {
  const ChooseLocation({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> items = [
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
    return Scaffold(
      appBar: simpleAppBar(title: "chooseYourLocation".tr),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              padding: AppSizes.listPaddingWithBottomBar(),
              physics: BouncingScrollPhysics(),
              children: [
                CustomDropDown(
                  labelText: "government".tr,
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
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: AppSizes.DEFAULT,
            child: MyButton(
              buttonText: "continue".tr,
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => Login()));
              },
            ),
          ),
        ],
      ),
    );
  }
}

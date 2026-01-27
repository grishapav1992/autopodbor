import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChangeLanguage extends StatelessWidget {
  const ChangeLanguage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> items = ["english".tr, "العربية".tr, "kurdish".tr];
    return Scaffold(
      appBar: simpleAppBar(title: 'Language'),
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MyText(
              text: "selectLanguage".tr,
              size: 14,
              weight: FontWeight.w600,
              paddingBottom: 8,
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Container(
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: kWhiteColor,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: items[index],
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        CustomRadio(isActive: index == 0, onTap: () {}),
                      ],
                    ),
                  );
                },
              ),
            ),
            MyButton(buttonText: "done".tr, onTap: () {}),
          ],
        ),
      ),
    );
  }
}

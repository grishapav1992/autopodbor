import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DescriptionPrice extends StatelessWidget {
  const DescriptionPrice({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyTextField(
          labelText: "description".tr,
          hintText: "writeDescriptionAboutYourCar".tr,
          maxLines: 6,
        ),
        MyText(
          onTap: () {
            Get.dialog(SuccessDialog());
          },
          text: "enterSellPriceOfYourCar".tr,
          size: 14,
          weight: FontWeight.w600,
          paddingBottom: 20,
        ),
        CustomDropDown(
          labelText: "selectCurrency".tr,
          hint: "dollars".tr,
          items: ['Рубли'],
          selectedValue: 'Рубли',
          onChanged: (v) {},
        ),
        CustomDropDown(
          labelText: "askingPrice".tr,
          hint: "enterPice".tr,
          items: ['Введите цену'],
          selectedValue: 'Введите цену',
          onChanged: (v) {},
        ),
      ],
    );
  }
}

class SuccessDialog extends StatelessWidget {
  const SuccessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          margin: AppSizes.DEFAULT,
          padding: AppSizes.DEFAULT,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: kWhiteColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(Assets.imagesAlert, height: 75),
              MyText(
                text: "carPriceSeemsWrong".tr,
                size: 20,
                textAlign: TextAlign.center,
                paddingTop: 16,
                weight: FontWeight.w600,
              ),
              MyText(
                text: "didYouMean".tr,
                textAlign: TextAlign.center,
                size: 16,
                color: kGreyColor,
                paddingTop: 8,
                weight: FontWeight.w500,
              ),
              MyText(
                text: '\$3215',
                size: 22,
                textAlign: TextAlign.center,
                paddingTop: 9,
                color: kSecondaryColor,
                paddingBottom: 20,
                weight: FontWeight.w700,
              ),
              Row(
                children: [
                  Expanded(
                    child: MyBorderButton(
                      buttonText: "back".tr,
                      radius: 10,
                      onTap: () {},
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: MyButton(
                      buttonText: "confirm".tr,
                      radius: 10,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}


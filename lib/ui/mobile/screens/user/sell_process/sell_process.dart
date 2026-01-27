import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/car_information.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/car_location.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/car_preview.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/description_price.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/extra_features.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/interior_details.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/paint_parts.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/technical_details.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/sell_process/steps/upload_images.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';

class SellProcess extends StatefulWidget {
  const SellProcess({super.key});

  @override
  State<SellProcess> createState() => _SellProcessState();
}

class _SellProcessState extends State<SellProcess> {
  int currentStep = 0;
  final List<Map<String, dynamic>> _steps = [
    {
      'title': "whereIsYourCar".tr,
      'subtitle': "selectCityOrDistrict".tr,
      'widget': CarLocation(),
    },
    {
      'title': "uploadImages".tr,
      'subtitle': "uploadImagesOfTheCarYouWantToSell".tr,
      'widget': UploadImages(),
    },
    {
      'title': "addCarInformation".tr,
      'subtitle': "selectInformation".tr,
      'widget': CarInformation(),
    },
    {
      'title': "addTechnicalDetails".tr,
      'subtitle': "selectCorrectDetails".tr,
      'widget': TechnicalDetails(),
    },
    {
      'title': "addInteriorDetails".tr,
      'subtitle': "selectCityOrDistrict".tr,
      'widget': InteriorDetails(),
    },
    {
      'title': "paintParts".tr,
      'subtitle': "selectIfCarIsDamaged".tr,
      'widget': PaintParts(),
    },
    {
      'title': "extraFeatures".tr,
      'subtitle': "selectFeaturesOfYourCar".tr,
      'widget': ExtraFeatures(),
    },
    {
      'title': "descriptionPrice".tr,
      'subtitle': "writeDescriptionAndEnterSellPrice".tr,
      'widget': DescriptionPrice(),
    },
  ];

  void nextStep() {
    setState(() {
      currentStep == _steps.length - 1
          ? Get.to(() => CarPreview())
          : currentStep++;
    });
  }

  void previousStep() {
    setState(() {
      currentStep == 0 ? Get.back() : currentStep--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20.0,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: previousStep,
              child: Image.asset(Assets.imagesArrowBackRounded, height: 32),
            ),
          ],
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: StepProgressIndicator(
            totalSteps: _steps.length,
            currentStep: currentStep + 1,
            size: 8,
            padding: 0,
            roundedEdges: Radius.circular(10),
            selectedGradientColor: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kSecondaryColor, kSecondaryColor],
            ),
            unselectedGradientColor: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kBorderColor, kBorderColor],
            ),
          ),
        ),
        actions: [
          Center(
            child: MyText(
              paddingLeft: 10,
              paddingRight: 20,
              text: '${currentStep + 1}/${_steps.length}',
              weight: FontWeight.w600,
              color: kSecondaryColor,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size(0, 1),
          child: Container(height: 1, color: kBorderColor),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              shrinkWrap: true,
              physics: BouncingScrollPhysics(),
              padding: AppSizes.DEFAULT,
              children: [
                MyText(
                  text: _steps[currentStep]['title'],
                  size: 20,
                  weight: FontWeight.w600,
                ),
                MyText(
                  text: _steps[currentStep]['subtitle'],
                  paddingTop: 8,
                  color: kHintColor,
                  weight: FontWeight.w500,
                  paddingBottom: 30,
                ),
                _steps[currentStep]['widget'],
              ],
            ),
          ),
          Padding(
            padding: AppSizes.DEFAULT,
            child: MyButton(buttonText: "continue".tr, onTap: nextStep),
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }
}

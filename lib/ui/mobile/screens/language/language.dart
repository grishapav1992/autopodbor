import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/core/utils/global_instances.dart';
import 'package:flutter_application_1/ui/mobile/screens/location/choose_location.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Language extends StatefulWidget {
  const Language({super.key});

  @override
  State<Language> createState() => _LanguageState();
}

class _LanguageState extends State<Language> {
  final List<String> languagesList = ['Русский', 'Английский'];

  void getLanguageIndex() async {
    languageController.currentIndex.value =
        await UserSimplePreferences.getLanguageIndex() ?? 0;
    languageController.isEnglish.value =
        languageController.currentIndex.value == 1;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<String> items = ['Русский', 'Английский'];
    return Scaffold(
      body: Padding(
        padding: AppSizes.DEFAULT,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MyText(
              paddingTop: 50,
              text: 'keyChooseLanguage'.tr,
              size: 32,
              weight: FontWeight.w600,
              textAlign: TextAlign.center,
              paddingBottom: 8,
            ),
            MyText(
              paddingLeft: 30,
              paddingRight: 30,
              text: 'keyChooseLanguageDescription'.tr,
              size: 14,
              lineHeight: 1.5,
              weight: FontWeight.w500,
              textAlign: TextAlign.center,
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(0, 50, 0, 0),
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
                        Obx(() {
                          return CustomRadio(
                            isActive:
                                languageController.currentIndex.value == index,
                            onTap: () {
                              languageController.onLanguageChanged(
                                languagesList[index],
                                index,
                              );
                            },
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
            MyButton(
              buttonText: 'continue'.tr,
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => ChooseLocation()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

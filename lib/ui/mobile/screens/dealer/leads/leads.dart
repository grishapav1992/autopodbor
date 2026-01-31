import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/leads/lead_detail.dart';
import 'package:flutter_application_1/ui/mobile/screens/notifications/notifications.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Leads extends StatelessWidget {
  const Leads({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(
        title: "leads".tr,
        actions: [
          Center(
            child: GestureDetector(
              onTap: () {
                Get.to(() => Notifications());
              },
              child: Image.asset(Assets.imagesNotificationIcon, height: 40),
            ),
          ),
          SizedBox(width: 20),
        ],
      ),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.listPaddingWithBottomBar(),
        physics: BouncingScrollPhysics(),
        children: [
          MyTextField(
            prefix: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Assets.imagesSearch,
                  height: 20,
                  color: kSecondaryColor,
                ),
              ],
            ),
            hintText: "search".tr,
          ),
          MyText(
            text: "50Leads".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 8,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 10,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Get.to(() => LeadDetail());
                },
                child: Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: AppSizes.DEFAULT,
                  decoration: BoxDecoration(
                    border: Border.all(width: 1.0, color: kBorderColor),
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MyText(
                        text: 'Александра Иванова',
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                      MyText(
                        paddingTop: 6,
                        text: 'Тойота Камри',
                        weight: FontWeight.w500,
                        color: kHintColor,
                      ),
                      MyText(
                        paddingTop: 10,
                        text: '30.07.2024, 10:20 • Почта',
                        size: 14,
                        weight: FontWeight.w500,
                        color: kHintColor,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

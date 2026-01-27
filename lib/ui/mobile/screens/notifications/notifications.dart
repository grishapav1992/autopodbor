import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Notifications extends StatelessWidget {
  const Notifications({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: "notifications".tr),
      body: ListView.builder(
        shrinkWrap: true,
        padding: AppSizes.DEFAULT,
        physics: BouncingScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyText(
                paddingBottom: 6,
                text: index == 0
                    ? "today".tr.toUpperCase()
                    : index == 1
                    ? "yesterday".tr.toUpperCase()
                    : "earlier".tr.toUpperCase(),
                size: 14,
                color: kGreyColor,
                weight: FontWeight.w500,
                paddingTop: index == 0 ? 0 : 16,
              ),
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: BouncingScrollPhysics(),
                itemCount: 4,
                itemBuilder: (context, nIndex) {
                  return _NotificationTile(
                    title: "notificationTitle".tr,
                    time: '2 minutes ago',
                    leading: dummyImg,
                    onTap: () {},
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.leading,
    required this.title,
    required this.time,
    required this.onTap,
  });
  final String title;
  final String leading;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: kWhiteColor,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CommonImageView(height: 38, width: 38, radius: 100, url: leading),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MyText(text: title, size: 14, weight: FontWeight.w600),
                MyText(text: time, size: 12, color: kGreyColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

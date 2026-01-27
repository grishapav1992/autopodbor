import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

AppBar simpleAppBar({
  bool haveLeading = true,
  String? title,
  bool? centerTitle = true,
  List<Widget>? actions,
}) {
  return AppBar(
    centerTitle: centerTitle,
    automaticallyImplyLeading: false,
    titleSpacing: 20.0,
    leading: haveLeading
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Image.asset(
                  Assets.imagesArrowBackRounded,
                  height: 32,
                ),
              ),
            ],
          )
        : null,
    title: MyText(text: title ?? '', size: 18, weight: FontWeight.w600),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: Size(0, 1),
      child: Container(height: 1, color: kBorderColor),
    ),
  );
}

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

AppBar simpleAppBar({
  bool haveLeading = true,
  String? title,
  bool? centerTitle = true,
  List<Widget>? actions,
  VoidCallback? onLeadingTap,
  bool sparkStyle = false,
}) {
  return AppBar(
    centerTitle: sparkStyle ? false : centerTitle,
    automaticallyImplyLeading: false,
    titleSpacing: sparkStyle
        ? (haveLeading ? 0 : SparkSpace.section)
        : 20.0,
    backgroundColor: sparkStyle ? kPrimaryColor : null,
    foregroundColor: sparkStyle ? kSecondaryColor : null,
    elevation: sparkStyle ? 0 : null,
    scrolledUnderElevation: sparkStyle ? 0 : null,
    surfaceTintColor: sparkStyle ? Colors.transparent : null,
    leading: haveLeading
        ? Builder(
            builder: (context) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    if (onLeadingTap != null) {
                      onLeadingTap();
                      return;
                    }
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop();
                      return;
                    }
                    if (Get.key.currentState?.canPop() == true) {
                      Get.back();
                    }
                  },
                  child: Image.asset(Assets.imagesArrowBackRounded, height: 32),
                ),
              ],
            ),
          )
        : null,
    title: sparkStyle
        ? MyText(
            text: title ?? '',
            size: SparkTextSize.titleLg,
            weight: FontWeight.w800,
            color: kSecondaryColor,
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
          )
        : MyText(
            text: title ?? '',
            size: 18,
            weight: FontWeight.w600,
          ),
    actions: actions,
    shape: sparkStyle
        ? const Border(
            bottom: BorderSide(
              color: kBorderColor,
              width: SparkSpace.hairline,
            ),
          )
        : null,
    bottom: sparkStyle
        ? null
        : PreferredSize(
            preferredSize: const Size(0, 1),
            child: Container(height: 1, color: kBorderColor),
          ),
  );
}

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class CustomCheckBox extends StatelessWidget {
  const CustomCheckBox({
    super.key,
    required this.isActive,
    required this.onTap,
    this.unSelectedColor,
  });

  final bool isActive;
  final VoidCallback onTap;
  final Color? unSelectedColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 230),
        curve: Curves.easeInOut,
        height: 20,
        width: 20,
        decoration: BoxDecoration(
          color: kSecondaryColor,
          borderRadius: BorderRadius.circular(7),
        ),
        child: !isActive
            ? SizedBox()
            : Icon(Icons.check, size: 16, color: kPrimaryColor),
      ),
    );
  }
}

// ignore: must_be_immutable
class CustomRadio extends StatelessWidget {
  const CustomRadio({
    super.key,
    required this.isActive,
    required this.onTap,
    this.unSelectedColor,
  });

  final bool isActive;
  final VoidCallback onTap;
  final Color? unSelectedColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 230),
        curve: Curves.easeInOut,
        height: 20,
        width: 20,
        decoration: BoxDecoration(
          color: kGreyColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(6),
            height: Get.height,
            width: Get.width,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? kSecondaryColor : kWhiteColor,
            ),
          ),
        ),
      ),
    );
  }
}

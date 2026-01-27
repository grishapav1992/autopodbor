import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'my_text_widget.dart';

// ignore: must_be_immutable
class MyButton extends StatelessWidget {
  MyButton({super.key, 
    required this.buttonText,
    required this.onTap,
    this.height = 48,
    this.textSize,
    this.weight,
    this.radius,
    this.customChild,
    this.bgColor,
    this.textColor,
  });

  final String buttonText;
  final VoidCallback onTap;
  double? height, textSize, radius;
  FontWeight? weight;
  Widget? customChild;
  Color? bgColor, textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? 8),
        color: bgColor ?? kSecondaryColor,
        border: Border.all(color: kSecondaryColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: kSecondaryColor.withValues(alpha: 0.08),
          highlightColor: kSecondaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(radius ?? 8),
          child: customChild ?? Center(
                  child: MyText(
                    text: buttonText,
                    size: textSize ?? 16,
                    weight: weight ?? FontWeight.w600,
                    color: textColor ?? kWhiteColor,
                  ),
                ),
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class MyBorderButton extends StatelessWidget {
  MyBorderButton({super.key, 
    required this.buttonText,
    required this.onTap,
    this.height = 48,
    this.textSize,
    this.weight,
    this.child,
    this.radius,
  });

  final String buttonText;
  final VoidCallback onTap;
  double? height, textSize;
  FontWeight? weight;
  Widget? child;
  double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius ?? 8),
        color: kInputBgColor,
        border: Border.all(width: 1.0, color: kBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: kSecondaryColor.withValues(alpha: 0.08),
          highlightColor: kSecondaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(radius ?? 8),
          child: child ?? Center(
                  child: MyText(
                    text: buttonText,
                    size: textSize ?? 16,
                    weight: weight ?? FontWeight.bold,
                    color: kSecondaryColor,
                  ),
                ),
        ),
      ),
    );
  }
}

class NextButton extends StatelessWidget {
  const NextButton({
    super.key,
    this.labelText,
    required this.hint,
    required this.onTap,
  });
  final String? labelText;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labelText != null)
          MyText(
            text: labelText ?? '',
            size: 14,
            color: kTertiaryColor,
            paddingBottom: 6,
            weight: FontWeight.bold,
          ),
        GestureDetector(
          onTap: onTap,
          child: Container(
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
                    text: hint,
                    size: 12,
                    weight: FontWeight.w500,
                    color: kTertiaryColor,
                  ),
                ),
                Image.asset(Assets.imagesArrowNext, height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

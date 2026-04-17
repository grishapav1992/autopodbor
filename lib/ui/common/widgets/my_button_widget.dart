import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_responsive.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';
import 'my_text_widget.dart';

// ignore: must_be_immutable
class MyButton extends StatelessWidget {
  MyButton({
    super.key,
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
    final effectiveHeight = AppResponsive.dp(
      context,
      height ?? SparkSize.inputHeight,
      min: SparkSize.actionHeight,
      max: 60,
    );
    final effectiveRadius = AppResponsive.dp(
      context,
      radius ?? SparkRadius.sm,
      min: SparkRadius.xs,
      max: SparkRadius.xxl,
    );
    final effectiveTextSize = textSize ?? SparkTextSize.title;
    return Container(
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        color: bgColor ?? kSecondaryColor,
        border: Border.all(color: kSecondaryColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: kSecondaryColor.withValues(alpha: 0.08),
          highlightColor: kSecondaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(effectiveRadius),
          child:
              customChild ??
              Center(
                child: MyText(
                  text: buttonText,
                  size: effectiveTextSize,
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
  MyBorderButton({
    super.key,
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
    final effectiveHeight = AppResponsive.dp(
      context,
      height ?? SparkSize.inputHeight,
      min: SparkSize.actionHeight,
      max: 60,
    );
    final effectiveRadius = AppResponsive.dp(
      context,
      radius ?? SparkRadius.sm,
      min: SparkRadius.xs,
      max: SparkRadius.xxl,
    );
    final effectiveTextSize = textSize ?? SparkTextSize.title;
    return Container(
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        color: kInputBgColor,
        border: Border.all(width: 1.0, color: kBorderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: kSecondaryColor.withValues(alpha: 0.08),
          highlightColor: kSecondaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(effectiveRadius),
          child:
              child ??
              Center(
                child: MyText(
                  text: buttonText,
                  size: effectiveTextSize,
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
    final effectiveHeight = AppResponsive.dp(
      context,
      SparkSize.inputHeight,
      min: SparkSize.actionHeight,
      max: 60,
    );
    final effectiveHorizontalPadding = AppResponsive.dp(
      context,
      15,
      min: SparkSpace.xl,
      max: SparkSize.iconLg,
    );
    final effectiveRadius = AppResponsive.dp(
      context,
      SparkRadius.sm,
      min: SparkRadius.xs,
      max: SparkRadius.xxl,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labelText != null)
          MyText(
            text: labelText ?? '',
            size: SparkTextSize.label,
            color: kTertiaryColor,
            paddingBottom: SparkSpace.sm,
            weight: FontWeight.bold,
          ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: effectiveHeight,
            padding: EdgeInsets.symmetric(
              horizontal: effectiveHorizontalPadding,
            ),
            decoration: BoxDecoration(
              color: kWhiteColor,
              border: Border.all(width: 1.0, color: kBorderColor),
              borderRadius: BorderRadius.circular(effectiveRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: MyText(
                    text: hint,
                    size: SparkTextSize.body,
                    weight: FontWeight.w500,
                    color: kTertiaryColor,
                  ),
                ),
                Image.asset(Assets.imagesArrowNext, height: SparkSize.iconSm),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

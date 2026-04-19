import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_responsive.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/app_fonts.dart';

// ignore: must_be_immutable
class MyText extends StatelessWidget {
  // ignore: prefer_typing_uninitialized_variables
  final String text;
  final String? fontFamily;
  final TextAlign? textAlign;
  final TextDecoration decoration;
  final FontWeight? weight;
  final TextOverflow? textOverflow;
  final Color? color;
  final FontStyle? fontStyle;
  final VoidCallback? onTap;

  final int? maxLines;
  final double? size;
  final double? lineHeight;
  final double? paddingTop;
  final double? paddingLeft;
  final double? paddingRight;
  final double? paddingBottom;
  final double? letterSpacing;
  final bool tracking;
  final bool tabularFigures;

  const MyText({
    super.key,
    required this.text,
    this.size,
    this.lineHeight,
    this.maxLines = 100,
    this.decoration = TextDecoration.none,
    this.color,
    this.letterSpacing,
    this.weight = FontWeight.w400,
    this.textAlign,
    this.textOverflow,
    this.fontFamily,
    this.paddingTop = 0,
    this.paddingRight = 0,
    this.paddingLeft = 0,
    this.paddingBottom = 0,
    this.onTap,
    this.fontStyle,
    this.tracking = false,
    this.tabularFigures = false,
  });

  @override
  Widget build(BuildContext context) {
    final scaledTop = AppResponsive.dp(
      context,
      paddingTop ?? 0,
      min: 0,
      max: 48,
    );
    final scaledLeft = AppResponsive.dp(
      context,
      paddingLeft ?? 0,
      min: 0,
      max: 48,
    );
    final scaledRight = AppResponsive.dp(
      context,
      paddingRight ?? 0,
      min: 0,
      max: 48,
    );
    final scaledBottom = AppResponsive.dp(
      context,
      paddingBottom ?? 0,
      min: 0,
      max: 48,
    );
    final scaledSize = size == null ? null : AppResponsive.sp(context, size!);
    final resolvedLetterSpacing = letterSpacing ?? (tracking ? -0.4 : null);
    final resolvedFeatures = tabularFigures
        ? const [FontFeature.tabularFigures()]
        : null;
    return Padding(
      padding: EdgeInsets.only(
        top: scaledTop,
        left: scaledLeft,
        right: scaledRight,
        bottom: scaledBottom,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(
            fontSize: scaledSize,
            color: color ?? kTertiaryColor,
            fontWeight: weight,
            decoration: decoration,
            fontFamily: fontFamily ?? AppFonts.URBANIST,
            fontFamilyFallback: const [
              'SF Pro Text',
              'Helvetica',
              'Roboto',
              'Arial',
              'Noto Sans',
              'sans-serif',
            ],
            height: lineHeight,
            fontStyle: fontStyle,
            letterSpacing: resolvedLetterSpacing,
            fontFeatures: resolvedFeatures,
          ),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: textOverflow,
        ),
      ),
    );
  }
}

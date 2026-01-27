import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';

// ignore: non_constant_identifier_names
FlutterSliderTooltip CustomSliderToolTip() {
  return FlutterSliderTooltip(
    textStyle: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: kBlackColor,
    ),
    boxStyle: FlutterSliderTooltipBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: kWhiteColor,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 3.83),
            blurRadius: 5.74,
            spreadRadius: -1.91,
            color: kQuaternaryColor.withValues(alpha: 0.03),
          ),
          BoxShadow(
            offset: Offset(0, 11.48),
            blurRadius: 15.3,
            spreadRadius: -3.83,
            color: kQuaternaryColor.withValues(alpha: 0.08),
          ),
        ],
      ),
    ),
  );
}

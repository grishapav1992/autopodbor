import 'package:flutter/material.dart';

class AppResponsive {
  AppResponsive._();

  static const double _baseWidth = 390;

  static double _screenScale(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width <= 0 ? _baseWidth : size.width;
    final raw = width / _baseWidth;
    return raw.clamp(0.9, 1.2);
  }

  static double dp(
    BuildContext context,
    double value, {
    double? min,
    double? max,
  }) {
    final scaled = value * _screenScale(context);
    final lower = min ?? value * 0.9;
    final upper = max ?? value * 1.2;
    return scaled.clamp(lower, upper);
  }

  static double sp(
    BuildContext context,
    double value, {
    double? min,
    double? max,
  }) {
    final scaled = value * _screenScale(context);
    final lower = min ?? value * 0.92;
    final upper = max ?? value * 1.18;
    return scaled.clamp(lower, upper);
  }
}

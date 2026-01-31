import 'package:flutter/material.dart';

class AppSizes {
  // ignore: constant_identifier_names
  static const DEFAULT = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  // ignore: constant_identifier_names
  static const HORIZONTAL = EdgeInsets.symmetric(horizontal: 20);
  // ignore: constant_identifier_names
  static const VERTICAL = EdgeInsets.symmetric(vertical: 16);

  static EdgeInsets listPaddingWithBottomBar({double bottom = 96}) {
    return DEFAULT.copyWith(bottom: bottom);
  }
}

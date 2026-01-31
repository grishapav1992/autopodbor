import 'package:flutter/foundation.dart';

class AppFonts {
  // ignore: non_constant_identifier_names
  static String get URBANIST {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'SF Pro Text';
      default:
        return 'Roboto';
    }
  }

  // ignore: non_constant_identifier_names
  static get GLACIAL_INDIFFERENCE => null;
}

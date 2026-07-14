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

  /// Моноширинный шрифт для полей VIN / госномера. В отличие от системного
  /// San Francisco (в котором цифры по дизайну ниже заглавных букв, из-за
  /// чего КАПС-VIN выглядит «буквы больше цифр»), в моноширинных цифры и
  /// заглавные буквы одной высоты и ширины. Menlo гарантированно есть на
  /// iOS/macOS, `monospace` резолвится в Roboto Mono на Android.
  // ignore: non_constant_identifier_names
  static String get MONOSPACE {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'Menlo';
      default:
        return 'monospace';
    }
  }
}

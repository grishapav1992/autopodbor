/// Design tokens — the single source of truth for spacing, radii, text sizes,
/// fixed component sizes and motion durations used across the UI.
///
/// Originally authored for the Spark design system that lives under
/// `lib/ui/mobile/screens/dealer/spark_joy/`. Now hoisted to core/constants so
/// that common widgets (buttons, dropdowns, cards) can consume the same tokens
/// without taking a feature-folder dependency.
///
/// The Spark-prefixed class names are preserved intentionally — the tokens are
/// used in dozens of spark_joy screens and renaming them all is a bigger
/// refactor than this change warrants.
abstract final class SparkSpace {
  static const double hairline = 1;
  static const double xxs = 2;
  static const double xxxs = 3;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double xxxl = 16;
  static const double chipX = 18;
  static const double section = 20;
}

abstract final class SparkRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 16;
  static const double xxl = 14;
  static const double xl = 16;
  static const double sheet = 24;
  static const double pill = 999;
}

abstract final class SparkTextSize {
  static const double chip = 10;
  static const double caption = 11;
  static const double body = 12;
  static const double bodyLg = 13;
  static const double label = 14;
  static const double sectionTitle = 15;
  static const double title = 16;
  static const double titleLg = 18;
  static const double modalTitle = 20;
  static const double pageTitle = 22;
  static const double hero = 26;
}

abstract final class SparkSize {
  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 18;
  static const double iconLg = 20;
  static const double iconXl = 24;
  static const double iconXxl = 26;
  static const double icon3xl = 36;
  static const double icon4xl = 40;
  static const double icon5xl = 44;
  static const double icon6xl = 56;
  static const double iconState = 34;
  static const double stepBadge = 28;
  static const double navStepBadge = 36;
  static const double avatarSm = 42;
  static const double spinner = 18;
  static const double spinnerLg = 22;
  static const double inputHeight = 48;
  static const double inputHeightLg = 52;
  static const double actionHeightSm = 38;
  static const double actionHeightMd = 40;
  static const double actionHeight = 44;
  static const double actionCompactHeight = 30;
  static const double modalActionHeight = 42;
  static const double modalActionSecondaryWidth = 98;
  static const double modalActionPrimaryWidth = 108;
  static const double progressThin = 6;
  static const double progress = 8;
  static const double modalNarrow = 320;
  static const double modalWide = 420;
  static const double modalTall = 460;
  static const double mediaPreviewHeight = 220;
  static const double mediaLightboxFab = 62;
  static const double mediaCardThumb = 112;
  static const double mediaThumb = 74;
  static const double authLogo = 70;
  static const double stateTopLoading = 30;
  static const double stateTopEmpty = 32;
  static const double stateTopError = 24;
  static const double listBottomInset = 96;
  static const double pageBottomInset = 24;
}

abstract final class SparkMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration regular = Duration(milliseconds: 180);
}

// Shared test harness for Spark widget + golden tests.
//
// Centralises the boilerplate (real `lightTheme`, optional
// `SparkShellInsets`, `MediaQuery` sizing, `loadAppFonts` once per suite)
// so individual test files stay focused on their widget under test.
//
// Used by:
//   - test/widgets/spark_widgets_golden_test.dart
//   - test/screens/profile_edit_mode_test.dart
//   - future widget-level tests
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/config/theme/light_theme.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device configurations used for every golden-test run.
///
/// iPhone SE 2020 (A13) — the perf-floor target called out in the A+ Frost
/// brief. Pixel 4a (Snapdragon 730G) sits roughly at the Android floor; its
/// 2.625x DPR catches rendering quirks iOS 3x doesn't surface.
///
/// Added size + textScale so font-scaling regressions show up alongside
/// layout ones.
final List<Device> sparkGoldenDevices = <Device>[
  const Device(
    name: 'iphone_se_2020',
    size: Size(375, 667),
    devicePixelRatio: 3,
    textScale: 1,
  ),
  const Device(
    name: 'pixel_4a',
    size: Size(393, 851),
    devicePixelRatio: 2.625,
    textScale: 1,
  ),
];

/// Wraps [child] in the minimum tree Spark widgets need in tests.
///
/// Mirrors `lib/app/main.dart`'s `GetMaterialApp` config but with the noise
/// trimmed: real `lightTheme`, no routing, no localisation controller, no
/// GetX. If a widget pulls `SparkShellInsets` via
/// `SparkShellInsets.maybeOf(context)`, pass [shellInsets]; otherwise leave
/// null so the widget takes its non-shell default (0 top/bottom inset).
///
/// [size] overrides the `MediaQuery.size`. Default mirrors iPhone SE 2020
/// so ad-hoc `testWidgets` calls see the same viewport goldens do.
Widget wrapWithSparkHarness({
  required Widget child,
  Size size = const Size(375, 667),
  EdgeInsets mediaPadding = EdgeInsets.zero,
  SparkShellInsets? shellInsets,
}) {
  Widget body = child;
  if (shellInsets != null) {
    body = SparkShellInsets(
      topInset: shellInsets.topInset,
      bottomInset: shellInsets.bottomInset,
      child: body,
    );
  }
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: lightTheme,
    home: MediaQuery(
      data: MediaQueryData(size: size, padding: mediaPadding),
      child: Material(color: lightTheme.scaffoldBackgroundColor, child: body),
    ),
  );
}

/// Pumps [child] through [wrapWithSparkHarness] and settles the animation
/// clock so tests can immediately assert without awaiting each time.
Future<void> pumpSparkWidget(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(375, 667),
  EdgeInsets mediaPadding = EdgeInsets.zero,
  SparkShellInsets? shellInsets,
}) async {
  await tester.pumpWidget(
    wrapWithSparkHarness(
      child: child,
      size: size,
      mediaPadding: mediaPadding,
      shellInsets: shellInsets,
    ),
  );
  await tester.pumpAndSettle();
}

/// Resets `shared_preferences` between tests. Mirrors the pattern already
/// used in [`test/spark_joy_storage_test.dart`] — lifted here so future
/// tests don't duplicate the 3-line dance.
Future<void> resetSparkPreferences([
  Map<String, Object> initial = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  UserSimplePreferences.pref = null;
  await UserSimplePreferences.init();
}

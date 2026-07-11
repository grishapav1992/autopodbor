import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('content sheet stays bottom-aligned at content height', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    const contentKey = Key('content-sheet-body');

    await tester.pumpWidget(
      _SheetTestApp(
        onOpen: (context) => showAppAdaptiveBottomSheet<void>(
          context: context,
          extent: AppBottomSheetExtent.content,
          builder: (_) => const SizedBox(key: contentKey, height: 120),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(contentKey));
    expect(rect.height, 120);
    expect(rect.bottom, closeTo(800, 1));
  });

  testWidgets('expanded sheet uses almost all available height', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    const contentKey = Key('expanded-sheet-body');

    await tester.pumpWidget(
      _SheetTestApp(
        onOpen: (context) => showAppAdaptiveBottomSheet<void>(
          context: context,
          extent: AppBottomSheetExtent.expanded,
          builder: (_) => const SizedBox.expand(key: contentKey),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(contentKey));
    expect(rect.height, greaterThan(700));
    expect(rect.bottom, closeTo(800, 1));
  });

  testWidgets('sheet background covers the bottom safe-area inset', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    const contentKey = Key('safe-area-sheet-body');

    await tester.pumpWidget(
      _SheetTestApp(
        onOpen: (context) => showAppAdaptiveBottomSheet<void>(
          context: context,
          extent: AppBottomSheetExtent.content,
          builder: (_) => const SizedBox(key: contentKey, height: 120),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    final surfaceRect = tester.getRect(
      find.byKey(appAdaptiveBottomSheetSurfaceKey),
    );
    final contentRect = tester.getRect(find.byKey(contentKey));
    expect(surfaceRect.bottom, closeTo(800, 1));
    expect(contentRect.bottom, closeTo(766, 1));
  });
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _SheetTestApp extends StatelessWidget {
  const _SheetTestApp({required this.onOpen});

  final Future<dynamic> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => onOpen(context),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
  }
}

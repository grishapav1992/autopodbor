import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_create_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/spark_test_harness.dart';

void main() {
  testWidgets('после подтверждения галереи показывает индикатор импорта', (
    tester,
  ) async {
    await resetSparkPreferences();
    final picker = Completer<List<UploadedItem>>();

    await tester.pumpWidget(
      wrapWithSparkHarness(
        size: const Size(800, 1400),
        child: SparkJoyCreateReportScreen(
          draft: const {'id': 'intake_import_progress_test'},
          intakeMediaPicker: () => picker.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openIntake = find.text('Загрузить материалы');
    await tester.ensureVisible(openIntake);
    await tester.tap(openIntake);
    await tester.pumpAndSettle();
    expect(find.text('Материалы автомобиля'), findsWidgets);

    await tester.tap(find.text('Фото и видео'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('intake-import-progress')),
      findsOneWidget,
    );
    expect(find.text('Добавляем выбранные файлы…'), findsOneWidget);

    picker.complete(const []);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('intake-import-progress')), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_create_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/spark_test_harness.dart';

Future<void> _openVehicleSection(
  WidgetTester tester,
  Map<String, dynamic> draft,
) async {
  await resetSparkPreferences();
  await tester.pumpWidget(
    wrapWithSparkHarness(
      size: const Size(800, 1400),
      child: SparkJoyCreateReportScreen(draft: draft),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Автомобиль').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('один VIN не завершает раздел Автомобиль', (tester) async {
    await _openVehicleSection(tester, const {
      'id': 'vehicle_vin_only_test',
      'vin': 'TESTVIN',
    });

    expect(find.text('В работе'), findsOneWidget);
    expect(find.textContaining('Укажите пробег'), findsOneWidget);
    expect(find.textContaining('Укажите город осмотра'), findsOneWidget);
  });

  testWidgets('VIN, пробег и город завершают раздел Автомобиль', (
    tester,
  ) async {
    await _openVehicleSection(tester, const {
      'id': 'vehicle_complete_test',
      'vin': 'TESTVIN',
      'mileage': '100000',
      'inspectionCity': 'Москва',
    });

    expect(find.text('Заполнено'), findsOneWidget);
    expect(find.textContaining('Укажите пробег'), findsNothing);
    expect(find.textContaining('Укажите город осмотра'), findsNothing);
  });
}

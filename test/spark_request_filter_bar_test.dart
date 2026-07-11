import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_filter_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('request statuses stay inside the compact filter sheet', (
    tester,
  ) async {
    var selected = RequestStatusFilter.all;
    var query = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SparkJoyRequestFilterBar(
            value: selected,
            onQueryChanged: (value) => query = value,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Новые'), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'REQ-42');
    expect(query, 'REQ-42');

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Фильтры'), findsOneWidget);
    expect(find.text('Новые'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.text('Завершены'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.tap(find.text('В работе'));
    await tester.tap(find.text('Показать заявки'));
    await tester.pumpAndSettle();

    expect(selected, RequestStatusFilter.inProgress);
  });
}

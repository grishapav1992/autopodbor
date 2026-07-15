import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_filter_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('request statuses are inline and apply immediately', (
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

    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Новые'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
    expect(find.text('Фильтр заявок'), findsNothing);
    expect(find.text('Применить'), findsNothing);
    expect(find.text('Сбросить'), findsNothing);

    await tester.enterText(find.byType(TextField), 'REQ-42');
    expect(query, 'REQ-42');

    expect(
      find.byKey(const ValueKey('request-filter-inProgress')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('request-filter-inProgress')));
    await tester.pump();

    expect(selected, RequestStatusFilter.inProgress);
  });
}

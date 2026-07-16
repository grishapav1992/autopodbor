import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_filter_bar.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('status pill opens menu with 4 categories and applies instantly', (
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

    // Одна строка: поиск + пилюля; чипов и старого шита нет.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('request-filter-pill')), findsOneWidget);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Активные'), findsNothing);
    expect(find.text('Фильтр заявок'), findsNothing);
    expect(find.text('Применить'), findsNothing);
    expect(find.text('Сбросить'), findsNothing);

    await tester.enterText(find.byType(TextField), 'REQ-42');
    expect(query, 'REQ-42');

    await tester.tap(find.byKey(const ValueKey('request-filter-pill')));
    await tester.pumpAndSettle();

    expect(find.text('Все'), findsNWidgets(2)); // пилюля + пункт меню
    expect(find.text('Активные'), findsOneWidget);
    expect(find.text('Завершены'), findsOneWidget);
    expect(find.text('Отменены'), findsOneWidget);
    expect(find.text('Черновики'), findsNothing);
    expect(find.text('Новые'), findsNothing);
    expect(find.text('В работе'), findsNothing);
    expect(find.text('Не выполнены'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('request-filter-active')));
    await tester.pumpAndSettle();

    expect(selected, RequestStatusFilter.active);
    expect(find.text('Завершены'), findsNothing); // меню закрылось
  });

  test('filter buckets cover all backend statuses without overlap', () {
    expect(RequestStatusFilter.values, hasLength(4));
    expect(RequestStatusFilter.all.statuses, isEmpty);
    expect(RequestStatusFilter.active.statuses, {
      'created',
      'await_payment',
      'paid_escrow',
      'in_work',
    });
    expect(RequestStatusFilter.done.statuses, {'done'});
    expect(RequestStatusFilter.canceled.statuses, {
      'canceled',
      'refund',
      'failed',
    });
  });
}

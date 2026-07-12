import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_detail_ui.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('sparkRequestDetailSubtitle', () {
    test('срок того же года — без года, как в макете', () {
      expect(
        sparkRequestDetailSubtitle(
          createdAt: '2026-05-27T19:54:00',
          dueAt: '2026-06-03',
        ),
        '27.05.2026 · срок до 03.06',
      );
    });

    test('срок другого года — с полной датой', () {
      expect(
        sparkRequestDetailSubtitle(
          createdAt: '2026-12-27T19:54:00',
          dueAt: '2027-01-03',
        ),
        '27.12.2026 · срок до 03.01.2027',
      );
    });

    test('без срока — только дата создания', () {
      expect(
        sparkRequestDetailSubtitle(createdAt: '2026-05-27', dueAt: ''),
        '27.05.2026',
      );
    });

    test('пустые входы — пустая строка', () {
      expect(sparkRequestDetailSubtitle(createdAt: '', dueAt: ''), '');
    });
  });

  test('sparkFormatRuDateTime разделяет дату и время запятой', () {
    expect(sparkFormatRuDateTime('2026-05-28T11:10:00'), '28.05.2026, 11:10');
  });

  group('sparkCancelUnavailableLabel', () {
    test('маппит финальные и рабочие статусы', () {
      expect(
        sparkCancelUnavailableLabel('done'),
        'Отменить заявку недоступно — заявка завершена',
      );
      expect(
        sparkCancelUnavailableLabel('canceled'),
        'Отменить заявку недоступно — заявка отменена',
      );
      expect(
        sparkCancelUnavailableLabel('in_work'),
        'Отменить заявку недоступно — заявка уже в работе',
      );
    });

    test('неизвестный статус — общий текст про отмену', () {
      expect(
        sparkCancelUnavailableLabel('something_new'),
        'Отмена доступна только до оплаты или начала работы',
      );
    });
  });

  testWidgets('SparkRequestDetailAppBar показывает номер, даты и статус', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SparkRequestDetailAppBar(
            title: 'Заявка №169959',
            subtitle: '27.05.2026 · срок до 03.06',
            badge: (
              label: 'Завершена',
              bg: Colors.green.shade50,
              fg: Colors.green,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Заявка №169959'), findsOneWidget);
    expect(find.text('27.05.2026 · срок до 03.06'), findsOneWidget);
    expect(find.text('Завершена'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('request_status_chip'))).height,
      lessThan(40),
    );
  });

  testWidgets('длинный статус не ломает узкий экран и крупный шрифт', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            appBar: SparkRequestDetailAppBar(
              title: 'Заявка №169959',
              badge: requestHistoryStatusBadge('specialist_reassigned'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('request_status_chip'))).width,
      lessThanOrEqualTo(134.5),
    );
  });

  testWidgets('таймлайн истории: статус, роль с датой и комментарий в плашке', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SparkRequestHistoryTimeline(
          entries: const [
            {
              'newStatus': 'done',
              'changedByRole': 'specialist',
              'reason': 'request_completed',
              'createdAt': '2026-05-28T11:10:00',
            },
            {
              'newStatus': 'in_work',
              'changedByRole': 'specialist',
              'reason': 'specialist_accepted:Харачо буду делать',
              'createdAt': '2026-05-27T19:55:00',
            },
            {
              'newStatus': 'created',
              'changedByRole': 'company',
              'createdAt': '2026-05-27T19:54:00',
            },
          ],
        ),
      ),
    );

    // Заголовки событий — человекочитаемые статусы, без «old → new».
    expect(find.text('Завершена'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.text('Создана'), findsOneWidget);
    // Мета «Роль · дата, время» с запятой между датой и временем.
    expect(find.text('Специалист · 28.05.2026, 11:10'), findsOneWidget);
    expect(find.text('Компания · 27.05.2026, 19:54'), findsOneWidget);
    // Пояснение причины и комментарий в кавычках-ёлочках.
    expect(find.text('Специалист принял заявку'), findsOneWidget);
    expect(find.text('«Харачо буду делать»'), findsOneWidget);
  });

  testWidgets('карточка авто: название, поколение с городом, телефон клиента', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SparkRequestCarBlock(
          car: const {
            'brand': {'name': 'Ford'},
            'model': {'model': 'Escape'},
            'generation': 3,
            'phone': '+7 946 494-66-46',
          },
          city: 'Чистые Боры',
        ),
      ),
    );

    expect(find.text('Ford Escape'), findsOneWidget);
    expect(find.text('Поколение 3 · Чистые Боры'), findsOneWidget);
    expect(find.text('Телефон клиента'), findsOneWidget);
    expect(find.text('+7 946 494-66-46'), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsNothing);
  });

  testWidgets('карточка авто без телефона и ссылки — без блока контактов', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SparkRequestCarBlock(
          car: const {'brand': 'Hyundai', 'model': 'Solaris'},
        ),
      ),
    );

    expect(find.text('Hyundai Solaris'), findsOneWidget);
    expect(find.text('Телефон клиента'), findsNothing);
    expect(find.byIcon(Icons.call_rounded), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });
}

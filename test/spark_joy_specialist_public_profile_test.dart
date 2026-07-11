import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_specialist_public_profile_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('SparkJoySpecialistPublicProfileScreen (initialProfile, без сети)', () {
    testWidgets('рендерит ФИО, город, контакты и рейтинг из initialProfile', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SparkJoySpecialistPublicProfileScreen(
            // specialistId нет → RPC не дёргается, экран живёт на данных
            // заявки (как при открытии из деталей заявки офлайн).
            initialProfile: {
              'lastName': 'Иванов',
              'firstName': 'Пётр',
              'middleName': 'Сергеевич',
              'city': 'Краснодар',
              'phone': '+7 (900) 123-45-67',
              'email': 'ivanov@example.com',
              'rating': 4.5,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Профиль специалиста'), findsOneWidget);
      // ФИО собирается в порядке Фамилия Имя Отчество.
      expect(find.text('Иванов Пётр Сергеевич'), findsOneWidget);
      expect(find.text('Краснодар'), findsWidgets);
      expect(find.text('+7 (900) 123-45-67'), findsOneWidget);
      expect(find.text('ivanov@example.com'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      // Телефон — действие «позвонить», а не переход: иконка трубки есть,
      // шеврона у строки телефона нет.
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    });

    testWidgets('фолбэк на одиночный ключ name (payload отчёта)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SparkJoySpecialistPublicProfileScreen(
            initialProfile: {'name': 'Мария Осмотрова'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Мария Осмотрова'), findsOneWidget);
    });

    testWidgets('совсем без данных — заглушка, а не краш', (tester) async {
      await tester.pumpWidget(
        _wrap(const SparkJoySpecialistPublicProfileScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Специалист'), findsOneWidget);
      expect(
        find.text('Специалист пока не заполнил публичную информацию'),
        findsOneWidget,
      );
    });
  });

  group('SparkInfoRow.onTap', () {
    testWidgets('тап по value вызывает колбэк', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SparkInfoRow(
              label: 'Исполнитель',
              value: 'Иванов Пётр',
              onTap: () => tapped++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Иванов Пётр'));
      expect(tapped, 1);
    });

    testWidgets('без onTap строка остаётся статичной (нет InkWell)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Scaffold(
            body: SparkInfoRow(label: 'Создан', value: '01.07.2026'),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(SparkInfoRow),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });
  });

  group('SparkProfileRow.showChevron', () {
    testWidgets('showChevron: false прячет шеврон у тапабельной строки', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SparkProfileRow(
              icon: Icons.phone_outlined,
              label: 'Телефон',
              value: '+7 (900) 000-00-00',
              onTap: () {},
              showChevron: false,
              trailing: const Icon(Icons.call_rounded),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    });

    testWidgets('по умолчанию шеврон у тапабельной строки остаётся', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: SparkProfileRow(
              icon: Icons.description_outlined,
              label: 'Описание услуг',
              value: 'Осмотры',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}

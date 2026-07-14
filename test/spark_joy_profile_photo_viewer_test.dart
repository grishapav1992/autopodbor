import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_company_public_profile_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_company_staff_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('фото компании открывается на весь экран', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SparkJoyCompanyPublicProfileScreen(
          initialProfile: {
            'companyName': 'Авто Эксперт',
            'urlAvatar': 'https://example.com/company.jpg',
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('company-avatar-preview')));
    await tester.pumpAndSettle();

    expect(find.text('Фото компании'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Профиль компании'), findsOneWidget);
  });

  testWidgets('фото сотрудника в карточке штата открывается полностью', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SparkJoyCompanyStaffDetailScreen(
          specialist: {
            'name': 'Мария Осмотрова',
            'urlAvatar': 'https://example.com/specialist.jpg',
          },
          requests: [],
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('staff-avatar-preview')));
    await tester.pumpAndSettle();

    expect(find.text('Фото сотрудника'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('профиль сотрудника показывает description как описание услуг', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        const SparkJoyCompanyStaffDetailScreen(
          specialist: {
            'name': 'Мария Осмотрова',
            'description': 'Осмотр кузова и диагностика',
          },
          requests: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ДАННЫЕ ПРОФИЛЯ'), findsOneWidget);
    expect(find.text('Описание услуг'), findsOneWidget);
    expect(find.text('Осмотр кузова и диагностика'), findsWidgets);
  });

  testWidgets('пустой публичный профиль компании скрывает раздел', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SparkJoyCompanyPublicProfileScreen(
          initialProfile: {'companyName': 'Авто Эксперт'},
        ),
      ),
    );

    expect(find.text('ИНФОРМАЦИЯ'), findsNothing);
    expect(find.text('Описание'), findsNothing);
  });

  testWidgets('публичный профиль компании показывает описание', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        const SparkJoyCompanyPublicProfileScreen(
          initialProfile: {
            'companyName': 'Авто Эксперт',
            'description': 'Подбор и проверка автомобилей',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ИНФОРМАЦИЯ'), findsOneWidget);
    expect(find.text('Описание'), findsOneWidget);
    expect(find.text('Подбор и проверка автомобилей'), findsOneWidget);
  });

  testWidgets('сервер может очистить старое описание компании', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SparkJoyCompanyPublicProfileScreen(
          companyId: 7,
          initialProfile: const {
            'companyName': 'Авто Эксперт',
            'description': 'Устаревшее описание',
          },
          profileLoader: (_) async => const {
            'companyName': 'Авто Эксперт',
            'description': null,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Устаревшее описание'), findsNothing);
    expect(find.text('ИНФОРМАЦИЯ'), findsNothing);
  });

  testWidgets('ошибка полного профиля сотрудника видна и допускает повтор', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        SparkJoyCompanyStaffDetailScreen(
          specialist: const {'id': 9, 'name': 'Мария Осмотрова'},
          requests: const [],
          profileLoader: (_) async {
            calls += 1;
            if (calls == 1) throw Exception('offline');
            return const {
              'id': 9,
              'firstName': 'Мария',
              'lastName': 'Осмотрова',
              'description': 'Диагностика после повторной загрузки',
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Не удалось загрузить полные данные сотрудника'),
      findsOneWidget,
    );
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Диагностика после повторной загрузки'), findsWidgets);
    expect(find.text('Повторить'), findsNothing);
    expect(calls, 2);
  });
}

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
}

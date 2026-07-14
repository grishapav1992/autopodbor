import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_invite_by_phone_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('модальное окно не показывает лишнюю подсказку под полем', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SparkJoyInviteByPhoneDialog(
            onLookup: (_) async => const InvitePhoneLookupResult.notFound(),
            onInvite: (_) async => '',
          ),
        ),
      ),
    );

    expect(find.text('Пригласить в штат'), findsOneWidget);
    expect(find.textContaining('Введите полный номер'), findsNothing);
  });
}

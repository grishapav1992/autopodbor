import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_specialist_profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'harness/spark_test_harness.dart';

const _tenServices = <String>[
  'Услуга 1',
  'Услуга 2',
  'Услуга 3',
  'Услуга 4',
  'Услуга 5',
  'Услуга 6',
  'Услуга 7',
  'Услуга 8',
  'Услуга 9',
  'Услуга 10',
];

Future<void> _pumpProfile(
  WidgetTester tester, {
  String? avatarBase64,
  List<String> services = _tenServices,
  Future<void> Function()? deleteProfileAvatar,
}) async {
  final storedAvatar =
      avatarBase64 ??
      base64Encode(img.encodePng(img.Image(width: 2, height: 2)));
  await resetSparkPreferences();
  await tester.pumpWidget(
    wrapWithSparkHarness(
      child: Scaffold(
        body: SparkJoySpecialistProfileScreen(
          deleteProfileAvatar: deleteProfileAvatar,
          fetchRemoteProfile: false,
          initialProfile: {
            'firstName': 'Иван',
            'lastName': 'Иванов',
            'specialization': services
                .map((service) => '• $service')
                .join('\n'),
          },
          initialAvatarBase64: storedAvatar,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _openProfileEditor(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-edit-button')));
  await tester.pumpAndSettle();
  expect(find.text('Редактировать профиль'), findsOneWidget);
}

Future<void> _requestPhotoDeletion(WidgetTester tester) async {
  await _openProfileEditor(tester);
  await tester.tap(find.text('Удалить фото'));
  await tester.pumpAndSettle();
  expect(find.text('Удалить фото профиля?'), findsOneWidget);
}

void main() {
  testWidgets('тап по фото открывает только полноэкранный просмотр', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey('profile-avatar-preview')));
    await tester.pumpAndSettle();

    expect(find.text('Фото профиля'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Изменить'), findsNothing);
  });

  testWidgets('карандаш открывает редактор ФИО', (tester) async {
    await _pumpProfile(tester);
    await _openProfileEditor(tester);

    await tester.tap(find.text('Изменить ФИО'));
    await tester.pumpAndSettle();

    expect(find.text('ФИО'), findsOneWidget);
    expect(find.text('Фамилия'), findsOneWidget);
    expect(find.text('Имя'), findsOneWidget);
    expect(find.text('Отчество'), findsOneWidget);
  });

  testWidgets('карандаш открывает выбор нового фото', (tester) async {
    await _pumpProfile(tester);
    await _openProfileEditor(tester);

    await tester.tap(find.text('Изменить фото'));
    await tester.pumpAndSettle();

    expect(find.text('Сделать новое фото'), findsOneWidget);
    expect(find.text('Выбрать из галереи'), findsOneWidget);
  });

  testWidgets('удаление фото требует подтверждения', (tester) async {
    var deleteCalls = 0;
    await _pumpProfile(tester, deleteProfileAvatar: () async => deleteCalls++);
    await _requestPhotoDeletion(tester);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    await _openProfileEditor(tester);
    expect(find.text('Изменить фото'), findsOneWidget);
  });

  testWidgets('фото исчезает только после успешного удаления', (tester) async {
    var deleteCalls = 0;
    await _pumpProfile(tester, deleteProfileAvatar: () async => deleteCalls++);
    await _requestPhotoDeletion(tester);

    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-profile-photo')),
    );
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    await _openProfileEditor(tester);
    expect(find.text('Добавить фото'), findsOneWidget);
    expect(find.text('Удалить фото'), findsNothing);
  });

  testWidgets('ошибка удаления не скрывает фото', (tester) async {
    await _pumpProfile(
      tester,
      deleteProfileAvatar: () async => throw Exception('offline'),
    );
    await _requestPhotoDeletion(tester);

    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-profile-photo')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Не удалось удалить фото'), findsOneWidget);
    await _openProfileEditor(tester);
    expect(find.text('Изменить фото'), findsOneWidget);
  });

  testWidgets('профиль раскрывает услуги после шестой', (tester) async {
    await _pumpProfile(tester);

    expect(find.text('Услуга 6'), findsOneWidget);
    expect(find.text('Услуга 7'), findsNothing);
    expect(find.text('Услуга 10'), findsNothing);

    final expandButton = find.byKey(const ValueKey('services-expand-button'));
    await tester.ensureVisible(expandButton);
    await tester.pumpAndSettle();
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    final lastService = find.text('Услуга 10');
    expect(lastService, findsOneWidget);
    await tester.ensureVisible(lastService);
    await tester.pumpAndSettle();
    expect(lastService.hitTestable(), findsOneWidget);
    expect(find.text('Свернуть'), findsOneWidget);
  });

  testWidgets('повреждённое локальное фото не создаёт мёртвую кнопку', (
    tester,
  ) async {
    await resetSparkPreferences({'avatarBase64': 'not-valid-base64'});
    await tester.pumpWidget(
      wrapWithSparkHarness(
        child: const Scaffold(
          body: SparkJoySpecialistProfileScreen(fetchRemoteProfile: false),
        ),
      ),
    );
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (await UserSimplePreferences.getAvatarBase64() != null &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(await UserSimplePreferences.getAvatarBase64(), isNull);
    expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
    await _openProfileEditor(tester);
    expect(find.text('Добавить фото'), findsOneWidget);
    expect(find.text('Удалить фото'), findsNothing);
  });
}

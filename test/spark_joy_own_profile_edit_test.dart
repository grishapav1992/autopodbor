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

// Undo-окно отложенного удаления фото — держать в синхроне с
// _avatarDeleteCommitDelay в spark_joy_specialist_profile_screen.dart.
const _undoWindow = Duration(seconds: 5);

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

Future<void> _closeEditorViaX(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Закрыть'));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
  return field.controller!.text;
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

  testWidgets('карандаш открывает редактор с предзаполненным ФИО', (
    tester,
  ) async {
    await _pumpProfile(tester);
    await _openProfileEditor(tester);

    expect(_fieldText(tester, 'editor-field-last'), 'Иванов');
    expect(_fieldText(tester, 'editor-field-first'), 'Иван');
    expect(_fieldText(tester, 'editor-field-middle'), '');
    expect(find.text('Фамилия'), findsOneWidget);
    expect(find.text('Имя'), findsOneWidget);
    expect(find.text('Отчество · не обязательно'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-avatar')), findsOneWidget);
    expect(find.text('Изменить фото'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-delete-photo')), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
  });

  testWidgets('удаление фото мгновенное, «Отменить» откатывает без запроса', (
    tester,
  ) async {
    var deleteCalls = 0;
    await _pumpProfile(tester, deleteProfileAvatar: () async => deleteCalls++);
    await _openProfileEditor(tester);

    await tester.tap(find.byKey(const ValueKey('editor-delete-photo')));
    await tester.pumpAndSettle();

    // Аватар скрыт локально, запрос ещё не ушёл, баннер предлагает undo.
    expect(deleteCalls, 0);
    expect(find.byKey(const ValueKey('editor-banner')), findsOneWidget);
    expect(find.text('Фото удалено'), findsOneWidget);
    expect(find.text('Добавить фото'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-delete-photo')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-undo-delete')));
    await tester.pumpAndSettle();

    expect(deleteCalls, 0);
    expect(find.byKey(const ValueKey('editor-banner')), findsNothing);
    expect(find.text('Изменить фото'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-delete-photo')), findsOneWidget);
  });

  testWidgets('удаление коммитится ровно один раз после undo-окна', (
    tester,
  ) async {
    var deleteCalls = 0;
    await _pumpProfile(tester, deleteProfileAvatar: () async => deleteCalls++);
    await _openProfileEditor(tester);

    await tester.tap(find.byKey(const ValueKey('editor-delete-photo')));
    await tester.pumpAndSettle();
    expect(deleteCalls, 0);

    await tester.pump(_undoWindow);
    await tester.pumpAndSettle();

    expect(deleteCalls, 1);
    expect(find.byKey(const ValueKey('editor-banner')), findsNothing);
    expect(find.text('Добавить фото'), findsOneWidget);

    await _closeEditorViaX(tester);
    expect(find.text('Редактировать профиль'), findsNothing);
    expect(deleteCalls, 1);
  });

  testWidgets('закрытие редактора в undo-окне коммитит удаление сразу', (
    tester,
  ) async {
    var deleteCalls = 0;
    await _pumpProfile(tester, deleteProfileAvatar: () async => deleteCalls++);
    await _openProfileEditor(tester);

    await tester.tap(find.byKey(const ValueKey('editor-delete-photo')));
    await tester.pumpAndSettle();
    expect(deleteCalls, 0);

    // ФИО не менялось — guard не вмешивается, закрытие мгновенное.
    await _closeEditorViaX(tester);

    expect(find.text('Редактировать профиль'), findsNothing);
    expect(deleteCalls, 1);
    expect(find.text('Фото профиля удалено'), findsOneWidget);
  });

  testWidgets('ошибка удаления возвращает фото и показывает баннер', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      deleteProfileAvatar: () async => throw Exception('offline'),
    );
    await _openProfileEditor(tester);

    await tester.tap(find.byKey(const ValueKey('editor-delete-photo')));
    await tester.pumpAndSettle();
    await tester.pump(_undoWindow);
    await tester.pumpAndSettle();

    // Аватар восстановлен, вместо undo-баннера — баннер ошибки.
    expect(find.byKey(const ValueKey('editor-banner')), findsOneWidget);
    expect(find.text('Фото удалено'), findsNothing);
    expect(find.text('Изменить фото'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-delete-photo')), findsOneWidget);

    await _closeEditorViaX(tester);
    expect(find.text('Редактировать профиль'), findsNothing);
  });

  testWidgets('guard: изменённые поля требуют подтверждения закрытия', (
    tester,
  ) async {
    await _pumpProfile(tester);
    await _openProfileEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('editor-field-first')),
      'Пётр',
    );
    await tester.pump();

    // Крестик при изменённых полях → диалог; «Продолжить» оставляет шит.
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Не сохранять изменения?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-discard-stay')));
    await tester.pumpAndSettle();
    expect(find.text('Не сохранять изменения?'), findsNothing);
    expect(find.text('Редактировать профиль'), findsOneWidget);

    // Тап по затемнению над шитом → снова диалог; «Закрыть» отбрасывает
    // правки без сохранения.
    await tester.tapAt(const Offset(187, 10));
    await tester.pumpAndSettle();
    expect(find.text('Не сохранять изменения?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-discard-close')));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать профиль'), findsNothing);
    expect(find.text('Иван Иванов'), findsOneWidget);
    expect(find.textContaining('Пётр'), findsNothing);
  });

  testWidgets('чистое закрытие не спрашивает подтверждения', (tester) async {
    await _pumpProfile(tester);
    await _openProfileEditor(tester);

    await tester.tap(find.byKey(const ValueKey('editor-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Не сохранять изменения?'), findsNothing);
    expect(find.text('Редактировать профиль'), findsNothing);
  });

  testWidgets('пустая фамилия не сохраняется, ошибка гаснет при вводе', (
    tester,
  ) async {
    await _pumpProfile(tester);
    await _openProfileEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('editor-field-last')),
      '',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pump();

    expect(find.text('Введите фамилию'), findsOneWidget);
    expect(find.text('Редактировать профиль'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('editor-field-last')),
      'Иванов',
    );
    await tester.pump();
    expect(find.text('Введите фамилию'), findsNothing);

    await _closeEditorViaX(tester);
    expect(find.text('Редактировать профиль'), findsNothing);
  });

  testWidgets('сохранение капитализирует ФИО и обновляет шапку', (
    tester,
  ) async {
    await _pumpProfile(tester);
    await _openProfileEditor(tester);

    await tester.enterText(
      find.byKey(const ValueKey('editor-field-last')),
      'петров',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    // Шит закрыт, шапка перерисована из контроллеров с заглавной буквы.
    // Server-push в тестовом окружении падает и глотается внутри
    // _pushProfileToServer — снекбар успеха не проверяем.
    expect(find.text('Редактировать профиль'), findsNothing);
    expect(find.text('Иван Петров'), findsOneWidget);
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
    // Без фото тап по аватару не должен открывать пустой просмотрщик.
    await tester.tap(find.byKey(const ValueKey('profile-avatar-preview')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    await _openProfileEditor(tester);
    expect(find.text('Добавить фото'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-delete-photo')), findsNothing);
  });
}

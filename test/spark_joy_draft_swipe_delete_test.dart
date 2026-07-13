import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_reports_list_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Свайп-влево по карточке черновика: удаление без диалога подтверждения,
/// с отложенным коммитом через undo-снекбар. Пока окно отмены открыто,
/// черновик остаётся в storage — «Отменить» просто возвращает карточку;
/// по истечении окна таймер коммитит настоящее удаление.
///
/// ВАЖНО про порядок тестов: коммит удаления стартует из зоны колбэка
/// Timer/Dismissible, чьи микротаски не попадают в FakeAsync-очередь
/// pump'ов — тест, доводящий до коммита, дренирует их через runAsync,
/// но хвост статического write-lock'а SparkJoyStorage (_draftWriteChain)
/// всё равно может остаться повисшим в зоне умершего теста и подвесить
/// upsertDraft в setUp следующего. Поэтому тест с коммитом стоит
/// ПОСЛЕДНИМ (файл = отдельный изолят, травить некого), а остальные
/// нейтрализуют таймер отменой и до коммита не доходят.
const _draftId = 'draft-swipe-test-1';
const _draftTitle = 'Свайп-тест BMW X5';

Future<void> _seedDraft() async {
  await SparkJoyStorage.upsertDraft(<String, dynamic>{
    'id': _draftId,
    'reportName': _draftTitle,
    'updatedAt': '2026-07-12T10:00:00.000',
  });
}

Future<bool> _draftInStorage() async {
  final drafts = await SparkJoyStorage.loadDrafts();
  return drafts.any((d) => d['id']?.toString() == _draftId);
}

Future<void> _pumpScreen(WidgetTester tester) async {
  // Экран живёт внутри шелла, который даёт Scaffold/Material — в тесте
  // оборачиваем сами (иначе TextField поиска падает без Material).
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SparkJoyReportsListScreen())),
  );
  await tester.pumpAndSettle();
}

/// Полный свайп влево (порог Dismissible — 0.7 ширины карточки).
Future<void> _swipeCardAway(WidgetTester tester) async {
  await tester.drag(find.text(_draftTitle), const Offset(-700, 0));
  await tester.pumpAndSettle();
}

/// Дожидается, пока коммит удаления реально доедет до storage. runAsync —
/// принципиален: он даёт прокрутиться реальному event loop'у и дренирует
/// микротаски коммит-цепочки, которые FakeAsync-pump'ы не видят.
Future<void> _waitDraftCommitted(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (!await _draftInStorage()) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Коммит удаления черновика не завершился');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();
    await _seedDraft();
  });

  testWidgets('свайп прячет карточку и показывает undo-снекбар, '
      'storage ещё не тронут', (tester) async {
    await _pumpScreen(tester);
    expect(find.text(_draftTitle), findsOneWidget);
    expect(find.textContaining('1 черновик'), findsNothing);
    expect(find.textContaining('Осталось:'), findsNothing);
    // Иконки корзины на карточке больше нет.
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

    await _swipeCardAway(tester);

    expect(find.text(_draftTitle), findsNothing);
    expect(find.text('Черновик удалён'), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);
    final undoAction = tester.widget<SnackBarAction>(
      find.byType(SnackBarAction),
    );
    expect(undoAction.textColor, Colors.white);
    // Диалог подтверждения не появлялся.
    expect(find.text('Удалить черновик?'), findsNothing);
    // Реальное удаление отложено до конца окна отмены.
    expect(await _draftInStorage(), isTrue);

    // Cleanup: гасим таймер коммита отменой, до удаления не доводим —
    // см. комментарий про порядок тестов в шапке файла.
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
  });

  testWidgets('«Отменить» возвращает карточку, черновик остаётся в storage', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _swipeCardAway(tester);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();

    expect(find.text(_draftTitle), findsOneWidget);
    expect(await _draftInStorage(), isTrue);
  });

  // ПОСЛЕДНИЙ тест файла — единственный, доводящий до коммита удаления.
  testWidgets('окно отмены истекло — черновик удалён из storage', (
    tester,
  ) async {
    await _pumpScreen(tester);
    await _swipeCardAway(tester);
    expect(await _draftInStorage(), isTrue);

    // Даём таймеру коммита (и снекбару) прожить свои 5 секунд.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await _waitDraftCommitted(tester);

    expect(find.text('Черновик удалён'), findsNothing);
    expect(await _draftInStorage(), isFalse);
    expect(find.text(_draftTitle), findsNothing);
  });
}

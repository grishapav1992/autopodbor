import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/spark_joy_report_upload_gate.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_create_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/spark_test_harness.dart';

/// Редактор × глобальный гейт выгрузки: пока идёт чужая выгрузка, кнопка
/// «Завершить и выгрузить» на шаге «Итог» задизейблена, причина показана
/// хинтом, а чужую выгрузку можно кооперативно отменить через confirm.
/// Это регресс-страховка на ПОДКЛЮЧЁННОСТЬ гейта к редактору — unit-тест
/// гейта семантику лока проверяет, но не его использование.
const _foreignDraftId = 'gate-foreign-draft';
const _foreignReportName = 'Отчёт А';
const _ownDraftId = 'gate-own-draft';

const _finishLabel = 'Завершить и выгрузить';

Future<void> _openSummaryStep(
  WidgetTester tester, {
  required String draftId,
}) async {
  // Онбординг-шиты списка/редактора гасим заранее — их flagKey уже "показан".
  await resetSparkPreferences(<String, Object>{
    UserSimplePreferences.sparkOnbReportEditorKey: true,
    UserSimplePreferences.sparkOnbReportsListKey: true,
  });
  // Харнесс задаёт только MediaQuery.size; физический вьюпорт теста по
  // умолчанию 800×600 — карточка «Итог» внизу обзора разделов не проходит
  // hit-test. Раздвигаем сам вьюпорт.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapWithSparkHarness(
      size: const Size(800, 1400),
      child: SparkJoyCreateReportScreen(
        draft: <String, dynamic>{'id': draftId, 'reportName': 'Мой отчёт'},
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Итог').first);
  await tester.tap(find.text('Итог').first);
  await tester.pumpAndSettle();
}

FilledButton _finishButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, _finishLabel),
);

void main() {
  setUp(SparkJoyReportUploadGate.resetSingletonForTest);
  tearDown(SparkJoyReportUploadGate.resetSingletonForTest);

  testWidgets('чужая выгрузка: кнопка задизейблена, хинт с именем отчёта, '
      'отмена через confirm', (tester) async {
    SparkJoyReportUploadGate.instance.tryAcquire(
      draftId: _foreignDraftId,
      reportName: _foreignReportName,
    );
    await _openSummaryStep(tester, draftId: _ownDraftId);

    expect(
      find.text(
        'Идёт выгрузка отчёта «$_foreignReportName» — дождитесь завершения',
      ),
      findsOneWidget,
    );
    expect(_finishButton(tester).onPressed, isNull);

    // Отказ в confirm-диалоге отмену не запрашивает.
    await tester.ensureVisible(find.text('Отменить выгрузку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить выгрузку'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить выгрузку?'), findsOneWidget);
    await tester.tap(find.text('Продолжить выгрузку'));
    await tester.pumpAndSettle();
    expect(
      SparkJoyReportUploadGate.instance.isCancelRequested(_foreignDraftId),
      isFalse,
    );

    // Подтверждение запрашивает кооперативную отмену: хинт меняется,
    // кнопка отмены исчезает.
    await tester.ensureVisible(find.text('Отменить выгрузку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить выгрузку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, отменить'));
    await tester.pumpAndSettle();
    expect(
      SparkJoyReportUploadGate.instance.isCancelRequested(_foreignDraftId),
      isTrue,
    );
    expect(find.text('Отменяем выгрузку…'), findsOneWidget);
    expect(find.text('Отменить выгрузку'), findsNothing);
    expect(_finishButton(tester).onPressed, isNull);
  });

  testWidgets('этот же черновик выгружается из умершего экрана: '
      'same-draft хинт без кнопки завершения', (tester) async {
    SparkJoyReportUploadGate.instance.tryAcquire(
      draftId: _ownDraftId,
      reportName: 'Мой отчёт',
    );
    await _openSummaryStep(tester, draftId: _ownDraftId);

    expect(find.text(kSparkReportUploadSameDraftBusyText), findsOneWidget);
    expect(_finishButton(tester).onPressed, isNull);
  });

  testWidgets('release гейта оживляет кнопку на живом экране', (tester) async {
    SparkJoyReportUploadGate.instance.tryAcquire(
      draftId: _foreignDraftId,
      reportName: _foreignReportName,
    );
    await _openSummaryStep(tester, draftId: _ownDraftId);
    expect(_finishButton(tester).onPressed, isNull);

    SparkJoyReportUploadGate.instance.release(_foreignDraftId);
    await tester.pumpAndSettle();

    expect(_finishButton(tester).onPressed, isNotNull);
    expect(find.textContaining('Идёт выгрузка отчёта'), findsNothing);
  });
}

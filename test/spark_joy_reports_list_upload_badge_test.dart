import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/spark_joy_report_upload_gate.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_reports_list_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Список черновиков × глобальный гейт выгрузки: карточка выгружаемого
/// прямо сейчас черновика несёт бейдж «Выгружается…» и не удаляется
/// свайпом (удаление под живой выгрузкой — гонка за файлы и
/// backendUploadState), остальные карточки живут как обычно; release
/// гейта гасит бейдж без пересоздания экрана.
const _uploadingDraftId = 'draft-upload-badge-1';
const _uploadingTitle = 'Выгружаемый BMW X5';
const _idleDraftId = 'draft-upload-badge-2';
const _idleTitle = 'Свободный Audi Q7';
const _badgeLabel = 'Выгружается…';

Future<void> _seedDrafts() async {
  await SparkJoyStorage.upsertDraft(<String, dynamic>{
    'id': _uploadingDraftId,
    'reportName': _uploadingTitle,
    'updatedAt': '2026-07-12T10:00:00.000',
  });
  await SparkJoyStorage.upsertDraft(<String, dynamic>{
    'id': _idleDraftId,
    'reportName': _idleTitle,
    'updatedAt': '2026-07-12T09:00:00.000',
  });
}

Future<bool> _draftInStorage(String id) async {
  final drafts = await SparkJoyStorage.loadDrafts();
  return drafts.any((d) => d['id']?.toString() == id);
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SparkJoyReportsListScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();
    await _seedDrafts();
    SparkJoyReportUploadGate.resetSingletonForTest();
  });

  tearDown(SparkJoyReportUploadGate.resetSingletonForTest);

  testWidgets('выгружаемый черновик: бейдж есть, свайп-удаление выключено; '
      'остальные карточки живут как обычно', (tester) async {
    SparkJoyReportUploadGate.instance.tryAcquire(
      draftId: _uploadingDraftId,
      reportName: _uploadingTitle,
    );
    await _pumpScreen(tester);

    expect(find.text(_badgeLabel), findsOneWidget);

    // Свайп по выгружаемому — карточка на месте, storage не тронут.
    await tester.drag(find.text(_uploadingTitle), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text(_uploadingTitle), findsOneWidget);
    expect(find.text('Черновик удалён'), findsNothing);
    expect(await _draftInStorage(_uploadingDraftId), isTrue);

    // Свайп по свободному черновику работает как раньше.
    await tester.drag(find.text(_idleTitle), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text(_idleTitle), findsNothing);
    expect(find.text('Черновик удалён'), findsOneWidget);

    // Гасим таймер коммита отменой — до реального удаления не доводим
    // (см. комментарий про зоны в spark_joy_draft_swipe_delete_test.dart).
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
  });

  testWidgets('release гейта гасит бейдж на живом экране', (tester) async {
    SparkJoyReportUploadGate.instance.tryAcquire(
      draftId: _uploadingDraftId,
      reportName: _uploadingTitle,
    );
    await _pumpScreen(tester);
    expect(find.text(_badgeLabel), findsOneWidget);

    SparkJoyReportUploadGate.instance.release(_uploadingDraftId);
    await tester.pumpAndSettle();

    expect(find.text(_badgeLabel), findsNothing);
    // Оба черновика по-прежнему в списке — release не трогает данные.
    expect(find.text(_uploadingTitle), findsOneWidget);
    expect(find.text(_idleTitle), findsOneWidget);
  });
}

import 'package:flutter_application_1/data/services/spark_joy_report_upload_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Глобальный single-flight гейт выгрузки отчётов: пока идёт одна выгрузка,
/// вторую (в т.ч. того же черновика из другого экрана) начать нельзя.
void main() {
  setUp(SparkJoyReportUploadGate.resetSingletonForTest);
  tearDown(SparkJoyReportUploadGate.resetSingletonForTest);

  SparkJoyReportUploadGate get() => SparkJoyReportUploadGate.instance;

  test('начальное состояние: гейт свободен', () {
    expect(get().active.value, isNull);
    expect(get().isBusy, isFalse);
    expect(get().isUploading('draft_a'), isFalse);
  });

  test('tryAcquire занимает гейт и публикует снапшот', () {
    final ok = get().tryAcquire(draftId: 'draft_a', reportName: 'BMW X5');
    expect(ok, isTrue);
    expect(get().isBusy, isTrue);
    expect(get().active.value?.draftId, 'draft_a');
    expect(get().active.value?.reportName, 'BMW X5');
    expect(get().isUploading('draft_a'), isTrue);
    expect(get().isUploading('draft_b'), isFalse);
  });

  test('повторный tryAcquire тем же draftId отклоняется (анти-дубликат)', () {
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);
    // Второй инстанс экрана того же черновика: раньше это давало две
    // выгрузки одного черновика и дубликат отчёта на сервере.
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isFalse);
    expect(get().active.value?.reportName, 'A');
  });

  test('tryAcquire другим draftId при занятом гейте отклоняется', () {
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);
    expect(get().tryAcquire(draftId: 'draft_b', reportName: 'B'), isFalse);
    // Активный снапшот не перезаписан отказом.
    expect(get().active.value?.draftId, 'draft_a');
  });

  test('release чужим draftId — no-op, владельцем — освобождает', () {
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);

    get().release('draft_b');
    expect(get().active.value?.draftId, 'draft_a');

    get().release('draft_a');
    expect(get().active.value, isNull);

    // Повторный release идемпотентен.
    get().release('draft_a');
    expect(get().active.value, isNull);

    // После освобождения гейт можно занять снова (ретрай).
    expect(get().tryAcquire(draftId: 'draft_b', reportName: 'B'), isTrue);
  });

  test('listener: по одной нотификации на acquire и release, ноль на отказах',
      () {
    var notifications = 0;
    get().active.addListener(() => notifications++);

    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);
    expect(notifications, 1);

    // Отказной tryAcquire и чужой release не будят подписчиков.
    expect(get().tryAcquire(draftId: 'draft_b', reportName: 'B'), isFalse);
    get().release('draft_b');
    expect(notifications, 1);

    get().release('draft_a');
    expect(notifications, 2);
  });

  test('resetAll освобождает гейт; поздний release умершей выгрузки — no-op',
      () {
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);

    // Разлогин.
    get().resetAll();
    expect(get().active.value, isNull);

    // Новый сеанс занимает гейт…
    expect(get().tryAcquire(draftId: 'draft_b', reportName: 'B'), isTrue);

    // …а доживший Future старой выгрузки не сбивает нового владельца.
    get().release('draft_a');
    expect(get().active.value?.draftId, 'draft_b');
  });

  test('isUploading с пустым draftId всегда false', () {
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);
    expect(get().isUploading(''), isFalse);
    expect(get().isUploading('   '), isFalse);
  });

  test('requestCancel помечает активную выгрузку и будит подписчиков', () {
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);
    var notifications = 0;
    get().active.addListener(() => notifications++);

    get().requestCancel();
    expect(get().active.value?.cancelRequested, isTrue);
    expect(get().isCancelRequested('draft_a'), isTrue);
    expect(get().isCancelRequested('draft_b'), isFalse);
    expect(notifications, 1);

    // Повторный запрос идемпотентен и не будит подписчиков.
    get().requestCancel();
    expect(notifications, 1);
  });

  test('requestCancel на свободном гейте — no-op', () {
    var notifications = 0;
    get().active.addListener(() => notifications++);
    get().requestCancel();
    expect(get().active.value, isNull);
    expect(notifications, 0);
  });

  test('cancelRequested не переживает release и новый tryAcquire', () {
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);
    get().requestCancel();
    get().release('draft_a');
    expect(get().isCancelRequested('draft_a'), isFalse);

    // Ретрай той же выгрузки стартует с чистым флагом отмены.
    expect(get().tryAcquire(draftId: 'draft_a', reportName: 'A'), isTrue);
    expect(get().active.value?.cancelRequested, isFalse);
    expect(get().isCancelRequested('draft_a'), isFalse);
  });
}

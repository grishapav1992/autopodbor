import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Разбор `result.error` от Notification.ActionNotification: бэк не даёт
/// числовых кодов — только русские тексты (resolveActionError), поэтому
/// матчинг по подстроке — единственный для клиента сигнал «карточка мертва»
/// (статус на сервере уже финальный или записи больше нет). На этих геттерах
/// держится восстановление после таймаута accept: без них приглашение
/// зависает в pending навсегда.
void main() {
  NotificationActionResult res(String? error) => NotificationActionResult(
    notificationId: 'n1',
    status: NotificationStatus.pending,
    action: NotificationAction.accept,
    error: error,
  );

  group('NotificationActionResult', () {
    test('isAlreadyProcessed матчит серверный текст', () {
      expect(res('Оповещение уже обработано.').isAlreadyProcessed, isTrue);
      expect(res('оповещение уже обработано').isAlreadyProcessed, isTrue);
      expect(res(null).isAlreadyProcessed, isFalse);
      expect(res('').isAlreadyProcessed, isFalse);
      expect(res('Оповещение не найдено.').isAlreadyProcessed, isFalse);
      expect(
        res(
          'Действие доступно только получателю оповещения.',
        ).isAlreadyProcessed,
        isFalse,
      );
    });

    test('isGoneOnServer матчит тексты об удалённой записи', () {
      expect(res('Оповещение не найдено.').isGoneOnServer, isTrue);
      expect(res('Уведомление не найдено').isGoneOnServer, isTrue);
      expect(res(null).isGoneOnServer, isFalse);
      expect(res('Оповещение уже обработано.').isGoneOnServer, isFalse);
    });

    test('fromJson сохраняет error и семантику isOk', () {
      final parsed = NotificationActionResult.fromJson({
        'notificationId': 'n1',
        'error': 'Оповещение уже обработано.',
      });
      expect(parsed.isOk, isFalse);
      expect(parsed.isAlreadyProcessed, isTrue);
      expect(parsed.isGoneOnServer, isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_notification_detail_rows.dart';

/// Покрывает багфикс #1/#3: «Детали уведомления» не должны показывать сырые
/// поля БД (event, *Id, requestType-сырьё, ключи from/to/clientUser, голый
/// senderId), но обязаны выводить человекочитаемый набор.
void main() {
  Map<String, String> labels(List<NotificationDetailRow> rows) => {
    for (final r in rows) r.label: r.value,
  };

  String flat(List<NotificationDetailRow> rows) =>
      rows.map((r) => '${r.label}:${r.value}').join('|');

  BackendNotification invite(Map<String, dynamic> payload) =>
      BackendNotification(
        id: 'n1',
        type: NotificationType.invitation,
        status: NotificationStatus.pending,
        recipientId: 10,
        senderId: 42,
        title: 'Приглашение в компанию',
        createdAt: DateTime.utc(2026, 6, 24, 9, 30),
        expiresAt: DateTime.utc(2026, 7, 24, 9, 30),
        payload: payload,
      );

  group('приглашение в компанию', () {
    final rows = notificationDetailRows(
      invite({
        'event': 'invitation',
        'from': {'companyName': 'ООО Автоподбор'},
        'to': {'fullName': 'Иван Петров'},
        'clientUser': {'name': 'Сергей Клиентов'},
        'requestId': 777,
        'requestNumber': '1234',
        'requestType': 'by_car',
        'dueAt': '2026-07-01',
        'requestCars': [
          {'vin': 'XYZ'},
        ],
        'note': 'Срочно',
        'companyId': 5,
      }),
    );
    final map = labels(rows);

    test('показывает человекочитаемые поля', () {
      expect(map['Тип'], 'Приглашение');
      expect(map['Компания'], 'ООО Автоподбор');
      expect(map['Клиент'], 'Сергей Клиентов');
      expect(map['Заявка'], '№1234');
      expect(map['Тип заявки'], 'По автомобилю');
      expect(map['Срок'], '01.07.2026');
      expect(map['Комментарий'], 'Срочно');
      expect(map['Истекает'], isNotNull);
    });

    test('НЕ протекают сырые поля БД', () {
      expect(map.containsKey('event'), isFalse);
      expect(map.containsKey('from'), isFalse);
      expect(map.containsKey('to'), isFalse);
      expect(map.containsKey('clientUser'), isFalse);
      expect(map.containsKey('companyId'), isFalse);
      expect(map.containsKey('requestId'), isFalse);
      expect(map.containsKey('requestCars'), isFalse);

      final all = flat(rows);
      expect(all.contains('event'), isFalse);
      expect(all.contains('by_car'), isFalse); // сырое значение requestType
      expect(all.contains('777'), isFalse); // requestId
      expect(all.contains('42'), isFalse); // голый senderId больше не выводим
    });
  });

  group('отвязка сотрудника (system)', () {
    final rows = notificationDetailRows(
      BackendNotification(
        id: 'n2',
        type: NotificationType.system,
        status: NotificationStatus.read,
        recipientId: 10,
        title: 'Вы удалены из штата компании',
        createdAt: DateTime.utc(2026, 6, 24, 9, 30),
        payload: const {'event': 'company_specialist_unlinked', 'companyId': 5},
      ),
    );
    final map = labels(rows);

    test('только базовые читаемые строки, без полей БД', () {
      expect(map['Тип'], 'Системное');
      expect(map['Статус'], 'Просмотрено');
      expect(map.containsKey('event'), isFalse);
      expect(map.containsKey('companyId'), isFalse);

      final all = flat(rows);
      expect(all.contains('company_specialist_unlinked'), isFalse);
      expect(all.contains('event'), isFalse);
    });
  });

  test('строковый requestNumber и turnkey форматируются', () {
    final rows = notificationDetailRows(
      invite({'requestNumber': '99', 'requestType': 'turnkey'}),
    );
    final map = labels(rows);
    expect(map['Заявка'], '№99');
    expect(map['Тип заявки'], 'Под ключ');
  });

  test('reminder: reminderAt показывается, entityId скрыт', () {
    final rows = notificationDetailRows(
      BackendNotification(
        id: 'r1',
        type: NotificationType.reminder,
        status: NotificationStatus.pending,
        recipientId: 10,
        title: 'Напоминание',
        createdAt: DateTime.utc(2026, 6, 24, 9, 30),
        payload: const {'reminderAt': '2026-07-05T08:00:00Z', 'entityId': 99},
      ),
    );
    final map = labels(rows);
    expect(map['Напомнить'], isNotNull);
    expect(map.containsKey('entityId'), isFalse);
    expect(flat(rows).contains('99'), isFalse);
  });
}

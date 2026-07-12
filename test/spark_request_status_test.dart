import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requestStatusBadge', () {
    test('maps transitional backend statuses to Russian labels', () {
      expect(
        requestHistoryStatusBadge('specialist_assigned').label,
        'Специалист назначен',
      );
      expect(requestStatusBadge('completed').label, 'Завершена');
      expect(requestStatusBadge('in_progress').label, 'В работе');
      expect(
        requestHistoryStatusBadge('specialist_rejected').label,
        'Отклонена специалистом',
      );
    });

    test('never exposes an unknown backend enum', () {
      expect(requestStatusBadge('new_backend_status').label, 'Статус обновлён');
    });
  });

  group('history labels', () {
    test('maps assignment reason', () {
      expect(
        requestHistoryReason('specialist_assigned').label,
        'Назначен специалист',
      );
      expect(
        requestHistoryReason('SPECIALIST_ASSIGNED').label,
        'Назначен специалист',
      );
    });

    test('does not expose unknown snake_case reasons and roles', () {
      expect(
        requestHistoryReason('backend_transition_v2').label,
        'Статус заявки изменён',
      );
      expect(requestRoleLabel('service_worker'), 'Участник');
    });
  });
}

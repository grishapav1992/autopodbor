import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/state/notification_controller.dart';

BackendNotification _notification(
  String id,
  DateTime createdAt, {
  NotificationStatus status = NotificationStatus.read,
}) {
  return BackendNotification(
    id: id,
    type: NotificationType.task,
    status: status,
    recipientId: 1,
    title: id,
    createdAt: createdAt,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await UserSimplePreferences.init();
  });

  group('notification seen marker', () {
    test('persists latest seen notification id and timestamp', () async {
      final createdAt = DateTime.utc(2026, 7, 8, 10, 30);

      await UserSimplePreferences.setLastSeenNotification(
        id: 'n-42',
        createdAt: createdAt,
      );

      final marker = await UserSimplePreferences.getLastSeenNotification();
      expect(marker?.id, 'n-42');
      expect(marker?.createdAt?.toUtc(), createdAt);
    });

    test('counts items before seen id even with equal timestamps', () {
      final createdAt = DateTime.utc(2026, 7, 8, 10);
      final notifications = [
        _notification('newer-a', createdAt),
        _notification('newer-b', createdAt),
        _notification('seen', createdAt),
      ];

      final count = NotificationController.countNotificationsNewerThanSeen(
        notifications: notifications,
        seenId: 'seen',
        seenCreatedAt: createdAt,
      );

      expect(count, 2);
    });

    test('falls back to createdAt when seen id is no longer loaded', () {
      final seenAt = DateTime.utc(2026, 7, 8, 10);
      final notifications = [
        _notification('newer', DateTime.utc(2026, 7, 8, 11)),
        _notification('same-time', seenAt),
        _notification('older', DateTime.utc(2026, 7, 8, 9)),
      ];

      final count = NotificationController.countNotificationsNewerThanSeen(
        notifications: notifications,
        seenId: 'not-on-page',
        seenCreatedAt: seenAt,
      );

      expect(count, 1);
    });

    test('treats all loaded items as unseen when marker is absent', () {
      final notifications = [
        _notification('first', DateTime.utc(2026, 7, 11, 10)),
        _notification('second', DateTime.utc(2026, 7, 11, 9)),
      ];

      final count = NotificationController.countNotificationsNewerThanSeen(
        notifications: notifications,
        seenId: null,
        seenCreatedAt: null,
      );

      expect(count, 2);
    });
  });
}

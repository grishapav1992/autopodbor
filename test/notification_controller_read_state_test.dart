import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/state/notification_controller.dart';

BackendNotification _notification(
  String id, {
  NotificationType type = NotificationType.system,
  NotificationStatus status = NotificationStatus.pending,
  bool legalConverter = false,
}) {
  return BackendNotification(
    id: id,
    type: type,
    status: status,
    recipientId: 1,
    title: id,
    payload: legalConverter
        ? const <String, dynamic>{
            'event': 'legal_review_persisted',
            'checkType': 'api_cloud_converter_search',
          }
        : const <String, dynamic>{},
    createdAt: DateTime.utc(2026, 7, 15, 12),
  );
}

NotificationsPage _page(Iterable<BackendNotification> items) =>
    NotificationsPage(items: items.toList());

void main() {
  test('bell badge matches visible pending cards only', () async {
    final controller = NotificationController(
      pageLoader: ({page, limit, status, type, cursor}) async => _page([
        _notification('already-read', status: NotificationStatus.read),
        _notification('pending'),
        _notification('hidden-converter', legalConverter: true),
      ]),
    );
    addTearDown(controller.shutdown);

    await controller.reload();

    expect(controller.unreadCount.value, 1);
    expect(controller.badgeCount.value, 1);
  });

  test(
    'stale reload cannot overwrite an in-flight successful MarkRead',
    () async {
      final markCompleter = Completer<void>();
      final controller = NotificationController(
        pageLoader: ({page, limit, status, type, cursor}) async =>
            _page([_notification('n1')]),
        readMarker: (_) => markCompleter.future,
      );
      addTearDown(controller.shutdown);
      await controller.reload();

      final markFuture = controller.markRead('n1');
      expect(controller.items.single.status, NotificationStatus.read);

      // Simulates GetNotifications returning stale `pending` while MarkRead is
      // still in flight. The local overlay must keep the card read.
      await controller.reload();
      expect(controller.items.single.status, NotificationStatus.read);

      markCompleter.complete();
      await markFuture;
      await controller.reload();

      expect(controller.items.single.status, NotificationStatus.read);
      expect(controller.badgeCount.value, 0);
    },
  );

  test(
    'failed MarkRead reverts by id after a reload reorders the page',
    () async {
      final markCompleter = Completer<void>();
      var loadCount = 0;
      final controller = NotificationController(
        pageLoader: ({page, limit, status, type, cursor}) async {
          loadCount++;
          return loadCount == 1
              ? _page([_notification('a'), _notification('b')])
              : _page([_notification('b'), _notification('a')]);
        },
        readMarker: (_) => markCompleter.future,
      );
      addTearDown(controller.shutdown);
      await controller.reload();

      final markFuture = controller.markRead('a');
      await controller.reload();
      markCompleter.completeError(Exception('network error'));

      await expectLater(markFuture, throwsException);
      expect(controller.items.map((n) => (n.id, n.status)), [
        ('b', NotificationStatus.pending),
        ('a', NotificationStatus.pending),
      ]);
    },
  );

  test(
    'auto-read clears passive cards but keeps interactive tasks pending',
    () async {
      final markedIds = <String>[];
      final serverItems = [
        _notification('passive'),
        _notification('interactive', type: NotificationType.task),
      ];
      final controller = NotificationController(
        pageLoader: ({page, limit, status, type, cursor}) async =>
            _page(serverItems),
        readMarker: (id) async => markedIds.add(id),
      );
      addTearDown(controller.shutdown);

      await controller.reload();
      final result = await controller.markLoadedPassiveRead();

      expect(result, (marked: 1, failed: 0));
      expect(markedIds, ['passive']);
      expect(controller.items.first.status, NotificationStatus.read);
      expect(controller.items.last.status, NotificationStatus.pending);
      expect(controller.badgeCount.value, 1);
    },
  );
}

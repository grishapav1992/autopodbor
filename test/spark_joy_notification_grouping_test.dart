import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

BackendNotification _n({
  required String id,
  required String title,
  NotificationType type = NotificationType.system,
  NotificationStatus status = NotificationStatus.read,
  DateTime? createdAt,
  Map<String, dynamic> payload = const <String, dynamic>{},
}) {
  return BackendNotification(
    id: id,
    type: type,
    status: status,
    recipientId: 1,
    title: title,
    createdAt: createdAt ?? DateTime.utc(2026, 7, 11, 12, 0),
    payload: payload,
  );
}

void main() {
  group('notificationGroupKey', () {
    test('same wording with different request codes share a key', () {
      final a = _n(id: 'a', title: 'Специалист отклонил заявку REQ-A225453');
      final b = _n(id: 'b', title: 'Специалист отклонил заявку REQ-A894735');
      expect(notificationGroupKey(a), notificationGroupKey(b));
    });

    test('different wording yields different keys', () {
      final a = _n(id: 'a', title: 'Специалист отклонил заявку REQ-A225453');
      final b = _n(id: 'b', title: 'Новая заявка на осмотр REQ-A225453');
      expect(notificationGroupKey(a), isNot(notificationGroupKey(b)));
    });

    test('same wording but different type does not merge', () {
      final a = _n(
        id: 'a',
        title: 'Заявка REQ-1',
        type: NotificationType.system,
      );
      final b = _n(
        id: 'b',
        title: 'Заявка REQ-2',
        type: NotificationType.task,
      );
      expect(notificationGroupKey(a), isNot(notificationGroupKey(b)));
    });
  });

  group('notificationIsGroupable', () {
    test('read passive notification is groupable', () {
      expect(
        notificationIsGroupable(
          _n(id: 'a', title: 'x', status: NotificationStatus.read),
        ),
        isTrue,
      );
    });

    test('unread (pending) notification is never groupable', () {
      expect(
        notificationIsGroupable(
          _n(id: 'a', title: 'x', status: NotificationStatus.pending),
        ),
        isFalse,
      );
    });

    test('pending interactive invitation is never groupable', () {
      expect(
        notificationIsGroupable(
          _n(
            id: 'a',
            title: 'x',
            type: NotificationType.invitation,
            status: NotificationStatus.pending,
          ),
        ),
        isFalse,
      );
    });

    test('read item carrying a comment stays ungroupable', () {
      for (final key in const ['note', 'comment', 'message', 'reason']) {
        expect(
          notificationIsGroupable(
            _n(
              id: 'a',
              title: 'Специалист отклонил заявку REQ-A1',
              payload: {key: 'зачем ?'},
            ),
          ),
          isFalse,
          reason: 'payload[$key] should keep the card expandable',
        );
      }
    });
  });

  group('buildNotificationFeedEntries', () {
    test('collapses 3+ same-kind read items into one group, newest-first', () {
      final items = [
        for (var i = 0; i < 5; i++)
          _n(
            id: 'g$i',
            title: 'Специалист отклонил заявку REQ-A${1000 + i}',
            createdAt: DateTime.utc(2026, 7, 11, 19 - i, 0),
          ),
      ];
      final entries = buildNotificationFeedEntries(items);
      expect(entries, hasLength(1));
      final group = entries.single as NotificationGroupEntry;
      expect(group.count, 5);
      // Newest member first (19:00).
      expect(group.newest.id, 'g0');
    });

    test('below threshold stays as individual single entries', () {
      final items = [
        _n(id: 'a', title: 'Специалист отклонил заявку REQ-A1'),
        _n(id: 'b', title: 'Специалист отклонил заявку REQ-A2'),
      ];
      final entries = buildNotificationFeedEntries(items);
      expect(entries, hasLength(2));
      expect(entries.every((e) => e is NotificationSingleEntry), isTrue);
    });

    test('unread and interactive items are never folded into a group', () {
      final items = [
        _n(
          id: 'u',
          title: 'Специалист отклонил заявку REQ-A1',
          status: NotificationStatus.pending,
        ),
        _n(id: 'a', title: 'Специалист отклонил заявку REQ-A2'),
        _n(id: 'b', title: 'Специалист отклонил заявку REQ-A3'),
        _n(id: 'c', title: 'Специалист отклонил заявку REQ-A4'),
      ];
      final entries = buildNotificationFeedEntries(items);
      // The 3 read ones group; the pending one stays a single card.
      final groups = entries.whereType<NotificationGroupEntry>().toList();
      final singles = entries.whereType<NotificationSingleEntry>().toList();
      expect(groups, hasLength(1));
      expect(groups.single.count, 3);
      expect(singles, hasLength(1));
      expect(singles.single.notification.id, 'u');
    });

    test('commented member is split out; the rest still group', () {
      final items = [
        _n(
          id: 'c',
          title: 'Специалист отклонил заявку REQ-A1',
          payload: const {'reason': 'зачем ?'},
        ),
        _n(id: 'a', title: 'Специалист отклонил заявку REQ-A2'),
        _n(id: 'b', title: 'Специалист отклонил заявку REQ-A3'),
        _n(id: 'd', title: 'Специалист отклонил заявку REQ-A4'),
      ];
      final entries = buildNotificationFeedEntries(items);
      final groups = entries.whereType<NotificationGroupEntry>().toList();
      final singles = entries.whereType<NotificationSingleEntry>().toList();
      expect(groups, hasLength(1));
      expect(groups.single.count, 3);
      expect(singles, hasLength(1));
      expect(singles.single.notification.id, 'c');
    });

    test('group is positioned at its newest member (order preserved)', () {
      final items = [
        _n(
          id: 'top',
          title: 'Новая заявка на осмотр',
          createdAt: DateTime.utc(2026, 7, 11, 20, 0),
        ),
        for (var i = 0; i < 3; i++)
          _n(
            id: 'r$i',
            title: 'Специалист отклонил заявку REQ-A${i + 1}',
            createdAt: DateTime.utc(2026, 7, 11, 19 - i, 0),
          ),
      ];
      final entries = buildNotificationFeedEntries(items);
      expect(entries, hasLength(2));
      expect(entries.first, isA<NotificationSingleEntry>());
      expect(entries.last, isA<NotificationGroupEntry>());
    });
  });
}

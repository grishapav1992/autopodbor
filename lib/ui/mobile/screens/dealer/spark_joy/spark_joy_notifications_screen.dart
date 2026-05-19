import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/state/notification_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_notification_actions.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Notifications feed — dealer/specialist side.
///
/// Backed by [NotificationController] (HTTP + realtime push). On-screen
/// reactions:
///   • `task` / `invitation` show inline accept / reject buttons that
///     call `Notification.ActionNotification`.
///   • `reminder` / `system` mark themselves read on first tap.
///   • Pull-to-refresh re-fetches page 1 from the backend.
///
/// Notifications cannot be deleted by the user (per spec); status
/// transitions (`pending` → `accepted` / `rejected` / `read`) are how
/// they "leave" the feed visually.
class SparkJoyNotificationsScreen extends StatefulWidget {
  const SparkJoyNotificationsScreen({super.key, this.onOpenRequest});

  final Future<void> Function(int requestId)? onOpenRequest;

  @override
  State<SparkJoyNotificationsScreen> createState() =>
      _SparkJoyNotificationsScreenState();
}

class _SparkJoyNotificationsScreenState
    extends State<SparkJoyNotificationsScreen> {
  late final NotificationController _controller =
      Get.find<NotificationController>();

  @override
  void initState() {
    super.initState();
    // Fire-and-forget — the controller already has page 1 from
    // bootstrap; this just refreshes to pick up anything that arrived
    // while the screen was off-screen.
    _controller.reload();
  }

  Future<void> _handleTap(BackendNotification n) async {
    final requestId = n.requestId;
    if (requestId != null && widget.onOpenRequest != null) {
      if (!n.type.isInteractive && n.status == NotificationStatus.pending) {
        try {
          await _controller.markRead(n.id);
        } catch (_) {
          // Navigation is still useful even if mark-read failed. The
          // next reload will reconcile notification status.
        }
      }
      await widget.onOpenRequest!(requestId);
      return;
    }
    // Interactive types are dismissed via accept/reject — tapping the
    // body should not silently mark them anything.
    if (n.type.isInteractive) return;
    if (n.status != NotificationStatus.pending) return;
    try {
      await _controller.markRead(n.id);
    } catch (_) {
      // Controller already reverted optimistic update; nothing else to
      // do — the next reload will sync.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = _controller.loading.value;
      final items = _controller.items;
      if (loading && items.isEmpty) {
        return const SparkLoadingState(message: 'Загрузка уведомлений...');
      }
      if (items.isEmpty) {
        return RefreshIndicator(
          onRefresh: _controller.reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SparkEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Нет уведомлений',
                subtitle:
                    'Здесь появятся сообщения о назначениях, приёмке и статусах отчётов.',
                topPadding: SparkSpace.xxxl,
              ),
            ],
          ),
        );
      }
      final groups = _groupByDate(items.toList());
      return RefreshIndicator(
        onRefresh: _controller.reload,
        child: SparkScreenList(
          bottomInset: 56,
          children: [
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: SparkSpace.md,
                  bottom: SparkSpace.sm,
                ),
                child: MyText(
                  text: group.label.toUpperCase(),
                  size: SparkTextSize.chip,
                  weight: FontWeight.w700,
                  color: kGreyColor,
                ),
              ),
              for (final n in group.items)
                _NotificationCard(notification: n, onTap: () => _handleTap(n)),
            ],
            const SizedBox(height: SparkSpace.xl),
          ],
        ),
      );
    });
  }

  /// Groups notifications into ordered buckets: Сегодня, Вчера, Ранее.
  List<_NotificationGroup> _groupByDate(List<BackendNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayItems = <BackendNotification>[];
    final yesterdayItems = <BackendNotification>[];
    final earlierItems = <BackendNotification>[];
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final n in sorted) {
      final localDate = n.createdAt.toLocal();
      final d = DateTime(localDate.year, localDate.month, localDate.day);
      if (d == today) {
        todayItems.add(n);
      } else if (d == yesterday) {
        yesterdayItems.add(n);
      } else {
        earlierItems.add(n);
      }
    }
    return <_NotificationGroup>[
      if (todayItems.isNotEmpty)
        _NotificationGroup(label: 'Сегодня', items: todayItems),
      if (yesterdayItems.isNotEmpty)
        _NotificationGroup(label: 'Вчера', items: yesterdayItems),
      if (earlierItems.isNotEmpty)
        _NotificationGroup(label: 'Ранее', items: earlierItems),
    ];
  }
}

class _NotificationGroup {
  const _NotificationGroup({required this.label, required this.items});

  final String label;
  final List<BackendNotification> items;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final BackendNotification notification;
  final VoidCallback onTap;

  _TypeStyle _styleForType(NotificationType type) {
    switch (type) {
      case NotificationType.task:
        return _TypeStyle(
          icon: Icons.assignment_outlined,
          color: kSecondaryColor,
        );
      case NotificationType.invitation:
        return _TypeStyle(icon: Icons.group_add_outlined, color: kBlueColor);
      case NotificationType.reminder:
        return _TypeStyle(icon: Icons.schedule_rounded, color: kYellowColor);
      case NotificationType.system:
        return _TypeStyle(icon: Icons.info_outline_rounded, color: kGreyColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleForType(notification.type);
    final unread = notification.status == NotificationStatus.pending;
    return SparkListCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.lg,
      ),
      backgroundColor: unread
          ? style.color.withValues(alpha: 0.04)
          : kWhiteColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(style.icon, size: 20, color: style.color),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: MyText(
                            text: notification.title,
                            size: SparkTextSize.body,
                            weight: unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: SparkSpace.sm),
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: kSecondaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if ((notification.body ?? '').isNotEmpty)
                      MyText(
                        text: notification.body!,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                        lineHeight: 1.35,
                        maxLines: 3,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    MyText(
                      text: _formatRelative(notification.createdAt),
                      size: SparkTextSize.chip,
                      color: kGreyColor,
                      paddingTop: SparkSpace.sm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (notification.isInteractivePending)
            SparkJoyNotificationActions(notification: notification),
        ],
      ),
    );
  }
}

class _TypeStyle {
  const _TypeStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Human-readable elapsed time for a notification.
String _formatRelative(DateTime ts) {
  final local = ts.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inSeconds < 45) return 'только что';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${_pluralMin(m)} назад';
  }
  if (diff.inHours < 24 && now.day == local.day) {
    final h = diff.inHours;
    return '$h ${_pluralHour(h)} назад';
  }
  final yesterday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 1));
  final tsDate = DateTime(local.year, local.month, local.day);
  if (tsDate == yesterday) {
    return 'вчера, ${_hhmm(local)}';
  }
  return '${_dd(local.day)}.${_dd(local.month)}.${local.year}, ${_hhmm(local)}';
}

String _pluralMin(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'минуту';
  if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
    return 'минуты';
  }
  return 'минут';
}

String _pluralHour(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'час';
  if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
    return 'часа';
  }
  return 'часов';
}

String _dd(int n) => n < 10 ? '0$n' : '$n';
String _hhmm(DateTime ts) => '${_dd(ts.hour)}:${_dd(ts.minute)}';

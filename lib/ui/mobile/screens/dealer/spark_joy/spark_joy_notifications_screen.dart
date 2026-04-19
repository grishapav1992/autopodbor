import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_notifications_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Notifications feed — dealer/specialist side.
///
/// Scope per product spec:
///   • universal card layout, no per-type drill-in yet,
///   • unread / read visual distinction,
///   • cannot be deleted by the user,
///   • title / short message / relative time / group headers.
///
/// The screen listens to [SparkJoyNotificationsStorage.notifier] so the
/// list rebuilds instantly when a tap marks an item as read — no manual
/// refresh required.
class SparkJoyNotificationsScreen extends StatefulWidget {
  const SparkJoyNotificationsScreen({super.key});

  @override
  State<SparkJoyNotificationsScreen> createState() =>
      _SparkJoyNotificationsScreenState();
}

class _SparkJoyNotificationsScreenState
    extends State<SparkJoyNotificationsScreen> {
  Future<List<SparkJoyNotification>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
    SparkJoyNotificationsStorage.notifier.addListener(_onStorageChanged);
  }

  @override
  void dispose() {
    SparkJoyNotificationsStorage.notifier.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    _reload();
  }

  void _reload() {
    setState(() {
      _future = SparkJoyNotificationsStorage.load();
    });
  }

  Future<void> _handleTap(SparkJoyNotification n) async {
    if (n.read) return;
    await SparkJoyNotificationsStorage.markAsRead(n.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SparkJoyNotification>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SparkLoadingState(message: 'Загрузка уведомлений...');
        }
        final items = snapshot.data ?? const <SparkJoyNotification>[];
        if (items.isEmpty) {
          return const SparkEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Нет уведомлений',
            subtitle: 'Здесь появятся сообщения о назначениях, приёмке и статусах отчётов.',
            topPadding: SparkSpace.xxxl,
          );
        }
        final groups = _groupByDate(items);
        return SparkScreenList(
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
        );
      },
    );
  }

  /// Groups notifications into ordered buckets: Сегодня, Вчера, Ранее.
  List<_NotificationGroup> _groupByDate(List<SparkJoyNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayItems = <SparkJoyNotification>[];
    final yesterdayItems = <SparkJoyNotification>[];
    final earlierItems = <SparkJoyNotification>[];
    for (final n in items) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
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
  final List<SparkJoyNotification> items;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final SparkJoyNotification notification;
  final VoidCallback onTap;

  _TypeStyle _styleForType(SparkJoyNotificationType type) {
    switch (type) {
      case SparkJoyNotificationType.assignment:
        return _TypeStyle(icon: Icons.assignment_outlined, color: kSecondaryColor);
      case SparkJoyNotificationType.reportAccepted:
        return _TypeStyle(icon: Icons.check_circle_outline_rounded, color: kGreenColor);
      case SparkJoyNotificationType.reminder:
        return _TypeStyle(icon: Icons.schedule_rounded, color: kYellowColor);
      case SparkJoyNotificationType.message:
        return _TypeStyle(icon: Icons.chat_bubble_outline_rounded, color: kSecondaryColor);
      case SparkJoyNotificationType.system:
        return _TypeStyle(icon: Icons.info_outline_rounded, color: kGreyColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleForType(notification.type);
    final unread = !notification.read;
    return SparkListCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.lg,
      ),
      // Subtle tint + coloured left border for unread notifications so a
      // scanner can spot them without relying solely on the dot.
      backgroundColor: unread
          ? style.color.withValues(alpha: 0.04)
          : kWhiteColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading circular icon — one per notification type.
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
                    // Unread dot — outside the text block so it stays
                    // aligned with the title regardless of message length.
                    if (unread) ...[
                      const SizedBox(width: SparkSpace.sm),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: kSecondaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notification.message.isNotEmpty)
                  MyText(
                    text: notification.message,
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
    );
  }
}

class _TypeStyle {
  const _TypeStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Human-readable elapsed time for a notification.
/// Examples: "только что", "5 мин назад", "вчера, 18:30",
/// "15.04.2026, 09:15".
String _formatRelative(DateTime ts) {
  final now = DateTime.now();
  final diff = now.difference(ts);
  if (diff.inSeconds < 45) return 'только что';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${_pluralMin(m)} назад';
  }
  if (diff.inHours < 24 && now.day == ts.day) {
    final h = diff.inHours;
    return '$h ${_pluralHour(h)} назад';
  }
  final yesterday = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 1));
  final tsDate = DateTime(ts.year, ts.month, ts.day);
  if (tsDate == yesterday) {
    return 'вчера, ${_hhmm(ts)}';
  }
  return '${_dd(ts.day)}.${_dd(ts.month)}.${ts.year}, ${_hhmm(ts)}';
}

String _pluralMin(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'минуту';
  if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) return 'минуты';
  return 'минут';
}

String _pluralHour(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'час';
  if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) return 'часа';
  return 'часов';
}

String _dd(int n) => n < 10 ? '0$n' : '$n';
String _hhmm(DateTime ts) => '${_dd(ts.hour)}:${_dd(ts.minute)}';

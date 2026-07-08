import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/state/notification_controller.dart';

/// Backwards-compat shim for code that still references the old
/// SharedPreferences-backed notifications storage.
///
/// Real state now lives in [NotificationController]; this class is just
/// a passthrough so [SparkJoyShell]'s bell icon and the
/// [ensureSeedData] boot hook keep compiling without a wider rewrite.
/// New code should depend on [NotificationController] directly.
@Deprecated(
  'Use NotificationController via Get.find<NotificationController>().',
)
class SparkJoyNotificationsStorage {
  SparkJoyNotificationsStorage._();

  /// Bridges to [NotificationController.notifier] — bumps on every
  /// realtime push, refresh, mark-read, accept/reject.
  static ValueListenable<int> get notifier => NotificationController.notifier;

  /// Returns the current nav-badge count from the live controller.
  /// Includes pending notifications and backend items newer than the latest
  /// notification the user has seen in the feed.
  /// Future-typed for source compatibility with the old async API.
  static Future<int> unreadCount() async {
    if (!Get.isRegistered<NotificationController>()) return 0;
    return Get.find<NotificationController>().badgeCount.value;
  }

  /// Count of loaded passive (`reminder` / `system`) pending items — the ones
  /// «Прочитать всё» can actually mark. Drives that action's visibility.
  static Future<int> passiveUnreadCount() async {
    if (!Get.isRegistered<NotificationController>()) return 0;
    return Get.find<NotificationController>().passiveUnreadLoaded;
  }

  /// Marks all passive (`reminder` / `system`) pending notifications as read
  /// via the live controller. Interactive invitations are left untouched.
  /// Returns how many were marked and how many failed.
  static Future<({int marked, int failed})> markAllRead() async {
    if (!Get.isRegistered<NotificationController>()) {
      return (marked: 0, failed: 0);
    }
    return Get.find<NotificationController>().markAllRead();
  }

  /// No-op — backend now owns the feed; nothing to seed locally.
  /// Kept so the existing call in `spark_joy_shell.dart` stays valid.
  static Future<void> ensureSeedData() async {}
}

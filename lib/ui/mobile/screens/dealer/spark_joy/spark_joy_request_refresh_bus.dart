import 'package:flutter/foundation.dart';

/// Lightweight cross-tab signal for request list invalidation.
///
/// Request actions can happen outside the request tab (for example from
/// notifications). Screens that cache `Storage.GetRequest` results listen to
/// this notifier and reload when the backend request state changes.
class SparkJoyRequestRefreshBus {
  SparkJoyRequestRefreshBus._();

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void notifyChanged() {
    notifier.value = notifier.value + 1;
  }
}

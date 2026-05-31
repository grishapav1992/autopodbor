import 'package:flutter/foundation.dart';

/// Cross-tab signal to refresh the current user's profile.
///
/// Fired when something outside the profile tab changes the user's
/// profile/company state — primarily accepting a staff invite from a
/// notification, after which the linked company and role must update
/// immediately instead of waiting for a manual reload (B7). The shell
/// re-syncs the role/nav and the profile screen re-fetches its data.
class SparkJoyProfileRefreshBus {
  SparkJoyProfileRefreshBus._();

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static void notifyChanged() {
    notifier.value = notifier.value + 1;
  }
}

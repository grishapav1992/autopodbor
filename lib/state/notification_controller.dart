import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/notification_websocket_service.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_refresh_bus.dart';

/// Singleton controller for the realtime + paginated notification feed.
///
/// Lifecycle (orchestrated by `lib/app/main.dart`):
///   • [bootstrap] — read persisted notification token, start WS, fetch
///     first page. Idempotent: safe to call multiple times.
///   • [shutdown] — close WS, drop in-memory state. Called on logout.
///
/// State is exposed as Rx fields for `Obx`-bound widgets, plus a legacy
/// [notifier] (`ValueNotifier<int>`) so existing code that watches
/// `SparkJoyNotificationsStorage.notifier` keeps reacting after the
/// storage class is converted to a thin proxy in a follow-up step.
///
/// Push events from [NotificationWebsocketService] trigger a full
/// refetch — preview frames carry only minimal data and the spec says
/// `requiresFetch=true` is the norm. We debounce rapid bursts (e.g. a
/// company sending 5 invitations in a row) to a single refetch.
class NotificationController extends GetxController {
  static const int _pageLimit = 20;
  static const Duration _refetchDebounce = Duration(milliseconds: 300);

  // Rx state
  final RxList<BackendNotification> items = <BackendNotification>[].obs;
  final RxBool loading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString nextCursor = RxnString();

  /// Number of unread / pending entries — drives the bell badge.
  /// Counts every notification whose status is `pending`. `read` /
  /// `accepted` / `rejected` / `expired` do not count.
  final RxInt unreadCount = 0.obs;

  /// Legacy bridge for widgets still watching
  /// `SparkJoyNotificationsStorage.notifier`. Bumped on every state
  /// change so `ValueListenableBuilder` rebuilds.
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  StreamSubscription<NotificationPushEvent>? _pushSub;
  Timer? _refetchTimer;
  bool _started = false;

  /// Set when a push arrives while [reload] is mid-flight. Without this
  /// flag the second push silently no-ops and the UI stays stale until
  /// the next event. We re-issue the reload as soon as the current one
  /// completes.
  bool _pendingReload = false;

  /// Read persisted notification token and start the realtime channel +
  /// initial HTTP fetch. No-op if already bootstrapped or no token saved.
  Future<void> bootstrap() async {
    if (_started) return;
    _started = true;
    final token = await UserSimplePreferences.getNotificationToken();
    if (token == null || token.isEmpty) {
      _log('bootstrap: no notification token, deferring');
      _started = false;
      return;
    }
    _pushSub ??= NotificationWebsocketService.instance.stream
        .listen(_onPushEvent);
    // Let the WS recover from an expired notification token: on repeated
    // disconnects it refreshes all tokens and reconnects with the fresh
    // notification token instead of dying until re-login (B18).
    NotificationWebsocketService.instance.onTokenRefresh = () async {
      final refreshed = await StorageApi.tryRefreshTokens();
      if (!refreshed) return null;
      return UserSimplePreferences.getNotificationToken();
    };
    await NotificationWebsocketService.instance.start(token);
    await reload();
  }

  /// Re-bootstrap after a fresh login (token changed). Restarts WS.
  Future<void> rebootstrap() async {
    await shutdown();
    await bootstrap();
  }

  /// Cancel WS, clear in-memory state. Idempotent.
  Future<void> shutdown() async {
    _refetchTimer?.cancel();
    _refetchTimer = null;
    await _pushSub?.cancel();
    _pushSub = null;
    await NotificationWebsocketService.instance.stop();
    items.clear();
    unreadCount.value = 0;
    nextCursor.value = null;
    errorMessage.value = null;
    _pendingReload = false;
    _started = false;
    _bumpNotifier();
  }

  /// Full refetch of page 1. Replaces the in-memory list.
  ///
  /// If called while another reload is in flight, sets [_pendingReload]
  /// so the in-flight task re-issues itself on completion. Net effect:
  /// at most 2 requests are queued (current + pending), bursts collapse.
  Future<void> reload() async {
    if (loading.value) {
      _pendingReload = true;
      return;
    }
    loading.value = true;
    errorMessage.value = null;
    try {
      final page = await NotificationApi.getNotifications(
        page: 1,
        limit: _pageLimit,
      );
      items.assignAll(page.items);
      nextCursor.value = page.nextCursor;
      _recomputeUnread();
    } catch (e) {
      errorMessage.value = e.toString();
      _log('refresh failed: $e');
    } finally {
      loading.value = false;
      _bumpNotifier();
      if (_pendingReload) {
        _pendingReload = false;
        // Don't await — caller doesn't need to wait for the chained
        // refetch, and avoiding await keeps the recursion shallow.
        // ignore: discarded_futures
        reload();
      }
    }
  }

  /// Fetches the next page using cursor pagination and appends.
  Future<void> loadMore() async {
    final cursor = nextCursor.value;
    if (cursor == null || cursor.isEmpty || loading.value) return;
    loading.value = true;
    try {
      final page = await NotificationApi.getNotifications(
        limit: _pageLimit,
        cursor: cursor,
      );
      items.addAll(page.items);
      nextCursor.value = page.nextCursor;
      _recomputeUnread();
    } catch (e) {
      errorMessage.value = e.toString();
      _log('loadMore failed: $e');
    } finally {
      loading.value = false;
      _bumpNotifier();
    }
  }

  /// Marks a `reminder` / `system` notification as read with optimistic
  /// local update; reverts on backend failure.
  Future<void> markRead(String notificationId) async {
    final index = items.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;
    final original = items[index];
    if (original.status == NotificationStatus.read) return;
    items[index] = original.copyWith(status: NotificationStatus.read);
    _recomputeUnread();
    _bumpNotifier();
    try {
      await NotificationApi.markRead(notificationId);
    } catch (e) {
      // Revert on failure.
      items[index] = original;
      _recomputeUnread();
      _bumpNotifier();
      _log('markRead failed: $e');
      rethrow;
    }
  }

  /// Accept or reject an interactive `task` / `invitation` notification.
  /// Returns the server result (with `requestId` / `companyId` for
  /// downstream navigation).
  Future<NotificationActionResult> action({
    required String notificationId,
    required NotificationAction action,
  }) async {
    try {
      final result = await NotificationApi.actionNotification(
        notificationId: notificationId,
        action: action,
      );
      // Server is the source of truth for status — apply locally.
      final index = items.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        items[index] = items[index].copyWith(
          status: result.status,
          actedAt: DateTime.now().toUtc(),
        );
        _recomputeUnread();
        _bumpNotifier();
      }
      return result;
    } catch (e) {
      _log('action $action on $notificationId failed: $e');
      rethrow;
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────

  void _onPushEvent(NotificationPushEvent event) {
    if (!event.requiresFetch) return;
    // Debounce — collapse a burst of pushes into one refetch.
    _refetchTimer?.cancel();
    _refetchTimer = Timer(_refetchDebounce, () {
      reload();
      // A push can also mean a new/changed request (e.g. a task assigned to
      // a specialist). Signal the request lists to reload too so the
      // «Заявки» section stays fresh without a manual pull (B11).
      SparkJoyRequestRefreshBus.notifyChanged();
    });
  }

  void _recomputeUnread() {
    unreadCount.value = items
        .where((n) => n.status == NotificationStatus.pending)
        .length;
  }

  void _bumpNotifier() {
    notifier.value = notifier.value + 1;
  }

  static void _log(String message) {
    developer.log('[notif ctrl] $message', name: 'NotificationController');
  }

  @override
  void onClose() {
    shutdown();
    super.onClose();
  }
}

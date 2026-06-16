import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_application_1/core/config/app_endpoints.dart';
import 'package:flutter_application_1/data/api/notification_api_models.dart';
import 'package:flutter_application_1/data/api/pinned_http_client.dart';

/// Singleton long-lived WebSocket client for the realtime notification
/// channel at [AppEndpoints.notificationWebSocket].
///
/// Lifecycle:
///   1. App boot: bootstrap calls [start] with the persisted
///      `notificationToken` (from `Storage.Auth` / `Storage.AuthVerify`).
///   2. While connected: server pushes `Notification.Push` frames
///      (preview only) — we parse them into [NotificationPushEvent] and
///      emit on [stream].
///   3. Disconnects (network drop, server restart) trigger silent
///      exponential reconnect with jitter (1s → 30s, capped).
///   4. Logout / session-expired: bootstrap calls [stop] to tear down
///      cleanly without further reconnects.
///
/// The push frame contains only a preview — consumers should treat it
/// as a hint to refetch via `Notification.GetNotifications`. The
/// `requiresFetch` flag on [NotificationPushEvent] is `true` for the
/// vast majority of events.
///
/// Auth is via `?authorization=<notificationToken>` query parameter.
/// The backend auto-Verifies on connect — no client-side handshake
/// required after the URL.
class NotificationWebsocketService {
  NotificationWebsocketService._internal();

  static final NotificationWebsocketService instance =
      NotificationWebsocketService._internal();

  static const String _wsBase = AppEndpoints.notificationWebSocket;
  static const Duration _initialBackoff = Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 30);

  /// After this many consecutive connect failures with zero successful
  /// frames in between, the channel is treated as permanently dead
  /// (most likely an expired notification token — TTL is 72h and there
  /// is no client-side refresh). We stop reconnecting and emit nothing
  /// further; the next [start] call (e.g. after re-login) re-arms.
  static const int _maxConsecutiveFailures = 10;

  /// Shared `Random` for jitter — instantiating per call is cheap but
  /// creating many short-lived Random instances inside tight reconnect
  /// loops looks noisy in profilers.
  static final math.Random _jitterRng = math.Random();

  final StreamController<NotificationPushEvent> _eventsController =
      StreamController<NotificationPushEvent>.broadcast();

  /// Public realtime push stream. Hot — events are dropped if no one is
  /// listening. Subscribe early (during controller init).
  Stream<NotificationPushEvent> get stream => _eventsController.stream;

  /// Max number of token-refresh attempts before giving up for good. Each
  /// attempt is triggered after a full burst of [_maxConsecutiveFailures]
  /// connect failures, so this bounds the «refresh → still failing» loop.
  static const int _maxTokenRefreshAttempts = 2;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;
  Duration _currentBackoff = _initialBackoff;
  String? _token;
  bool _disposed = false;
  bool _shouldReconnect = false;
  int _consecutiveFailures = 0;
  bool _markedDead = false;
  bool _refreshingToken = false;
  int _tokenRefreshAttempts = 0;

  /// Optional hook that refreshes the auth/notification tokens and returns a
  /// fresh notification token (or null on failure). Wired by the controller
  /// so the data-layer WS client doesn't hard-depend on StorageApi. When set,
  /// repeated connect failures trigger a refresh + reconnect instead of the
  /// channel dying until the next re-login (B18).
  Future<String?> Function()? onTokenRefresh;

  /// True when the underlying channel is open and ready to receive.
  bool get isConnected => _channel != null && _channelSub != null;

  /// Starts (or restarts) the connection with the given notification
  /// token. If already connected with the same token, this is a no-op.
  /// If the token changed (e.g. after re-login), the old channel is
  /// closed and a new one opens.
  Future<void> start(String token) async {
    if (_disposed) return;
    if (token.isEmpty) {
      _log('start: empty token, refusing to connect');
      return;
    }
    if (_token == token && isConnected) {
      _log('start: already connected with same token');
      return;
    }
    _token = token;
    _shouldReconnect = true;
    _currentBackoff = _initialBackoff;
    _consecutiveFailures = 0;
    _markedDead = false;
    _tokenRefreshAttempts = 0;
    await _closeChannel();
    _connect();
  }

  /// Tears down the connection and cancels any pending reconnects.
  /// Idempotent. After calling, [start] reactivates.
  Future<void> stop() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeChannel();
    _token = null;
    _log('stopped');
  }

  /// Permanently disposes the singleton — intended for hot-restart only;
  /// production code should prefer [stop].
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _eventsController.close();
  }

  // ── Internals ─────────────────────────────────────────────────────────

  void _connect() {
    final token = _token;
    if (token == null || token.isEmpty || !_shouldReconnect || _disposed) {
      return;
    }
    final uri = AppEndpoints.notificationWebSocketUri(token);
    _log('connect: $_wsBase');
    try {
      final channel = connectPinnedWebSocketChannel(uri);
      _channel = channel;
      _channelSub = channel.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _log('connect-failed: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw == null) return;
    String text;
    if (raw is String) {
      text = raw;
    } else if (raw is List<int>) {
      try {
        text = utf8.decode(raw);
      } catch (_) {
        return;
      }
    } else {
      return;
    }
    if (text.isEmpty) return;
    Map<String, dynamic> frame;
    try {
      final decoded = json.decode(text);
      if (decoded is! Map) return;
      frame = decoded.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      _log(
        'drop-non-json frame=${text.length > 80 ? '${text.substring(0, 80)}…' : text}',
      );
      return;
    }
    // Reset backoff + failure counter on any valid frame — server is
    // healthy and the token works. Without this reset a brief network
    // hiccup followed by a successful reconnect would leave a stale
    // backoff value.
    _currentBackoff = _initialBackoff;
    _consecutiveFailures = 0;
    final event = NotificationPushEvent.tryParse(frame);
    if (event == null) {
      _log('drop-unknown response=${frame['response']}');
      return;
    }
    _log(
      'push id=${event.notificationId} event=${event.event.name} requiresFetch=${event.requiresFetch}',
    );
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  void _onError(Object error, StackTrace _) {
    _log('error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    _log(
      'done (closeCode=${_channel?.closeCode} reason=${_channel?.closeReason})',
    );
    _scheduleReconnect();
  }

  Future<void> _closeChannel() async {
    final sub = _channelSub;
    final channel = _channel;
    _channelSub = null;
    _channel = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }

  void _scheduleReconnect() {
    if (_disposed || !_shouldReconnect || _markedDead) return;
    // A token refresh is already in flight (B18). The old channel's straggler
    // onError/onDone must NOT increment failures or mark the channel dead here
    // — otherwise it flips _shouldReconnect=false and the refresh, on success,
    // bails at its own `!_shouldReconnect` guard and throws away a fresh token.
    // Let the in-flight refresh own the reconnect/give-up decision.
    if (_refreshingToken) return;
    // Coalesce — onError + onDone often fire back-to-back for the same
    // disconnect; without this guard backoff would double per failure.
    if (_reconnectTimer?.isActive == true) return;
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      // Before declaring the channel dead, try refreshing the tokens — a
      // burst of failures usually means the notification token expired
      // (TTL 72h). If the refresh yields a fresh token we reconnect with it
      // instead of forcing a re-login (B18).
      if (onTokenRefresh != null &&
          !_refreshingToken &&
          _tokenRefreshAttempts < _maxTokenRefreshAttempts) {
        // ignore: discarded_futures
        _attemptTokenRefreshAndReconnect();
        return;
      }
      _markedDead = true;
      _shouldReconnect = false;
      _log(
        'giving up after $_consecutiveFailures consecutive failures — '
        'token refresh exhausted. Re-login required.',
      );
      // Don't await — caller is in a sync callback path.
      // ignore: discarded_futures
      _closeChannel();
      return;
    }
    final delay = _withJitter(_currentBackoff);
    _log(
      'reconnect in ${delay.inMilliseconds}ms '
      '(backoff=${_currentBackoff.inSeconds}s, fails=$_consecutiveFailures)',
    );
    _reconnectTimer = Timer(delay, () async {
      await _closeChannel();
      _connect();
    });
    // Exponential bump for the NEXT failure, capped.
    final nextSeconds = math.min(
      _maxBackoff.inSeconds,
      _currentBackoff.inSeconds * 2,
    );
    _currentBackoff = Duration(seconds: nextSeconds);
  }

  /// Runs [onTokenRefresh]; on a fresh token, reconnects with it and resets
  /// the failure counter. On failure, marks the channel dead (B18).
  Future<void> _attemptTokenRefreshAndReconnect() async {
    if (_refreshingToken) return;
    _refreshingToken = true;
    _tokenRefreshAttempts += 1;
    _log(
      'token refresh attempt $_tokenRefreshAttempts after '
      '$_consecutiveFailures failures',
    );
    try {
      // Tear down the dead channel up front so its straggler onError/onDone
      // can't fire while the refresh RPC is pending.
      await _closeChannel();
      final fresh = await onTokenRefresh?.call();
      if (_disposed || !_shouldReconnect) return;
      if (fresh != null && fresh.isNotEmpty) {
        _token = fresh;
        _consecutiveFailures = 0;
        _currentBackoff = _initialBackoff;
        _markedDead = false;
        _log('token refreshed — reconnecting');
        _connect();
        return;
      }
      _markedDead = true;
      _shouldReconnect = false;
      _log('token refresh returned no token — giving up. Re-login required.');
      await _closeChannel();
    } catch (e) {
      _markedDead = true;
      _shouldReconnect = false;
      _log('token refresh failed ($e) — giving up. Re-login required.');
      await _closeChannel();
    } finally {
      _refreshingToken = false;
    }
  }

  static Duration _withJitter(Duration base) {
    // ±25% jitter to prevent thundering-herd on backend restart.
    final ms = base.inMilliseconds;
    final jitter = (_jitterRng.nextDouble() * 0.5 - 0.25) * ms;
    final result = math.max(250, (ms + jitter).round());
    return Duration(milliseconds: result);
  }

  static void _log(String message) {
    developer.log('[notif ws] $message', name: 'NotificationWebsocket');
  }
}

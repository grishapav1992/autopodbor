import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_application_1/data/api/notification_api_models.dart';

/// Singleton long-lived WebSocket client for the realtime notification
/// channel at `wss://77.83.92.234:2350/auth`.
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

  static const String _wsBase = 'wss://77.83.92.234:2350/auth';
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

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  Timer? _reconnectTimer;
  Duration _currentBackoff = _initialBackoff;
  String? _token;
  bool _disposed = false;
  bool _shouldReconnect = false;
  int _consecutiveFailures = 0;
  bool _markedDead = false;

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
    final uri = Uri.parse('$_wsBase?authorization=$token');
    _log('connect: $_wsBase');
    try {
      final channel = WebSocketChannel.connect(uri);
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
      _log('drop-non-json frame=${text.length > 80 ? '${text.substring(0, 80)}…' : text}');
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
    _log('push id=${event.notificationId} event=${event.event.name} requiresFetch=${event.requiresFetch}');
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  void _onError(Object error, StackTrace _) {
    _log('error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    _log('done (closeCode=${_channel?.closeCode} reason=${_channel?.closeReason})');
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
    // Coalesce — onError + onDone often fire back-to-back for the same
    // disconnect; without this guard backoff would double per failure.
    if (_reconnectTimer?.isActive == true) return;
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      _markedDead = true;
      _shouldReconnect = false;
      _log(
        'giving up after $_consecutiveFailures consecutive failures — '
        'token likely expired (TTL 72h). Re-login required.',
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

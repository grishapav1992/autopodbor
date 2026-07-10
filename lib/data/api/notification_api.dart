import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:flutter_application_1/core/config/app_endpoints.dart';
import 'package:flutter_application_1/data/api/pinned_http_client.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'notification_api_models.dart';
import 'storage_api.dart' show StorageApi, SessionExpiredException;

export 'notification_api_models.dart';

/// Client for the `Notification.*` RPC family on the storage backend
/// ([AppEndpoints.appRpc]).
///
/// Same JSON-RPC 2.0 transport as [StorageApi] (POST,
/// `application/json`, `{jsonrpc, id, method, params}`). Auth Bearer
/// token is the same access JWT [StorageApi] uses; refresh is delegated
/// to [StorageApi.tryRefreshTokens] to keep both clients in sync.
///
/// We do NOT reuse [StorageApi]'s private `_postRpc` (the project keeps
/// per-API transports isolated — see [AiQueueApi] for the same pattern)
/// — instead we mirror its envelope shape here. This keeps the storage
/// API's surface stable while letting Notification methods evolve
/// independently (e.g. different timeout defaults, different retry
/// policies).
class NotificationApi {
  NotificationApi._();

  static const String _endpoint = AppEndpoints.appRpc;
  static int _rpcSeq = 0;

  // Pinned HTTP client — MITM defence via cert public-key pinning in
  // release; plain client in debug (Charles/mitmproxy friendly).
  static final http.Client _httpClient = makePinnedHttpClient();

  // ── Public surface ────────────────────────────────────────────────────

  /// Paginated list of the current user's notifications. All filters are
  /// optional; defaults are page=1 / limit=20 server-side.
  static Future<NotificationsPage> getNotifications({
    int? page,
    int? limit,
    NotificationStatus? status,
    NotificationType? type,
    String? cursor,
  }) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    if (status != null) params['status'] = status.wireValue;
    if (type != null) params['type'] = type.wireValue;
    if (cursor != null && cursor.isNotEmpty) params['cursor'] = cursor;

    final data = await _postRpc(
      method: 'Notification.GetNotifications',
      params: params,
    );
    final result = _asMap(data['result']);
    final rawList = result['notifications'];
    final items = <BackendNotification>[];
    if (rawList is List) {
      for (final raw in rawList) {
        if (raw is Map) {
          items.add(
            BackendNotification.fromJson(
              raw.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }
    final pagination = _asMap(result['pagination']);
    final nextCursor = pagination['nextCursor']?.toString();
    return NotificationsPage(
      items: items,
      nextCursor: (nextCursor == null || nextCursor.isEmpty)
          ? null
          : nextCursor,
    );
  }

  /// Marks a `reminder` or `system` notification as read.
  static Future<void> markRead(String notificationId) async {
    await _postRpc(
      method: 'Notification.MarkRead',
      params: <String, dynamic>{'notificationId': notificationId},
    );
  }

  /// Accept or reject an interactive `task` / `invitation` notification.
  static Future<NotificationActionResult> actionNotification({
    required String notificationId,
    required NotificationAction action,
  }) async {
    final data = await _postRpc(
      method: 'Notification.ActionNotification',
      params: <String, dynamic>{
        'notificationId': notificationId,
        'action': action.wireValue,
      },
      // Дольше дефолтных 12с: бэк на этом методе может отвечать медленно
      // (внутренний IPC без серверного таймаута, NATS/email-рассылка ДО
      // ответа, таймаут его БД — 25с), а действие мутирующее — пользователь
      // ждёт с «Обрабатываем…». Прямой ответ лучше ложного таймаута с
      // последующим reconcile-восстановлением (см. NotificationController).
      timeout: const Duration(seconds: 30),
    );
    return NotificationActionResult.fromJson(_asMap(data['result']));
  }

  /// Send a notification to another user. Currently not wired into UI;
  /// exposed here so future flows can call it without re-discovery.
  ///
  /// Per OpenRPC: `system` cannot be created via SendNotification — it's
  /// produced only by the backend (feedback, expiry). The schema's enum
  /// for this method is task / invitation / reminder.
  static Future<void> sendNotification({
    required NotificationType type,
    required int recipientId,
    required String title,
    String? body,
    Map<String, dynamic>? payload,
  }) async {
    assert(
      type != NotificationType.system,
      'Notification.SendNotification rejects type=system; '
      'system notifications are server-issued only.',
    );
    final params = <String, dynamic>{
      'type': type.wireValue,
      'recipientId': recipientId,
      'title': title,
    };
    if (body != null && body.isNotEmpty) params['body'] = body;
    if (payload != null && payload.isNotEmpty) params['payload'] = payload;
    await _postRpc(method: 'Notification.SendNotification', params: params);
  }

  /// Debug-only — server requires `APP_DEBUG=true`. Sends a `reminder` or
  /// `system` notification to the current user. Useful for verifying
  /// realtime push end-to-end.
  static Future<void> debugSendToSelf({
    required NotificationType type,
    required String title,
    String? body,
    Map<String, dynamic>? payload,
  }) async {
    assert(
      type == NotificationType.reminder || type == NotificationType.system,
      'DebugSendNotificationToSelf accepts only reminder or system',
    );
    final params = <String, dynamic>{'type': type.wireValue, 'title': title};
    if (body != null && body.isNotEmpty) params['body'] = body;
    if (payload != null && payload.isNotEmpty) params['payload'] = payload;
    await _postRpc(
      method: 'Notification.DebugSendNotificationToSelf',
      params: params,
    );
  }

  // ── RPC plumbing ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _postRpc({
    required String method,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 12),
    bool requiresAuth = true,
    bool allowRefresh = true,
  }) async {
    final seq = ++_rpcSeq;
    final stopwatch = Stopwatch()..start();
    final payload = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': seq,
      'method': method,
      'params': params,
    };
    final bytes = utf8.encode(json.encode(payload));
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Content-Length': bytes.length.toString(),
    };
    var hasAuth = false;
    if (requiresAuth) {
      var accessToken = await UserSimplePreferences.getAccessToken();
      if (allowRefresh &&
          accessToken != null &&
          accessToken.isNotEmpty &&
          _isJwtExpired(accessToken, skew: const Duration(seconds: 15))) {
        _log('refresh-before-send', seq: seq, method: method);
        final refresh = await StorageApi.refreshTokensDetailed();
        if (refresh.isSuccess) {
          accessToken = await UserSimplePreferences.getAccessToken();
        } else if (refresh.isRejected) {
          throw const SessionExpiredException();
        } else {
          // Transient сбой refresh'а ≠ смерть сессии — пробрасываем
          // сетевую ошибку, не выкидывая пользователя на логин.
          throw refresh.asException();
        }
      }
      if (accessToken == null || accessToken.isEmpty) {
        throw const SessionExpiredException(
          'No access token for NotificationApi',
        );
      }
      headers['Authorization'] = 'Bearer $accessToken';
      hasAuth = true;
    }

    _log(
      'send',
      seq: seq,
      method: method,
      extra:
          'bytes=${bytes.length} timeout=${timeout.inSeconds}s auth=$hasAuth',
    );

    http.Response response;
    try {
      response = await _httpClient
          .post(Uri.parse(_endpoint), headers: headers, body: bytes)
          .timeout(timeout);
    } on TimeoutException catch (e) {
      _log('timeout', seq: seq, method: method);
      throw Exception(
        'Timeout on $method after ${timeout.inSeconds}s '
        '(elapsed=${stopwatch.elapsedMilliseconds}ms): $e',
      );
    } catch (e) {
      _log('transport-error', seq: seq, method: method, extra: 'err=$e');
      rethrow;
    }

    _log(
      'recv',
      seq: seq,
      method: method,
      extra:
          'status=${response.statusCode} bytes=${response.bodyBytes.length} elapsed=${stopwatch.elapsedMilliseconds}ms',
    );

    // HTTP-level retry on 401 — same dance as ai_queue_api.
    if (response.statusCode == 401 && requiresAuth && allowRefresh) {
      final refresh = await StorageApi.refreshTokensDetailed();
      if (refresh.isSuccess) {
        return _postRpc(
          method: method,
          params: params,
          timeout: timeout,
          requiresAuth: requiresAuth,
          allowRefresh: false,
        );
      }
      if (refresh.isRejected) {
        throw const SessionExpiredException();
      }
      throw refresh.asException();
    }

    if (response.statusCode != 200) {
      final body = response.body.trim();
      final shortBody = body.length > 400 ? '${body.substring(0, 400)}…' : body;
      throw Exception('HTTP ${response.statusCode} from $method: $shortBody');
    }

    final rawBody = response.body.trim();
    if (rawBody.isEmpty) {
      throw Exception('Empty response body from $method');
    }

    Map<String, dynamic> data;
    try {
      data = _asMap(json.decode(rawBody));
    } catch (_) {
      throw Exception('Invalid JSON response from $method: $rawBody');
    }

    final responseFlag = data['response']?.toString().toLowerCase() ?? '';
    if (responseFlag != 'success' && responseFlag != 'ok') {
      // Application-level Unauthorized → retry once after refresh.
      final errorsText = _extractErrorsText(data).toLowerCase();
      if (requiresAuth &&
          allowRefresh &&
          (responseFlag.contains('unauth') || errorsText.contains('unauth'))) {
        final refresh = await StorageApi.refreshTokensDetailed();
        if (refresh.isSuccess) {
          return _postRpc(
            method: method,
            params: params,
            timeout: timeout,
            requiresAuth: requiresAuth,
            allowRefresh: false,
          );
        }
        if (refresh.isRejected) {
          throw const SessionExpiredException();
        }
        throw refresh.asException();
      }
      final errorMsg = _extractErrorsText(data);
      throw Exception(
        errorMsg.isEmpty
            ? 'Bad response from $method (response=$responseFlag)'
            : '$method: $errorMsg',
      );
    }
    return data;
  }

  // ── Helpers (private duplicates of StorageApi internals) ──────────────

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  static DateTime? _jwtExpUtc(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final claims = json.decode(decoded);
      if (claims is! Map) return null;
      final exp = claims['exp'];
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          (exp.toDouble() * 1000).toInt(),
          isUtc: true,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isJwtExpired(String token, {Duration skew = Duration.zero}) {
    final exp = _jwtExpUtc(token);
    if (exp == null) return false;
    return DateTime.now().toUtc().add(skew).isAfter(exp);
  }

  static String _extractErrorsText(Map<String, dynamic> data) {
    final errors = data['errors'];
    if (errors is Map) {
      final msg = errors['message'];
      if (msg != null) return msg.toString();
    }
    if (errors is List) {
      final parts = <String>[];
      for (final item in errors) {
        if (item is Map) {
          final m = item['message'];
          if (m != null) parts.add(m.toString());
        } else if (item != null) {
          parts.add(item.toString());
        }
      }
      return parts.join('; ');
    }
    return errors?.toString() ?? '';
  }

  static void _log(
    String tag, {
    required int seq,
    required String method,
    String? extra,
  }) {
    final suffix = (extra == null || extra.isEmpty) ? '' : ' $extra';
    developer.log(
      '[notif rpc $tag] #$seq $method$suffix',
      name: 'NotificationApi',
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_application_1/core/config/app_endpoints.dart';
import 'package:flutter_application_1/data/api/pinned_http_client.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:http/http.dart' as http;

import 'storage_api.dart' show StorageApi, SessionExpiredException;

/// Wire-enum for `Feedback.SendFeedback.topic`. The backend accepts only
/// these three values (added 2026-05-13 in the storage RPC changelog):
///
///   - `question` — общий вопрос
///   - `help`     — нужна помощь / что-то не работает
///   - `proposal` — предложение по улучшению
enum FeedbackTopic {
  question('question'),
  help('help'),
  proposal('proposal');

  const FeedbackTopic(this.wireValue);
  final String wireValue;
}

/// Outcome of a `Feedback.SendFeedback` call. `accepted=true` means the
/// server queued the task in NATS; mail delivery happens asynchronously
/// and the client should treat acceptance as success.
class FeedbackSubmitResult {
  const FeedbackSubmitResult({required this.accepted, this.errorMessage});

  final bool accepted;
  final String? errorMessage;
}

/// Client for the `Feedback.*` RPC family on the storage backend
/// ([AppEndpoints.appRpc]). Per-API transport isolation, same
/// JSON-RPC 2.0 envelope as `StorageApi` / `NotificationApi`.
class FeedbackApi {
  FeedbackApi._();

  static const String _endpoint = AppEndpoints.appRpc;
  static int _rpcSeq = 0;

  // Pinned HTTP client — MITM defence via cert public-key pinning in
  // release; plain client in debug (Charles/mitmproxy friendly).
  static final http.Client _httpClient = makePinnedHttpClient();

  /// Sends a support-ticket-style message to the team. Identity fields
  /// (name, email, phone, role) are pulled by the server from the JWT —
  /// the client only sends `topic` + `message`.
  ///
  /// `message` length must be 10..5000 characters (server-validated).
  /// Throws [SessionExpiredException] if there's no valid access token.
  /// Other transport errors propagate as `Exception`s — caller is
  /// expected to surface them in a SnackBar.
  static Future<FeedbackSubmitResult> sendFeedback({
    required FeedbackTopic topic,
    required String message,
  }) async {
    final data = await _postRpc(
      method: 'Feedback.SendFeedback',
      params: <String, dynamic>{'topic': topic.wireValue, 'message': message},
    );
    // Server contract: `errors` array — empty/missing on success,
    // populated on validation/business failures.
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final msg = first is Map && first['message'] is String
          ? first['message'] as String
          : 'Не удалось отправить обращение.';
      return FeedbackSubmitResult(accepted: false, errorMessage: msg);
    }
    final result = data['result'];
    var accepted = false;
    if (result is Map && result['accepted'] is bool) {
      accepted = result['accepted'] as bool;
    }
    return FeedbackSubmitResult(accepted: accepted);
  }

  // ── transport ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _postRpc({
    required String method,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 15),
    bool allowRefresh = true,
  }) async {
    final seq = ++_rpcSeq;
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

    var accessToken = await UserSimplePreferences.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const SessionExpiredException('No access token for FeedbackApi');
    }
    headers['Authorization'] = 'Bearer $accessToken';

    // Не оборачиваем TimeoutException — экран ловит этот тип отдельно
    // и показывает дружелюбный текст «Долго не отвечает сервер».
    // SocketException / http.ClientException пробрасываем как есть —
    // экран распознаёт их по toString() и подменяет на «Нет соединения».
    final response = await _httpClient
        .post(Uri.parse(_endpoint), headers: headers, body: bytes)
        .timeout(timeout);

    // 401 → try to refresh once and retry.
    if (response.statusCode == 401 && allowRefresh) {
      final refreshed = await StorageApi.tryRefreshTokens();
      if (refreshed) {
        return _postRpc(
          method: method,
          params: params,
          timeout: timeout,
          allowRefresh: false,
        );
      }
      throw const SessionExpiredException();
    }

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode} on $method '
        '(${response.body.length} bytes)',
      );
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw Exception('Malformed JSON-RPC response for $method');
    }
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  }
}

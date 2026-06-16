import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:flutter_application_1/core/config/app_endpoints.dart';
import 'package:flutter_application_1/data/api/pinned_http_client.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'ai_queue_api_models.dart';
import 'storage_api.dart' show StorageApi, SessionExpiredException;

export 'ai_queue_api_models.dart';

/// Client for the AiQueue RPC API ([AppEndpoints.aiRpc]).
///
/// Transport differs from [StorageApi] — see the contrast table:
///
/// | | StorageApi | AiQueueApi |
/// |---|---|---|
/// | Content-Type | application/json | application/json |
/// | Auth         | Bearer header    | Bearer header |
/// | Payload      | `{jsonrpc, id, method, params}` | `{id, method, params}` |
/// | id semantic  | counter          | chatId (stable per element) |
///
/// Note: the OpenRPC `Doc` advertises `?token=<jwt>` query auth, but
/// the live backend (verified 2026-04-28) requires the same
/// `Authorization: Bearer` header that [StorageApi] uses. We send the
/// header and let the documented query form remain a fallback if it
/// ever becomes the canonical scheme.
///
/// Auth uses the same JWT as [StorageApi] (the backend validates the
/// shared token). Refresh is delegated to [StorageApi.tryRefreshTokens]
/// to avoid duplicating the refresh chain and keep both clients in sync.
class AiQueueApi {
  AiQueueApi._();

  static const String _endpoint = AppEndpoints.aiRpc;
  static int _rpcSeq = 0;

  // Pinned HTTP client — MITM defence via cert public-key pinning in
  // release; plain client in debug (Charles/mitmproxy friendly).
  static final http.Client _httpClient = makePinnedHttpClient();

  static const String _defaultChatModel = 'gpt-5.4';

  static void resetCaches() {}

  // ── Public surface ────────────────────────────────────────────────────

  /// `AiQueue.Doc` — OpenRPC document. No auth.
  static Future<Map<String, dynamic>> doc({String? getMethodByName}) async {
    final params = <String, dynamic>{};
    if (getMethodByName != null && getMethodByName.isNotEmpty) {
      params['getMethodByName'] = getMethodByName;
    }
    final data = await _postRpc(
      method: 'AiQueue.Doc',
      id: 0,
      params: params,
      requiresAuth: false,
    );
    final result = _asMap(data['result']);
    final doc = _asMap(result['doc']);
    return doc;
  }

  /// `AiQueue.Health` — health check. No auth.
  static Future<AiQueueHealth> health() async {
    final data = await _postRpc(
      method: 'AiQueue.Health',
      id: 0,
      params: const <String, dynamic>{},
      requiresAuth: false,
      timeout: const Duration(seconds: 6),
    );
    final result = _asMap(data['result']);
    return AiQueueHealth(
      status: result['status']?.toString() ?? '',
      nats: result['nats'] == true,
      uptime: _asInt(result['uptime']) ?? 0,
    );
  }

  /// `AiQueue.Models` — list of available models + server default.
  static Future<AiQueueModelsResult> models({int idHint = 0}) async {
    final data = await _postRpc(
      method: 'AiQueue.Models',
      id: idHint,
      params: const <String, dynamic>{},
    );
    final result = _asMap(data['result']);
    final rawModels = result['models'];
    final list = <AiQueueModel>[];
    if (rawModels is List) {
      for (final m in rawModels) {
        if (m is Map) {
          list.add(
            AiQueueModel.fromJson(m.map((k, v) => MapEntry(k.toString(), v))),
          );
        }
      }
    }
    return AiQueueModelsResult(
      models: list,
      defaultModel: result['default']?.toString() ?? '',
    );
  }

  /// `AiQueue.ChatCompletions` — synchronous chat call.
  ///
  /// [chatId] is the JSON-RPC `id` *and* the conversation key on the
  /// server. Reuse the same id to continue a thread; pick a new one to
  /// start fresh. Bound to `(JWT.sub, chatId)` on the backend.
  static Future<AiQueueChatCompletionResult> chatCompletions({
    required int chatId,
    required String text,
    required String cliche,
    List<String>? fileUrls,
    String? model,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final params = <String, dynamic>{'text': text, 'cliche': cliche};
    if (fileUrls != null && fileUrls.isNotEmpty) {
      params['fileUrls'] = fileUrls;
    }
    final resolvedModel = model ?? await resolveDefaultModel();
    if (resolvedModel.isNotEmpty) {
      params['model'] = resolvedModel;
    }
    final data = await _postRpc(
      method: 'AiQueue.ChatCompletions',
      id: chatId,
      params: params,
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    return AiQueueChatCompletionResult(chatId: chatId, raw: result);
  }

  /// `AiQueue.ClearChatHistory` — wipes the NATS KV entry for [chatId].
  /// Next call with the same id starts a fresh thread.
  static Future<void> clearChatHistory({required int chatId}) async {
    await _postRpc(
      method: 'AiQueue.ClearChatHistory',
      id: chatId,
      params: <String, dynamic>{'chatId': chatId},
    );
  }

  /// `AiQueue.GetChatHistories` — bulk fetch by chatId list.
  static Future<AiQueueChatHistories> getChatHistories({
    required List<int> ids,
    int idHint = 0,
  }) async {
    if (ids.isEmpty) {
      return const AiQueueChatHistories(chats: <int, AiQueueChatSession>{});
    }
    final data = await _postRpc(
      method: 'AiQueue.GetChatHistories',
      id: idHint,
      params: <String, dynamic>{'ids': ids},
    );
    final result = _asMap(data['result']);
    final rawChats = _asMap(result['chats']);
    final chats = <int, AiQueueChatSession>{};
    rawChats.forEach((key, value) {
      final chatId = int.tryParse(key);
      if (chatId == null || value is! Map) return;
      chats[chatId] = AiQueueChatSession.fromJson(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    });
    return AiQueueChatHistories(chats: chats);
  }

  /// Returns the product-selected default model for report text generation.
  /// We intentionally do not auto-upgrade to the highest `AiQueue.Models`
  /// entry: prompt behavior for inspection reports is calibrated against
  /// this model and should not drift when the backend exposes newer IDs.
  static Future<String> resolveDefaultModel() async {
    return _defaultChatModel;
  }

  // ── RPC plumbing ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _postRpc({
    required String method,
    required int id,
    required Map<String, dynamic> params,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 30),
    bool allowRefresh = true,
  }) async {
    final seq = ++_rpcSeq;
    final stopwatch = Stopwatch()..start();
    final payload = <String, dynamic>{
      'id': id,
      'method': method,
      'params': params,
    };
    final bytes = utf8.encode(json.encode(payload));

    final uri = Uri.parse(_endpoint);
    var hasAuth = false;
    final headers = <String, String>{
      'Accept': 'application/json',
      // Backend now expects JSON content-type on the AiQueue route too (same
      // as the Storage route) — the old text/plain (chosen to skip CORS
      // preflight) is no longer accepted server-side.
      'Content-Type': 'application/json',
      'Content-Length': bytes.length.toString(),
    };
    if (requiresAuth) {
      var accessToken = await UserSimplePreferences.getAccessToken();
      if (allowRefresh &&
          accessToken != null &&
          accessToken.isNotEmpty &&
          _isJwtExpired(accessToken, skew: const Duration(seconds: 15))) {
        _rpcLog('refresh-before-send', seq: seq, method: method);
        final refreshed = await StorageApi.tryRefreshTokens();
        if (refreshed) {
          accessToken = await UserSimplePreferences.getAccessToken();
        } else {
          _rpcLog('refresh-failed-clearing', seq: seq, method: method);
          throw const SessionExpiredException();
        }
      }
      if (accessToken == null || accessToken.isEmpty) {
        _rpcLog('no-token', seq: seq, method: method);
        throw const SessionExpiredException('No access token for AiQueue');
      }
      headers['Authorization'] = 'Bearer $accessToken';
      hasAuth = true;
    }

    _rpcLog(
      'send',
      seq: seq,
      method: method,
      extra:
          'bytes=${bytes.length} timeout=${timeout.inSeconds}s auth=$hasAuth id=$id',
    );

    http.Response response;
    try {
      response = await _httpClient
          .post(uri, headers: headers, body: bytes)
          .timeout(timeout);
    } on TimeoutException catch (e) {
      _rpcLog(
        'timeout',
        seq: seq,
        method: method,
        extra: 'elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
      throw Exception(
        'Timeout on $method after ${timeout.inSeconds}s '
        '(elapsed=${stopwatch.elapsedMilliseconds}ms): $e',
      );
    } catch (e) {
      _rpcLog(
        'transport-error',
        seq: seq,
        method: method,
        extra: 'elapsed=${stopwatch.elapsedMilliseconds}ms err=$e',
      );
      rethrow;
    }

    _rpcLog(
      'recv',
      seq: seq,
      method: method,
      extra:
          'status=${response.statusCode} bytes=${response.contentLength ?? response.bodyBytes.length} elapsed=${stopwatch.elapsedMilliseconds}ms',
    );

    if (response.statusCode == 401 && requiresAuth && allowRefresh) {
      _rpcLog('http-401-retry', seq: seq, method: method);
      final refreshed = await StorageApi.tryRefreshTokens();
      if (refreshed) {
        return _postRpc(
          method: method,
          id: id,
          params: params,
          requiresAuth: requiresAuth,
          timeout: timeout,
          allowRefresh: false,
        );
      }
      throw const SessionExpiredException();
    }

    if (response.statusCode != 200) {
      final body = response.body.trim();
      final shortBody = body.length > 400 ? '${body.substring(0, 400)}…' : body;
      _rpcLog(
        'http-error',
        seq: seq,
        method: method,
        extra: 'status=${response.statusCode} body=$shortBody',
      );
      throw Exception('HTTP ${response.statusCode} from $method: $shortBody');
    }

    final rawBody = response.body.trim();
    if (rawBody.isEmpty) {
      _rpcLog('empty-body', seq: seq, method: method);
      throw Exception('Empty response body from $method');
    }

    Map<String, dynamic> data;
    try {
      data = _asMap(json.decode(rawBody));
    } catch (_) {
      _rpcLog(
        'bad-json',
        seq: seq,
        method: method,
        extra:
            'body=${rawBody.length > 200 ? '${rawBody.substring(0, 200)}…' : rawBody}',
      );
      throw Exception('Invalid JSON response from $method: $rawBody');
    }

    final responseFlag = data['response']?.toString() ?? '';
    final responseFlagLc = responseFlag.toLowerCase();
    if (responseFlagLc != 'success' && responseFlagLc != 'ok') {
      if (requiresAuth &&
          allowRefresh &&
          (responseFlagLc.contains('unauth') ||
              _extractErrorsText(data).toLowerCase().contains('unauth'))) {
        final refreshed = await StorageApi.tryRefreshTokens();
        if (refreshed) {
          return _postRpc(
            method: method,
            id: id,
            params: params,
            requiresAuth: requiresAuth,
            timeout: timeout,
            allowRefresh: false,
          );
        }
        throw const SessionExpiredException();
      }
      final errors = _extractErrorsText(data);
      _rpcLog(
        'rpc-error',
        seq: seq,
        method: method,
        extra:
            'response=$responseFlag errors=${errors.isEmpty ? '(none)' : errors}',
      );
      throw Exception(
        errors.isEmpty
            ? 'Bad response from $method (response=$responseFlag)'
            : 'Bad response from $method (response=$responseFlag): $errors',
      );
    }

    _rpcLog(
      'ok',
      seq: seq,
      method: method,
      extra:
          'elapsed=${stopwatch.elapsedMilliseconds}ms bytes=${rawBody.length}',
    );
    return data;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static void _rpcLog(
    String stage, {
    required int seq,
    required String method,
    String extra = '',
  }) {
    final now = DateTime.now().toIso8601String();
    final suffix = extra.trim().isEmpty ? '' : ' $extra';
    developer.log(
      '[ai-rpc][$now][#$seq][$stage][$method]$suffix',
      name: 'AiQueueApi.rpc',
    );
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String _extractErrorsText(Map<String, dynamic> data) {
    final errors = data['errors'];
    if (errors is String) return errors;
    if (errors is List) {
      return errors
          .where((e) => e != null)
          .map(
            (e) => e is Map
                ? (e['message']?.toString() ?? e.toString())
                : e.toString(),
          )
          .where((s) => s.isNotEmpty)
          .join(' | ');
    }
    if (errors is Map) {
      return errors['message']?.toString() ?? errors.toString();
    }
    return '';
  }

  static DateTime? _jwtExpUtc(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    final payload = parts[1].trim();
    if (payload.isEmpty) return null;
    final mod = payload.length % 4;
    final normalized = mod == 0 ? payload : '$payload${'=' * (4 - mod)}';
    try {
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = json.decode(decoded);
      if (map is! Map) return null;
      final expRaw = map['exp'];
      final expSeconds = expRaw is num
          ? expRaw.toInt()
          : int.tryParse(expRaw?.toString() ?? '');
      if (expSeconds == null || expSeconds <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        expSeconds * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isJwtExpired(String token, {Duration skew = Duration.zero}) {
    final expUtc = _jwtExpUtc(token);
    if (expUtc == null) return false;
    final nowUtc = DateTime.now().toUtc().add(skew);
    return !nowUtc.isBefore(expUtc);
  }
}

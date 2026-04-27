import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'storage_api_models.dart';

// Re-export the data classes so existing callers keep working with just
// `import '.../storage_api.dart';` — no migration required at call sites.
export 'storage_api_models.dart';

class _CreateRequestCacheEntry {
  final DateTime sentAt;
  final CreateRequestResult result;

  const _CreateRequestCacheEntry({required this.sentAt, required this.result});
}

class _TokenPair {
  final String accessToken;
  final String refreshToken;

  const _TokenPair({required this.accessToken, required this.refreshToken});
}

/// Thrown by [StorageApi._postRpc] when an authenticated call has a
/// locally-expired access token and the server-side refresh has also
/// failed. Callers should unwind, clear UI state, and let the global
/// listener (see `SessionExpiredNotifier`) redirect to login instead
/// of retrying the same dead token.
class SessionExpiredException implements Exception {
  const SessionExpiredException([this.message = 'Session expired']);
  final String message;

  @override
  String toString() => 'SessionExpiredException: $message';
}

/// Single listenable the shell subscribes to so an expired session
/// discovered mid-session (e.g. during a background RPC) can kick
/// the user back to the login route without every callsite knowing.
/// Incremented on each expiry event so multiple rapid failures still
/// deliver distinct notifications.
final ValueNotifier<int> sessionExpiredTicker = ValueNotifier<int>(0);

void _notifySessionExpired() {
  sessionExpiredTicker.value = sessionExpiredTicker.value + 1;
}

class StorageApi {
  static const String _endpoint = 'https://podbor-av.ru.tuna.am';
  static final Map<String, Future<CreateRequestResult>>
  _createRequestInFlightByKey = {};
  static final Map<String, _CreateRequestCacheEntry> _recentCreateRequestByKey =
      {};
  static const Duration _createRequestDedupeWindow = Duration(seconds: 20);
  static int _createRequestSeq = 0;

  static void _debugCreateRequestLog(
    String stage, {
    required int seq,
    required String requestType,
    required String dedupeKey,
    String extra = '',
  }) {
    assert(() {
      final now = DateTime.now().toIso8601String();
      final shortKey = dedupeKey.hashCode.toUnsigned(32).toRadixString(16);
      final suffix = extra.trim().isEmpty ? '' : ' $extra';
      developer.log(
        '[CreateRequest][$now][#$seq][$stage][type=$requestType][key=$shortKey]$suffix',
        name: 'StorageApi',
      );
      return true;
    }());
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Future<Map<String, dynamic>> _postRpcFirstSuccess({
    required List<String> methods,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 12),
    bool includeAuth = true,
    bool allowRefresh = true,
  }) async {
    Object? lastError;
    for (final method in methods) {
      try {
        return await _postRpc(
          method: method,
          params: params,
          timeout: timeout,
          includeAuth: includeAuth,
          allowRefresh: allowRefresh,
        );
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      throw Exception(lastError.toString());
    }
    throw Exception('No RPC methods provided');
  }

  static String _todayIsoDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String? _normalizeIsoDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      final y = parsed.year.toString().padLeft(4, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final d = parsed.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    final ru = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
    if (ru != null) {
      final day = int.tryParse(ru.group(1)!);
      final month = int.tryParse(ru.group(2)!);
      final year = int.tryParse(ru.group(3)!);
      if (day != null && month != null && year != null) {
        final y = year.toString().padLeft(4, '0');
        final m = month.toString().padLeft(2, '0');
        final d = day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }
    }
    return value;
  }

  static String _extractString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      if (value is bool) {
        return value ? 'true' : 'false';
      }
    }
    return '';
  }

  static int? _readReportIdFromMap(Map<String, dynamic> report) {
    for (final key in const ['id', 'reportId', 'report_id']) {
      final raw = report[key];
      if (raw == null) continue;
      if (raw is int && raw > 0) return raw;
      final parsed = int.tryParse(raw.toString().trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  static String _readReportNumberFromMap(Map<String, dynamic> report) {
    return _extractString(report, [
      'reportNumber',
      'report_number',
      'number',
      'reportCode',
    ]);
  }

  static int? readSpecialistReportId(Map<String, dynamic> report) {
    return _readReportIdFromMap(_asMap(report));
  }

  static String readSpecialistReportNumber(Map<String, dynamic> report) {
    return _readReportNumberFromMap(_asMap(report));
  }

  static String _extractErrorsText(Map<String, dynamic> data) {
    final errors = data['errors'];
    final messages = <String>[];
    if (errors is String) {
      final value = errors.trim();
      if (value.isNotEmpty) messages.add(value);
    } else if (errors is Map) {
      final map = _asMap(errors);
      if (map['message'] != null) {
        final value = map['message'].toString().trim();
        if (value.isNotEmpty) messages.add(value);
      }
      for (final value in map.values) {
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) messages.add(text);
      }
    } else if (errors is List) {
      for (final item in errors) {
        if (item == null) continue;
        if (item is Map) {
          final map = _asMap(item);
          if (map['message'] != null) {
            final value = map['message'].toString().trim();
            if (value.isNotEmpty) messages.add(value);
          }
          for (final value in map.values) {
            if (value == null) continue;
            final text = value.toString().trim();
            if (text.isNotEmpty) messages.add(text);
          }
        } else {
          final value = item.toString().trim();
          if (value.isNotEmpty) messages.add(value);
        }
      }
    }
    return messages.toSet().join(' | ');
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
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
      final map = _asMap(json.decode(decoded));
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

  static int _rpcSeq = 0;

  /// Emits a structured RPC trace line visible in Console.app / `flutter
  /// logs` (filter by name "StorageApi.rpc"). Runs in every build mode —
  /// release / profile / debug — because we need device-side diagnostics
  /// for production timeouts. The payload itself is never logged, only
  /// metadata (method, byte size, auth state, timing, status, error
  /// class).
  static void _rpcLog(
    String stage, {
    required int seq,
    required String method,
    String extra = '',
  }) {
    final now = DateTime.now().toIso8601String();
    final suffix = extra.trim().isEmpty ? '' : ' $extra';
    developer.log(
      '[rpc][$now][#$seq][$stage][$method]$suffix',
      name: 'StorageApi.rpc',
    );
  }

  static Future<Map<String, dynamic>> _postRpc({
    required String method,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 12),
    bool includeAuth = true,
    bool allowRefresh = true,
  }) async {
    final seq = ++_rpcSeq;
    final stopwatch = Stopwatch()..start();
    final requestParams = Map<String, dynamic>.from(params);
    final payload = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': 0,
      'method': method,
      'params': requestParams,
    };
    final bytes = utf8.encode(json.encode(payload));
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Content-Length': bytes.length.toString(),
    };
    var hasAuth = false;
    if (includeAuth) {
      var accessToken = await UserSimplePreferences.getAccessToken();
      if (allowRefresh &&
          accessToken != null &&
          accessToken.isNotEmpty &&
          _isJwtExpired(accessToken, skew: const Duration(seconds: 15))) {
        _rpcLog('refresh-before-send', seq: seq, method: method);
        final refreshed = await _tryRefreshTokens();
        if (refreshed) {
          accessToken = await UserSimplePreferences.getAccessToken();
        } else {
          // Refresh failed → the stored access token is permanently
          // dead. Don't ship a Bearer the backend will log as
          // unauthenticated; instead wipe, surface a dedicated
          // exception, and signal the shell to redirect. `allowRefresh`
          // is false inside RefreshToken itself so this branch can't
          // recurse.
          _rpcLog('refresh-failed-clearing', seq: seq, method: method);
          await UserSimplePreferences.clearAuthTokens();
          _notifySessionExpired();
          throw const SessionExpiredException();
        }
      }
      // Defence-in-depth: if the access token is still expired after
      // a supposedly-successful refresh (e.g. server echoed the same
      // stale token back), fail fast rather than making yet another
      // unauth-looking call.
      if (accessToken != null &&
          accessToken.isNotEmpty &&
          _isJwtExpired(accessToken, skew: const Duration(seconds: 15))) {
        _rpcLog('refresh-returned-expired', seq: seq, method: method);
        await UserSimplePreferences.clearAuthTokens();
        _notifySessionExpired();
        throw const SessionExpiredException();
      }
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
        hasAuth = true;
      }
    }
    _rpcLog(
      'send',
      seq: seq,
      method: method,
      extra:
          'bytes=${bytes.length} timeout=${timeout.inSeconds}s auth=$hasAuth',
    );
    http.Response response;
    try {
      response = await http
          .post(Uri.parse(_endpoint), headers: headers, body: bytes)
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
    if (response.statusCode == 401 && includeAuth && allowRefresh) {
      _rpcLog('http-401-retry', seq: seq, method: method);
      final refreshed = await _tryRefreshTokens();
      if (refreshed) {
        return _postRpc(
          method: method,
          params: params,
          timeout: timeout,
          includeAuth: includeAuth,
          allowRefresh: false,
        );
      }
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
      if (shortBody.isNotEmpty) {
        throw Exception('HTTP ${response.statusCode} from $method: $shortBody');
      }
      throw Exception('HTTP ${response.statusCode} from $method');
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
        extra: 'body=${rawBody.length > 200 ? '${rawBody.substring(0, 200)}…' : rawBody}',
      );
      throw Exception('Invalid JSON response from $method: $rawBody');
    }
    final responseFlag = data['response']?.toString().toLowerCase() ?? '';
    if (responseFlag != 'ok') {
      if (includeAuth &&
          allowRefresh &&
          _isUnauthorizedResponse(data, responseFlag)) {
        _rpcLog('rpc-401-retry', seq: seq, method: method);
        final refreshed = await _tryRefreshTokens();
        if (refreshed) {
          return _postRpc(
            method: method,
            params: params,
            timeout: timeout,
            includeAuth: includeAuth,
            allowRefresh: false,
          );
        }
      }
      final errors = _extractErrorsText(data);
      _rpcLog(
        'rpc-error',
        seq: seq,
        method: method,
        extra:
            'response=$responseFlag errors=${errors.isEmpty ? '(none)' : errors}',
      );
      if (errors.isNotEmpty) {
        throw Exception(
          'Bad response from $method (response=$responseFlag): $errors',
        );
      }
      throw Exception('Bad response from $method (response=$responseFlag)');
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

  static bool _isUnauthorizedResponse(
    Map<String, dynamic> data,
    String responseFlag,
  ) {
    if (responseFlag.contains('unauthor')) return true;
    final errorsText = _extractErrorsText(data);
    if (errorsText.isEmpty) return false;
    return errorsText
        .split('|')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .any((m) => m.toLowerCase().contains('unauthor') || m.contains('401'));
  }

  static Future<bool> hasSavedSession({bool probeWithGetBrand = false}) async {
    final accessToken = await UserSimplePreferences.getAccessToken();
    final refreshToken = await UserSimplePreferences.getRefreshToken();
    final hasAccess = accessToken != null && accessToken.isNotEmpty;
    final hasRefresh = refreshToken != null && refreshToken.isNotEmpty;

    if (probeWithGetBrand) {
      // Force an authenticated probe call. If access token is expired,
      // _postRpc will run the standard 401 -> RefreshToken -> retry flow.
      return _probeSessionByGetBrand();
    }

    if (!hasAccess && !hasRefresh) return false;

    // Access token is present and still valid locally — accept.
    if (hasAccess &&
        !_isJwtExpired(accessToken, skew: const Duration(seconds: 15))) {
      return true;
    }

    // Access missing or expired. Without a refresh token we can't
    // recover — wipe whatever half-state we still have so next start
    // is guaranteed clean, then bail to the login flow.
    if (!hasRefresh) {
      await UserSimplePreferences.clearAuthTokens();
      return false;
    }

    // Try server-side refresh. If it fails we're truly dead — wipe.
    final refreshed = await _tryRefreshTokens();
    if (!refreshed) {
      await UserSimplePreferences.clearAuthTokens();
      return false;
    }

    // Defensive: if the refreshed access token is itself expired
    // (observed on dev backends that echo input tokens back), treat
    // it as a dead session instead of shipping a Bearer the server
    // will reject on the next RPC.
    final refreshedAccess = await UserSimplePreferences.getAccessToken();
    if (refreshedAccess == null ||
        refreshedAccess.isEmpty ||
        _isJwtExpired(refreshedAccess, skew: const Duration(seconds: 15))) {
      await UserSimplePreferences.clearAuthTokens();
      return false;
    }
    return true;
  }

  static Future<bool> _probeSessionByGetBrand() async {
    try {
      await _postRpcFirstSuccess(
        methods: const ['Storage.GetBrand'],
        params: {'search': ''},
        timeout: const Duration(seconds: 8),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryRefreshTokens() async {
    try {
      final refreshToken = await UserSimplePreferences.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final data = await _callRefreshToken(refreshToken);
      if (data == null) return false;
      final tokens = _extractTokens(data);
      if (tokens == null) return false;
      await UserSimplePreferences.setAuthTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _callRefreshToken(
    String refreshToken,
  ) async {
    try {
      return await _postRpc(
        method: 'RefreshToken',
        params: {'refreshToken': refreshToken},
        includeAuth: false,
        allowRefresh: false,
      );
    } catch (_) {}
    return null;
  }

  static _TokenPair? _extractTokens(Map<String, dynamic> data) {
    final result = _asMap(data['result']);
    var accessToken = _extractString(result, [
      'accessToken',
      'access_token',
      'token',
      'access',
    ]);
    var refreshToken = _extractString(result, [
      'refreshToken',
      'refresh_token',
      'refresh',
    ]);
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      accessToken = _extractString(data, [
        'accessToken',
        'access_token',
        'token',
        'access',
      ]);
      refreshToken = _extractString(data, [
        'refreshToken',
        'refresh_token',
        'refresh',
      ]);
    }
    if (accessToken.isEmpty || refreshToken.isEmpty) return null;
    return _TokenPair(accessToken: accessToken, refreshToken: refreshToken);
  }

  static Future<AuthStartResult> auth({
    required String phone,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpcFirstSuccess(
      methods: const ['Storage.Auth'],
      params: {'phone': phone},
      timeout: timeout,
      includeAuth: false,
    );
    final result = _asMap(data['result']);
    final callPhone = _extractString(result, [
      'callToPhone',
      'callPhone',
      'phoneForCall',
      'authPhone',
      'targetPhone',
      'phone',
    ]);
    if (callPhone.isEmpty) {
      throw Exception('Call phone is empty');
    }
    final sessionId = _extractString(result, ['sessionId', 'authId', 'id']);
    return AuthStartResult(
      callPhone: callPhone,
      sessionId: sessionId.isEmpty ? null : sessionId,
    );
  }

  static Future<AuthVerifyResult> authVerify({
    required String phone,
    String? sessionId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final params = <String, dynamic>{'phone': phone};
    if (sessionId != null && sessionId.isNotEmpty) {
      params['sessionId'] = sessionId;
    }
    final data = await _postRpcFirstSuccess(
      methods: const ['Storage.AuthVerify'],
      params: params,
      timeout: timeout,
      includeAuth: false,
    );
    final result = _asMap(data['result']);
    final accessToken = _extractString(result, [
      'accessToken',
      'access_token',
      'token',
      'access',
    ]);
    final refreshToken = _extractString(result, [
      'refreshToken',
      'refresh_token',
      'refresh',
    ]);
    return AuthVerifyResult(
      accessToken: accessToken.isEmpty ? null : accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
    );
  }

  static Future<CreateRequestResult> createRequest({
    required String requestType,
    required List<Map<String, dynamic>> requestCars,
    String? dueAt,
    String? note,
    String? city,
    int? budgetFrom,
    int? budgetTo,
    int? maxMileage,
    int? ownersCount,
    List<String>? tags,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalizedDueAt =
        _normalizeIsoDate(dueAt) ??
        _normalizeIsoDate(
          requestCars.isNotEmpty
              ? requestCars.first['dueAt']?.toString()
              : null,
        ) ??
        _todayIsoDate();

    final sanitizedRequestCars = requestCars.map((rawCar) {
      final car = _asMap(rawCar);
      final restylingsRaw = car['restylings'];
      final restylings = <int>[];
      if (restylingsRaw is List) {
        for (final item in restylingsRaw) {
          final id = _asInt(item);
          if (id == null || id <= 0) continue;
          restylings.add(id);
        }
      }
      final phone = car['phone']?.toString().trim() ?? '';
      final url = car['url']?.toString().trim() ?? '';
      return <String, dynamic>{
        'restylings': restylings,
        if (phone.isNotEmpty) 'phone': phone,
        if (url.isNotEmpty) 'url': url,
      };
    }).toList();

    final normalizedTags = (tags ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final seq = ++_createRequestSeq;
    final payload = <String, dynamic>{
      'dueAt': normalizedDueAt,
      'requestType': requestType,
      'requestCars': sanitizedRequestCars,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (budgetFrom != null) 'budgetFrom': budgetFrom,
      if (budgetTo != null) 'budgetTo': budgetTo,
      if (maxMileage != null) 'maxMileage': maxMileage,
      if (ownersCount != null) 'ownersCount': ownersCount,
      if (normalizedTags.isNotEmpty) 'tags': normalizedTags,
    };
    final dedupeKey = json.encode(payload);
    _debugCreateRequestLog(
      'prepare',
      seq: seq,
      requestType: requestType,
      dedupeKey: dedupeKey,
      extra: 'cars=${requestCars.length}',
    );
    final recent = _recentCreateRequestByKey[dedupeKey];
    if (recent != null &&
        DateTime.now().difference(recent.sentAt) <=
            _createRequestDedupeWindow) {
      _debugCreateRequestLog(
        'dedupe_recent',
        seq: seq,
        requestType: requestType,
        dedupeKey: dedupeKey,
        extra: 'id=${recent.result.id} number=${recent.result.requestNumber}',
      );
      return recent.result;
    }
    final inFlight = _createRequestInFlightByKey[dedupeKey];
    if (inFlight != null) {
      _debugCreateRequestLog(
        'dedupe_inflight',
        seq: seq,
        requestType: requestType,
        dedupeKey: dedupeKey,
      );
      return inFlight;
    }

    final future = () async {
      _debugCreateRequestLog(
        'send',
        seq: seq,
        requestType: requestType,
        dedupeKey: dedupeKey,
      );
      try {
        final data = await _postRpc(
          method: 'Storage.CreateRequest',
          params: payload,
          timeout: timeout,
        );
        final result = _asMap(data['result']);
        final id = _asInt(result['id']) ?? 0;
        final requestNumber = _extractString(result, [
          'requestNumber',
          'request_number',
          'number',
        ]);
        final created = CreateRequestResult(
          id: id,
          requestNumber: requestNumber,
        );
        _recentCreateRequestByKey[dedupeKey] = _CreateRequestCacheEntry(
          sentAt: DateTime.now(),
          result: created,
        );
        _debugCreateRequestLog(
          'success',
          seq: seq,
          requestType: requestType,
          dedupeKey: dedupeKey,
          extra: 'id=$id number=$requestNumber',
        );
        return created;
      } catch (e) {
        _debugCreateRequestLog(
          'error',
          seq: seq,
          requestType: requestType,
          dedupeKey: dedupeKey,
          extra: e.toString(),
        );
        rethrow;
      }
    }();

    _createRequestInFlightByKey[dedupeKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_createRequestInFlightByKey[dedupeKey], future)) {
        _createRequestInFlightByKey.remove(dedupeKey);
      }
    }
  }

  static Future<PrepareSpecialistReportResult> prepareSpecialistReport({
    required Map<String, dynamic> report,
    // Heavy endpoint: saves the full draft + generates presigned S3 URLs for
    // every inspection file. Large reports with 20+ media items routinely
    // need 60–150 s server-side; bumped from 90 s after timeouts surfaced
    // on the device. Server is idempotent per reportNumber, so a fresh
    // call with the same payload is safe if the caller decides to retry.
    Duration timeout = const Duration(seconds: 180),
  }) async {
    final data = await _postRpc(
      method: 'Storage.PrepareSpecialistReport',
      params: {'report': report},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final reportNumber = _extractString(result, [
      'reportNumber',
      'report_number',
      'number',
    ]);
    final reportId = _asInt(result['id']);
    final uploadFiles = <PreparedUploadFile>[];
    final rawUploadFiles = result['uploadFiles'];
    if (rawUploadFiles is List) {
      for (final item in rawUploadFiles) {
        final fileMap = _asMap(item);
        final filename = _extractString(fileMap, ['filename']);
        if (filename.isEmpty) continue;
        uploadFiles.add(
          PreparedUploadFile(
            filename: filename,
            type: _extractString(fileMap, ['type']),
            key: _extractString(fileMap, ['key']),
          ),
        );
      }
    }
    return PrepareSpecialistReportResult(
      reportNumber: reportNumber,
      reportId: reportId,
      uploadFiles: uploadFiles,
      result: result,
    );
  }

  static Future<SpecialistReportCompletionResult> completeSpecialistReport({
    required String reportNumber,
    // Heavy endpoint: verifies checksums of every uploaded file against S3
    // and flips `isDraft = false`. Bumped from 20 s after 90-s timeouts
    // showed up in the field under slow tuna.am tunnels.
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CompleteSpecialistReport',
      params: {'reportNumber': reportNumber},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final successRaw = result['success'];
    final hasSuccess = result.containsKey('success');
    final success = successRaw is bool
        ? successRaw
        : (successRaw?.toString().trim().toLowerCase() == 'true');
    if (hasSuccess && !success) {
      final errors = result['errors'];
      var errorText = '';
      if (errors is List) {
        errorText = errors
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .join(' | ');
      } else if (errors != null) {
        errorText = errors.toString().trim();
      }
      if (errorText.isNotEmpty) {
        throw Exception('Storage.CompleteSpecialistReport: $errorText');
      }
      throw Exception(
        'Storage.CompleteSpecialistReport вернул success=false',
      );
    }
    final reportId = _asInt(result['id']);
    return SpecialistReportCompletionResult(
      success: hasSuccess ? success : null,
      reportId: reportId,
      result: result,
    );
  }

  static Map<String, dynamic> _normalizeSpecialistReportMap(
    Map<String, dynamic> source,
  ) {
    final report = _asMap(source['report']);
    final base = <String, dynamic>{...source, ...report};
    final carStep = _asMap(base['carStep']);
    final characteristicsStep = _asMap(base['characteristicsStep']);
    final documentReconciliationStep = _asMap(
      base['documentReconciliationStep'],
    );
    final inspectionStep = _asMap(base['inspectionStep']);
    final testDriveStep = _asMap(base['testDriveStep']);
    final resultStep = _asMap(base['resultStep']);

    final normalized = Map<String, dynamic>.from(base);

    final id = _extractString(normalized, ['id', 'reportId', 'report_id']);
    if (id.isNotEmpty) normalized['id'] = id;

    final reportNumber = _extractString(normalized, [
      'reportNumber',
      'report_number',
      'number',
    ]);
    if (reportNumber.isNotEmpty) normalized['reportNumber'] = reportNumber;

    final reportName = _extractString(normalized, [
      'reportName',
      'name',
      'title',
    ]);
    if (reportName.isNotEmpty) normalized['reportName'] = reportName;

    final vin = _extractString(normalized, ['vin']);
    final carStepVin = _extractString(carStep, ['vin']);
    if (vin.isNotEmpty || carStepVin.isNotEmpty) {
      normalized['vin'] = vin.isNotEmpty ? vin : carStepVin;
    }

    final plate = _extractString(normalized, ['plate', 'gosNumber']);
    final carStepPlate = _extractString(carStep, ['gosNumber', 'plate']);
    if (plate.isNotEmpty || carStepPlate.isNotEmpty) {
      normalized['plate'] = plate.isNotEmpty ? plate : carStepPlate;
    }

    final mileageRaw = normalized['mileage'] ?? carStep['mileage'];
    if (mileageRaw != null && mileageRaw.toString().trim().isNotEmpty) {
      normalized['mileage'] = mileageRaw.toString();
    }

    final make = _extractString(normalized, ['make', 'brand']);
    final model = _extractString(normalized, ['model']);
    final car = _extractString(normalized, ['car']);
    if (make.isNotEmpty) normalized['make'] = make;
    if (model.isNotEmpty) normalized['model'] = model;
    if (car.isNotEmpty) {
      normalized['car'] = car;
    } else {
      final combined = [make, model].where((e) => e.isNotEmpty).join(' ');
      if (combined.isNotEmpty) normalized['car'] = combined;
    }

    final engineVolume = _extractString(characteristicsStep, [
      'engineVolume',
      'engine_volume',
    ]);
    final engineType = _extractString(characteristicsStep, [
      'engineType',
      'engine_type',
    ]);
    final engine = [
      engineVolume,
      engineType,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    if (engine.isNotEmpty) normalized['engine'] = engine;

    final transmission = _extractString(characteristicsStep, [
      'transmission',
      'transmissionType',
    ]);
    if (transmission.isNotEmpty) normalized['transmission'] = transmission;

    final drive = _extractString(characteristicsStep, ['driveType', 'drive']);
    if (drive.isNotEmpty) normalized['drive'] = drive;

    final createdAt = _extractString(normalized, [
      'createdAt',
      'reportDate',
      'date',
    ]);
    final dateInspection = _extractString(carStep, ['dateInspection']);
    if (createdAt.isNotEmpty || dateInspection.isNotEmpty) {
      normalized['createdAt'] = createdAt.isNotEmpty
          ? createdAt
          : dateInspection;
      normalized['date'] = normalized['createdAt'];
    }

    final verdict = _extractString(normalized, ['verdict']);
    final resultVerdict = _extractString(resultStep, ['verdict']);
    if (verdict.isNotEmpty || resultVerdict.isNotEmpty) {
      normalized['verdict'] = verdict.isNotEmpty ? verdict : resultVerdict;
    }

    final specialistNote = _extractString(resultStep, ['resultSpecialistNote']);
    if (specialistNote.isNotEmpty) {
      normalized['expertConclusion'] = specialistNote;
    }

    final inspector = _extractString(normalized, [
      'inspector',
      'specialistName',
      'expertName',
    ]);
    if (inspector.isNotEmpty) normalized['inspector'] = inspector;

    // ---- carStep → flat draft keys the editor hydration reads ----
    if (carStep['unreadableVin'] is bool) {
      normalized['vinUnreadable'] = carStep['unreadableVin'];
    }
    if (carStep['visuallyMileageNotMatchCondition'] is bool) {
      normalized['mileageMismatch'] = carStep['visuallyMileageNotMatchCondition'];
    }
    final cityInspection = _extractString(carStep, ['cityInspection']);
    if (cityInspection.isNotEmpty) {
      normalized['inspectionCity'] = cityInspection;
    }
    final dateInspection2 = _extractString(carStep, ['dateInspection']);
    if (dateInspection2.isNotEmpty) {
      normalized['inspectionDate'] = dateInspection2;
    }
    final uriListing = _extractString(carStep, ['uriListing']);
    if (uriListing.isNotEmpty) normalized['adLink'] = uriListing;

    // ---- characteristicsStep → flat ----
    final color = _extractString(characteristicsStep, ['color']);
    if (color.isNotEmpty) normalized['color'] = color;
    final equipment = _extractString(characteristicsStep, ['equipment']);
    if (equipment.isNotEmpty) normalized['trim'] = equipment;
    if (engineVolume.isNotEmpty) normalized['engineVolume'] = engineVolume;
    if (engineType.isNotEmpty) normalized['engineType'] = engineType;
    if (transmission.isNotEmpty) normalized['gearboxType'] = transmission;
    if (drive.isNotEmpty) normalized['driveType'] = drive;

    // ---- documentReconciliationStep → flat ----
    final ownersCountRaw = documentReconciliationStep['ownersCount'];
    if (ownersCountRaw != null) {
      normalized['ownersCount'] = ownersCountRaw.toString();
    }
    if (documentReconciliationStep['ownerFullNameMatchWithPtsOrSts'] is bool) {
      normalized['docsOwnerMatch'] =
          documentReconciliationStep['ownerFullNameMatchWithPtsOrSts'];
    }
    if (documentReconciliationStep['vinOnBodyMatchWithPtsOrSts'] is bool) {
      normalized['docsVinMatch'] =
          documentReconciliationStep['vinOnBodyMatchWithPtsOrSts'];
    }
    if (documentReconciliationStep['engineModelMatchWithPtsOrSts'] is bool) {
      normalized['docsEngineMatch'] =
          documentReconciliationStep['engineModelMatchWithPtsOrSts'];
    }

    // ---- inspectionStep → paint thickness defaults ----
    final bodyFrom = _asInt(inspectionStep['bodyPaintworkThicknessFrom']);
    final bodyTo = _asInt(inspectionStep['bodyPaintworkThicknessTo']);
    if (bodyFrom != null) normalized['bodyPaintFrom'] = bodyFrom;
    if (bodyTo != null) normalized['bodyPaintTo'] = bodyTo;
    final structFrom = _asInt(
      inspectionStep['bodyReinforcementPaintworkThicknessFrom'],
    );
    final structTo = _asInt(
      inspectionStep['bodyReinforcementPaintworkThicknessTo'],
    );
    if (structFrom != null) normalized['structPaintFrom'] = structFrom;
    if (structTo != null) normalized['structPaintTo'] = structTo;

    // ---- testDriveStep → flat ----
    if (testDriveStep['testDriveEngineIsWorkingProperly'] is bool) {
      normalized['tdEngineOk'] =
          testDriveStep['testDriveEngineIsWorkingProperly'];
    }
    if (testDriveStep['testDriveTransmissionIsWorkingProperly'] is bool) {
      normalized['tdGearboxOk'] =
          testDriveStep['testDriveTransmissionIsWorkingProperly'];
    }
    if (testDriveStep['testDriveSteeringWheelIsWorkingProperly'] is bool) {
      normalized['tdSteeringOk'] =
          testDriveStep['testDriveSteeringWheelIsWorkingProperly'];
    }
    if (testDriveStep['testDriveSuspensionInDriveIsWorkingProperly'] is bool) {
      normalized['tdRideOk'] =
          testDriveStep['testDriveSuspensionInDriveIsWorkingProperly'];
    }
    if (testDriveStep['testDriveBrakesInDriveIsWorkingProperly'] is bool) {
      normalized['tdBrakeOk'] =
          testDriveStep['testDriveBrakesInDriveIsWorkingProperly'];
    }
    final tdNote = _extractString(testDriveStep, ['testDriveNote']);
    if (tdNote.isNotEmpty) normalized['tdNote'] = tdNote;

    // ---- resultStep → summary note ----
    final summaryNote = _extractString(resultStep, [
      'summaryInspectionNote',
      'summary',
    ]);
    if (summaryNote.isNotEmpty) {
      normalized['summaryNote'] = summaryNote;
      normalized['summary'] = summaryNote;
    }

    return normalized;
  }

  static List<Map<String, dynamic>> _extractReportList(dynamic rawResult) {
    if (rawResult is List) {
      return rawResult.whereType<Map>().map((e) {
        return _normalizeSpecialistReportMap(_asMap(e));
      }).toList();
    }

    final resultMap = _asMap(rawResult);
    if (resultMap.isEmpty) return const <Map<String, dynamic>>[];
    final list =
        resultMap['items'] ??
        resultMap['reports'] ??
        resultMap['data'] ??
        resultMap['list'];
    if (list is List) {
      return list.whereType<Map>().map((e) {
        return _normalizeSpecialistReportMap(_asMap(e));
      }).toList();
    }

    final one = _normalizeSpecialistReportMap(resultMap);
    if (one.isNotEmpty &&
        (_extractString(one, ['id']).isNotEmpty ||
            _extractString(one, ['reportNumber']).isNotEmpty)) {
      return <Map<String, dynamic>>[one];
    }
    return const <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> getSpecialistReport({
    int page = 1,
    int limit = 20,
    bool isDraft = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetSpecialistReport',
      params: {'page': page, 'limit': limit, 'isDraft': isDraft},
      timeout: timeout,
    );
    return _extractReportList(data['result']);
  }

  static Future<int?> resolveSpecialistReportId({
    required Map<String, dynamic> report,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final local = _asMap(report);
    final directId = _readReportIdFromMap(local);
    if (directId != null) return directId;

    final reportNumber = _readReportNumberFromMap(local);
    final reportName = _extractString(local, ['reportName', 'name', 'title']);
    final createdAt = _extractString(local, ['createdAt', 'date', 'reportDate']);

    final remoteReports = await getSpecialistReport(
      page: 1,
      limit: 200,
      isDraft: false,
      timeout: timeout,
    );
    if (remoteReports.isEmpty) return null;

    if (reportNumber.isNotEmpty) {
      for (final remote in remoteReports) {
        final remoteNumber = _readReportNumberFromMap(remote);
        if (remoteNumber.isEmpty) continue;
        if (remoteNumber.trim() == reportNumber.trim()) {
          final resolved = _readReportIdFromMap(remote);
          if (resolved != null) return resolved;
        }
      }
    }

    if (reportName.isNotEmpty) {
      for (final remote in remoteReports) {
        final remoteName = _extractString(remote, ['reportName', 'name', 'title']);
        if (remoteName.trim() != reportName.trim()) continue;
        if (createdAt.isNotEmpty) {
          final remoteCreated = _extractString(remote, [
            'createdAt',
            'date',
            'reportDate',
          ]);
          if (remoteCreated.isNotEmpty &&
              !remoteCreated.startsWith(createdAt) &&
              !createdAt.startsWith(remoteCreated)) {
            continue;
          }
        }
        final resolved = _readReportIdFromMap(remote);
        if (resolved != null) return resolved;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>> viewSpecialistReport({
    required int reportId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'Storage.ViewSpecialistReport',
      params: {'id': reportId},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    if (result.isEmpty) return const <String, dynamic>{};
    return _normalizeSpecialistReportMap(result);
  }

  static Future<SpecialistReportShareUrlResult> createSpecialistReportShareUrl({
    required int reportId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CreateSpecialistReportShareUrl',
      params: {'reportId': reportId},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final url = _extractString(result, ['url', 'shareUrl', 'link']);
    return SpecialistReportShareUrlResult(url: url, result: result);
  }

  /// Returns a presigned GET URL for viewing / downloading a file from S3.
  /// Default TTL is 24 hours (server-side default). Empty string on failure.
  static Future<String> getTemporaryViewUrl({
    required String reportNumber,
    required String filename,
    int? expiresInSeconds,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (reportNumber.trim().isEmpty || filename.trim().isEmpty) return '';
    final params = <String, dynamic>{
      'reportNumber': reportNumber,
      'filename': filename,
      if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds,
    };
    try {
      final data = await _postRpc(
        method: 'ObjectStorage.GetTemporaryViewUrl',
        params: params,
        timeout: timeout,
      );
      return _extractString(_asMap(data['result']), ['url', 'signedUrl']);
    } catch (_) {
      return '';
    }
  }

  /// Resolves presigned view URLs for every `(reportNumber, filename)` pair
  /// in parallel, capped at [concurrency] in-flight requests. Returns a
  /// map keyed by filename; missing / failed entries are absent. Duplicate
  /// filenames across different `reportNumber` values use the last winner.
  static Future<Map<String, String>> getTemporaryViewUrlsBatch({
    required String reportNumber,
    required Iterable<String> filenames,
    int concurrency = 6,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final unique = filenames
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (unique.isEmpty) return const <String, String>{};

    final result = <String, String>{};
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        final idx = cursor;
        if (idx >= unique.length) return;
        cursor = idx + 1;
        final filename = unique[idx];
        final url = await getTemporaryViewUrl(
          reportNumber: reportNumber,
          filename: filename,
          timeout: timeout,
        );
        if (url.isNotEmpty) result[filename] = url;
      }
    }

    final workerCount = concurrency < unique.length
        ? concurrency
        : unique.length;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return result;
  }

  static Future<MultipartUploadSession> initiateMultipartUpload({
    required String reportNumber,
    required String filename,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.InitiateMultipartUpload',
      params: {'reportNumber': reportNumber, 'filename': filename},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final uploadId = _extractString(result, ['uploadId', 'uploadID', 'id']);
    final key = _extractString(result, ['key', 'path', 'objectKey']);
    if (uploadId.isEmpty) {
      throw Exception('Multipart uploadId is empty');
    }
    return MultipartUploadSession(uploadId: uploadId, key: key, result: result);
  }

  static Future<MultipartUploadUrlsResult> getPartUploadUrls({
    required String reportNumber,
    required String filename,
    required String uploadId,
    required int partCount,
    int? expiresInSeconds,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final params = <String, dynamic>{
      'reportNumber': reportNumber,
      'filename': filename,
      'uploadId': uploadId,
      'partCount': partCount,
      if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds,
    };
    final data = await _postRpc(
      method: 'ObjectStorage.GetPartUploadUrls',
      params: params,
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final key = _extractString(result, ['key', 'path', 'objectKey']);
    final urlsRaw = result['urls'];
    final urls = <MultipartUploadUrl>[];
    if (urlsRaw is List) {
      for (final item in urlsRaw) {
        if (item is! Map) continue;
        final map = _asMap(item);
        final partNumber = _asInt(map['partNumber']);
        final url = _extractString(map, ['url', 'signedUrl', 'uploadUrl']);
        if (partNumber == null || url.isEmpty) continue;
        urls.add(MultipartUploadUrl(partNumber: partNumber, url: url));
      }
    }
    urls.sort((a, b) => a.partNumber.compareTo(b.partNumber));
    return MultipartUploadUrlsResult(key: key, urls: urls, result: result);
  }

  static Future<String> uploadBytesToPresignedUrl({
    required String url,
    required List<int> bytes,
    String? contentType,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (url.trim().isEmpty) {
      throw Exception('Presigned URL is empty');
    }
    if (bytes.isEmpty) {
      throw Exception('Upload bytes are empty');
    }
    final headers = <String, String>{
      'Content-Length': bytes.length.toString(),
      if (contentType != null && contentType.trim().isNotEmpty)
        'Content-Type': contentType.trim(),
    };
    final response = await http
        .put(Uri.parse(url), headers: headers, body: bytes)
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload failed: HTTP ${response.statusCode}');
    }
    final etag = response.headers['etag'] ?? response.headers['ETag'] ?? '';
    return etag.trim();
  }

  static Future<MultipartCompleteResult> completeMultipartUpload({
    required String reportNumber,
    required String filename,
    required String uploadId,
    required List<MultipartUploadedPart> parts,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.CompleteMultipartUpload',
      params: {
        'reportNumber': reportNumber,
        'filename': filename,
        'uploadId': uploadId,
        'parts': parts.map((e) => e.toJson()).toList(),
      },
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final key = _extractString(result, ['key', 'path', 'objectKey']);
    return MultipartCompleteResult(key: key, result: result);
  }

  static Future<MultipartAbortResult> abortMultipartUpload({
    required String reportNumber,
    required String filename,
    required String uploadId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.AbortMultipartUpload',
      params: {
        'reportNumber': reportNumber,
        'filename': filename,
        'uploadId': uploadId,
      },
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final success =
        (result['success'] == true) ||
        (_extractString(result, ['success']).toLowerCase() == 'true');
    return MultipartAbortResult(success: success, result: result);
  }

  static Future<MultipartListPartsResult> listMultipartParts({
    required String reportNumber,
    required String filename,
    required String uploadId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.ListParts',
      params: {
        'reportNumber': reportNumber,
        'filename': filename,
        'uploadId': uploadId,
      },
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final key = _extractString(result, ['key', 'path', 'objectKey']);
    final partsRaw = result['parts'];
    final parts = <MultipartUploadedPart>[];
    if (partsRaw is List) {
      for (final item in partsRaw) {
        if (item is! Map) continue;
        final map = _asMap(item);
        final partNumber = _asInt(map['partNumber']);
        final etag = _extractString(map, ['etag', 'ETag']);
        if (partNumber == null || etag.isEmpty) continue;
        parts.add(MultipartUploadedPart(partNumber: partNumber, etag: etag));
      }
    }
    parts.sort((a, b) => a.partNumber.compareTo(b.partNumber));
    return MultipartListPartsResult(key: key, parts: parts, result: result);
  }

  static Future<List<Map<String, dynamic>>> getRequests({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetRequest',
      params: const {},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result.whereType<Map>().map((e) => _asMap(e)).toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list =
          map['items'] ?? map['requests'] ?? map['data'] ?? map['list'];
      if (list is List) {
        return list.whereType<Map>().map((e) => _asMap(e)).toList();
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getRequestCars({
    required int requestId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetRequestCar',
      params: {'requestId': requestId},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result.whereType<Map>().map((e) => _asMap(e)).toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list =
          map['items'] ??
          map['cars'] ??
          map['requestCars'] ??
          map['data'] ??
          map['list'];
      if (list is List) {
        return list.whereType<Map>().map((e) => _asMap(e)).toList();
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>> parseCarSourceUrl({
    required String url,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // Method removed from current Doc spec. Keep UI flow stable without RPC call.
    final normalized = url.trim();
    final uri = Uri.tryParse(normalized);
    return {
      if (normalized.isNotEmpty) 'url': normalized,
      if (uri != null) 'host': uri.host,
      'parsedLocally': true,
    };
  }

  static Future<Map<String, dynamic>> decodeVin({
    required String vin,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'DecodeVin',
      params: {'vin': vin.trim()},
      timeout: timeout,
      includeAuth: false,
    );
    return _asMap(data['result']);
  }

  static Future<Map<String, dynamic>> getVin({
    required String vin,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetVin',
      params: {'vin': vin.trim()},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  static Future<List<String>> getRequestTags({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'GetRequestTag',
      params: const {},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list = map['tags'] ?? map['items'] ?? map['data'];
      if (list is List) {
        return list
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const <String>[];
  }

  /// Returns user tags for a specific report step.
  ///
  /// [step] — required: car, characteristics, document_reconciliation,
  /// legal_review, inspection, test_drive, result.
  /// [section] — only for step=inspection: body, body_reinforcement, glass,
  /// interior, under_hood, wheels_and_brakes, lightning, computer_diagnostics.
  /// [selectedTagIds] — optional int[] for relevance sorting.
  /// Per the OpenRPC `Doc` description (фоrmal source of truth for
  /// the API contract), `step` accepts the underscore form:
  ///   `test_drive` / `legal_review` / `document_reconciliation`.
  /// We send what the spec mandates and align the server-side
  /// validator to match — the previous wire-form (`testdrive` etc.)
  /// matched the JSON-Schema `enum` field which is being treated as
  /// the inconsistent half of the spec and will be updated.
  ///
  /// Kept as a function (not removed) so a future divergence can be
  /// re-introduced at one place if the contract shifts again.
  static String _stepToWireEnum(String step) => step;

  static Future<List<UserTag>> getUserTags({
    required String step,
    String? section,
    List<int>? selectedTagIds,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final params = <String, dynamic>{'step': _stepToWireEnum(step)};
    if (section != null) params['section'] = section;
    if (selectedTagIds != null && selectedTagIds.isNotEmpty) {
      params['selectedTagIds'] = selectedTagIds;
    }
    final data = await _postRpc(
      method: 'Storage.GetUserTags',
      params: params,
      timeout: timeout,
    );
    final result = data['result'];
    if (result is! List) return const <UserTag>[];
    return result.whereType<Map>().map(_userTagFromMap).toList();
  }

  /// Parses a single UserTag object per OpenRPC Doc schema.
  /// Handles nullable step/section and normalizes the tri-state server
  /// `type` (serious | non_serious | null) into the two-value domain
  /// enum via [UserTagType.normalize].
  static UserTag _userTagFromMap(Map item) {
    String? nullableString(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return UserTag(
      id: _asInt(item['id']) ?? 0,
      step: nullableString(item['step']),
      section: nullableString(item['section']),
      name: (item['name'] ?? '').toString(),
      slug: (item['slug'] ?? '').toString(),
      type: UserTagType.normalize(item['type']),
      createdAt: nullableString(item['createdAt']),
      // userId: null = system tag, int = current user's own tag
      // (or another user's, if the server ever supports sharing).
      // Used downstream to gate the delete-affordance in the editor.
      userId: _asInt(item['userId']),
    );
  }

  /// Creates a user tag for a specific report step.
  ///
  /// [step] — required: car, characteristics, document_reconciliation,
  /// legal_review, inspection, test_drive, result.
  /// [name] — tag name (max 255 chars).
  /// [section] — only for step=inspection.
  /// [type] — domain severity; always sent to the server. Accepts any
  /// form understood by [UserTagType.normalize] (the enum itself,
  /// `'serious'`, `'non_serious'`, `'nonserious'`, null → nonserious).
  /// Returns the created (or existing) tag.
  static Future<UserTag> addUserTag({
    required String step,
    required String name,
    String? section,
    Object? type,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalizedType = UserTagType.normalize(type);
    final params = <String, dynamic>{
      'step': _stepToWireEnum(step),
      'name': name,
      'type': normalizedType.wireName,
    };
    if (section != null) params['section'] = section;
    final data = await _postRpc(
      method: 'Storage.AddUserTag',
      params: params,
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    return _userTagFromMap(result);
  }

  static Future<BrandCatalog> fetchBrandCatalog({
    String search = '',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final data = await _postRpcFirstSuccess(
      methods: const ['Storage.GetBrand'],
      params: {'search': search},
      timeout: timeout,
    );

    final result = data['result'];
    if (result is! List) {
      return BrandCatalog(
        items: const [],
        names: const [],
        rusByName: const {},
        idByName: const {},
      );
    }

    final names = <String>{};
    final items = <BrandItem>[];
    final rusByName = <String, String>{};
    final idByName = <String, int>{};
    for (final item in result) {
      if (item is Map && item['name'] is String) {
        final name = item['name'] as String;
        final id = _asInt(item['id']);
        if (id == null) continue;
        final nameRus = item['nameRus'] is String
            ? item['nameRus'] as String
            : '';
        names.add(name);
        idByName[name] = id;
        if (nameRus.isNotEmpty) {
          rusByName[name] = nameRus;
        }
        items.add(BrandItem(id: id, name: name, nameRus: nameRus));
      }
    }
    final list = names.toList()..sort();
    return BrandCatalog(
      items: items,
      names: list,
      rusByName: rusByName,
      idByName: idByName,
    );
  }

  static Future<List<String>> fetchBrands({
    String search = '',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final catalog = await fetchBrandCatalog(search: search, timeout: timeout);
    return catalog.names;
  }

  static Future<List<ModelItem>> fetchModels({
    required int brandId,
    String search = '',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final params = <String, dynamic>{'brandId': brandId};
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    final data = await _postRpcFirstSuccess(
      methods: const ['Storage.GetModelCar'],
      params: params,
      timeout: timeout,
    );

    final result = data['result'];
    if (result is! List) return [];
    final items = <ModelItem>[];
    for (final item in result) {
      if (item is Map && item['model'] is String) {
        final id = _asInt(item['id']);
        final brand = _asInt(item['brandId']);
        if (id == null || brand == null) continue;
        items.add(
          ModelItem(
            id: id,
            brandId: brand,
            model: item['model'] as String,
            modelRus: item['modelRus'] is String
                ? item['modelRus'] as String
                : '',
          ),
        );
      }
    }
    items.sort((a, b) => a.model.compareTo(b.model));
    return items;
  }

  static Future<List<GenerationItem>> fetchGenerations({
    required int modelCarId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetModelGeneration',
      params: {'modelCarId': modelCarId},
      timeout: timeout,
    );

    final result = data['result'];
    if (result is! List) return [];
    final items = <GenerationItem>[];
    for (final item in result) {
      if (item is! Map) continue;
      final id = _asInt(item['id']);
      if (id == null) continue;
      final frames = _parseFrames(item['frames']);
      final restylings = _parseRestylings(item['restylings']);
      items.add(
        GenerationItem(
          id: id,
          modelCarId: _asInt(item['modelCarId']) ?? 0,
          generation: _asInt(item['generation']) ?? 0,
          frames: frames,
          restylings: restylings,
        ),
      );
    }
    items.sort((a, b) => b.generation.compareTo(a.generation));
    return items;
  }

  static List<FrameItem> _parseFrames(dynamic raw) {
    if (raw is! List) return [];
    final items = <FrameItem>[];
    for (final item in raw) {
      if (item is Map && item['frame'] is String) {
        final id = _asInt(item['id']);
        if (id == null) continue;
        items.add(FrameItem(id: id, frame: item['frame']));
      }
    }
    return items;
  }

  static int? _parseYear(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String && raw.length >= 4) {
      return int.tryParse(raw.substring(0, 4));
    }
    if (raw is Map && raw['date'] is String) {
      final date = raw['date'] as String;
      if (date.length >= 4) {
        return int.tryParse(date.substring(0, 4));
      }
    }
    return null;
  }

  static List<PhotoItem> _parsePhotos(dynamic raw) {
    if (raw is! List) return [];
    final items = <PhotoItem>[];
    for (final item in raw) {
      if (item is Map &&
          item['size'] is String &&
          item['urlX1'] is String &&
          item['urlX2'] is String) {
        final id = _asInt(item['id']);
        if (id == null) continue;
        items.add(
          PhotoItem(
            id: id,
            size: item['size'] as String,
            urlX1: item['urlX1'] as String,
            urlX2: item['urlX2'] as String,
          ),
        );
      }
    }
    return items;
  }

  static List<RestylingItem> _parseRestylings(dynamic raw) {
    if (raw is! List) return [];
    final items = <RestylingItem>[];
    for (final item in raw) {
      if (item is! Map || item['restyling'] == null) {
        continue;
      }
      final id = _asInt(item['id']);
      if (id == null) continue;
      final frames = _parseFrames(item['frames']);
      final photos = _parsePhotos(item['photos']);
      items.add(
        RestylingItem(
          id: id,
          restyling: item['restyling'].toString(),
          yearStart: _parseYear(item['yearStart']),
          yearEnd: _parseYear(item['yearEnd']),
          frames: frames,
          photos: photos,
        ),
      );
    }
    return items;
  }

  // ---------------------------------------------------------------------------
  // Tag management
  // ---------------------------------------------------------------------------

  /// Deletes a user-owned tag by id.
  ///
  /// Only tags owned by the caller can be removed; shared/system tags
  /// (user_id = null) return an error.
  ///
  /// [id] — tag id (required, ≥1).
  /// [step] — required: car, characteristics, document_reconciliation,
  /// legal_review, inspection, test_drive, result.
  /// [section] — only for step=inspection.
  static Future<void> removeUserTag({
    required int id,
    required String step,
    String? section,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final params = <String, dynamic>{'id': id, 'step': _stepToWireEnum(step)};
    if (section != null) params['section'] = section;
    await _postRpc(
      method: 'Storage.RemoveUserTag',
      params: params,
      timeout: timeout,
    );
  }

  // ---------------------------------------------------------------------------
  // Legal check
  // ---------------------------------------------------------------------------

  /// Purchases a legal check for the given VIN.
  static Future<Map<String, dynamic>> purchaseLegalCheck({
    required String vin,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.PurchaseLegalCheck',
      params: {'vin': vin.trim()},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Returns legal information for the given VIN.
  static Future<Map<String, dynamic>> getLegalInfo({
    required String vin,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetLegalInfo',
      params: {'vin': vin.trim()},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  // ---------------------------------------------------------------------------
  // Balance & payments
  // ---------------------------------------------------------------------------

  /// Returns the current user balance.
  static Future<Map<String, dynamic>> getBalance({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetBalance',
      params: const {},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Returns a list of user transactions.
  static Future<List<Map<String, dynamic>>> getTransactions({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetTransactions',
      params: const {},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result.whereType<Map>().map((e) => _asMap(e)).toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list =
          map['items'] ?? map['transactions'] ?? map['data'] ?? map['list'];
      if (list is List) {
        return list.whereType<Map>().map((e) => _asMap(e)).toList();
      }
    }
    return [];
  }

  /// Creates a payment for the given amount and returns payment info (URL, etc).
  static Future<Map<String, dynamic>> createPayment({
    required int amount,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CreatePayment',
      params: {'amount': amount},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  // ---------------------------------------------------------------------------
  // Company specialists
  // ---------------------------------------------------------------------------

  /// Returns a list of company specialists.
  static Future<List<Map<String, dynamic>>> getCompanySpecialists({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetCompanySpecialists',
      params: const {},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result.whereType<Map>().map((e) => _asMap(e)).toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list =
          map['items'] ?? map['specialists'] ?? map['data'] ?? map['list'];
      if (list is List) {
        return list.whereType<Map>().map((e) => _asMap(e)).toList();
      }
    }
    return [];
  }

  /// Updates a company specialist record.
  static Future<Map<String, dynamic>> updateCompanySpecialist({
    required String specialistId,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final resp = await _postRpc(
      method: 'Storage.UpdateCompanySpecialist',
      params: {'specialistId': specialistId, ...data},
      timeout: timeout,
    );
    return _asMap(resp['result']);
  }

  /// Creates an invite link for staff members.
  static Future<String> createStaffInviteLink({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CreateStaffInviteLink',
      params: const {},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    return _extractString(result, ['url', 'link', 'inviteUrl', 'inviteLink']);
  }

  // ---------------------------------------------------------------------------
  // Assignments
  // ---------------------------------------------------------------------------

  /// Creates a new assignment.
  static Future<Map<String, dynamic>> createAssignment({
    required Map<String, dynamic> assignment,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CreateAssignment',
      params: assignment,
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Returns a list of assignments.
  static Future<List<Map<String, dynamic>>> getAssignments({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetAssignments',
      params: const {},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result.whereType<Map>().map((e) => _asMap(e)).toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list =
          map['items'] ?? map['assignments'] ?? map['data'] ?? map['list'];
      if (list is List) {
        return list.whereType<Map>().map((e) => _asMap(e)).toList();
      }
    }
    return [];
  }

  /// Updates an existing assignment.
  static Future<Map<String, dynamic>> updateAssignment({
    required String assignmentId,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final resp = await _postRpc(
      method: 'Storage.UpdateAssignment',
      params: {'assignmentId': assignmentId, ...data},
      timeout: timeout,
    );
    return _asMap(resp['result']);
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// Returns the current user profile.
  static Future<Map<String, dynamic>> getProfile({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetProfile',
      params: const {},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Updates the current user profile.
  static Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> profile,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.UpdateProfile',
      params: profile,
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  // ---------------------------------------------------------------------------
  // Promo
  // ---------------------------------------------------------------------------

  /// Retrieves promo information, optionally by code.
  static Future<Map<String, dynamic>> getPromo({
    String? code,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final params = <String, dynamic>{};
    if (code != null && code.trim().isNotEmpty) {
      params['code'] = code.trim();
    }
    final data = await _postRpc(
      method: 'Storage.GetPromo',
      params: params,
      timeout: timeout,
    );
    return _asMap(data['result']);
  }
}

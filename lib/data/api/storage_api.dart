import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/core/config/app_endpoints.dart';
import 'package:flutter_application_1/data/api/pinned_http_client.dart';
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
  final String? notificationToken;

  const _TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.notificationToken,
  });
}

class _MapPage {
  const _MapPage({
    required this.items,
    required this.page,
    required this.limit,
    this.total,
    this.pages,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int limit;
  final int? total;
  final int? pages;

  bool get shouldFetchNext {
    final pagesValue = pages;
    if (pagesValue != null && pagesValue > 0) return page < pagesValue;
    final totalValue = total;
    if (totalValue != null && totalValue >= 0) return page * limit < totalValue;
    return items.length >= limit;
  }
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

/// Thrown when an authenticated RPC is rejected because the user lacks the
/// required backend permission — either HTTP 403 or an RPC-level error whose
/// text signals "forbidden" / "нет прав". Carries the method + server message
/// so the UI can show a clean «недостаточно прав» instead of a raw dump, and
/// so callsites can `catch (PermissionDeniedException)` distinctly from
/// network/transport errors.
class PermissionDeniedException implements Exception {
  PermissionDeniedException(this.method, [this.serverMessage = '']);
  final String method;
  final String serverMessage;
  @override
  String toString() => serverMessage.isEmpty
      ? 'Недостаточно прав для $method'
      : 'Недостаточно прав для $method: $serverMessage';
}

/// True while a legal-review batch still has at least one check in a
/// non-terminal state (or the list is empty — nothing settled yet). Drives
/// the [StorageApi.getBatchLegalReviewResults] polling loop's stop condition.
/// Terminal = anything that isn't pending/processing/in_progress/running.
bool legalReviewBatchPending(List<Map<String, dynamic>> checks) {
  if (checks.isEmpty) return true;
  return checks.any((c) {
    final s = (c['status'] ?? '').toString().toLowerCase();
    return s.isEmpty ||
        s == 'pending' ||
        s == 'processing' ||
        s == 'in_progress' ||
        s == 'running';
  });
}

/// Extracts ApiCloud batch numbers from a report's `legalReviewStep` as
/// returned by `ViewSpecialistReport`. Live-confirmed 2026-06-01 that the
/// backend stores attached batches under **`legalReviewStep.batches`**
/// (shape `{id, files, batches}`); the older/doc-implied `batchIds` key is
/// tolerated as a fallback. Each element is either a bare batch-number string
/// (`"LEG-A416822"`) or an object carrying it under `batchNumber`/`number`/
/// `batch`/`id`. Returns de-duplicated, non-empty batch numbers in order.
List<String> legalReviewBatchNumbers(Map<String, dynamic> legalStep) {
  final raw = legalStep['batches'] ?? legalStep['batchIds'];
  if (raw is! List) return const <String>[];
  final out = <String>[];
  for (final el in raw) {
    var number = '';
    if (el is String) {
      number = el.trim();
    } else if (el is Map) {
      for (final key in const ['batchNumber', 'number', 'batch', 'id']) {
        final value = el[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          number = value.toString().trim();
          break;
        }
      }
    }
    if (number.isNotEmpty && !out.contains(number)) out.add(number);
  }
  return out;
}

/// Parsed result of the ApiCloud VIN↔plate converter
/// (`api_cloud_converter_search`). `found=false` means the vehicle isn't in
/// ApiCloud's DB (or the payload was empty/unparseable). `timedOut=true` means
/// the check didn't settle within the poll window (the ApiCloud worker can lag
/// hours — results aren't lost server-side); callers should show «попробуйте
/// позже», not «не найдено». In both cases callers must not overwrite fields.
typedef VinPlateConverterResult = ({
  bool found,
  String vin,
  String gosNumber,
  String brand,
  String model,
  int? year,
  bool timedOut,
});

const VinPlateConverterResult _emptyVinPlateResult = (
  found: false,
  vin: '',
  gosNumber: '',
  brand: '',
  model: '',
  year: null,
  timedOut: false,
);

const VinPlateConverterResult _timedOutVinPlateResult = (
  found: false,
  vin: '',
  gosNumber: '',
  brand: '',
  model: '',
  year: null,
  timedOut: true,
);

/// Parses a converter check's `responseNormalized` (a JSON STRING like
/// `{"vin":"…","gos_number":"…","brand":"LADA","model":"VESTA","year":2017,
/// "found":true}`, occasionally already a Map) into [VinPlateConverterResult].
VinPlateConverterResult parseVinPlateConverterResult(dynamic responseNormalized) {
  dynamic m = responseNormalized;
  if (m is String) {
    final s = m.trim();
    if (s.isEmpty) return _emptyVinPlateResult;
    try {
      m = json.decode(s);
    } catch (_) {
      return _emptyVinPlateResult;
    }
  }
  if (m is! Map) return _emptyVinPlateResult;
  String str(String k) => (m[k] ?? '').toString().trim();
  final yearRaw = m['year'];
  final year = yearRaw is int ? yearRaw : int.tryParse('${yearRaw ?? ''}');
  return (
    found: m['found'] == true,
    vin: str('vin'),
    gosNumber: str('gos_number'),
    brand: str('brand'),
    model: str('model'),
    year: year,
    timedOut: false,
  );
}

class StorageApi {
  static const String _endpoint = AppEndpoints.appRpc;
  static String get _authVerifyPlatform => kIsWeb ? 'web' : 'mobile';

  // Singleton Dio used only for binary uploads to presigned URLs. Other
  // RPC calls go through `package:http` as before — Dio buys us native
  // upload-progress callbacks (`onSendProgress`) that `http.put` can't
  // expose. Reusing one instance keeps the underlying connection pool
  // warm across concurrent part uploads.
  static final dio.Dio _uploadDio = dio.Dio(
    // connectTimeout bounds a stalled TCP connect / CORS-preflight: without it
    // a dead presigned-URL connection is bounded only by sendTimeout (60s+) ×
    // retries and looks frozen for minutes before erroring.
    dio.BaseOptions(connectTimeout: const Duration(seconds: 30)),
  );

  // Pinned HTTP client: in release it enforces certificate public-key
  // pinning (MITM defence); in debug it is a plain client so developers can
  // use Charles / mitmproxy. One instance shared by every RPC call.
  static final http.Client _httpClient = makePinnedHttpClient();
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
      response = await _httpClient
          .post(Uri.parse(_endpoint), headers: headers, body: bytes)
          .timeout(timeout);
    } on TimeoutException catch (e) {
      // DIAG: surface the real transport state at timeout — a bare
      // TimeoutException hides whether the TLS handshake, the request send,
      // or the response read stalled. iOS-only hangs land here.
      developer.log(
        'RPC TIMEOUT method=$method after ${stopwatch.elapsedMilliseconds}ms '
        'endpoint=$_endpoint client=${_httpClient.runtimeType}',
        name: 'StorageApi.diag',
        level: 900,
        error: e,
      );
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
    } catch (e, st) {
      // DIAG: log the full stack for any non-timeout transport failure
      // (SocketException, HandshakeException, ClientException) — critical for
      // diagnosing the iOS-only Auth hang.
      developer.log(
        'RPC TRANSPORT ERROR method=$method '
        'type=${e.runtimeType} msg=$e',
        name: 'StorageApi.diag',
        level: 900,
        error: e,
        stackTrace: st,
      );
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
      if (response.statusCode == 403) {
        throw PermissionDeniedException(method, shortBody);
      }
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
        extra:
            'body=${rawBody.length > 200 ? '${rawBody.substring(0, 200)}…' : rawBody}',
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
      if (_isForbiddenResponse(data, responseFlag)) {
        throw PermissionDeniedException(method, errors);
      }
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

  /// True when an RPC-level error (HTTP 200, `response != 'ok'`) signals a
  /// permission/forbidden denial rather than an expired session. Used to
  /// surface [PermissionDeniedException] for graceful RBAC handling.
  static bool _isForbiddenResponse(
    Map<String, dynamic> data,
    String responseFlag,
  ) {
    if (responseFlag.contains('forbidden') || responseFlag.contains('denied')) {
      return true;
    }
    final errorsText = _extractErrorsText(data).toLowerCase();
    if (errorsText.isEmpty) return false;
    // Узкие маркеры: 'доступ' матчил бы «недоступен» (сервис недоступен), а
    // голый '403' — любой ID с этими цифрами. Берём только однозначное.
    return errorsText.contains('forbidden') ||
        errorsText.contains('permission') ||
        errorsText.contains('access denied') ||
        errorsText.contains('нет доступа') ||
        errorsText.contains('недостаточно прав');
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

  /// Public entry point to the access-token refresh chain. Other clients
  /// (e.g. [AiQueueApi]) call this to reuse the same single-flight refresh
  /// path instead of duplicating it. Returns `true` when the cached
  /// tokens were updated.
  static Future<bool> tryRefreshTokens() => _tryRefreshTokens();

  /// Single-flight protection: при одновременных вызовах (pre-send JWT
  /// skew check + 401-retry + manual из других модулей) все caller'ы
  /// получают one shared future вместо отдельных network requests.
  /// Без этого backend получал несколько RefreshToken'ов параллельно,
  /// и последующий мог invalidate refresh-токен предыдущего (зависит
  /// от backend logic; safer избегать гонок).
  static Future<bool>? _inFlightRefresh;

  static Future<bool> _tryRefreshTokens() {
    final pending = _inFlightRefresh;
    if (pending != null) return pending;
    final future = _doRefreshTokens().whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = future;
    return future;
  }

  static Future<bool> _doRefreshTokens() async {
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
      // Replace the notification token too when the refresh returns one —
      // otherwise the realtime WS keeps using the stale (expired) token and
      // never recovers after the 72h TTL (B18).
      final notifToken = tokens.notificationToken;
      if (notifToken != null && notifToken.isNotEmpty) {
        await UserSimplePreferences.setNotificationToken(notifToken);
      }
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
    const notificationKeys = [
      'notificationToken',
      'notification_token',
      'notifyToken',
      'wsToken',
    ];
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
    // RefreshToken returns a fresh notification token too — capture it so
    // the realtime WS can reconnect after its token expires (B18).
    var notificationToken = _extractString(result, notificationKeys);
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
    if (notificationToken.isEmpty) {
      notificationToken = _extractString(data, notificationKeys);
    }
    if (accessToken.isEmpty || refreshToken.isEmpty) return null;
    return _TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      notificationToken: notificationToken.isEmpty ? null : notificationToken,
    );
  }

  static Future<AuthStartResult> auth({
    required String phone,
    // 30s — backend auth-pipeline (call-provider lookup) иногда
    // отвечает на грани 12-15s. Старый timeout стрелял раньше чем
    // сервер успевал вернуть номер для звонка → пользователь видел
    // «Не удалось начать авторизацию» когда фактически всё было ок.
    Duration timeout = const Duration(seconds: 30),
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
    final notificationToken = _extractString(result, [
      'notificationToken',
      'notification_token',
    ]);
    return AuthStartResult(
      callPhone: callPhone,
      sessionId: sessionId.isEmpty ? null : sessionId,
      notificationToken: notificationToken.isEmpty ? null : notificationToken,
    );
  }

  static Future<AuthVerifyResult> authVerify({
    required String phone,
    String? sessionId,
    String? platform,
    // Same reason as `auth` above — backend verify под нагрузкой
    // подтягивает входящий звонок и иногда уходит за 12s. 30 с
    // даёт запас, но всё ещё не висит у юзера бесконечно.
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final resolvedPlatform = platform ?? _authVerifyPlatform;
    final params = <String, dynamic>{
      'phone': phone,
      'platform': resolvedPlatform,
    };
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
    final notificationToken = _extractString(result, [
      'notificationToken',
      'notification_token',
    ]);
    return AuthVerifyResult(
      accessToken: accessToken.isEmpty ? null : accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      notificationToken: notificationToken.isEmpty ? null : notificationToken,
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
    // Optional: ID специалиста, на которого назначается заявка. Только
    // для company-роли — backend валидирует что user в роли SPECIALIST
    // и состоит в той же компании. При успешном назначении специалисту
    // шлётся system-оповещение `request_assigned`.
    int? assignedSpecialistId,
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
      if (assignedSpecialistId != null && assignedSpecialistId > 0)
        'assignedSpecialistId': assignedSpecialistId,
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
    int? requestId,
    // Heavy endpoint: saves the full draft + generates presigned S3 URLs for
    // every inspection file. Large reports with 20+ media items routinely
    // need 60–150 s server-side; bumped from 90 s after timeouts surfaced
    // on the device. Server is idempotent per reportNumber, so a fresh
    // call with the same payload is safe if the caller decides to retry.
    Duration timeout = const Duration(seconds: 180),
  }) async {
    final data = await _postRpc(
      method: 'Storage.PrepareSpecialistReport',
      params: {
        'report': report,
        if (requestId != null && requestId > 0) 'requestId': requestId,
      },
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
    // and flips `isDraft = false`. 120 s accommodates large report bundles
    // on slow networks; 20 s timed out in the field.
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
      throw Exception('Storage.CompleteSpecialistReport вернул success=false');
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
      normalized['mileageMismatch'] =
          carStep['visuallyMileageNotMatchCondition'];
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
    // carStep also carries a generated listing snapshot stored in S3 by key
    // (the «listing file / listing pdf»). We surface the key here; the
    // completed-report hydrator resolves it to a presigned view URL (B14).
    final listingPdfKey = _extractString(carStep, [
      'listingPdf',
      'listing_pdf',
      'listingFile',
      'listing_file',
      'listingPdfFile',
      'listingFileKey',
      'listingPdfKey',
      'pdfListing',
    ]);
    if (listingPdfKey.isNotEmpty) normalized['listingPdfFile'] = listingPdfKey;

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

  static _MapPage _extractReportPage(
    dynamic rawResult, {
    required int page,
    required int limit,
  }) {
    if (rawResult is List) {
      return _MapPage(
        items: rawResult.whereType<Map>().map((e) {
          return _normalizeSpecialistReportMap(_asMap(e));
        }).toList(),
        page: page,
        limit: limit,
      );
    }

    final resultMap = _asMap(rawResult);
    if (resultMap.isEmpty) {
      return _MapPage(items: const [], page: page, limit: limit);
    }
    final list =
        resultMap['items'] ??
        resultMap['reports'] ??
        resultMap['data'] ??
        resultMap['list'];
    if (list is List) {
      final pagination = _asMap(resultMap['pagination']);
      return _MapPage(
        items: list.whereType<Map>().map((e) {
          return _normalizeSpecialistReportMap(_asMap(e));
        }).toList(),
        page: _asInt(pagination['page']) ?? _asInt(resultMap['page']) ?? page,
        limit:
            _asInt(pagination['limit']) ?? _asInt(resultMap['limit']) ?? limit,
        total: _asInt(pagination['total']) ?? _asInt(resultMap['total']),
        pages:
            _asInt(pagination['pages']) ??
            _asInt(resultMap['pages']) ??
            _asInt(resultMap['totalPages']),
      );
    }

    final one = _normalizeSpecialistReportMap(resultMap);
    if (one.isNotEmpty &&
        (_extractString(one, ['id']).isNotEmpty ||
            _extractString(one, ['reportNumber']).isNotEmpty)) {
      return _MapPage(
        items: <Map<String, dynamic>>[one],
        page: page,
        limit: limit,
      );
    }
    return _MapPage(items: const [], page: page, limit: limit);
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
    return _extractReportPage(data['result'], page: page, limit: limit).items;
  }

  static Future<List<Map<String, dynamic>>> getAllSpecialistReports({
    int limit = 100,
    bool isDraft = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final safeLimit = limit <= 0 ? 100 : limit;
    final reports = <Map<String, dynamic>>[];
    const maxPages = 100;
    var page = 1;
    while (page <= maxPages) {
      final data = await _postRpc(
        method: 'Storage.GetSpecialistReport',
        params: {'page': page, 'limit': safeLimit, 'isDraft': isDraft},
        timeout: timeout,
      );
      final parsed = _extractReportPage(
        data['result'],
        page: page,
        limit: safeLimit,
      );
      reports.addAll(parsed.items);
      if (!parsed.shouldFetchNext) break;
      page += 1;
    }
    return reports;
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
    final createdAt = _extractString(local, [
      'createdAt',
      'date',
      'reportDate',
    ]);

    final remoteReports = await getAllSpecialistReports(
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
        final remoteName = _extractString(remote, [
          'reportName',
          'name',
          'title',
        ]);
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

  /// Returns a presigned PUT URL for a direct single-request upload to S3.
  /// `reportNumber: 'temp'` puts the object under `temp/` where the bucket
  /// lifecycle rule deletes it after 1 day — use for ephemeral files like
  /// document photos sent to AI recognition. Unlike [getTemporaryViewUrl]
  /// this THROWS on failure: callers must handle "can't upload" explicitly
  /// instead of silently continuing without the file.
  static Future<({String url, String key})> getTemporaryUploadUrl({
    required String reportNumber,
    required String filename,
    int? expiresInSeconds,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.GetTemporaryUploadUrl',
      params: {
        'reportNumber': reportNumber,
        'filename': filename,
        if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds,
      },
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final url = _extractString(result, ['url', 'signedUrl']);
    if (url.isEmpty) {
      throw Exception('Бэкенд не вернул URL загрузки файла');
    }
    return (url: url, key: _extractString(result, ['key']));
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

  /// Streams a presigned PUT through Dio so we can surface real
  /// upload progress to the UI via [onProgress]. The `package:http`
  /// equivalent only fires once the entire body is buffered, which
  /// makes small files appear frozen at 0% then jump to 100%.
  ///
  /// Behavioural parity with the previous implementation:
  /// - Throws on empty URL / empty bytes / non-2xx status.
  /// - Returns the trimmed `ETag` header (case-insensitive).
  /// - Honours [timeout] for both send + receive.
  static Future<String> uploadBytesToPresignedUrl({
    required String url,
    required List<int> bytes,
    String? contentType,
    Duration timeout = const Duration(seconds: 60),
    void Function(int sent, int total)? onProgress,
  }) async {
    if (url.trim().isEmpty) {
      throw Exception('Presigned URL is empty');
    }
    if (bytes.isEmpty) {
      throw Exception('Upload bytes are empty');
    }
    final length = bytes.length;
    final headers = <String, dynamic>{
      'Content-Length': length,
      if (contentType != null && contentType.trim().isNotEmpty)
        'Content-Type': contentType.trim(),
    };
    final dio.Response<dynamic> response;
    try {
      response = await _uploadDio.put<dynamic>(
        url,
        // `Stream.fromIterable` yields the buffer in one chunk to
        // Dio, which then segments it for the socket. Dio invokes
        // onSendProgress as bytes leave its buffer.
        data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        options: dio.Options(
          headers: headers,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          // Treat any non-2xx as throwable so we keep the same error
          // semantics as the old http.put-based flow.
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
          // Don't try to JSON-decode the response body — S3 returns
          // an XML body or empty body; we only care about ETag.
          responseType: dio.ResponseType.bytes,
        ),
        onSendProgress: onProgress,
      );
    } on dio.DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null) {
        throw Exception('Upload failed: HTTP $status');
      }
      // На web null-status транспортная ошибка против s3.regru.cloud почти
      // всегда = отсутствие CORS на бакете (нет Access-Control-Allow-Origin),
      // браузер режет запрос до ответа. Даём понятное сообщение вместо «Upload
      // transport error».
      if (kIsWeb) {
        throw Exception(
          'Браузер заблокировал загрузку в хранилище (CORS). '
          'Завершите отчёт в приложении на телефоне.',
        );
      }
      throw Exception(e.message ?? 'Upload transport error');
    }
    final etag =
        response.headers.value('etag') ?? response.headers.value('ETag') ?? '';
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
    return _parseListPartsResult(data);
  }

  /// Парсит ответ ListParts (общего и профильного) в типизированный
  /// результат: ключ объекта + отсортированный список частей с ETag.
  static MultipartListPartsResult _parseListPartsResult(
    Map<String, dynamic> data,
  ) {
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
    return MultipartListPartsResult(key: key, parts: parts);
  }

  // ---------------------------------------------------------------------------
  // ObjectStorage.Profile — profile-specific multipart upload
  // ---------------------------------------------------------------------------

  static Future<ProfileMultipartSession> initiateProfileMultipartUpload({
    required String filename,
    required int contentLength,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.Profile.InitiateProfileMultipartUpload',
      params: {'filename': filename, 'contentLength': contentLength},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final uploadId = _extractString(result, ['uploadId', 'uploadID', 'id']);
    final fn = _extractString(result, ['filename', 'fileName']);
    final key = _extractString(result, ['key', 'path', 'objectKey']);
    final publicUrl = _extractString(result, ['publicUrl', 'url']);
    if (uploadId.isEmpty) {
      throw Exception('Profile multipart uploadId is empty');
    }
    return ProfileMultipartSession(
      uploadId: uploadId,
      filename: fn.isNotEmpty ? fn : filename,
      key: key,
      publicUrl: publicUrl,
    );
  }

  static Future<MultipartUploadUrlsResult> getProfilePartUploadUrls({
    required String filename,
    required String uploadId,
    required int partCount,
    int? expiresInSeconds,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final params = <String, dynamic>{
      'filename': filename,
      'uploadId': uploadId,
      'partCount': partCount,
      if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds,
    };
    final data = await _postRpc(
      method: 'ObjectStorage.Profile.GetProfilePartUploadUrls',
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

  static Future<ProfileMultipartCompleteResult> completeProfileMultipartUpload({
    required String filename,
    required String uploadId,
    required List<MultipartUploadedPart> parts,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.Profile.CompleteProfileMultipartUpload',
      params: {
        'filename': filename,
        'uploadId': uploadId,
        'parts': parts.map((e) => e.toJson()).toList(),
      },
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final key = _extractString(result, ['key', 'path', 'objectKey']);
    final publicUrl = _extractString(result, ['publicUrl', 'url']);
    final contentSize = _asInt(result['contentSize']) ?? 0;
    final errorRaw = result['error']?.toString();
    final error = (errorRaw != null && errorRaw.isNotEmpty) ? errorRaw : null;
    return ProfileMultipartCompleteResult(
      key: key,
      publicUrl: publicUrl,
      contentSize: contentSize,
      error: error,
      maxSize: _asInt(result['maxSize']),
      actual: _asInt(result['actual']),
    );
  }

  static Future<void> abortProfileMultipartUpload({
    required String filename,
    required String uploadId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    await _postRpc(
      method: 'ObjectStorage.Profile.AbortProfileMultipartUpload',
      params: {'filename': filename, 'uploadId': uploadId},
      timeout: timeout,
    );
  }

  /// CORS-фолбэк для web: возвращает ETag'и загруженных частей профильного
  /// multipart upload. Ключ строится сервером из JWT
  /// (`app/user/{userId}/profile/{filename}`) — `reportNumber` не нужен.
  static Future<MultipartListPartsResult> listProfileParts({
    required String filename,
    required String uploadId,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final data = await _postRpc(
      method: 'ObjectStorage.Profile.ListParts',
      params: {'filename': filename, 'uploadId': uploadId},
      timeout: timeout,
    );
    return _parseListPartsResult(data);
  }

  static Future<Map<String, dynamic>> deleteProfileAvatar({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.DeleteProfileAvatar',
      params: const <String, dynamic>{},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Полный multipart-флоу загрузки аватара в персональную папку профиля:
  /// initiate → presigned PUT → complete (+ abort на любой ошибке).
  /// Возвращает публичный URL, который вызывающая сторона записывает
  /// в `urlAvatar` через [updateProfile]. Бросает [ProfileAvatarUploadException].
  static Future<String> uploadProfileAvatar({
    required List<int> bytes,
    required String originalFilename,
  }) async {
    final filename = sanitizeAvatarFilename(originalFilename);
    final session = await initiateProfileMultipartUpload(
      filename: filename,
      contentLength: bytes.length,
    );
    try {
      final urlsResult = await getProfilePartUploadUrls(
        filename: session.filename,
        uploadId: session.uploadId,
        partCount: 1,
      );
      if (urlsResult.urls.isEmpty) {
        throw const ProfileAvatarUploadException(
          code: 'no_url',
          message: 'Сервер не вернул URL для загрузки',
        );
      }
      var etag = await uploadBytesToPresignedUrl(
        url: urlsResult.urls.first.url,
        bytes: bytes,
        contentType: _avatarContentType(filename),
      );
      // На web браузер не отдаёт ETag из ответа S3 (CORS exposedHeaders
      // не включает ETag). Фолбэк: добираем ETag серверно через
      // ObjectStorage.Profile.ListParts.
      if (etag.isEmpty) {
        etag = await _resolveProfilePartEtag(
          filename: session.filename,
          uploadId: session.uploadId,
        );
      }
      if (etag.isEmpty) {
        throw const ProfileAvatarUploadException(
          code: 'no_etag',
          message: 'Не удалось получить ETag загруженной части',
        );
      }
      final complete = await completeProfileMultipartUpload(
        filename: session.filename,
        uploadId: session.uploadId,
        parts: [MultipartUploadedPart(partNumber: 1, etag: etag)],
      );
      if (complete.hasError) {
        throw ProfileAvatarUploadException(
          code: complete.error!,
          message: _avatarErrorMessage(complete),
          maxSize: complete.maxSize,
          actualSize: complete.actual,
        );
      }
      if (complete.publicUrl.isEmpty) {
        throw const ProfileAvatarUploadException(
          code: 'empty_url',
          message: 'Сервер не вернул публичный URL аватарки',
        );
      }
      return complete.publicUrl;
    } catch (e) {
      unawaited(
        abortProfileMultipartUpload(
          filename: session.filename,
          uploadId: session.uploadId,
        ).catchError((_) {}),
      );
      if (e is ProfileAvatarUploadException) rethrow;
      throw ProfileAvatarUploadException(
        code: 'transport',
        message: 'Не удалось загрузить фото: $e',
      );
    }
  }

  /// Нормализует имя файла для S3-ключа аватара: имя всегда `avatar.<ext>`,
  /// расширение проходит whitelist (latin/цифры до 10 символов), иначе jpg.
  /// Whitelisting — защита от path-traversal и неожиданных MIME-типов.
  static String sanitizeAvatarFilename(String original) {
    final dotIndex = original.lastIndexOf('.');
    final ext = dotIndex >= 0 && dotIndex < original.length - 1
        ? original.substring(dotIndex + 1).toLowerCase()
        : 'jpg';
    final safeExt = RegExp(r'^[a-z0-9]{1,10}$').hasMatch(ext) ? ext : 'jpg';
    return 'avatar.$safeExt';
  }

  /// CORS-фолбэк для web: достаёт ETag части серверно через
  /// `ObjectStorage.Profile.ListParts`. Возвращает пустую строку если
  /// part не нашёлся или запрос упал.
  static Future<String> _resolveProfilePartEtag({
    required String filename,
    required String uploadId,
  }) async {
    try {
      final listed = await listProfileParts(
        filename: filename,
        uploadId: uploadId,
      );
      for (final part in listed.parts) {
        if (part.partNumber == 1 && part.etag.trim().isNotEmpty) {
          return part.etag.trim();
        }
      }
    } catch (_) {
      // Сам сбой ListParts уже залогирован в _postRpc (rpc-error/timeout).
      // Здесь глотаем — вызывающий бросит no_etag и сделает abort.
    }
    return '';
  }

  static String _avatarContentType(String filename) {
    if (filename.endsWith('.png')) return 'image/png';
    if (filename.endsWith('.heic')) return 'image/heic';
    if (filename.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String _avatarErrorMessage(ProfileMultipartCompleteResult complete) {
    if (complete.error == 'file_too_large') {
      final maxMb = complete.maxSize != null
          ? (complete.maxSize! / 1024 / 1024).round()
          : null;
      return maxMb != null
          ? 'Файл слишком большой (максимум $maxMb МБ).'
          : 'Файл слишком большой.';
    }
    if (complete.error == 'checksum_mismatch') {
      return 'Контрольная сумма не совпала. Попробуйте ещё раз.';
    }
    return 'Ошибка при завершении загрузки: ${complete.error}';
  }

  static _MapPage _extractRequestsPage(
    dynamic rawResult, {
    required int page,
    required int limit,
  }) {
    if (rawResult is List) {
      return _MapPage(
        items: rawResult.whereType<Map>().map((e) => _asMap(e)).toList(),
        page: page,
        limit: limit,
      );
    }
    if (rawResult is Map) {
      final map = _asMap(rawResult);
      final list =
          map['items'] ?? map['requests'] ?? map['data'] ?? map['list'];
      if (list is List) {
        final pagination = _asMap(map['pagination']);
        return _MapPage(
          items: list.whereType<Map>().map((e) => _asMap(e)).toList(),
          page: _asInt(pagination['page']) ?? _asInt(map['page']) ?? page,
          limit: _asInt(pagination['limit']) ?? _asInt(map['limit']) ?? limit,
          total: _asInt(pagination['total']) ?? _asInt(map['total']),
          pages:
              _asInt(pagination['pages']) ??
              _asInt(map['pages']) ??
              _asInt(map['totalPages']),
        );
      }
    }
    return _MapPage(items: const [], page: page, limit: limit);
  }

  static Future<_MapPage> _getRequestsPage({
    int? page,
    int? limit,
    String? status,
    String? requestType,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final params = <String, dynamic>{};
    if (page != null && page > 0) params['page'] = page;
    if (limit != null && limit > 0) params['limit'] = limit;
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (requestType != null && requestType.trim().isNotEmpty) {
      params['requestType'] = requestType.trim();
    }
    final data = await _postRpc(
      method: 'Storage.GetRequest',
      params: params,
      timeout: timeout,
    );
    return _extractRequestsPage(
      data['result'],
      page: page ?? 1,
      limit: limit ?? 20,
    );
  }

  static Future<List<Map<String, dynamic>>> getRequests({
    int? page,
    int? limit,
    String? status,
    String? requestType,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    return (await _getRequestsPage(
      page: page,
      limit: limit,
      status: status,
      requestType: requestType,
      timeout: timeout,
    )).items;
  }

  static Future<List<Map<String, dynamic>>> getAllRequests({
    int limit = 100,
    String? status,
    String? requestType,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final safeLimit = limit <= 0 ? 100 : limit;
    final requests = <Map<String, dynamic>>[];
    const maxPages = 100;
    var page = 1;
    while (page <= maxPages) {
      final parsed = await _getRequestsPage(
        page: page,
        limit: safeLimit,
        status: status,
        requestType: requestType,
        timeout: timeout,
      );
      requests.addAll(parsed.items);
      if (!parsed.shouldFetchNext) break;
      page += 1;
    }
    return requests;
  }

  static Future<List<Map<String, dynamic>>> getRequestCars({
    required int requestId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final details = await getRequestCarDetails(
      requestId: requestId,
      timeout: timeout,
    );
    return details.cars;
  }

  static Future<RequestCarDetails> getRequestCarDetails({
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
      return RequestCarDetails(
        cars: result.whereType<Map>().map((e) => _asMap(e)).toList(),
        requestStatusHistories: const <Map<String, dynamic>>[],
      );
    }
    if (result is Map) {
      final map = _asMap(result);
      final list =
          map['items'] ??
          map['cars'] ??
          map['requestCars'] ??
          map['data'] ??
          map['list'];
      final rawHistory =
          map['requestStatusHistories'] ??
          map['request_status_histories'] ??
          map['statusHistories'] ??
          map['history'];
      final history = rawHistory is List
          ? rawHistory.whereType<Map>().map((e) => _asMap(e)).toList()
          : const <Map<String, dynamic>>[];
      if (list is List) {
        return RequestCarDetails(
          cars: list.whereType<Map>().map((e) => _asMap(e)).toList(),
          requestStatusHistories: history,
        );
      }
      return RequestCarDetails(
        cars: const <Map<String, dynamic>>[],
        requestStatusHistories: history,
      );
    }
    return const RequestCarDetails(
      cars: <Map<String, dynamic>>[],
      requestStatusHistories: <Map<String, dynamic>>[],
    );
  }

  static RequestActionResult _requestActionResultFromMap(
    Map<String, dynamic> result, {
    required int fallbackRequestId,
    String fallbackStatus = '',
  }) {
    final success = result['success'] is bool
        ? result['success'] as bool
        : true;
    final status = _extractString(result, ['status']);
    return RequestActionResult(
      requestId: _asInt(result['requestId']) ?? fallbackRequestId,
      requestNumber: _extractString(result, [
        'requestNumber',
        'request_number',
        'number',
      ]),
      status: status.isNotEmpty ? status : (success ? fallbackStatus : ''),
      success: success,
      error: _asNullableString(result['error']),
      reportId: _asInt(result['reportId']),
      reportNumber: _asNullableString(result['reportNumber']),
    );
  }

  static Future<RequestActionResult> acceptRequest({
    required int requestId,
    String? note,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.AcceptRequest',
      params: {
        'requestId': requestId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      timeout: timeout,
    );
    return _requestActionResultFromMap(
      _asMap(data['result']),
      fallbackRequestId: requestId,
      fallbackStatus: 'in_work',
    );
  }

  static Future<RequestActionResult> rejectRequest({
    required int requestId,
    String? note,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.RejectRequest',
      params: {
        'requestId': requestId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      timeout: timeout,
    );
    return _requestActionResultFromMap(
      _asMap(data['result']),
      fallbackRequestId: requestId,
      fallbackStatus: 'created',
    );
  }

  static Future<RequestActionResult> abandonRequest({
    required int requestId,
    required String note,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.AbandonRequest',
      params: {'requestId': requestId, 'note': note.trim()},
      timeout: timeout,
    );
    final parsed = _requestActionResultFromMap(
      _asMap(data['result']),
      fallbackRequestId: requestId,
      fallbackStatus: 'failed',
    );
    if (!parsed.success) {
      final message = parsed.error?.trim() ?? '';
      if (message.isNotEmpty) {
        throw Exception('Storage.AbandonRequest: $message');
      }
      throw Exception('Storage.AbandonRequest вернул success=false');
    }
    return parsed;
  }

  static Future<RequestActionResult> assignSpecialist({
    required int requestId,
    required int specialistId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.AssignSpecialist',
      params: {'requestId': requestId, 'specialistId': specialistId},
      timeout: timeout,
    );
    final parsed = _requestActionResultFromMap(
      _asMap(data['result']),
      fallbackRequestId: requestId,
      fallbackStatus: 'created',
    );
    if (!parsed.success) {
      final message = parsed.error?.trim() ?? '';
      if (message.isNotEmpty) {
        throw Exception('Storage.AssignSpecialist: $message');
      }
      throw Exception('Storage.AssignSpecialist вернул success=false');
    }
    return parsed;
  }

  static Future<RequestActionResult> cancelRequest({
    required int requestId,
    required String cancelReason,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CancelRequest',
      params: {'requestId': requestId, 'cancelReason': cancelReason},
      timeout: timeout,
    );
    final parsed = _requestActionResultFromMap(
      _asMap(data['result']),
      fallbackRequestId: requestId,
      fallbackStatus: 'canceled',
    );
    if (!parsed.success) {
      final message = parsed.error?.trim() ?? '';
      if (message.isNotEmpty) {
        throw Exception('Storage.CancelRequest: $message');
      }
      throw Exception('Storage.CancelRequest вернул success=false');
    }
    return parsed;
  }

  static Future<RequestActionResult> completeRequest({
    required int requestId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CompleteRequest',
      params: {'requestId': requestId},
      timeout: timeout,
    );
    final parsed = _requestActionResultFromMap(
      _asMap(data['result']),
      fallbackRequestId: requestId,
      fallbackStatus: 'done',
    );
    if (!parsed.success) {
      final message = parsed.error?.trim() ?? '';
      if (message.isNotEmpty) {
        throw Exception('Storage.CompleteRequest: $message');
      }
      throw Exception('Storage.CompleteRequest вернул success=false');
    }
    return parsed;
  }

  static SpecialistsPage _parseSpecialistsPage(
    dynamic rawResult, {
    required int page,
    required int limit,
  }) {
    final result = _asMap(rawResult);
    final rawSpecs = result['specialists'];
    final specs = <SpecialistItem>[];
    if (rawSpecs is List) {
      for (final raw in rawSpecs) {
        if (raw is! Map) continue;
        final m = _asMap(raw);
        final profile = _asMap(m['profile']);
        final user = _asMap(m['user']);
        String? field(List<String> keys) {
          for (final source in [m, profile, user]) {
            final value = _extractString(source, keys);
            if (value.isNotEmpty) return value;
          }
          return null;
        }

        final id =
            _asInt(m['id']) ??
            _asInt(m['userId']) ??
            _asInt(m['user_id']) ??
            _asInt(profile['id']) ??
            _asInt(user['id']);
        if (id == null) continue;
        // Rating sometimes arrives as int (0 / 1), sometimes double.
        final r = m['rating'];
        final ratingDouble = r is num ? r.toDouble() : 0.0;
        specs.add(
          SpecialistItem(
            id: id,
            fullName: field(['displayName', 'fullName', 'full_name', 'name']),
            firstName: field(['firstName', 'first_name']),
            lastName: field(['lastName', 'last_name', 'surname']),
            middleName: field(['middleName', 'middle_name', 'patronymic']),
            urlAvatar: field([
              'urlAvatar',
              'url_avatar',
              'avatarUrl',
              'avatar_url',
              'photoUrl',
              'photo_url',
              'profilePhoto',
              'profile_photo',
              // Bare variants — GetCompanySpecialists returns the avatar
              // under a plain key while names resolve fine, so the staff
              // list showed initials instead of the photo (B9).
              'avatar',
              'photo',
              'image',
              'picture',
              'imageUrl',
              'image_url',
              'pictureUrl',
              'picture_url',
            ]),
            description: field(['description', 'about']),
            likeUp: _asInt(m['likeUp']) ?? 0,
            likeDown: _asInt(m['likeDown']) ?? 0,
            rating: ratingDouble,
            city: field(['city', 'cityName', 'city_name']),
            email: field(['email', 'contactEmail', 'contact_email']),
            phone: field([
              'phone',
              'contactPhone',
              'contact_phone',
              'phoneNumber',
              'phone_number',
            ]),
          ),
        );
      }
    }
    final pag = _asMap(result['pagination']);
    return SpecialistsPage(
      specialists: specs,
      page: _asInt(pag['page']) ?? page,
      limit: _asInt(pag['limit']) ?? limit,
      total: _asInt(pag['total']) ?? specs.length,
      pages: _asInt(pag['pages']) ?? 1,
    );
  }

  /// `Storage.GetSpecialists` — пагинированный список специалистов с
  /// фильтрами. Доступен только роли `company`.
  ///
  /// По актуальному `Doc` это общий поиск по всем специалистам.
  /// Для штатных специалистов компании используйте
  /// [getCompanySpecialistsPage]. Email/phone приходят только когда
  /// search exact-matched.
  static Future<SpecialistsPage> getSpecialists({
    int page = 1,
    int limit = 20,
    String? search,
    List<String>? cities,
    double? minRating,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetSpecialists',
      params: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (cities != null && cities.isNotEmpty) 'cities': cities,
        if (minRating != null) 'minRating': minRating,
      },
      timeout: timeout,
    );
    return _parseSpecialistsPage(data['result'], page: page, limit: limit);
  }

  static Future<SpecialistsPage> getCompanySpecialistsPage({
    int page = 1,
    int limit = 20,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetCompanySpecialists',
      params: {'page': page, 'limit': limit},
      timeout: timeout,
    );
    return _parseSpecialistsPage(data['result'], page: page, limit: limit);
  }

  static CompanySpecialistUnlinkResult _companySpecialistUnlinkResultFromMap(
    Map<String, dynamic> result, {
    required int fallbackSpecialistId,
  }) {
    return CompanySpecialistUnlinkResult(
      success: result['success'] is bool ? result['success'] as bool : true,
      specialistId: _asInt(result['specialistId']) ?? fallbackSpecialistId,
      companyId: _asInt(result['companyId']),
      changed: result['changed'] == true,
      activeAssignedRequests: _asInt(result['activeAssignedRequests']),
      error: _asNullableString(result['error']),
    );
  }

  static Future<CompanySpecialistUnlinkResult> unlinkCompanySpecialist({
    required int specialistId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.UnlinkCompanySpecialist',
      params: {'specialistId': specialistId},
      timeout: timeout,
    );
    final parsed = _companySpecialistUnlinkResultFromMap(
      _asMap(data['result']),
      fallbackSpecialistId: specialistId,
    );
    if (!parsed.success) {
      throw CompanySpecialistUnlinkException(
        code: parsed.error ?? '',
        activeAssignedRequests: parsed.activeAssignedRequests,
      );
    }
    return parsed;
  }

  static String? _asNullableString(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
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

  // ---------------------------------------------------------------------------
  // Legal review (ApiCloud) — «Материалы проверки»
  // ---------------------------------------------------------------------------

  /// Available ApiCloud check types for [runBatchLegalReview].
  /// Backend `result.checkTypes` = `[{value, name}]`; `value` is the string
  /// passed back in `checkTypes`, `name` is the human-readable enum name.
  static Future<List<({String value, String name})>>
  getAvailableLegalReviewCheckTypes({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetAvailableLegalReviewCheckTypes',
      params: const {},
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final raw = result['checkTypes'];
    final out = <({String value, String name})>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final m = _asMap(item);
        final value = (m['value'] ?? '').toString().trim();
        if (value.isEmpty) continue;
        final name = (m['name'] ?? value).toString().trim();
        out.add((value: value, name: name));
      }
    }
    return out;
  }

  /// Starts a batch of ApiCloud legal-review checks. **PAID**; requires the
  /// `run_legal_review` permission. Returns `{batchNumber, checks:[…]}`.
  ///
  /// Param usage by check type (see Doc): zalog checks use vin/chassis/
  /// bodyNumber; gost/taxi/converter use searchString → vin → gosNumber;
  /// fgis_taxi uses gosNumber. The batch is attached to a report later via
  /// PrepareSpecialistReport `legalReviewStep.batches` (no stepId here).
  static Future<Map<String, dynamic>> runBatchLegalReview({
    required List<String> checkTypes,
    String? vin,
    String? gosNumber,
    String? chassis,
    String? bodyNumber,
    String? searchString,
    Map<String, dynamic>? extra,
    // Старт batch обычно ~1–2с, но при перегрузке бэка create может зависать
    // (live 2026-06-03: RunBatchLegalReview таймаутил на 30с). Даём 60с, чтобы
    // медленный старт успел вернуть batchNumber — исполнение проверок дальше
    // отслеживается отдельным поллингом с большим потолком.
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // ВАЖНО: бэкенд ожидает ПОЛНУЮ структуру params, включая `extra` (хотя бы
    // `{}`). Если слать частично (без `extra`/опущенными ключами) — обработчик
    // на бэке падает с HTTP 502 (проверено live). Поэтому всегда отдаём все
    // ключи: vin/gosNumber как строки (возможно пустые), chassis/bodyNumber/
    // searchString как null при отсутствии, extra как объект.
    String? clean(String? v) {
      final t = v?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final params = <String, dynamic>{
      'checkTypes': checkTypes,
      'vin': vin?.trim() ?? '',
      'gosNumber': gosNumber?.trim() ?? '',
      'chassis': clean(chassis),
      'bodyNumber': clean(bodyNumber),
      'searchString': clean(searchString),
      'extra': extra ?? const <String, dynamic>{},
    };
    final data = await _postRpc(
      method: 'Storage.RunBatchLegalReview',
      params: params,
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Returns all checks of a [batchNumber] with normalized API results
  /// (`responseNormalized`) + batch `summary`. Used to poll progress and read
  /// final results.
  static Future<Map<String, dynamic>> getBatchLegalReviewResults({
    required String batchNumber,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetBatchLegalReviewResults',
      params: <String, dynamic>{'batchNumber': batchNumber},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Paginated list of LegalReviewCheck records, filterable (e.g. by
  /// [legalReviewStepId]) — used to render a saved report's check materials.
  static Future<Map<String, dynamic>> getLegalReviewChecks({
    int? page,
    int? limit,
    String? vehicleVin,
    String? vehicleGosNumber,
    String? batchNumber,
    String? checkType,
    String? status,
    int? legalReviewStepId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final params = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
      if (vehicleVin != null && vehicleVin.trim().isNotEmpty)
        'vehicleVin': vehicleVin.trim(),
      if (vehicleGosNumber != null && vehicleGosNumber.trim().isNotEmpty)
        'vehicleGosNumber': vehicleGosNumber.trim(),
      if (batchNumber != null && batchNumber.trim().isNotEmpty)
        'batchNumber': batchNumber.trim(),
      if (checkType != null && checkType.trim().isNotEmpty)
        'checkType': checkType.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (legalReviewStepId != null) 'legalReviewStepId': legalReviewStepId,
    };
    final data = await _postRpc(
      method: 'Storage.GetLegalReviewChecks',
      params: params,
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Запускает ApiCloud-конвертер (`api_cloud_converter_search`) и возвращает
  /// его `batchNumber` (или '' при сбое). **Платно**; требует `run_legal_review`
  /// (403 → [PermissionDeniedException], surface'ит вызывающий). Передай `vin`
  /// ИЛИ `gosNumber`.
  ///
  /// Разделено с поллингом намеренно: клиент сохраняет `batchNumber` в
  /// персистентное хранилище ДО опроса, поэтому медленный/прерванный результат
  /// не теряется, а повторный запуск переиспользует уже **оплаченный** батч
  /// ([pollVinPlateConverterBatch]) вместо новой оплаты.
  static Future<String> startVinPlateConverter({
    String? vin,
    String? gosNumber,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // DIAG: trace the paid start call to find why the browser hangs.
    developer.log(
      'start: vin="$vin" gosNumber="$gosNumber" timeout=${timeout.inSeconds}s',
      name: 'StorageApi.converter',
    );
    final started = await runBatchLegalReview(
      checkTypes: const ['api_cloud_converter_search'],
      vin: vin,
      gosNumber: gosNumber,
      timeout: timeout,
    );
    final batchNumber = (started['batchNumber'] ?? '').toString().trim();
    developer.log(
      'start done: batchNumber="$batchNumber" raw=${started.keys.toList()}',
      name: 'StorageApi.converter',
    );
    return batchNumber;
  }

  /// Опрашивает СУЩЕСТВУЮЩИЙ батч конвертера (**бесплатно** — только чтения
  /// `GetBatchLegalReviewResults`) до терминального статуса.
  ///
  /// Экспоненциальный backoff: интервал растёт [firstInterval] → ×[backoffFactor]
  /// → cap [maxInterval], пока суммарное ожидание < [maxWait]. То же окно
  /// ожидания, что и фикс-3с×50, но кратно меньше запросов (≈10–13 вместо 50).
  /// Воркер ApiCloud может лагать (наблюдали ~84с 2026-06-08, ~116с 2026-06-03);
  /// потолок щедрый, чтобы медленный-но-рабочий чек дорезолвился. Поздний
  /// результат на бэке не теряется → на `timedOut` вызывающий показывает
  /// «попробуйте позже» (НЕ «не найдено») и не блокирует UI навсегда.
  /// [onProgress] зовётся на каждом опросе (индекс, прошедшее время) — для
  /// прогресс-индикатора.
  static Future<VinPlateConverterResult> pollVinPlateConverterBatch(
    String batchNumber, {
    Duration firstInterval = const Duration(seconds: 2),
    double backoffFactor = 1.5,
    Duration maxInterval = const Duration(seconds: 15),
    Duration maxWait = const Duration(seconds: 165),
    void Function(int pollIndex, Duration elapsed)? onProgress,
  }) async {
    if (batchNumber.trim().isEmpty) return _emptyVinPlateResult;
    Duration grow(Duration d) {
      final next = d * backoffFactor;
      return next > maxInterval ? maxInterval : next;
    }

    // DIAG: trace each poll to find why the browser never resolves.
    developer.log(
      'poll start: batch="$batchNumber" maxWait=${maxWait.inSeconds}s',
      name: 'StorageApi.converter',
    );
    var interval = firstInterval;
    var elapsed = Duration.zero;
    var poll = 0;
    var emptyStreak = 0;
    var failStreak = 0;
    while (elapsed < maxWait) {
      await Future<void>.delayed(interval);
      elapsed += interval;
      poll++;
      onProgress?.call(poll, elapsed);
      Map<String, dynamic> res;
      try {
        res = await getBatchLegalReviewResults(
          batchNumber: batchNumber,
          timeout: const Duration(seconds: 10),
        );
      } catch (e) {
        // Таймаут/сбой поллинга: пара попыток, потом считаем, что бэк не
        // отвечает вовремя → timedOut (а не «не найдено»), чтобы не растягивать
        // цикл на минуты на тормозящем воркере.
        developer.log(
          'poll #$poll THREW after ${elapsed.inSeconds}s: $e '
          '(failStreak=${failStreak + 1})',
          name: 'StorageApi.converter',
        );
        if (++failStreak >= 3) return _timedOutVinPlateResult;
        interval = grow(interval);
        continue;
      }
      failStreak = 0;
      final rawChecks = res['checks'];
      final checks = rawChecks is List
          ? rawChecks
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      if (checks.isEmpty) {
        // Пустой ответ — несколько попыток, потом сдаёмся.
        developer.log(
          'poll #$poll EMPTY (no checks) after ${elapsed.inSeconds}s '
          '(emptyStreak=${emptyStreak + 1})',
          name: 'StorageApi.converter',
        );
        if (++emptyStreak >= 3) return _emptyVinPlateResult;
        interval = grow(interval);
        continue;
      }
      emptyStreak = 0;
      // DIAG: log the raw status set + checkTypes seen.
      final statusSet = checks
          .map((c) => '${c['checkType']}:${c['status']}')
          .join(',');
      final pending = legalReviewBatchPending(checks);
      developer.log(
        'poll #$poll after ${elapsed.inSeconds}s: pending=$pending '
        'statuses=[$statusSet]',
        name: 'StorageApi.converter',
      );
      if (!pending) {
        for (final c in checks) {
          if ((c['checkType'] ?? '').toString() ==
              'api_cloud_converter_search') {
            final normalized = c['responseNormalized'];
            developer.log(
              'poll TERMINAL: converter responseNormalized='
              '${normalized is String ? normalized.substring(0, normalized.length > 200 ? 200 : normalized.length) : normalized}',
              name: 'StorageApi.converter',
            );
            return parseVinPlateConverterResult(normalized);
          }
        }
        developer.log(
          'poll TERMINAL but NO converter check in batch '
          '(types=${checks.map((c) => c['checkType']).join(',')})',
          name: 'StorageApi.converter',
        );
        return _emptyVinPlateResult;
      }
      interval = grow(interval);
    }
    // Окно ожидания исчерпано, проверка всё ещё pending → воркер лагает.
    developer.log(
      'poll TIMED OUT after ${elapsed.inSeconds}s '
      '(batch never left pending)',
      name: 'StorageApi.converter',
      level: 900, // warning level
    );
    return _timedOutVinPlateResult;
  }

  /// Convenience: старт (платно) + поллинг (бесплатно) одним вызовом. Прямой
  /// вызов НЕ переиспользует батч между запусками — клиент в spark_joy ради
  /// экономии денег дёргает [startVinPlateConverter]/[pollVinPlateConverterBatch]
  /// раздельно и персистит `batchNumber`. Оставлено для совместимости/тестов;
  /// по умолчанию сохраняет старое поведение (фикс-интервал, без backoff).
  static Future<VinPlateConverterResult> runVinPlateConverter({
    String? vin,
    String? gosNumber,
    Duration pollInterval = const Duration(seconds: 3),
    int maxPolls = 50,
  }) async {
    final batchNumber = await startVinPlateConverter(
      vin: vin,
      gosNumber: gosNumber,
    );
    if (batchNumber.isEmpty) return _emptyVinPlateResult;
    return pollVinPlateConverterBatch(
      batchNumber,
      firstInterval: pollInterval,
      backoffFactor: 1.0,
      maxInterval: pollInterval,
      maxWait: pollInterval * maxPolls,
    );
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
    int page = 1,
    int limit = 20,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetCompanySpecialists',
      params: {'page': page, 'limit': limit},
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

  /// Returns the current user's effective RBAC permissions.
  ///
  /// Backend `result` = `{role: string, permissions: [string]}` — the
  /// permission slugs (e.g. `edit_profile`, `edit_reports`, `view_reports`,
  /// `manage_company`, `run_legal_review`) the user currently holds. Needs
  /// only an AUTH token (no specific permission). Mirrors [getProfile]'s
  /// shape so the caller parses the raw result map.
  static Future<Map<String, dynamic>> getPermissions({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetPermissions',
      params: const {},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Returns public company profile data by company user id.
  static Future<Map<String, dynamic>> getCompanyProfile({
    required int companyId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetCompanyProfile',
      params: <String, dynamic>{'companyId': companyId},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  /// Updates the current user profile.
  static Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> profile,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final refreshRoleToken = _profileUpdateChangesRole(profile);
    final data = await _postRpc(
      method: 'Storage.UpdateProfile',
      params: profile,
      timeout: timeout,
    );
    if (refreshRoleToken) {
      await _tryRefreshTokens();
    }
    return _asMap(data['result']);
  }

  /// Deactivates the current user account.
  ///
  /// Backend contract: no params, requires `edit_profile`, sets
  /// `is_active=false` without changing `is_delete`, and invalidates mobile
  /// refresh by resetting mobileJti. Caller must clear local auth tokens after
  /// a successful response.
  static Future<Map<String, dynamic>> deactivateAccount({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.DeactivateAccount',
      params: const {},
      timeout: timeout,
    );
    return _asMap(data['result']);
  }

  static bool _profileUpdateChangesRole(Map<String, dynamic> profile) {
    final role = profile['role']?.toString().trim().toLowerCase();
    return role == 'company' || role == 'specialist';
  }

  /// Подтверждение email-адреса кодом из письма. Code приходит на email
  /// пользователя автоматически после смены email через UpdateProfile.
  /// Контракт получен от backend через пример payload'а — `Doc` пока
  /// возвращает `Storage.VerifyEmail` как голую строку без полного
  /// schema, поэтому result-структура здесь толерантна (пробрасываем
  /// результат как Map для будущего расширения).
  static Future<Map<String, dynamic>> verifyEmail({
    required String code,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.VerifyEmail',
      params: <String, dynamic>{'code': code},
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

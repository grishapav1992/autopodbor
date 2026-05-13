import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Isolate helpers for auto-request list JSON ───────────────────────────
// Same rationale as in spark_joy_storage.dart: `compute()` only pays off
// when the payload is large enough to exceed the isolate spawn + SendPort
// round-trip cost. We keep a per-item threshold here because a single
// auto-request entry is small (~1–3 KB), so anything under ~4 entries is
// faster to process synchronously on the UI thread.

const int _autoRequestsIsolateThresholdItems = 4;

/// Top-level function (required by `compute()`) — encodes a list of
/// auto-request maps into SharedPreferences-ready JSON strings.
List<String> _encodeAutoRequestsForPrefs(List<Map<String, dynamic>> values) {
  return values.map(jsonEncode).toList(growable: false);
}

/// Normalizes the stored auto-request `status` field, undoing the mojibake
/// leftovers from earlier encoding bugs. Lives at the top level so it can
/// run inside a background isolate via `compute()`.
String _sanitizeAutoRequestStatus(String? value) {
  if (value == null || value.isEmpty) return 'Создана';
  if (value.contains('?')) return 'Создана';
  if (value == 'РЎРѕР·РґР°РЅР°') return 'Создана';
  if (value == 'Р’ СЂР°Р±РѕС‚Рµ') return 'В работе';
  if (value == 'Р—Р°РІРµСЂС€РµРЅР°') return 'Завершена';
  if (value == 'РћС‚РјРµРЅРµРЅР°') return 'Отменена';
  return value;
}

/// Top-level function (required by `compute()`) — decodes the stored JSON
/// strings and sanitizes the `status` field so consumers can treat the
/// list as ready-to-render.
List<Map<String, dynamic>> _decodeAutoRequestsFromPrefs(List<String> raw) {
  final result = <Map<String, dynamic>>[];
  for (final item in raw) {
    try {
      final decoded = jsonDecode(item);
      if (decoded is Map<String, dynamic>) {
        final status = decoded['status'];
        if (status is String) {
          decoded['status'] = _sanitizeAutoRequestStatus(status);
        }
        result.add(decoded);
      }
    } catch (_) {}
  }
  return result;
}

class UserSimplePreferences {
  static SharedPreferences? pref;
  static const _languageIndexKey = 'languageKey';
  static const _chooseLanguageFirstTime = 'chooseLanguageFirstTime';
  static const _reportQueryKey = 'reportQuery';
  static const _reportVerdictKey = 'reportVerdict';
  static const _reportMakeKey = 'reportMake';
  static const _reportModelKey = 'reportModel';
  static const _reportInspectorKey = 'reportInspector';
  static const _reportVerdictsKey = 'reportVerdicts';
  static const _reportMakesKey = 'reportMakes';
  static const _reportModelsKey = 'reportModels';
  static const _reportInspectorsKey = 'reportInspectors';
  static const _reportSortOrderKey = 'reportSortOrder';
  static const _brandCacheKey = 'brandCache';
  static const _brandCacheTsKey = 'brandCacheTs';
  static const _brandRusCacheKey = 'brandRusCache';
  static const _autoRequestsKey = 'autoRequests';
  static const _requestDisplayOverridesKey = 'requestDisplayOverrides';
  static const _inspectorAboutKey = 'inspectorAbout';
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _notificationTokenKey = 'notificationToken';
  static const _userRoleKey = 'userRole';

  // Spark Joy onboarding "shown once" flags. Each key corresponds to a
  // contextual bottom sheet that appears at the first encounter with a
  // major Spark Joy section for users in the Specialist (dealer) role.
  static const sparkOnbReportsListKey = 'sparkOnb.reportsList';
  static const sparkOnbReportEditorKey = 'sparkOnb.reportEditor';
  static const sparkOnbVinScannerKey = 'sparkOnb.vinScanner';
  static const sparkOnbMediaStepKey = 'sparkOnb.mediaStep';
  static const sparkOnbCommentAiKey = 'sparkOnb.commentAi';
  static const sparkOnbSummaryStepKey = 'sparkOnb.summaryStep';
  // Company-role-only sheets — staff management and per-report
  // assignment flow.
  static const sparkOnbStaffKey = 'sparkOnb.staff';
  static const sparkOnbAssignReportKey = 'sparkOnb.assignReport';


  static const List<String> sparkOnboardingKeys = <String>[
    sparkOnbReportsListKey,
    sparkOnbReportEditorKey,
    sparkOnbVinScannerKey,
    sparkOnbMediaStepKey,
    sparkOnbCommentAiKey,
    sparkOnbSummaryStepKey,
    sparkOnbStaffKey,
    sparkOnbAssignReportKey,
  ];

  static Future init() async {
    pref = await SharedPreferences.getInstance();
  }

  static Future<SharedPreferences> _prefs() async {
    final current = pref;
    if (current != null) return current;
    final loaded = await SharedPreferences.getInstance();
    pref = loaded;
    return loaded;
  }

  static Future setLanguageIndex(int index) async {
    await (await _prefs()).setInt(_languageIndexKey, index);
  }

  static Future getLanguageIndex() async {
    // ignore: await_only_futures
    return (await _prefs()).getInt(_languageIndexKey);
  }

  static Future isFirstLaunch(bool value) async {
    await (await _prefs()).setBool(_chooseLanguageFirstTime, value);
  }

  static Future getIsFirstLaunch() async {
    // ignore: await_only_futures
    return (await _prefs()).getBool(_chooseLanguageFirstTime);
  }

  static Future setReportQuery(String value) async {
    await (await _prefs()).setString(_reportQueryKey, value);
  }

  static Future getReportQuery() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_reportQueryKey);
  }

  static Future setReportVerdict(String value) async {
    await (await _prefs()).setString(_reportVerdictKey, value);
  }

  static Future getReportVerdict() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_reportVerdictKey);
  }

  static Future setReportMake(String value) async {
    await (await _prefs()).setString(_reportMakeKey, value);
  }

  static Future getReportMake() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_reportMakeKey);
  }

  static Future setReportModel(String value) async {
    await (await _prefs()).setString(_reportModelKey, value);
  }

  static Future getReportModel() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_reportModelKey);
  }

  static Future setReportInspector(String value) async {
    await (await _prefs()).setString(_reportInspectorKey, value);
  }

  static Future getReportInspector() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_reportInspectorKey);
  }

  static Future setReportVerdicts(List<String> values) async {
    await (await _prefs()).setStringList(_reportVerdictsKey, values);
  }

  static Future<List<String>?> getReportVerdicts() async {
    // ignore: await_only_futures
    return (await _prefs()).getStringList(_reportVerdictsKey);
  }

  static Future setReportMakes(List<String> values) async {
    await (await _prefs()).setStringList(_reportMakesKey, values);
  }

  static Future<List<String>?> getReportMakes() async {
    // ignore: await_only_futures
    return (await _prefs()).getStringList(_reportMakesKey);
  }

  static Future setReportModels(List<String> values) async {
    await (await _prefs()).setStringList(_reportModelsKey, values);
  }

  static Future<List<String>?> getReportModels() async {
    // ignore: await_only_futures
    return (await _prefs()).getStringList(_reportModelsKey);
  }

  static Future setReportInspectors(List<String> values) async {
    await (await _prefs()).setStringList(_reportInspectorsKey, values);
  }

  static Future<List<String>?> getReportInspectors() async {
    // ignore: await_only_futures
    return (await _prefs()).getStringList(_reportInspectorsKey);
  }

  static Future setReportSortOrder(String value) async {
    await (await _prefs()).setString(_reportSortOrderKey, value);
  }

  static Future<String?> getReportSortOrder() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_reportSortOrderKey);
  }

  static Future setBrandCache(
    List<String> values,
    Map<String, String> rusByName,
  ) async {
    await (await _prefs()).setStringList(_brandCacheKey, values);
    final combined = values
        .map((name) => '$name|${rusByName[name] ?? ''}')
        .toList();
    await (await _prefs()).setStringList(_brandRusCacheKey, combined);
    await (await _prefs()).setInt(
      _brandCacheTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<List<String>?> getBrandCache() async {
    // ignore: await_only_futures
    return (await _prefs()).getStringList(_brandCacheKey);
  }

  static Future<Map<String, String>> getBrandRusCache() async {
    // ignore: await_only_futures
    final list = (await _prefs()).getStringList(_brandRusCacheKey);
    final map = <String, String>{};
    if (list == null) return map;
    for (final entry in list) {
      final idx = entry.indexOf('|');
      if (idx <= 0) continue;
      final name = entry.substring(0, idx);
      final rus = entry.substring(idx + 1);
      map[name] = rus;
    }
    return map;
  }

  static Future<int?> getBrandCacheTimestamp() async {
    // ignore: await_only_futures
    return (await _prefs()).getInt(_brandCacheTsKey);
  }

  static Future clearBrandCache() async {
    await (await _prefs()).remove(_brandCacheKey);
    await (await _prefs()).remove(_brandCacheTsKey);
    await (await _prefs()).remove(_brandRusCacheKey);
  }

  // Status sanitization moved to the top-level _sanitizeAutoRequestStatus
  // function so it can run inside a background isolate via compute(); the
  // class-level wrapper was unused and got removed during Phase 2 perf work.

  static Future<List<Map<String, dynamic>>> getAutoRequests() async {
    // ignore: await_only_futures
    final list = (await _prefs()).getStringList(_autoRequestsKey) ?? [];
    if (list.isEmpty) return <Map<String, dynamic>>[];
    // Offload decoding + status sanitization to a background isolate for
    // non-trivial lists; stay sync for a handful of items.
    if (list.length >= _autoRequestsIsolateThresholdItems) {
      return compute(_decodeAutoRequestsFromPrefs, list);
    }
    return _decodeAutoRequestsFromPrefs(list);
  }

  static Future setAutoRequests(List<Map<String, dynamic>> values) async {
    // Offload encoding to a background isolate when the list is large
    // enough to matter; stay sync for small lists to avoid the ~20 ms
    // spawn overhead. Benchmarks: 1–3 items finish in <1 ms sync.
    final List<String> list;
    if (values.length >= _autoRequestsIsolateThresholdItems) {
      list = await compute(_encodeAutoRequestsForPrefs, values);
    } else {
      list = _encodeAutoRequestsForPrefs(values);
    }
    await (await _prefs()).setStringList(_autoRequestsKey, list);
  }

  static Future addAutoRequest(Map<String, dynamic> value) async {
    final list = await getAutoRequests();
    list.insert(0, value);
    await setAutoRequests(list);
  }

  static Future<Map<String, dynamic>> getRequestDisplayOverrides() async {
    final raw = (await _prefs()).getString(_requestDisplayOverridesKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>?> getRequestDisplayOverride(
    String key,
  ) async {
    final map = await getRequestDisplayOverrides();
    final value = map[key];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static Future<void> setRequestDisplayOverride(
    String key,
    Map<String, dynamic> value,
  ) async {
    final map = await getRequestDisplayOverrides();
    map[key] = value;
    await (await _prefs()).setString(
      _requestDisplayOverridesKey,
      jsonEncode(map),
    );
  }

  static Future updateAutoRequest(String id, Map<String, dynamic> patch) async {
    final list = await getAutoRequests();
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item['id'] == id) {
        list[i] = {...item, ...patch};
        break;
      }
    }
    await setAutoRequests(list);
  }

  static Future setInspectorAbout(String value) async {
    await (await _prefs()).setString(_inspectorAboutKey, value);
  }

  static Future<String?> getInspectorAbout() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_inspectorAboutKey);
  }

  static Future<void> setAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await (await _prefs()).setString(_accessTokenKey, accessToken);
    await (await _prefs()).setString(_refreshTokenKey, refreshToken);
  }

  static Future<String?> getAccessToken() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_refreshTokenKey);
  }

  static Future<void> clearAuthTokens() async {
    await (await _prefs()).remove(_accessTokenKey);
    await (await _prefs()).remove(_refreshTokenKey);
    await (await _prefs()).remove(_notificationTokenKey);
  }

  static Future<void> setNotificationToken(String token) async {
    await (await _prefs()).setString(_notificationTokenKey, token);
  }

  static Future<String?> getNotificationToken() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_notificationTokenKey);
  }

  static Future<void> clearNotificationToken() async {
    await (await _prefs()).remove(_notificationTokenKey);
  }

  static Future<void> setUserRole(String role) async {
    await (await _prefs()).setString(_userRoleKey, role);
  }

  static Future<String?> getUserRole() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_userRoleKey);
  }

  static Future<bool> isSparkOnboardingSeen(String key) async {
    return (await _prefs()).getBool(key) ?? false;
  }

  static Future<void> setSparkOnboardingSeen(String key) async {
    await (await _prefs()).setBool(key, true);
  }

  static Future<void> resetSparkOnboarding() async {
    final prefs = await _prefs();
    for (final key in sparkOnboardingKeys) {
      await prefs.remove(key);
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  static const _inspectorAboutKey = 'inspectorAbout';
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _userRoleKey = 'userRole';

  static Future init() async {
    pref = await SharedPreferences.getInstance();
  }

  static Future setLanguageIndex(int index) async {
    await pref!.setInt(_languageIndexKey, index);
  }

  static Future getLanguageIndex() async {
    // ignore: await_only_futures
    return await pref!.getInt(_languageIndexKey);
  }

  static Future isFirstLaunch(bool value) async {
    await pref!.setBool(_chooseLanguageFirstTime, value);
  }

  static Future getIsFirstLaunch() async {
    // ignore: await_only_futures
    return await pref!.getBool(_chooseLanguageFirstTime);
  }

  static Future setReportQuery(String value) async {
    await pref!.setString(_reportQueryKey, value);
  }

  static Future getReportQuery() async {
    // ignore: await_only_futures
    return await pref!.getString(_reportQueryKey);
  }

  static Future setReportVerdict(String value) async {
    await pref!.setString(_reportVerdictKey, value);
  }

  static Future getReportVerdict() async {
    // ignore: await_only_futures
    return await pref!.getString(_reportVerdictKey);
  }

  static Future setReportMake(String value) async {
    await pref!.setString(_reportMakeKey, value);
  }

  static Future getReportMake() async {
    // ignore: await_only_futures
    return await pref!.getString(_reportMakeKey);
  }

  static Future setReportModel(String value) async {
    await pref!.setString(_reportModelKey, value);
  }

  static Future getReportModel() async {
    // ignore: await_only_futures
    return await pref!.getString(_reportModelKey);
  }

  static Future setReportInspector(String value) async {
    await pref!.setString(_reportInspectorKey, value);
  }

  static Future getReportInspector() async {
    // ignore: await_only_futures
    return await pref!.getString(_reportInspectorKey);
  }

  static Future setReportVerdicts(List<String> values) async {
    await pref!.setStringList(_reportVerdictsKey, values);
  }

  static Future<List<String>?> getReportVerdicts() async {
    // ignore: await_only_futures
    return await pref!.getStringList(_reportVerdictsKey);
  }

  static Future setReportMakes(List<String> values) async {
    await pref!.setStringList(_reportMakesKey, values);
  }

  static Future<List<String>?> getReportMakes() async {
    // ignore: await_only_futures
    return await pref!.getStringList(_reportMakesKey);
  }

  static Future setReportModels(List<String> values) async {
    await pref!.setStringList(_reportModelsKey, values);
  }

  static Future<List<String>?> getReportModels() async {
    // ignore: await_only_futures
    return await pref!.getStringList(_reportModelsKey);
  }

  static Future setReportInspectors(List<String> values) async {
    await pref!.setStringList(_reportInspectorsKey, values);
  }

  static Future<List<String>?> getReportInspectors() async {
    // ignore: await_only_futures
    return await pref!.getStringList(_reportInspectorsKey);
  }

  static Future setReportSortOrder(String value) async {
    await pref!.setString(_reportSortOrderKey, value);
  }

  static Future<String?> getReportSortOrder() async {
    // ignore: await_only_futures
    return await pref!.getString(_reportSortOrderKey);
  }

  static Future setBrandCache(
    List<String> values,
    Map<String, String> rusByName,
  ) async {
    await pref!.setStringList(_brandCacheKey, values);
    final combined = values
        .map((name) => '$name|${rusByName[name] ?? ''}')
        .toList();
    await pref!.setStringList(_brandRusCacheKey, combined);
    await pref!.setInt(_brandCacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<List<String>?> getBrandCache() async {
    // ignore: await_only_futures
    return await pref!.getStringList(_brandCacheKey);
  }

  static Future<Map<String, String>> getBrandRusCache() async {
    // ignore: await_only_futures
    final list = await pref!.getStringList(_brandRusCacheKey);
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
    return await pref!.getInt(_brandCacheTsKey);
  }

  static Future clearBrandCache() async {
    await pref!.remove(_brandCacheKey);
    await pref!.remove(_brandCacheTsKey);
    await pref!.remove(_brandRusCacheKey);
  }

  static String _sanitizeStatus(String? value) {
    if (value == null || value.isEmpty) return 'Создана';
    if (value.contains('?')) return 'Создана';
    if (value == 'РЎРѕР·РґР°РЅР°') return 'Создана';
    if (value == 'Р’ СЂР°Р±РѕС‚Рµ') return 'В работе';
    if (value == 'Р—Р°РІРµСЂС€РµРЅР°') return 'Завершена';
    if (value == 'РћС‚РјРµРЅРµРЅР°') return 'Отменена';
    return value;
  }

  static Future<List<Map<String, dynamic>>> getAutoRequests() async {
    // ignore: await_only_futures
    final list = await pref!.getStringList(_autoRequestsKey) ?? [];
    final result = <Map<String, dynamic>>[];
    for (final raw in list) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final status = decoded['status'];
          if (status is String) {
            decoded['status'] = _sanitizeStatus(status);
          }
          result.add(decoded);
        }
      } catch (_) {}
    }
    return result;
  }

  static Future setAutoRequests(List<Map<String, dynamic>> values) async {
    final list = values.map(jsonEncode).toList();
    await pref!.setStringList(_autoRequestsKey, list);
  }

  static Future addAutoRequest(Map<String, dynamic> value) async {
    final list = await getAutoRequests();
    list.insert(0, value);
    await setAutoRequests(list);
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
    await pref!.setString(_inspectorAboutKey, value);
  }

  static Future<String?> getInspectorAbout() async {
    // ignore: await_only_futures
    return await pref!.getString(_inspectorAboutKey);
  }

  static Future<void> setAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await pref!.setString(_accessTokenKey, accessToken);
    await pref!.setString(_refreshTokenKey, refreshToken);
  }

  static Future<String?> getAccessToken() async {
    // ignore: await_only_futures
    return await pref!.getString(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    // ignore: await_only_futures
    return await pref!.getString(_refreshTokenKey);
  }

  static Future<void> clearAuthTokens() async {
    await pref!.remove(_accessTokenKey);
    await pref!.remove(_refreshTokenKey);
  }

  static Future<void> setUserRole(String role) async {
    await pref!.setString(_userRoleKey, role);
  }

  static Future<String?> getUserRole() async {
    // ignore: await_only_futures
    return await pref!.getString(_userRoleKey);
  }
}

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
}

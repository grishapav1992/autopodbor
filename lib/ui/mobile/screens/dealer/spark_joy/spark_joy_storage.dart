import 'dart:convert';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'spark_joy_data.dart';

class SparkJoyStorage {
  SparkJoyStorage._();

  static const String _loggedInKey = 'spark_joy_logged_in_v1';
  static const String _roleKey = 'spark_joy_role_v1';
  static const String _verifiedInnKey = 'spark_joy_verified_inn_v1';
  static const String _businessTypeKey = 'spark_joy_business_type_v1';
  static const String _draftsKey = 'spark_joy_drafts_v1';
  static const String _completedKey = 'spark_joy_completed_v1';

  static Future<bool> isLoggedIn() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return false;
    return pref.getBool(_loggedInKey) ?? false;
  }

  static Future<SparkJoyRole> currentRole() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return SparkJoyRole.specialist;
    final rawRole = pref.getString(_roleKey);
    if (rawRole != null && rawRole.isNotEmpty) {
      return sparkJoyRoleFromKey(rawRole);
    }
    final businessType = pref.getString(_businessTypeKey);
    if (businessType == 'company' || businessType == 'ip') {
      return SparkJoyRole.company;
    }
    return SparkJoyRole.specialist;
  }

  static Future<void> login(SparkJoyRole role) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setBool(_loggedInKey, true);
    await pref.setString(_roleKey, sparkJoyRoleKey(role));
  }

  static Future<void> logout() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setBool(_loggedInKey, false);
  }

  static Future<String?> currentBusinessType() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return null;
    return pref.getString(_businessTypeKey);
  }

  static Future<String?> currentVerifiedInn() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return null;
    return pref.getString(_verifiedInnKey);
  }

  static String normalizeInn(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool isValidInn(String raw, {bool strict = false}) {
    final inn = normalizeInn(raw);
    if (inn.length != 10 && inn.length != 12) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(inn)) return false;
    if (!strict) return true;
    return _isInnChecksumValid(inn);
  }

  static bool _isInnChecksumValid(String inn) {
    final digits = inn.split('').map(int.parse).toList(growable: false);
    if (inn.length == 10) {
      final checksum =
          ((2 * digits[0] +
                  4 * digits[1] +
                  10 * digits[2] +
                  3 * digits[3] +
                  5 * digits[4] +
                  9 * digits[5] +
                  4 * digits[6] +
                  6 * digits[7] +
                  8 * digits[8]) %
              11) %
          10;
      return checksum == digits[9];
    }
    final checksum11 =
        ((7 * digits[0] +
                2 * digits[1] +
                4 * digits[2] +
                10 * digits[3] +
                3 * digits[4] +
                5 * digits[5] +
                9 * digits[6] +
                4 * digits[7] +
                6 * digits[8] +
                8 * digits[9]) %
            11) %
        10;
    final checksum12 =
        ((3 * digits[0] +
                7 * digits[1] +
                2 * digits[2] +
                4 * digits[3] +
                10 * digits[4] +
                3 * digits[5] +
                5 * digits[6] +
                9 * digits[7] +
                4 * digits[8] +
                6 * digits[9] +
                8 * digits[10]) %
            11) %
        10;
    return checksum11 == digits[10] && checksum12 == digits[11];
  }

  static String? detectBusinessTypeByInn(String raw) {
    final inn = normalizeInn(raw);
    if (!isValidInn(inn)) return null;
    if (inn.length == 10) return 'company';
    if (inn.length == 12) return 'ip';
    return null;
  }

  static Future<String?> verifyInnAndPromote(String rawInn) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return null;
    final inn = normalizeInn(rawInn);
    final businessType = detectBusinessTypeByInn(inn);
    if (businessType == null) return null;
    await pref.setString(_verifiedInnKey, inn);
    await pref.setString(_businessTypeKey, businessType);
    await pref.setString(_roleKey, sparkJoyRoleKey(SparkJoyRole.company));
    await pref.setBool(_loggedInKey, true);
    await UserSimplePreferences.setUserRole('company');
    return businessType;
  }

  static Future<void> resetBusinessVerification() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.remove(_verifiedInnKey);
    await pref.remove(_businessTypeKey);
    await pref.setString(_roleKey, sparkJoyRoleKey(SparkJoyRole.specialist));
    await UserSimplePreferences.setUserRole('specialist');
  }

  static Future<void> ensureSeedData() async {
    await _clearCompletedCache();
  }

  static Future<List<Map<String, dynamic>>> loadDrafts() async {
    return _readList(_draftsKey);
  }

  static Future<List<Map<String, dynamic>>> loadCompleted() async {
    await _clearCompletedCache();
    return const <Map<String, dynamic>>[];
  }

  static Future<void> upsertDraft(Map<String, dynamic> draft) async {
    final drafts = await loadDrafts();
    final id = (draft['id'] ?? '').toString();
    if (id.isEmpty) return;
    final filtered = drafts.where((d) => d['id']?.toString() != id).toList();
    filtered.insert(0, draft);
    await _writeList(_draftsKey, filtered);
  }

  static Future<void> deleteDraft(String id) async {
    final drafts = await loadDrafts();
    await _writeList(
      _draftsKey,
      drafts.where((d) => d['id']?.toString() != id).toList(),
    );
  }

  static Future<void> upsertCompleted(Map<String, dynamic> report) async {
    // Completed reports are not stored locally anymore.
  }

  static Future<void> deleteCompleted(String id) async {
    // Completed reports are not stored locally anymore.
  }

  static Future<void> moveDraftToCompleted({
    required String draftId,
    required Map<String, dynamic> completedReport,
  }) async {
    // Kept for backward compatibility: locally we now store drafts only.
    await deleteDraft(draftId);
  }

  static Future<void> purgeDraftAfterUpload(String draftId) async {
    await deleteDraft(draftId);
  }

  static Future<List<Map<String, dynamic>>> _readList(String key) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return [];
    final raw = pref.getStringList(key) ?? <String>[];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          result.add(decoded);
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<void> _writeList(
    String key,
    List<Map<String, dynamic>> values,
  ) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setStringList(key, values.map(jsonEncode).toList());
  }

  static Future<void> _clearCompletedCache() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.remove(_completedKey);
  }
}

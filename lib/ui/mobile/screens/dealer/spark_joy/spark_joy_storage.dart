import 'dart:convert';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'spark_joy_data.dart';

class SparkJoyStorage {
  SparkJoyStorage._();

  static const String _loggedInKey = 'spark_joy_logged_in_v1';
  static const String _roleKey = 'spark_joy_role_v1';
  static const String _draftsKey = 'spark_joy_drafts_v1';
  static const String _completedKey = 'spark_joy_completed_v1';
  static const String _legacySeedCompletedId = 'spark_report_seed_1';

  static Future<bool> isLoggedIn() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return false;
    return pref.getBool(_loggedInKey) ?? false;
  }

  static Future<SparkJoyRole> currentRole() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return SparkJoyRole.specialist;
    return sparkJoyRoleFromKey(pref.getString(_roleKey));
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

  static Future<void> ensureSeedData() async {
    final completed = await loadCompleted();
    final cleaned = completed
        .where(
          (report) => (report['id'] ?? '').toString() != _legacySeedCompletedId,
        )
        .toList();
    if (cleaned.length != completed.length) {
      await _writeList(_completedKey, cleaned);
    }
  }

  static Future<List<Map<String, dynamic>>> loadDrafts() async {
    return _readList(_draftsKey);
  }

  static Future<List<Map<String, dynamic>>> loadCompleted() async {
    return _readList(_completedKey);
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
    final completed = await loadCompleted();
    final id = (report['id'] ?? '').toString();
    if (id.isEmpty) return;
    final filtered = completed.where((d) => d['id']?.toString() != id).toList();
    filtered.insert(0, report);
    await _writeList(_completedKey, filtered);
  }

  static Future<void> deleteCompleted(String id) async {
    final completed = await loadCompleted();
    await _writeList(
      _completedKey,
      completed.where((d) => d['id']?.toString() != id).toList(),
    );
  }

  static Future<void> moveDraftToCompleted({
    required String draftId,
    required Map<String, dynamic> completedReport,
  }) async {
    await upsertCompleted(completedReport);
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
}

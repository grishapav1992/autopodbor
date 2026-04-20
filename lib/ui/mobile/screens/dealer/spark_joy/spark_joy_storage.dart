import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'spark_joy_data.dart';

// ─── Isolate helpers ──────────────────────────────────────────────────────
// `compute()` spawns a fresh isolate (~20–50 ms on first call) + round-trips
// its arguments/results via SendPort, so using it blindly for every JSON
// op is a net loss for small data. We gate by `_jsonIsolateThresholdItems`
// and `_jsonIsolateThresholdBytes`: if the payload is trivially small we
// do the work sync, otherwise we offload to keep the UI at 60 fps while
// inspection-heavy drafts (50+ KB) are encoded/decoded.

const int _jsonIsolateThresholdItems = 4;
const int _jsonIsolateThresholdBytes = 16 * 1024; // ~16 KB

/// Top-level function (required by `compute()`) — encodes a list of report
/// drafts into `SharedPreferences`-ready strings.
List<String> _encodeListForPrefs(List<Map<String, dynamic>> values) {
  return values.map(jsonEncode).toList(growable: false);
}

/// Top-level function (required by `compute()`) — decodes a string list
/// from `SharedPreferences`. Malformed entries are silently skipped so a
/// single corrupt draft can't bring down the whole list.
List<Map<String, dynamic>> _decodeListFromPrefs(List<String> raw) {
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

int _estimateRawBytes(List<String> raw) {
  var total = 0;
  for (final item in raw) {
    total += item.length;
    if (total >= _jsonIsolateThresholdBytes) return total;
  }
  return total;
}

class SparkJoyStorage {
  SparkJoyStorage._();

  static const String _loggedInKey = 'spark_joy_logged_in_v1';
  static const String _roleKey = 'spark_joy_role_v1';
  static const String _verifiedInnKey = 'spark_joy_verified_inn_v1';
  static const String _businessTypeKey = 'spark_joy_business_type_v1';
  static const String _specialistProfileKey = 'spark_joy_specialist_profile_v1';
  static const String _hiddenCompanyStaffIdsKey =
      'spark_joy_hidden_company_staff_ids_v1';
  static const String _draftsKey = 'spark_joy_drafts_v1';
  // Legacy keys kept only for the one-time migration in [migrateLegacyKeys].
  // Completed reports are now online-only (Storage.GetSpecialistReport).
  static const String _legacyCompletedKey = 'spark_joy_completed_v1';
  static const String _legacyCompletedSyncedAtKey =
      'spark_joy_completed_synced_at_v1';
  static const String _userTagsKey = 'spark_joy_user_tags_v1';
  static const String _userTagsSyncedAtKey = 'spark_joy_user_tags_synced_at_v1';
  static const String _pendingTagDeletesKey =
      'spark_joy_pending_tag_deletes_v1';
  static const String _frameCatalogKey = 'spark_joy_frame_catalog_v1';

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

  static Future<Map<String, dynamic>> loadSpecialistProfile() async {
    final base = cloneMap(
      sparkSpecialists.firstWhere(
        (specialist) =>
            (specialist['id'] ?? '').toString() == kSparkSpecialistId,
        orElse: () => sparkSpecialists.first,
      ),
    );
    final pref = UserSimplePreferences.pref;
    if (pref == null) return base;
    final raw = pref.getString(_specialistProfileKey);
    if (raw == null || raw.trim().isEmpty) return base;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return base;
      final saved = Map<String, dynamic>.from(decoded);
      return {...base, ...saved};
    } catch (_) {
      return base;
    }
  }

  static Future<void> saveSpecialistProfile(
    Map<String, dynamic> profile,
  ) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setString(_specialistProfileKey, jsonEncode(profile));
  }

  static Future<List<String>> loadHiddenCompanyStaffIds() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return <String>[];
    final raw = pref.getStringList(_hiddenCompanyStaffIdsKey) ?? <String>[];
    return raw
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  static Future<void> hideCompanyStaffId(String staffId) async {
    final normalized = staffId.trim();
    if (normalized.isEmpty) return;
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    final hidden = await loadHiddenCompanyStaffIds();
    if (!hidden.contains(normalized)) {
      hidden.add(normalized);
    }
    await pref.setStringList(_hiddenCompanyStaffIdsKey, hidden);
  }

  static Future<void> unhideCompanyStaffId(String staffId) async {
    final normalized = staffId.trim();
    if (normalized.isEmpty) return;
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    final hidden = await loadHiddenCompanyStaffIds();
    hidden.removeWhere((id) => id == normalized);
    await pref.setStringList(_hiddenCompanyStaffIdsKey, hidden);
  }

  static Future<void> ensureSeedData() async {
    // Completed reports are online-only — clear any leftover cache
    // from previous app versions so the "Завершённые" tab always
    // reflects the server truth.
    await migrateLegacyKeys();
  }

  static Future<List<Map<String, dynamic>>> loadDrafts() async {
    return _readList(_draftsKey);
  }

  /// Deletes any leftover local completed-reports cache from previous
  /// versions of the app. Completed reports are online-only now.
  static Future<void> migrateLegacyKeys() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    if (pref.containsKey(_legacyCompletedKey)) {
      await pref.remove(_legacyCompletedKey);
    }
    if (pref.containsKey(_legacyCompletedSyncedAtKey)) {
      await pref.remove(_legacyCompletedSyncedAtKey);
    }
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

  static Future<void> purgeDraftAfterUpload(String draftId) async {
    await deleteDraft(draftId);
  }

  static Future<List<Map<String, dynamic>>> _readList(String key) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return [];
    final raw = pref.getStringList(key) ?? <String>[];
    if (raw.isEmpty) return [];
    // Offload decoding to a background isolate only for non-trivial lists —
    // tiny lists finish in <1 ms sync and would pay a net cost under compute.
    if (raw.length >= _jsonIsolateThresholdItems ||
        _estimateRawBytes(raw) >= _jsonIsolateThresholdBytes) {
      return compute(_decodeListFromPrefs, raw);
    }
    return _decodeListFromPrefs(raw);
  }

  static Future<void> _writeList(
    String key,
    List<Map<String, dynamic>> values,
  ) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    // Same rationale as _readList: only use an isolate for meaningful
    // payloads. For small drafts the sync path is faster and keeps the
    // storage API synchronous up to the SharedPreferences boundary.
    final List<String> encoded;
    if (values.length >= _jsonIsolateThresholdItems) {
      encoded = await compute(_encodeListForPrefs, values);
    } else {
      encoded = _encodeListForPrefs(values);
    }
    await pref.setStringList(key, encoded);
  }

  /// Loads the cached user-tag catalog (id + name + step + section + type).
  /// Populated by [replaceUserTags] after a successful `Storage.GetUserTags`
  /// fan-out. Enables the report flow to resolve tag names → server IDs
  /// offline and after app restarts.
  static Future<List<Map<String, dynamic>>> loadUserTags() async {
    return _readList(_userTagsKey);
  }

  static Future<void> replaceUserTags(List<Map<String, dynamic>> tags) async {
    await _writeList(_userTagsKey, tags);
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setString(
      _userTagsSyncedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Queue of tag deletions that failed offline. Each entry:
  /// `{name, step, section}`. Flushed by [SparkJoyTagService] once the
  /// network returns and the user-tag catalog is re-synced.
  static Future<List<Map<String, dynamic>>> loadPendingTagDeletes() async {
    return _readList(_pendingTagDeletesKey);
  }

  static Future<void> replacePendingTagDeletes(
    List<Map<String, dynamic>> items,
  ) async {
    await _writeList(_pendingTagDeletesKey, items);
  }

  /// Frame-id → picker metadata cache. Populated opportunistically when
  /// the user selects a car via the car picker; consumed by the completed-
  /// report hydrator to restore brand / model / generation / restyling /
  /// photoUrl from a `modelGenerationRestylingFrameId` the server echoes.
  ///
  /// On a fresh install the cache is empty — brand/model fields render
  /// as placeholders for reports completed on other devices. Walking the
  /// entire catalog on demand would cost hundreds of RPCs, so we accept
  /// the tradeoff rather than blocking the open.
  static Future<Map<String, dynamic>?> loadFrameCatalogEntry(int frameId) async {
    if (frameId <= 0) return null;
    final pref = UserSimplePreferences.pref;
    if (pref == null) return null;
    final raw = pref.getString(_frameCatalogKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final entry = decoded['$frameId'];
      if (entry is Map) return Map<String, dynamic>.from(entry);
    } catch (_) {}
    return null;
  }

  static Future<void> upsertFrameCatalogEntry({
    required int frameId,
    required Map<String, dynamic> entry,
  }) async {
    if (frameId <= 0) return;
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    Map<String, dynamic> store = <String, dynamic>{};
    final raw = pref.getString(_frameCatalogKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) store = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    store['$frameId'] = entry;
    await pref.setString(_frameCatalogKey, jsonEncode(store));
  }

  static Future<DateTime?> userTagsSyncedAt() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return null;
    final raw = pref.getString(_userTagsSyncedAtKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

}

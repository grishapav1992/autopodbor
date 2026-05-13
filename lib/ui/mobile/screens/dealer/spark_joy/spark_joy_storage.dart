import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
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
  /// External specialists (not originally in the company roster) that
  /// the company has explicitly promoted to staff via "Добавить в штат".
  /// Persists between sessions so the promotion survives app restarts.
  static const String _promotedCompanyStaffIdsKey =
      'spark_joy_promoted_company_staff_ids_v1';
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

  /// Тянет GetProfile и синкает локальный кэш роли + INN с серверной
  /// правдой. Вызывается из login flow (после AuthVerify) и splash
  /// (после hasSavedSession). На сетевую ошибку — fallback на текущий
  /// локальный role-кэш (offline / первый запуск без сети не должен
  /// блокировать вход в приложение).
  static Future<void> syncRoleFromServer() async {
    try {
      // Короткий timeout (5s vs default 12s) — это bootstrap-call, и
      // никакой UI не открывается пока он не вернётся. На offline /
      // медленной сети лучше быстрее упасть и зайти на локальном
      // кэше, чем висеть 12-18 секунд на splash'е до nav-bar.
      final result = await StorageApi.getProfile(
        timeout: const Duration(seconds: 5),
      );
      final serverRole = (result['role'] ?? '').toString().toLowerCase();
      final isCompany = serverRole == 'company';
      await UserSimplePreferences.setUserRole(
        isCompany ? 'company' : 'specialist',
      );
      await login(isCompany ? SparkJoyRole.company : SparkJoyRole.specialist);
      // Для company синкаем companyInn + businessType, чтобы spark_joy
      // экраны (assignee-picker, completed-reports) видели бизнес-
      // статус сразу, без ожидания первого open'а профиля.
      if (isCompany) {
        final inn = result['companyInn']?.toString().trim() ?? '';
        if (inn.length == 10 || inn.length == 12) {
          final pref = UserSimplePreferences.pref;
          if (pref != null) {
            await pref.setString(_verifiedInnKey, inn);
            await pref.setString(
              _businessTypeKey,
              inn.length == 10 ? 'ip' : 'company',
            );
          }
        }
      }
    } catch (e) {
      // Network/offline — оставляем локальный кэш. Будущие GetProfile
      // (при open profile screen) подтянут роль когда сеть вернётся.
      if (kDebugMode) {
        debugPrint('[bootstrap] GetProfile failed during role sync: $e');
      }
      final localRole = await currentRole();
      await login(localRole);
      await UserSimplePreferences.setUserRole(
        localRole == SparkJoyRole.company ? 'company' : 'specialist',
      );
    }
  }

  static Future<void> logout() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setBool(_loggedInKey, false);
    // Wipe every per-user cache so switching accounts on the same
    // device (e.g. specialist → company staff sign-in) doesn't leak
    // the previous owner's data. Drafts, the frame-id → car catalog,
    // the user-tag snapshot, and the pending-deletes queue are all
    // owned by whoever signed in and meaningless to the next user.
    //
    // Бизнес-верификация (`_verifiedInnKey` / `_businessTypeKey`)
    // намеренно **НЕ** чистится: ИНН принадлежит компании, а не
    // пользователю, и при логине другого сотрудника той же компании
    // повторная верификация не нужна. Для ручного сброса есть
    // [resetBusinessVerification].
    await pref.remove(_draftsKey);
    await pref.remove(_frameCatalogKey);
    await pref.remove(_userTagsKey);
    await pref.remove(_userTagsSyncedAtKey);
    await pref.remove(_pendingTagDeletesKey);
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

  /// Проверяет ИНН локально и сохраняет результат.
  ///
  /// Сейчас «проверка» = валидация формата (длина 10 → company,
  /// длина 12 → ip) + checksum. Сетевого запроса нет — бывшая
  /// интеграция с api-cloud.ru/pb_nalog убрана. Когда подключат
  /// нового провайдера, этот метод обновится: он будет дёргать API,
  /// получать данные компании и заполнять расширенные поля.
  /// Storage-ключи `_verifiedInnKey` и `_businessTypeKey` остаются
  /// провайдер-независимым каркасом.
  ///
  /// Раньше параллельный фикс блокировал промоцию неактивных
  /// (terminated/liquidation/exclusion/unknown) ЮЛ через
  /// `isInactivePbNalogStatus(PbNalogStatus)`. Без источника данных
  /// по статусу проверять нечего, гейт временно снят. Восстановить
  /// при подключении нового провайдера — там же, где будет логика
  /// заполнения расширенных полей.
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

  /// Pre-flight summary for the "Сбросить статус" confirmation modal.
  /// Counts every draft currently attributed to the company plus the
  /// subset that carries an active invite link. The modal uses these
  /// numbers to spell out exactly what the hard wipe is about to
  /// destroy.
  static Future<CompanyCancelSummary> buildCompanyCancelSummary() async {
    final drafts = await loadDrafts();
    int total = 0;
    int withAssignee = 0;
    int withPendingInvite = 0;
    for (final d in drafts) {
      final companyId = (d['companyId'] ?? '').toString();
      final businessType = (d['businessType'] ?? '').toString();
      final isCompany = companyId == kSparkCompanyId ||
          businessType == 'company' ||
          businessType == 'ip';
      if (!isCompany) continue;
      total++;
      final assignee = ((d['assignedSpecialistId'] ?? d['specialistId']) ?? '')
          .toString()
          .trim();
      if (assignee.isNotEmpty) withAssignee++;
      final link = (d['staffInviteLink'] ?? '').toString().trim();
      if (link.isNotEmpty && assignee.isEmpty) withPendingInvite++;
    }
    final hidden = await loadHiddenCompanyStaffIds();
    final promoted = await loadPromotedCompanyStaffIds();
    return CompanyCancelSummary(
      totalDrafts: total,
      assignedDrafts: withAssignee,
      pendingInviteDrafts: withPendingInvite,
      hiddenStaff: hidden.length,
      promotedStaff: promoted.length,
    );
  }

  /// Hard-reset of company mode. Deletes every draft owned by the
  /// current company, clears the company-local staff preferences, and
  /// delegates the business-type reset to [resetBusinessVerification].
  /// Callers should show [buildCompanyCancelSummary] in a modal first
  /// — this method does not prompt.
  static Future<void> cancelCompanyMode() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    final drafts = await loadDrafts();
    final keep = drafts.where((d) {
      final companyId = (d['companyId'] ?? '').toString();
      final businessType = (d['businessType'] ?? '').toString();
      final isCompany = companyId == kSparkCompanyId ||
          businessType == 'company' ||
          businessType == 'ip';
      return !isCompany;
    }).toList();
    await _writeList(_draftsKey, keep);
    await pref.remove(_hiddenCompanyStaffIdsKey);
    await pref.remove(_promotedCompanyStaffIdsKey);
    await resetBusinessVerification();
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

  static Future<List<String>> loadPromotedCompanyStaffIds() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return <String>[];
    final raw = pref.getStringList(_promotedCompanyStaffIdsKey) ?? <String>[];
    return raw
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  static Future<void> promoteExternalStaffId(String staffId) async {
    final normalized = staffId.trim();
    if (normalized.isEmpty) return;
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    final promoted = await loadPromotedCompanyStaffIds();
    if (!promoted.contains(normalized)) {
      promoted.add(normalized);
    }
    await pref.setStringList(_promotedCompanyStaffIdsKey, promoted);
  }

  static Future<void> demotePromotedStaffId(String staffId) async {
    final normalized = staffId.trim();
    if (normalized.isEmpty) return;
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    final promoted = await loadPromotedCompanyStaffIds();
    promoted.removeWhere((id) => id == normalized);
    await pref.setStringList(_promotedCompanyStaffIdsKey, promoted);
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
    final id = (draft['id'] ?? '').toString();
    if (id.isEmpty) return;
    await _withDraftLock(() async {
      final drafts = await loadDrafts();
      final filtered = drafts.where((d) => d['id']?.toString() != id).toList();
      filtered.insert(0, draft);
      await _writeList(_draftsKey, filtered);
    });
  }

  /// Atomic read-modify-write of a single draft by id. Use this when
  /// multiple writers can race on the same draft (e.g. autosave +
  /// upload-progress + AI-queue persistence). The [mutate] callback
  /// receives the live draft map; mutate it in place. Returns `true`
  /// when the draft was found and written back, `false` when no draft
  /// with [draftId] exists.
  static Future<bool> applyDraftPatch({
    required String draftId,
    required void Function(Map<String, dynamic> draft) mutate,
  }) async {
    if (draftId.isEmpty) return false;
    final completer = Completer<bool>();
    await _withDraftLock(() async {
      final drafts = await loadDrafts();
      final index = drafts.indexWhere((d) => d['id']?.toString() == draftId);
      if (index < 0) {
        completer.complete(false);
        return;
      }
      final draft = drafts[index];
      mutate(draft);
      final next = [...drafts];
      next[index] = draft;
      await _writeList(_draftsKey, next);
      completer.complete(true);
    });
    return completer.future;
  }

  // Single-flight chain: every draft mutation queues behind the
  // previous one. Cheap when contention is low, prevents read-modify-
  // write loss when two writers fire simultaneously.
  static Future<void> _draftWriteChain = Future<void>.value();

  static Future<T> _withDraftLock<T>(Future<T> Function() body) async {
    final previous = _draftWriteChain;
    final completer = Completer<void>();
    _draftWriteChain = previous.then((_) => completer.future);
    await previous;
    try {
      return await body();
    } finally {
      completer.complete();
    }
  }

  static Future<void> deleteDraft(String id) async {
    await _withDraftLock(() async {
      final drafts = await loadDrafts();
      await _writeList(
        _draftsKey,
        drafts.where((d) => d['id']?.toString() != id).toList(),
      );
    });
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

/// Pre-flight summary shown in the "Сбросить статус" confirmation
/// modal so the user sees exactly what a hard wipe is about to
/// destroy.
class CompanyCancelSummary {
  const CompanyCancelSummary({
    required this.totalDrafts,
    required this.assignedDrafts,
    required this.pendingInviteDrafts,
    required this.hiddenStaff,
    required this.promotedStaff,
  });

  final int totalDrafts;
  final int assignedDrafts;
  final int pendingInviteDrafts;
  final int hiddenStaff;
  final int promotedStaff;

  bool get hasAnyData =>
      totalDrafts > 0 || hiddenStaff > 0 || promotedStaff > 0;
}

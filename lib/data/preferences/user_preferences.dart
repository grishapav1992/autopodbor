import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  // brandCache/brandCacheTs/brandRusCache удалены: каталог авто теперь
  // персистит CarCatalogRepository (car_catalog_*), см. _legacyKeys ниже —
  // если появится общий сборщик легаси-ключей. Старые значения безвредны.
  static const _autoRequestsKey = 'autoRequests';
  static const _requestDisplayOverridesKey = 'requestDisplayOverrides';
  static const _inspectorAboutKey = 'inspectorAbout';
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _notificationTokenKey = 'notificationToken';
  static const _lastSeenNotificationIdKey = 'notification.lastSeenId';
  static const _lastSeenNotificationCreatedAtKey =
      'notification.lastSeenCreatedAt';
  static const _userRoleKey = 'userRole';
  // Last-known effective RBAC permissions (Storage.GetPermissions). Cached
  // so the first frame after a cold start can gate UI by last-known rights
  // before the background refetch lands. Cleared on logout alongside tokens.
  static const _permissionsKey = 'userPermissions';
  // Email, ожидающий подтверждения через Storage.VerifyEmail.
  // Set когда пользователь сменил email через UpdateProfile, clear при
  // успешной верификации или logout. Local-only — backend пока не даёт
  // флаг isVerifyEmail в GetProfile, поэтому состояние «pending» живёт
  // тут. Переживает рестарт приложения.
  static const _pendingEmailVerifyKey = 'pendingEmailVerify';

  // Avatar profile photo как base64-JPEG. Local-only (backend пока без
  // upload-endpoint'а; есть только поле urlAvatar в GetProfile). Image
  // picker берёт фото из галереи/камеры → maxWidth 800 + quality 85,
  // base64encode → сюда. Очищается на logout вместе с токенами.
  static const _avatarBase64Key = 'avatarBase64';

  // Индекс preset-аватара (стилизованная авто-плитка из
  // kSparkAvatarPresets). Альтернатива base64-фото: юзер может выбрать
  // одну из 10 готовых иконок-на-фоне. Mutual exclusion с base64 — при
  // выборе фото preset чистится и наоборот.
  static const _avatarPresetIndexKey = 'avatarPresetIndex';

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
  // Company-only вкладка «Заявки» (4-я в shell) — список + создание
  // заявок на специалистов.
  static const sparkOnbCompanyRequestsKey = 'sparkOnb.companyRequests';

  static const List<String> sparkOnboardingKeys = <String>[
    sparkOnbReportsListKey,
    sparkOnbReportEditorKey,
    sparkOnbVinScannerKey,
    sparkOnbMediaStepKey,
    sparkOnbCommentAiKey,
    sparkOnbSummaryStepKey,
    sparkOnbStaffKey,
    sparkOnbAssignReportKey,
    sparkOnbCompanyRequestsKey,
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

  // setBrandCache/getBrandCache/getBrandRusCache/clearBrandCache удалены
  // вместе с миграцией фильтра ленты на CarCatalogRepository.

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

  // Auth tokens live in the OS secure store (iOS Keychain / Android
  // Keystore-backed), never in plaintext SharedPreferences. iOS items use
  // first_unlock_this_device: readable after first unlock, but never synced
  // to iCloud nor migrated to a new device. Legacy plaintext tokens written
  // before this change are moved into secure storage on first read.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // Jetpack EncryptedSharedPreferences вместо самодельной RSA/AES-обвязки
    // плагина: устойчивее к порче Keystore-ключа (частый источник исключений,
    // роняющих _writeToken в plaintext-фолбэк). Включено ДО первого
    // Android-релиза: сменить бэкенд позже = потерять сохранённые токены.
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Writes a token to secure storage; on failure falls back to plain
  /// SharedPreferences so the session still persists and the auth flow is
  /// never aborted by a storage hiccup. Notably web: flutter_secure_storage
  /// relies on SubtleCrypto and can throw on write — that must NOT break login
  /// (the backend Auth already succeeded). [_readTokenWithMigration] reads the
  /// plain copy back. A successful secure write erases any plain copy.
  ///
  /// Returns false when NEITHER store accepted the value: caller'ы, для
  /// которых важна долговечность (token refresh), не должны рапортовать
  /// success по факту вызова — только по подтверждённой записи.
  static Future<bool> _writeToken(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {
      try {
        return await (await _prefs()).setString(key, value);
      } catch (_) {
        return false;
      }
    }
    try {
      await (await _prefs()).remove(key);
    } catch (_) {
      // Легаси-копию стереть не удалось — перезапишем её свежим значением,
      // чтобы [_readTokenWithMigration] при сбое secure-ЧТЕНИЯ не воскресил
      // устаревший токен. Сам secure-write уже успешен — вердикт true.
      try {
        await (await _prefs()).setString(key, value);
      } catch (_) {}
    }
    return true;
  }

  /// Persists the auth token pair — refresh-токен ПЕРВЫМ. Если процесс
  /// умрёт между двумя записями, на диске останется «новый refresh +
  /// старый access» — безопасная комбинация (протухший access чинится
  /// очередным RefreshToken). Обратный порядок при ротации refresh на
  /// бэке оставил бы «новый access + мёртвый refresh» → разлогин, когда
  /// access истечёт. Returns true только когда записаны ОБА токена.
  static Future<bool> setAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final refreshOk = await _writeToken(_refreshTokenKey, refreshToken);
    final accessOk = await _writeToken(_accessTokenKey, accessToken);
    return refreshOk && accessOk;
  }

  static Future<String?> getAccessToken() =>
      _readTokenWithMigration(_accessTokenKey);

  static Future<String?> getRefreshToken() =>
      _readTokenWithMigration(_refreshTokenKey);

  /// Reads a token from secure storage, transparently migrating a legacy
  /// plaintext SharedPreferences value (written before the secure-storage
  /// switch) on first read and erasing the plaintext copy afterwards.
  static Future<String?> _readTokenWithMigration(String key) async {
    try {
      final secure = await _secure.read(key: key);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {
      // Keychain/Keystore hiccup — fall through to the legacy read.
    }
    final prefs = await _prefs();
    final legacy = prefs.getString(key);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _secure.write(key: key, value: legacy);
        await prefs.remove(key);
      } catch (_) {
        // Keep the plaintext value if the secure write fails so the session
        // survives; migration retries on the next read.
      }
      return legacy;
    }
    return null;
  }

  static Future<void> clearAuthTokens() async {
    final prefs = await _prefs();
    // Tokens now live in secure storage — clear it plus any legacy plaintext.
    try {
      await _secure.delete(key: _accessTokenKey);
      await _secure.delete(key: _refreshTokenKey);
      await _secure.delete(key: _notificationTokenKey);
    } catch (_) {
      // Best-effort; the legacy prefs removals below still run.
    }
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_notificationTokenKey);
    await prefs.remove(_lastSeenNotificationIdKey);
    await prefs.remove(_lastSeenNotificationCreatedAtKey);
    // RBAC permissions привязаны к юзеру — не должны утечь в следующего
    // на том же девайсе (иначе он увидел бы гейтинг по чужим правам).
    await prefs.remove(_permissionsKey);
    // Pending email verify тоже привязан к сессии пользователя — чтобы
    // banner из прошлого аккаунта не утёк в новый при logout/re-login.
    await prefs.remove(_pendingEmailVerifyKey);
    // Аватар привязан к юзеру (local-only) — не должен утечь в
    // следующего пользователя на том же девайсе.
    await prefs.remove(_avatarBase64Key);
    await prefs.remove(_avatarPresetIndexKey);
    // Profile snapshot (cache-as-seed для Spark Joy profile screen) —
    // содержит email/имя/телефон/companyName предыдущего юзера.
    // clearAuthTokens вызывается из storage_api.dart на путях
    // session-expiry (только при ЯВНОМ отказе сервера по refresh-токену;
    // транзиентные сетевые сбои токены не трогают); SparkJoyStorage
    // .logout() при этом
    // НЕ дёргается (только при ручном logout-кнопке в shell). Без
    // явной очистки тут новый юзер на том же девайсе увидел бы кеш
    // предыдущего до прихода первого GetProfile. Ключ держим в sync
    // с SparkJoyStorage._specialistProfileKey (не импортируем UI-слой
    // в data-слой ради избежания cycle).
    await prefs.remove('spark_joy_specialist_profile_v1');
  }

  static Future<void> setNotificationToken(String token) async {
    await _writeToken(_notificationTokenKey, token);
  }

  static Future<String?> getNotificationToken() =>
      _readTokenWithMigration(_notificationTokenKey);

  static Future<void> clearNotificationToken() async {
    try {
      await _secure.delete(key: _notificationTokenKey);
    } catch (_) {
      // Best-effort.
    }
    await (await _prefs()).remove(_notificationTokenKey);
  }

  static Future<void> setLastSeenNotification({
    required String id,
    required DateTime createdAt,
  }) async {
    final prefs = await _prefs();
    await prefs.setString(_lastSeenNotificationIdKey, id);
    await prefs.setString(
      _lastSeenNotificationCreatedAtKey,
      createdAt.toUtc().toIso8601String(),
    );
  }

  static Future<({String id, DateTime? createdAt})?>
  getLastSeenNotification() async {
    final prefs = await _prefs();
    final id = prefs.getString(_lastSeenNotificationIdKey);
    if (id == null || id.isEmpty) return null;
    final rawCreatedAt = prefs.getString(_lastSeenNotificationCreatedAtKey);
    return (
      id: id,
      createdAt: rawCreatedAt == null ? null : DateTime.tryParse(rawCreatedAt),
    );
  }

  static Future<void> clearLastSeenNotification() async {
    final prefs = await _prefs();
    await prefs.remove(_lastSeenNotificationIdKey);
    await prefs.remove(_lastSeenNotificationCreatedAtKey);
  }

  static Future<void> setUserRole(String role) async {
    await (await _prefs()).setString(_userRoleKey, role);
  }

  static Future<String?> getUserRole() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_userRoleKey);
  }

  /// Persists the user's effective RBAC permission slugs. Stored as a string
  /// list so the cold-start seed in [PermissionsController] is cheap.
  static Future<void> setPermissions(List<String> permissions) async {
    await (await _prefs()).setStringList(_permissionsKey, permissions);
  }

  static Future<List<String>> getPermissions() async {
    // ignore: await_only_futures
    return (await _prefs()).getStringList(_permissionsKey) ?? const <String>[];
  }

  static Future<void> clearPermissions() async {
    await (await _prefs()).remove(_permissionsKey);
  }

  /// Сохраняет email, который ожидает подтверждения через
  /// Storage.VerifyEmail. Передача null или пустой строки удаляет ключ —
  /// банер «⚠️ Не подтверждён» исчезает.
  static Future<void> setPendingEmailVerify(String? email) async {
    final prefs = await _prefs();
    if (email == null || email.trim().isEmpty) {
      await prefs.remove(_pendingEmailVerifyKey);
    } else {
      await prefs.setString(_pendingEmailVerifyKey, email.trim());
    }
  }

  static Future<String?> getPendingEmailVerify() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_pendingEmailVerifyKey);
  }

  /// Сохраняет аватар как base64-JPEG. null / пустая строка → удаляет
  /// ключ (равносильно clearAvatar). Размер строки ограничен только
  /// SharedPreferences-бэкендом (web localStorage ≥5 MB). Чистит
  /// preset-индекс — фото и preset взаимоисключающие.
  static Future<void> setAvatarBase64(String? base64) async {
    final prefs = await _prefs();
    await prefs.remove(_avatarPresetIndexKey);
    if (base64 == null || base64.isEmpty) {
      await prefs.remove(_avatarBase64Key);
    } else {
      await prefs.setString(_avatarBase64Key, base64);
    }
  }

  static Future<String?> getAvatarBase64() async {
    // ignore: await_only_futures
    return (await _prefs()).getString(_avatarBase64Key);
  }

  /// Сохраняет preset-индекс (0..N-1, см. kSparkAvatarPresets). null →
  /// удаляет ключ. Чистит base64 — preset и фото mutual exclusive.
  static Future<void> setAvatarPresetIndex(int? index) async {
    final prefs = await _prefs();
    await prefs.remove(_avatarBase64Key);
    if (index == null) {
      await prefs.remove(_avatarPresetIndexKey);
    } else {
      await prefs.setInt(_avatarPresetIndexKey, index);
    }
  }

  static Future<int?> getAvatarPresetIndex() async {
    // ignore: await_only_futures
    return (await _prefs()).getInt(_avatarPresetIndexKey);
  }

  /// Снести оба представления аватара (и фото, и preset). Используется
  /// в action-sheet'е «Удалить фото» в Профиле.
  static Future<void> clearAvatar() async {
    final prefs = await _prefs();
    await prefs.remove(_avatarBase64Key);
    await prefs.remove(_avatarPresetIndexKey);
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

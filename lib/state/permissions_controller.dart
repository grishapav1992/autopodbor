import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

/// Backend-driven RBAC state. Holds the current user's effective permission
/// slugs (`Storage.GetPermissions`) and reactively gates the UI.
///
/// A permission is a backend slug string — `edit_profile`, `edit_reports`,
/// `view_reports`, `manage_company`, `run_legal_review`, `edit_request`, … —
/// the same values returned by `Storage.GetPermissions` (see Doc). Gate the
/// UI with [can] / [canAny] inside an `Obx(...)`:
///
/// ```dart
/// final perms = Get.find<PermissionsController>();
/// Obx(() => perms.can('manage_company')
///     ? StaffTab()
///     : const SizedBox.shrink());
/// ```
///
/// Lifecycle: [seedFromCache] runs at app start for an instant first-frame
/// gate by last-known rights; [syncFromServer] refreshes from the backend in
/// the background (fired from the role-sync bootstrap) and the `RxList`
/// notifies observers so gated widgets rebuild when fresh rights arrive.
class PermissionsController extends GetxController {
  final RxList<String> _permissions = <String>[].obs;
  final RxString _role = ''.obs;
  final RxBool _loaded = false.obs;

  /// Immutable snapshot of the current permission slugs.
  List<String> get permissions => _permissions.toList(growable: false);

  /// Server-reported role accompanying the permissions (may differ in casing
  /// from the locally-cached role; informational).
  String get role => _role.value;

  /// True once permissions have been seeded from cache or fetched. Lets the
  /// UI distinguish "no rights" from "not loaded yet" if it needs to.
  bool get isLoaded => _loaded.value;

  /// Whether the user holds [permission].
  bool can(String permission) => _permissions.contains(permission);

  /// Whether the user holds at least one of [perms].
  bool canAny(Iterable<String> perms) => perms.any(_permissions.contains);

  /// Whether the user holds every one of [perms].
  bool canAll(Iterable<String> perms) => perms.every(_permissions.contains);

  /// Seeds state from the local cache (instant, no network). Call at app
  /// start so the first frame gates by last-known rights while
  /// [syncFromServer] is still in flight.
  Future<void> seedFromCache() async {
    final cached = await UserSimplePreferences.getPermissions();
    if (cached.isNotEmpty) {
      _permissions.assignAll(cached);
      _loaded.value = true;
    }
    final role = await UserSimplePreferences.getUserRole();
    if (role != null && role.isNotEmpty) _role.value = role;
  }

  /// Fetches `Storage.GetPermissions` and updates state + cache. On a network
  /// error the existing (seeded) state is left untouched — gating keeps
  /// working on last-known rights and the next successful sync corrects it.
  Future<void> syncFromServer({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final result = await StorageApi.getPermissions(timeout: timeout);
      final rawPerms = result['permissions'];
      final perms = <String>[];
      if (rawPerms is List) {
        for (final p in rawPerms) {
          final s = p?.toString().trim() ?? '';
          if (s.isNotEmpty) perms.add(s);
        }
      }
      _permissions.assignAll(perms);
      _role.value = (result['role'] ?? '').toString().trim();
      _loaded.value = true;
      await UserSimplePreferences.setPermissions(perms);
    } catch (e) {
      // Offline / transport error — keep the seeded cache. A 403 here would
      // be unusual (GetPermissions needs no specific right) but is equally
      // non-fatal: we just don't update.
      if (kDebugMode) {
        debugPrint('[permissions] GetPermissions sync failed: $e');
      }
    }
  }

  /// Clears all permission state (logout / user switch). The persisted cache
  /// is cleared separately in [UserSimplePreferences.clearAuthTokens].
  void clear() {
    _permissions.clear();
    _role.value = '';
    _loaded.value = false;
  }
}

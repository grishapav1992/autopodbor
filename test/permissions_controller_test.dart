import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/state/permissions_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();
  });

  group('PermissionsController gating (B1)', () {
    test('starts unloaded with no permissions', () {
      final c = PermissionsController();
      expect(c.isLoaded, isFalse);
      expect(c.permissions, isEmpty);
      expect(c.can('edit_reports'), isFalse);
    });

    test('seedFromCache loads persisted permissions + role', () async {
      await UserSimplePreferences.setPermissions(
        const ['edit_reports', 'view_reports', 'manage_company'],
      );
      await UserSimplePreferences.setUserRole('company');

      final c = PermissionsController();
      await c.seedFromCache();

      expect(c.isLoaded, isTrue);
      expect(c.role, 'company');
      expect(c.can('manage_company'), isTrue);
      expect(c.can('run_legal_review'), isFalse);
      expect(c.canAny(const ['run_legal_review', 'view_reports']), isTrue);
      expect(c.canAny(const ['run_legal_review', 'delete_request']), isFalse);
      expect(c.canAll(const ['edit_reports', 'view_reports']), isTrue);
      expect(c.canAll(const ['edit_reports', 'delete_request']), isFalse);
    });

    test('empty cache leaves controller unloaded', () async {
      final c = PermissionsController();
      await c.seedFromCache();
      expect(c.isLoaded, isFalse);
      expect(c.can('edit_profile'), isFalse);
    });

    test('clear resets all state', () async {
      await UserSimplePreferences.setPermissions(const ['edit_profile']);
      final c = PermissionsController();
      await c.seedFromCache();
      expect(c.can('edit_profile'), isTrue);

      c.clear();
      expect(c.can('edit_profile'), isFalse);
      expect(c.isLoaded, isFalse);
      expect(c.role, isEmpty);
    });

    test('clearAuthTokens wipes the persisted permission cache', () async {
      await UserSimplePreferences.setPermissions(const ['edit_reports']);
      expect(await UserSimplePreferences.getPermissions(), isNotEmpty);

      await UserSimplePreferences.clearAuthTokens();
      expect(await UserSimplePreferences.getPermissions(), isEmpty);
    });
  });
}

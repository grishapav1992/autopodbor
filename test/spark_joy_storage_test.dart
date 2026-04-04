import 'dart:convert';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_data.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();
  });

  group('SparkJoyStorage auth state', () {
    test('defaults to logged out specialist', () async {
      expect(await SparkJoyStorage.isLoggedIn(), isFalse);
      expect(await SparkJoyStorage.currentRole(), SparkJoyRole.specialist);
    });

    test('login/logout updates auth state', () async {
      await SparkJoyStorage.login(SparkJoyRole.company);
      expect(await SparkJoyStorage.isLoggedIn(), isTrue);
      expect(await SparkJoyStorage.currentRole(), SparkJoyRole.company);

      await SparkJoyStorage.logout();
      expect(await SparkJoyStorage.isLoggedIn(), isFalse);
    });
  });

  group('SparkJoyStorage drafts and completed', () {
    test('upsertDraft keeps latest version first and deduplicates by id', () async {
      await SparkJoyStorage.upsertDraft(<String, dynamic>{
        'id': 'd1',
        'name': 'Первый',
      });
      await SparkJoyStorage.upsertDraft(<String, dynamic>{
        'id': 'd2',
        'name': 'Второй',
      });
      await SparkJoyStorage.upsertDraft(<String, dynamic>{
        'id': 'd1',
        'name': 'Первый обновленный',
      });

      final drafts = await SparkJoyStorage.loadDrafts();
      expect(drafts.length, 2);
      expect(drafts.first['id'], 'd1');
      expect(drafts.first['name'], 'Первый обновленный');
      expect(drafts.last['id'], 'd2');
    });

    test('moveDraftToCompleted moves data atomically', () async {
      await SparkJoyStorage.upsertDraft(<String, dynamic>{
        'id': 'draft_42',
        'name': 'Черновик',
      });

      await SparkJoyStorage.moveDraftToCompleted(
        draftId: 'draft_42',
        completedReport: <String, dynamic>{
          'id': 'report_42',
          'name': 'Готовый отчет',
        },
      );

      final drafts = await SparkJoyStorage.loadDrafts();
      final completed = await SparkJoyStorage.loadCompleted();
      expect(drafts.where((d) => d['id'] == 'draft_42'), isEmpty);
      expect(completed.first['id'], 'report_42');
    });

    test('ensureSeedData removes only legacy seeded completed id', () async {
      final pref = UserSimplePreferences.pref!;
      await pref.setStringList('spark_joy_completed_v1', <String>[
        jsonEncode(<String, dynamic>{'id': 'spark_report_seed_1', 'name': 'old'}),
        jsonEncode(<String, dynamic>{'id': 'report_keep', 'name': 'keep'}),
      ]);

      await SparkJoyStorage.ensureSeedData();
      final completed = await SparkJoyStorage.loadCompleted();

      expect(completed.length, 1);
      expect(completed.first['id'], 'report_keep');
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_data.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Routes path_provider calls to a temp dir tree we control, so we can
/// prove logout wipes on-disk media. The platform interface returns paths
/// (strings); the plugin wraps them into Directory for the app.
class _MockPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _MockPathProvider(this.docsDir, this.cacheDir);

  final Directory docsDir;
  final Directory cacheDir;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsDir.path;

  @override
  Future<String?> getTemporaryPath() async => cacheDir.path;

  @override
  Future<String?> getApplicationCachePath() async => cacheDir.path;

  @override
  Future<String?> getApplicationSupportPath() async => docsDir.path;
}

void main() {
  late Directory tmpRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();
    tmpRoot = await Directory.systemTemp.createTemp('spark_joy_storage_test_');
  });

  tearDown(() async {
    if (await tmpRoot.exists()) {
      await tmpRoot.delete(recursive: true);
    }
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

    test('purgeDraftAfterUpload removes the draft', () async {
      await SparkJoyStorage.upsertDraft(<String, dynamic>{
        'id': 'draft_42',
        'name': 'Черновик',
      });

      await SparkJoyStorage.purgeDraftAfterUpload('draft_42');

      final drafts = await SparkJoyStorage.loadDrafts();
      expect(drafts.where((d) => d['id'] == 'draft_42'), isEmpty);
    });

    test('migrateLegacyKeys removes the old completed cache', () async {
      final pref = UserSimplePreferences.pref!;
      await pref.setStringList('spark_joy_completed_v1', <String>[
        jsonEncode(<String, dynamic>{'id': 'r1', 'name': 'old'}),
      ]);
      await pref.setString(
        'spark_joy_completed_synced_at_v1',
        '2026-04-20T12:00:00.000Z',
      );

      await SparkJoyStorage.migrateLegacyKeys();

      expect(pref.containsKey('spark_joy_completed_v1'), isFalse);
      expect(pref.containsKey('spark_joy_completed_synced_at_v1'), isFalse);
    });
  });

  group('SparkJoyStorage logout media purge', () {
    test('logout deletes on-disk inspection media and thumbnails', () async {
      final docs = Directory('${tmpRoot.path}/docs');
      final cache = Directory('${tmpRoot.path}/cache');
      await docs.create(recursive: true);
      await cache.create(recursive: true);

      // Pre-populate the two spark-owned subtrees exactly as the app does.
      final mediaDir = Directory(
        '${docs.path}/${SparkJoyStorage.mediaSubdirName}',
      );
      final thumbsDir = Directory(
        '${cache.path}/${SparkJoyStorage.thumbsSubdirName}',
      );
      await mediaDir.create(recursive: true);
      await thumbsDir.create(recursive: true);
      await File('${mediaDir.path}/vin_plate.jpg').writeAsBytes([1, 2, 3]);
      await File('${mediaDir.path}/interior.mp4').writeAsBytes([4, 5, 6]);
      await File('${thumbsDir.path}/preview.jpg').writeAsBytes([7, 8, 9]);
      expect(await mediaDir.exists(), isTrue);
      expect(await thumbsDir.exists(), isTrue);

      PathProviderPlatform.instance = _MockPathProvider(docs, cache);

      await SparkJoyStorage.login(SparkJoyRole.specialist);
      await SparkJoyStorage.logout();

      expect(await mediaDir.exists(), isFalse,
          reason: 'inspection media must be wiped on logout');
      expect(await thumbsDir.exists(), isFalse,
          reason: 'generated thumbnails must be wiped on logout');
    });
  });
}

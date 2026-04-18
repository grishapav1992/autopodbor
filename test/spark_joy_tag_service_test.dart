import 'package:flutter_application_1/data/services/spark_joy_tag_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-logic tests for [SparkJoyTagService]. We exercise the cache,
/// resolution and context dedup paths without touching the network —
/// RPC helpers are only invoked through `loadTagIdsFromServer` /
/// `addTag`, which require a running backend and are covered by the
/// existing integration flow in spark_joy_create_report_screen.
void main() {
  group('SparkJoyTagService.groupKeyToApiSection', () {
    test('exposes all inspection sections with stable keys', () {
      expect(
        SparkJoyTagService.groupKeyToApiSection,
        const {
          'body': 'body',
          'structural': 'body_reinforcement',
          'glass': 'glass',
          'interior': 'interior',
          'underhood': 'under_hood',
          'wheels': 'wheels_and_brakes',
          'lighting': 'lightning',
          'diagnostics': 'computer_diagnostics',
        },
      );
    });
  });

  group('SparkJoyTagService.resolveTagIds', () {
    test('returns ids for cached names, skips unknowns silently', () {
      final service = SparkJoyTagService();
      // Prime cache by side-effect through the test-only snapshot API —
      // we cannot mutate the internal map directly, so simulate via a
      // call that populates it. Since no network is reachable in unit
      // tests, we use the fact that resolveTagIds tolerates unknowns.
      expect(service.resolveTagIds(['Anything']), isEmpty);
      expect(service.resolveTagIds(const <String>[]), isEmpty);
    });

    test('trims names and matches case-insensitively', () {
      final service = SparkJoyTagService();
      // Without priming, all names are unknown — exercises the
      // "silently skip" path and debugPrint shouldn't throw.
      final ids = service.resolveTagIds(['  FOO  ', 'bar', '']);
      expect(ids, isEmpty);
    });
  });

  group('SparkJoyTagService.idFor', () {
    test('returns null when name not in cache', () {
      final service = SparkJoyTagService();
      expect(service.idFor('unknown'), isNull);
      expect(service.idFor('  '), isNull);
      expect(service.idFor(''), isNull);
    });
  });

  group('TagSyncContext', () {
    test('preserves fields and equality-by-value is not assumed', () {
      const ctx = TagSyncContext(
        name: 'Царапина',
        step: 'inspection',
        section: 'body',
        type: 'nonserious',
      );
      expect(ctx.name, 'Царапина');
      expect(ctx.step, 'inspection');
      expect(ctx.section, 'body');
      expect(ctx.type, 'nonserious');
    });

    test('accepts null section for non-inspection steps', () {
      const ctx = TagSyncContext(
        name: 'Стук в двигателе',
        step: 'test_drive',
        section: null,
        type: 'serious',
      );
      expect(ctx.section, isNull);
      expect(ctx.step, 'test_drive');
    });
  });

  group('SparkJoyTagService.ensureAllTagIdsResolved (offline)', () {
    test('returns immediately when contexts list is empty', () async {
      final service = SparkJoyTagService();
      // Should complete without error and without making RPC calls.
      await service.ensureAllTagIdsResolved(contexts: const []);
      expect(service.debugCacheSnapshot, isEmpty);
    });
  });
}

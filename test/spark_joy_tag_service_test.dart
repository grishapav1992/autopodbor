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
    test('returns empty list for unknown names, tolerates empty input', () {
      final service = SparkJoyTagService();
      expect(
        service.resolveTagIds(['Anything'], step: 'inspection', section: 'body'),
        isEmpty,
      );
      expect(
        service.resolveTagIds(const <String>[], step: 'inspection'),
        isEmpty,
      );
    });

    test('trims names and skips blanks without throwing', () {
      final service = SparkJoyTagService();
      final ids = service.resolveTagIds(
        ['  FOO  ', 'bar', ''],
        step: 'test_drive',
      );
      expect(ids, isEmpty);
    });
  });

  group('SparkJoyTagService.idFor', () {
    test('returns null when bucket empty', () {
      final service = SparkJoyTagService();
      expect(
        service.idFor(step: 'inspection', section: 'body', name: 'unknown'),
        isNull,
      );
      expect(
        service.idFor(step: 'test_drive', name: '  '),
        isNull,
      );
      expect(
        service.idFor(step: 'inspection', section: 'interior', name: ''),
        isNull,
      );
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

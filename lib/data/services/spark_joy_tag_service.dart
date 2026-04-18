import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;

/// Metadata required to create a missing user tag on the server in the
/// correct step / section / severity bucket.
///
/// See [SparkJoyTagService.ensureAllTagIdsResolved] for the workflow that
/// consumes these contexts.
class TagSyncContext {
  final String name;
  final String step;
  final String? section;
  final String type;

  const TagSyncContext({
    required this.name,
    required this.step,
    required this.section,
    required this.type,
  });
}

/// Client-side cache and RPC wrapper for the `Storage.GetUserTags` /
/// `Storage.AddUserTag` endpoints.
///
/// The service owns a name → server id map that the spark_joy report flow
/// uses to translate user-entered / selected tag names into the integer IDs
/// required by `Storage.PrepareSpecialistReport` (OpenRPC Doc changelog
/// 2026-04-15 switched tag payloads from `string[]` to `int[]`).
///
/// This class intentionally has no dependency on UI state: callers are
/// responsible for collecting the currently-selected tag context (media
/// state, test-drive lists, …) and passing it in via method parameters.
/// That keeps the service pure and trivially unit-testable.
class SparkJoyTagService {
  /// Name (normalized: trimmed + lowercased) → server-assigned tag ID.
  /// Populated by [loadTagIdsFromServer] and [addTag] / its wrappers.
  final Map<String, int> _tagNameToId = <String, int>{};

  /// Maps media group keys (`body`, `structural`, …) used in the spark_joy
  /// UI to the API `section` parameter the backend expects on the
  /// inspection step.
  static const Map<String, String> groupKeyToApiSection = {
    'body': 'body',
    'structural': 'body_reinforcement',
    'glass': 'glass',
    'interior': 'interior',
    'underhood': 'under_hood',
    'wheels': 'wheels_and_brakes',
    'lighting': 'lightning',
    'diagnostics': 'computer_diagnostics',
  };

  /// Returns the cached server ID for [tagName], or `null` if not known.
  int? idFor(String tagName) =>
      _tagNameToId[tagName.trim().toLowerCase()];

  /// Read-only view of the current name → id cache. Intended for tests.
  @visibleForTesting
  Map<String, int> get debugCacheSnapshot => Map.unmodifiable(_tagNameToId);

  /// Resolves [tagNames] to server integer IDs via the local cache. Unknown
  /// tags are silently skipped — they should have been created via [addTag]
  /// or [ensureAllTagIdsResolved] before this point.
  List<int> resolveTagIds(Iterable<String> tagNames) {
    final ids = <int>[];
    final missing = <String>[];
    for (final name in tagNames) {
      final trimmed = name.trim();
      final key = trimmed.toLowerCase();
      final id = _tagNameToId[key];
      if (id != null && id > 0) {
        ids.add(id);
      } else if (trimmed.isNotEmpty) {
        missing.add(trimmed);
      }
    }
    if (missing.isNotEmpty) {
      debugPrint('[TagSync] resolveTagIds unresolved: $missing');
    }
    return ids;
  }

  /// Fetches user tags from the server and populates the name → id cache.
  ///
  /// Per OpenRPC Doc, `Storage.GetUserTags` returns section-specific tags
  /// only when `section` is supplied for `step=inspection`. We therefore
  /// fan out:
  ///   • every inspection section explicitly (body, interior, …)
  ///   • a generic inspection request (section=null) for shared tags
  ///   • the test_drive step (no sections)
  ///
  /// Callers can pass already-selected tag IDs via
  /// [selectedInspectionIdsBySection] / [genericInspectionSelectedIds] /
  /// [testDriveSelectedIds] so the server sorts results by relevance and
  /// warms its co-occurrence stats for the next
  /// `PrepareSpecialistReport` call (changelog 2026-04-15).
  Future<void> loadTagIdsFromServer({
    Map<String, List<int>> selectedInspectionIdsBySection =
        const <String, List<int>>{},
    List<int> genericInspectionSelectedIds = const <int>[],
    List<int> testDriveSelectedIds = const <int>[],
  }) async {
    try {
      final futures = <Future<List<storage_api.UserTag>>>[
        storage_api.StorageApi.getUserTags(
          step: 'inspection',
          selectedTagIds: genericInspectionSelectedIds.isEmpty
              ? null
              : genericInspectionSelectedIds,
        ),
        storage_api.StorageApi.getUserTags(
          step: 'test_drive',
          selectedTagIds:
              testDriveSelectedIds.isEmpty ? null : testDriveSelectedIds,
        ),
        for (final section in groupKeyToApiSection.values)
          storage_api.StorageApi.getUserTags(
            step: 'inspection',
            section: section,
            selectedTagIds:
                selectedInspectionIdsBySection[section]?.isNotEmpty == true
                    ? selectedInspectionIdsBySection[section]
                    : null,
          ),
      ];
      final results = await Future.wait(futures);
      for (final tags in results) {
        for (final tag in tags) {
          final key = tag.name.trim().toLowerCase();
          if (key.isNotEmpty && tag.id > 0) {
            _tagNameToId[key] = tag.id;
          }
        }
      }
    } catch (_) {
      // Tags may not be available; payload builder falls back gracefully.
    }
  }

  /// Low-level create: calls `Storage.AddUserTag` and caches the result.
  ///
  /// [step] — `car`, `characteristics`, `document_reconciliation`,
  /// `legal_review`, `inspection`, `test_drive`, or `result`.
  /// [tagName] — the user-entered tag name (≤255 chars).
  /// [section] — only meaningful for `step=inspection`.
  /// [type] — `serious` or `nonserious`.
  ///
  /// Returns the server-assigned tag ID, or `null` on failure.
  Future<int?> addTag({
    required String step,
    required String tagName,
    String? section,
    String? type,
  }) async {
    final key = tagName.trim().toLowerCase();
    // Already cached — no need to call the server again.
    final existing = _tagNameToId[key];
    if (existing != null && existing > 0) return existing;

    try {
      final tag = await storage_api.StorageApi.addUserTag(
        step: step,
        name: tagName.trim(),
        section: section,
        type: type,
      );
      if (tag.id > 0) {
        _tagNameToId[key] = tag.id;
        return tag.id;
      }
    } catch (_) {
      // Best-effort: the tag will still be usable locally; it just won't
      // have an ID until the next loadTagIdsFromServer or retry.
    }
    return null;
  }

  /// Wrapper over [addTag] for the inspection editor. Maps a UI media group
  /// key to the matching API section via [groupKeyToApiSection].
  Future<int?> addInspectionTag({
    required String groupKey,
    required String tagName,
    required String severity,
  }) {
    return addTag(
      step: 'inspection',
      tagName: tagName,
      section: groupKeyToApiSection[groupKey],
      type: severity == 'serious' ? 'serious' : 'nonserious',
    );
  }

  /// Wrapper over [addTag] for the test-drive step (no section).
  Future<int?> addTestDriveTag({
    required String tagName,
    required String severity,
  }) {
    return addTag(
      step: 'test_drive',
      tagName: tagName,
      type: severity == 'serious' ? 'serious' : 'nonserious',
    );
  }

  /// Guarantees every context in [contexts] has a cached ID.
  ///
  /// Workflow:
  ///   1. Skip contexts whose tag name is already cached.
  ///   2. Refresh the cache from the server (another device / session may
  ///      have created the tag already).
  ///   3. For anything still missing, call [addTag] with the provided
  ///      step / section / type.
  ///
  /// Should be awaited once before building the final
  /// `Storage.PrepareSpecialistReport` payload.
  Future<void> ensureAllTagIdsResolved({
    required Iterable<TagSyncContext> contexts,
    Map<String, List<int>> selectedInspectionIdsBySection =
        const <String, List<int>>{},
    List<int> genericInspectionSelectedIds = const <int>[],
    List<int> testDriveSelectedIds = const <int>[],
  }) async {
    // Dedupe by normalized name + filter out already-cached entries.
    final pending = <String, TagSyncContext>{};
    for (final ctx in contexts) {
      final trimmed = ctx.name.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (_tagNameToId[key] != null) continue;
      pending.putIfAbsent(key, () => ctx);
    }

    if (pending.isEmpty) return;

    // First refresh from server (may have been updated elsewhere).
    await loadTagIdsFromServer(
      selectedInspectionIdsBySection: selectedInspectionIdsBySection,
      genericInspectionSelectedIds: genericInspectionSelectedIds,
      testDriveSelectedIds: testDriveSelectedIds,
    );

    for (final ctx in pending.values) {
      final key = ctx.name.toLowerCase();
      if (_tagNameToId[key] != null) continue;
      debugPrint(
        '[TagSync] creating tag: name="${ctx.name}" '
        'step=${ctx.step} section=${ctx.section} type=${ctx.type}',
      );
      await addTag(
        step: ctx.step,
        tagName: ctx.name,
        section: ctx.section,
        type: ctx.type,
      );
      final resolvedId = _tagNameToId[key];
      if (resolvedId == null || resolvedId <= 0) {
        debugPrint(
          '[TagSync] FAILED to resolve after create: name="${ctx.name}" '
          'step=${ctx.step} section=${ctx.section}',
        );
      }
    }
  }
}

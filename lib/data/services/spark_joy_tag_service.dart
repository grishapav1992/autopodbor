import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';

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
/// `Storage.AddUserTag` / `Storage.RemoveUserTag` endpoints.
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
  /// Composite key `"{step}|{section ?? ''}|{nameKey}"` → server-assigned
  /// tag ID. Populated by [loadTagIdsFromServer] and [addTag] / wrappers.
  ///
  /// Keying on `(step, section, name)` instead of just `name` prevents
  /// collisions when the same user-facing label exists in two different
  /// inspection sections (e.g. "царапина" in `body` and in `interior`
  /// have different server IDs and must not alias).
  final Map<String, int> _idByKey = <String, int>{};

  /// Builds the composite cache key. Normalizes name to
  /// `trim().toLowerCase()`. `section` is nullable — for steps without
  /// sections (car, test_drive, …) we store an empty string.
  ///
  /// Step is also normalized to the server's wire enum (`test_drive` →
  /// `testdrive`, `legal_review` → `legalreview`, `document_reconciliation`
  /// → `documentreconciliation`) so server responses (which use the
  /// concatenated form) and client-side calls (which use the readable
  /// form) land in the same bucket. Without this the `testdrive` entry
  /// the server writes on `GetUserTags` / `AddUserTag` wouldn't match a
  /// later `idFor(step: 'test_drive', …)` lookup and the upload path
  /// would send empty `testDriveXxxTags` arrays.
  static String _composeKey({
    required String step,
    String? section,
    required String name,
  }) {
    return '${_normalizeStep(step)}|${section ?? ''}|'
        '${name.trim().toLowerCase()}';
  }

  static String _normalizeStep(String step) {
    switch (step) {
      case 'test_drive':
        return 'testdrive';
      case 'legal_review':
        return 'legalreview';
      case 'document_reconciliation':
        return 'documentreconciliation';
      default:
        return step;
    }
  }

  /// Serializes every compound read-modify-write against the persisted
  /// pending-delete queue and the persisted tag catalog. Without this,
  /// two quick `removeInspectionTag` taps race at the `load → mutate →
  /// write` boundary and can lose queue entries; the same applies to
  /// [flushPendingDeletes] running while an enqueue is mid-flight.
  Future<void> _storageLock = Future<void>.value();

  Future<T> _withStorageLock<T>(Future<T> Function() op) {
    final prior = _storageLock;
    final gate = Completer<void>();
    _storageLock = gate.future;
    return prior.then((_) async {
      try {
        return await op();
      } finally {
        gate.complete();
      }
    });
  }

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

  /// Returns the cached server ID for a tag in the given step/section
  /// bucket, or `null` if not known. `section` is null for steps without
  /// sections (test_drive, car, …).
  int? idFor({
    required String step,
    String? section,
    required String name,
  }) => _idByKey[_composeKey(step: step, section: section, name: name)];

  /// Reverse lookup: given a server tag id, return the human-readable
  /// name. Used by the completed-report hydrator to turn `seriousDamageTags:
  /// [int]` from the server back into UI tag labels. Linear scan — the
  /// cache is small (hundreds, not thousands) so this is fine.
  String? nameForId(int id) {
    if (id <= 0) return null;
    for (final entry in _idByKey.entries) {
      if (entry.value != id) continue;
      final parts = entry.key.split('|');
      // Composite key is "step|section|name" — name is the last segment.
      if (parts.isEmpty) continue;
      return parts.last;
    }
    return null;
  }

  /// Returns every cached tag name (any bucket). Intended for the
  /// completed-report hydrator when matching display names and for tests.
  List<String> get allCachedNames => _idByKey.keys
      .map((key) => key.split('|').last)
      .toSet()
      .toList(growable: false);

  /// Read-only view of the current cache. Keys are the composite
  /// `"step|section|name"` format — see [_composeKey]. Intended for tests.
  @visibleForTesting
  Map<String, int> get debugCacheSnapshot => Map.unmodifiable(_idByKey);

  /// Resolves [tagNames] to server integer IDs within the given step /
  /// section bucket. Unknown tags are silently skipped — they should have
  /// been created via [addTag] or [ensureAllTagIdsResolved] first.
  List<int> resolveTagIds(
    Iterable<String> tagNames, {
    required String step,
    String? section,
  }) {
    final ids = <int>[];
    final missing = <String>[];
    for (final name in tagNames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      final id = _idByKey[_composeKey(
        step: step,
        section: section,
        name: trimmed,
      )];
      if (id != null && id > 0) {
        ids.add(id);
      } else {
        missing.add(trimmed);
      }
    }
    if (missing.isNotEmpty) {
      debugPrint(
        '[TagSync] resolveTagIds unresolved (step=$step section=$section): $missing',
      );
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
      // Deduplicate by id across section / generic fan-out results so we
      // don't persist the same tag multiple times.
      final byId = <int, storage_api.UserTag>{};
      for (final tags in results) {
        for (final tag in tags) {
          if (tag.id <= 0 || tag.name.trim().isEmpty) continue;
          // Each UserTag carries its own step + section; use them so
          // identical names in different sections remain distinct.
          final step = tag.step ?? 'inspection';
          _idByKey[_composeKey(
            step: step,
            section: tag.section,
            name: tag.name,
          )] = tag.id;
          byId[tag.id] = tag;
        }
      }
      await SparkJoyStorage.replaceUserTags(
        byId.values.map(_tagToMap).toList(growable: false),
      );
      // Fresh server catalog is loaded — a good time to drain any offline
      // deletions the user did in a previous session.
      await flushPendingDeletes();
    } catch (_) {
      // Tags may not be available (offline, server down). The persistent
      // cache populated on earlier runs is still in _tagNameToId after
      // [hydrateFromCache], so payload builder falls back gracefully.
    }
  }

  /// Loads the persisted tag catalog into [_idByKey]. Call once on
  /// screen init, before [loadTagIdsFromServer]. Makes offline tag-id
  /// resolution possible for reports saved earlier.
  Future<void> hydrateFromCache() async {
    final cached = await SparkJoyStorage.loadUserTags();
    for (final raw in cached) {
      final name = (raw['name'] ?? '').toString();
      if (name.trim().isEmpty) continue;
      final idRaw = raw['id'];
      final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
      if (id <= 0) continue;
      final step = (raw['step'] as String?) ?? 'inspection';
      final section = raw['section'] as String?;
      _idByKey[_composeKey(step: step, section: section, name: name)] = id;
    }
  }

  static Map<String, dynamic> _tagToMap(storage_api.UserTag tag) => {
    'id': tag.id,
    'name': tag.name,
    'slug': tag.slug,
    'step': tag.step,
    'section': tag.section,
    'type': tag.type,
    'createdAt': tag.createdAt,
  };

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
    final cacheKey = _composeKey(step: step, section: section, name: tagName);
    // Already cached for this exact bucket — no need to call the server.
    final existing = _idByKey[cacheKey];
    if (existing != null && existing > 0) return existing;

    try {
      final tag = await storage_api.StorageApi.addUserTag(
        step: step,
        name: tagName.trim(),
        section: section,
        type: type,
      );
      if (tag.id > 0) {
        _idByKey[cacheKey] = tag.id;
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

  /// Wrapper over `Storage.RemoveUserTag` for the inspection editor. Maps
  /// a UI media group key to the matching API section, resolves the tag
  /// name to its server id (querying the backend if the local cache misses),
  /// and evicts the cache entry on success. Backend rejects deletion of
  /// system tags (user_id = null), so callers should only invoke this for
  /// user-owned (custom) tags.
  ///
  /// On any failure (network down, id unresolved, RPC error) the intent is
  /// queued in [SparkJoyStorage.loadPendingTagDeletes] so [flushPendingDeletes]
  /// — called after the next successful [loadTagIdsFromServer] — can retry.
  Future<bool> removeInspectionTag({
    required String groupKey,
    required String tagName,
  }) async {
    final section = groupKeyToApiSection[groupKey];
    final cacheKey = _composeKey(
      step: 'inspection',
      section: section,
      name: tagName,
    );
    var id = _idByKey[cacheKey];
    if (id == null || id <= 0) {
      // Cache miss — tag was added optimistically in this session, or the
      // draft was reopened before loadTagIdsFromServer ran. Try to resolve
      // for just this section.
      try {
        final tags = await storage_api.StorageApi.getUserTags(
          step: 'inspection',
          section: section,
        );
        for (final tag in tags) {
          if (tag.id <= 0 || tag.name.trim().isEmpty) continue;
          _idByKey[_composeKey(
            step: tag.step ?? 'inspection',
            section: tag.section ?? section,
            name: tag.name,
          )] = tag.id;
        }
        id = _idByKey[cacheKey];
      } catch (_) {
        await _enqueuePendingDelete(name: tagName, section: section);
        return false;
      }
      if (id == null || id <= 0) {
        debugPrint(
          '[TagSync] removeInspectionTag: id not resolved for "$tagName" in section=$section — enqueued',
        );
        await _enqueuePendingDelete(name: tagName, section: section);
        return false;
      }
    }
    try {
      await storage_api.StorageApi.removeUserTag(
        id: id,
        step: 'inspection',
        section: section,
      );
      _idByKey.remove(cacheKey);
      await _persistCatalogSnapshot();
      return true;
    } catch (e) {
      debugPrint(
        '[TagSync] removeInspectionTag rpc failed for "$tagName" id=$id: $e — enqueued',
      );
      await _enqueuePendingDelete(name: tagName, section: section);
      return false;
    }
  }

  /// Adds a pending deletion so [flushPendingDeletes] can retry later.
  /// Dedupes by (nameKey, section). Serialized via [_withStorageLock] so
  /// rapid successive X-taps don't lose entries at the read-write gap.
  Future<void> _enqueuePendingDelete({
    required String name,
    required String? section,
  }) {
    return _withStorageLock(
      () => _enqueuePendingDeleteImpl(name: name, section: section),
    );
  }

  Future<void> _enqueuePendingDeleteImpl({
    required String name,
    required String? section,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final queue = await SparkJoyStorage.loadPendingTagDeletes();
    final key = normalized.toLowerCase();
    final deduped = queue.where((item) {
      final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
      final itemSection = item['section']?.toString();
      return !(itemName == key && itemSection == section);
    }).toList()
      ..add({
        'name': normalized,
        'step': 'inspection',
        'section': section,
      });
    await SparkJoyStorage.replacePendingTagDeletes(deduped);
  }

  /// Retries every queued pending deletion. Must be called **after** a
  /// successful [loadTagIdsFromServer] so the fresh server catalog has
  /// populated `_tagNameToId`; unresolved entries are then treated as
  /// phantoms (already gone on the server) and dropped from the queue.
  /// Failed RPCs (network / server error) stay queued for the next run.
  ///
  /// Re-entry safe via [_withStorageLock] — two overlapping
  /// `loadTagIdsFromServer` calls won't double-send RemoveUserTag for
  /// the same id.
  Future<void> flushPendingDeletes() {
    return _withStorageLock(_flushPendingDeletesImpl);
  }

  Future<void> _flushPendingDeletesImpl() async {
    final queue = await SparkJoyStorage.loadPendingTagDeletes();
    if (queue.isEmpty) return;
    final survivors = <Map<String, dynamic>>[];
    var mutated = false;
    for (final item in queue) {
      final name = (item['name'] ?? '').toString();
      final section = item['section']?.toString();
      final step = (item['step'] as String?) ?? 'inspection';
      final cacheKey = _composeKey(step: step, section: section, name: name);
      final id = _idByKey[cacheKey];
      if (id == null || id <= 0) {
        // Phantom: after a fresh sync the tag isn't on the server.
        // Either it was added + deleted entirely offline, or another
        // client already removed it. Drop the queue entry.
        debugPrint(
          '[TagSync] flushPendingDeletes: dropping phantom "$name" '
          '(step=$step section=$section)',
        );
        continue;
      }
      try {
        await storage_api.StorageApi.removeUserTag(
          id: id,
          step: step,
          section: section,
        );
        _idByKey.remove(cacheKey);
        mutated = true;
      } catch (e) {
        debugPrint(
          '[TagSync] flushPendingDeletes: failed "$name" id=$id: $e — keeping queued',
        );
        survivors.add(item);
      }
    }
    if (mutated) {
      await _persistCatalogSnapshotImpl();
    }
    if (survivors.length != queue.length) {
      await SparkJoyStorage.replacePendingTagDeletes(survivors);
    }
  }

  /// Rewrites the persisted catalog from the current in-memory map. Used
  /// after successful deletions so reopening the app doesn't resurrect
  /// the ghost tag from the last full-fan-out snapshot.
  Future<void> _persistCatalogSnapshot() {
    return _withStorageLock(_persistCatalogSnapshotImpl);
  }

  Future<void> _persistCatalogSnapshotImpl() async {
    final cached = await SparkJoyStorage.loadUserTags();
    final keepIds = _idByKey.values.toSet();
    final filtered = cached.where((raw) {
      final idRaw = raw['id'];
      final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
      return keepIds.contains(id);
    }).toList(growable: false);
    if (filtered.length != cached.length) {
      await SparkJoyStorage.replaceUserTags(filtered);
    }
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
    // Dedupe by composite key + filter out already-cached entries.
    final pending = <String, TagSyncContext>{};
    for (final ctx in contexts) {
      final trimmed = ctx.name.trim();
      if (trimmed.isEmpty) continue;
      final key = _composeKey(
        step: ctx.step,
        section: ctx.section,
        name: trimmed,
      );
      if (_idByKey[key] != null) continue;
      pending.putIfAbsent(key, () => ctx);
    }

    if (pending.isEmpty) return;

    // First refresh from server (may have been updated elsewhere).
    await loadTagIdsFromServer(
      selectedInspectionIdsBySection: selectedInspectionIdsBySection,
      genericInspectionSelectedIds: genericInspectionSelectedIds,
      testDriveSelectedIds: testDriveSelectedIds,
    );

    for (final entry in pending.entries) {
      final cacheKey = entry.key;
      final ctx = entry.value;
      if (_idByKey[cacheKey] != null) continue;
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
      final resolvedId = _idByKey[cacheKey];
      if (resolvedId == null || resolvedId <= 0) {
        debugPrint(
          '[TagSync] FAILED to resolve after create: name="${ctx.name}" '
          'step=${ctx.step} section=${ctx.section}',
        );
      }
    }
  }
}

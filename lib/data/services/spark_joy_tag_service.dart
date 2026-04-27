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

  /// Composite key (same shape as [_idByKey]) → owner user-id from
  /// `Storage.GetUserTags`. `null` for system / shared tags. Populated
  /// alongside [_idByKey] in [loadTagIdsFromServer] and on the
  /// [addTag] refetch. UI side reads this to gate the delete
  /// affordance — only user-owned tags can be removed via
  /// `Storage.RemoveUserTag`.
  final Map<String, int?> _userIdByKey = <String, int?>{};

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

  /// Returns true if the given (step, section, name) is owned by a
  /// user (`userId != null` in the server's `GetUserTags` response).
  /// False for system / shared tags. Returns false when the tag isn't
  /// in the cache yet (defensive — no UI delete-affordance until we
  /// know it's safe to remove).
  bool isCustomTag({
    required String step,
    String? section,
    required String name,
  }) {
    final userId =
        _userIdByKey[_composeKey(step: step, section: section, name: name)];
    return userId != null;
  }

  /// Snapshots the current user's custom inspection tags grouped by
  /// the UI media group key (`body`, `glass`, `interior`, …). Used to
  /// seed `_mediaCustomTagsByScope` after a server refresh so tags
  /// created in earlier sessions render with a delete affordance.
  ///
  /// Each value is a list of `(name, isSerious)` tuples; the caller
  /// splits these into name + serious-name maps that match the
  /// editor's existing scope-keyed shape.
  Map<String, List<({String name, bool isSerious})>>
      customInspectionTagsByGroupKey() {
    final reverse = <String, String>{
      for (final e in groupKeyToApiSection.entries) e.value: e.key,
    };
    final out = <String, List<({String name, bool isSerious})>>{};
    for (final tag in _lastSnapshot) {
      if (!tag.isCustom) continue;
      final step = tag.step ?? 'inspection';
      if (step != 'inspection') continue;
      final section = tag.section;
      if (section == null) continue;
      final groupKey = reverse[section];
      if (groupKey == null) continue;
      out.putIfAbsent(groupKey, () => []).add((
        name: tag.name,
        isSerious: tag.isSerious,
      ));
    }
    return out;
  }

  /// Last server snapshot of every user-visible tag — kept so the
  /// helpers above can answer "is this custom?" / "what severity?" /
  /// "what's the cased display name?" without re-walking the cache
  /// keys.
  List<storage_api.UserTag> _lastSnapshot = const <storage_api.UserTag>[];

  /// Symmetric eviction helper. Removing a tag has to clear three
  /// in-memory tracks at once or stale entries linger:
  ///   - [_idByKey] (composite key → server id)
  ///   - [_userIdByKey] (composite key → owner)
  ///   - [_lastSnapshot] (ordered list used by [customInspectionTagsByGroupKey])
  /// Without this the deleted tag keeps getting re-seeded into
  /// `_mediaCustomTagsByScope` on the next refresh, even though the
  /// server has dropped it.
  void _evictTagByKey(String cacheKey) {
    final id = _idByKey.remove(cacheKey);
    _userIdByKey.remove(cacheKey);
    if (id != null && _lastSnapshot.any((t) => t.id == id)) {
      _lastSnapshot = _lastSnapshot
          .where((t) => t.id != id)
          .toList(growable: false);
    }
  }

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
          final key = _composeKey(
            step: step,
            section: tag.section,
            name: tag.name,
          );
          _idByKey[key] = tag.id;
          _userIdByKey[key] = tag.userId;
          byId[tag.id] = tag;
        }
      }
      _lastSnapshot = byId.values.toList(growable: false);
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
    final restored = <storage_api.UserTag>[];
    for (final raw in cached) {
      final name = (raw['name'] ?? '').toString();
      if (name.trim().isEmpty) continue;
      final idRaw = raw['id'];
      final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
      if (id <= 0) continue;
      final step = (raw['step'] as String?) ?? 'inspection';
      final section = raw['section'] as String?;
      final userIdRaw = raw['userId'];
      final userId = userIdRaw is int
          ? userIdRaw
          : (userIdRaw is num ? userIdRaw.toInt() : int.tryParse('${userIdRaw ?? ''}'));
      final key = _composeKey(step: step, section: section, name: name);
      _idByKey[key] = id;
      _userIdByKey[key] = userId;
      restored.add(
        storage_api.UserTag(
          id: id,
          name: name,
          slug: (raw['slug'] ?? '').toString(),
          type: storage_api.UserTagType.normalize(raw['type']),
          step: step,
          section: section,
          createdAt: raw['createdAt']?.toString(),
          userId: userId,
        ),
      );
    }
    _lastSnapshot = restored;
  }

  static Map<String, dynamic> _tagToMap(storage_api.UserTag tag) => {
    'id': tag.id,
    'name': tag.name,
    'slug': tag.slug,
    'step': tag.step,
    'section': tag.section,
    // Persist the canonical wire form so older caches written with
    // `nonserious` / null stay readable after UserTagType.normalize
    // on the way back in (hydrateFromCache).
    'type': tag.type.wireName,
    'createdAt': tag.createdAt,
    'userId': tag.userId,
  };

  /// Low-level create: calls `Storage.AddUserTag` and caches the result.
  ///
  /// [step] — `car`, `characteristics`, `document_reconciliation`,
  /// `legal_review`, `inspection`, `test_drive`, or `result`.
  /// [tagName] — the user-entered tag name (≤255 chars).
  /// [section] — only meaningful for `step=inspection`.
  /// [type] — domain severity; defaults to [UserTagType.nonSerious].
  /// Accepts any form [UserTagType.normalize] understands.
  ///
  /// Returns the server-assigned tag ID, or `null` on failure.
  Future<int?> addTag({
    required String step,
    required String tagName,
    String? section,
    Object? type,
  }) async {
    final cacheKey = _composeKey(step: step, section: section, name: tagName);
    // Already cached for this exact bucket — no need to call the server.
    final existing = _idByKey[cacheKey];
    if (existing != null && existing > 0) return existing;

    final normalizedName = tagName.trim().toLowerCase();
    try {
      // По указанию backend dev'а: AddUserTag возвращает только ack
      // (`result: []`, без id). Чтобы получить id свежесозданного
      // тега, нужно сразу после AddUserTag дёрнуть GetUserTags для
      // того же step/section и найти тег по имени. Делаем это всегда —
      // даже если AddUserTag упал с validation error: refetch вернёт
      // canonical-список, кэш обновится, для других тегов будет
      // полезно. Если матча не нашли — возвращаем null, caller
      // обрабатывает как «id пока не известен».
      try {
        await storage_api.StorageApi.addUserTag(
          step: step,
          name: tagName.trim(),
          section: section,
          type: type,
        );
      } catch (_) {
        // Игнорируем — refetch ниже всё равно делается.
      }

      final tags = await storage_api.StorageApi.getUserTags(
        step: step,
        section: section,
      );
      int? matchedId;
      for (final t in tags) {
        if (t.id <= 0 || t.name.trim().isEmpty) continue;
        final tagSection = t.section ?? section;
        // Кэшируем все теги пока тут — getUserTags возвращает полный
        // список для bucket'а, грех не воспользоваться.
        final key = _composeKey(
          step: t.step ?? step,
          section: tagSection,
          name: t.name,
        );
        _idByKey[key] = t.id;
        _userIdByKey[key] = t.userId;
        if (t.name.trim().toLowerCase() == normalizedName) {
          matchedId = t.id;
        }
      }
      return matchedId;
    } catch (_) {
      // Network / parse failure. Tag usable locally; id появится при
      // следующем loadTagIdsFromServer или retry.
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
      type: storage_api.UserTagType.normalize(severity),
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
      type: storage_api.UserTagType.normalize(severity),
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
        await _enqueuePendingDelete(
          name: tagName,
          step: 'inspection',
          section: section,
        );
        return false;
      }
      if (id == null || id <= 0) {
        debugPrint(
          '[TagSync] removeInspectionTag: id not resolved for "$tagName" in section=$section — enqueued',
        );
        await _enqueuePendingDelete(
          name: tagName,
          step: 'inspection',
          section: section,
        );
        return false;
      }
    }
    try {
      await storage_api.StorageApi.removeUserTag(
        id: id,
        step: 'inspection',
        section: section,
      );
      _evictTagByKey(cacheKey);
      await _persistCatalogSnapshot();
      return true;
    } catch (e) {
      debugPrint(
        '[TagSync] removeInspectionTag rpc failed for "$tagName" id=$id: $e — enqueued',
      );
      await _enqueuePendingDelete(
        name: tagName,
        step: 'inspection',
        section: section,
      );
      return false;
    }
  }

  /// Symmetric counterpart to [removeInspectionTag] for the
  /// test-drive step. Test-drive tags have no section — the cache key
  /// uses `step='test_drive'` and a null section. Otherwise the
  /// resolve-id-or-enqueue flow mirrors the inspection path.
  Future<bool> removeTestDriveTag({
    required String tagName,
  }) async {
    final cacheKey = _composeKey(
      step: 'test_drive',
      section: null,
      name: tagName,
    );
    var id = _idByKey[cacheKey];
    if (id == null || id <= 0) {
      try {
        final tags = await storage_api.StorageApi.getUserTags(
          step: 'test_drive',
        );
        for (final tag in tags) {
          if (tag.id <= 0 || tag.name.trim().isEmpty) continue;
          _idByKey[_composeKey(
            step: tag.step ?? 'test_drive',
            section: tag.section,
            name: tag.name,
          )] = tag.id;
        }
        id = _idByKey[cacheKey];
      } catch (_) {
        await _enqueuePendingDelete(
          name: tagName,
          step: 'test_drive',
          section: null,
        );
        return false;
      }
      if (id == null || id <= 0) {
        debugPrint(
          '[TagSync] removeTestDriveTag: id not resolved for "$tagName" — enqueued',
        );
        await _enqueuePendingDelete(
          name: tagName,
          step: 'test_drive',
          section: null,
        );
        return false;
      }
    }
    try {
      await storage_api.StorageApi.removeUserTag(
        id: id,
        step: 'test_drive',
      );
      _evictTagByKey(cacheKey);
      await _persistCatalogSnapshot();
      return true;
    } catch (e) {
      debugPrint(
        '[TagSync] removeTestDriveTag rpc failed for "$tagName" id=$id: $e — enqueued',
      );
      await _enqueuePendingDelete(
        name: tagName,
        step: 'test_drive',
        section: null,
      );
      return false;
    }
  }

  /// Adds a pending deletion so [flushPendingDeletes] can retry later.
  /// Dedupes by (nameKey, step, section). Serialized via
  /// [_withStorageLock] so rapid successive X-taps don't lose entries
  /// at the read-write gap.
  Future<void> _enqueuePendingDelete({
    required String name,
    required String step,
    required String? section,
  }) {
    return _withStorageLock(
      () => _enqueuePendingDeleteImpl(
        name: name,
        step: step,
        section: section,
      ),
    );
  }

  Future<void> _enqueuePendingDeleteImpl({
    required String name,
    required String step,
    required String? section,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final queue = await SparkJoyStorage.loadPendingTagDeletes();
    final key = normalized.toLowerCase();
    final deduped = queue.where((item) {
      final itemName = (item['name'] ?? '').toString().trim().toLowerCase();
      final itemStep = (item['step'] as String?) ?? 'inspection';
      final itemSection = item['section']?.toString();
      return !(itemName == key && itemStep == step && itemSection == section);
    }).toList()
      ..add({
        'name': normalized,
        'step': step,
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
        _evictTagByKey(cacheKey);
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

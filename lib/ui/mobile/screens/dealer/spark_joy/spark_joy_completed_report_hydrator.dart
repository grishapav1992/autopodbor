import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/services/spark_joy_tag_service.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';

/// Transforms a `Storage.ViewSpecialistReport` response into the flat
/// draft-shape map the `SparkJoyCreateReportScreen` editor reads.
///
/// The editor state hydration ([_SparkJoyCreateReportScreenState._loadDraftIntoState]
/// + [_initMediaState]) expects ~50 flat keys (`vin`, `plate`, `mileage`, …)
/// plus a `mediaGroupsState` map built from `UploadedItem` JSON. Server
/// returns everything nested under `carStep / characteristicsStep /
/// documentReconciliationStep / inspectionStep / testDriveStep /
/// resultStep / legalReviewStep`. This hydrator does the mapping and also
/// resolves presigned view URLs for every file referenced in the report.
///
/// Usage:
/// ```dart
/// final server = await StorageApi.viewSpecialistReport(reportId: id);
/// final draft = await hydrateCompletedReport(
///   server: server,
///   tagService: tagService,
/// );
/// Navigator.push(..., SparkJoyCreateReportScreen(draft: draft, readOnly: true));
/// ```
///
/// Note: `StorageApi.viewSpecialistReport` already calls
/// `_normalizeSpecialistReportMap` before returning, so top-level flat
/// fields (`vin`, `plate`, `inspectionCity`, `docsOwnerMatch`, …) are
/// present before we get here. This hydrator fills in the big missing
/// pieces: `mediaGroupsState`, `legalFiles`, test-drive tag names, and
/// rewrites every file reference's source URL to a presigned GET URL.
Future<Map<String, dynamic>> hydrateCompletedReport({
  required Map<String, dynamic> server,
  required SparkJoyTagService tagService,
}) async {
  final reportNumber = (server['reportNumber'] ?? '').toString().trim();
  final inspectionStep = _asMap(server['inspectionStep']);
  final testDriveStep = _asMap(server['testDriveStep']);
  final legalReviewStep = _asMap(server['legalReviewStep']);
  final characteristicsStep = _asMap(server['characteristicsStep']);
  if (reportNumber.isEmpty) {
    debugPrint(
      '[CompletedReportHydrator] reportNumber missing — media URLs '
      'cannot be resolved; view will render without images.',
    );
  }

  // Completed reports normally return tags as embedded `{id, name}` objects.
  // Warm the local catalog, then hit Storage.GetUserTags only for legacy bare
  // IDs that still need name lookup. The regular editor intentionally warms
  // every inspection section; read-only completed reports must not fan out
  // into section-wide suggestion requests.
  await tagService.hydrateFromCache();
  try {
    final selectedInspectionIds = _collectMissingInspectionTagIdsBySection(
      inspectionStep,
      tagService,
    );
    final testDriveIds = _collectMissingTestDriveTagIds(
      testDriveStep,
      tagService,
    );
    if (selectedInspectionIds.isNotEmpty || testDriveIds.isNotEmpty) {
      await tagService.loadTagIdsFromServer(
        selectedInspectionIdsBySection: selectedInspectionIds,
        testDriveSelectedIds: testDriveIds,
        inspectionSections: selectedInspectionIds.keys,
        includeGenericInspection: false,
        includeTestDrive: testDriveIds.isNotEmpty,
      );
    }
  } catch (e) {
    debugPrint(
      '[CompletedReportHydrator] GetUserTags failed for completed report: $e',
    );
  }

  // 1. Walk every file-bearing node, collect filenames (unique).
  final filenames = <String>{};
  for (final key in _inspectionArrayKeys.keys) {
    final list = inspectionStep[key];
    if (list is! List) continue;
    for (final raw in list) {
      if (raw is! Map) continue;
      final file = _asMap(raw['file']);
      final name = (file['filename'] ?? '').toString().trim();
      if (name.isNotEmpty) filenames.add(name);
      // Audio notes live alongside the photo/video as plain filenames
      // (`voice_memo_1.m4a`). They go to S3 under the same report and
      // need presigned GET URLs too — the lightbox player otherwise
      // calls UrlSource() with a bare filename and silently fails.
      final rawAudio = raw['audioNotes'];
      if (rawAudio is List) {
        for (final audio in rawAudio) {
          final audioName = audio?.toString().trim() ?? '';
          if (audioName.isNotEmpty) filenames.add(audioName);
        }
      }
    }
  }
  _collectLegalFilenames(legalReviewStep, filenames);

  // Listing PDF (snapshot of the ad) lives in S3 by key under the carStep —
  // surfaced as `listingPdfFile` by _normalizeSpecialistReportMap. Resolve
  // it to a presigned view URL alongside the media (B14).
  final listingPdfFile = (server['listingPdfFile'] ?? '').toString().trim();
  if (listingPdfFile.isNotEmpty) filenames.add(listingPdfFile);

  // 2. Batch-resolve URLs (concurrency-limited).
  final urls = reportNumber.isEmpty || filenames.isEmpty
      ? const <String, String>{}
      : await storage_api.StorageApi.getTemporaryViewUrlsBatch(
          reportNumber: reportNumber,
          filenames: filenames,
        );
  if (filenames.isNotEmpty && urls.length != filenames.length) {
    debugPrint(
      '[CompletedReportHydrator] ${filenames.length - urls.length} of '
      '${filenames.length} view URLs failed to resolve — those files '
      'will render as missing.',
    );
  }

  // 3. Build mediaGroupsState (keyed by editor's groupKey).
  final mediaGroupsState = <String, dynamic>{};
  for (final entry in _inspectionArrayKeys.entries) {
    final serverKey = entry.key;
    final groupKey = entry.value.groupKey;
    final list = inspectionStep[serverKey];
    if (list is! List) continue;
    final files = <Map<String, dynamic>>[];
    var hasIssue = false;
    for (final raw in list) {
      if (raw is! Map) continue;
      final item = _elementToUploadedItemJson(
        raw,
        groupKey: groupKey,
        urls: urls,
        tagService: tagService,
      );
      if (item == null) continue;
      files.add(item);
      final inspection = _asMap(item['inspection']);
      final noDamage = inspection['noDamage'];
      if (noDamage is bool && !noDamage) hasIssue = true;
    }
    if (files.isEmpty) continue;
    mediaGroupsState[groupKey] = <String, dynamic>{
      'hasIssue': hasIssue,
      'note': '',
      'rawUrls': '',
      'files': files,
      'partInspection': const <String, dynamic>{},
    };
  }

  // 4. Legal files list.
  final legalFiles = _buildLegalFiles(legalReviewStep, urls: urls);

  // 4b. ApiCloud legal-review check results (B2) — для рендера материалов
  // проверок в разделе «Материалы проверки» при in-app просмотре отчёта.
  final legalCheckResults = await _buildLegalCheckResults(legalReviewStep);
  final legalBatchIds = legalReviewStep['batchIds'];
  final legalBatchNumber = (legalBatchIds is List && legalBatchIds.isNotEmpty)
      ? legalBatchIds.first.toString().trim()
      : '';

  // 5. Test-drive tag names.
  final tdEngineTags = _resolveTagNames(
    testDriveStep['testDriveEngineTags'],
    tagService,
  );
  final tdGearboxTags = _resolveTagNames(
    testDriveStep['testDriveTransmissionTags'],
    tagService,
  );
  final tdSteeringTags = _resolveTagNames(
    testDriveStep['testDriveSteeringWheelTags'],
    tagService,
  );
  final tdRideTags = _resolveTagNames(
    testDriveStep['testDriveSuspensionInDriveTags'],
    tagService,
  );
  final tdBrakeTags = _resolveTagNames(
    testDriveStep['testDriveBrakesInDriveTags'],
    tagService,
  );

  // 6. Resolve brand/model/generation/restyling/photoUrl from the
  //    local frame catalog (populated by car picker selections). A
  //    cache miss is expected on fresh installs or reports from
  //    other users — the editor then renders placeholders.
  final frameIdRaw = characteristicsStep['modelGenerationRestylingFrameId'];
  final frameId = frameIdRaw is int
      ? frameIdRaw
      : (frameIdRaw is num
            ? frameIdRaw.toInt()
            : int.tryParse('${frameIdRaw ?? ''}'));
  final frameMeta = (frameId != null && frameId > 0)
      ? await SparkJoyStorage.loadFrameCatalogEntry(frameId)
      : null;

  // 7. Merge back into a single flat draft-shape map.
  //
  // Note on expertConclusionTouched: the draft-time flag gates whether
  // _normalizeInitialExpertConclusion returns the stored text or an
  // empty string (the editor uses it to distinguish auto-generated
  // placeholder vs. user input). For a completed report the text that
  // came back from the server IS the user's own conclusion, so we pin
  // the touched flag to `true` — otherwise read-only summary shows
  // "Заключение не указано" even when the real value is present.
  final serverExpert = (server['expertConclusion'] ?? '').toString().trim();
  final listingPdfUrl = listingPdfFile.isEmpty
      ? ''
      : (urls[listingPdfFile] ?? '');
  final draft = <String, dynamic>{
    ...server,
    if (frameMeta != null) ..._frameMetaToDraftKeys(frameMeta),
    if (frameId != null && frameId > 0)
      'modelGenerationRestylingFrameId': frameId,
    if (listingPdfUrl.isNotEmpty) 'listingPdfUrl': listingPdfUrl,
    if (serverExpert.isNotEmpty) 'expertConclusionTouched': true,
    'mediaGroupsState': mediaGroupsState,
    if (legalFiles.isNotEmpty) 'legalFiles': legalFiles,
    if (legalCheckResults.isNotEmpty) 'legalCheckResults': legalCheckResults,
    if (legalCheckResults.isNotEmpty) 'legalLoaded': true,
    if (legalBatchNumber.isNotEmpty) 'legalBatchNumber': legalBatchNumber,
    'tdEngineTags': tdEngineTags,
    'tdGearboxTags': tdGearboxTags,
    'tdSteeringTags': tdSteeringTags,
    'tdRideTags': tdRideTags,
    'tdBrakeTags': tdBrakeTags,
    // Completed reports are never drafts — pin for clarity.
    'isDraft': false,
  };
  return draft;
}

Map<String, dynamic> _frameMetaToDraftKeys(Map<String, dynamic> meta) {
  final out = <String, dynamic>{};
  void put(String draftKey, String metaKey) {
    final value = (meta[metaKey] ?? '').toString().trim();
    if (value.isNotEmpty) out[draftKey] = value;
  }

  put('brand', 'brand');
  put('model', 'model');
  put('generation', 'generation');
  put('restyling', 'restyling');
  put('carPhotoUrl', 'photoUrl');
  put('carFrames', 'frames');
  return out;
}

/// Maps a server inspection-element `{id, elementType, file:{filename,
/// type}, noDamage, seriousDamageTags, noSeriousDamageTags, note,
/// audioNotes, paintworkThicknessFrom, paintworkThicknessTo}` to the
/// editor's UploadedItem JSON shape.
Map<String, dynamic>? _elementToUploadedItemJson(
  Map raw, {
  required String groupKey,
  required Map<String, String> urls,
  required SparkJoyTagService tagService,
}) {
  final file = _asMap(raw['file']);
  final filename = (file['filename'] ?? '').toString().trim();
  if (filename.isEmpty) return null;
  final serverType = (file['type'] ?? '').toString();
  final mimeType = _mimeTypeFromServer(
    serverType: serverType,
    filename: filename,
  );
  final dataUrl = urls[filename] ?? '';

  final tags = <String>[
    ..._resolveTagNames(raw['seriousDamageTags'], tagService),
    ..._resolveTagNames(raw['noSeriousDamageTags'], tagService),
  ];

  final audioFilenames = _asStringList(raw['audioNotes']);
  // Replace filenames with presigned view URLs where available so the
  // AudioPlayer source lands on a real HTTP endpoint. Missing entries
  // are dropped instead of leaving a dead filename behind — the UI
  // would otherwise show a play button that silently fails.
  final audioRecordings = <String>[
    for (final name in audioFilenames)
      if ((urls[name] ?? '').isNotEmpty) urls[name]!,
  ];

  final paintFromRaw = raw['paintworkThicknessFrom'];
  final paintToRaw = raw['paintworkThicknessTo'];
  final paintFrom = paintFromRaw is num ? paintFromRaw.toDouble() : null;
  final paintTo = paintToRaw is num ? paintToRaw.toDouble() : null;
  final elementId = raw['id']?.toString();

  return <String, dynamic>{
    'id': '${groupKey}_${elementId ?? filename}',
    'name': filename,
    'mimeType': mimeType,
    'dataUrl': dataUrl,
    'inspection': <String, dynamic>{
      'noDamage': raw['noDamage'] == true,
      'tags': tags,
      'note': (raw['note'] ?? '').toString(),
      'elementType': raw['elementType']?.toString(),
      'audioRecordings': audioRecordings,
      'paintFrom': paintFrom,
      'paintTo': paintTo,
      'isDraft': false,
    },
  };
}

void _collectLegalFilenames(Map legalStep, Set<String> out) {
  final other = legalStep['otherLegalReviews'];
  if (other is List) {
    for (final raw in other) {
      if (raw is! Map) continue;
      final name = (raw['filename'] ?? '').toString().trim();
      if (name.isNotEmpty) out.add(name);
    }
  }
  final legalReview = _asMap(legalStep['legalReview']);
  final lrFiles = legalReview['files'];
  if (lrFiles is List) {
    for (final raw in lrFiles) {
      if (raw is! Map) continue;
      final name = (raw['filename'] ?? '').toString().trim();
      if (name.isNotEmpty) out.add(name);
    }
  }
  final legalFiles = legalStep['files'];
  if (legalFiles is List) {
    for (final raw in legalFiles) {
      if (raw is! Map) continue;
      final name = (raw['filename'] ?? '').toString().trim();
      if (name.isNotEmpty) out.add(name);
    }
  }
}

/// Извлекает результаты ApiCloud-проверок из `legalReviewStep` для рендера
/// в разделе «Материалы проверки» завершённого отчёта. Источник зависит от
/// формы ответа `ViewSpecialistReport` (подтвердить live):
///   (а) встроенный массив проверок под одним из ожидаемых ключей;
///   (б) иначе — дотянуть по `legalReviewStepId`, затем по `batchIds`, через
///       getLegalReviewChecks / getBatchLegalReviewResults.
/// Возвращаемый формат совпадает с тем, что рендерит редактор
/// (`checkType` / `status` / `responseNormalized`).
Future<List<Map<String, dynamic>>> _buildLegalCheckResults(
  Map<String, dynamic> legalStep,
) async {
  List<Map<String, dynamic>> asMapList(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  // (а) встроенные результаты.
  for (final key in const [
    'checks',
    'legalReviewChecks',
    'batchChecks',
    'results',
    'legalChecks',
  ]) {
    final embedded = asMapList(legalStep[key]);
    if (embedded.isNotEmpty) return embedded;
  }

  // (б) дотянуть по stepId, затем по batchIds.
  try {
    final stepIdRaw = legalStep['legalReviewStepId'] ?? legalStep['id'];
    final stepId = stepIdRaw is int
        ? stepIdRaw
        : int.tryParse('${stepIdRaw ?? ''}');
    if (stepId != null && stepId > 0) {
      final res = await storage_api.StorageApi.getLegalReviewChecks(
        legalReviewStepId: stepId,
        limit: 100,
      );
      final byStep = asMapList(res['checks']);
      if (byStep.isNotEmpty) return byStep;
    }
    final batchIds = legalStep['batchIds'];
    if (batchIds is List && batchIds.isNotEmpty) {
      final batchNumber = batchIds.first.toString().trim();
      if (batchNumber.isNotEmpty) {
        final res = await storage_api.StorageApi.getBatchLegalReviewResults(
          batchNumber: batchNumber,
        );
        final byBatch = asMapList(res['checks']);
        if (byBatch.isNotEmpty) return byBatch;
      }
    }
  } catch (e) {
    debugPrint('[CompletedReportHydrator] legal checks fetch failed: $e');
  }
  return const <Map<String, dynamic>>[];
}

List<Map<String, dynamic>> _buildLegalFiles(
  Map legalStep, {
  required Map<String, String> urls,
}) {
  // Dedupe by filename — the server may expose the same file under
  // `legalReviewStep.files`, `legalReviewStep.otherLegalReviews`, and
  // `legalReviewStep.legalReview.files`; listing them all would render
  // duplicates in the editor's legal-files section.
  final collected = <Map<String, dynamic>>[];
  final seenFilenames = <String>{};
  void consume(dynamic source, String prefix) {
    if (source is! List) return;
    for (var i = 0; i < source.length; i++) {
      final raw = source[i];
      if (raw is! Map) continue;
      final filename = (raw['filename'] ?? '').toString().trim();
      if (filename.isEmpty) continue;
      if (!seenFilenames.add(filename.toLowerCase())) continue;
      final serverType = (raw['type'] ?? '').toString();
      collected.add(<String, dynamic>{
        'id': '${prefix}_${raw['id'] ?? i}',
        'name': filename,
        'mimeType': _mimeTypeFromServer(
          serverType: serverType,
          filename: filename,
        ),
        'dataUrl': urls[filename] ?? '',
        'inspection': const <String, dynamic>{
          'noDamage': true,
          'tags': <String>[],
          'note': '',
          'audioRecordings': <String>[],
          'isDraft': false,
        },
      });
    }
  }

  consume(legalStep['files'], 'legal');
  consume(legalStep['otherLegalReviews'], 'legalOther');
  final review = _asMap(legalStep['legalReview']);
  consume(review['files'], 'legalReview');
  return collected;
}

/// Server returns inspection / test-drive tags either as bare integer
/// arrays (legacy / older drafts) or as full objects
/// `[{id, name, slug, type}, ...]` (current `ViewSpecialistReport`
/// shape). Accept both. When the object form arrives, prefer its
/// embedded `name` — saves a tag-service lookup and works even when
/// the local catalog hasn't been hydrated yet (cold start, foreign
/// report).
List<String> _resolveTagNames(dynamic raw, SparkJoyTagService tagService) {
  if (raw is! List) return const <String>[];
  final out = <String>[];
  for (final item in raw) {
    String? name;
    if (item is Map) {
      final embedded = (item['name'] ?? '').toString().trim();
      if (embedded.isNotEmpty) {
        name = embedded;
      } else {
        final idRaw = item['id'];
        final id = idRaw is int
            ? idRaw
            : (idRaw is num ? idRaw.toInt() : int.tryParse('${idRaw ?? ''}'));
        if (id != null) name = tagService.nameForId(id);
      }
    } else {
      final id = item is int
          ? item
          : (item is num ? item.toInt() : int.tryParse('$item'));
      if (id != null) name = tagService.nameForId(id);
    }
    if (name != null && name.trim().isNotEmpty) out.add(name);
  }
  return out;
}

Map<String, List<int>> _collectMissingInspectionTagIdsBySection(
  Map inspectionStep,
  SparkJoyTagService tagService,
) {
  final out = <String, Set<int>>{};
  for (final entry in _inspectionArrayKeys.entries) {
    final section =
        SparkJoyTagService.groupKeyToApiSection[entry.value.groupKey];
    if (section == null) continue;
    final list = inspectionStep[entry.key];
    if (list is! List) continue;
    final ids = out.putIfAbsent(section, () => <int>{});
    for (final raw in list) {
      if (raw is! Map) continue;
      ids.addAll(
        _extractTagIdsNeedingLookup(raw['seriousDamageTags'], tagService),
      );
      ids.addAll(
        _extractTagIdsNeedingLookup(raw['noSeriousDamageTags'], tagService),
      );
    }
  }
  return {
    for (final entry in out.entries)
      if (entry.value.isNotEmpty)
        entry.key: entry.value.toList(growable: false),
  };
}

List<int> _collectMissingTestDriveTagIds(
  Map testDriveStep,
  SparkJoyTagService tagService,
) {
  final ids = <int>{};
  for (final key in const [
    'testDriveEngineTags',
    'testDriveTransmissionTags',
    'testDriveSteeringWheelTags',
    'testDriveSuspensionInDriveTags',
    'testDriveBrakesInDriveTags',
  ]) {
    ids.addAll(_extractTagIdsNeedingLookup(testDriveStep[key], tagService));
  }
  return ids.toList(growable: false);
}

List<int> _extractTagIdsNeedingLookup(
  dynamic raw,
  SparkJoyTagService tagService,
) {
  if (raw is! List) return const <int>[];
  final ids = <int>[];
  for (final item in raw) {
    if (item is Map) {
      final embeddedName = (item['name'] ?? '').toString().trim();
      if (embeddedName.isNotEmpty) continue;
    }
    int? id;
    if (item is Map) {
      final rawId = item['id'];
      id = rawId is int
          ? rawId
          : (rawId is num ? rawId.toInt() : int.tryParse('${rawId ?? ''}'));
    } else {
      id = item is int
          ? item
          : (item is num ? item.toInt() : int.tryParse('$item'));
    }
    if (id != null && id > 0 && tagService.nameForId(id) == null) {
      ids.add(id);
    }
  }
  return ids;
}

String _mimeTypeFromServer({
  required String serverType,
  required String filename,
}) {
  // Server `file.type` is one of image|video|document. Derive a concrete
  // MIME so UploadedItem.isImage / isVideo / isAudio gates stay correct.
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  switch (serverType) {
    case 'video':
      if (ext == 'mov') return 'video/quicktime';
      if (ext == 'm4v') return 'video/x-m4v';
      if (ext == 'webm') return 'video/webm';
      if (ext == 'avi') return 'video/x-msvideo';
      if (ext == 'mkv') return 'video/x-matroska';
      return 'video/mp4';
    case 'document':
      if (ext == 'pdf') return 'application/pdf';
      if (ext == 'doc') return 'application/msword';
      if (ext == 'docx') {
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }
      return 'application/octet-stream';
    case 'image':
    default:
      if (ext == 'png') return 'image/png';
      if (ext == 'webp') return 'image/webp';
      if (ext == 'heic') return 'image/heic';
      return 'image/jpeg';
  }
}

/// Maps server-side inspection element array keys to editor group keys.
const _inspectionArrayKeys = <String, _GroupDescriptor>{
  'bodyElements': _GroupDescriptor('body'),
  'bodyReinforcementElements': _GroupDescriptor('structural'),
  'glassElements': _GroupDescriptor('glass'),
  'interiorElements': _GroupDescriptor('interior'),
  'underHoodElements': _GroupDescriptor('underhood'),
  'wheelsAndBrakesElements': _GroupDescriptor('wheels'),
  // Server-side typo: the API uses "lightning" (молниеносные) for
  // what's actually the lighting (освещение) section. The value is
  // load-bearing — Prepare/View both round-trip through this exact
  // key. Keeping the misnomer here matches the wire; the editor's
  // group key on the right stays "lighting".
  'lightningElements': _GroupDescriptor('lighting'),
  'computerDiagnosticsElements': _GroupDescriptor('diagnostics'),
};

class _GroupDescriptor {
  const _GroupDescriptor(this.groupKey);
  final String groupKey;
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return const <String, dynamic>{};
}

List<String> _asStringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  final out = <String>[];
  for (final item in raw) {
    final s = item?.toString().trim() ?? '';
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

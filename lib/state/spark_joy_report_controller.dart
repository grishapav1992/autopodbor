import 'dart:math' as math;

import 'package:get/get.dart';

import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_create_report_screen.dart'
    show UploadedItem, BackendUploadFileProgress, MediaGroupState;
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_plate_formats.dart';

/// Owns the reactive state of a single spark_joy specialist report.
///
/// ## Migration strategy (Phase 4.1)
///
/// The spark_joy create-report screen currently holds ~50 state fields
/// directly inside [_SparkJoyCreateReportScreenState], with 140+ setState
/// calls spread across 30+ part-of files. Converting all of that in one
/// shot is too risky — we migrate the state group-by-group.
///
/// This controller starts with the **test-drive tag lists** (Chunk 1):
/// five `List<String>` fields used only by the test-drive step. The host
/// screen keeps the old `_tdEngineTags` etc. field names as getter/setter
/// proxies so the 73 existing references across 7 files do not need to
/// change — they transparently read/write through the controller now.
///
/// Subsequent chunks (media state, test-drive booleans, VIN/plate/car
/// fields, backend-upload progress, …) follow the same pattern.
///
/// The controller is instantiated per-screen via `Get.put(...)` tagged
/// with the widget's `hashCode` so multiple concurrent report screens
/// don't share state, and disposed in `State.dispose()` via `Get.delete()`.
class SparkJoyReportController extends GetxController {
  // ──────────────────────────────────────────────────────────────────
  // Chunk 1 — Test-drive tag selections
  //
  // Each list is set wholesale by the UI (no in-place mutation in the
  // current codebase — confirmed by grep), so an ordinary RxList with
  // `.value = newList` assignment is a safe drop-in.
  // ──────────────────────────────────────────────────────────────────

  final RxList<String> tdEngineTags = <String>[].obs;
  final RxList<String> tdGearboxTags = <String>[].obs;
  final RxList<String> tdSteeringTags = <String>[].obs;
  final RxList<String> tdRideTags = <String>[].obs;
  final RxList<String> tdBrakeTags = <String>[].obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 2 — Test-drive "was this subsystem OK" booleans
  //
  // Toggled by the test-drive step UI; false → there are issues (and
  // tags are shown). The host screen exposes the old `_tdEngineOk …`
  // field names as getter/setter proxies to avoid touching the 65
  // references across 7 files.
  // ──────────────────────────────────────────────────────────────────

  final RxBool tdEngineOk = false.obs;
  final RxBool tdGearboxOk = false.obs;
  final RxBool tdSteeringOk = false.obs;
  final RxBool tdRideOk = false.obs;
  final RxBool tdBrakeOk = false.obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 3 — Business / company-mode metadata
  //
  // Cached from SparkJoyStorage when the user enters the report as a
  // business (ИП / company). Drives the staff-invite card visibility
  // plus the business-tag displayed at the top of the form.
  // ──────────────────────────────────────────────────────────────────

  final Rxn<String> accountBusinessType = Rxn<String>();
  final Rxn<String> accountVerifiedInn = Rxn<String>();
  final RxString staffInviteLink = ''.obs;
  final RxBool staffInviteLinkCreating = false.obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 4 — Car-step declarations
  //
  // Two small flags from the "Автомобиль" step that don't belong to a
  // TextEditingController but still shape the final payload:
  //   • vinUnreadable     — "VIN нечитаемый" checkbox
  //   • mileageMismatch   — tri-state ("есть/нет/пока неизвестно") for
  //                         the "не совпадает с состоянием авто" flag.
  // ──────────────────────────────────────────────────────────────────

  final RxBool vinUnreadable = false.obs;
  final Rxn<bool> mileageMismatch = Rxn<bool>();

  /// Country whose plate-format rules apply to the госномер field.
  /// Defaults to RF; persisted in the draft as a wire-string under
  /// `gosNumberCountry`. See `spark_joy_plate_formats.dart` for the
  /// full RF + 5 СНГ catalog.
  final Rx<PlateCountry> plateCountry = Rx<PlateCountry>(PlateCountry.ru);

  // ──────────────────────────────────────────────────────────────────
  // Chunk 5 — Paintwork thickness ranges
  //
  // Two pairs of numeric ranges (micrometers) the user enters on the
  // body and body-reinforcement sections. Defaults 80..200 match the
  // server schema defaults in OpenRPC Doc.
  // ──────────────────────────────────────────────────────────────────

  final RxDouble bodyPaintFrom = 80.0.obs;
  final RxDouble bodyPaintTo = 200.0.obs;
  final RxDouble structPaintFrom = 80.0.obs;
  final RxDouble structPaintTo = 200.0.obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 6 — Legal-check step state + test-drive mode
  //
  // Drives the "Юридическая проверка" step UI and the summary widget:
  //   • legalLoading / Loaded / TimedOut / Skipped / Purchased flags
  //   • legalLoadToken — monotonic token to dedupe async retries
  //   • tdMode — "included" | "excluded" | null (is test-drive done?)
  // ──────────────────────────────────────────────────────────────────

  final RxBool legalLoading = false.obs;
  final RxBool legalLoaded = false.obs;
  final RxBool legalSkipped = false.obs;
  final RxBool legalTimedOut = false.obs;
  final RxBool legalPurchased = false.obs;
  final RxInt legalLoadToken = 0.obs;
  final Rxn<String> tdMode = Rxn<String>();

  // ──────────────────────────────────────────────────────────────────
  // Chunk 7 — Draft autosave meta-state
  //
  // Tracks the state of the background autosave pipeline. Timers and
  // the actual debounce logic stay in the host widget — only the
  // status flags that other helpers want to *read* live here.
  // ──────────────────────────────────────────────────────────────────

  final RxBool draftSaveInProgress = false.obs;
  final RxBool draftSaveFailed = false.obs;
  final RxBool hasUnsavedDraftChanges = false.obs;
  final RxBool autosaveRequestedWhileSaving = false.obs;
  final RxBool appPauseHandlingInProgress = false.obs;
  final Rxn<DateTime> lastDraftSavedAt = Rxn<DateTime>();

  // ──────────────────────────────────────────────────────────────────
  // Chunk 8 — Permissions + speech availability
  //
  // Runtime microphone / speech-recognition permission states, plus
  // the current availability of the SpeechToText engine.
  // ──────────────────────────────────────────────────────────────────

  final RxBool microphonePermissionGranted = false.obs;
  final RxBool speechPermissionGranted = false.obs;
  final RxBool tdSpeechInitializing = false.obs;
  final RxBool tdSpeechAvailable = false.obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 9 — Dictation state per step
  //
  // The test-drive, documents, legal and expert steps each expose a
  // "hold to dictate" button. isDictating = recognizer is currently
  // listening. shouldDictate = user wants dictation on next opening.
  // ──────────────────────────────────────────────────────────────────

  final RxBool tdIsDictating = false.obs;
  final RxBool tdShouldDictate = false.obs;
  final RxBool docsIsDictating = false.obs;
  final RxBool docsShouldDictate = false.obs;
  final RxBool legalIsDictating = false.obs;
  final RxBool legalShouldDictate = false.obs;
  // Dictation state for the unified «Итог осмотра» field
  // (`_summaryController`). Replaced the old `expertIsDictating` after
  // the «Сводка» + «Итог специалиста» cards were merged into one.
  final RxBool summaryIsDictating = false.obs;
  final RxBool summaryShouldDictate = false.obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 10 — Currently-playing audio index per comment list
  //
  // -1 means "nothing playing". Exactly one non-negative value across
  // these four lists at any time (the host widget enforces it).
  // ──────────────────────────────────────────────────────────────────

  final RxInt docsCommentPlayingAudioIndex = (-1).obs;
  final RxInt legalCommentPlayingAudioIndex = (-1).obs;
  final RxInt tdCommentPlayingAudioIndex = (-1).obs;
  final RxInt expertCommentPlayingAudioIndex = (-1).obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 11 — Media-editor tag customization by scope
  //
  // The inspection editor lets the user override the default tag set
  // per (section, element) scope:
  //   • customTagsByScope          — user-added non-serious tags
  //   • customSeriousTagsByScope   — user-added serious tags
  //   • disabledDefaultTagsByScope — hidden factory-default tags
  //   • tagOrderByScope            — user-defined tag ordering
  //
  // Confirmed via grep: every usage is a wholesale reassignment
  // (`_mediaCustomTagsByScope = newMap`) — no `[key] = ...` or
  // `.putIfAbsent` patterns — so proxying through the controller's
  // mutable maps is safe.
  // ──────────────────────────────────────────────────────────────────

  final Rx<Map<String, List<String>>> mediaCustomTagsByScope =
      Rx<Map<String, List<String>>>(<String, List<String>>{});
  final Rx<Map<String, List<String>>> mediaCustomSeriousTagsByScope =
      Rx<Map<String, List<String>>>(<String, List<String>>{});
  final Rx<Map<String, List<String>>> mediaDisabledDefaultTagsByScope =
      Rx<Map<String, List<String>>>(<String, List<String>>{});
  final Rx<Map<String, List<String>>> mediaTagOrderByScope =
      Rx<Map<String, List<String>>>(<String, List<String>>{});

  // ──────────────────────────────────────────────────────────────────
  // Chunk 12 — Backend multipart upload progress
  //
  // Drives the "upload to S3" overlay shown after PrepareSpecialist-
  // Report returns presigned URLs. These ten fields are scalars /
  // strings / a free-form map; the typed progress LIST stays in the
  // host for now because its `BackendUploadFileProgress` item class
  // is library-private and would need a rename first (see chunk 13).
  // ──────────────────────────────────────────────────────────────────

  final Rx<Map<String, dynamic>> backendUploadState =
      Rx<Map<String, dynamic>>(<String, dynamic>{});
  final RxBool backendUploadInProgress = false.obs;
  final RxBool backendUploadFailed = false.obs;
  final RxString backendUploadStatusText = ''.obs;
  final RxString backendUploadErrorText = ''.obs;
  final RxInt backendUploadCurrentFile = 0.obs;
  final RxInt backendUploadTotalFiles = 0.obs;
  final RxInt backendUploadCurrentPart = 0.obs;
  final RxInt backendUploadTotalParts = 0.obs;
  final RxBool backendFileUploadLocked = false.obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 13 — Uploaded file lists + per-file upload progress list
  //
  // These lists all carry `UploadedItem` / `BackendUploadFileProgress`
  // — classes that used to be private (`_UploadedItem`, etc.) and got
  // renamed in this chunk so the controller can reference them without
  // living in the same `part of` library.
  // ──────────────────────────────────────────────────────────────────

  final Rx<List<UploadedItem>> legalFiles =
      Rx<List<UploadedItem>>(const <UploadedItem>[]);
  final Rx<List<UploadedItem>> docsCommentAudioFiles =
      Rx<List<UploadedItem>>(const <UploadedItem>[]);
  final Rx<List<UploadedItem>> legalCommentAudioFiles =
      Rx<List<UploadedItem>>(const <UploadedItem>[]);
  final Rx<List<UploadedItem>> tdCommentAudioFiles =
      Rx<List<UploadedItem>>(const <UploadedItem>[]);
  final Rx<List<UploadedItem>> expertAudioFiles =
      Rx<List<UploadedItem>>(const <UploadedItem>[]);

  final Rx<List<BackendUploadFileProgress>> backendUploadFilesProgress =
      Rx<List<BackendUploadFileProgress>>(const <BackendUploadFileProgress>[]);

  // ──────────────────────────────────────────────────────────────────
  // Chunk 14 — Main media / inspection state map
  //
  // The big one: `_mediaState` in the host widget was a
  // `late Map<String, MediaGroupState>` (previously _MediaGroupState —
  // renamed to public in this chunk along with _MediaGroupConfig /
  // _MediaPartInspection). It holds every section of the inspection
  // step: files, notes, hasIssue flags, tag photos, element types.
  //
  // Host code freely does `_mediaState[key] = newState` — so we expose
  // a RxMap directly. The getter returns the same underlying
  // RxMap instance every time (RxMap implements Map), so key-assign
  // operations work transparently.
  // ──────────────────────────────────────────────────────────────────

  final RxMap<String, MediaGroupState> mediaState =
      <String, MediaGroupState>{}.obs;

  // ──────────────────────────────────────────────────────────────────
  // Chunk 15 — AiQueue per-element chat ids + last AI results
  //
  // Each inspection element (group + elementType + optional file) gets
  // a stable JSON-RPC `id` that doubles as the conversation key on the
  // aiqueue backend. Map is persisted into the draft (`aiChatIds`)
  // alongside the rest of the report state and rehydrated on load.
  //
  // [aiResultBySourceKey] holds the last successful AI text response
  // per element so the editor can preview what the model returned even
  // after closing/reopening, and so a successful background flush can
  // surface results without the editor being open at that moment.
  //
  // Rule: chatIds are bound to the *local* draftId — they persist across
  // app restarts but die with the draft on submit/delete.
  // ──────────────────────────────────────────────────────────────────

  final RxMap<String, int> aiChatIdBySourceKey = <String, int>{}.obs;
  final RxMap<String, String> aiResultBySourceKey = <String, String>{}.obs;

  /// Stable scope key for an element. We deliberately key on
  /// (groupKey, elementType, itemDataUrl) so two different files of the
  /// same element type get different chats. When the editor is at the
  /// section level (no per-file context), pass `itemDataUrl: null`.
  static String aiSourceKey({
    required String groupKey,
    required String elementType,
    String? itemDataUrl,
  }) {
    final group = groupKey.trim();
    final element = elementType.trim();
    final url = (itemDataUrl ?? '').trim();
    return url.isEmpty ? '$group:$element' : '$group:$element:$url';
  }

  /// Returns the chatId for [sourceKey], minting a new one if absent.
  /// The minted id is JSON safe-int and locally unique across drafts of
  /// the same user (server isolates by `(JWT.sub, chatId)`).
  int ensureAiChatId(String sourceKey) {
    final existing = aiChatIdBySourceKey[sourceKey];
    if (existing != null && existing > 0) return existing;
    final id = _mintChatId();
    aiChatIdBySourceKey[sourceKey] = id;
    return id;
  }

  void rememberAiResult(String sourceKey, String text) {
    if (text.isEmpty) return;
    aiResultBySourceKey[sourceKey] = text;
  }

  static int _mintChatId() {
    final ms = DateTime.now().millisecondsSinceEpoch; // ~41 bits
    final rnd = math.Random.secure().nextInt(1 << 20); // 20 bits
    final composed = (ms << 20) | rnd; // ~61 bits
    // Clamp to JSON-safe int (2^53 - 1) so any JSON encoder we transit
    // through (Dart, NATS, OpenAI bridge) keeps the id intact.
    return composed & 0x1FFFFFFFFFFFFF;
  }

  /// Loads chatIds and last results from the persisted draft into the
  /// controller. Idempotent — safe to call on every draft hydration.
  void hydrateAiChatStateFromDraft(Map<String, dynamic>? rawAiQueue) {
    if (rawAiQueue == null) return;
    final chatIds = rawAiQueue['bySourceKey'];
    if (chatIds is Map) {
      final next = <String, int>{};
      chatIds.forEach((k, v) {
        final intVal = v is int ? v : int.tryParse(v?.toString() ?? '');
        if (intVal != null && intVal > 0) {
          next[k.toString()] = intVal;
        }
      });
      aiChatIdBySourceKey
        ..clear()
        ..addAll(next);
    }
    final results = rawAiQueue['results'];
    if (results is Map) {
      final next = <String, String>{};
      results.forEach((k, v) {
        if (v is Map) {
          final text = v['text']?.toString() ?? '';
          if (text.isNotEmpty) next[k.toString()] = text;
        } else if (v is String && v.isNotEmpty) {
          next[k.toString()] = v;
        }
      });
      aiResultBySourceKey
        ..clear()
        ..addAll(next);
    }
  }

  /// Snapshot of AI chat state in the shape persisted into the draft
  /// under the `aiChatIds` key. Pure read — does not mutate state.
  Map<String, dynamic> exportAiChatStateToDraft() {
    return <String, dynamic>{
      'bySourceKey': Map<String, int>.from(aiChatIdBySourceKey),
      'results': {
        for (final entry in aiResultBySourceKey.entries)
          entry.key: <String, dynamic>{
            'text': entry.value,
            'updatedAt': DateTime.now().toIso8601String(),
          },
      },
    };
  }

  /// Replaces the contents of [list] with [next] in one shot, keeping the
  /// same RxList instance (so listeners don't have to re-subscribe).
  static void _assignList(RxList<String> list, List<String> next) {
    list
      ..clear()
      ..addAll(next);
  }

  void setTdEngineTags(List<String> next) => _assignList(tdEngineTags, next);
  void setTdGearboxTags(List<String> next) => _assignList(tdGearboxTags, next);
  void setTdSteeringTags(List<String> next) =>
      _assignList(tdSteeringTags, next);
  void setTdRideTags(List<String> next) => _assignList(tdRideTags, next);
  void setTdBrakeTags(List<String> next) => _assignList(tdBrakeTags, next);

  /// Resets every tracked test-drive list to empty. Used when the user
  /// toggles "test-drive not performed" — see spark_joy_test_drive_rules.
  void clearAllTdTags() {
    tdEngineTags.clear();
    tdGearboxTags.clear();
    tdSteeringTags.clear();
    tdRideTags.clear();
    tdBrakeTags.clear();
  }
}

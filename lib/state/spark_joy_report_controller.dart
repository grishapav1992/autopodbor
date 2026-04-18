import 'package:get/get.dart';

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
  final RxBool expertIsDictating = false.obs;
  final RxBool expertShouldDictate = false.obs;

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

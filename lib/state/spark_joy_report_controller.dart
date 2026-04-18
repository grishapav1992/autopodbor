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

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

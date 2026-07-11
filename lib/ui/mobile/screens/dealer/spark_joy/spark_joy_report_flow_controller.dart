part of 'spark_joy_create_report_screen.dart';

class _SparkJoyReportFlowController {
  int stepIndex = 0;
  bool editingSection = false;
  bool returnToSummaryOnBack = false;

  /// Экран интейка «Фото автомобиля» — третья ветка шелла наряду с
  /// обзором разделов и редактором секции.
  bool editingPhotoIntake = false;

  void openPhotoIntake() {
    editingPhotoIntake = true;
  }

  void closePhotoIntake() {
    editingPhotoIntake = false;
  }

  int sanitizeStepIndex(int index, {required int totalSteps}) {
    if (totalSteps <= 0) return 0;
    if (index < 0) return 0;
    if (index >= totalSteps) return 0;
    return index;
  }

  void openSection(int index, {required int totalSteps}) {
    stepIndex = sanitizeStepIndex(index, totalSteps: totalSteps);
    editingSection = true;
    returnToSummaryOnBack = false;
  }

  void openFromSummary({
    required int nextIndex,
    required int summaryIndex,
    required int totalSteps,
  }) {
    stepIndex = sanitizeStepIndex(nextIndex, totalSteps: totalSteps);
    editingSection = true;
    returnToSummaryOnBack =
        summaryIndex >= 0 &&
        stepIndex != sanitizeStepIndex(summaryIndex, totalSteps: totalSteps);
  }

  bool moveToNext({required int totalSteps}) {
    if (stepIndex >= totalSteps - 1) return false;
    stepIndex += 1;
    editingSection = true;
    returnToSummaryOnBack = false;
    return true;
  }

  void closeSection() {
    editingSection = false;
    returnToSummaryOnBack = false;
  }

  bool returnToSummary({required int summaryIndex, required int totalSteps}) {
    if (summaryIndex < 0) return false;
    stepIndex = sanitizeStepIndex(summaryIndex, totalSteps: totalSteps);
    editingSection = true;
    returnToSummaryOnBack = false;
    return true;
  }

  bool isSummaryStep({required int totalSteps}) {
    if (totalSteps <= 0) return false;
    return stepIndex == totalSteps - 1;
  }
}

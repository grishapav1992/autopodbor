import 'package:flutter/foundation.dart';

/// Снапшот активной выгрузки отчёта — для текстов UI (хинт в редакторе,
/// бейдж на карточке черновика).
@immutable
class SparkJoyActiveReportUpload {
  const SparkJoyActiveReportUpload({
    required this.draftId,
    required this.reportName,
  });

  final String draftId;
  final String reportName;
}

/// Глобальный single-flight гейт выгрузки отчётов: на всё приложение — не
/// более одной выгрузки одновременно. Сама выгрузка живёт в состоянии
/// экрана редактора и доживает в фоне после ухода с него, поэтому
/// пер-экранные гарды (`backendUploadInProgress`) не видят чужих выгрузок:
/// «запустил №1 → назад → запустил №2» давал параллельные выгрузки, а
/// повторное открытие того же черновика — две выгрузки одного черновика и
/// дубликат отчёта на сервере (два PrepareSpecialistReport → два номера).
///
/// Инвариант владения: release(draftId) вызывает только код, успешно
/// прошедший tryAcquire с этим draftId. Повторный tryAcquire того же
/// draftId отклоняется, поэтому владелец однозначен без lease-токенов.
///
/// Синглтон уровня приложения (паттерн SparkJoyIntakeUploadService).
class SparkJoyReportUploadGate {
  SparkJoyReportUploadGate._();

  static SparkJoyReportUploadGate instance = SparkJoyReportUploadGate._();

  @visibleForTesting
  static void resetSingletonForTest() {
    instance = SparkJoyReportUploadGate._();
  }

  final ValueNotifier<SparkJoyActiveReportUpload?> _active =
      ValueNotifier<SparkJoyActiveReportUpload?>(null);

  /// Текущая активная выгрузка (null — гейт свободен). UI подписывается
  /// addListener-ом / ValueListenableBuilder-ом.
  ValueListenable<SparkJoyActiveReportUpload?> get active => _active;

  bool get isBusy => _active.value != null;

  bool isUploading(String draftId) =>
      draftId.trim().isNotEmpty && _active.value?.draftId == draftId;

  /// Атомарно (без await) занимает гейт. false — занят кем угодно, включая
  /// тот же draftId: вторая выгрузка того же черновика из повторно
  /// открытого экрана тоже запрещена.
  bool tryAcquire({required String draftId, required String reportName}) {
    if (_active.value != null) return false;
    _active.value = SparkJoyActiveReportUpload(
      draftId: draftId,
      reportName: reportName,
    );
    return true;
  }

  /// Owner-check: сбрасывает только если владелец совпадает. Поздний
  /// release «умершей» выгрузки после resetAll() — no-op.
  void release(String draftId) {
    if (_active.value?.draftId != draftId) return;
    _active.value = null;
  }

  /// Разлогин: гасим бейджи/дизейблы для нового сеанса. Живой Future старой
  /// выгрузки позже вызовет release() — станет no-op по owner-check.
  void resetAll() {
    _active.value = null;
  }
}

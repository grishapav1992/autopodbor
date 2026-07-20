import 'package:flutter/foundation.dart';

/// Единый текст «этот черновик уже выгружается»: хинт на шаге «Итог» и
/// страховочный снекбар отказа в `_finishReport` обязаны совпадать.
const String kSparkReportUploadSameDraftBusyText =
    'Этот отчёт уже выгружается — дождитесь завершения';

/// Снапшот активной выгрузки отчёта — для текстов UI (хинт в редакторе,
/// бейдж на карточке черновика).
@immutable
class SparkJoyActiveReportUpload {
  const SparkJoyActiveReportUpload({
    required this.draftId,
    required this.reportName,
    this.cancelRequested = false,
  });

  final String draftId;
  final String reportName;

  /// Отмена запрошена извне через [SparkJoyReportUploadGate.requestCancel]
  /// (не с экрана-владельца). Выгрузка опрашивает флаг кооперативно в тех же
  /// точках, что и свою отмену.
  final bool cancelRequested;

  SparkJoyActiveReportUpload _withCancelRequested() =>
      SparkJoyActiveReportUpload(
        draftId: draftId,
        reportName: reportName,
        cancelRequested: true,
      );
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

  /// Кооперативная отмена активной выгрузки «снаружи»: экран-владелец после
  /// ухода с него мёртв, его крестик отмены недоступен, а `_uploadCancelled`
  /// досягаем только из замыкания выгрузки. Флаг попадает в снапшот
  /// (нотификация UI: кнопка → «Отменяем выгрузку…»), выгрузка-владелец
  /// абсорбирует его в свою обычную цепочку отмены при следующем опросе.
  void requestCancel() {
    final current = _active.value;
    if (current == null || current.cancelRequested) return;
    _active.value = current._withCancelRequested();
  }

  /// true — владельцу [draftId] запрошена отмена извне.
  bool isCancelRequested(String draftId) {
    final current = _active.value;
    return current != null &&
        current.draftId == draftId &&
        current.cancelRequested;
  }

  /// Разлогин: гасим бейджи/дизейблы для нового сеанса. Живой Future старой
  /// выгрузки позже вызовет release() — станет no-op по owner-check.
  void resetAll() {
    _active.value = null;
  }
}

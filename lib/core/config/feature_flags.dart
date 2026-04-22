/// Централизованные feature flags проекта.
///
/// Пока это просто статические const — позже можно будет подвязать к
/// remote config (GrowthBook, Firebase Remote Config) без изменения
/// потребителей: достаточно будет сменить геттер с `const` на
/// runtime-lookup.
class FeatureFlags {
  FeatureFlags._();

  /// Использовать мок вместо реального запроса в api-cloud.ru/pb_nalog.
  ///
  /// TODO(api-cloud): когда будет выдан реальный API-ключ:
  ///   1. Перевести оба флага (usePbNalogMock + useConverterMock) в false
  ///      (или начать читать из remote config).
  ///   2. Положить ключ через `UserSimplePreferences.setApiCloudToken(...)`
  ///      или перенести его в `--dart-define=API_CLOUD_TOKEN=...` для
  ///      более надёжного хранения. Один ключ покрывает все api-cloud
  ///      эндпоинты — pb_nalog, converter и будущие.
  ///   3. Проверить, что endpoints актуальны (`pb_nalog.php`, `converter.php`).
  ///   4. Прогнать happy-path и error-path (истёкший баланс / неверный
  ///      ключ / офлайн) — убедиться, что UI корректно показывает
  ///      локализованные ошибки через `ApiCloudErrorKind`.
  static const bool usePbNalogMock = true;

  /// Использовать мок вместо реального запроса в api-cloud.ru/converter.
  /// См. TODO(api-cloud) выше — переключаются синхронно.
  static const bool useConverterMock = true;
}

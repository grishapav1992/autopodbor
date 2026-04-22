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
  /// TODO(pb-nalog-api): когда будет выдан реальный API-ключ:
  ///   1. Перевести в `false` (или начать читать из remote config).
  ///   2. Положить ключ через `UserSimplePreferences.setPbNalogToken(...)`
  ///      или перенести его в `--dart-define=PB_NALOG_TOKEN=...` для
  ///      более надёжного хранения.
  ///   3. Проверить, что endpoint в `PbNalogApiHttp` актуален
  ///      (`https://api-cloud.ru/api/pb_nalog.php`).
  ///   4. Прогнать happy-path на живом ИНН и error-path (истёкший
  ///      баланс / неверный ключ) — убедиться, что UI корректно
  ///      показывает локализованные ошибки из [PbNalogException.userMessage].
  static const bool usePbNalogMock = true;
}

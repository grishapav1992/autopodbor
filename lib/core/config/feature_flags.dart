import 'package:flutter/foundation.dart' show kDebugMode;

/// Централизованные feature flags проекта.
///
/// Пока это просто статические const — позже можно будет подвязать к
/// remote config (GrowthBook, Firebase Remote Config) без изменения
/// потребителей: достаточно будет сменить геттер с `const` на
/// runtime-lookup.
class FeatureFlags {
  FeatureFlags._();

  /// Показывать «технический вход» (пароль 12112016 + хардкоженные JWT)
  /// на экране логина. В релизе строго выключено — любой, кто
  /// декомпилит бинарь, иначе увидит встроенные токены. В debug-
  /// сборках оставлен как bypass для локальной разработки, пока
  /// реальный phone-auth flow в работе.
  static bool get devTechLogin => kDebugMode;
}

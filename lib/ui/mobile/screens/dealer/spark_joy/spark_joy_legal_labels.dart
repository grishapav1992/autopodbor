/// Человекочитаемое русское название типа ApiCloud-проверки по стабильному
/// `value` (бэк в `name` отдаёт техничный PascalCase: `ApiCloudZalogNotary`).
///
/// Единый источник истины для шага «Материалы проверки»
/// (`spark_joy_step_legal.dart`) и ленты уведомлений
/// (`spark_joy_notifications_screen.dart`) — чтобы названия проверок не
/// расходились между двумя экранами.
///
/// Неизвестный тип — мягкий фолбэк: убрать префикс `api_cloud_`, `_`→пробел,
/// первая буква заглавная; если пусто — вернуть исходный `value`.
String sparkJoyLegalCheckTypeLabel(String value) {
  switch (value) {
    case 'api_cloud_zalog_notary':
      return 'Залог (реестр нотариусов)';
    case 'api_cloud_zalog_fedresurs':
      return 'Лизинг (Федресурс)';
    case 'api_cloud_gost_certificate':
      return 'Сертификат ГОСТ';
    case 'api_cloud_taxi_search':
      return 'Работа в такси';
    case 'api_cloud_fgis_taxi_search':
      return 'Разрешение такси (ФГИС)';
    case 'api_cloud_converter_search':
      return 'Определение по VIN/госномеру';
    default:
      final cleaned = value
          .replaceFirst('api_cloud_', '')
          .replaceAll('_', ' ')
          .trim();
      if (cleaned.isEmpty) return value;
      return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

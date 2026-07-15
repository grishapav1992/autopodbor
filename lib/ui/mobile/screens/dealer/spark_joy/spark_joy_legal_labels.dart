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

/// Переводит сырое сообщение провайдера проверки (ApiCloud → бэк пробрасывает
/// его в `responseNormalized.message` / `errorMessage` как есть) в понятный
/// русский текст. Живой пример: «gosNumber% forbidden symbols present» —
/// ответ ApiCloud на пустой/невалидный госномер, в таком виде он доходил до
/// пользователя (репорт 2026-07-15).
///
/// `errorMessage` бэк собирает как «ExceptionClass | текст | /path/file.php:123»
/// (`ApiCloudLegalReviewProvider::formatErrorMessage`) — технические части
/// отбрасываем, неизвестный текст возвращаем как есть.
String sparkJoyHumanizeLegalCheckMessage(String raw) {
  var message = raw.trim();
  if (message.isEmpty) return '';
  if (message.contains(' | ')) {
    final human = message
        .split(' | ')
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty &&
              // PHP-класс исключения: App\Workerman\…\ApiCloudException.
              !RegExp(r'^[A-Za-z0-9_\\]+(Exception|Error)$').hasMatch(part) &&
              // Файл и строка: /var/www/src/….php:123.
              !RegExp(r'\.php:\d+$').hasMatch(part),
        )
        .toList();
    if (human.isNotEmpty) message = human.join(' | ');
  }
  final lower = message.toLowerCase();
  if (lower.contains('forbidden symbols')) {
    return 'Сервис проверки не принял госномер — нужен российский номер '
        'кириллицей и цифрами';
  }
  if (lower.contains('curl') ||
      lower.contains('timeout') ||
      lower.contains('timed out')) {
    return 'Сервис проверки не ответил вовремя — попробуйте позже';
  }
  return message;
}

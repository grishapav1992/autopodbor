/// Общие типы/таксономия ошибок для всех API api-cloud.ru.
///
/// Коды ошибок у всех эндпоинтов api-cloud.ru одинаковые (498 —
/// нет денег, 499 — неверный токен, 503/504 — токен заблокирован,
/// 404 — таймаут источника, 456 — rate-limit, и т.д.). Доменно-
/// специфичные коды (например, 331 «Неверный формат ИНН» для
/// pb_nalog) остаются в соответствующем клиенте.
///
/// Псевдокод `net_offline` — наш локальный маркер, который ставит
/// HTTP-клиент, когда ловит `SocketException`/`ClientException`.
/// API его не возвращает.
library;

/// Категория ошибки — что показывать пользователю.
enum ApiCloudErrorKind {
  /// Юзер сам может исправить (формат входа, недопустимые символы).
  /// UI показывает конкретный текст возле поля.
  userInput,

  /// Транзиентное — сеть/таймаут/rate-limit. UI: «попробуйте позже».
  transient,

  /// Наша конфигурация/биллинг/доступ — пользователь ничего не
  /// сделает. UI: обобщённое «сервис недоступен». Детали — в логах.
  admin,
}

/// Классифицирует код ошибки по категории.
///
/// Доменные коды (например, 331 для ИНН) передавайте через
/// [overrideUserInput] — для них вернётся [ApiCloudErrorKind.userInput]
/// независимо от того, есть ли они в списке ниже.
ApiCloudErrorKind kindForApiCloudCode(
  String code, {
  Set<String> overrideUserInput = const <String>{},
}) {
  if (overrideUserInput.contains(code)) {
    return ApiCloudErrorKind.userInput;
  }
  switch (code) {
    case '888':
      return ApiCloudErrorKind.userInput;
    case '404':
    case '456':
    case 'net_offline':
      return ApiCloudErrorKind.transient;
    case '498':
    case '499':
    case '500':
    case '502':
    case '503':
    case '504':
    case '602':
    case '766':
    case '460':
    case '111':
    case '123':
    case '15':
    case '5':
    case '1':
    case '2':
    case '3':
      return ApiCloudErrorKind.admin;
    default:
      // Неизвестный код → admin. Пользователю не показываем техдетали,
      // разработчик увидит diagnosticMessage в developer.log.
      return ApiCloudErrorKind.admin;
  }
}

/// Общее сообщение для transient-ошибок, разделяемое всеми клиентами
/// api-cloud.ru.
String transientMessageForApiCloudCode(String code) {
  switch (code) {
    case '404':
      return 'Источник данных не ответил. Попробуйте ещё раз через пару минут.';
    case '456':
      return 'Слишком много запросов подряд. Попробуйте через минуту.';
    case 'net_offline':
      return 'Нет подключения к интернету. Проверьте сеть и попробуйте снова.';
    default:
      return 'Сервис сейчас занят. Попробуйте ещё раз.';
  }
}

/// Сообщение для admin-ошибок — намеренно общее.
const String adminMessageForApiCloud =
    'Сервис временно недоступен. Попробуйте позже.';

/// Сообщение для нетипизированных userInput-ошибок (888 — запрещённые
/// символы). Доменные `userInput`-коды (вроде 331 для ИНН) обрабатывает
/// соответствующий клиент.
String sharedUserInputMessage(String code) {
  switch (code) {
    case '888':
      return 'Недопустимые символы во входных данных';
    default:
      return 'Проверьте введённые данные';
  }
}

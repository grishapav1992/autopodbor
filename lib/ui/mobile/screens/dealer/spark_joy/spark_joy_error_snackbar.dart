import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart'
    show PermissionDeniedException;
import 'package:flutter_application_1/data/api/storage_api_models.dart';

/// Стабильные внутренние коды ошибок для техподдержки.
///
/// Код показывается пользователю (баннер ошибки выгрузки, строка «Код: …» в
/// снекбарах) и всегда входит в копируемый support-текст — по нему поддержка
/// определяет класс проблемы, не разбирая техническое сообщение. Значения
/// НЕ переиспользовать и не менять: они документированы в
/// docs/SUPPORT_ERROR_CODES.md (при добавлении кода — обновить таблицу там).
abstract final class SparkJoyErrorCode {
  /// Нет доступа к сети: DNS lookup не прошёл, сеть недостижима.
  static const netNoConnection = 'NET-01';

  /// Соединение или ответ сервера не уложились в таймаут.
  static const netTimeout = 'NET-02';

  /// Соединение оборвалось на середине (reset / closed / broken pipe).
  static const netInterrupted = 'NET-03';

  /// Сервер отверг подключение (connection refused).
  static const netRefused = 'NET-04';

  /// Не установилось защищённое соединение (TLS handshake / сертификат) —
  /// в т.ч. устаревший cert-pin в старом билде приложения.
  static const netTls = 'NET-05';

  /// Прочий сетевой сбой (SocketException/ClientException без деталей).
  static const netGeneric = 'NET-06';

  /// Сервер недоступен: HTTP 5xx / bad gateway.
  static const serverUnavailable = 'SRV-01';

  /// Сервер ограничил частоту запросов (HTTP 429 / rate limit).
  static const serverRateLimited = 'SRV-02';

  /// Сервер ответил, но ответ некорректный или действие не подтверждено.
  static const serverBadResponse = 'SRV-03';

  /// Сервер отклонил операцию бизнес-кодом (snake_case-код — в support-тексте).
  static const serverRejected = 'SRV-04';

  /// Сессия истекла / нет авторизации (HTTP 401).
  static const authSession = 'AUTH-01';

  /// Недостаточно прав (HTTP 403 / permission denied).
  static const authForbidden = 'AUTH-02';

  /// Локальный файл отчёта не прочитался с устройства.
  static const fileUnreadable = 'FILE-01';

  /// У файла отчёта пустой источник данных (медиа устарело).
  static const fileEmptySource = 'FILE-02';

  /// У файла отчёта не определилось имя для загрузки.
  static const fileEmptyName = 'FILE-03';

  /// Финализация остановлена: часть заявленных файлов не дошла до S3.
  static const fileMissingOnServer = 'FILE-04';

  /// Хранилище не приняло файл (presigned URL / ETag / multipart).
  static const fileUploadFailed = 'FILE-05';

  /// Не удалось определить модель авто из каталога перед выгрузкой.
  static const reportModelUnresolved = 'RPT-01';

  /// Не классифицировано — техническое сообщение в support-тексте.
  static const unknown = 'UNK-01';
}

typedef SparkJoyReadableError = ({
  String message,
  String supportText,
  String code,
});

SparkJoyReadableError sparkJoyReadableError(Object error, {String? fallback}) {
  // RBAC: a backend permission denial (HTTP 403 / forbidden RPC) always maps
  // to the same clean message regardless of which method was blocked — the
  // method name stays in the copyable support text for diagnostics.
  if (error is PermissionDeniedException) {
    const msg = 'Недостаточно прав для этого действия';
    const code = SparkJoyErrorCode.authForbidden;
    final support = <String>[
      'Код: $code',
      'Сообщение: $msg',
      'Метод: ${error.method}',
      if (error.serverMessage.trim().isNotEmpty)
        'Техническая ошибка: ${error.serverMessage.trim()}',
    ].join('\n');
    return (
      message: _withFallback(fallback, msg),
      supportText: support,
      code: code,
    );
  }
  final rawText = _rawErrorText(error);
  final backendCode = _errorCode(error, rawText);
  final mapped = _mappedBackendError(
    backendCode,
    activeAssignedRequests: error is CompanySpecialistUnlinkException
        ? error.activeAssignedRequests
        : null,
  );
  final rawMessage = _cleanTechnicalText(rawText);
  final String message;
  final String code;
  if (mapped != null && backendCode != null) {
    message = mapped;
    code = _internalCodeForBackendCode(backendCode);
  } else {
    final generic = _classifyGeneric(rawMessage);
    message = generic.message;
    code = generic.code;
  }
  final finalMessage = _withFallback(fallback, message);

  return (
    message: finalMessage,
    supportText: _supportText(
      message: finalMessage,
      rawText: rawText,
      code: code,
      backendCode: backendCode,
    ),
    code: code,
  );
}

String sparkJoyReadableErrorText(Object error, {String? fallback}) {
  return sparkJoyReadableError(error, fallback: fallback).message;
}

void showSparkJoyErrorSnackBar(
  BuildContext context,
  Object error, {
  String? fallback,
}) {
  final readable = sparkJoyReadableError(error, fallback: fallback);
  // Бизнес-отказы (SRV-04) самоописательны — «Заявка не найдена» не требует
  // кода на экране; для транспортных/непонятных ошибок код в тексте позволяет
  // опознать проблему даже по скриншоту, без копирования.
  final showCode = readable.code != SparkJoyErrorCode.serverRejected;
  showSparkJoySupportErrorSnackBar(
    context,
    message: readable.message,
    supportText: readable.supportText,
    code: showCode ? readable.code : '',
  );
}

/// Красный снекбар с кнопкой копирования support-текста. Для мест, где
/// читаемое сообщение и код уже вычислены (например, состояние ошибки
/// выгрузки отчёта), в отличие от [showSparkJoyErrorSnackBar], который
/// классифицирует исключение сам.
void showSparkJoySupportErrorSnackBar(
  BuildContext context, {
  required String message,
  String supportText = '',
  String code = '',
}) {
  final text = code.trim().isEmpty ? message : '$message\nКод: ${code.trim()}';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Expanded(child: Text(text)),
          IconButton(
            tooltip: 'Скопировать ошибку',
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: supportText.trim().isEmpty ? text : supportText,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            color: kWhiteColor,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      backgroundColor: kRedColor,
      // Дольше стандартных 4с: пользователю нужно успеть нажать «копировать».
      duration: const Duration(seconds: 8),
    ),
  );
}

String _rawErrorText(Object error) {
  if (error is CompanySpecialistUnlinkException) {
    return error.code.isEmpty ? error.message : error.code;
  }
  return error.toString();
}

String _cleanTechnicalText(String raw) {
  var text = raw.trim();
  text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');
  text = text.replaceFirst(RegExp(r'^Bad response from [^:]+:\s*'), '');
  // Срезаем префикс ЛЮБОГО RPC-неймспейса (был только Storage.) — иначе
  // ошибки Notification./ObjectStorage./AiQueue. показывались с техничным
  // «Notification.SendNotification: …» в начале (баг приглашения в штат).
  text = text.replaceFirst(
    RegExp(r'^(?:Storage|Notification|ObjectStorage|AiQueue)\.[A-Za-z0-9_]+:\s*'),
    '',
  );
  return text.trim();
}

String? _errorCode(Object error, String rawText) {
  if (error is CompanySpecialistUnlinkException && error.code.isNotEmpty) {
    return error.code;
  }

  final cleaned = _cleanTechnicalText(rawText);
  RegExpMatch? codeMatch;
  for (final match in RegExp(
    r'\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b',
  ).allMatches(cleaned)) {
    codeMatch = match;
  }
  return codeMatch?.group(0);
}

String? _errorMethod(String rawText) {
  final match = RegExp(
    r'\b(?:Storage|Notification|ObjectStorage|AiQueue)\.[A-Za-z0-9_]+\b',
  ).firstMatch(rawText);
  return match?.group(0);
}

String? _mappedBackendError(String? code, {int? activeAssignedRequests}) {
  if (code == null || code.isEmpty) return null;
  final normalized = code.trim().toLowerCase();
  return switch (normalized) {
    'request_status_does_not_allow_cancel' =>
      'Заявку нельзя отменить в текущем статусе',
    'request_status_does_not_allow_accept' =>
      'Заявку нельзя принять в текущем статусе',
    'request_status_does_not_allow_reject' =>
      'Заявку нельзя отклонить в текущем статусе',
    'request_status_does_not_allow_abandon' =>
      'Заявку нельзя отметить как не выполненную в текущем статусе',
    'request_status_is_final' => 'Заявка уже находится в финальном статусе',
    'request_not_found' => 'Заявка не найдена',
    'request_not_assigned_to_user' => 'Заявка назначена другому специалисту',
    'completed_report_not_found' => 'Готовый отчёт по заявке не найден',
    'report_not_found' => 'Отчёт не найден',
    'specialist_not_found' => 'Специалист не найден',
    'specialist_not_in_company' => 'Специалист не состоит в штате компании',
    'specialist_not_found_or_not_linked_to_your_company' =>
      'Сотрудник не найден в штате компании',
    'specialist_has_active_assigned_requests' => _activeRequestsMessage(
      activeAssignedRequests,
    ),
    'company_specialist_already_exists' =>
      'Этот специалист уже состоит в штате компании',
    'user_already_in_company' => 'Пользователь уже состоит в компании',
    'user_already_has_company' => 'Пользователь уже привязан к компании',
    'user_not_found' => 'Пользователь не найден',
    'company_not_found' => 'Компания не найдена',
    'already_assigned' => 'Этот специалист уже назначен на заявку',
    'already_exists' => 'Такая запись уже существует',
    'not_found' => 'Запись не найдена',
    'invalid_phone' => 'Укажите корректный номер телефона',
    'phone_required' => 'Укажите номер телефона',
    'invalid_email' => 'Укажите корректный email',
    'email_already_exists' => 'Этот email уже зарегистрирован',
    'email_already_in_use' => 'Этот email уже зарегистрирован',
    'email_already_registered' => 'Этот email уже зарегистрирован',
    'email_taken' => 'Этот email уже зарегистрирован',
    'email_exists' => 'Этот email уже зарегистрирован',
    'email_in_use' => 'Этот email уже зарегистрирован',
    'invalid_url' => 'Укажите корректную ссылку',
    'invalid_city' => 'Выберите город из списка',
    'invalid_vin' => 'Проверьте VIN',
    'validation_error' => 'Проверьте заполненные данные',
    'bad_request' => 'Проверьте данные и повторите действие',
    'permission_denied' => 'Недостаточно прав для этого действия',
    'access_denied' => 'Нет доступа к этому действию',
    'forbidden' => 'Нет доступа к этому действию',
    'unauthorized' => 'Сессия истекла. Войдите заново.',
    'token_expired' => 'Сессия истекла. Войдите заново.',
    'too_many_requests' => 'Слишком много запросов. Повторите позже.',
    'rate_limit_exceeded' => 'Слишком много запросов. Повторите позже.',
    'report_incomplete' => 'Отчёт заполнен не полностью',
    'required_fields_missing' => 'Заполните обязательные поля',
    'missing_required_fields' => 'Заполните обязательные поля',
    'specialist_required' => 'Назначьте специалиста',
    'city_required' => 'Укажите город',
    'vin_required' => 'Укажите VIN или отметьте, что он нечитаемый',
    'file_type_not_allowed' => 'Этот тип файла нельзя прикрепить',
    'video_not_allowed' => 'Видео нельзя прикрепить к заявке',
    'unsupported_file_type' => 'Этот тип файла не поддерживается',
    'payload_too_large' => 'Слишком большой объём данных',
    'file_too_large' => 'Файл слишком большой',
    'checksum_mismatch' => 'Контрольная сумма файла не совпала',
    _ => _genericBackendCodeMessage(normalized),
  };
}

String _genericBackendCodeMessage(String code) {
  final words = code
      .split(RegExp(r'[_\s.-]+'))
      .map((word) => word.trim().toLowerCase())
      .where((word) => word.isNotEmpty)
      .toSet();
  final entity = _entityLabel(words);

  if (_hasAll(words, const ['status', 'does', 'not', 'allow']) ||
      _hasAll(words, const ['status', 'not', 'allowed'])) {
    return entity == null
        ? 'Действие недоступно в текущем статусе'
        : '$entity: действие недоступно в текущем статусе';
  }
  if (_hasAll(words, const ['not', 'found'])) {
    return entity == null ? 'Запись не найдена' : _notFoundMessage(entity);
  }
  if (words.contains('required') || words.contains('missing')) {
    return entity == null
        ? 'Заполните обязательные данные'
        : 'Заполните обязательное поле: $entity';
  }
  if (words.contains('invalid')) {
    return entity == null ? 'Проверьте данные' : 'Проверьте поле: $entity';
  }
  if (words.contains('already') &&
      (words.contains('exists') ||
          words.contains('assigned') ||
          words.contains('linked'))) {
    return entity == null
        ? 'Такая запись уже существует'
        : '$entity уже указана';
  }
  if (words.contains('permission') ||
      words.contains('forbidden') ||
      words.contains('denied') ||
      words.contains('access')) {
    return 'Недостаточно прав для этого действия';
  }
  if (words.contains('expired')) return 'Срок действия истёк';
  if (words.contains('large')) return 'Слишком большой объём данных';
  if (words.contains('unsupported') || words.contains('allowed')) {
    return 'Действие не поддерживается';
  }

  final readable = _humanizeUnknownCode(code);
  return readable.isEmpty
      ? 'Не удалось выполнить действие. Код ошибки: $code'
      : 'Не удалось выполнить действие: $readable';
}

String _notFoundMessage(String entity) {
  return switch (entity) {
    'Заявка' => 'Заявка не найдена',
    'Компания' => 'Компания не найдена',
    'Ссылка' => 'Ссылка не найдена',
    'Запись' => 'Запись не найдена',
    'Уведомление' => 'Уведомление не найдено',
    _ => '$entity не найден',
  };
}

bool _hasAll(Set<String> words, List<String> expected) {
  return expected.every(words.contains);
}

String? _entityLabel(Set<String> words) {
  if (words.contains('phone')) return 'Телефон';
  if (words.contains('email')) return 'Email';
  if (words.contains('city')) return 'Город';
  if (words.contains('vin')) return 'VIN';
  if (words.contains('url') || words.contains('link')) return 'Ссылка';
  if (words.contains('request')) return 'Заявка';
  if (words.contains('report')) return 'Отчёт';
  if (words.contains('specialist')) return 'Специалист';
  if (words.contains('company')) return 'Компания';
  if (words.contains('user')) return 'Пользователь';
  if (words.contains('profile')) return 'Профиль';
  if (words.contains('notification')) return 'Уведомление';
  if (words.contains('file') || words.contains('attachment')) return 'Файл';
  return null;
}

String _humanizeUnknownCode(String code) {
  final labels = <String, String>{
    'request': 'заявка',
    'report': 'отчёт',
    'specialist': 'специалист',
    'company': 'компания',
    'user': 'пользователь',
    'profile': 'профиль',
    'notification': 'уведомление',
    'file': 'файл',
    'attachment': 'файл',
    'phone': 'телефон',
    'email': 'email',
    'city': 'город',
    'vin': 'VIN',
    'url': 'ссылка',
    'link': 'ссылка',
    'status': 'статус',
    'invalid': 'некорректный',
    'required': 'обязательное поле',
    'missing': 'не заполнено',
    'not': 'не',
    'found': 'найдено',
    'already': 'уже',
    'exists': 'существует',
    'assigned': 'назначено',
    'allowed': 'разрешено',
    'expired': 'истёк срок',
    'permission': 'права доступа',
    'denied': 'отказано',
  };
  return code
      .split(RegExp(r'[_\s.-]+'))
      .map((word) => labels[word] ?? word)
      .where((word) => word.trim().isNotEmpty)
      .join(' ');
}

String _activeRequestsMessage(int? count) {
  if (count == null || count <= 0) {
    return 'Нельзя удалить сотрудника: у него есть активные заявки';
  }
  return 'Нельзя удалить сотрудника: активных заявок $count';
}

/// Внутренний код для распознанного бизнес-кода бэка: почти все — SRV-04,
/// кроме кодов, по смыслу совпадающих с транспортными классами (сессия,
/// права, rate limit) — им отдаём профильный код, чтобы поддержка сразу
/// видела класс проблемы.
String _internalCodeForBackendCode(String backendCode) {
  return switch (backendCode.trim().toLowerCase()) {
    'unauthorized' || 'token_expired' => SparkJoyErrorCode.authSession,
    'permission_denied' ||
    'access_denied' ||
    'forbidden' => SparkJoyErrorCode.authForbidden,
    'too_many_requests' ||
    'rate_limit_exceeded' => SparkJoyErrorCode.serverRateLimited,
    _ => SparkJoyErrorCode.serverRejected,
  };
}

/// Классифицирует техническое сообщение без бизнес-кода бэка в пару
/// «читаемое сообщение + внутренний код». Порядок проверок важен:
/// специфичные сетевые случаи (TLS, DNS, таймаут) — раньше общего
/// SocketException/ClientException.
({String message, String code}) _classifyGeneric(String rawMessage) {
  final lower = rawMessage.toLowerCase();
  if (lower.contains('sessionexpiredexception') ||
      lower.contains('session expired')) {
    return (
      message: 'Сессия истекла. Войдите заново.',
      code: SparkJoyErrorCode.authSession,
    );
  }
  // TLS раньше таймаута и общей сети: «connection terminated during
  // handshake» содержит и сетевые слова. Сюда же попадает устаревший
  // cert-pin старого билда — поэтому совет «обновите приложение».
  if (lower.contains('handshakeexception') ||
      lower.contains('handshake') ||
      lower.contains('certificate')) {
    return (
      message:
          'Не удалось установить защищённое соединение. Обновите приложение '
          'до последней версии или попробуйте другую сеть.',
      code: SparkJoyErrorCode.netTls,
    );
  }
  if (lower.contains('failed host lookup') ||
      lower.contains('no address associated') ||
      lower.contains('network is unreachable') ||
      lower.contains('no route to host') ||
      lower.contains('network changed')) {
    return (
      message: 'Нет подключения к интернету. Проверьте связь и повторите.',
      code: SparkJoyErrorCode.netNoConnection,
    );
  }
  if (lower.contains('timed out') || lower.contains('timeout')) {
    return (
      message: 'Сервер не ответил вовремя. Проверьте подключение и повторите.',
      code: SparkJoyErrorCode.netTimeout,
    );
  }
  if (lower.contains('connection refused')) {
    return (
      message: 'Не удалось подключиться к серверу. Попробуйте позже.',
      code: SparkJoyErrorCode.netRefused,
    );
  }
  if (lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('connection abort') ||
      lower.contains('broken pipe') ||
      lower.contains('connection terminated')) {
    return (
      message: 'Соединение с сервером прервалось. Повторите попытку.',
      code: SparkJoyErrorCode.netInterrupted,
    );
  }
  if (lower.contains('http 401')) {
    return (
      message: 'Сессия истекла. Войдите заново.',
      code: SparkJoyErrorCode.authSession,
    );
  }
  if (lower.contains('http 403')) {
    return (
      message: 'Нет доступа к действию. Войдите заново или обратитесь в '
          'поддержку.',
      code: SparkJoyErrorCode.authForbidden,
    );
  }
  if (lower.contains('http 429')) {
    return (
      message: 'Слишком много запросов. Подождите минуту и повторите.',
      code: SparkJoyErrorCode.serverRateLimited,
    );
  }
  if (lower.contains('http 500') ||
      lower.contains('http 502') ||
      lower.contains('http 503') ||
      lower.contains('http 504') ||
      lower.contains('bad gateway')) {
    return (
      message: 'Сервер временно недоступен. Повторите позже.',
      code: SparkJoyErrorCode.serverUnavailable,
    );
  }
  if (lower.contains('invalid json response')) {
    return (
      message: 'Сервер вернул некорректный ответ. Повторите позже.',
      code: SparkJoyErrorCode.serverBadResponse,
    );
  }
  if (lower.contains('empty response body')) {
    return (
      message: 'Сервер вернул пустой ответ. Повторите позже.',
      code: SparkJoyErrorCode.serverBadResponse,
    );
  }
  if (lower.contains('bad response from')) {
    return (
      message: 'Сервер не подтвердил выполнение действия',
      code: SparkJoyErrorCode.serverBadResponse,
    );
  }
  if (lower.contains('upload failed')) {
    return (
      message: 'Не удалось загрузить файл. Повторите позже.',
      code: SparkJoyErrorCode.fileUploadFailed,
    );
  }
  if (lower.contains('presigned url is empty') ||
      lower.contains('part url not found') ||
      lower.contains('missing etag')) {
    return (
      message: 'Не удалось подготовить загрузку файла. Повторите позже.',
      code: SparkJoyErrorCode.fileUploadFailed,
    );
  }
  if (lower.contains('success=false')) {
    return (
      message: 'Сервер не подтвердил выполнение действия',
      code: SparkJoyErrorCode.serverBadResponse,
    );
  }
  // Приглашение в штат (Notification.SendNotification) — бэк отдаёт текст на
  // английском. Маппим в понятное и НЕпугающее сообщение: дубль приглашения
  // не «ошибка», а сигнал «уже отправлено, ждём принятия».
  if (lower.contains('pending invitation') &&
      (lower.contains('already exist') || lower.contains('already sent'))) {
    return (
      message:
          'Этому специалисту уже отправлено приглашение — оно ожидает '
          'принятия.',
      code: SparkJoyErrorCode.serverRejected,
    );
  }
  if (lower.contains('invitation') &&
      (lower.contains('already') || lower.contains('exists'))) {
    return (
      message: 'Приглашение этому специалисту уже отправлено.',
      code: SparkJoyErrorCode.serverRejected,
    );
  }
  if (lower.contains('already') &&
      lower.contains('specialist') &&
      (lower.contains('compan') || lower.contains('staff'))) {
    return (
      message: 'Этот специалист уже состоит в штате компании.',
      code: SparkJoyErrorCode.serverRejected,
    );
  }
  // Общая сеть — после всех специфичных сетевых веток выше.
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed to fetch') ||
      lower.contains('transport')) {
    return (
      message:
          'Не удалось подключиться к серверу. Проверьте интернет и повторите.',
      code: SparkJoyErrorCode.netGeneric,
    );
  }
  return (
    message: rawMessage.isEmpty ? 'Неизвестная ошибка' : rawMessage,
    code: SparkJoyErrorCode.unknown,
  );
}

String _withFallback(String? fallback, String message) {
  final prefix = (fallback ?? '').trim();
  if (prefix.isEmpty) return message;
  if (message.toLowerCase().startsWith(prefix.toLowerCase())) {
    return message;
  }
  return '$prefix: $message';
}

String _supportText({
  required String message,
  required String rawText,
  required String code,
  String? backendCode,
}) {
  final cleanRaw = rawText.trim();
  final cleanBackendCode = (backendCode ?? '').trim();
  final method = _errorMethod(cleanRaw);
  final lines = <String>[
    'Код: $code',
    'Сообщение: $message',
    if (cleanBackendCode.isNotEmpty) 'Код сервера: $cleanBackendCode',
    if (method != null && method.isNotEmpty) 'Метод: $method',
    if (cleanRaw.isNotEmpty && cleanRaw != message)
      'Техническая ошибка: $cleanRaw',
  ];
  return lines.join('\n');
}

/// Копируемый support-текст для ошибки выгрузки отчёта: код + сообщение +
/// контекст (номер отчёта, этап выгрузки, время, техническая ошибка) — всё,
/// что нужно поддержке для поиска инцидента в логах сервера.
String sparkJoyUploadSupportText({
  required String code,
  required String message,
  String technical = '',
  String reportNumber = '',
  String stage = '',
  DateTime? timestamp,
}) {
  final cleanTechnical = technical.trim();
  final lines = <String>[
    'Ошибка выгрузки отчёта',
    'Код: ${code.trim().isEmpty ? SparkJoyErrorCode.unknown : code.trim()}',
    'Сообщение: ${message.trim()}',
    if (reportNumber.trim().isNotEmpty) 'Отчёт: ${reportNumber.trim()}',
    if (stage.trim().isNotEmpty) 'Этап: ${stage.trim()}',
    if (timestamp != null) 'Время: ${timestamp.toIso8601String()}',
    if (cleanTechnical.isNotEmpty && cleanTechnical != message.trim())
      'Техническая ошибка: $cleanTechnical',
  ];
  return lines.join('\n');
}

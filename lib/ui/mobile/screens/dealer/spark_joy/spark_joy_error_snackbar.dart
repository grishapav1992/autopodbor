import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart'
    show PermissionDeniedException;
import 'package:flutter_application_1/data/api/storage_api_models.dart';

typedef SparkJoyReadableError = ({String message, String supportText});

SparkJoyReadableError sparkJoyReadableError(Object error, {String? fallback}) {
  // RBAC: a backend permission denial (HTTP 403 / forbidden RPC) always maps
  // to the same clean message regardless of which method was blocked — the
  // method name stays in the copyable support text for diagnostics.
  if (error is PermissionDeniedException) {
    const msg = 'Недостаточно прав для этого действия';
    final support = <String>[
      'Сообщение: $msg',
      'Метод: ${error.method}',
      if (error.serverMessage.trim().isNotEmpty)
        'Техническая ошибка: ${error.serverMessage.trim()}',
    ].join('\n');
    return (message: _withFallback(fallback, msg), supportText: support);
  }
  final rawText = _rawErrorText(error);
  final code = _errorCode(error, rawText);
  final mapped = _mappedBackendError(
    code,
    activeAssignedRequests: error is CompanySpecialistUnlinkException
        ? error.activeAssignedRequests
        : null,
  );
  final rawMessage = _cleanTechnicalText(rawText);
  final message = _withFallback(
    fallback,
    mapped ?? _genericReadableMessage(rawMessage),
  );

  return (
    message: message,
    supportText: _supportText(message: message, rawText: rawText, code: code),
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Expanded(child: Text(readable.message)),
          IconButton(
            tooltip: 'Скопировать ошибку',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: readable.supportText));
            },
            icon: const Icon(Icons.copy_rounded),
            color: kWhiteColor,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      backgroundColor: kRedColor,
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
  text = text.replaceFirst(RegExp(r'^Storage\.[A-Za-z0-9_]+:\s*'), '');
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

String _genericReadableMessage(String rawMessage) {
  final lower = rawMessage.toLowerCase();
  if (lower.contains('sessionexpiredexception') ||
      lower.contains('session expired')) {
    return 'Сессия истекла. Войдите заново.';
  }
  if (lower.contains('timeout')) {
    return 'Сервер не ответил вовремя. Проверьте подключение и повторите.';
  }
  if (lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('transport')) {
    return 'Не удалось подключиться к серверу. Проверьте интернет и повторите.';
  }
  if (lower.contains('http 401') || lower.contains('http 403')) {
    return 'Нет доступа к действию. Войдите заново или обратитесь в поддержку.';
  }
  if (lower.contains('invalid json response')) {
    return 'Сервер вернул некорректный ответ. Повторите позже.';
  }
  if (lower.contains('empty response body')) {
    return 'Сервер вернул пустой ответ. Повторите позже.';
  }
  if (lower.contains('bad response from')) {
    return 'Сервер не подтвердил выполнение действия';
  }
  if (lower.contains('upload failed')) {
    return 'Не удалось загрузить файл. Повторите позже.';
  }
  if (lower.contains('presigned url is empty') ||
      lower.contains('part url not found') ||
      lower.contains('missing etag')) {
    return 'Не удалось подготовить загрузку файла. Повторите позже.';
  }
  if (lower.contains('http 500') ||
      lower.contains('http 502') ||
      lower.contains('http 503') ||
      lower.contains('http 504')) {
    return 'Сервер временно недоступен. Повторите позже.';
  }
  if (lower.contains('success=false')) {
    return 'Сервер не подтвердил выполнение действия';
  }
  return rawMessage.isEmpty ? 'Неизвестная ошибка' : rawMessage;
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
  String? code,
}) {
  final cleanRaw = rawText.trim();
  final cleanCode = (code ?? '').trim();
  final method = _errorMethod(cleanRaw);
  final lines = <String>[
    'Сообщение: $message',
    if (cleanCode.isNotEmpty) 'Код ошибки: $cleanCode',
    if (method != null && method.isNotEmpty) 'Метод: $method',
    if (cleanRaw.isNotEmpty && cleanRaw != message)
      'Техническая ошибка: $cleanRaw',
  ];
  return lines.join('\n');
}

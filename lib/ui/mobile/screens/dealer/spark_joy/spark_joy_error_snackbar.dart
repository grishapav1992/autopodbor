import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api_models.dart';

typedef SparkJoyReadableError = ({String message, String supportText});

SparkJoyReadableError sparkJoyReadableError(Object error, {String? fallback}) {
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
    supportText: _supportText(message: message, rawText: rawText),
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
      content: Text(readable.message),
      backgroundColor: kRedColor,
      action: SnackBarAction(
        label: 'Скопировать',
        textColor: kWhiteColor,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: readable.supportText));
        },
      ),
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

String? _mappedBackendError(String? code, {int? activeAssignedRequests}) {
  if (code == null || code.isEmpty) return null;
  return switch (code) {
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
    'user_not_found' => 'Пользователь не найден',
    'company_not_found' => 'Компания не найдена',
    'already_assigned' => 'Этот специалист уже назначен на заявку',
    'file_too_large' => 'Файл слишком большой',
    'checksum_mismatch' => 'Контрольная сумма файла не совпала',
    _ => 'Не удалось выполнить действие. Код ошибки: $code',
  };
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

String _supportText({required String message, required String rawText}) {
  final cleanRaw = rawText.trim();
  if (cleanRaw.isEmpty || cleanRaw == message) return message;
  return '$message\n\nТехническая ошибка: $cleanRaw';
}

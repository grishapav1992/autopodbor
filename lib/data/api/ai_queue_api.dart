/// Транспортный клиент `https://aiqueue.ru.tuna.am`.
///
/// AiQueue — отдельный JSON-RPC 2.0 сервис для AI-помощника
/// автоподборщика. Подробности схемы — в
/// `docs/api/AiQueue_Client_Integration.md` и
/// `docs/openrpc_aiqueue_doc_2026-04-24.json`.
///
/// Особенности транспорта (важно — отличается от [StorageApi]):
///   • Авторизация через query-параметр `?token=<jwt>`, **не** Bearer header.
///   • Content-Type `text/plain;charset=UTF-8` (не `application/json`).
///   • Поле `id` в payload — это **chatId**, а не обычный JSON-RPC id.
///     Один и тот же `id` означает «продолжить ту же историю чата».
///   • Ответ всегда в обёртке `{id, response, fromMethod, result, errors}`.
///     Пустой массив `errors: []` = успех. Если `errors` непустой
///     (массив или объект — сервер не консистентен) — ошибка.
///
/// Token reuse: использует тот же access-token, что [StorageApi]
/// (хранится в [UserSimplePreferences]). При 401-ответе пытается
/// принудительно проверить сессию через [StorageApi.hasSavedSession],
/// которая сама делает refresh + cleanup и при `false` уже эмитит
/// `sessionExpiredTicker`.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/data/api/storage_api.dart'
    show SessionExpiredException, StorageApi, sessionExpiredTicker;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

/// Доменная ошибка AiQueue. Бросается на любой непустой `errors`
/// в ответе, плюс на сетевые / парсерные сбои. UI должен показывать
/// [userMessage]; полная диагностика — в [diagnosticMessage].
class AiQueueException implements Exception {
  const AiQueueException({
    required this.userMessage,
    required this.diagnosticMessage,
    this.code,
  });

  /// Текст для пользователя (RU). Намеренно общий — детали внутри
  /// логов и [diagnosticMessage].
  final String userMessage;

  /// Полное техническое сообщение (для логов и админки). Содержит
  /// код ошибки и оригинальный текст, не показывать пользователю.
  final String diagnosticMessage;

  /// Код ошибки (если сервер прислал) или `null` для сетевых сбоев.
  final String? code;

  @override
  String toString() => 'AiQueueException(code=$code): $diagnosticMessage';
}

/// Один turn в истории чата. Сервер пришлёт `role + content` —
/// формат соответствует OpenAI Chat Completions message.
class AiQueueChatMessage {
  const AiQueueChatMessage({
    required this.role,
    required this.content,
  });

  /// `'system' | 'user' | 'assistant'`. Не нормализуем enum'ом
  /// сознательно — backend может добавить роли (`tool` / `function`)
  /// без релиза клиента.
  final String role;
  final String content;

  factory AiQueueChatMessage.fromJson(Map<String, dynamic> json) {
    return AiQueueChatMessage(
      role: (json['role'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// История одного чата (chatId). [messages] — turns в порядке от
/// первого к последнему.
class AiQueueChatHistory {
  const AiQueueChatHistory({
    required this.chatId,
    required this.messages,
    this.model,
    this.updatedAt,
  });

  final int chatId;
  final List<AiQueueChatMessage> messages;
  final String? model;
  final DateTime? updatedAt;

  bool get isEmpty => messages.isEmpty;

  factory AiQueueChatHistory.fromJson(int chatId, Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final list = <AiQueueChatMessage>[];
    if (rawMessages is List) {
      for (final m in rawMessages) {
        if (m is Map<String, dynamic>) {
          list.add(AiQueueChatMessage.fromJson(m));
        } else if (m is Map) {
          list.add(AiQueueChatMessage.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }
    return AiQueueChatHistory(
      chatId: chatId,
      messages: list,
      model: json['model']?.toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
    );
  }
}

/// Список доступных моделей + дефолтная.
class AiQueueModelsResult {
  const AiQueueModelsResult({required this.models, required this.defaultModel});
  final List<String> models;
  final String defaultModel;
}

/// Результат `ChatCompletions`. `text` — полный ответ AI; backend
/// может вернуть и доп. поля (`messages`, `usage`), мы их кладём
/// в [raw] на случай если UI захочет показать.
class AiQueueChatCompletionResult {
  const AiQueueChatCompletionResult({required this.text, required this.raw});
  final String text;
  final Map<String, dynamic> raw;
}

/// Глобальный nonce для wire-format `id` запросов, **не** chatId.
/// Используется только для методов без chatId (Models, Health, и т.п.)
/// чтобы каждый payload имел свой уникальный id.
int _nonceSeq = DateTime.now().microsecondsSinceEpoch;
int _nextNonce() {
  _nonceSeq += 1;
  return _nonceSeq;
}

class AiQueueApi {
  AiQueueApi._();

  static const String _endpoint = 'https://aiqueue.ru.tuna.am';
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Models-кэш. Запрос лёгкий, но всё равно делаем не чаще раза в час
  /// — список моделей очень редко меняется, а UI может его дёргать
  /// на каждом открытии диалога.
  static AiQueueModelsResult? _modelsCache;
  static DateTime? _modelsCacheAt;
  static const Duration _modelsCacheTtl = Duration(hours: 1);

  /// Тикер для observers (UI), который инкрементируется при каждом
  /// успешном `ChatCompletions`. Полезен для ручной инвалидации
  /// кэшей histories.
  static final ValueNotifier<int> chatCompletionsTicker = ValueNotifier<int>(0);

  /// Health-чек. Не требует авторизации (по спеке).
  static Future<bool> health() async {
    try {
      final result = await _post(
        method: 'AiQueue.Health',
        chatId: _nextNonce(),
        params: const {},
        includeAuth: false,
      );
      final inner = result['result'];
      if (inner is Map && inner['status'] == 'ok') return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Список моделей с in-memory TTL-кэшем.
  static Future<AiQueueModelsResult> models({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _modelsCache != null &&
        _modelsCacheAt != null &&
        now.difference(_modelsCacheAt!) < _modelsCacheTtl) {
      return _modelsCache!;
    }
    final result = await _post(
      method: 'AiQueue.Models',
      chatId: _nextNonce(),
      params: const {},
    );
    final inner = _asMap(result['result']);
    final rawModels = inner['models'];
    final list = <String>[];
    if (rawModels is List) {
      for (final m in rawModels) {
        if (m is Map && m['id'] != null) {
          list.add(m['id'].toString());
        } else if (m is String && m.isNotEmpty) {
          list.add(m);
        }
      }
    }
    final parsed = AiQueueModelsResult(
      models: list,
      defaultModel: (inner['default'] ?? '').toString(),
    );
    _modelsCache = parsed;
    _modelsCacheAt = now;
    return parsed;
  }

  /// Основной метод per-element / summary AI-помощника.
  /// [chatId] — стабильный идентификатор истории на стороне сервера.
  /// Один и тот же id = продолжение диалога; новый id = новый чат.
  /// [text] подставится в `cliche` сервером в плейсхолдер `{text}`.
  /// [fileUrls] — presigned S3 URL уже залитых файлов (фото/аудио).
  static Future<AiQueueChatCompletionResult> chatCompletions({
    required int chatId,
    required String text,
    required String cliche,
    List<String>? fileUrls,
    String? model,
    Duration timeout = _defaultTimeout,
  }) async {
    final params = <String, dynamic>{
      'text': text,
      'cliche': cliche,
      if (fileUrls != null && fileUrls.isNotEmpty) 'fileUrls': fileUrls,
      if (model != null && model.isNotEmpty) 'model': model,
    };
    final result = await _post(
      method: 'AiQueue.ChatCompletions',
      chatId: chatId,
      params: params,
      timeout: timeout,
    );
    final inner = _asMap(result['result']);
    // Backend пока не определился со shape: `text` лежит то в
    // `result.text`, то в `result.message.content`. Пытаемся оба.
    String resolvedText = (inner['text'] ?? '').toString();
    if (resolvedText.isEmpty) {
      final message = inner['message'];
      if (message is Map) {
        resolvedText = (message['content'] ?? '').toString();
      }
    }
    if (resolvedText.isEmpty) {
      // Финальный фолбэк — вытащить assistant-turn из messages
      final messages = inner['messages'];
      if (messages is List) {
        for (final m in messages.reversed) {
          if (m is Map && m['role'] == 'assistant') {
            resolvedText = (m['content'] ?? '').toString();
            break;
          }
        }
      }
    }
    chatCompletionsTicker.value = chatCompletionsTicker.value + 1;
    return AiQueueChatCompletionResult(
      text: resolvedText,
      raw: inner,
    );
  }

  /// Удаляет историю одного чата. Следующий `ChatCompletions` с
  /// тем же [chatId] начнёт с нуля.
  static Future<void> clearChatHistory(int chatId) async {
    await _post(
      method: 'AiQueue.ClearChatHistory',
      chatId: _nextNonce(),
      params: {'chatId': chatId},
    );
  }

  /// Подтягивает истории нескольких чатов разом. Возвращает
  /// `{chatId: history}`. ChatId'ы у которых TTL истёк просто не
  /// попадут в map — caller должен обрабатывать это мягко.
  static Future<Map<int, AiQueueChatHistory>> getChatHistories(
    List<int> chatIds,
  ) async {
    if (chatIds.isEmpty) return const <int, AiQueueChatHistory>{};
    final result = await _post(
      method: 'AiQueue.GetChatHistories',
      chatId: _nextNonce(),
      params: {'ids': chatIds},
    );
    final inner = _asMap(result['result']);
    final chats = inner['chats'];
    final out = <int, AiQueueChatHistory>{};
    if (chats is Map) {
      chats.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id == null) return;
        if (value is Map<String, dynamic>) {
          out[id] = AiQueueChatHistory.fromJson(id, value);
        } else if (value is Map) {
          out[id] = AiQueueChatHistory.fromJson(
            id,
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    return out;
  }

  // ── Internals ──────────────────────────────────────────────────────

  /// Универсальный POST. Возвращает декодированный response-объект
  /// (полная обёртка `{id, response, fromMethod, result, errors}`).
  /// При непустом `errors` бросает [AiQueueException].
  static Future<Map<String, dynamic>> _post({
    required String method,
    required int chatId,
    required Map<String, dynamic> params,
    bool includeAuth = true,
    bool allowRetry = true,
    Duration timeout = _defaultTimeout,
  }) async {
    final uri = await _buildUri(includeAuth: includeAuth);
    if (uri == null) {
      throw const AiQueueException(
        userMessage: 'Не удалось авторизоваться в AI-помощнике',
        diagnosticMessage: 'access token missing for AiQueue',
        code: 'no_token',
      );
    }
    final body = jsonEncode({
      'jsonrpc': '2.0', // спека в Doc-тексте говорит без поля, но сервер
      // в реальности принимает (мы это проверили в probe). Шлём для
      // совместимости с возможными RPC-клиентами на стороне сервера.
      'id': chatId,
      'method': method,
      'params': params,
    });
    _log('send', method: method, chatId: chatId, extra: 'bytes=${body.length}');

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const {
              // Спека требует именно text/plain — не application/json.
              'Content-Type': 'text/plain;charset=UTF-8',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      _log('timeout', method: method, chatId: chatId, extra: e.toString());
      throw AiQueueException(
        userMessage: 'AI-помощник не отвечает, попробуйте ещё раз',
        diagnosticMessage: 'timeout: $e',
        code: 'timeout',
      );
    } catch (e) {
      _log('network-error', method: method, chatId: chatId, extra: e.toString());
      throw AiQueueException(
        userMessage: 'Нет связи с AI-помощником',
        diagnosticMessage: 'network: $e',
        code: 'network',
      );
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is! Map<String, dynamic>) {
        throw FormatException('not an object: ${response.body}');
      }
      decoded = raw;
    } catch (e) {
      _log('parse-error', method: method, chatId: chatId, extra: '$e');
      throw AiQueueException(
        userMessage: 'AI-помощник вернул некорректный ответ',
        diagnosticMessage: 'parse: $e body=${response.body}',
        code: 'parse',
      );
    }

    // Errors могут прийти и массивом, и объектом ({"message": "..."})
    // — сервер не консистентен. Парсим оба варианта.
    final errors = decoded['errors'];
    String? errorMessage;
    String? errorCode;
    if (errors is Map && errors.isNotEmpty) {
      errorMessage = (errors['message'] ?? '').toString();
      errorCode = (errors['code'] ?? '').toString();
    } else if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map) {
        errorMessage = (first['message'] ?? '').toString();
        errorCode = (first['code'] ?? '').toString();
      } else {
        errorMessage = first.toString();
      }
    }

    if (errorMessage != null && errorMessage.isNotEmpty) {
      _log(
        'rpc-error',
        method: method,
        chatId: chatId,
        extra: 'code=$errorCode msg=$errorMessage status=${response.statusCode}',
      );
      // Auth-related — пытаемся обновить токен один раз и повторить.
      final isAuthErr = _looksLikeAuthError(
        statusCode: response.statusCode,
        message: errorMessage,
        code: errorCode,
      );
      if (isAuthErr && allowRetry && includeAuth) {
        final refreshed = await StorageApi.hasSavedSession();
        if (refreshed) {
          return _post(
            method: method,
            chatId: chatId,
            params: params,
            includeAuth: includeAuth,
            allowRetry: false,
            timeout: timeout,
          );
        }
        // Сессия мертва — разблокируем глобальный listener,
        // shell редиректнёт на login.
        sessionExpiredTicker.value = sessionExpiredTicker.value + 1;
        throw const SessionExpiredException();
      }
      throw AiQueueException(
        userMessage: _userMessageFor(errorCode, errorMessage),
        diagnosticMessage: '[$errorCode] $errorMessage',
        code: errorCode,
      );
    }

    _log(
      'ok',
      method: method,
      chatId: chatId,
      extra: 'status=${response.statusCode}',
    );
    return decoded;
  }

  /// Строит URI с подставленным `?token=<jwt>` или без, если
  /// [includeAuth] = false.
  static Future<Uri?> _buildUri({required bool includeAuth}) async {
    final base = Uri.parse(_endpoint);
    if (!includeAuth) return base;
    final token = await UserSimplePreferences.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return base.replace(queryParameters: {'token': token});
  }

  static bool _looksLikeAuthError({
    required int statusCode,
    required String message,
    String? code,
  }) {
    if (statusCode == 401 || statusCode == 403) return true;
    final lc = message.toLowerCase();
    if (lc.contains('unauthor') ||
        lc.contains('forbidden') ||
        lc.contains('token')) {
      return true;
    }
    final lcCode = (code ?? '').toLowerCase();
    return lcCode.contains('unauthor') || lcCode.contains('auth');
  }

  static String _userMessageFor(String? code, String message) {
    if (message.toLowerCase().contains('rate')) {
      return 'Слишком много запросов к AI-помощнику. Подождите немного.';
    }
    if (message.toLowerCase().contains('model')) {
      return 'AI-модель временно недоступна.';
    }
    return 'AI-помощник вернул ошибку. Попробуйте ещё раз.';
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static void _log(
    String stage, {
    required String method,
    required int chatId,
    String extra = '',
  }) {
    final now = DateTime.now().toIso8601String();
    developer.log(
      '[aiqueue][$now][$stage][$method][chat=$chatId] $extra',
      name: 'AiQueueApi.rpc',
    );
  }
}

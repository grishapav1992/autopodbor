import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LlmProfileGuardResult {
  const LlmProfileGuardResult({
    required this.checked,
    required this.blocked,
    required this.errors,
    this.note,
  });

  final bool checked;
  final bool blocked;
  final List<String> errors;
  final String? note;
}

class LlmServerStatus {
  const LlmServerStatus({required this.online, required this.message});

  final bool online;
  final String message;
}

class LlmChatResult {
  const LlmChatResult({required this.success, this.answer, this.error});

  final bool success;
  final String? answer;
  final String? error;
}

/// Calls local llama.cpp OpenAI-compatible endpoint to detect hidden contacts.
class LocalLlmProfileGuardApi {
  LocalLlmProfileGuardApi({
    http.Client? client,
    String? endpoint,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? _defaultEndpoint(),
       _timeout = timeout ?? const Duration(seconds: 20);

  final http.Client _client;
  final String _endpoint;
  final Duration _timeout;

  static String _defaultEndpoint() {
    if (kIsWeb) return 'http://127.0.0.1:8081/v1/chat/completions';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator to host machine.
        return 'http://10.0.2.2:8081/v1/chat/completions';
      default:
        return 'http://127.0.0.1:8081/v1/chat/completions';
    }
  }

  Future<LlmServerStatus> checkServerStatus() async {
    try {
      final endpoint = Uri.parse(_endpoint);
      final modelsEndpoint = endpoint.replace(path: '/v1/models', query: null);
      final response = await _client.get(modelsEndpoint).timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const LlmServerStatus(
          online: true,
          message: 'Нейросеть: подключена',
        );
      }

      return LlmServerStatus(
        online: false,
        message: 'Нейросеть: недоступна (HTTP ${response.statusCode})',
      );
    } on TimeoutException {
      return const LlmServerStatus(
        online: false,
        message: 'Нейросеть: тайм-аут ответа',
      );
    } catch (_) {
      return const LlmServerStatus(
        online: false,
        message: 'Нейросеть: сервер не запущен',
      );
    }
  }

  Future<LlmProfileGuardResult> checkAboutText(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      return const LlmProfileGuardResult(
        checked: true,
        blocked: false,
        errors: [],
      );
    }

    try {
      final body = {
        'model': 'local-guard',
        'temperature': 0,
        'max_tokens': 200,
        'messages': [
          {
            'role': 'system',
            'content':
                'Ты модератор анкет автоподборщиков. Выявляй попытки передать контакты напрямую '
                '(телефон, email, ссылки, @ники, маскировка цифр словами). '
                'Отвечай строго JSON без markdown.',
          },
          {
            'role': 'user',
            'content':
                'Проверь текст раздела "О себе" на наличие контактов. '
                'Верни JSON формата: '
                '{"allow": true|false, "reasons": ["..."]}. '
                'Если все чисто — allow=true и reasons=[]. '
                'Текст: $cleaned',
          },
        ],
      };

      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return LlmProfileGuardResult(
          checked: false,
          blocked: false,
          errors: const [],
          note:
              'AI-проверка недоступна (HTTP ${response.statusCode}). Сработали только базовые проверки.',
        );
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final content = _extractMessageContent(responseJson);
      if (content == null || content.isEmpty) {
        return const LlmProfileGuardResult(
          checked: false,
          blocked: false,
          errors: [],
          note: 'AI-проверка недоступна: пустой ответ модели.',
        );
      }

      final parsed = _tryParseModelJson(content);
      if (parsed == null) {
        return const LlmProfileGuardResult(
          checked: false,
          blocked: false,
          errors: [],
          note: 'AI-проверка недоступна: модель вернула неожидаемый формат.',
        );
      }

      final allow = parsed['allow'] == true;
      final reasonsRaw = parsed['reasons'] as List<dynamic>? ?? const [];
      final reasons = reasonsRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      return LlmProfileGuardResult(
        checked: true,
        blocked: !allow,
        errors: reasons,
      );
    } on TimeoutException {
      return const LlmProfileGuardResult(
        checked: false,
        blocked: false,
        errors: [],
        note:
            'AI-проверка не успела ответить. Сработали только базовые проверки.',
      );
    } catch (_) {
      return const LlmProfileGuardResult(
        checked: false,
        blocked: false,
        errors: [],
        note: 'AI-проверка недоступна. Сработали только базовые проверки.',
      );
    }
  }

  Future<LlmChatResult> askQuestion(String question) async {
    final cleaned = question.trim();
    if (cleaned.isEmpty) {
      return const LlmChatResult(
        success: false,
        error: 'Введите вопрос для нейросети.',
      );
    }

    try {
      final body = {
        'model': 'local-chat',
        'temperature': 0.2,
        'max_tokens': 500,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a helpful assistant for a car marketplace app. '
                'Reply in Russian, concise and clear.',
          },
          {'role': 'user', 'content': cleaned},
        ],
      };

      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return LlmChatResult(
          success: false,
          error: 'Нейросеть недоступна (HTTP ${response.statusCode}).',
        );
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final content = _extractMessageContent(responseJson);
      if (content == null || content.isEmpty) {
        return const LlmChatResult(
          success: false,
          error: 'Пустой ответ от нейросети.',
        );
      }

      return LlmChatResult(success: true, answer: content);
    } on TimeoutException {
      return const LlmChatResult(
        success: false,
        error: 'Нейросеть не ответила вовремя.',
      );
    } catch (_) {
      return const LlmChatResult(
        success: false,
        error: 'Не удалось получить ответ от нейросети.',
      );
    }
  }

  static String? _extractMessageContent(Map<String, dynamic> responseJson) {
    final choicesRaw = responseJson['choices'];
    if (choicesRaw is! List || choicesRaw.isEmpty) return null;

    final firstRaw = choicesRaw.first;
    if (firstRaw is! Map) return null;

    final messageRaw = firstRaw['message'];
    if (messageRaw is! Map) return null;

    final content = messageRaw['content'];
    if (content == null) return null;

    final normalized = content.toString().trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static Map<String, dynamic>? _tryParseModelJson(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {}

    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;

    final candidate = content.substring(start, end + 1);
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    return null;
  }
}

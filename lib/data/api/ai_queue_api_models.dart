/// Data models for [AiQueueApi]. Kept in a sibling file so callers can
/// import everything via `ai_queue_api.dart` (which re-exports this file)
/// while the RPC plumbing stays focused on transport.
class AiQueueModel {
  final String id;
  const AiQueueModel({required this.id});

  factory AiQueueModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    return AiQueueModel(id: id);
  }
}

class AiQueueModelsResult {
  final List<AiQueueModel> models;
  final String defaultModel;
  const AiQueueModelsResult({required this.models, required this.defaultModel});
}

class AiQueueHealth {
  final String status;
  final bool nats;
  final int uptime;
  const AiQueueHealth({
    required this.status,
    required this.nats,
    required this.uptime,
  });

  bool get isOk => status.toLowerCase() == 'ok';
}

/// Single message in a chat history. Format mirrors what aiqueue stores
/// in NATS KV — clients only need to read it (we never construct one).
class AiQueueChatMessage {
  final String role;
  final String content;
  const AiQueueChatMessage({required this.role, required this.content});

  factory AiQueueChatMessage.fromJson(Map<String, dynamic> json) {
    return AiQueueChatMessage(
      role: json['role']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
    );
  }
}

class AiQueueChatSession {
  final int chatId;
  final int userId;
  final List<AiQueueChatMessage> messages;
  final int messageCount;
  final String? model;
  final String updatedAt;

  const AiQueueChatSession({
    required this.chatId,
    required this.userId,
    required this.messages,
    required this.messageCount,
    required this.model,
    required this.updatedAt,
  });

  factory AiQueueChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = <AiQueueChatMessage>[];
    if (rawMessages is List) {
      for (final m in rawMessages) {
        if (m is Map) {
          messages.add(AiQueueChatMessage.fromJson(
            m.map((k, v) => MapEntry(k.toString(), v)),
          ));
        }
      }
    }
    return AiQueueChatSession(
      chatId: _toInt(json['chatId']) ?? 0,
      userId: _toInt(json['userId']) ?? 0,
      messages: messages,
      messageCount: _toInt(json['messageCount']) ?? messages.length,
      model: json['model']?.toString(),
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }
}

/// Response of `AiQueue.GetChatHistories` — map of `chatId(string) → session`.
class AiQueueChatHistories {
  final Map<int, AiQueueChatSession> chats;
  const AiQueueChatHistories({required this.chats});
}

/// Result of `AiQueue.ChatCompletions`. The bare schema is `additionalProperties: true`,
/// so we keep the full raw map and surface the most likely text fields lazily.
class AiQueueChatCompletionResult {
  final int chatId;
  final Map<String, dynamic> raw;
  const AiQueueChatCompletionResult({required this.chatId, required this.raw});

  /// Best-effort extraction of the assistant text. Tries the most common
  /// shapes returned by OpenAI-compatible backends: `content`, `text`,
  /// `message.content`, `choices[0].message.content`.
  String get text {
    final direct = raw['content'] ?? raw['text'] ?? raw['response'];
    if (direct is String && direct.trim().isNotEmpty) return direct;
    final message = raw['message'];
    if (message is Map) {
      final c = message['content'];
      if (c is String && c.trim().isNotEmpty) return c;
    }
    final choices = raw['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) {
          final c = msg['content'];
          if (c is String && c.trim().isNotEmpty) return c;
        }
        final c = first['content'] ?? first['text'];
        if (c is String && c.trim().isNotEmpty) return c;
      }
    }
    return '';
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

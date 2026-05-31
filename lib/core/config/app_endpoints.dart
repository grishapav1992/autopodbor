/// Network endpoints used by the mobile/web client.
///
/// Keep backend hosts in one place so environment migrations do not leave
/// stale hard-coded ports across API clients.
class AppEndpoints {
  AppEndpoints._();

  /// Main JSON-RPC endpoint for Storage.*, Notification.* and Feedback.*.
  static const String appRpc = 'https://app.carreports.ru';

  /// Realtime notification WebSocket endpoint.
  static const String notificationWebSocket = 'wss://ws.carreports.ru/auth';

  /// Public base domain for generated share links.
  static const String publicShareBase = 'https://carreports.ru';

  /// AiQueue JSON-RPC endpoint.
  static const String aiRpc = 'https://ai.carreports.ru';

  static Uri notificationWebSocketUri(String notificationToken) {
    final base = Uri.parse(notificationWebSocket);
    return base.replace(
      queryParameters: <String, String>{'authorization': notificationToken},
    );
  }
}

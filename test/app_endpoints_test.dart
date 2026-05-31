import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/config/app_endpoints.dart';

void main() {
  group('AppEndpoints', () {
    test('uses production carreports hosts', () {
      expect(AppEndpoints.appRpc, 'https://app.carreports.ru');
      expect(AppEndpoints.aiRpc, 'https://ai.carreports.ru');
      expect(AppEndpoints.publicShareBase, 'https://carreports.ru');
      expect(AppEndpoints.notificationWebSocket, 'wss://ws.carreports.ru/auth');
    });

    test('builds websocket URI with encoded notification token', () {
      final uri = AppEndpoints.notificationWebSocketUri('token with spaces');

      expect(uri.scheme, 'wss');
      expect(uri.host, 'ws.carreports.ru');
      expect(uri.path, '/auth');
      expect(uri.queryParameters['authorization'], 'token with spaces');
      expect(uri.toString(), contains('authorization=token+with+spaces'));
    });
  });
}

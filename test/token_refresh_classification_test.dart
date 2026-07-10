import 'dart:async';
import 'dart:io';

import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_error_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Классификация исходов RefreshToken: токены стираются ТОЛЬКО при явном
/// отказе сервера (HTTP 401 / unauthorized / «token is bad.»), а любые
/// транспортные сбои (таймаут, сеть, 429, 5xx, битый ответ) — transient и
/// сессию не убивают. Регрессия на баг «через день снова вход по звонку»:
/// access живёт 12ч, refresh 60 дней, и один сетевой сбой на старте
/// уничтожал живой refresh-токен.
void main() {
  group('StorageApi.isExplicitRefreshRejection', () {
    test('HTTP 401 — явный вердикт, сессия мертва', () {
      expect(
        StorageApi.isExplicitRefreshRejection(
          const RpcHttpStatusException('RefreshToken', 401, 'Unauthorized'),
        ),
        isTrue,
      );
    });

    test('HTTP 403/429/5xx — инфраструктура, НЕ вердикт', () {
      for (final status in const [403, 429, 500, 502, 503, 504]) {
        expect(
          StorageApi.isExplicitRefreshRejection(
            RpcHttpStatusException('RefreshToken', status, 'body'),
          ),
          isFalse,
          reason: 'HTTP $status не должен стирать токены',
        );
      }
    });

    test('RPC-ответ «token is bad.» (живой формат бэка) — вердикт', () {
      // Формат сверен живым запросом 2026-07-10:
      // {"response":"error","errors":{"message":"token is bad."}}
      expect(
        StorageApi.isExplicitRefreshRejection(
          const RpcBadResponseException(
            method: 'RefreshToken',
            responseFlag: 'error',
            errorsText: 'token is bad.',
            unauthorized: false,
          ),
        ),
        isTrue,
      );
    });

    test('RPC-ответ unauthorized (Exception::unauthorized бэка) — вердикт',
        () {
      expect(
        StorageApi.isExplicitRefreshRejection(
          const RpcBadResponseException(
            method: 'RefreshToken',
            responseFlag: 'error',
            errorsText: 'Unauthorized',
            unauthorized: true,
          ),
        ),
        isTrue,
      );
    });

    test('прочая RPC-ошибка (не про токен) — transient', () {
      expect(
        StorageApi.isExplicitRefreshRejection(
          const RpcBadResponseException(
            method: 'RefreshToken',
            responseFlag: 'error',
            errorsText: 'internal error',
            unauthorized: false,
          ),
        ),
        isFalse,
      );
    });

    test('транспортные ошибки — transient', () {
      final transports = <Object>[
        TimeoutException('Timeout on RefreshToken after 12s'),
        const SocketException('Network is unreachable'),
        Exception('Invalid JSON response from RefreshToken: <html>'),
        Exception('Empty response body from RefreshToken'),
      ];
      for (final e in transports) {
        expect(
          StorageApi.isExplicitRefreshRejection(e),
          isFalse,
          reason: '$e не должен стирать токены',
        );
      }
    });
  });

  group('TokenRefreshResult', () {
    test('статусы и геттеры', () {
      expect(const TokenRefreshResult.success().isSuccess, isTrue);
      expect(const TokenRefreshResult.success().isRejected, isFalse);
      expect(const TokenRefreshResult.rejected().isRejected, isTrue);
      expect(const TokenRefreshResult.rejected().isSuccess, isFalse);
      final transient = TokenRefreshResult.transient(Exception('boom'));
      expect(transient.isSuccess, isFalse);
      expect(transient.isRejected, isFalse);
    });

    test('asException возвращает исходную причину без обёртки', () {
      final cause = TimeoutException('Timeout on RefreshToken after 12s');
      final result = TokenRefreshResult.transient(cause);
      expect(identical(result.asException(), cause), isTrue);
    });

    test('asException оборачивает не-Exception причину', () {
      final result = TokenRefreshResult.transient(StateError('bad'));
      expect(result.asException().toString(), contains('RefreshToken failed'));
    });
  });

  group('типизированные исключения сохраняют текст для кодов поддержки', () {
    // sparkJoyReadableError матчит подстроки ('http 401', 'timeout'...) —
    // toString() новых типов обязан давать те же тексты, что старые
    // Exception('HTTP …' / 'Bad response …'), иначе поедут NET/SRV-коды.
    test('RpcHttpStatusException — тот же текст, те же коды', () {
      const with401 = RpcHttpStatusException('GetProfile', 401, 'nope');
      expect(with401.toString(), 'HTTP 401 from GetProfile: nope');
      expect(
        sparkJoyReadableError(with401).code,
        SparkJoyErrorCode.authSession,
      );

      const with503 = RpcHttpStatusException('GetProfile', 503);
      expect(with503.toString(), 'HTTP 503 from GetProfile');
      expect(
        sparkJoyReadableError(with503).code,
        SparkJoyErrorCode.serverUnavailable,
      );

      expect(
        sparkJoyReadableError(
          const RpcHttpStatusException('GetProfile', 429, 'busy'),
        ).code,
        SparkJoyErrorCode.serverRateLimited,
      );
    });

    test('RpcBadResponseException — тот же текст', () {
      const withErrors = RpcBadResponseException(
        method: 'GetProfile',
        responseFlag: 'error',
        errorsText: 'что-то пошло не так',
        unauthorized: false,
      );
      expect(
        withErrors.toString(),
        'Bad response from GetProfile (response=error): что-то пошло не так',
      );
      const noErrors = RpcBadResponseException(
        method: 'GetProfile',
        responseFlag: 'error',
        errorsText: '',
        unauthorized: false,
      );
      expect(
        noErrors.toString(),
        'Bad response from GetProfile (response=error)',
      );
    });
  });
}

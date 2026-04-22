import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/data/api/converter_api.dart';
import 'package:flutter_application_1/data/api/converter_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Хелпер — UTF-8 http.Response, чтобы кириллица в теле не ломалась
/// из-за latin1-дефолта. В проде сервер отдаёт charset=utf-8 сам.
http.Response _jsonResponse(String body, int status) {
  return http.Response.bytes(
    utf8.encode(body),
    status,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

const String _docResponse =
    '{"status":200,"partner":{"status":200,"found":true,"result":{'
    '"brand_model":"PEUGEOT 308","brand":"PEUGEOT","model":"308","year":2008,'
    '"regNumber":"С812МУ93","vin":"VF34CAAAAA5170236",'
    '"body":"VF34CAAAAA5170236","chassis":null}},'
    '"inquiry":{"price":1.4,"balance":399.01}}';

void main() {
  group('ConverterApiHttp — транспорт', () {
    test('токен в заголовке Token, не в query', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      final mock = MockClient((http.Request req) async {
        capturedUri = req.url;
        capturedHeaders = req.headers;
        return _jsonResponse(_docResponse, 200);
      });
      final api = ConverterApiHttp(
        client: mock,
        overrideToken: 'super-secret-token-1234',
      );
      await api.lookup('VF34CAAAAA5170236');

      expect(capturedUri!.queryParameters['type'], 'search');
      expect(capturedUri!.queryParameters['string'], 'VF34CAAAAA5170236');
      expect(
        capturedUri!.queryParameters.containsKey('token'),
        isFalse,
        reason: 'Токен должен быть в заголовке, не в URL (security)',
      );
      expect(capturedHeaders!['Token'], 'super-secret-token-1234');
    });

    test('HTTPS + правильный endpoint', () async {
      Uri? captured;
      final mock = MockClient((http.Request req) async {
        captured = req.url;
        return _jsonResponse(_docResponse, 200);
      });
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await api.lookup('VF34CAAAAA5170236');
      expect(captured!.scheme, 'https');
      expect(captured!.host, 'api-cloud.ru');
      expect(captured!.path, '/api/converter.php');
    });

    test('Кириллический ГРЗ проходит без искажения', () async {
      String? capturedString;
      final mock = MockClient((http.Request req) async {
        capturedString = req.url.queryParameters['string'];
        return _jsonResponse(_docResponse, 200);
      });
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await api.lookup('С812МУ93');
      expect(capturedString, 'С812МУ93');
    });

    test('пустая строка → 460 без запроса', () async {
      var called = false;
      final mock = MockClient((http.Request req) async {
        called = true;
        return _jsonResponse('{}', 200);
      });
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('   '),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '460')),
      );
      expect(called, isFalse);
    });

    test('пустой токен → 502, запрос не уходит', () async {
      var called = false;
      final mock = MockClient((http.Request req) async {
        called = true;
        return _jsonResponse(_docResponse, 200);
      });
      final api = ConverterApiHttp(client: mock, overrideToken: '');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '502')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)),
      );
      expect(called, isFalse);
    });
  });

  group('ConverterApiHttp — разбор ответов', () {
    test('happy-path → ConverterResult с полями', () async {
      final mock = MockClient(
        (http.Request req) async => _jsonResponse(_docResponse, 200),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      final r = await api.lookup('VF34CAAAAA5170236');
      expect(r.brand, 'PEUGEOT');
      expect(r.year, 2008);
      expect(r.regNumber, 'С812МУ93');
    });

    test('found: false → empty result, не исключение', () async {
      final mock = MockClient(
        (http.Request req) async => _jsonResponse(
          '{"status":200,"partner":{"status":200,"found":false,"result":{}}}',
          200,
        ),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      final r = await api.lookup('NTFND123456789ABC');
      expect(r.found, isFalse);
    });

    test('{"status":404,"error":"TIME_MAX_CONNECT"} → transient (404)', () async {
      // Числовой status приоритетнее симвόла в error — иначе таймаут
      // классифицировался бы как admin, а юзер должен увидеть
      // «источник не ответил, попробуйте позже».
      final mock = MockClient(
        (http.Request req) async => _jsonResponse(
          '{"status":404,"error":"TIME_MAX_CONNECT","errormsg":"таймаут"}',
          200,
        ),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '404')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)
            .having((e) => e.message, 'message', 'таймаут')
            .having((e) => e.userMessage, 'userMessage',
                contains('Попробуйте'))),
      );
    });

    test('{"status":200,"error":"503"} → admin (status==200 игнорим, берём error)',
        () async {
      // Обратный кейс: когда status = 200 (или отсутствует), код
      // извлекаем из поля error.
      final mock = MockClient(
        (http.Request req) async => _jsonResponse(
          '{"status":200,"error":"503","message":"TOKEN_LOCKED"}',
          200,
        ),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '503')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)),
      );
    });

    test('status как double 404.0 → корректно парсится в "404"', () async {
      // Defensive: если JSON придёт с дробной записью (dart:convert
      // выбирает double по наличию точки), toInt() должен отрезать.
      final mock = MockClient(
        (http.Request req) async => _jsonResponse(
          '{"status":404.0,"error":"TIME_MAX_CONNECT"}',
          200,
        ),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '404')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)),
      );
    });

    test('{"error":"498","message":"TOKEN_NO_MONEY"} → admin', () async {
      final mock = MockClient(
        (http.Request req) async => _jsonResponse(
          '{"error":"498","message":"TOKEN_NO_MONEY"}',
          200,
        ),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '498')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)),
      );
    });

    test('не-JSON тело → PbNalogException с HTTP-кодом', () async {
      final mock = MockClient(
        (http.Request req) async =>
            _jsonResponse('<html>502 Bad Gateway</html>', 502),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '502')
            .having((e) => e.message, 'message', 'NON_JSON_RESPONSE')),
      );
    });

    test('массив на верхнем уровне → UNEXPECTED_RESPONSE_SHAPE', () async {
      final mock = MockClient(
        (http.Request req) async => _jsonResponse('[1,2,3]', 200),
      );
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.message, 'message', 'UNEXPECTED_RESPONSE_SHAPE')),
      );
    });
  });

  group('ConverterApiHttp — сетевые ошибки', () {
    test('SocketException → transient net_offline', () async {
      final mock = MockClient((http.Request req) async {
        throw const SocketException('No route to host');
      });
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', 'net_offline')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)),
      );
    });

    test('TimeoutException → 404 transient', () async {
      final mock = MockClient((http.Request req) async {
        throw TimeoutException('slow');
      });
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '404')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)),
      );
    });

    test('http.ClientException → transient net_offline', () async {
      final mock = MockClient((http.Request req) async {
        throw http.ClientException('closed', req.url);
      });
      final api = ConverterApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('VF34CAAAAA5170236'),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', 'net_offline')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)),
      );
    });
  });
}

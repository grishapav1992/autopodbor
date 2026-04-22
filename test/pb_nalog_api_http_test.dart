import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/data/api/pb_nalog_api.dart';
import 'package:flutter_application_1/data/api/pb_nalog_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Хелпер — отдаёт корректный UTF-8 http.Response. Без этого
/// `http.Response(String, ...)` использует latin1 и ломается на
/// кириллице (в продакшне сервер отдаёт `Content-Type: charset=utf-8`,
/// так что эта проблема только в тестах).
http.Response _jsonResponse(String body, int status) {
  return http.Response.bytes(
    utf8.encode(body),
    status,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

/// Фикстура-ответ из документации api-cloud.ru/pb_nalog (раздел «search_ip»).
const String _ipResponseBody =
    '{"status":200,"found":true,"count":1,'
    '"data":[{"ogrn":"322237500371357","inn":"233410953141","okved":"62.09",'
    '"okved_name":"Деятельность, связанная с использованием вычислительной техники",'
    '"name":"КОЧУРА АЛЕКСАНДР ВАСИЛЬЕВИЧ","dateReg":"14.10.2022",'
    '"statusIP":1,"statusIPDesc":"Действующий ИП","edo":"Участник ЭДО"}],'
    '"inquiry":{"price":0,"balance":498.79}}';

void main() {
  group('PbNalogApiHttp — транспорт и формат запроса', () {
    test('токен идёт в заголовок Token, не в query string', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      final mock = MockClient((http.Request req) async {
        capturedUri = req.url;
        capturedHeaders = req.headers;
        return _jsonResponse(_ipResponseBody, 200);
      });

      final api = PbNalogApiHttp(
        client: mock,
        overrideToken: 'super-secret-token-1234',
      );
      await api.lookup('233410953141');

      expect(capturedUri!.queryParameters, <String, String>{
        'type': 'search_ip',
        'inn': '233410953141',
      });
      expect(
        capturedUri!.queryParameters.containsKey('token'),
        isFalse,
        reason: 'Токен не должен оказаться в URL — это security fix',
      );
      expect(capturedHeaders!['Token'], 'super-secret-token-1234');
    });

    test('HTTPS — обязателен по доке, endpoint уже hardcoded', () async {
      Uri? capturedUri;
      final mock = MockClient((http.Request req) async {
        capturedUri = req.url;
        return _jsonResponse(_ipResponseBody, 200);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await api.lookup('233410953141');
      expect(capturedUri!.scheme, 'https');
      expect(capturedUri!.host, 'api-cloud.ru');
      expect(capturedUri!.path, '/api/pb_nalog.php');
    });

    test('10 цифр → type=search_org', () async {
      String? capturedType;
      final mock = MockClient((http.Request req) async {
        capturedType = req.url.queryParameters['type'];
        return _jsonResponse(
          jsonEncode(<String, dynamic>{
            'status': 200,
            'found': false,
            'count': 0,
            'data': <dynamic>[],
          }),
          200,
        );
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await api.lookup('6234083042');
      expect(capturedType, 'search_org');
    });

    test('12 цифр → type=search_ip', () async {
      String? capturedType;
      final mock = MockClient((http.Request req) async {
        capturedType = req.url.queryParameters['type'];
        return _jsonResponse(_ipResponseBody, 200);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await api.lookup('233410953141');
      expect(capturedType, 'search_ip');
    });

    test('некорректная длина ИНН — throws 331 без сетевого вызова', () async {
      var called = false;
      final mock = MockClient((http.Request req) async {
        called = true;
        return _jsonResponse('{}', 200);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('123'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', '331')),
      );
      expect(called, isFalse, reason: 'Валидация формата — до сети');
    });

    test('пустой токен → PbNalogException(502), запрос не уходит', () async {
      var called = false;
      final mock = MockClient((http.Request req) async {
        called = true;
        return _jsonResponse('{}', 200);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: '');
      await expectLater(
        api.lookup('6234083042'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', '502')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)),
      );
      expect(called, isFalse);
    });
  });

  group('PbNalogApiHttp — разбор ответа', () {
    test('успешный search_ip → PbNalogResult.kind=ip', () async {
      final mock = MockClient((http.Request req) async {
        return _jsonResponse(_ipResponseBody, 200);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      final result = await api.lookup('233410953141');
      expect(result.kind, PbNalogKind.ip);
      expect(result.found, isTrue);
      expect(result.primaryIp!.name, 'КОЧУРА АЛЕКСАНДР ВАСИЛЬЕВИЧ');
    });

    test('JSON с {"error":"503",...} → PbNalogException(503) admin', () async {
      final mock = MockClient((http.Request req) async {
        return _jsonResponse(
          '{"error":"503","message":"TOKEN_NOT_REGISTERED_IN_THE_SYSTEM"}',
          200,
        );
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('6234083042'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', '503')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)
            .having((e) => e.message, 'message',
                'TOKEN_NOT_REGISTERED_IN_THE_SYSTEM')),
      );
    });

    test('JSON с {"error":"498","message":"TOKEN_NO_MONEY"} → admin', () async {
      final mock = MockClient((http.Request req) async {
        return _jsonResponse(
          '{"error":"498","message":"TOKEN_NO_MONEY"}',
          200,
        );
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('233410953141'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)
            .having((e) => e.userMessage, 'userMessage',
                isNot(contains('деньги'))) // у пользователя нет деталей
            ),
      );
    });

    test('не-JSON тело → PbNalogException с HTTP-кодом', () async {
      final mock = MockClient((http.Request req) async {
        return _jsonResponse('<html>500 Internal Server Error</html>', 500);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('233410953141'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', '500')
            .having((e) => e.message, 'message', 'NON_JSON_RESPONSE')),
      );
    });

    test('JSON не-Map (массив на верхнем уровне) → UNEXPECTED_RESPONSE_SHAPE',
        () async {
      final mock = MockClient((http.Request req) async {
        return _jsonResponse('[1,2,3]', 200);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('233410953141'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.message, 'message', 'UNEXPECTED_RESPONSE_SHAPE')),
      );
    });
  });

  group('PbNalogApiHttp — сетевые ошибки', () {
    test('SocketException → transient net_offline, не admin', () async {
      final mock = MockClient((http.Request req) async {
        throw const SocketException('No route to host');
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('233410953141'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', 'net_offline')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)
            .having((e) => e.userMessage, 'userMessage',
                contains('интернет'))),
      );
    });

    test('TimeoutException → 404 TIME_MAX_CONNECT (transient)', () async {
      final mock = MockClient((http.Request req) async {
        // Возвращает Future, которое никогда не завершится в пределах
        // timeout клиента. Используем задержку больше таймаута, но для
        // теста проще кинуть TimeoutException напрямую.
        throw TimeoutException('slow');
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('233410953141'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', '404')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)),
      );
    });

    test('http.ClientException → transient net_offline', () async {
      final mock = MockClient((http.Request req) async {
        throw http.ClientException('Connection closed', req.url);
      });
      final api = PbNalogApiHttp(client: mock, overrideToken: 'x');
      await expectLater(
        api.lookup('233410953141'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', 'net_offline')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)),
      );
    });
  });
}

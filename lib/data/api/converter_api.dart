import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_application_1/core/config/feature_flags.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:http/http.dart' as http;

import 'converter_models.dart';

/// Клиент к api-cloud.ru/converter (Конвертер VIN ↔ ГРЗ).
///
/// Док: https://api-cloud.ru/converter
///
/// Один endpoint, один `type=search`: API сам определяет, что на
/// входе — VIN или ГРЗ. Возвращает ОБЕ величины плюс brand/model/year,
/// поэтому второй запрос в обратную сторону не нужен.
abstract class ConverterApi {
  /// [query] — либо VIN (17 символов), либо ГРЗ (8–9 символов,
  /// кириллица или латиница — API принимает оба). Клиент ничего с
  /// ней не делает кроме базовой проверки непустоты — формат-валидация
  /// на плечах UI.
  ///
  /// Бросает [ConverterException] при ошибках API/сети/таймауте.
  Future<ConverterResult> lookup(String query);

  /// Фабрика — возвращает мок или реальный клиент в зависимости от
  /// [FeatureFlags.useConverterMock]. Кешируется: один `http.Client`
  /// переиспользуется между вызовами (keep-alive).
  ///
  /// Для тестов используйте конструкторы [ConverterApiMock] /
  /// [ConverterApiHttp] напрямую — они принимают свой `http.Client`
  /// и не трогают кеш.
  static ConverterApi instance() {
    return _instance ??=
        FeatureFlags.useConverterMock ? ConverterApiMock() : ConverterApiHttp();
  }

  static ConverterApi? _instance;

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }
}

// ─── Мок ────────────────────────────────────────────────────────────────

/// Мок на основе примера из документации.
///
/// Триггеры зарезервированы под 17-символьные VIN-валидные строки,
/// чтобы кнопка «Подтянуть …» активировалась — иначе полевой
/// валидатор VIN (`[A-HJ-NPR-Z0-9]{17}`) не пустит юзера и до мока
/// запрос не дойдёт. Все триггеры — **точное совпадение**, чтобы не
/// триггериться случайно на реальных VIN'ах в каких-нибудь будущих
/// интеграционных тестах.
///
/// Зарегистрированные триггеры (ровно эти строки):
/// - `VF34CAAAAA5170236` → Peugeot 308 из доки (happy-path).
/// - `С812МУ93` / `C812MY93` → тот же Peugeot, но через ГРЗ.
/// - `NTFND123456789ABC` → `found: false`.
/// - `ERR498123456789AB` → `ConverterException('498', 'TOKEN_NO_MONEY')` (admin).
/// - `NETDWN123456789AB` → `ConverterException('net_offline', ...)` (transient).
///
/// Любой другой 17-char VIN → синтетический Toyota Camry.
/// Любой другой 7–9 char ГРЗ → синтетический VW Polo.
class ConverterApiMock implements ConverterApi {
  ConverterApiMock({Duration? simulatedLatency})
      : _latency = simulatedLatency ?? const Duration(milliseconds: 700);

  final Duration _latency;

  /// Публичные константы, чтобы DEV-раскрывашка и unit-тесты ссылались
  /// на один источник истины и не расходились при правках мока.
  static const String triggerDocVin = 'VF34CAAAAA5170236';
  static const String triggerDocPlateCyr = 'С812МУ93';
  static const String triggerDocPlateLat = 'C812MY93';
  static const String triggerNotFound = 'NTFND123456789ABC';
  static const String triggerError498 = 'ERR498123456789AB';
  static const String triggerOffline = 'NETDWN123456789AB';

  @override
  Future<ConverterResult> lookup(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw ConverterException('460', 'NO_REQUIRED_PARAMETERS');
    }

    if (_latency > Duration.zero) {
      await Future<void>.delayed(_latency);
    }

    final upper = trimmed.toUpperCase();

    if (upper == triggerError498) {
      throw ConverterException('498', 'TOKEN_NO_MONEY');
    }
    if (upper == triggerOffline) {
      throw ConverterException('net_offline', 'OFFLINE: mock');
    }
    if (upper == triggerNotFound) {
      return ConverterResult.fromJson(_notFoundFixture);
    }

    // Точный пример из доки (VIN + алиас-ГРЗ).
    if (upper == triggerDocVin ||
        upper == triggerDocPlateCyr ||
        upper == triggerDocPlateLat) {
      return ConverterResult.fromJson(_docFixture);
    }

    // Fallback: определяем по длине и возвращаем синтетическую
    // «найденную» запись — чтобы UI можно было прогонять на любом
    // валидном VIN/ГРЗ, не завязываясь на конкретные триггеры.
    final looksLikeVin = trimmed.length == 17;
    if (looksLikeVin) {
      return ConverterResult.fromJson(_syntheticFromVin(trimmed));
    }
    return ConverterResult.fromJson(_syntheticFromPlate(trimmed));
  }

  // ── фикстуры ──────────────────────────────────────────────────────────

  // В доке VIN записан как `VF34C*****5170236` (5 звёздочек — маскировка,
  // итого 17 символов). Мы их раскрываем как `AAAAA`, чтобы получить
  // валидный по VIN-regex 17-символьный идентификатор — иначе кнопка
  // «Подтянуть …» не активируется на этом тестовом значении.
  // `brand_model` из доки не используем — геттер [ConverterResult.brandModel]
  // собирает его из `brand` + `model`.
  static const Map<String, dynamic> _docFixture = <String, dynamic>{
    'status': 200,
    'partner': <String, dynamic>{
      'status': 200,
      'found': true,
      'result': <String, dynamic>{
        'brand': 'PEUGEOT',
        'model': '308',
        'year': 2008,
        'regNumber': 'С812МУ93',
        'vin': 'VF34CAAAAA5170236',
        'body': 'VF34CAAAAA5170236',
        'chassis': null,
      },
    },
    'inquiry': <String, dynamic>{
      'price': 1.4,
      'balance': 399.01,
      'credit': '0.00',
      'speed': 0,
      'attempts': 1,
    },
  };

  static const Map<String, dynamic> _notFoundFixture = <String, dynamic>{
    'status': 200,
    'partner': <String, dynamic>{
      'status': 200,
      'found': false,
      'result': <String, dynamic>{},
    },
    'inquiry': <String, dynamic>{
      'price': 1.4,
      'balance': 399.01,
      'credit': '0.00',
      'speed': 0,
      'attempts': 1,
    },
  };

  Map<String, dynamic> _syntheticFromVin(String vin) => <String, dynamic>{
        'status': 200,
        'partner': <String, dynamic>{
          'status': 200,
          'found': true,
          'result': <String, dynamic>{
            'brand': 'TOYOTA',
            'model': 'CAMRY',
            'year': 2020,
            'regNumber': 'А123ВС777',
            'vin': vin,
            'body': vin,
            'chassis': null,
          },
        },
        'inquiry': <String, dynamic>{
          'price': 1.4,
          'balance': 100.0,
          'credit': '0.00',
          'speed': 0,
          'attempts': 1,
        },
      };

  Map<String, dynamic> _syntheticFromPlate(String plate) => <String, dynamic>{
        'status': 200,
        'partner': <String, dynamic>{
          'status': 200,
          'found': true,
          'result': <String, dynamic>{
            'brand': 'VOLKSWAGEN',
            'model': 'POLO',
            'year': 2019,
            'regNumber': plate,
            'vin': 'WVWZZZ9NZKT000001',
            'body': 'WVWZZZ9NZKT000001',
            'chassis': null,
          },
        },
        'inquiry': <String, dynamic>{
          'price': 1.4,
          'balance': 100.0,
          'credit': '0.00',
          'speed': 0,
          'attempts': 1,
        },
      };
}

// ─── HTTP ───────────────────────────────────────────────────────────────

/// Реальный HTTP-клиент. Не используется, пока
/// [FeatureFlags.useConverterMock] == true.
///
/// - HTTPS обязателен (иначе запросы дублируются при редиректе).
/// - Минимальный таймаут 120 секунд — источник может медленно отвечать.
/// - Токен в заголовке `Token:`, не в query string (чтобы не утекал
///   через access-логи прокси/CDN/дев-инструментов).
class ConverterApiHttp implements ConverterApi {
  ConverterApiHttp({http.Client? client, String? overrideToken})
      : _client = client ?? http.Client(),
        _overrideToken = overrideToken;

  final http.Client _client;
  final String? _overrideToken;

  static const String _endpoint = 'https://api-cloud.ru/api/converter.php';
  static const Duration _timeout = Duration(seconds: 120);

  @override
  Future<ConverterResult> lookup(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw ConverterException('460', 'NO_REQUIRED_PARAMETERS');
    }

    final token =
        _overrideToken ?? await UserSimplePreferences.getApiCloudToken();
    if (token == null || token.isEmpty) {
      throw ConverterException('502', 'MISSING_REQUIRED_TOKEN_PARAMETER');
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: <String, String>{
      'type': 'search',
      'string': trimmed,
    });

    developer.log(
      'GET $_endpoint?type=search&string=$trimmed',
      name: 'ConverterApi',
    );

    http.Response res;
    try {
      res = await _client
          .get(uri, headers: <String, String>{'Token': token})
          .timeout(_timeout);
    } on TimeoutException {
      throw ConverterException('404', 'TIME_MAX_CONNECT');
    } on SocketException catch (e) {
      throw ConverterException('net_offline', 'OFFLINE: $e');
    } on http.ClientException catch (e) {
      throw ConverterException('net_offline', 'CLIENT_EXCEPTION: $e');
    } catch (e) {
      throw ConverterException('500', 'HTTP_TRANSPORT_ERROR: $e');
    }

    final dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ConverterException(
        res.statusCode.toString(),
        'NON_JSON_RESPONSE',
      );
    }

    if (body is! Map) {
      throw ConverterException(
        res.statusCode.toString(),
        'UNEXPECTED_RESPONSE_SHAPE',
      );
    }

    final asMap = Map<String, dynamic>.from(body);

    // Формат ошибок:
    //   {"status":404,"error":"TIME_MAX_CONNECT","errormsg":"..."}
    //   {"error":"503","message":"..."}  (общий для api-cloud)
    // Коды приходят то строкой, то в поле `status`. Нормализуем к
    // нашим строковым кодам.
    final errorCode = _extractErrorCode(asMap);
    if (errorCode != null) {
      final msg = _extractErrorMessage(asMap);
      throw ConverterException(errorCode, msg);
    }

    return ConverterResult.fromJson(asMap);
  }

  /// Возвращает строковый код ошибки, если ответ выглядит ошибочным,
  /// иначе null.
  ///
  /// Приоритет: **числовой `status`** (если ≠ 200) идёт первым, потом
  /// строковый `error`. Без этого приоритета таймаут
  /// `{"status":404, "error":"TIME_MAX_CONNECT", ...}` классифицируется
  /// как admin (код `"TIME_MAX_CONNECT"` не в transient-списке), а
  /// должен быть transient. Симвόл `error` ценен только как
  /// человекочитаемое имя для логов — его мы включаем в [message].
  static String? _extractErrorCode(Map<String, dynamic> body) {
    final status = body['status'];
    if (status is num && status.toInt() != 200) {
      return status.toInt().toString();
    }
    final topError = body['error'];
    if (topError != null) {
      return topError.toString();
    }
    return null;
  }

  static String _extractErrorMessage(Map<String, dynamic> body) {
    final candidates = <dynamic>[
      body['errormsg'],
      body['message'],
      body['error'],
    ];
    for (final c in candidates) {
      if (c != null && c.toString().isNotEmpty) return c.toString();
    }
    return 'UNKNOWN_ERROR';
  }
}

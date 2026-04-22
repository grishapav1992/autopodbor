import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_application_1/core/config/feature_flags.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:http/http.dart' as http;

import 'pb_nalog_models.dart';

/// Клиент к api-cloud.ru/pb_nalog (ФНС «Прозрачный бизнес»).
///
/// Док: https://api-cloud.ru/pb_nalog
///
/// Реализации:
/// - [PbNalogApiMock] — возвращает примеры из документации, не делает
///   сетевых запросов. Используется по умолчанию, пока [FeatureFlags.usePbNalogMock] = true.
/// - [PbNalogApiHttp] — реальный HTTP-клиент. Готов к работе, но
///   требует валидного токена в `UserSimplePreferences.getApiCloudToken()`.
abstract class PbNalogApi {
  /// Запрашивает данные по ИНН. Длина 10 → юрлицо (search_org),
  /// длина 12 → ИП (search_ip). Иные значения — `PbNalogException('331')`.
  ///
  /// Бросает [PbNalogException] при ошибках API/сети/таймауте.
  Future<PbNalogResult> lookup(String inn);

  /// Фабрика — возвращает мок или реальный клиент в зависимости от
  /// [FeatureFlags.usePbNalogMock]. Скрывает выбор реализации от
  /// потребителей: они зовут `PbNalogApi.instance().lookup(...)`.
  ///
  /// Кешируется, чтобы `PbNalogApiHttp` переиспользовал один и тот же
  /// `http.Client` (keep-alive / connection pooling). Для тестов
  /// используйте конструкторы напрямую — они принимают свой `http.Client`
  /// и не трогают кеш.
  ///
  /// TODO(pb-nalog-api): когда выдадут реальный ключ — переключить
  /// флаг и убедиться, что токен лежит в SharedPreferences (или
  /// перенести его в --dart-define для продакшна).
  static PbNalogApi instance() {
    return _instance ??=
        FeatureFlags.usePbNalogMock ? PbNalogApiMock() : PbNalogApiHttp();
  }

  static PbNalogApi? _instance;

  /// Сбрасывает кэшированный экземпляр. Нужно, если на лету меняется
  /// [FeatureFlags.usePbNalogMock] (например, в интеграционных тестах
  /// или при добавлении runtime-конфига).
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }
}

// ─── Мок ────────────────────────────────────────────────────────────────

/// Возвращает данные из [pb_nalog docs](https://api-cloud.ru/pb_nalog) —
/// для тех ИНН, что упомянуты в примерах. Для любого другого валидного
/// ИНН синтезирует «активную» запись с заглушкой имени, чтобы UI
/// можно было прогонять на произвольных значениях.
///
/// Специальные ИНН для тестов error-flow:
/// - `000000000011` (12 цифр) → бросает `PbNalogException('498', 'TOKEN_NO_MONEY')`.
/// - `0000000000`   (10 цифр) → возвращает `found: false` (компания не найдена).
class PbNalogApiMock implements PbNalogApi {
  PbNalogApiMock({Duration? simulatedLatency})
      : _latency = simulatedLatency ?? const Duration(milliseconds: 700);

  final Duration _latency;

  @override
  Future<PbNalogResult> lookup(String inn) async {
    final normalized = inn.replaceAll(RegExp(r'\D'), '');
    if (normalized.length != 10 && normalized.length != 12) {
      throw PbNalogException('331', 'inn: entered incorrectly');
    }

    if (_latency > Duration.zero) {
      await Future<void>.delayed(_latency);
    }

    // Точные примеры из доки.
    if (normalized == '233410953141') {
      return PbNalogResult.fromJson(_ipFixture);
    }
    if (normalized == '6234083042') {
      return PbNalogResult.fromJson(_orgFixture);
    }

    // Триггеры для error-UI.
    if (normalized == '000000000011') {
      throw PbNalogException('498', 'TOKEN_NO_MONEY');
    }
    if (normalized == '0000000000') {
      return PbNalogResult.fromJson(<String, dynamic>{
        'status': 200,
        'found': false,
        'count': 0,
        'data': <dynamic>[],
        'inquiry': <String, dynamic>{
          'price': 0,
          'balance': 100.0,
          'credit': '0.00',
          'speed': 1,
          'attempts': 1,
        },
      });
    }

    // Любой другой валидный ИНН → синтетическая активная запись,
    // чтобы можно было дергать мок на реальных значениях из тестовых
    // аккаунтов разработчика, не привязываясь к двум фикстурам выше.
    if (normalized.length == 12) {
      return PbNalogResult.fromJson(_ipFallback(normalized));
    }
    return PbNalogResult.fromJson(_orgFallback(normalized));
  }

  // ── фикстуры точно из документации ────────────────────────────────────

  static const Map<String, dynamic> _ipFixture = <String, dynamic>{
    'status': 200,
    'found': true,
    'count': 2,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'ogrn': '322237500371357',
        'inn': '233410953141',
        'okved': '62.09',
        'okved_name':
            'Деятельность, связанная с использованием вычислительной техники и информационных технологий, прочая',
        'name': 'КОЧУРА АЛЕКСАНДР ВАСИЛЬЕВИЧ',
        'dateReg': '14.10.2022',
        'statusIP': 1,
        'statusIPDesc': 'Действующий ИП',
        'edo': 'Участник ЭДО',
      },
      <String, dynamic>{
        'ogrn': '316237500033445',
        'inn': '233410953141',
        'okved': '62.09',
        'okved_name':
            'Деятельность, связанная с использованием вычислительной техники и информационных технологий, прочая',
        'name': 'КОЧУРА АЛЕКСАНДР ВАСИЛЬЕВИЧ',
        'dateReg': '29.06.2016',
        'statusIP': 0,
        'statusIPDesc': 'Деятельность прекращена',
        'edo': '',
      },
    ],
    'inquiry': <String, dynamic>{
      'price': 0,
      'balance': 498.79,
      'credit': '0.00',
      'speed': 1,
      'attempts': 1,
    },
  };

  static const Map<String, dynamic> _orgFixture = <String, dynamic>{
    'status': 200,
    'found': true,
    'count': 1,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'invalid': '0',
        'ogrn': '1106234007021',
        'inn': '6234083042',
        'kpp': '773101001',
        'name':
            'ОБЩЕСТВО С ОГРАНИЧЕННОЙ ОТВЕТСТВЕННОСТЬЮ "АВТОМОЙКА № 1"',
        'abbreviated_name': 'ООО "АВТОМОЙКА № 1"',
        'region': 'РЯЗАНСКАЯ ОБЛАСТЬ',
        'adress': '665835, ИРКУТСКАЯ ОБЛАСТЬ, Г. АНГАРСК, МКР. 29, Д.7',
        'dateReg': '18.08.2010',
        'noReg':
            'Межрайонная инспекция Федеральной налоговой службы № 21 по Иркутской области',
        'statusORG': 0,
        'statusORGDesc': 'Деятельность прекращена',
        'edo': '',
        'okved': '45.20',
        'okved_name': 'Техническое обслуживание и ремонт автотранспортных средств',
      },
    ],
    'inquiry': <String, dynamic>{
      'price': 0.3,
      'balance': 496.94,
      'credit': '0.00',
      'speed': 1,
      'attempts': 1,
    },
  };

  Map<String, dynamic> _ipFallback(String inn) => <String, dynamic>{
        'status': 200,
        'found': true,
        'count': 1,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'ogrn': '300000000000000',
            'inn': inn,
            'okved': '00.00',
            'okved_name': '— (мок: данные подменены)',
            'name': 'ИВАНОВ ИВАН ИВАНОВИЧ',
            'dateReg': '01.01.2024',
            'statusIP': 1,
            'statusIPDesc': 'Действующий ИП',
            'edo': '',
          },
        ],
        'inquiry': <String, dynamic>{
          'price': 0,
          'balance': 100.0,
          'credit': '0.00',
          'speed': 1,
          'attempts': 1,
        },
      };

  Map<String, dynamic> _orgFallback(String inn) => <String, dynamic>{
        'status': 200,
        'found': true,
        'count': 1,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'invalid': '0',
            'ogrn': '1000000000000',
            'inn': inn,
            'kpp': '770000000',
            'name':
                'ОБЩЕСТВО С ОГРАНИЧЕННОЙ ОТВЕТСТВЕННОСТЬЮ "ТЕСТОВАЯ КОМПАНИЯ"',
            'abbreviated_name': 'ООО "ТЕСТОВАЯ КОМПАНИЯ"',
            'region': 'Г. МОСКВА',
            'adress': '125009, Г. МОСКВА, УЛ. ТВЕРСКАЯ, Д. 1',
            'dateReg': '01.01.2024',
            'noReg': '— (мок)',
            'statusORG': 1,
            'statusORGDesc': 'Действующая организация',
            'edo': '',
            'okved': '00.00',
            'okved_name': '— (мок: данные подменены)',
          },
        ],
        'inquiry': <String, dynamic>{
          'price': 0,
          'balance': 100.0,
          'credit': '0.00',
          'speed': 1,
          'attempts': 1,
        },
      };
}

// ─── HTTP ───────────────────────────────────────────────────────────────

/// Реальный HTTP-клиент. Не используется, пока
/// [FeatureFlags.usePbNalogMock] = true. Готов к включению.
///
/// Особенности (см. документацию api-cloud.ru):
/// - HTTPS обязателен; иначе запросы дублируются при редиректе.
/// - Минимальный таймаут 120 секунд (источник может медленно отвечать).
/// - Лимит 3 попытки соединения — пока полагаемся на одно соединение,
///   ретраи добавлять позже, если будет нужно.
class PbNalogApiHttp implements PbNalogApi {
  PbNalogApiHttp({http.Client? client, String? overrideToken})
      : _client = client ?? http.Client(),
        _overrideToken = overrideToken;

  final http.Client _client;
  final String? _overrideToken;

  static const String _endpoint = 'https://api-cloud.ru/api/pb_nalog.php';
  static const Duration _timeout = Duration(seconds: 120);

  @override
  Future<PbNalogResult> lookup(String inn) async {
    final normalized = inn.replaceAll(RegExp(r'\D'), '');
    final type = switch (normalized.length) {
      12 => 'search_ip',
      10 => 'search_org',
      _ => null,
    };
    if (type == null) {
      throw PbNalogException('331', 'inn: entered incorrectly');
    }

    final token =
        _overrideToken ?? await UserSimplePreferences.getApiCloudToken();
    if (token == null || token.isEmpty) {
      throw PbNalogException('502', 'MISSING_REQUIRED_TOKEN_PARAMETER');
    }

    // Токен идёт в заголовок `Token:`, а не в query string. API поддерживает
    // оба способа, но URL попадает в логи прокси/CDN/дев-инструментов
    // (Charles, Proxyman), поэтому держим токен в заголовке.
    final uri = Uri.parse(_endpoint).replace(queryParameters: <String, String>{
      'type': type,
      'inn': normalized,
    });

    developer.log(
      'GET $_endpoint?type=$type&inn=$normalized',
      name: 'PbNalogApi',
    );

    http.Response res;
    try {
      res = await _client
          .get(uri, headers: <String, String>{'Token': token})
          .timeout(_timeout);
    } on TimeoutException {
      throw PbNalogException('404', 'TIME_MAX_CONNECT');
    } on SocketException catch (e) {
      // Offline / DNS-fail / connection refused — пользователю «нет сети»,
      // а не «сервис временно недоступен». Псевдокод `net_offline` не
      // пересекается с цифровыми кодами API и позволяет UI показать
      // корректный transient-текст.
      throw PbNalogException('net_offline', 'OFFLINE: $e');
    } on http.ClientException catch (e) {
      // Обычно заворачивает SocketException на non-IO платформах (web),
      // плюс ошибки парсинга ответа. Тоже транзиентное.
      throw PbNalogException('net_offline', 'CLIENT_EXCEPTION: $e');
    } catch (e) {
      throw PbNalogException('500', 'HTTP_TRANSPORT_ERROR: $e');
    }

    final dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw PbNalogException(
        res.statusCode.toString(),
        'NON_JSON_RESPONSE',
      );
    }

    if (body is! Map) {
      throw PbNalogException(
        res.statusCode.toString(),
        'UNEXPECTED_RESPONSE_SHAPE',
      );
    }

    final asMap = Map<String, dynamic>.from(body);

    // Формат ошибки документирован как {"error":"503","message":"..."}.
    if (asMap.containsKey('error') && asMap['error'] != null) {
      final code = asMap['error'].toString();
      final msg = (asMap['message'] ?? '').toString();
      throw PbNalogException(code, msg);
    }

    return PbNalogResult.fromJson(asMap);
  }
}

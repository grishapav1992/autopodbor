import 'package:flutter_application_1/data/api/converter_api.dart';
import 'package:flutter_application_1/data/api/converter_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final api = ConverterApiMock(simulatedLatency: Duration.zero);

  group('ConverterApiMock — фикстура из документации', () {
    test('VIN из доки → Peugeot 308, 2008', () async {
      final r = await api.lookup('VF34C9HZC5170236');
      expect(r.found, isTrue);
      expect(r.brand, 'PEUGEOT');
      expect(r.model, '308');
      expect(r.year, 2008);
      expect(r.regNumber, 'С812МУ93');
      expect(r.vin, 'VF34C9HZC5170236');
      expect(r.brandModel, 'PEUGEOT 308');
    });

    test('ГРЗ кириллицей → тот же Peugeot', () async {
      final r = await api.lookup('С812МУ93');
      expect(r.found, isTrue);
      expect(r.brand, 'PEUGEOT');
      expect(r.vin, 'VF34C9HZC5170236');
    });

    test('ГРЗ латиницей (транслитом) → тот же Peugeot', () async {
      final r = await api.lookup('C812MY93');
      expect(r.found, isTrue);
      expect(r.brand, 'PEUGEOT');
    });
  });

  group('ConverterApiMock — синтетические fallback ответы', () {
    test('Валидный 17-символьный VIN → заглушка Toyota Camry', () async {
      final r = await api.lookup('XWEGH81BBM0012345');
      expect(r.found, isTrue);
      expect(r.brand, 'TOYOTA');
      expect(r.model, 'CAMRY');
      expect(r.vin, 'XWEGH81BBM0012345');
    });

    test('Любой ГРЗ (не VIN по длине) → заглушка VW Polo', () async {
      final r = await api.lookup('А001АА777');
      expect(r.found, isTrue);
      expect(r.brand, 'VOLKSWAGEN');
      expect(r.model, 'POLO');
      // регномер в ответе — то, что юзер прислал
      expect(r.regNumber, 'А001АА777');
    });
  });

  group('ConverterApiMock — error/edge кейсы', () {
    test('NOTFOUND12345678 → found: false, поля пустые', () async {
      final r = await api.lookup('NOTFOUND12345678');
      expect(r.found, isFalse);
      expect(r.brand, isEmpty);
      expect(r.vin, isEmpty);
      expect(r.year, 0);
    });

    test('ERROR498 → admin ConverterException', () async {
      await expectLater(
        api.lookup('ERROR498'),
        throwsA(
          isA<ConverterException>()
              .having((e) => e.code, 'code', '498')
              .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('временно недоступен'),
              )
              // Никаких технических деталей в user-тексте.
              .having(
                (e) => e.userMessage,
                'userMessage',
                isNot(contains('498')),
              ),
        ),
      );
    });

    test('OFFLINE → transient net_offline', () async {
      await expectLater(
        api.lookup('OFFLINE'),
        throwsA(
          isA<ConverterException>()
              .having((e) => e.code, 'code', 'net_offline')
              .having((e) => e.kind, 'kind', ApiCloudErrorKind.transient)
              .having((e) => e.userMessage, 'userMessage',
                  contains('интернет')),
        ),
      );
    });

    test('пустая строка → 460 NO_REQUIRED_PARAMETERS', () async {
      await expectLater(
        api.lookup('   '),
        throwsA(isA<ConverterException>()
            .having((e) => e.code, 'code', '460')
            .having((e) => e.kind, 'kind', ApiCloudErrorKind.admin)),
      );
    });
  });

  group('ConverterResult.fromJson — malformed input', () {
    test('partner отсутствует → empty', () {
      final r = ConverterResult.fromJson(<String, dynamic>{
        'status': 200,
      });
      expect(r.found, isFalse);
      expect(r.brand, isEmpty);
    });

    test('partner.found: false → empty', () {
      final r = ConverterResult.fromJson(<String, dynamic>{
        'partner': <String, dynamic>{'found': false, 'result': <String, dynamic>{}},
      });
      expect(r.found, isFalse);
    });

    test('partner.result — не-map → empty', () {
      final r = ConverterResult.fromJson(<String, dynamic>{
        'partner': <String, dynamic>{'found': true, 'result': 'что-то не то'},
      });
      expect(r.found, isFalse);
    });

    test('year строкой → парсится в int', () {
      final r = ConverterResult.fromJson(<String, dynamic>{
        'partner': <String, dynamic>{
          'found': true,
          'result': <String, dynamic>{
            'brand': 'TEST',
            'year': '2021',
          },
        },
      });
      expect(r.year, 2021);
    });

    test('year невалидный → 0', () {
      final r = ConverterResult.fromJson(<String, dynamic>{
        'partner': <String, dynamic>{
          'found': true,
          'result': <String, dynamic>{
            'brand': 'TEST',
            'year': 'not-a-number',
          },
        },
      });
      expect(r.year, 0);
    });

    test('chassis: null → пустая строка', () {
      final r = ConverterResult.fromJson(<String, dynamic>{
        'partner': <String, dynamic>{
          'found': true,
          'result': <String, dynamic>{'brand': 'X', 'chassis': null},
        },
      });
      expect(r.chassis, '');
    });
  });

  group('ConverterException — категоризация (shared api-cloud коды)', () {
    test('498 (нет денег) → admin, generic user-текст', () {
      final e = ConverterException('498', 'TOKEN_NO_MONEY');
      expect(e.kind, ApiCloudErrorKind.admin);
      expect(e.userMessage, contains('временно недоступен'));
      expect(e.userMessage, isNot(contains('деньги')));
      expect(e.diagnosticMessage, contains('498'));
      expect(e.diagnosticMessage, contains('TOKEN_NO_MONEY'));
    });

    test('404 (timeout источника) → transient', () {
      final e = ConverterException('404', 'TIME_MAX_CONNECT');
      expect(e.kind, ApiCloudErrorKind.transient);
      expect(e.userMessage, contains('Попробуйте'));
    });

    test('888 (запрещённые символы) → userInput', () {
      final e = ConverterException('888', 'forbidden symbols present');
      expect(e.kind, ApiCloudErrorKind.userInput);
      expect(e.userMessage, contains('Недопустимые'));
    });

    test('net_offline → transient «нет интернета»', () {
      final e = ConverterException('net_offline', 'OFFLINE');
      expect(e.kind, ApiCloudErrorKind.transient);
      expect(e.userMessage, contains('интернет'));
    });
  });
}

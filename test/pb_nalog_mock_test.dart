import 'package:flutter_application_1/data/api/pb_nalog_api.dart';
import 'package:flutter_application_1/data/api/pb_nalog_models.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Нулевая задержка, чтобы тесты не висели 700 мс на каждом кейсе.
  final api = PbNalogApiMock(simulatedLatency: Duration.zero);

  group('PbNalogApiMock (фикстуры из документации)', () {
    test('ИП 233410953141 → две записи, первая активная', () async {
      final result = await api.lookup('233410953141');
      expect(result.kind, PbNalogKind.ip);
      expect(result.found, isTrue);
      expect(result.count, 2);
      expect(result.ipEntries, hasLength(2));
      expect(result.orgEntries, isEmpty);

      final primary = result.primaryIp!;
      expect(primary.status, PbNalogStatus.active);
      expect(primary.name, 'КОЧУРА АЛЕКСАНДР ВАСИЛЬЕВИЧ');
      expect(primary.ogrn, '322237500371357');
      expect(primary.participatesInEdo, isTrue);
      expect(primary.dateReg, '14.10.2022');
    });

    test('ЮЛ 6234083042 → terminated ООО', () async {
      final result = await api.lookup('6234083042');
      expect(result.kind, PbNalogKind.organization);
      expect(result.found, isTrue);
      expect(result.orgEntries, hasLength(1));

      final primary = result.primaryOrg!;
      expect(primary.status, PbNalogStatus.terminated);
      expect(primary.shortName, 'ООО "АВТОМОЙКА № 1"');
      expect(primary.region, 'РЯЗАНСКАЯ ОБЛАСТЬ');
      expect(primary.kpp, '773101001');
      expect(primary.ogrn, '1106234007021');
    });

    test('000000000011 → throws admin-kind PbNalogException(498)', () async {
      await expectLater(
        api.lookup('000000000011'),
        throwsA(
          isA<PbNalogException>()
              .having((e) => e.code, 'code', '498')
              .having(
                (e) => e.kind,
                'kind',
                ApiCloudErrorKind.admin,
              )
              // User-facing сообщение — обобщённое, без технических деталей.
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('временно недоступна'),
              )
              // Diagnostic — с кодом и raw-message, для логов/админки.
              .having(
                (e) => e.diagnosticMessage,
                'diagnosticMessage',
                allOf(contains('498'), contains('TOKEN_NO_MONEY')),
              ),
        ),
      );
    });

    test('0000000000 → found: false', () async {
      final result = await api.lookup('0000000000');
      expect(result.found, isFalse);
      expect(result.ipEntries, isEmpty);
      expect(result.orgEntries, isEmpty);
    });

    test('слишком короткий ИНН → throws 331', () async {
      await expectLater(
        api.lookup('123'),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', '331')),
      );
    });

    test('произвольный 12-значный → синтетический активный ИП', () async {
      final result = await api.lookup('123456789012');
      expect(result.kind, PbNalogKind.ip);
      expect(result.primaryIp!.status, PbNalogStatus.active);
      expect(result.primaryIp!.inn, '123456789012');
    });

    test('произвольный 10-значный → синтетическое активное ЮЛ', () async {
      final result = await api.lookup('1234567890');
      expect(result.kind, PbNalogKind.organization);
      expect(result.primaryOrg!.status, PbNalogStatus.active);
      expect(result.primaryOrg!.inn, '1234567890');
    });
  });

  group('SparkJoyStorage.verifyInnAndPromote через мок', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      UserSimplePreferences.pref = null;
      await UserSimplePreferences.init();
    });

    test('успех ИП пишет плоские поля и сырой JSON', () async {
      final result = await SparkJoyStorage.verifyInnAndPromote(
        '233410953141',
        api: api,
      );
      expect(result, isNotNull);
      expect(await SparkJoyStorage.currentVerifiedInn(), '233410953141');
      expect(await SparkJoyStorage.currentBusinessType(), 'ip');
      expect(await SparkJoyStorage.currentBusinessStatusName(), 'active');
      expect(
        await SparkJoyStorage.currentBusinessDisplayName(),
        'КОЧУРА АЛЕКСАНДР ВАСИЛЬЕВИЧ',
      );
      expect(await SparkJoyStorage.currentBusinessOgrn(), '322237500371357');
    });

    test('успех ЮЛ пишет abbreviated_name и регион', () async {
      await SparkJoyStorage.verifyInnAndPromote('6234083042', api: api);
      expect(await SparkJoyStorage.currentBusinessType(), 'company');
      expect(
        await SparkJoyStorage.currentBusinessDisplayName(),
        'ООО "АВТОМОЙКА № 1"',
      );
      expect(
        await SparkJoyStorage.currentBusinessRegion(),
        'РЯЗАНСКАЯ ОБЛАСТЬ',
      );
      expect(
        await SparkJoyStorage.currentBusinessStatusName(),
        'terminated',
      );
    });

    test('not found не пишет бизнес-поля', () async {
      final result = await SparkJoyStorage.verifyInnAndPromote(
        '0000000000',
        api: api,
      );
      expect(result!.found, isFalse);
      expect(await SparkJoyStorage.currentVerifiedInn(), isNull);
      expect(await SparkJoyStorage.currentBusinessType(), isNull);
    });

    test('ошибка API пробрасывается как PbNalogException', () async {
      await expectLater(
        SparkJoyStorage.verifyInnAndPromote('000000000011', api: api),
        throwsA(isA<PbNalogException>()
            .having((e) => e.code, 'code', '498')),
      );
      expect(await SparkJoyStorage.currentVerifiedInn(), isNull);
    });

    test('reset чистит все бизнес-поля', () async {
      await SparkJoyStorage.verifyInnAndPromote('6234083042', api: api);
      await SparkJoyStorage.resetBusinessVerification();
      expect(await SparkJoyStorage.currentVerifiedInn(), isNull);
      expect(await SparkJoyStorage.currentBusinessType(), isNull);
      expect(await SparkJoyStorage.currentBusinessDisplayName(), '');
      expect(await SparkJoyStorage.currentBusinessOgrn(), '');
    });
  });

  group('PbNalogResult.fromJson — malformed input не падает', () {
    test('data отсутствует → пустой результат', () {
      final r = PbNalogResult.fromJson(<String, dynamic>{
        'status': 200,
        'found': false,
        'count': 0,
      });
      expect(r.found, isFalse);
      expect(r.ipEntries, isEmpty);
      expect(r.orgEntries, isEmpty);
      expect(r.kind, PbNalogKind.unknown);
    });

    test('data не-список (строка) → пустой результат', () {
      final r = PbNalogResult.fromJson(<String, dynamic>{
        'found': true,
        'count': 1,
        'data': 'что-то не то',
      });
      expect(r.ipEntries, isEmpty);
      expect(r.orgEntries, isEmpty);
    });

    test('data содержит не-map элементы — они игнорируются', () {
      final r = PbNalogResult.fromJson(<String, dynamic>{
        'found': true,
        'count': 3,
        'data': <dynamic>[
          'строка вместо объекта',
          42,
          <String, dynamic>{'statusIP': 1, 'name': 'ИВАНОВ И.И.', 'inn': '1'},
        ],
      });
      expect(r.ipEntries, hasLength(1));
      expect(r.ipEntries.first.name, 'ИВАНОВ И.И.');
    });

    test('count строкой («1») нормально парсится', () {
      final r = PbNalogResult.fromJson(<String, dynamic>{
        'found': true,
        'count': '1',
        'data': <dynamic>[
          <String, dynamic>{'statusORG': 1, 'inn': '1'},
        ],
      });
      expect(r.count, 1);
      expect(r.orgEntries, hasLength(1));
    });

    test('found может быть не-bool — строго сравниваем с true', () {
      final r = PbNalogResult.fromJson(<String, dynamic>{
        'found': 'true', // строка, не bool → found останется false
        'count': 0,
        'data': <dynamic>[],
      });
      expect(r.found, isFalse);
    });

    test('смешанные IP+ORG записи — обе категории заполняются', () {
      final r = PbNalogResult.fromJson(<String, dynamic>{
        'found': true,
        'count': 2,
        'data': <dynamic>[
          <String, dynamic>{'statusIP': 1, 'inn': '123456789012'},
          <String, dynamic>{'statusORG': 1, 'inn': '1234567890'},
        ],
      });
      expect(r.ipEntries, hasLength(1));
      expect(r.orgEntries, hasLength(1));
      // Последняя увиденная категория определяет kind (не критично, но
      // фиксируем поведение, чтобы ловить случайные рефакторы).
      expect(r.kind, PbNalogKind.organization);
    });

    test('числовые поля с null — не падает, подставляется пустая строка', () {
      final r = PbNalogResult.fromJson(<String, dynamic>{
        'found': true,
        'count': 1,
        'data': <dynamic>[
          <String, dynamic>{
            'statusIP': null,
            'inn': null,
            'name': null,
            'dateReg': null,
            'ogrn': null,
            'edo': null,
          },
        ],
      });
      final e = r.ipEntries.first;
      expect(e.status, PbNalogStatus.unknown);
      expect(e.name, '');
      expect(e.participatesInEdo, isFalse);
    });
  });

  group('PbNalogStatus — стабильная сериализация', () {
    // Защита от рефакторинга enum'а: если кто-то переименует значение,
    // эти тесты упадут и напомнят, что нужна миграция данных.
    const expectedKeys = <PbNalogStatus, String>{
      PbNalogStatus.active: 'active',
      PbNalogStatus.terminated: 'terminated',
      PbNalogStatus.bankruptcy: 'bankruptcy',
      PbNalogStatus.exclusion: 'exclusion',
      PbNalogStatus.reorganization: 'reorganization',
      PbNalogStatus.liquidation: 'liquidation',
      PbNalogStatus.unknown: 'unknown',
    };

    test('toStorageKey — зафиксированные ключи', () {
      for (final entry in expectedKeys.entries) {
        expect(pbNalogStatusToStorageKey(entry.key), entry.value);
      }
    });

    test('round-trip: toStorageKey → fromStorageKey', () {
      for (final status in PbNalogStatus.values) {
        final key = pbNalogStatusToStorageKey(status);
        expect(pbNalogStatusFromStorageKey(key), status);
      }
    });

    test('неизвестный ключ → unknown, не падает', () {
      expect(pbNalogStatusFromStorageKey('какая_то_старая_запись'),
          PbNalogStatus.unknown);
      expect(pbNalogStatusFromStorageKey(''), PbNalogStatus.unknown);
    });
  });

  group('PbNalogException — категоризация и сообщения', () {
    test('498 (нет денег) — admin, юзер видит generic', () {
      final e = PbNalogException('498', 'TOKEN_NO_MONEY');
      expect(e.kind, ApiCloudErrorKind.admin);
      expect(e.userMessage, contains('временно недоступна'));
      // Никаких «денег», «баланса», «токена» в user-сообщении.
      expect(e.userMessage, isNot(contains('средств')));
      expect(e.userMessage, isNot(contains('баланс')));
      expect(e.userMessage, isNot(contains('токен')));
      expect(e.userMessage, isNot(contains('498')));
      // Но всё это есть в диагностике.
      expect(e.diagnosticMessage, contains('498'));
      expect(e.diagnosticMessage, contains('TOKEN_NO_MONEY'));
    });

    test('503 (токен не принят) — admin, user-текст общий', () {
      final e = PbNalogException('503', 'TOKEN_NOT_REGISTERED_IN_THE_SYSTEM');
      expect(e.kind, ApiCloudErrorKind.admin);
      expect(e.userMessage, contains('временно недоступна'));
      expect(e.userMessage, isNot(contains('токен')));
      expect(e.userMessage, isNot(contains('503')));
    });

    test('331 (кривой ИНН) — userInput, конкретное сообщение', () {
      final e = PbNalogException('331', 'inn: entered incorrectly');
      expect(e.kind, ApiCloudErrorKind.userInput);
      expect(e.userMessage, contains('формат'));
    });

    test('404 (timeout источника) — transient, «попробуйте позже»', () {
      final e = PbNalogException('404', 'TIME_MAX_CONNECT');
      expect(e.kind, ApiCloudErrorKind.transient);
      expect(e.userMessage, contains('Попробуйте'));
    });

    test('неизвестный код — admin, generic текст', () {
      final e = PbNalogException('9999', 'WUT');
      expect(e.kind, ApiCloudErrorKind.admin);
      expect(e.userMessage, contains('временно недоступна'));
      expect(e.diagnosticMessage, contains('9999'));
    });
  });
}

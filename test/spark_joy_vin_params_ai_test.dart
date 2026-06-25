import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_vin_params_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Зеркала опций дропдаунов (_SparkJoyVehicleRegistry приватный) — держать
  // синхронно с spark_joy_vehicle_registry.dart.
  const engineTypes = ['Бензин', 'Дизель', 'Гибрид', 'Электро', 'Газ/Бензин'];
  const gearboxTypes = ['АКПП', 'МКПП', 'Робот', 'Вариатор'];
  const driveTypes = ['Передний', 'Задний', 'Полный'];
  final engineVolumes = List<String>.generate(
    43,
    (i) => (0.8 + i * 0.1).toStringAsFixed(1),
  );

  VinParamsAiResult parse(String text) => parseVinParamsAiResult(
    text,
    allowedEngineTypes: engineTypes,
    allowedGearboxTypes: gearboxTypes,
    allowedDriveTypes: driveTypes,
    allowedEngineVolumes: engineVolumes,
  );

  group('parseVinParamsAiResult', () {
    test('parses bare valid JSON, all fields canonical', () {
      final r = parse(
        '{"engineVolume": 1.6, "engineType": "Бензин", '
        '"transmission": "АКПП", "driveType": "Передний", '
        '"equipment": "Comfort"}',
      );
      expect(r.engineVolume, '1.6');
      expect(r.engineType, 'Бензин');
      expect(r.transmission, 'АКПП');
      expect(r.driveType, 'Передний');
      expect(r.equipment, 'Comfort');
    });

    test('parses JSON wrapped in ```json fences', () {
      final r = parse(
        '```json\n{"engineType": "Дизель", "transmission": "МКПП"}\n```',
      );
      expect(r.engineType, 'Дизель');
      expect(r.transmission, 'МКПП');
    });

    test('parses JSON embedded in prose', () {
      final r = parse('Вот результат: {"driveType": "Полный"} — готово.');
      expect(r.driveType, 'Полный');
    });

    test('ignores trailing prose with stray brace', () {
      final r = parse(
        '{"engineType":"Бензин","transmission":"АКПП"} — это бензин 1.6}',
      );
      expect(r.engineType, 'Бензин');
      expect(r.transmission, 'АКПП');
    });

    test('drops unknown enum values to empty', () {
      final r = parse(
        '{"engineType": "Турбодизель", "transmission": "DSG", '
        '"driveType": "AWD"}',
      );
      expect(r.engineType, '');
      expect(r.transmission, '');
      expect(r.driveType, '');
    });

    test('canonicalizes enum case-insensitively', () {
      final r = parse(
        '{"engineType": "бензин", "driveType": "ПОЛНЫЙ", '
        '"transmission": "акпп"}',
      );
      expect(r.engineType, 'Бензин');
      expect(r.driveType, 'Полный');
      expect(r.transmission, 'АКПП');
    });

    test('engineVolume: out-of-range dropped, in-range kept', () {
      expect(parse('{"engineVolume": 7.5}').engineVolume, '');
      expect(parse('{"engineVolume": 0.5}').engineVolume, '');
      expect(parse('{"engineVolume": 1.0}').engineVolume, '1.0');
      expect(parse('{"engineVolume": 5.0}').engineVolume, '5.0');
    });

    test('engineVolume: number vs string, comma decimal, rounds to 0.1', () {
      expect(parse('{"engineVolume": 2}').engineVolume, '2.0');
      expect(parse('{"engineVolume": "1,6"}').engineVolume, '1.6');
      // Не-0.1 гранулярность округляется к ближайшей 0.1 из списка.
      expect(parse('{"engineVolume": 1.65}').engineVolume, '1.6');
      // Терпим суффикс единицы.
      expect(parse('{"engineVolume": "1.6 л"}').engineVolume, '1.6');
      expect(parse('{"engineVolume": "2.0 L"}').engineVolume, '2.0');
    });

    test('empty / garbage / partial → emptyVinParamsAiResult, never throws', () {
      for (final bad in ['', 'not json', '{', '{}', '   ']) {
        expect(parse(bad), emptyVinParamsAiResult, reason: 'input: "$bad"');
      }
    });

    test('equipment trimmed and capped at 80 chars', () {
      final long = 'A' * 120;
      final r = parse('{"equipment": "  $long  "}');
      expect(r.equipment.length, 80);
      expect(parse('{"equipment": ""}').equipment, '');
    });

    test('electric car: engineVolume empty, type kept', () {
      final r = parse('{"engineType": "Электро", "engineVolume": ""}');
      expect(r.engineType, 'Электро');
      expect(r.engineVolume, '');
    });
  });

  group('extractJsonObject', () {
    test('extracts from fences and prose', () {
      expect(extractJsonObject('```json\n{"a":1}\n```'), {'a': 1});
      expect(extractJsonObject('x {"a":"b"} y'), {'a': 'b'});
    });

    test('no braces / empty → null', () {
      expect(extractJsonObject('no json here'), isNull);
      expect(extractJsonObject(''), isNull);
      expect(extractJsonObject('{'), isNull);
    });

    test('takes outermost object incl. nested', () {
      final r = extractJsonObject('{"a":1,"b":{"c":2}}');
      expect(r?['a'], 1);
      expect(r?['b'], {'c': 2});
    });

    test('stops at first balanced object, ignores trailing brace', () {
      expect(extractJsonObject('{"a":1} junk }'), {'a': 1});
    });

    test('handles braces and quotes inside string values', () {
      expect(extractJsonObject(r'{"a":"x{y}\"z"}'), {'a': 'x{y}"z'});
    });
  });

  group('staleVinAutofillKeys', () {
    test('returns only untouched AI fields; skips user-changed and ai-empty', () {
      final stale = staleVinAutofillKeys(
        {'engineType': 'Бензин', 'transmission': 'АКПП', 'driveType': ''},
        {'engineType': 'Бензин', 'transmission': 'МКПП', 'driveType': ''},
      );
      // engineType не тронут → stale; transmission изменён вручную → нет;
      // driveType ИИ оставлял пустым → нет.
      expect(stale, {'engineType'});
    });

    test('empty tracking → empty set', () {
      expect(staleVinAutofillKeys({}, {'engineType': 'Бензин'}), isEmpty);
    });

    test('identity reuse: clears untouched auto-brand, keeps user-edited model', () {
      // Тот же чистый хелпер используется для идентификации (ключи brand/model).
      final stale = staleVinAutofillKeys(
        {'brand': 'LADA', 'model': 'VESTA'},
        {'brand': 'LADA', 'model': 'Granta'}, // модель изменена вручную
      );
      expect(stale, {'brand'});
    });
  });

  group('planIdentityFill', () {
    test('found + both empty → fills both (trimmed)', () {
      final p = planIdentityFill(
        brandEmpty: true,
        modelEmpty: true,
        found: true,
        timedOut: false,
        resolvedBrand: '  LADA ',
        resolvedModel: ' VESTA ',
      );
      expect(p.brand, 'LADA');
      expect(p.model, 'VESTA');
    });

    test('only-empty per field: brand занят → пишем только модель', () {
      final p = planIdentityFill(
        brandEmpty: false,
        modelEmpty: true,
        found: true,
        timedOut: false,
        resolvedBrand: 'LADA',
        resolvedModel: 'VESTA',
      );
      expect(p.brand, '');
      expect(p.model, 'VESTA');
    });

    test('not found → пусто', () {
      final p = planIdentityFill(
        brandEmpty: true,
        modelEmpty: true,
        found: false,
        timedOut: false,
        resolvedBrand: 'LADA',
        resolvedModel: 'VESTA',
      );
      expect(p.brand, '');
      expect(p.model, '');
    });

    test('timedOut → пусто (даже если found)', () {
      final p = planIdentityFill(
        brandEmpty: true,
        modelEmpty: true,
        found: true,
        timedOut: true,
        resolvedBrand: 'LADA',
        resolvedModel: 'VESTA',
      );
      expect(p.brand, '');
      expect(p.model, '');
    });

    test('found но резолв пустой → пусто', () {
      final p = planIdentityFill(
        brandEmpty: true,
        modelEmpty: true,
        found: true,
        timedOut: false,
        resolvedBrand: '',
        resolvedModel: '',
      );
      expect(p.brand, '');
      expect(p.model, '');
    });
  });

  // ── ГОСТ-сертификат → «Параметры» ────────────────────────────────────
  final liveCert = <String, dynamic>{
    'product': 'VOLKSWAGEN',
    'tradename': 'TIGUAN',
    'type': '5NZLW',
    'category': 'M1',
    'bodytype': 'универсал/5',
    'fullmass': '1950',
    'yearofmanufacturing': '2020',
    'enginepetrol': 'Дизельное топливо',
    'enginecylindersusefulcapacity': '1968',
    'transmission': 'Volkswagen, роботизированная с ручным управлением',
    'enginemaxpower': '110.29(3500)',
    'eco': '4',
    'numberofcertificate': 'ТС RU А-DE.НУ08.71226',
  };
  GostParamsResult parseGost(Map<String, dynamic> c) =>
      parseGostCertificateParams(
        c,
        allowedEngineTypes: engineTypes,
        allowedGearboxTypes: gearboxTypes,
        allowedEngineVolumes: engineVolumes,
      );

  group('parseGostCertificateParams', () {
    test('live LEG-A404259 → Дизель / 2.0 / Робот', () {
      final r = parseGost(liveCert);
      expect(r.engineType, 'Дизель');
      expect(r.engineVolume, '2.0'); // 1968 см³ → 1.968 → «2.0»
      expect(r.transmission, 'Робот');
    });
    test('fuel substrings map + canon', () {
      expect(parseGost({'enginepetrol': 'Бензиновое'}).engineType, 'Бензин');
      expect(parseGost({'enginepetrol': 'Электродвигатель'}).engineType, 'Электро');
      expect(parseGost({'enginepetrol': 'Гибридная установка'}).engineType, 'Гибрид');
      expect(parseGost({'enginepetrol': 'Газовое/бензиновое'}).engineType, 'Газ/Бензин');
      expect(parseGost({'enginepetrol': 'неизвестно'}).engineType, '');
      expect(parseGost({'enginepetrol': ''}).engineType, '');
    });
    test('transmission substrings', () {
      expect(parseGost({'transmission': 'автоматическая'}).transmission, 'АКПП');
      expect(parseGost({'transmission': 'механическая 6-ст'}).transmission, 'МКПП');
      expect(parseGost({'transmission': 'вариаторного типа'}).transmission, 'Вариатор');
      expect(parseGost({'transmission': 'роботизированная'}).transmission, 'Робот');
      expect(parseGost({'transmission': 'странная'}).transmission, '');
    });
    test('volume cm3 → liters, only if in dropdown list', () {
      expect(parseGost({'enginecylindersusefulcapacity': '1598'}).engineVolume, '1.6');
      expect(parseGost({'enginecylindersusefulcapacity': '799'}).engineVolume, '0.8');
      expect(parseGost({'enginecylindersusefulcapacity': '99000'}).engineVolume, '');
      expect(parseGost({'enginecylindersusefulcapacity': ''}).engineVolume, '');
      expect(parseGost({'enginecylindersusefulcapacity': 'нет'}).engineVolume, '');
    });
    test('empty cert → all empty, never throws', () {
      final r = parseGost(<String, dynamic>{});
      expect(r.engineVolume, '');
      expect(r.engineType, '');
      expect(r.transmission, '');
    });
  });

  group('gostCertificateFields', () {
    const foundJson =
        '{"found":true,"certificate":[{"product":"VOLKSWAGEN","tradename":"TIGUAN"}]}';
    test('JSON-string found → first cert map', () {
      final c = gostCertificateFields(foundJson);
      expect(c, isNotNull);
      expect(c!['product'], 'VOLKSWAGEN');
      expect(c['tradename'], 'TIGUAN');
    });
    test('already-decoded Map found → first cert map', () {
      final c = gostCertificateFields({'found': true, 'certificate': [liveCert]});
      expect(c!['enginepetrol'], 'Дизельное топливо');
    });
    test('found:false → null', () {
      expect(gostCertificateFields('{"found":false,"certificate":[]}'), isNull);
    });
    test('found:true but empty certificate → null', () {
      expect(gostCertificateFields({'found': true, 'certificate': []}), isNull);
    });
    test('null / empty / garbage → null, never throws', () {
      expect(gostCertificateFields(null), isNull);
      expect(gostCertificateFields(''), isNull);
      expect(gostCertificateFields('not json'), isNull);
    });
    test('JSON wrapped in prose (extractJsonObject path)', () {
      final c = gostCertificateFields(
        'итог: {"found":true,"certificate":[{"product":"BMW"}]} конец',
      );
      expect(c!['product'], 'BMW');
    });
  });

  group('gostListField / gostMapField (scaffold)', () {
    test('items populated → list of maps', () {
      final l = gostListField(
        '{"found":true,"items":[{"number":"1"},{"number":"2"}]}',
        'items',
      );
      expect(l.length, 2);
      expect(l.first['number'], '1');
    });
    test('items empty / missing → []', () {
      expect(gostListField('{"items":[]}', 'items'), isEmpty);
      expect(gostListField('{"found":true}', 'items'), isEmpty);
      expect(gostListField(null, 'items'), isEmpty);
    });
    test('permit populated → map; null/empty → null', () {
      expect(gostMapField('{"permit":{"number":"X1"}}', 'permit')!['number'], 'X1');
      expect(gostMapField('{"permit":null}', 'permit'), isNull);
      expect(gostMapField('{"permit":{}}', 'permit'), isNull);
    });
  });
}

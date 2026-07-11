import 'dart:convert';

import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_test/flutter_test.dart';

// toJson/tryFromJson каталожных классов — wire-контракт файлового кэша
// каталога И черновика заявки компании (они делят один набор ключей).
// Голден-тесты ниже фиксируют имена ключей: их смена ломает старые
// черновики и уже записанные файлы кэша.

PhotoItem _photo({int id = 1}) => PhotoItem(
  id: id,
  size: 'l',
  urlX1: 'https://x/1.jpg',
  urlX2: 'https://x/2.jpg',
);

FrameItem _frame({int id = 7}) => FrameItem(id: id, frame: 'XV70');

RestylingItem _restyling({int id = 3}) => RestylingItem(
  id: id,
  restyling: 'Рестайлинг 1',
  yearStart: 2017,
  yearEnd: 2020,
  frames: [_frame()],
  photos: [_photo()],
);

GenerationItem _generation({int id = 9}) => GenerationItem(
  id: id,
  modelCarId: 55,
  generation: 8,
  frames: [_frame(id: 8)],
  restylings: [_restyling()],
);

void main() {
  group('round-trip через jsonEncode/jsonDecode', () {
    test('BrandItem', () {
      final source = BrandItem(id: 1, name: 'Toyota', nameRus: 'Тойота');
      final parsed = BrandItem.tryFromJson(
        jsonDecode(jsonEncode(source.toJson())),
      );
      expect(parsed, isNotNull);
      expect(parsed!.id, 1);
      expect(parsed.name, 'Toyota');
      expect(parsed.nameRus, 'Тойота');
    });

    test('ModelItem', () {
      final source = ModelItem(
        id: 2,
        brandId: 1,
        model: 'Camry',
        modelRus: 'Камри',
      );
      final parsed = ModelItem.tryFromJson(
        jsonDecode(jsonEncode(source.toJson())),
      );
      expect(parsed, isNotNull);
      expect(parsed!.id, 2);
      expect(parsed.brandId, 1);
      expect(parsed.model, 'Camry');
      expect(parsed.modelRus, 'Камри');
    });

    test('GenerationItem с вложенными рестайлингами/кузовами/фото', () {
      final parsed = GenerationItem.tryFromJson(
        jsonDecode(jsonEncode(_generation().toJson())),
      );
      expect(parsed, isNotNull);
      expect(parsed!.id, 9);
      expect(parsed.modelCarId, 55);
      expect(parsed.generation, 8);
      expect(parsed.frames.single.frame, 'XV70');
      final rest = parsed.restylings.single;
      expect(rest.id, 3);
      expect(rest.restyling, 'Рестайлинг 1');
      expect(rest.yearStart, 2017);
      expect(rest.yearEnd, 2020);
      expect(rest.frames.single.id, 7);
      expect(rest.photos.single.urlX2, 'https://x/2.jpg');
    });

    test('RestylingItem: nullable годы переживают null', () {
      final source = RestylingItem(
        id: 4,
        restyling: '',
        yearStart: null,
        yearEnd: null,
        frames: const [],
        photos: const [],
      );
      final parsed = RestylingItem.tryFromJson(
        jsonDecode(jsonEncode(source.toJson())),
      );
      expect(parsed, isNotNull);
      expect(parsed!.yearStart, isNull);
      expect(parsed.yearEnd, isNull);
      expect(parsed.frames, isEmpty);
      expect(parsed.photos, isEmpty);
    });
  });

  group('голден: ключи совпадают с легаси-черновиком заявки компании', () {
    // Ключи из _brandToDraft/_modelToDraft/… (spark_joy_company_create_
    // request_screen.dart) — исторический формат персиста.
    test('наборы ключей', () {
      expect(
        BrandItem(id: 1, name: 'a', nameRus: 'б').toJson().keys,
        unorderedEquals(['id', 'name', 'nameRus']),
      );
      expect(
        ModelItem(id: 1, brandId: 2, model: 'a', modelRus: 'б').toJson().keys,
        unorderedEquals(['id', 'brandId', 'model', 'modelRus']),
      );
      expect(
        _generation().toJson().keys,
        unorderedEquals([
          'id',
          'modelCarId',
          'generation',
          'frames',
          'restylings',
        ]),
      );
      expect(
        _restyling().toJson().keys,
        unorderedEquals([
          'id',
          'restyling',
          'yearStart',
          'yearEnd',
          'frames',
          'photos',
        ]),
      );
      expect(_frame().toJson().keys, unorderedEquals(['id', 'frame']));
      expect(
        _photo().toJson().keys,
        unorderedEquals(['id', 'size', 'urlX1', 'urlX2']),
      );
    });

    test('легаси-мапа черновика парсится', () {
      final legacy = {
        'id': 10,
        'modelCarId': 20,
        'generation': 3,
        'frames': [
          {'id': 1, 'frame': 'E210'},
        ],
        'restylings': [
          {
            'id': 2,
            'restyling': 'Дорестайлинг',
            'yearStart': 2019,
            'yearEnd': null,
            'frames': [],
            'photos': [
              {'id': 5, 'size': 'm', 'urlX1': 'u1', 'urlX2': 'u2'},
            ],
          },
        ],
      };
      final parsed = GenerationItem.tryFromJson(legacy);
      expect(parsed, isNotNull);
      expect(parsed!.restylings.single.photos.single.id, 5);
    });
  });

  group('терпимость к мусору', () {
    test('строковый id парсится, отсутствующий — null', () {
      expect(BrandItem.tryFromJson({'id': '5', 'name': 'X'})?.id, 5);
      expect(BrandItem.tryFromJson({'name': 'X'}), isNull);
      expect(BrandItem.tryFromJson('мусор'), isNull);
      expect(BrandItem.tryFromJson(null), isNull);
      expect(ModelItem.tryFromJson({'id': 1}), isNull); // без brandId
    });

    test('битые элементы вложенных списков выбрасываются молча', () {
      final parsed = GenerationItem.tryFromJson({
        'id': 1,
        'modelCarId': 2,
        'generation': 1,
        'frames': [
          {'id': 1, 'frame': 'ok'},
          {'frame': 'без id'},
          'строка',
        ],
        'restylings': 'не список',
      });
      expect(parsed, isNotNull);
      expect(parsed!.frames.single.frame, 'ok');
      expect(parsed.restylings, isEmpty);
    });
  });

  group('GenerationItem.yearRange — диапазон годов из рестайлингов', () {
    RestylingItem rest({int? start, int? end}) => RestylingItem(
      id: 1,
      restyling: 'r',
      yearStart: start,
      yearEnd: end,
      frames: const [],
      photos: const [],
    );

    GenerationItem gen(List<RestylingItem> rs, {int number = 5}) =>
        GenerationItem(
          id: 1,
          modelCarId: 1,
          generation: number,
          frames: const [],
          restylings: rs,
        );

    test('один рестайлинг с началом и концом', () {
      expect(gen([rest(start: 2016, end: 2020)]).yearRange, '2016–2020');
    });

    test('несколько рестайлингов — минимальный старт и максимальный конец', () {
      final g = gen([
        rest(start: 2018, end: 2021),
        rest(start: 2015, end: 2019),
      ]);
      expect(g.yearRange, '2015–2021');
    });

    test('открытый конец (модель ещё выпускается) → «с YYYY»', () {
      expect(gen([rest(start: 2019, end: null)]).yearRange, 'с 2019');
    });

    test('любой рестайлинг без конца делает диапазон открытым', () {
      final g = gen([
        rest(start: 2010, end: 2014),
        rest(start: 2014, end: null),
      ]);
      expect(g.yearRange, 'с 2010');
    });

    test('старт == конец → один год без тире', () {
      expect(gen([rest(start: 2020, end: 2020)]).yearRange, '2020');
    });

    test('нет годов ни у одного рестайлинга → null', () {
      expect(gen([rest(), rest()]).yearRange, isNull);
      expect(gen(const []).yearRange, isNull);
    });

    test('yearRangeOrNumber падает на номер поколения без годов', () {
      expect(gen(const [], number: 7).yearRangeOrNumber, '7');
      expect(gen([rest(start: 2016, end: 2020)]).yearRangeOrNumber, '2016–2020');
    });
  });

  group('RestylingItem.yearRange — период одного рестайлинга', () {
    RestylingItem r({int? s, int? e}) => RestylingItem(
      id: 1,
      restyling: '0',
      yearStart: s,
      yearEnd: e,
      frames: const [],
      photos: const [],
    );
    test('начало и конец → «2020–2022»', () {
      expect(r(s: 2020, e: 2022).yearRange, '2020–2022');
    });
    test('только начало → «с 2020»', () {
      expect(r(s: 2020).yearRange, 'с 2020');
    });
    test('только конец → «по 2022»', () {
      expect(r(e: 2022).yearRange, 'по 2022');
    });
    test('равные годы → один год', () {
      expect(r(s: 2020, e: 2020).yearRange, '2020');
    });
    test('нет годов → null', () {
      expect(r().yearRange, isNull);
    });
  });

  group('GenerationItem.yearRangeFromRestylingsJson — из «сырого» списка', () {
    test('список карт с годами → диапазон', () {
      final raw = [
        {'id': 1, 'yearStart': 2015, 'yearEnd': 2019},
        {'id': 2, 'yearStart': 2018, 'yearEnd': 2021},
      ];
      expect(GenerationItem.yearRangeFromRestylingsJson(raw), '2015–2021');
    });

    test('открытый конец → «с YYYY»', () {
      final raw = [
        {'id': 1, 'yearStart': 2019, 'yearEnd': null},
      ];
      expect(GenerationItem.yearRangeFromRestylingsJson(raw), 'с 2019');
    });

    test('без годов → null (вызывающий покажет номер)', () {
      expect(
        GenerationItem.yearRangeFromRestylingsJson([
          {'id': 1},
        ]),
        isNull,
      );
    });

    test('незнакомая форма молча даёт null, не бросает', () {
      expect(GenerationItem.yearRangeFromRestylingsJson(null), isNull);
      expect(GenerationItem.yearRangeFromRestylingsJson('мусор'), isNull);
      expect(GenerationItem.yearRangeFromRestylingsJson(const []), isNull);
      expect(GenerationItem.yearRangeFromRestylingsJson(42), isNull);
    });
  });

  group('GenerationItem.displayValueFromRequestCarJson', () {
    test('живой GetRequestCar: singular restyling и строковые годы', () {
      final value = GenerationItem.displayValueFromRequestCarJson({
        'generation': 4,
        'restyling': [
          {'id': 10, 'yearStart': '2018', 'yearEnd': '2022'},
        ],
      });
      expect(value, '2018–2022');
    });

    test('ISO-даты годов тоже преобразуются в диапазон', () {
      final value = GenerationItem.displayValueFromRequestCarJson({
        'generation': 2,
        'restyling': [
          {
            'id': 10,
            'yearStart': '2019-01-01',
            'yearEnd': '2021-12-31',
          },
        ],
      });
      expect(value, '2019–2021');
    });

    test('легаси plural restylings поддерживается', () {
      final value = GenerationItem.displayValueFromRequestCarJson({
        'generation': 3,
        'restylings': [
          {'id': 10, 'yearStart': 2015, 'yearEnd': null},
        ],
      });
      expect(value, 'с 2015');
    });

    test('без годов используется номер поколения', () {
      expect(
        GenerationItem.displayValueFromRequestCarJson({'generation': 7}),
        '7',
      );
    });

    test('нулевое и отсутствующее поколение не показываются', () {
      expect(
        GenerationItem.displayValueFromRequestCarJson({'generation': 0}),
        isNull,
      );
      expect(GenerationItem.displayValueFromRequestCarJson(const {}), isNull);
    });
  });
}

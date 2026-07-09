import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_doc_scan_ai.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_plate_formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DocScanAiResult parse(String text) => parseDocScanAiResult(text);

  group('parseDocScanAiResult', () {
    test('латинский госномер от vision → кириллица РФ и опознаётся детектором', () {
      // Vision транслитерирует «К254ТМ797» в латиницу — без обратного маппинга
      // РФ-детектор вырезал бы латинские буквы, страна стала бы «Другая», а
      // номер не совпал бы с базами ApiCloud.
      final r = parse('{"gosNumber": "K254TM797"}');
      expect(r.gosNumber, 'К254ТМ797'); // кириллица
      expect(detectPlateCountry(r.gosNumber), PlateCountry.ru);
    });

    test('кириллический госномер проходит без изменений', () {
      final r = parse('{"gosNumber": "К254ТМ797"}');
      expect(r.gosNumber, 'К254ТМ797');
      expect(detectPlateCountry(r.gosNumber), PlateCountry.ru);
    });

    test('О/0 путаница: буква О прочитана как 0 (В01600123 → В016ОО123)', () {
      // Реальный кейс: буквы О в позициях 4-5 распознались как нули.
      final r = parse('{"gosNumber": "В01600123"}');
      expect(r.gosNumber, 'В016ОО123');
      expect(detectPlateCountry(r.gosNumber), PlateCountry.ru);
    });

    test('О/0 путаница: 0 в цифровой позиции прочитан как О (ВО16ОО123)', () {
      final r = parse('{"gosNumber": "ВО16ОО123"}');
      expect(r.gosNumber, 'В016ОО123');
      expect(detectPlateCountry(r.gosNumber), PlateCountry.ru);
    });

    test('латиница + О/0 вместе (BO16OO123 → В016ОО123)', () {
      // Латинские B/O + путаница 0: обе канонизации в цепочке.
      final r = parse('{"gosNumber": "BO16OO123"}');
      expect(r.gosNumber, 'В016ОО123');
      expect(detectPlateCountry(r.gosNumber), PlateCountry.ru);
    });

    test('иностранный/непохожий номер не коверкается позиционным фиксом', () {
      // Не РФ-форма → coerce возвращает как есть (после latin→cyr).
      final r = parse('{"gosNumber": "123ABC02"}');
      expect(detectPlateCountry(r.gosNumber), isNot(PlateCountry.ru));
    });

    test('parses full СТС JSON — 6 полей отчёта', () {
      final r = parse(
        '{"docType": "sts", "vin": "XW7BF4FK10S012345", '
        '"gosNumber": "А123ВС77", "brand": "Volkswagen", '
        '"model": "Tiguan", "year": 2020, "color": "белый"}',
      );
      expect(r.docType, 'sts');
      expect(r.vin, 'XW7BF4FK10S012345');
      expect(r.gosNumber, 'А123ВС77');
      expect(r.brand, 'Volkswagen');
      expect(r.model, 'Tiguan');
      expect(r.year, '2020');
      expect(r.color, 'белый');
      expect(hasAnyDocScanData(r), isTrue);
    });

    test('лишние ключи модели (объём/топливо) не ломают разбор 6 полей', () {
      // Тип DocScanAiResult движковых полей не содержит — их извлекает
      // отдельный VIN-шаг, а не скан документа; лишние ключи игнорируются.
      final r = parse(
        '{"vin": "XW7BF4FK10S012345", "brand": "Kia", "model": "Rio", '
        '"engineVolume": "1598", "engineType": "Бензиновый", "power": "123"}',
      );
      expect(r.vin, 'XW7BF4FK10S012345');
      expect(r.brand, 'Kia');
      expect(r.model, 'Rio');
    });

    test('cyrillic lookalikes in VIN transliterate to latin', () {
      // ХТА (кириллица) → XTA: частый артефакт распознавания ладовских VIN.
      final r = parse('{"vin": "ХТА21099012345678"}');
      expect(r.vin, 'XTA21099012345678');
    });

    test('invalid VINs are dropped', () {
      expect(parse('{"vin": "SHORT"}').vin, '');
      // I, O, Q запрещены в VIN.
      expect(parse('{"vin": "IOQBF4FK10S012345"}').vin, '');
      expect(parse('{"vin": "XW7BF4FK10S01234"}').vin, ''); // 16 симв.
    });

    test('VIN survives spaces and dashes', () {
      expect(
        parse('{"vin": "xw7 bf4-fk10s 012345"}').vin,
        'XW7BF4FK10S012345',
      );
    });

    test('year: garbage rejected, plausible extracted', () {
      expect(parse('{"year": "н/у"}').year, '');
      expect(parse('{"year": "2015 г."}').year, '2015');
      expect(parse('{"year": 1998}').year, '1998');
    });

    test('docType canonicalized, unknown otherwise', () {
      expect(parse('{"docType": "PTS"}').docType, 'pts');
      expect(parse('{"docType": "справка"}').docType, 'unknown');
    });

    test('tolerates ```json fences and prose around object', () {
      final r = parse(
        'Вот результат:\n```json\n{"brand": "Kia", "model": "Rio"}\n```\nГотово.',
      );
      expect(r.brand, 'Kia');
      expect(r.model, 'Rio');
    });

    test('non-JSON → empty result, hasAnyDocScanData false', () {
      final r = parse('не могу распознать документ');
      expect(r, emptyDocScanAiResult);
      expect(hasAnyDocScanData(r), isFalse);
    });

    test('docType alone is not "data" for hasAnyDocScanData', () {
      final r = parse('{"docType": "sts"}');
      expect(hasAnyDocScanData(r), isFalse);
    });
  });
}

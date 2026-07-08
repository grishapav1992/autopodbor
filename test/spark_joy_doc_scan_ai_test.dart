import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_doc_scan_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DocScanAiResult parse(String text) => parseDocScanAiResult(text);

  group('parseDocScanAiResult', () {
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

import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_doc_scan_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Зеркала опций дропдаунов (_SparkJoyVehicleRegistry приватный) — держать
  // синхронно с spark_joy_vehicle_registry.dart.
  const engineTypes = ['Бензин', 'Дизель', 'Гибрид', 'Электро', 'Газ/Бензин'];
  final engineVolumes = List<String>.generate(
    43,
    (i) => (0.8 + i * 0.1).toStringAsFixed(1),
  );

  DocScanAiResult parse(String text) => parseDocScanAiResult(
    text,
    allowedEngineTypes: engineTypes,
    allowedEngineVolumes: engineVolumes,
  );

  group('parseDocScanAiResult', () {
    test('parses full СТС JSON, all fields normalized', () {
      final r = parse(
        '{"docType": "sts", "vin": "XW7BF4FK10S012345", '
        '"gosNumber": "А123ВС77", "brand": "Volkswagen", '
        '"model": "Tiguan", "year": 2020, "color": "белый", '
        '"engineVolume": 1.4, "engineType": "Бензин"}',
      );
      expect(r.docType, 'sts');
      expect(r.vin, 'XW7BF4FK10S012345');
      expect(r.gosNumber, 'А123ВС77');
      expect(r.brand, 'Volkswagen');
      expect(r.model, 'Tiguan');
      expect(r.year, '2020');
      expect(r.color, 'белый');
      expect(r.engineVolume, '1.4');
      expect(r.engineType, 'Бензин');
      expect(hasAnyDocScanData(r), isTrue);
    });

    test('volume in cm³ converts to litres (1598 → 1.6)', () {
      expect(parse('{"engineVolume": "1598"}').engineVolume, '1.6');
      expect(parse('{"engineVolume": "1 598,0 куб.см"}').engineVolume, '1.6');
    });

    test('volume with comma and litre suffix', () {
      expect(parse('{"engineVolume": "2,0 л"}').engineVolume, '2.0');
    });

    test('fuel maps by substring like GOST parser', () {
      expect(parse('{"engineType": "Бензиновый"}').engineType, 'Бензин');
      expect(parse('{"engineType": "дизельный"}').engineType, 'Дизель');
      expect(
        parse('{"engineType": "электрический"}').engineType,
        'Электро',
      );
      expect(parse('{"engineType": "керосин"}').engineType, '');
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

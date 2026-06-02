import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseVinPlateConverterResult (Phase 2)', () {
    test('parses the live JSON-string shape', () {
      final r = parseVinPlateConverterResult(
        '{"vin": "XTAGFL110JY123456", "year": 2017, "brand": "LADA", '
        '"found": true, "model": "VESTA", "gos_number": "Х872ТХ163"}',
      );
      expect(r.found, isTrue);
      expect(r.vin, 'XTAGFL110JY123456');
      expect(r.gosNumber, 'Х872ТХ163');
      expect(r.brand, 'LADA');
      expect(r.model, 'VESTA');
      expect(r.year, 2017);
      expect(r.timedOut, isFalse);
    });

    test('accepts an already-decoded map + string year', () {
      final r = parseVinPlateConverterResult(<String, dynamic>{
        'found': true,
        'vin': 'X',
        'gos_number': 'A001AA01',
        'brand': 'KIA',
        'model': 'RIO',
        'year': '2020',
      });
      expect(r.found, isTrue);
      expect(r.brand, 'KIA');
      expect(r.year, 2020);
    });

    test('found=false / empty / garbage → empty result', () {
      expect(parseVinPlateConverterResult('{"found": false}').found, isFalse);
      expect(parseVinPlateConverterResult('').found, isFalse);
      expect(parseVinPlateConverterResult(null).found, isFalse);
      expect(parseVinPlateConverterResult('not json').found, isFalse);
      final empty = parseVinPlateConverterResult(null);
      expect(empty.vin, isEmpty);
      expect(empty.year, isNull);
      // A settled not-found is NOT a timeout — drives «не найдено» vs
      // «ещё обрабатывается» in the UI.
      expect(empty.timedOut, isFalse);
    });
  });
}

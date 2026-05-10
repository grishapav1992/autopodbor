import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_plate_formats.dart';

void main() {
  group('detectPlateCountry — happy paths', () {
    test('РФ: А123ВЕ77', () {
      expect(detectPlateCountry('А123ВЕ77'), PlateCountry.ru);
    });
    test('РФ 3-digit region: А123ВЕ777', () {
      expect(detectPlateCountry('А123ВЕ777'), PlateCountry.ru);
    });
    test('Беларусь: 1234АА7', () {
      expect(detectPlateCountry('1234АА7'), PlateCountry.by);
    });
    test('Украина: АА1234АА', () {
      expect(detectPlateCountry('АА1234АА'), PlateCountry.ua);
    });
    test('Казахстан: 123ABC02', () {
      expect(detectPlateCountry('123ABC02'), PlateCountry.kz);
    });
    test('Армения: 12AB123', () {
      expect(detectPlateCountry('12AB123'), PlateCountry.am);
    });
    test('Киргизия: B1234ABC', () {
      expect(detectPlateCountry('B1234ABC'), PlateCountry.kg);
    });
    test('Узбекистан: 01A123AB', () {
      expect(detectPlateCountry('01A123AB'), PlateCountry.uz);
    });
    test('Абхазия: А123ВЕ80 распознаётся как АБХ а не РФ', () {
      // AB должен быть строже RU (фиксированный регион 80) и победить.
      expect(detectPlateCountry('А123ВЕ80'), PlateCountry.ab);
    });
  });

  group('detectPlateCountry — non-detected cases', () {
    test('пустая строка', () {
      expect(detectPlateCountry(''), null);
    });
    test('частичный ввод (РФ partial)', () {
      // Длина < minLength для всех форматов кроме AM (7).
      expect(detectPlateCountry('А12'), null);
    });
    test('немецкий plate не распознаётся', () {
      // BAB1234 не матчит ни один из 8 шаблонов.
      expect(detectPlateCountry('BAB1234'), null);
    });
    test('корейский plate с hangul не распознаётся', () {
      expect(detectPlateCountry('12가1234'), null);
    });
  });

  group('sanitizePlate с расширенным whitelist', () {
    test('Корея: hangul сохраняется в KR-формате', () {
      final fmt = plateFormatFor(PlateCountry.kr);
      expect(sanitizePlate('12가1234', fmt), '12가1234');
    });
    test('Япония: hiragana сохраняется в JP-формате', () {
      final fmt = plateFormatFor(PlateCountry.jp);
      expect(sanitizePlate('500さ1234', fmt), '500さ1234');
    });
    test('Китай: иероглиф сохраняется в CN-формате', () {
      final fmt = plateFormatFor(PlateCountry.cn);
      expect(sanitizePlate('京A12345', fmt), '京A12345');
    });
    test('Германия: дефис стрипается, буквы и цифры остаются', () {
      final fmt = plateFormatFor(PlateCountry.de);
      // '-' не в whitelist'е, удаляется.
      expect(sanitizePlate('B-AB1234', fmt), 'BAB1234');
    });
    test('Южная Осетия: hangul тоже проходит (после фикса)', () {
      // Регрессия из последнего ревью — _soFormat должен использовать
      // _plateAsianRanges как и другие skipValidation-страны.
      final fmt = plateFormatFor(PlateCountry.so);
      expect(sanitizePlate('가1234', fmt), '가1234');
    });
    test('РФ: латиница стрипается (whitelist строгий)', () {
      final fmt = plateFormatFor(PlateCountry.ru);
      expect(sanitizePlate('А123BВ77', fmt), 'А123В77');
    });
    test('обрезание по maxLength', () {
      final fmt = plateFormatFor(PlateCountry.ru);
      // maxLength=9, лишние символы режутся.
      expect(sanitizePlate('А123ВЕ77777777', fmt).length, 9);
    });
  });

  group('sanitizePlatePermissive', () {
    test('uppercases и стрипает пробелы', () {
      expect(sanitizePlatePermissive('а 123 ве 77'), 'А123ВЕ77');
    });
    test('режет до 14 символов', () {
      expect(sanitizePlatePermissive('А' * 20).length, 14);
    });
    test('не пропускает hangul (auto-mode только Cyr+Lat+digits)', () {
      // Permissive whitelist в auto-mode уже для детектора, hangul
      // не входит — и не должен, т.к. KR в детекторе нет.
      expect(sanitizePlatePermissive('가1234'), '1234');
    });
  });

  group('plateError с skipValidation', () {
    test('Южная Осетия: любой ввод не вызывает ошибку', () {
      final fmt = plateFormatFor(PlateCountry.so);
      expect(plateError('что-то 123', fmt), null);
      expect(plateError('хххххх', fmt), null);
    });
    test('Германия (picker-only): нет ошибки даже для невалидного ввода', () {
      final fmt = plateFormatFor(PlateCountry.de);
      expect(plateError('totally wrong format', fmt), null);
    });
    test('РФ: валидный plate — null', () {
      final fmt = plateFormatFor(PlateCountry.ru);
      expect(plateError('А123ВЕ77', fmt), null);
    });
    test('РФ: некорректный формат — ошибка', () {
      final fmt = plateFormatFor(PlateCountry.ru);
      expect(plateError('XYZ123', fmt), isNotNull);
    });
    test('Абхазия: регион не 80 — ошибка', () {
      final fmt = plateFormatFor(PlateCountry.ab);
      expect(plateError('А123ВЕ77', fmt), isNotNull);
    });
    test('Абхазия: регион 80 — null', () {
      final fmt = plateFormatFor(PlateCountry.ab);
      expect(plateError('А123ВЕ80', fmt), null);
    });
  });

  group('formatPlate раскладка', () {
    test('РФ: А 123 ВЕ 77', () {
      expect(formatPlate('А123ВЕ77', plateFormatFor(PlateCountry.ru)),
          'А 123 ВЕ 77');
    });
    test('Беларусь: 1234 АА-7', () {
      expect(formatPlate('1234АА7', plateFormatFor(PlateCountry.by)),
          '1234 АА-7');
    });
    test('Украина: АА 1234 АА', () {
      expect(formatPlate('АА1234АА', plateFormatFor(PlateCountry.ua)),
          'АА 1234 АА');
    });
    test('Корея: возвращается как есть (picker-only)', () {
      expect(formatPlate('12가1234', plateFormatFor(PlateCountry.kr)),
          '12가1234');
    });
    test('Германия: возвращается как есть (picker-only)', () {
      expect(formatPlate('BAB1234', plateFormatFor(PlateCountry.de)),
          'BAB1234');
    });
  });

  group('parsePlateCountry — wire-format compat', () {
    test('известные коды парсятся', () {
      expect(parsePlateCountry('ru'), PlateCountry.ru);
      expect(parsePlateCountry('ua'), PlateCountry.ua);
      expect(parsePlateCountry('ab'), PlateCountry.ab);
      expect(parsePlateCountry('kr'), PlateCountry.kr);
      expect(parsePlateCountry('other'), PlateCountry.other);
    });
    test('неизвестный код → fallback на РФ', () {
      expect(parsePlateCountry('XX'), PlateCountry.ru);
    });
    test('null → РФ', () {
      expect(parsePlateCountry(null), PlateCountry.ru);
    });
    test('uppercase wire-value тоже парсится', () {
      expect(parsePlateCountry('RU'), PlateCountry.ru);
    });
  });

  group('PlateFormat.skipValidation distribution', () {
    test('детектируемые страны имеют skipValidation=false', () {
      for (final fmt in kAutoDetectFormats) {
        expect(fmt.skipValidation, false,
            reason: '${fmt.country.name} в детекторе должна валидировать');
      }
    });
    test('picker-only страны имеют skipValidation=true', () {
      const detectorCountries = {
        PlateCountry.ru,
        PlateCountry.by,
        PlateCountry.kz,
        PlateCountry.am,
        PlateCountry.kg,
        PlateCountry.uz,
        PlateCountry.ab,
        PlateCountry.ua,
      };
      for (final fmt in kPlateFormats) {
        if (detectorCountries.contains(fmt.country)) continue;
        expect(fmt.skipValidation, true,
            reason: '${fmt.country.name} picker-only должна skip-validate');
      }
    });
    test('каждая enum-value имеет ровно один формат в kPlateFormats', () {
      final countries = kPlateFormats.map((f) => f.country).toSet();
      expect(countries.length, kPlateFormats.length,
          reason: 'дубликат страны в kPlateFormats');
      expect(countries, PlateCountry.values.toSet(),
          reason: 'не все enum-values покрыты в kPlateFormats');
    });
  });
}

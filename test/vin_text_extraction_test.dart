import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/vin_text_extraction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String strict(String text) =>
      extractVinFromOcrText(text, mode: VinExtractionMode.strict);
  String lenient(String text) =>
      extractVinFromOcrText(text, mode: VinExtractionMode.lenient);
  List<VinTextCandidate> strictCandidates(String text) =>
      extractVinCandidatesFromOcrText(text, mode: VinExtractionMode.strict);

  // Опорные VIN тестов:
  //  • 1HGCM82633A004352 — контрольная сумма ISO 3779 сходится;
  //  • XTA220990Y2765432 — РФ-стиль, сумма НЕ сходится, нет символов 1/L
  //    (repair 1↔L заведомо не переписывает);
  //  • Z8T4C5FS9BM005269 — второй не-checksum VIN без 1/L для ранжирования.
  const vinChecksum = '1HGCM82633A004352';
  const vinRf = 'XTA220990Y2765432';
  const vinRf2 = 'Z8T4C5FS9BM005269';

  group('strict: ложные срабатывания прежнего «супа» больше не проходят', () {
    test('регресс инцидента: склейка коротких строк не даёт VIN', () {
      // Прежний алгоритм склеивал все строки фото в одну и брал первое
      // 17-окно: TEL8926123456 7PR1CE2500 содержит «валидное» окно.
      expect(strict('TEL 8926\n123 45 67\nPRICE 2500'), '');
    });

    test('госномер + дата (ровно 17 значимых символов) отбрасывается', () {
      // А/В/С кириллические → 3 подстановки → не VIN.
      expect(strict('А123ВС777 01.02.2024'), '');
      expect(lenient('А123ВС777 01.02.2024'), '');
    });

    test('шильдик шины (18-24 символов, без метки и суммы) отбрасывается', () {
      expect(strict('225 45 R17 91W RUNFLAT M S'), '');
    });

    test('латинская строка из 17 символов с 3 подстановками I/O', () {
      expect(strict('DISCOUNT PRICES 250'), '');
      // lenient пропускает (человек подтверждает руками).
      expect(lenient('DISCOUNT PRICES 250'), 'D1SC0UNTPR1CES250');
    });

    test('телефонная строка 18-24 символов отбрасывается', () {
      expect(strict('TEL 8 926 123 45 68 OFFICE'), '');
    });

    test('плотная строка >24 символов пропускается целиком', () {
      expect(
        strict('AVTOSERVIS MOSKVA LENINGRADSKOE SHOSSE 125 KM 24H'),
        '',
      );
    });

    test('17 только цифр / только букв / пусто', () {
      expect(strict('12345678901234567'), '');
      expect(strict('ABCDEFGHJKMNPRSTU'), '');
      expect(strict(''), '');
      expect(lenient('12345678901234567'), '');
    });

    test('кириллическая наклейка с несмапленными буквами', () {
      expect(strict('ЗАМЕНА МАСЛА ПРОБЕГ 123456 КМ'), '');
      expect(lenient('ЗАМЕНА МАСЛА ПРОБЕГ 123456 КМ'), '');
    });

    test('3+ кириллических подстановки отбрасываются в обоих режимах', () {
      // Х, Т, А кириллические.
      expect(strict('ХТА220990Y2765432'), '');
      expect(lenient('ХТА220990Y2765432'), '');
    });

    test('окно в длинной строке без метки VIN и без суммы не принимается', () {
      expect(strict('N92 $vinRf'), '');
    });
  });

  group('strict: настоящие VIN находятся', () {
    test('checksum-валидный VIN отдельной строкой', () {
      expect(strict(vinChecksum), vinChecksum);
      final c = strictCandidates(vinChecksum).first;
      expect(c.checksumValid, isTrue);
      expect(c.standaloneToken, isTrue);
    });

    test('РФ-VIN без валидной суммы отдельной строкой (сумма — не гейт)', () {
      expect(strict(vinRf), vinRf);
      expect(strictCandidates(vinRf).first.checksumValid, isFalse);
    });

    test('метка «VIN:» открывает окно в строке с хвостом', () {
      expect(strict('VIN: $vinRf RUS'), vinRf);
      expect(strict('VIN $vinRf'), vinRf);
      expect(strictCandidates('VIN $vinRf').first.hadVinLabel, isTrue);
    });

    test('пробелы и дефисы внутри строки не мешают', () {
      expect(strict('XTA 220990 Y2765432'), vinRf);
      expect(strict('XTA-220990-Y2765432'), vinRf);
    });

    test('1-2 кириллических мисрида допустимы', () {
      // Т кириллическая — одна подстановка.
      expect(strict('XТA220990Y2765432'), vinRf);
      expect(
        strictCandidates('XТA220990Y2765432').first.cyrillicSubstitutionCount,
        1,
      );
    });

    test('VIN с буквой L сохраняется (регресс прежнего L→1)', () {
      // Checksum-валидный, поэтому repair 1↔L не трогает.
      const vinWithL = '5LMFU285X5LJ12345';
      expect(strict(vinWithL), vinWithL);
      expect(strictCandidates(vinWithL).first.checksumValid, isTrue);
    });

    test('repair 1↔L по контрольной сумме чинит мисрид', () {
      // L вместо 1 в первой позиции: единственный toggle даёт валидную сумму.
      expect(strict('LHGCM82633A004352'), vinChecksum);
    });

    test('маркер [PSM8] web-распознавания срезается', () {
      expect(strict('[PSM8] $vinRf'), vinRf);
    });

    test('VIN, начинающийся с V1N, не теряет префикс из-за метки', () {
      // Метка «VIN» срезается только когда после неё остаётся полный VIN.
      expect(strict('V1NXTA220990Y2765'), 'V1NXTA220990Y2765');
    });
  });

  group('ранжирование кандидатов', () {
    test('сошедшаяся сумма важнее порядка строк', () {
      final c = strictCandidates('$vinRf\n$vinChecksum');
      expect(c.first.vin, vinChecksum);
      expect(c.first.checksumValid, isTrue);
      expect(c[1].vin, vinRf);
    });

    test('строка-токен важнее окна', () {
      final c = strictCandidates('VIN ${vinRf}X\n$vinRf2');
      expect(c.first.vin, vinRf2);
      expect(c.first.standaloneToken, isTrue);
    });

    test('при прочих равных выигрывает более ранняя строка', () {
      expect(strict('$vinRf\n$vinRf2'), vinRf);
    });
  });

  group('lenient: recall ручного сканера', () {
    test('VIN, разбитый OCR на две строки, находится фолбэком-склейкой', () {
      expect(strict('XTA22099\n0Y2765432'), '');
      expect(lenient('XTA22099\n0Y2765432'), vinRf);
    });

    test('безметочное окно в длинной строке находится', () {
      final vin = lenient('N92 $vinRf');
      expect(vin, isNotEmpty);
      expect(isStrictVin(vin), isTrue);
    });
  });

  group('isStrictVin / isValidVinChecksum / fixVinOcrAmbiguity', () {
    test('isStrictVin: формат', () {
      expect(isStrictVin(vinRf), isTrue);
      expect(isStrictVin('XTA220990Y276543'), isFalse); // 16
      expect(isStrictVin('XTA220990Q2765432'), isFalse); // Q
      expect(isStrictVin('12345678901234567'), isFalse); // нет буквы
      expect(isStrictVin('ABCDEFGHJKMNPRSTU'), isFalse); // нет цифры
    });

    test('isValidVinChecksum', () {
      expect(isValidVinChecksum(vinChecksum), isTrue);
      expect(isValidVinChecksum(vinRf), isFalse);
    });

    test('fixVinOcrAmbiguity', () {
      expect(fixVinOcrAmbiguity(vinChecksum), vinChecksum); // валидный не трогаем
      expect(fixVinOcrAmbiguity('LHGCM82633A004352'), vinChecksum);
      expect(fixVinOcrAmbiguity(vinRf), vinRf); // нет символов 1/L
    });
  });
}

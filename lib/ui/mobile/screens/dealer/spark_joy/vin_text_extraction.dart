/// Чистое извлечение VIN из OCR-текста (MLKit/Tesseract) — без Flutter-зависимостей.
///
/// Ключевое отличие от прежней логики: текст НЕ склеивается в одну строку.
/// Прежний алгоритм выбрасывал все пробелы/переносы по всей фотографии и брал
/// первое 17-символьное окно — из-за этого «VIN» находился на шильдике шины,
/// наклейке ТО или связке «госномер + дата» и уходил в платные проверки
/// (инцидент 2026-07-21). Здесь кандидаты ищутся построчно, плотные строки
/// отбрасываются, а контрольная сумма ISO 3779 используется как сигнал доверия
/// при ранжировании (гейтом её делать нельзя: у многих валидных РФ-VIN
/// контрольная цифра не по ISO).
library;

/// Режим извлечения.
///
///  • [strict] — безнадзорные потребители (OCR-свип интейка): находка молча
///    автозаполняет поле и запускает платные проверки, поэтому оконные
///    кандидаты принимаются только с меткой «VIN» или сошедшейся контрольной
///    суммой, а суммарные OCR-подстановки ограничены.
///  • [lenient] — потоки с человеком в контуре (ручной сканер VIN, скан СТС):
///    пользователь видит и подтверждает кандидата, допустим широкий recall,
///    включая легаси-фолбэк по склеенному тексту (VIN, разбитый OCR на две
///    строки).
enum VinExtractionMode { strict, lenient }

/// Кандидат VIN из OCR-текста с признаками для ранжирования.
class VinTextCandidate {
  const VinTextCandidate({
    required this.vin,
    required this.checksumValid,
    required this.standaloneToken,
    required this.hadVinLabel,
    required this.lineIndex,
    required this.substitutionCount,
    required this.cyrillicSubstitutionCount,
  });

  /// Итоговый VIN (после [fixVinOcrAmbiguity]).
  final String vin;

  /// Контрольная сумма ISO 3779 сошлась (считается ПОСЛЕ репейра 1↔L).
  final bool checksumValid;

  /// Строка целиком состояла из 17 значимых символов (не окно в длинной строке).
  final bool standaloneToken;

  /// В сырой строке была метка «VIN» (в т.ч. OCR-искажения V1N/VLN/VІN).
  final bool hadVinLabel;

  /// Индекс строки в исходном тексте (меньше — выше на фото).
  final int lineIndex;

  /// Сколько символов получено OCR-подстановками (кириллица + I/O/Q/|).
  final int substitutionCount;

  /// Из них кириллических подстановок (А→A, О→0, …).
  final int cyrillicSubstitutionCount;
}

const int _vinLength = 17;

/// Строки с alnum-остатком длиннее этого — плотный текст (объявление, адрес),
/// окна в них не ищем. 18..24 покрывает «VIN: <17>» и мусорный хвост/префикс
/// в пару символов.
const int _maxWindowLineLength = 24;

/// Больше двух кириллических подстановок — почти наверняка русский текст
/// (госномер, наклейка), а не латинский VIN с парой мисридов.
const int _maxCyrillicSubstitutions = 2;

/// В strict-режиме ограничиваем и суммарные подстановки: строка из латинских
/// слов с I/O (например «DISCOUNT PRICES 250») не должна превращаться в VIN.
const int _maxStrictSubstitutions = 2;

const List<int> _vinWeights = [
  8,
  7,
  6,
  5,
  4,
  3,
  2,
  10,
  0,
  9,
  8,
  7,
  6,
  5,
  4,
  3,
  2,
];

const Map<String, int> _vinTransliteration = {
  'A': 1,
  'B': 2,
  'C': 3,
  'D': 4,
  'E': 5,
  'F': 6,
  'G': 7,
  'H': 8,
  'J': 1,
  'K': 2,
  'L': 3,
  'M': 4,
  'N': 5,
  'P': 7,
  'R': 9,
  'S': 2,
  'T': 3,
  'U': 4,
  'V': 5,
  'W': 6,
  'X': 7,
  'Y': 8,
  'Z': 9,
  '0': 0,
  '1': 1,
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
};

/// Кириллические двойники → латиница/цифры. Считаются и как подстановка, и
/// как кириллическая подстановка.
const Map<String, String> _cyrillicVinMap = {
  'А': 'A',
  'В': 'B',
  'С': 'C',
  'Е': 'E',
  'Н': 'H',
  'К': 'K',
  'М': 'M',
  'Р': 'P',
  'Т': 'T',
  'У': 'Y',
  'Х': 'X',
  'О': '0',
  'З': '3',
  'Б': '6',
  'І': '1',
};

/// Латинские/символьные OCR-двойники. ВАЖНО: L НЕ конвертируется — это
/// валидный символ VIN, прежняя замена L→1 портила настоящие VIN с буквой L;
/// путаницу 1↔L решает [fixVinOcrAmbiguity] по контрольной сумме.
const Map<String, String> _latinVinMap = {'I': '1', 'O': '0', 'Q': '0', '|': '1'};

final RegExp _validVinCharRe = RegExp(r'[A-HJ-NPR-Z0-9]');
final RegExp _lineSplitRe = RegExp(r'[\r\n]+');

/// Маркер варианта распознавания в web-rawText (`[PSM8] …`, web/vin_ocr.js).
final RegExp _psmMarkerRe = RegExp(r'^\[PSM\d+\]\s*');

/// Метка «VIN» в начале строки, включая OCR-искажения буквы I (1/L/І/|) и
/// обрамление скобками/разделителями.
final RegExp _vinLabelRe = RegExp(
  r'^[(\[]?V[I1LІ|]N[)\]]?\s*[:№#=\-–—]*\s*',
  caseSensitive: false,
);

/// Строгий формат VIN: 17 символов, без I/O/Q, минимум одна буква и одна
/// цифра. 1:1 семантика прежнего `_isStrictVin`.
bool isStrictVin(String value) {
  final vin = value.trim().toUpperCase();
  if (vin.length != _vinLength) return false;
  if (RegExp(r'[IOQ]').hasMatch(vin)) return false;
  if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin)) return false;
  if (!RegExp(r'[A-Z]').hasMatch(vin) || !RegExp(r'\d').hasMatch(vin)) {
    return false;
  }
  return true;
}

/// Контрольная сумма ISO 3779 (9-й символ). 1:1 прежнего `_isValidVinChecksum`.
bool isValidVinChecksum(String vin) {
  if (!isStrictVin(vin)) return false;
  var sum = 0;
  for (var i = 0; i < vin.length; i++) {
    final value = _vinTransliteration[vin[i]];
    if (value == null) return false;
    sum += value * _vinWeights[i];
  }
  final remainder = sum % 11;
  final expected = remainder == 10 ? 'X' : remainder.toString();
  return vin[8] == expected;
}

String _toggleVinAmbiguousChar(String vin, int index) {
  if (index < 0 || index >= vin.length) return vin;
  final ch = vin[index];
  if (ch != '1' && ch != 'L') return vin;
  final replacement = ch == '1' ? 'L' : '1';
  return vin.substring(0, index) + replacement + vin.substring(index + 1);
}

/// Чинит OCR-путаницу 1↔L по контрольной сумме: если сумма не сошлась и
/// существует ЕДИНСТВЕННЫЙ вариант с 1-2 переключениями, дающий валидную
/// сумму, — возвращает его. 1:1 прежнего `_maybeFixVinOcrAmbiguity`.
String fixVinOcrAmbiguity(String value) {
  final vin = value.trim().toUpperCase();
  if (!isStrictVin(vin)) return vin;
  if (isValidVinChecksum(vin)) return vin;

  final ambiguousIndexes = <int>[];
  for (var i = 0; i < vin.length; i++) {
    if (i == 8) continue;
    if (vin[i] == '1' || vin[i] == 'L') {
      ambiguousIndexes.add(i);
    }
  }
  if (ambiguousIndexes.isEmpty) return vin;

  final validCandidates = <String>{};

  for (final index in ambiguousIndexes) {
    final candidate = _toggleVinAmbiguousChar(vin, index);
    if (isStrictVin(candidate) && isValidVinChecksum(candidate)) {
      validCandidates.add(candidate);
    }
  }

  const maxPairChecks = 28;
  var pairChecks = 0;
  for (var i = 0; i < ambiguousIndexes.length; i++) {
    for (var j = i + 1; j < ambiguousIndexes.length; j++) {
      if (pairChecks >= maxPairChecks) break;
      pairChecks += 1;
      final first = _toggleVinAmbiguousChar(vin, ambiguousIndexes[i]);
      final candidate = _toggleVinAmbiguousChar(first, ambiguousIndexes[j]);
      if (isStrictVin(candidate) && isValidVinChecksum(candidate)) {
        validCandidates.add(candidate);
      }
    }
    if (pairChecks >= maxPairChecks) break;
  }

  if (validCandidates.length == 1) {
    return validCandidates.first;
  }
  return vin;
}

/// Нормализованный alnum-остаток строки с пометками подстановок по позициям.
class _NormalizedRun {
  _NormalizedRun(this.chars, this.cyrillic, this.substituted);

  final String chars;
  final List<bool> cyrillic;
  final List<bool> substituted;

  int cyrillicCount(int start, int end) =>
      cyrillic.sublist(start, end).where((f) => f).length;

  int substitutionCount(int start, int end) =>
      substituted.sublist(start, end).where((f) => f).length;
}

_NormalizedRun _normalizeRun(String value) {
  final buf = StringBuffer();
  final cyr = <bool>[];
  final sub = <bool>[];
  for (final ch in value.toUpperCase().split('')) {
    final mappedCyr = _cyrillicVinMap[ch];
    if (mappedCyr != null) {
      buf.write(mappedCyr);
      cyr.add(true);
      sub.add(true);
      continue;
    }
    final mappedLat = _latinVinMap[ch];
    if (mappedLat != null) {
      buf.write(mappedLat);
      cyr.add(false);
      sub.add(true);
      continue;
    }
    if (_validVinCharRe.hasMatch(ch)) {
      buf.write(ch);
      cyr.add(false);
      sub.add(false);
    }
    // Всё остальное (пробелы, пунктуация, несмапленная кириллица) — сепаратор
    // внутри строки; строки между собой не склеиваются никогда.
  }
  return _NormalizedRun(buf.toString(), cyr, sub);
}

/// Все кандидаты VIN из OCR-текста, отранжированные от лучшего к худшему:
/// сошедшаяся контрольная сумма → строка-токен из ровно 17 символов → метка
/// «VIN» → более ранняя строка → меньше OCR-подстановок.
List<VinTextCandidate> extractVinCandidatesFromOcrText(
  String rawText, {
  required VinExtractionMode mode,
}) {
  final candidates = <VinTextCandidate>[];
  final lines = rawText.split(_lineSplitRe);
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    var line = lines[lineIndex].trim().replaceFirst(_psmMarkerRe, '');
    if (line.isEmpty) continue;

    var hadVinLabel = false;
    final labelMatch = _vinLabelRe.firstMatch(line);
    if (labelMatch != null) {
      final rest = line.substring(labelMatch.end);
      // Метку срезаем, только если после неё остаётся полный VIN: иначе
      // реальный VIN, начинающийся с «V1N…», потерял бы первые символы.
      if (_normalizeRun(rest).chars.length >= _vinLength) {
        hadVinLabel = true;
        line = rest;
      }
    }

    final run = _normalizeRun(line);
    final len = run.chars.length;
    if (len < _vinLength || len > _maxWindowLineLength) continue;

    final standalone = len == _vinLength;
    for (var start = 0; start <= len - _vinLength; start++) {
      final end = start + _vinLength;
      final windowVin = run.chars.substring(start, end);
      if (!isStrictVin(windowVin)) continue;

      final cyrCount = run.cyrillicCount(start, end);
      if (cyrCount > _maxCyrillicSubstitutions) continue;
      final subCount = run.substitutionCount(start, end);
      if (mode == VinExtractionMode.strict &&
          subCount > _maxStrictSubstitutions) {
        continue;
      }

      final vin = fixVinOcrAmbiguity(windowVin);
      final checksumValid = isValidVinChecksum(vin);
      // Окно в длинной строке — слабый сигнал: в strict принимаем его только
      // с меткой «VIN» или сошедшейся суммой (шины/телефоны/наклейки дают
      // 18-24 значимых символа и валидное по формату окно).
      if (mode == VinExtractionMode.strict &&
          !standalone &&
          !hadVinLabel &&
          !checksumValid) {
        continue;
      }

      candidates.add(
        VinTextCandidate(
          vin: vin,
          checksumValid: checksumValid,
          standaloneToken: standalone,
          hadVinLabel: hadVinLabel,
          lineIndex: lineIndex,
          substitutionCount: subCount,
          cyrillicSubstitutionCount: cyrCount,
        ),
      );
    }
  }

  if (candidates.isEmpty && mode == VinExtractionMode.lenient) {
    final fallback = _legacySoupCandidate(rawText);
    if (fallback != null) return [fallback];
    return const [];
  }

  // Стабильная сортировка: List.sort в Dart нестабильна, порядок вставки
  // (строка выше / окно левее) — последний тай-брейк.
  final indexed = candidates.asMap().entries.toList()
    ..sort((a, b) {
      final x = a.value;
      final y = b.value;
      if (x.checksumValid != y.checksumValid) {
        return x.checksumValid ? -1 : 1;
      }
      if (x.standaloneToken != y.standaloneToken) {
        return x.standaloneToken ? -1 : 1;
      }
      if (x.hadVinLabel != y.hadVinLabel) return x.hadVinLabel ? -1 : 1;
      if (x.lineIndex != y.lineIndex) return x.lineIndex - y.lineIndex;
      if (x.substitutionCount != y.substitutionCount) {
        return x.substitutionCount - y.substitutionCount;
      }
      return a.key - b.key;
    });

  final seen = <String>{};
  final result = <VinTextCandidate>[];
  for (final entry in indexed) {
    if (seen.add(entry.value.vin)) result.add(entry.value);
  }
  return result;
}

/// Легаси-фолбэк для lenient: склейка всего текста и первое валидное окно —
/// сохраняет recall ручного сканера (VIN, разбитый OCR на две строки).
/// Кириллический лимит действует и здесь.
VinTextCandidate? _legacySoupCandidate(String rawText) {
  final run = _normalizeRun(rawText);
  final len = run.chars.length;
  if (len < _vinLength) return null;
  for (var start = 0; start <= len - _vinLength; start++) {
    final end = start + _vinLength;
    final windowVin = run.chars.substring(start, end);
    if (!isStrictVin(windowVin)) continue;
    final cyrCount = run.cyrillicCount(start, end);
    if (cyrCount > _maxCyrillicSubstitutions) continue;
    final vin = fixVinOcrAmbiguity(windowVin);
    return VinTextCandidate(
      vin: vin,
      checksumValid: isValidVinChecksum(vin),
      standaloneToken: false,
      hadVinLabel: false,
      lineIndex: 0,
      substitutionCount: run.substitutionCount(start, end),
      cyrillicSubstitutionCount: cyrCount,
    );
  }
  return null;
}

/// Лучший VIN из OCR-текста либо пустая строка.
String extractVinFromOcrText(
  String rawText, {
  required VinExtractionMode mode,
}) {
  final candidates = extractVinCandidatesFromOcrText(rawText, mode: mode);
  return candidates.isEmpty ? '' : candidates.first.vin;
}

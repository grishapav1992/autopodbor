import 'spark_joy_vin_params_ai.dart' show extractJsonObject;
import 'spark_joy_plate_formats.dart' show detectPlateCountry, PlateCountry;

/// Результат ИИ-распознавания фото СТС (AiQueue vision). Ровно 6 полей отчёта,
/// которые извлекаем из документа (решение дева 2026-07-08): госномер, VIN,
/// марка, модель, год, цвет. VIN — к строгому формату, год — 4 цифры,
/// остальное — trim + кап длины (или `''`, если не распознано/невалидно).
/// Движковые параметры (объём/топливо/КПП) из СТС НЕ берём — их дозаполняет
/// отдельный VIN-шаг (`_autofillParamsFromVinWithAi`) после установки VIN.
/// Чистый top-level тип/функция без Flutter-зависимостей для юнит-тестов.
typedef DocScanAiResult = ({
  String docType, // 'sts' | 'pts' | 'epts' | 'unknown'
  String vin,
  String gosNumber,
  String brand,
  String model,
  String year,
  String color,
});

const DocScanAiResult emptyDocScanAiResult = (
  docType: 'unknown',
  vin: '',
  gosNumber: '',
  brand: '',
  model: '',
  year: '',
  color: '',
);

/// Есть ли в результате хоть одно применимое поле (docType не считается —
/// сам по себе он ничего не заполняет).
bool hasAnyDocScanData(DocScanAiResult r) =>
    r.vin.isNotEmpty ||
    r.gosNumber.isNotEmpty ||
    r.brand.isNotEmpty ||
    r.model.isNotEmpty ||
    r.year.isNotEmpty ||
    r.color.isNotEmpty;

// Кириллические двойники латиницы (визуально идентичные глифы): модель может
// «прочитать» VIN в русской раскладке. После транслита строгая валидация всё
// равно отсеет символы, запрещённые в VIN (I, O, Q → в т.ч. бывшие О/о).
const Map<String, String> _cyrToLat = {
  'А': 'A', 'В': 'B', 'Е': 'E', 'К': 'K', 'М': 'M', 'Н': 'H',
  'О': 'O', 'Р': 'P', 'С': 'C', 'Т': 'T', 'У': 'Y', 'Х': 'X',
};

final RegExp _strictVinRe = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

/// Канонизирует VIN из ответа модели: upper, без пробелов/дефисов,
/// кириллица → латиница, затем строгая проверка (17 символов, без I/O/Q).
/// Не подошло → `''`.
String canonDocScanVin(dynamic raw) {
  var v = (raw ?? '')
      .toString()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]'), '');
  if (v.isEmpty) return '';
  _cyrToLat.forEach((cyr, lat) => v = v.replaceAll(cyr, lat));
  return _strictVinRe.hasMatch(v) ? v : '';
}

// Латинские двойники → кириллица для РОССИЙСКОГО госномера (обратна _cyrToLat).
// Vision часто транслитерирует «К254ТМ797» в латиницу «K254TM797», а
// RU-детектор (spark_joy_plate_formats) требует кириллицу: иначе латинские
// буквы вырезаются как «не из алфавита», номер не опознаётся как РФ (страна →
// «Другая»), а латинский номер не матчится в ApiCloud (конвертер/проверки).
// СТС — российский документ, номер всегда РФ-кириллица, поэтому маппинг
// безопасен (буквы вне набора РФ-плат тут не встречаются).
const Map<String, String> _latToPlateCyr = {
  'A': 'А', 'B': 'В', 'E': 'Е', 'K': 'К', 'M': 'М', 'H': 'Н',
  'O': 'О', 'P': 'Р', 'C': 'С', 'T': 'Т', 'Y': 'У', 'X': 'Х',
};

/// Канонизирует госномер из ответа модели: upper, без пробелов/дефисов,
/// латинские двойники → кириллица (см. [_latToPlateCyr]) + позиционный фикс
/// О↔0 (см. [_coerceRuPlateOhZero]) — чтобы РФ-детектор опознал номер и он
/// совпал с базами ApiCloud. Кап 16 символов.
String canonDocScanPlate(dynamic raw) {
  var v = (raw ?? '')
      .toString()
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]'), '');
  if (v.isEmpty) return '';
  _latToPlateCyr.forEach((lat, cyr) => v = v.replaceAll(lat, cyr));
  v = _coerceRuPlateOhZero(v);
  return v.length > 16 ? v.substring(0, 16) : v;
}

/// Чинит путаницу буквы «О» и цифры «0» в РФ-номере (визуально идентичны —
/// vision их мешает: реальный кейс «В016ОО123» распозналось как «В01600123»,
/// буквы О стали нулями). РФ-форма фиксирована — буква,3 цифры,2 буквы,2-3
/// цифры региона (буквенные позиции 0/4/5). В буквенных позициях `0`→`О`, в
/// цифровых `О`→`0`. Применяем ТОЛЬКО если после правки строка — валидный
/// РФ-номер (через существующий [detectPlateCountry]); иначе иностранный
/// номер/мусор возвращаем нетронутым.
String _coerceRuPlateOhZero(String s) {
  if (s.length != 8 && s.length != 9) return s;
  const letterPos = {0, 4, 5};
  final chars = s.split('');
  for (var i = 0; i < chars.length; i++) {
    if (letterPos.contains(i) && chars[i] == '0') {
      chars[i] = 'О'; // цифра 0 в буквенной позиции → буква О
    } else if (!letterPos.contains(i) && chars[i] == 'О') {
      chars[i] = '0'; // буква О в цифровой позиции → цифра 0
    }
  }
  final coerced = chars.join();
  return detectPlateCountry(coerced) == PlateCountry.ru ? coerced : s;
}

/// Парсит + нормализует ответ модели по фото СТС в [DocScanAiResult].
/// Извлекает 6 полей отчёта: docType (тех.), vin, gosNumber, brand, model,
/// year, color. Никогда не бросает.
DocScanAiResult parseDocScanAiResult(String modelText) {
  final obj = extractJsonObject(modelText);
  if (obj == null) return emptyDocScanAiResult;

  String capped(dynamic raw, int max) {
    final v = (raw ?? '').toString().trim();
    return v.length > max ? v.substring(0, max).trim() : v;
  }

  String docType() {
    final v = (obj['docType'] ?? '').toString().trim().toLowerCase();
    return const {'sts', 'pts', 'epts'}.contains(v) ? v : 'unknown';
  }

  String year() {
    final raw = (obj['year'] ?? '').toString();
    final match = RegExp(r'(19|20)\d{2}').firstMatch(raw);
    return match?.group(0) ?? '';
  }

  return (
    docType: docType(),
    vin: canonDocScanVin(obj['vin']),
    gosNumber: canonDocScanPlate(obj['gosNumber']),
    brand: capped(obj['brand'], 40),
    model: capped(obj['model'], 60),
    year: year(),
    color: capped(obj['color'], 30),
  );
}

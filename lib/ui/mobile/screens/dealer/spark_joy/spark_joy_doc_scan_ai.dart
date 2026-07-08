import 'spark_joy_vin_params_ai.dart' show extractJsonObject;

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
    gosNumber: capped(obj['gosNumber'], 16),
    brand: capped(obj['brand'], 40),
    model: capped(obj['model'], 60),
    year: year(),
    color: capped(obj['color'], 30),
  );
}

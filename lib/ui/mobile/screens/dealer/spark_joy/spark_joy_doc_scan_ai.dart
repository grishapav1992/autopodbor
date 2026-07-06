import 'spark_joy_vin_params_ai.dart' show extractJsonObject;

/// Результат ИИ-распознавания фото СТС/ПТС (AiQueue vision). Все поля уже
/// нормализованы: enum'ы — к каноничным опциям дропдаунов «Параметров»,
/// VIN — к строгому формату, остальное — trim + кап длины (или `''`, если
/// поле не распознано/невалидно). Стиль зеркалит [VinParamsAiResult] —
/// чистый top-level тип/функция без Flutter-зависимостей для юнит-тестов.
typedef DocScanAiResult = ({
  String docType, // 'sts' | 'pts' | 'epts' | 'unknown'
  String vin,
  String gosNumber,
  String brand,
  String model,
  String year,
  String color,
  String engineVolume,
  String engineType,
});

const DocScanAiResult emptyDocScanAiResult = (
  docType: 'unknown',
  vin: '',
  gosNumber: '',
  brand: '',
  model: '',
  year: '',
  color: '',
  engineVolume: '',
  engineType: '',
);

/// Есть ли в результате хоть одно применимое поле (docType не считается —
/// сам по себе он ничего не заполняет).
bool hasAnyDocScanData(DocScanAiResult r) =>
    r.vin.isNotEmpty ||
    r.gosNumber.isNotEmpty ||
    r.brand.isNotEmpty ||
    r.model.isNotEmpty ||
    r.year.isNotEmpty ||
    r.color.isNotEmpty ||
    r.engineVolume.isNotEmpty ||
    r.engineType.isNotEmpty;

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

/// Парсит + нормализует ответ модели по фото СТС/ПТС в [DocScanAiResult].
///
/// [allowedEngineTypes] / [allowedEngineVolumes] — точные опции дропдаунов
/// (`_SparkJoyVehicleRegistry`). Топливо маппится подстрочно (как в
/// `parseGostCertificateParams`: «Бензиновый» → «Бензин»). Объём терпит
/// см³ (1598 → 1.6) и литры с запятой; принимается только значение из
/// списка дропдауна. Никогда не бросает.
DocScanAiResult parseDocScanAiResult(
  String modelText, {
  required List<String> allowedEngineTypes,
  required List<String> allowedEngineVolumes,
}) {
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

  String fuel() {
    final raw = (obj['engineType'] ?? '').toString().toLowerCase().trim();
    if (raw.isEmpty) return '';
    final String mapped;
    if (raw.contains('дизель')) {
      mapped = 'Дизель';
    } else if (raw.contains('гибрид')) {
      mapped = 'Гибрид';
    } else if (raw.contains('электр')) {
      mapped = 'Электро';
    } else if (raw.contains('газ')) {
      mapped = 'Газ/Бензин';
    } else if (raw.contains('бензин')) {
      mapped = 'Бензин';
    } else {
      return '';
    }
    for (final opt in allowedEngineTypes) {
      if (opt.toLowerCase() == mapped.toLowerCase()) return opt;
    }
    return '';
  }

  // Объём: число из строки/числа; > 20 трактуем как см³ (в СТС/ПТС объём
  // пишется в куб.см) → делим на 1000. Округление к 0.1 и сверка со списком —
  // как в canonVolume у parseVinParamsAiResult.
  String volume() {
    final raw = obj['engineVolume'];
    if (raw == null) return '';
    var str = raw is num ? raw.toString() : raw.toString().trim();
    if (str.isEmpty) return '';
    // «1 598,0 куб.см»: пробел/неразрывный пробел как разделитель тысяч
    // порвал бы число на «1» и «598» — склеиваем до матча.
    str = str.replaceAll(RegExp(r'[\s ]'), '');
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(str);
    if (match == null) return '';
    var asNum = double.tryParse(match.group(0)!.replaceAll(',', '.'));
    if (asNum == null || asNum <= 0) return '';
    if (asNum > 20) asNum /= 1000; // см³ → литры
    final formatted = asNum.toStringAsFixed(1);
    return allowedEngineVolumes.contains(formatted) ? formatted : '';
  }

  return (
    docType: docType(),
    vin: canonDocScanVin(obj['vin']),
    gosNumber: capped(obj['gosNumber'], 16),
    brand: capped(obj['brand'], 40),
    model: capped(obj['model'], 60),
    year: year(),
    color: capped(obj['color'], 30),
    engineVolume: volume(),
    engineType: fuel(),
  );
}

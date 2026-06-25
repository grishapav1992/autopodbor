import 'dart:convert';

/// Результат AI-вывода технических параметров по VIN. Все поля уже
/// нормализованы к каноничным строкам дропдаунов раздела «Параметры»
/// (или `''`, если неизвестно/невалидно). Стиль записи зеркалит
/// `parseVinPlateConverterResult` из `storage_api.dart` — чистый top-level
/// тип/функция без Flutter-зависимостей, чтобы юнит-тест шёл без харнеса.
typedef VinParamsAiResult = ({
  String engineVolume,
  String engineType,
  String transmission,
  String driveType,
  String equipment,
});

const VinParamsAiResult emptyVinParamsAiResult = (
  engineVolume: '',
  engineType: '',
  transmission: '',
  driveType: '',
  equipment: '',
);

/// Вырезает первый `{`..последний `}` (терпит ```json-заборы и обрамляющую
/// прозу), затем `json.decode`. Ключи приводятся к String. Возвращает `null`
/// при любом сбое — НИКОГДА не бросает.
Map<String, dynamic>? extractJsonObject(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final start = s.indexOf('{');
  if (start < 0) return null;
  // Сканируем первый СБАЛАНСИРОВАННЫЙ верхнеуровневый объект, игнорируя скобки
  // внутри строк — так хвостовая проза с `}` после JSON не ломает разбор.
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < s.length; i++) {
    final ch = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        try {
          final decoded = json.decode(s.substring(start, i + 1));
          return decoded is Map
              ? decoded.map((key, value) => MapEntry('$key', value))
              : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null; // объект не закрыт
}

/// Парсит + нормализует текст модели в [VinParamsAiResult].
///
/// Списки `allowed*` — точные опции дропдаунов (`_SparkJoyVehicleRegistry`),
/// `allowedEngineVolumes` — сгенерированный 0.8…5.0. Совпадение enum —
/// регистронезависимое → каноничная опция из списка; всё прочее
/// отбрасывается в `''`. `engineVolume` парсится как число (терпит запятую),
/// округляется к 0.1 и должен попасть в список (иначе `''`). `equipment` —
/// trim + кап 80 символов. Никогда не бросает.
VinParamsAiResult parseVinParamsAiResult(
  String modelText, {
  required List<String> allowedEngineTypes,
  required List<String> allowedGearboxTypes,
  required List<String> allowedDriveTypes,
  required List<String> allowedEngineVolumes,
}) {
  final obj = extractJsonObject(modelText);
  if (obj == null) return emptyVinParamsAiResult;

  String canon(dynamic raw, List<String> allowed) {
    final v = (raw ?? '').toString().trim();
    if (v.isEmpty) return '';
    for (final opt in allowed) {
      if (opt.toLowerCase() == v.toLowerCase()) return opt; // каноничный регистр
    }
    return '';
  }

  // engineVolume: число или строка, запятая → точка, в литрах с одним знаком.
  // Округляем к 0.1 (toStringAsFixed нормализует и список, и ввод одинаково),
  // принимаем только если значение есть в списке дропдауна.
  String canonVolume(dynamic raw) {
    if (raw == null) return '';
    final str = raw is num ? raw.toString() : raw.toString().trim();
    if (str.isEmpty) return '';
    // Терпим суффикс единицы («1.6 л», «1,6 L») — берём первое число.
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(str);
    if (match == null) return '';
    final asNum = double.tryParse(match.group(0)!.replaceAll(',', '.'));
    if (asNum == null) return '';
    final formatted = asNum.toStringAsFixed(1);
    return allowedEngineVolumes.contains(formatted) ? formatted : '';
  }

  final equipmentRaw = (obj['equipment'] ?? '').toString().trim();
  final equipment = equipmentRaw.length > 80
      ? equipmentRaw.substring(0, 80).trim()
      : equipmentRaw;

  return (
    engineVolume: canonVolume(obj['engineVolume']),
    engineType: canon(obj['engineType'], allowedEngineTypes),
    transmission: canon(obj['transmission'], allowedGearboxTypes),
    driveType: canon(obj['driveType'], allowedDriveTypes),
    equipment: equipment,
  );
}

/// Ключи ранее ИИ-заполненных полей, которые пользователь НЕ трогал (текущее
/// значение совпадает с записанным ИИ) — при смене авто они «устаревшие» и их
/// можно очистить под новый VIN. Поля, изменённые/очищенные вручную, и поля,
/// которые ИИ оставлял пустыми, не возвращаются. Чистая функция (тестируема).
Set<String> staleVinAutofillKeys(
  Map<String, String> aiWritten,
  Map<String, String> current,
) {
  final stale = <String>{};
  aiWritten.forEach((key, aiValue) {
    final av = aiValue.trim();
    if (av.isNotEmpty && (current[key] ?? '').trim() == av) {
      stale.add(key);
    }
  });
  return stale;
}

/// Чистое решение: что записать в марку/модель по итогу VIN-конвертера. Пусто,
/// если резолв не терминален (`!found` или `timedOut`); иначе — каждое поле
/// заполняется ТОЛЬКО если оно пусто (only-empty: ручной ввод не перетираем).
/// Тестируема без виджет-харнеса. Решение «запускать ли вообще» (обе пусты)
/// делает вызывающий ДО платного вызова.
typedef IdentityFillPlan = ({String brand, String model});

IdentityFillPlan planIdentityFill({
  required bool brandEmpty,
  required bool modelEmpty,
  required bool found,
  required bool timedOut,
  required String resolvedBrand,
  required String resolvedModel,
}) {
  if (!found || timedOut) return (brand: '', model: '');
  return (
    brand: brandEmpty ? resolvedBrand.trim() : '',
    model: modelEmpty ? resolvedModel.trim() : '',
  );
}

// ── ГОСТ-сертификат (ApiCloud `gost_certificate`) → «Параметры» ──────────────
// Бэк ОТДАЁТ `responseNormalized.certificate[]` целиком при found (проверено
// live, batch LEG-A404259). Достаём официальные поля и нормализуем к опциям
// дропдаунов. Привод/комплектацию сертификат не содержит. Чисто, без Flutter.

/// Подмножество [VinParamsAiResult] из сертификата ГОСТ. Поля нормализованы к
/// опциям дропдаунов или `''`.
typedef GostParamsResult = ({
  String engineVolume,
  String engineType,
  String transmission,
});

const GostParamsResult emptyGostParamsResult = (
  engineVolume: '',
  engineType: '',
  transmission: '',
);

/// Толерантный декодер `responseNormalized` → Map (приходит строкой ИЛИ уже
/// Map). Терпит обрамляющую прозу/```-заборы. Возвращает `null` при сбое. Не бросает.
Map<String, dynamic>? _decodeNormalizedMap(dynamic normalized) {
  if (normalized == null) return null;
  dynamic decoded = normalized;
  if (normalized is String) {
    final s = normalized.trim();
    if (s.isEmpty) return null;
    try {
      decoded = json.decode(s);
    } catch (_) {
      final obj = extractJsonObject(s);
      if (obj == null) return null;
      decoded = obj;
    }
  }
  if (decoded is! Map) return null;
  return decoded.map((k, v) => MapEntry('$k', v));
}

/// Первый элемент `certificate[]` из `responseNormalized` ГОСТ-проверки — если
/// `found == true` и список непустой; иначе `null`. Не бросает.
Map<String, dynamic>? gostCertificateFields(dynamic normalized) {
  final map = _decodeNormalizedMap(normalized);
  if (map == null) return null;
  if (map['found'] != true) return null;
  final cert = map['certificate'];
  if (cert is! List || cert.isEmpty) return null;
  final first = cert.first;
  if (first is! Map) return null;
  return first.map((k, v) => MapEntry('$k', v));
}

/// Списочное поле [key] из `responseNormalized` (залог — `items`). Пусто/нет →
/// `[]`. Скелет: детали показываем ТОЛЬКО когда список непуст. Не бросает.
List<Map<String, dynamic>> gostListField(dynamic normalized, String key) {
  final m = _decodeNormalizedMap(normalized);
  if (m == null) return const [];
  final v = m[key];
  if (v is! List) return const [];
  return v
      .whereType<Map>()
      .map((e) => e.map((k, val) => MapEntry('$k', val)))
      .toList();
}

/// Map-поле [key] из `responseNormalized` (ФГИС — `permit`), если непустой Map;
/// иначе `null`. Скелет для разрешения такси. Не бросает.
Map<String, dynamic>? gostMapField(dynamic normalized, String key) {
  final m = _decodeNormalizedMap(normalized);
  if (m == null) return null;
  final v = m[key];
  if (v is! Map || v.isEmpty) return null;
  return v.map((k, val) => MapEntry('$k', val));
}

/// Парсит поля сертификата ГОСТ к опциям дропдаунов «Параметры». [cert] —
/// первый элемент `certificate[]` (см. [gostCertificateFields]). Маппинги
/// (подстрока, регистронезависимо): enginepetrol (дизель→Дизель, бензин→Бензин,
/// электр→Электро, гибрид→Гибрид, газ→Газ/Бензин); transmission (робот→Робот,
/// вариатор→Вариатор, автомат→АКПП, механ→МКПП); enginecylindersusefulcapacity
/// (см³ → /1000 → 0.1, если в allowedEngineVolumes). Неизвестное → `''`. Не бросает.
GostParamsResult parseGostCertificateParams(
  Map<String, dynamic> cert, {
  required List<String> allowedEngineTypes,
  required List<String> allowedGearboxTypes,
  required List<String> allowedEngineVolumes,
}) {
  String canon(String candidate, List<String> allowed) {
    final v = candidate.trim();
    if (v.isEmpty) return '';
    for (final opt in allowed) {
      if (opt.toLowerCase() == v.toLowerCase()) return opt;
    }
    return '';
  }

  String fuel() {
    final raw = (cert['enginepetrol'] ?? '').toString().toLowerCase();
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
    return canon(mapped, allowedEngineTypes);
  }

  String gearbox() {
    final raw = (cert['transmission'] ?? '').toString().toLowerCase();
    if (raw.isEmpty) return '';
    final String mapped;
    if (raw.contains('робот')) {
      mapped = 'Робот';
    } else if (raw.contains('вариатор')) {
      mapped = 'Вариатор';
    } else if (raw.contains('автомат')) {
      mapped = 'АКПП';
    } else if (raw.contains('механ')) {
      mapped = 'МКПП';
    } else {
      return '';
    }
    return canon(mapped, allowedGearboxTypes);
  }

  String volume() {
    final raw = (cert['enginecylindersusefulcapacity'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return '';
    final cm3 = int.tryParse(match.group(0)!);
    if (cm3 == null || cm3 <= 0) return '';
    final formatted = (cm3 / 1000).toStringAsFixed(1);
    return allowedEngineVolumes.contains(formatted) ? formatted : '';
  }

  return (
    engineVolume: volume(),
    engineType: fuel(),
    transmission: gearbox(),
  );
}

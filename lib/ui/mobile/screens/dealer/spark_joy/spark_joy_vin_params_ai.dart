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

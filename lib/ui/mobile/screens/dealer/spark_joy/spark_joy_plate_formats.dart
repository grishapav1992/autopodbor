/// Plate-format configs for РФ + 5 СНГ countries + Абхазия + Ю. Осетия.
///
/// Each [PlateFormat] knows:
///   • which characters are allowed (alphabet whitelist + digits),
///   • a regex that accepts the canonical passenger-car format,
///   • a max length used for input truncation,
///   • a placeholder shown in the empty TextField,
///   • an optional display mask (with spaces / dashes) for read-only
///     rendering in summary cards.
///
/// Used by `spark_joy_vehicle_business_helpers.dart` (sanitize / format /
/// error helpers) and by `spark_joy_step_vehicle.dart` (country chip
/// row + TextField placeholder).
///
/// Validation scope: passenger plates with regional suffix only. Trailer,
/// commercial, gov, diplomat etc. series are NOT enforced — the regex
/// will reject them, but the user can still type whatever they want and
/// save the draft (we surface the error inline, never block save).
library;

enum PlateCountry {
  // ── Распознаются авто-детектором (строгие шаблоны) ──
  ru, // Россия
  by, // Беларусь
  kz, // Казахстан
  am, // Армения
  kg, // Киргизия
  uz, // Узбекистан
  ab, // Абхазия (РФ-style + регион 80)
  ua, // Украина

  // ── Picker-only (без авто-детекта, skipValidation=true) ──
  // Бывший СССР / постсоветское пространство:
  ge, // Грузия
  az, // Азербайджан
  md, // Молдова
  tj, // Таджикистан
  tm, // Туркменистан
  ee, // Эстония
  lv, // Латвия
  lt, // Литва
  so, // Южная Осетия
  // ЕС:
  de, // Германия
  pl, // Польша
  fr, // Франция
  it, // Италия
  es, // Испания
  // Азия:
  kr, // Корея
  jp, // Япония
  cn, // Китай

  // Универсальный fallback: любая страна вне списка плюс случай
  // «авто-детект не сработал». Без валидации формата — sanitize
  // принимает любые буквы (кириллица + латиница) и цифры, длина
  // до maxLength=14. Используется и как явный выбор «Другая страна»
  // в picker'е, и как неявное состояние когда auto-mode не нашёл
  // подходящего шаблона.
  other,
}

class PlateFormat {
  PlateFormat({
    required this.country,
    required this.name,
    required this.label,
    required this.flag,
    required this.allowedChars,
    required this.pattern,
    required this.maxLength,
    required this.placeholder,
    int? minLength,
    this.usesDash = false,
    this.skipValidation = false,
  }) : minLength = minLength ?? maxLength;

  final PlateCountry country;

  /// Полное название страны на русском — для picker-листа («Россия»,
  /// «Беларусь», «Абхазия» и т.д.).
  final String name;

  /// Short label for the country chip ("РФ", "BY", ...).
  final String label;

  /// Flag emoji shown alongside the label.
  final String flag;

  /// Whitelist of letters (uppercased) accepted in plate body — digits
  /// 0-9 are always allowed in addition to these. Used by [sanitize].
  final String allowedChars;

  /// Regex matching the *sanitized* canonical form for this country
  /// (no spaces / dashes — those are layout sugar applied by [format]).
  final RegExp pattern;

  /// Hard cap for input length AFTER sanitize. Anything beyond is
  /// silently truncated.
  final int maxLength;

  /// Smallest length that can possibly match [pattern]. For most
  /// countries this equals [maxLength] (fixed-length plates), but RF
  /// allows both 8- and 9-character variants (`\d{2,3}` regional part)
  /// so its [minLength] is 8 while [maxLength] is 9. Used by
  /// [plateError] to phrase the "too short" message correctly.
  final int minLength;

  /// Example shown in TextField hint when empty.
  final String placeholder;

  /// True for countries whose canonical display includes a dash before
  /// the regional digit(s) — e.g. Belarus `1234АА-7`. The dash is
  /// inserted by [format], NOT typed by the user.
  final bool usesDash;

  /// Когда true, [plateError] не возвращает ошибку формата — используется
  /// для регионов с разнородными форматами, где жёсткая валидация
  /// больше мешает чем помогает (Ю. Осетия). Sanitize и maxLength
  /// продолжают работать.
  final bool skipValidation;
}

/// Cyrillic letters allowed on RF + BY plates.
/// Both countries share the same Cyrillic-Latin-lookalike subset.
const String _plateCyr = 'АВЕКМНОРСТУХ';

/// Latin letters used by KZ / AM / KG / UZ plate series we support.
/// Full A-Z; some series in these countries do use Q (e.g. KZ taxi /
/// rare regional codes), so excluding it would silently drop valid
/// input.
const String _plateLatin = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Заглушка-паттерн для форматов с [PlateFormat.skipValidation] = true:
/// поле `pattern` обязательно в конструкторе, но ни sanitize, ни plateError
/// его не используют. Назван `_unusedPattern` чтобы не путать читателя с
/// SO-специфичной логикой.
final RegExp _unusedPattern = RegExp('^.+\$');

/// Расширенный whitelist для picker-only стран — включает Cyrillic +
/// Latin + азиатские символы (CJK ideographs / Hangul / Hiragana /
/// Katakana). Без этого инспектор, выбравший Корею/Китай/Японию в
/// picker'е, не сможет ввести настоящий номер: hangul/kanji символы
/// отфильтровывались бы как «не из whitelist'а». Diacritic-латиница
/// (ä/ö/ü/ñ etc.) тоже включена для редких европейских регионов.
const String _plateAsianRanges =
    '一-鿿' // CJK Unified Ideographs (Китай, Япония кандзи)
    '가-힣' // Hangul Syllables (Корея) — стандартный диапазон, без зарезервированных
    '぀-ゟ' // Hiragana (Япония)
    '゠-ヿ' // Katakana (Япония)
    'À-ſ'; // Latin Extended (Германия/Испания/Франция/Польша)

final PlateFormat _ruFormat = PlateFormat(
  country: PlateCountry.ru,
  name: 'Россия',
  label: 'РФ',
  flag: '🇷🇺',
  allowedChars: _plateCyr,
  // 1 letter + 3 digits + 2 letters + 2..3 region digits
  // Example: А123ВЕ77 / А123ВЕ777 (буквы только из _plateCyr —
  // Latin-lookalike Cyrillic, БЕЗ Б).
  pattern: _ruPattern,
  maxLength: 9,
  // Both 8-char (2-digit region) and 9-char (3-digit region) plates
  // are valid — see `\d{2,3}` in _ruPattern.
  minLength: 8,
  placeholder: 'А123ВЕ77',
);

final RegExp _ruPattern = RegExp('^[$_plateCyr]\\d{3}[$_plateCyr]{2}\\d{2,3}\$');

final PlateFormat _byFormat = PlateFormat(
  country: PlateCountry.by,
  name: 'Беларусь',
  label: 'BY',
  flag: '🇧🇾',
  allowedChars: _plateCyr,
  // 4 digits + 2 letters + 1 region digit (dash inserted by formatter)
  // Example: 1234АА7 → "1234АА-7"
  pattern: _byPattern,
  maxLength: 7,
  placeholder: '1234АА-7',
  usesDash: true,
);

final RegExp _byPattern = RegExp('^\\d{4}[$_plateCyr]{2}\\d\$');

final PlateFormat _kzFormat = PlateFormat(
  country: PlateCountry.kz,
  name: 'Казахстан',
  label: 'KZ',
  flag: '🇰🇿',
  allowedChars: _plateLatin,
  // 3 digits + 3 latin letters + 2 region digits
  // Example: 123ABC02
  pattern: _kzPattern,
  maxLength: 8,
  placeholder: '123ABC02',
);

final RegExp _kzPattern = RegExp('^\\d{3}[$_plateLatin]{3}\\d{2}\$');

final PlateFormat _amFormat = PlateFormat(
  country: PlateCountry.am,
  name: 'Армения',
  label: 'AM',
  flag: '🇦🇲',
  allowedChars: _plateLatin,
  // 2 digits + 2 latin letters + 3 digits
  // Example: 12AB123
  pattern: _amPattern,
  maxLength: 7,
  placeholder: '12AB123',
);

final RegExp _amPattern = RegExp('^\\d{2}[$_plateLatin]{2}\\d{3}\$');

final PlateFormat _kgFormat = PlateFormat(
  country: PlateCountry.kg,
  name: 'Киргизия',
  label: 'KG',
  flag: '🇰🇬',
  allowedChars: _plateLatin,
  // 1 region letter + 4 digits + 3 latin letters
  // Example: B1234ABC
  pattern: _kgPattern,
  maxLength: 8,
  placeholder: 'B1234ABC',
);

final RegExp _kgPattern = RegExp('^[$_plateLatin]\\d{4}[$_plateLatin]{3}\$');

final PlateFormat _uzFormat = PlateFormat(
  country: PlateCountry.uz,
  name: 'Узбекистан',
  label: 'UZ',
  flag: '🇺🇿',
  allowedChars: _plateLatin,
  // 2 region digits + 1 letter + 3 digits + 2 letters
  // Example: 01A123AB
  pattern: _uzPattern,
  maxLength: 8,
  placeholder: '01A123AB',
);

final RegExp _uzPattern = RegExp('^\\d{2}[$_plateLatin]\\d{3}[$_plateLatin]{2}\$');

final PlateFormat _abFormat = PlateFormat(
  country: PlateCountry.ab,
  name: 'Абхазия',
  label: 'АБХ',
  // У Абхазии нет официального ISO-кода и emoji-флага. Regional-
  // indicator пара 🇦🇧 на iOS 15+ может рендериться как условный
  // флаг с буквами «AB», на старших платформах — двух-буквенный
  // плейсхолдер. Для надёжного рендеринга нужен SVG-ассет (TODO).
  flag: '🇦🇧',
  allowedChars: _plateCyr,
  // РФ-стиль с фиксированным регионом 80: 1 буква + 3 цифры + 2 буквы + «80».
  // Example: А123ВЕ80 (буквы только из _plateCyr — Latin-lookalike Cyrillic).
  pattern: _abPattern,
  maxLength: 8,
  placeholder: 'А123ВЕ80',
);

final RegExp _abPattern = RegExp('^[$_plateCyr]\\d{3}[$_plateCyr]{2}80\$');

/// Украинский plate-alphabet — Cyrillic-Latin-lookalike subset (12 букв,
/// но с І вместо У и без Б — в РФ Б есть, в UA нет).
const String _plateUaCyr = 'АВЕІКМНОРСТХ';

final PlateFormat _uaFormat = PlateFormat(
  country: PlateCountry.ua,
  name: 'Украина',
  label: 'UA',
  flag: '🇺🇦',
  allowedChars: _plateUaCyr,
  // Modern (2004+): 2 буквы + 4 цифры + 2 буквы (АА 1234 АА).
  // Length 8.
  pattern: _uaPattern,
  maxLength: 8,
  placeholder: 'АА1234АА',
);

final RegExp _uaPattern = RegExp('^[$_plateUaCyr]{2}\\d{4}[$_plateUaCyr]{2}\$');

final PlateFormat _soFormat = PlateFormat(
  country: PlateCountry.so,
  name: 'Южная Осетия',
  label: 'ЮО',
  // Аналогично АБХ — нет надёжного emoji.
  flag: '🅾️',
  // Тот же расширенный whitelist что и у других skipValidation-стран,
  // на случай дикого input'а (paste / dictation с азиатскими
  // символами и т.п.). Регион имеет несколько конкурирующих
  // исторических форматов — стрипать ничего не должны.
  allowedChars: _plateCyr + _plateLatin + _plateAsianRanges,
  pattern: _unusedPattern,
  maxLength: 14,
  minLength: 1,
  placeholder: 'Любой формат',
  skipValidation: true,
);

final PlateFormat _otherFormat = PlateFormat(
  country: PlateCountry.other,
  name: 'Другая страна',
  label: 'Другая',
  flag: '🌍',
  // Максимально широкий whitelist — кириллица + латиница + азиатские
  // символы + Latin Extended. «Другая страна» — fallback для всего
  // что детектор не распознал: должен принимать вообще любые плата.
  allowedChars: _plateCyr + _plateLatin + _plateAsianRanges,
  pattern: _unusedPattern,
  maxLength: 14,
  minLength: 1,
  placeholder: 'Любой формат',
  skipValidation: true,
);

/// Создаёт picker-only формат: без жёсткой валидации, но с правильным
/// именем / флагом / placeholder'ом для отображения. Используется для
/// стран, которые инспектор может выбрать вручную, но детектор за них
/// не отвечает (слишком много вариантов или коллизий шаблонов).
PlateFormat _pickerOnlyFormat({
  required PlateCountry country,
  required String name,
  required String label,
  required String flag,
  required String placeholder,
}) {
  return PlateFormat(
    country: country,
    name: name,
    label: label,
    flag: flag,
    // Permissive whitelist — Cyr + Lat + digits + азиатские символы +
    // латиница с диакритикой. Без расширенных диапазонов корейские/
    // японские/китайские плата невозможно ввести (hangul/kanji
    // отфильтровываются sanitize), хотя страна выбрана в picker'е.
    allowedChars: _plateCyr + _plateLatin + _plateAsianRanges,
    pattern: _unusedPattern,
    maxLength: 14,
    minLength: 1,
    placeholder: placeholder,
    skipValidation: true,
  );
}

// ── Picker-only форматы: бывший СССР, ЕС, Азия ────────────────────────
//
// Без авто-детекта (см. [kAutoDetectFormats]). Если инспектор вручную
// выбирает страну в picker'е — мы переключаемся на её формат, но не
// валидируем строго (skipValidation=true). Это исключает ложные
// срабатывания детектора между похожими шаблонами (FR=IT=GE,
// AM=AZ и т.п.) и при этом даёт инспектору правильный label и флаг.

final PlateFormat _geFormat = _pickerOnlyFormat(
  country: PlateCountry.ge,
  name: 'Грузия',
  label: 'GE',
  flag: '🇬🇪',
  placeholder: 'AB123CD',
);

final PlateFormat _azFormat = _pickerOnlyFormat(
  country: PlateCountry.az,
  name: 'Азербайджан',
  label: 'AZ',
  flag: '🇦🇿',
  placeholder: '10AB123',
);

final PlateFormat _mdFormat = _pickerOnlyFormat(
  country: PlateCountry.md,
  name: 'Молдова',
  label: 'MD',
  flag: '🇲🇩',
  placeholder: 'ABC123',
);

final PlateFormat _tjFormat = _pickerOnlyFormat(
  country: PlateCountry.tj,
  name: 'Таджикистан',
  label: 'TJ',
  flag: '🇹🇯',
  placeholder: '1234АА01',
);

final PlateFormat _tmFormat = _pickerOnlyFormat(
  country: PlateCountry.tm,
  name: 'Туркменистан',
  label: 'TM',
  flag: '🇹🇲',
  placeholder: 'AG1234',
);

final PlateFormat _eeFormat = _pickerOnlyFormat(
  country: PlateCountry.ee,
  name: 'Эстония',
  label: 'EE',
  flag: '🇪🇪',
  placeholder: '123ABC',
);

final PlateFormat _lvFormat = _pickerOnlyFormat(
  country: PlateCountry.lv,
  name: 'Латвия',
  label: 'LV',
  flag: '🇱🇻',
  placeholder: 'AB1234',
);

final PlateFormat _ltFormat = _pickerOnlyFormat(
  country: PlateCountry.lt,
  name: 'Литва',
  label: 'LT',
  flag: '🇱🇹',
  placeholder: 'ABC123',
);

final PlateFormat _deFormat = _pickerOnlyFormat(
  country: PlateCountry.de,
  name: 'Германия',
  label: 'DE',
  flag: '🇩🇪',
  placeholder: 'B-AB1234',
);

final PlateFormat _plFormat = _pickerOnlyFormat(
  country: PlateCountry.pl,
  name: 'Польша',
  label: 'PL',
  flag: '🇵🇱',
  placeholder: 'WI12345',
);

final PlateFormat _frFormat = _pickerOnlyFormat(
  country: PlateCountry.fr,
  name: 'Франция',
  label: 'FR',
  flag: '🇫🇷',
  placeholder: 'AB123CD',
);

final PlateFormat _itFormat = _pickerOnlyFormat(
  country: PlateCountry.it,
  name: 'Италия',
  label: 'IT',
  flag: '🇮🇹',
  placeholder: 'AB123CD',
);

final PlateFormat _esFormat = _pickerOnlyFormat(
  country: PlateCountry.es,
  name: 'Испания',
  label: 'ES',
  flag: '🇪🇸',
  placeholder: '1234ABC',
);

final PlateFormat _krFormat = _pickerOnlyFormat(
  country: PlateCountry.kr,
  name: 'Корея',
  label: 'KR',
  flag: '🇰🇷',
  placeholder: '12가1234',
);

final PlateFormat _jpFormat = _pickerOnlyFormat(
  country: PlateCountry.jp,
  name: 'Япония',
  label: 'JP',
  flag: '🇯🇵',
  placeholder: '500さ1234',
);

final PlateFormat _cnFormat = _pickerOnlyFormat(
  country: PlateCountry.cn,
  name: 'Китай',
  label: 'CN',
  flag: '🇨🇳',
  placeholder: '京A12345',
);

/// Ordered list — defines the picker sequence in the UI.
/// Группировка: распознаваемые детектором → бывший СССР → ЕС → Азия →
/// Южная Осетия → «Другая страна». Auto-detect использует
/// [kAutoDetectFormats] (строгий subset).
final List<PlateFormat> kPlateFormats = <PlateFormat>[
  // Распознаются детектором:
  _ruFormat,
  _byFormat,
  _uaFormat,
  _kzFormat,
  _amFormat,
  _kgFormat,
  _uzFormat,
  _abFormat,
  // Picker-only — бывший СССР:
  _geFormat,
  _azFormat,
  _mdFormat,
  _tjFormat,
  _tmFormat,
  _eeFormat,
  _lvFormat,
  _ltFormat,
  _soFormat,
  // Picker-only — ЕС:
  _deFormat,
  _plFormat,
  _frFormat,
  _itFormat,
  _esFormat,
  // Picker-only — Азия:
  _krFormat,
  _jpFormat,
  _cnFormat,
  // Универсальный fallback:
  _otherFormat,
];

/// Порядок попыток матча в [detectPlateCountry]. AB первым (строже
/// чем RU — фиксированный регион 80). UA и BY с уникальной структурой
/// (4-значный блок цифр) — следующими. RU после AB чтобы не
/// перехватить АБХ-плату. Latin (KZ/AM/KG/UZ) — структуры разные,
/// порядок неважен. SO / other / picker-only страны в детекторе НЕ
/// участвуют — explicit-only выбор.
final List<PlateFormat> kAutoDetectFormats = <PlateFormat>[
  _abFormat,
  _uaFormat,
  _byFormat,
  _ruFormat,
  _kzFormat,
  _amFormat,
  _kgFormat,
  _uzFormat,
];

PlateFormat plateFormatFor(PlateCountry country) {
  return kPlateFormats.firstWhere(
    (f) => f.country == country,
    orElse: () => _ruFormat,
  );
}

/// Parses the persisted wire-value (string) into a [PlateCountry].
/// Falls back to RF on missing / unknown values — old drafts without a
/// `gosNumberCountry` key keep their original behavior.
PlateCountry parsePlateCountry(Object? raw) {
  final value = raw?.toString().toLowerCase();
  if (value == null || value.isEmpty) return PlateCountry.ru;
  for (final c in PlateCountry.values) {
    if (c.name == value) return c;
  }
  return PlateCountry.ru;
}

/// Strips characters not in the alphabet and truncates to maxLength.
String sanitizePlate(String input, PlateFormat fmt) {
  final upper = input.toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final allowed = '${fmt.allowedChars}0-9';
  final cleaned = upper.replaceAll(RegExp('[^$allowed]'), '');
  if (cleaned.length > fmt.maxLength) {
    return cleaned.substring(0, fmt.maxLength);
  }
  return cleaned;
}

/// Pretty display for a *sanitized* plate, with country-specific
/// separators. Returns the raw value untouched if it's too short to
/// be split meaningfully — partial input is shown as-typed.
String formatPlate(String sanitized, PlateFormat fmt) {
  if (sanitized.length <= 1) return sanitized;
  switch (fmt.country) {
    case PlateCountry.ru:
      return _formatRu(sanitized);
    case PlateCountry.by:
      return _formatBy(sanitized);
    case PlateCountry.kz:
      return _formatKz(sanitized);
    case PlateCountry.am:
      return _formatAm(sanitized);
    case PlateCountry.kg:
      return _formatKg(sanitized);
    case PlateCountry.uz:
      return _formatUz(sanitized);
    case PlateCountry.ab:
      // Та же раскладка что у РФ — слитно «А123БВ80».
      return _formatRu(sanitized);
    case PlateCountry.ua:
      return _formatUa(sanitized);
    // Picker-only форматы и fallback'и — отдаём как ввели, без
    // country-specific раскладки. Каждая страна имеет десятки
    // подформатов (city-codes, спец-серии, etc.), универсальный
    // formatter невозможен. Sanitize уже нормализовал регистр и
    // отфильтровал мусор.
    case PlateCountry.ge:
    case PlateCountry.az:
    case PlateCountry.md:
    case PlateCountry.tj:
    case PlateCountry.tm:
    case PlateCountry.ee:
    case PlateCountry.lv:
    case PlateCountry.lt:
    case PlateCountry.de:
    case PlateCountry.pl:
    case PlateCountry.fr:
    case PlateCountry.it:
    case PlateCountry.es:
    case PlateCountry.kr:
    case PlateCountry.jp:
    case PlateCountry.cn:
    case PlateCountry.so:
    case PlateCountry.other:
      return sanitized;
  }
}

/// Permissive-сanitize для auto-mode: убирает пробелы, апперкейзит,
/// фильтрует под универсальный whitelist (Cyr+Lat+digits) и режет
/// до 14 символов (общий максимум по всем форматам). Используется
/// пока auto-детектор ещё не определил страну — чтобы инспектор мог
/// набирать любые символы из любого алфавита, а под формат-специфичный
/// whitelist строка пересушится автоматически после матча.
String sanitizePlatePermissive(String input) {
  final upper = input.toUpperCase().replaceAll(RegExp(r'\s+'), '');
  final allowed = '$_plateCyr$_plateLatin' '0-9';
  final cleaned = upper.replaceAll(RegExp('[^$allowed]'), '');
  if (cleaned.length > 14) return cleaned.substring(0, 14);
  return cleaned;
}

/// Прогоняет [input] через [kAutoDetectFormats] в порядке специфичности.
/// Для каждого кандидата делает format-specific sanitize и проверяет
/// `pattern.hasMatch`. Возвращает первый страновой код с полным матчем,
/// либо null если ни один не подошёл (тогда UI показывает «Не определено»).
PlateCountry? detectPlateCountry(String input) {
  final permissive = sanitizePlatePermissive(input);
  if (permissive.isEmpty) return null;
  for (final fmt in kAutoDetectFormats) {
    final sanitized = sanitizePlate(permissive, fmt);
    if (sanitized.length < fmt.minLength) continue;
    if (fmt.pattern.hasMatch(sanitized)) {
      return fmt.country;
    }
  }
  return null;
}

/// Returns null if the sanitized input matches the country pattern,
/// otherwise a localized error message. Empty input returns null —
/// emptiness is handled separately by the caller (required-field check).
String? plateError(String input, PlateFormat fmt) {
  final clean = sanitizePlate(input, fmt);
  if (clean.isEmpty) return null;
  // Регионы со skipValidation (Ю. Осетия) — никаких ошибок формата:
  // sanitize и maxLength уже отработали, дальше доверяем инспектору.
  if (fmt.skipValidation) return null;
  if (clean.length < fmt.minLength) {
    final lengthLabel = fmt.minLength == fmt.maxLength
        ? '${fmt.maxLength}'
        : '${fmt.minLength}-${fmt.maxLength}';
    return 'Введено ${clean.length} из $lengthLabel символов';
  }
  if (!fmt.pattern.hasMatch(clean)) {
    return 'Некорректный формат госномера для ${fmt.label}';
  }
  return null;
}

// ── Per-country display formatters ────────────────────────────────────

String _formatRu(String s) {
  // Слитно «А123ВЕ77» — как пишут в документах и как показывает
  // placeholder. Прежняя раскладка с пробелами («А 123 ВЕ 77») читалась
  // в поле ввода как «огромные дыры» между группами (фидбек 2026-07-10).
  return s;
}

String _formatBy(String s) {
  // 1234 АА-7
  if (s.length <= 4) return s;
  final digits = s.substring(0, 4);
  final letters = s.substring(4, s.length < 6 ? s.length : 6);
  final region = s.length > 6 ? '-${s.substring(6)}' : '';
  return letters.isEmpty ? digits : '$digits $letters$region';
}

String _formatKz(String s) {
  // 123 ABC 02
  if (s.length <= 3) return s;
  final d1 = s.substring(0, 3);
  final letters = s.substring(3, s.length < 6 ? s.length : 6);
  final region = s.length > 6 ? ' ${s.substring(6)}' : '';
  return letters.isEmpty ? d1 : '$d1 $letters$region';
}

String _formatAm(String s) {
  // 12 AB 123
  if (s.length <= 2) return s;
  final d1 = s.substring(0, 2);
  final letters = s.substring(2, s.length < 4 ? s.length : 4);
  final region = s.length > 4 ? ' ${s.substring(4)}' : '';
  return letters.isEmpty ? d1 : '$d1 $letters$region';
}

String _formatKg(String s) {
  // B 1234 ABC
  var out = s[0];
  if (s.length <= 1) return out;
  final digits = s.substring(1, s.length < 5 ? s.length : 5);
  if (digits.isNotEmpty) out += ' $digits';
  final letters = s.length > 5 ? ' ${s.substring(5)}' : '';
  return out + letters;
}

String _formatUz(String s) {
  // 01 A 123 AB
  if (s.length <= 2) return s;
  final region = s.substring(0, 2);
  final letter = s.length >= 3 ? s.substring(2, 3) : '';
  if (letter.isEmpty) return region;
  final digits = s.length > 3 ? s.substring(3, s.length < 6 ? s.length : 6) : '';
  if (digits.isEmpty) return '$region $letter';
  final tail = s.length > 6 ? s.substring(6) : '';
  return tail.isEmpty ? '$region $letter $digits' : '$region $letter $digits $tail';
}

String _formatUa(String s) {
  // АА 1234 АА
  if (s.length <= 2) return s;
  final prefix = s.substring(0, 2);
  final mid = s.substring(2, s.length < 6 ? s.length : 6);
  if (mid.isEmpty) return prefix;
  final tail = s.length > 6 ? s.substring(6) : '';
  return tail.isEmpty ? '$prefix $mid' : '$prefix $mid $tail';
}

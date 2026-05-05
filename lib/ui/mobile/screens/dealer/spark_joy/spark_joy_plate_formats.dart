/// Plate-format configs for РФ + 5 СНГ countries.
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
  ru,
  by,
  kz,
  am,
  kg,
  uz,
}

class PlateFormat {
  PlateFormat({
    required this.country,
    required this.label,
    required this.flag,
    required this.allowedChars,
    required this.pattern,
    required this.maxLength,
    required this.placeholder,
    this.usesDash = false,
  });

  final PlateCountry country;

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

  /// Example shown in TextField hint when empty.
  final String placeholder;

  /// True for countries whose canonical display includes a dash before
  /// the regional digit(s) — e.g. Belarus `1234АА-7`. The dash is
  /// inserted by [format], NOT typed by the user.
  final bool usesDash;
}

/// Cyrillic letters allowed on RF + BY plates.
/// Both countries share the same Cyrillic-Latin-lookalike subset.
const String _plateCyr = 'АВЕКМНОРСТУХ';

/// Latin letters used by KZ / AM / KG / UZ plate series we support.
const String _plateLatin = 'ABCDEFGHIJKLMNOPRSTUVWXYZ';

final PlateFormat _ruFormat = PlateFormat(
  country: PlateCountry.ru,
  label: 'РФ',
  flag: '🇷🇺',
  allowedChars: _plateCyr,
  // 1 letter + 3 digits + 2 letters + 2..3 region digits
  // Example: А123БВ77 / А123БВ777
  pattern: _ruPattern,
  maxLength: 9,
  placeholder: 'А123БВ77',
);

final RegExp _ruPattern = RegExp('^[$_plateCyr]\\d{3}[$_plateCyr]{2}\\d{2,3}\$');

final PlateFormat _byFormat = PlateFormat(
  country: PlateCountry.by,
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

/// Ordered list — defines the chip-row sequence in the UI.
final List<PlateFormat> kPlateFormats = <PlateFormat>[
  _ruFormat,
  _byFormat,
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
  }
}

/// Returns null if the sanitized input matches the country pattern,
/// otherwise a localized error message. Empty input returns null —
/// emptiness is handled separately by the caller (required-field check).
String? plateError(String input, PlateFormat fmt) {
  final clean = sanitizePlate(input, fmt);
  if (clean.isEmpty) return null;
  if (clean.length < fmt.maxLength - 1) {
    return 'Введено ${clean.length} из ${fmt.maxLength} символов';
  }
  if (!fmt.pattern.hasMatch(clean)) {
    return 'Некорректный формат госномера для ${fmt.label}';
  }
  return null;
}

// ── Per-country display formatters ────────────────────────────────────

String _formatRu(String s) {
  // А 123 БВ 77
  var out = s[0];
  final rest = s.substring(1);
  final digits = rest.substring(0, rest.length < 3 ? rest.length : 3);
  if (digits.isNotEmpty) out += ' $digits';
  final letters = rest.length > 3
      ? rest.substring(3, rest.length < 5 ? rest.length : 5)
      : '';
  if (letters.isNotEmpty) out += ' $letters';
  final region = rest.length > 5 ? rest.substring(5) : '';
  if (region.isNotEmpty) out += ' $region';
  return out;
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

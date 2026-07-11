import 'package:get/get.dart';

String sjCurrentLocaleCode() {
  final locale = Get.locale;
  if (locale == null) return 'ru';
  final lang = locale.languageCode.trim().toLowerCase();
  return lang.isEmpty ? 'ru' : lang;
}

bool sjIsEnglishLocale() => sjCurrentLocaleCode().startsWith('en');

String sjT(String key, {required String fallback}) {
  final translated = key.tr;
  if (translated == key) return fallback;
  return translated;
}

String sjTFormat(
  String key, {
  required String fallback,
  Map<String, String> args = const <String, String>{},
}) {
  var text = sjT(key, fallback: fallback);
  args.forEach((name, value) {
    text = text.replaceAll('{$name}', value);
  });
  return text;
}

DateTime? _parseDateFlexible(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final direct = DateTime.tryParse(value);
  if (direct != null) return direct;
  final ruMatch = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(value);
  if (ruMatch == null) return null;
  final day = int.tryParse(ruMatch.group(1)!);
  final month = int.tryParse(ruMatch.group(2)!);
  final year = int.tryParse(ruMatch.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String sjFormatDate(String raw) {
  final date = _parseDateFlexible(raw);
  if (date == null) return raw;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  if (sjIsEnglishLocale()) return '$m/$d/$y';
  return '$d.$m.$y';
}

String sjFormatInteger(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return raw;
  final value = int.tryParse(digits);
  if (value == null) return raw;
  final source = value.toString();
  final separator = sjIsEnglishLocale() ? ',' : ' ';
  final buffer = StringBuffer();
  for (var i = 0; i < source.length; i++) {
    final reverseIndex = source.length - i;
    buffer.write(source[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(separator);
    }
  }
  return buffer.toString();
}

String sjFormatMileage(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) return raw;
  final formatted = sjFormatInteger(normalized);
  final km = sjT('spark.unit.km', fallback: 'км');
  return '$formatted $km';
}

String sjFormatReportMeta(String code, String createdAt) {
  final trimmedCode = code.trim();
  final formattedDate = sjFormatDate(createdAt);
  if (trimmedCode.isEmpty) {
    return sjTFormat(
      'spark.report.meta.noCode',
      fallback: 'Отчёт от {date}',
      args: <String, String>{'date': formattedDate},
    );
  }
  return sjTFormat(
    'spark.report.meta',
    fallback: '{code} от {date}',
    args: <String, String>{'code': trimmedCode, 'date': formattedDate},
  );
}

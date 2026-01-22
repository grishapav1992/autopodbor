import 'dart:math';

import 'data.dart';
import 'models.dart';

String genId(String prefix) {
  final n = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final r = Random().nextInt(90) + 10;
  return '$prefix-${n.toString().substring(n.toString().length - 6)}-$r';
}

String stripSpaces(String s) => s.replaceAll(' ', '').trim();

String digitsOnly(String s) =>
    stripSpaces(s).replaceAll(RegExp(r'[^0-9]'), '');

int? parseMoney(String s) {
  final t = stripSpaces(s);
  if (t.isEmpty) return null;
  return int.tryParse(t);
}

String formatMoney(int? v) {
  if (v == null) return '—';
  return '${_formatNumber(v)} ₽';
}

String formatBudget(int? from, int? to) {
  if (from == null && to == null) return '—';
  if (from != null && to == null) return 'от ${formatMoney(from)}';
  if (from == null && to != null) return 'до ${formatMoney(to)}';
  return '${formatMoney(from)} — ${formatMoney(to)}';
}

String formatEtaDays(int days) {
  if (days <= 0) return 'в день обращения';
  if (days == 1) return '1 день';
  if (days >= 2 && days <= 4) return '$days дня';
  return '$days дней';
}

String safeUrlHost(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.host.toLowerCase();
  } catch (_) {
    return '';
  }
}

bool isAllowedListingUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return false;
  final host = safeUrlHost(t);
  return host.isNotEmpty && allowedListingDomains.contains(host);
}

String shortListingLabel(String url) {
  final t = url.trim();
  if (t.isEmpty) return '';
  try {
    final uri = Uri.parse(t);
    final parts = uri.pathSegments;
    final tail = parts.length >= 2
        ? '${parts[parts.length - 2]}/${parts.last}'
        : (parts.isNotEmpty ? parts.last : '');
    return '${uri.host}${tail.isNotEmpty ? '/$tail' : ''}';
  } catch (_) {
    return t.length > 32 ? '${t.substring(0, 32)}…' : t;
  }
}

List<String> getYearOptions(String make, String model, String restyling) {
  final years = yearCatalog[make]?[model]?[restyling] ?? [];
  return years.map((e) => e.toString()).toList();
}

bool isCarEmpty(CarItem c) {
  final fields = [
    c.sourceUrl,
    c.sellerPhone,
    c.plate,
    c.vin,
    c.note,
    c.make,
    c.model,
    c.restyling,
    c.year,
  ];
  return fields.every((x) => x.trim().isEmpty);
}

List<String> getAllModelsForMakes(List<String> makes) {
  final set = <String>{};
  for (final mk in makes) {
    final models = carCatalog[mk];
    if (models == null) continue;
    set.addAll(models.keys);
  }
  return set.toList();
}

List<String> getAllRestylingsForSelection(
  List<String> makes,
  List<String> models,
) {
  final set = <String>{};
  for (final mk in makes) {
    final byModel = carCatalog[mk];
    if (byModel == null) continue;
    for (final md in models) {
      final gens = byModel[md];
      if (gens == null) continue;
      set.addAll(gens);
    }
  }
  return set.toList();
}

List<int> getAllYearsForSelection(
  List<String> makes,
  List<String> models,
  List<String> restylings,
) {
  final years = <int>[];
  for (final mk in makes) {
    final byModel = yearCatalog[mk];
    if (byModel == null) continue;
    for (final md in models) {
      final byGen = byModel[md];
      if (byGen == null) continue;
      for (final g in restylings) {
        final ys = byGen[g];
        if (ys != null) years.addAll(ys);
      }
    }
  }
  return years;
}

String getMakeCountry(String make) => brandCountryByMake[make] ?? 'Иномарки';

String formatDate(DateTime dt) {
  return '${_two(dt.day)}.${_two(dt.month)}.${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
}

String _two(int v) => v < 10 ? '0$v' : '$v';

String _formatNumber(int v) {
  final s = v.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buffer.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buffer.write(' ');
  }
  return buffer.toString();
}


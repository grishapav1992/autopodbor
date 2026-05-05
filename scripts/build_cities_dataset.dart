// Generates `assets/data/cities_ru_cis.json` from GeoNames public-domain
// dumps. Run once per dataset refresh — output is checked into the repo.
//
// Usage:
//   1. Populate scripts/.cache/ from https://download.geonames.org/export/dump/:
//        cities5000.txt          (from cities5000.zip)
//        admin1CodesASCII.txt
//        alternateNames_ru.tsv   (from alternateNamesV2.txt filtered to col3=='ru':
//                                   awk -F'\t' '$3=="ru"' alternateNamesV2.txt > alternateNames_ru.tsv)
//      Cache directory is gitignored.
//   2. dart run scripts/build_cities_dataset.dart
//
// What it does:
//   - Build a `geonameid → ru_name` lookup from alternateNames_ru.tsv,
//     preferring isPreferredName=1, then isShortName=1, skipping
//     isHistoric=1 records. This is the authoritative source: GeoNames'
//     `isolanguage='ru'` rows are explicitly tagged Russian (not just
//     "happens to use Cyrillic"), so we never confuse a Belarusian or
//     Ossetian alternate with a Russian one.
//   - Filter cities5000.txt to settlements (feature_class P) with
//     population ≥ 5000 in RU + 11 CIS countries.
//   - Resolve admin1 → Russian region name via a hand-curated dict
//     (see _admin1Ru below). Missing entries leave region blank.
//   - Dedup by (nameRu, country, region) — drop the lower-population
//     duplicate when names collide.
//   - Sort case-insensitive by Russian name with ё→е normalisation.
//   - Emit minified JSON with short keys (r/e/c/cn/a/p) to keep the
//     final file ≤ 700 KB.
//
// The script is pure Dart (`dart:io` + `dart:convert` only). No Pub
// deps — keeps cold-machine setup trivial.

import 'dart:convert';
import 'dart:io';

// UA and GE intentionally excluded from the bundled dataset (product
// decision 2026-05-05). To re-add later: append the codes back here,
// add a name in `_countryNamesRu`, and add a chip in
// `_CityPickerSheetState._countries`. The build script will pick up
// the new countries automatically — no other code changes needed.
const _targetCountries = <String>{
  'RU', 'BY', 'KZ', 'AM', 'AZ', 'MD', 'TJ', 'TM', 'UZ', 'KG',
};

const _countryNamesRu = <String, String>{
  'RU': 'Россия',
  'BY': 'Беларусь',
  'KZ': 'Казахстан',
  'AM': 'Армения',
  'AZ': 'Азербайджан',
  'MD': 'Молдова',
  'TJ': 'Таджикистан',
  'TM': 'Туркменистан',
  'UZ': 'Узбекистан',
  'KG': 'Кыргызстан',
};

// Hand-curated admin1 (region) translations. Used as a final fallback
// when admin1CodesASCII.txt → ru-lookup cannot resolve a region (the
// auto-resolved Russian names cover ~95% of admin1 codes for RU+CIS;
// this dict is kept tiny for future-proofing). Keyed
// `<countryCode>.<admin1Code>`. Most entries can stay empty — the auto
// path is the source of truth.
const _admin1Ru = <String, String>{
  // Russia (codes are GeoNames admin1, not ISO).
  'RU.01': 'Республика Адыгея',
  'RU.02': 'Республика Башкортостан',
  'RU.03': 'Республика Бурятия',
  'RU.04': 'Республика Дагестан',
  'RU.05': 'Республика Ингушетия',
  'RU.06': 'Кабардино-Балкарская Республика',
  'RU.07': 'Республика Калмыкия',
  'RU.08': 'Карачаево-Черкесская Республика',
  'RU.09': 'Республика Карелия',
  'RU.10': 'Республика Коми',
  'RU.11': 'Республика Марий Эл',
  'RU.12': 'Республика Мордовия',
  'RU.13': 'Республика Северная Осетия — Алания',
  'RU.14': 'Республика Татарстан',
  'RU.15': 'Республика Тыва',
  'RU.16': 'Удмуртская Республика',
  'RU.17': 'Республика Хакасия',
  'RU.18': 'Чеченская Республика',
  'RU.19': 'Чувашская Республика',
  'RU.20': 'Алтайский край',
  'RU.21': 'Краснодарский край',
  'RU.22': 'Красноярский край',
  'RU.23': 'Приморский край',
  'RU.24': 'Ставропольский край',
  'RU.25': 'Хабаровский край',
  'RU.26': 'Амурская область',
  'RU.27': 'Архангельская область',
  'RU.28': 'Астраханская область',
  'RU.29': 'Белгородская область',
  'RU.30': 'Брянская область',
  'RU.31': 'Челябинская область',
  'RU.32': 'Чукотский автономный округ',
  'RU.33': 'Иркутская область',
  'RU.34': 'Ивановская область',
  'RU.35': 'Калининградская область',
  'RU.36': 'Калужская область',
  'RU.37': 'Камчатский край',
  'RU.38': 'Кемеровская область',
  'RU.39': 'Хабаровский край',
  'RU.40': 'Ханты-Мансийский автономный округ — Югра',
  'RU.41': 'Кировская область',
  'RU.42': 'Республика Коми',
  'RU.43': 'Костромская область',
  'RU.44': 'Курганская область',
  'RU.45': 'Курская область',
  'RU.46': 'Ленинградская область',
  'RU.47': 'Липецкая область',
  'RU.48': 'Москва',
  'RU.49': 'Магаданская область',
  'RU.50': 'Мурманская область',
  'RU.51': 'Нижегородская область',
  'RU.52': 'Новгородская область',
  'RU.53': 'Новосибирская область',
  'RU.54': 'Омская область',
  'RU.55': 'Оренбургская область',
  'RU.56': 'Орловская область',
  'RU.57': 'Пензенская область',
  'RU.58': 'Пермский край',
  'RU.59': 'Калининградская область',
  'RU.60': 'Ростовская область',
  'RU.61': 'Рязанская область',
  'RU.62': 'Республика Саха (Якутия)',
  'RU.63': 'Сахалинская область',
  'RU.64': 'Самарская область',
  'RU.65': 'Санкт-Петербург',
  'RU.66': 'Саратовская область',
  'RU.67': 'Смоленская область',
  'RU.68': 'Свердловская область',
  'RU.69': 'Тамбовская область',
  'RU.70': 'Томская область',
  'RU.71': 'Тульская область',
  'RU.72': 'Тверская область',
  'RU.73': 'Тюменская область',
  'RU.74': 'Республика Алтай',
  'RU.75': 'Ульяновская область',
  'RU.76': 'Владимирская область',
  'RU.77': 'Волгоградская область',
  'RU.78': 'Вологодская область',
  'RU.79': 'Воронежская область',
  'RU.80': 'Ярославская область',
  'RU.81': 'Еврейская автономная область',
  'RU.82': 'Забайкальский край',
  'RU.83': 'Ненецкий автономный округ',
  'RU.84': 'Ямало-Ненецкий автономный округ',
  'RU.85': 'Республика Крым',
  'RU.86': 'Севастополь',

  // Kazakhstan (top oblasts).
  'KZ.01': 'Алматинская область',
  'KZ.02': 'Алматы',
  'KZ.03': 'Акмолинская область',
  'KZ.04': 'Актюбинская область',
  'KZ.05': 'Атырауская область',
  'KZ.06': 'Восточно-Казахстанская область',
  'KZ.07': 'Жамбылская область',
  'KZ.08': 'Западно-Казахстанская область',
  'KZ.09': 'Карагандинская область',
  'KZ.10': 'Костанайская область',
  'KZ.11': 'Кызылординская область',
  'KZ.12': 'Мангистауская область',
  'KZ.13': 'Туркестанская область',
  'KZ.14': 'Павлодарская область',
  'KZ.15': 'Северо-Казахстанская область',
  'KZ.16': 'Шымкент',
  'KZ.17': 'Астана',

  // Belarus.
  'BY.01': 'Минская область',
  'BY.02': 'Брестская область',
  'BY.03': 'Гомельская область',
  'BY.04': 'Гродненская область',
  'BY.05': 'Могилёвская область',
  'BY.06': 'Витебская область',
  'BY.07': 'Минск',

  // Ukraine (a handful of largest).
  'UA.01': 'АР Крым',
  'UA.02': 'Винницкая область',
  'UA.03': 'Волынская область',
  'UA.04': 'Днепропетровская область',
  'UA.05': 'Донецкая область',
  'UA.06': 'Житомирская область',
  'UA.07': 'Закарпатская область',
  'UA.08': 'Запорожская область',
  'UA.09': 'Ивано-Франковская область',
  'UA.10': 'Киевская область',
  'UA.11': 'Кировоградская область',
  'UA.13': 'Львовская область',
  'UA.14': 'Николаевская область',
  'UA.15': 'Одесская область',
  'UA.16': 'Полтавская область',
  'UA.17': 'Ровенская область',
  'UA.18': 'Сумская область',
  'UA.19': 'Тернопольская область',
  'UA.20': 'Харьковская область',
  'UA.21': 'Херсонская область',
  'UA.22': 'Хмельницкая область',
  'UA.23': 'Черкасская область',
  'UA.24': 'Черниговская область',
  'UA.25': 'Черновицкая область',
  'UA.26': 'Луганская область',
  'UA.27': 'Севастополь',
  'UA.28': 'Киев',
};

void main(List<String> args) {
  final cacheDir = Directory('scripts/.cache');
  final citiesFile = File('${cacheDir.path}/cities5000.txt');
  final ruAltFile = File('${cacheDir.path}/alternateNames_ru.tsv');
  final admin1File = File('${cacheDir.path}/admin1CodesASCII.txt');
  if (!citiesFile.existsSync()) {
    stderr.writeln('Missing ${citiesFile.path}.');
    stderr.writeln('Download cities5000.zip from GeoNames and unzip into '
        'scripts/.cache/, then re-run.');
    exit(1);
  }
  if (!ruAltFile.existsSync()) {
    stderr.writeln('Missing ${ruAltFile.path}.');
    stderr.writeln('Generate it with: '
        "awk -F'\\t' '\$3==\"ru\"' alternateNamesV2.txt > alternateNames_ru.tsv");
    exit(1);
  }
  if (!admin1File.existsSync()) {
    stderr.writeln('Missing ${admin1File.path}.');
    stderr.writeln('Download admin1CodesASCII.txt from GeoNames into '
        'scripts/.cache/, then re-run.');
    exit(1);
  }

  // Step 1: build geonameid → russian-name lookup from the ru-only
  // alternate-names dump.
  //
  // Each row is TSV with columns:
  //   0: alternateNameId
  //   1: geonameid
  //   2: isolanguage  ("ru" only after the awk pre-filter)
  //   3: alternate name
  //   4: isPreferredName  (1 or empty)
  //   5: isShortName       (1 or empty)
  //   6: isColloquial      (1 or empty)
  //   7: isHistoric        (1 or empty)
  //
  // For each geonameid we want:
  //   1. isPreferredName=1, isHistoric=0   ← gold standard
  //   2. isShortName=1, isHistoric=0       ← reasonable secondary
  //   3. any non-historic ru row           ← any name beats Latin
  // History is rejected outright — "Ленинград" must NOT win over
  // "Санкт-Петербург", "Алма-Ата" must NOT win over "Алматы".
  stderr.writeln('Reading ${ruAltFile.path}...');
  final ruLookup = <int, _RuPick>{};
  final ruLines = const LineSplitter().convert(ruAltFile.readAsStringSync());
  for (final line in ruLines) {
    if (line.isEmpty) continue;
    final f = line.split('\t');
    if (f.length < 8) continue;
    final geonameId = int.tryParse(f[1]);
    if (geonameId == null) continue;
    final name = f[3].trim();
    if (name.isEmpty) continue;
    final isPreferred = f[4] == '1';
    final isShort = f[5] == '1';
    final isHistoric = f[7] == '1';
    if (isHistoric) continue;
    final tier = isPreferred ? 0 : (isShort ? 1 : 2);
    final prev = ruLookup[geonameId];
    if (prev == null || tier < prev.tier) {
      ruLookup[geonameId] = _RuPick(name: name, tier: tier);
    }
  }
  stderr.writeln('  loaded ${ruLookup.length} geonameids with ru name');

  // Step 1b: build admin1code → russian region name lookup. Each
  // admin1CodesASCII.txt row links a `<country>.<admin1>` code to a
  // geonameid; we resolve that geonameid through ruLookup to get the
  // Russian name (e.g. "Краснодарский край" instead of "Krasnodar
  // Krai"). Falls back to the hand-curated _admin1Ru, then to ASCII.
  stderr.writeln('Reading ${admin1File.path}...');
  final admin1Ru = <String, String>{};
  for (final line in const LineSplitter()
      .convert(admin1File.readAsStringSync())) {
    if (line.isEmpty) continue;
    final f = line.split('\t');
    if (f.length < 4) continue;
    final code = f[0];
    final name = f[1];
    final geonameId = int.tryParse(f[3]);
    if (geonameId == null) continue;
    final ruName = ruLookup[geonameId]?.name ?? _admin1Ru[code] ?? name;
    admin1Ru[code] = ruName;
  }
  stderr.writeln('  loaded ${admin1Ru.length} admin1 regions');

  // Step 2: parse cities5000.txt, picking the russian name from the
  // lookup or falling back to the ASCII name.
  stderr.writeln('Reading ${citiesFile.path}...');
  final raw = citiesFile.readAsStringSync();
  final lines = const LineSplitter().convert(raw);
  stderr.writeln('  ${lines.length} total rows in cities5000.txt');

  final entries = <_CityEntry>[];
  var seen = 0, kept = 0, ruHits = 0;
  for (final line in lines) {
    if (line.isEmpty) continue;
    final f = line.split('\t');
    if (f.length < 15) continue;
    seen++;

    final featureClass = f[6];
    final country = f[8];
    final admin1 = f[10];
    final populationStr = f[14];

    if (featureClass != 'P') continue;
    if (!_targetCountries.contains(country)) continue;
    final population = int.tryParse(populationStr) ?? 0;
    if (population < 5000) continue;

    final geonameId = int.tryParse(f[0]) ?? 0;
    final asciiName = f[2];
    final ruPick = ruLookup[geonameId];
    final ru = ruPick?.name ?? asciiName;
    if (ruPick != null) ruHits++;

    final regionKey = '$country.$admin1';
    final region = admin1Ru[regionKey] ?? '';

    entries.add(_CityEntry(
      nameRu: ru,
      nameEn: asciiName,
      countryCode: country,
      countryNameRu: _countryNamesRu[country] ?? country,
      regionNameRu: region,
      population: population,
    ));
    kept++;
  }
  stderr.writeln('  scanned $seen settlement rows, kept $kept '
      '(of which $ruHits had a russian alternate name)');

  // Dedup on (nameRu, country, region). Keep highest population.
  final byKey = <String, _CityEntry>{};
  for (final e in entries) {
    final k = '${e.nameRu}|${e.countryCode}|${e.regionNameRu}';
    final prev = byKey[k];
    if (prev == null || e.population > prev.population) {
      byKey[k] = e;
    }
  }
  final deduped = byKey.values.toList();
  stderr.writeln('  deduped to ${deduped.length} entries');

  // ё→е normalised, lowercase comparator. Stable across runs.
  String fold(String s) =>
      s.toLowerCase().replaceAll('ё', 'е').replaceAll('Ё', 'е');
  deduped.sort((a, b) {
    final cmp = fold(a.nameRu).compareTo(fold(b.nameRu));
    if (cmp != 0) return cmp;
    final cc = a.countryCode.compareTo(b.countryCode);
    if (cc != 0) return cc;
    return b.population - a.population;
  });

  // Schema with short keys (r/e/c/cn/a/p) — the file ships with the
  // app and is parsed exactly once at first picker open, so terseness
  // here is a bandwidth-on-disk and parse-time win.
  final json = deduped
      .map((e) => {
            'r': e.nameRu,
            'e': e.nameEn,
            'c': e.countryCode,
            'cn': e.countryNameRu,
            'a': e.regionNameRu,
            'p': e.population,
          })
      .toList();

  final outFile = File('assets/data/cities_ru_cis.json');
  outFile.parent.createSync(recursive: true);
  // Minified JSON. Plain JsonEncoder default produces no whitespace,
  // which is what we want for production.
  outFile.writeAsStringSync(jsonEncode(json));

  stderr.writeln('  wrote ${outFile.path} (${outFile.lengthSync()} bytes, '
      '${deduped.length} entries)');
}

class _CityEntry {
  _CityEntry({
    required this.nameRu,
    required this.nameEn,
    required this.countryCode,
    required this.countryNameRu,
    required this.regionNameRu,
    required this.population,
  });

  final String nameRu;
  final String nameEn;
  final String countryCode;
  final String countryNameRu;
  final String regionNameRu;
  final int population;
}

/// Tier 0 = isPreferredName=1, 1 = isShortName=1, 2 = any other ru name.
/// Lower tier wins.
class _RuPick {
  const _RuPick({required this.name, required this.tier});
  final String name;
  final int tier;
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

/// One settlement entry. The schema mirrors the build-time JSON produced
/// by `scripts/build_cities_dataset.dart` (short keys r/e/c/cn/a/p);
/// here we expand them into readable field names so callers don't deal
/// with bag-of-strings.
class City {
  City({
    required this.nameRu,
    required this.nameEn,
    required this.countryCode,
    required this.countryNameRu,
    required this.regionNameRu,
    required this.population,
    this.isNameAmbiguous = false,
  }) : displayNameRu = _displayNameForRu(countryCode, nameRu),
       _foldedRu = _fold(_displayNameForRu(countryCode, nameRu)),
       _foldedEn = _fold(nameEn);

  /// Russian name as displayed (e.g. "Москва", "Санкт-Петербург"). This
  /// is also what gets written into the report's `cityInspection`
  /// payload when the user picks the city.
  final String nameRu;

  /// User-facing Russian name. Some GeoNames RU rows have ASCII
  /// transliteration in `nameRu`; keep the original raw value for
  /// round-trips, but render a localized value in the UI.
  final String displayNameRu;

  /// ASCII transliteration from GeoNames (e.g. "Moscow"). Used as a
  /// secondary search target so an inspector typing on a Latin keyboard
  /// (`almaty`, `moscow`) finds the right city.
  final String nameEn;

  /// ISO 3166-1 alpha-2 country code. Used for the country chip filter
  /// in the picker UI.
  final String countryCode;

  /// Country name in Russian (e.g. "Россия", "Казахстан"). Shown in the
  /// list tile subtitle.
  final String countryNameRu;

  /// Russian-language admin1 name (oblast/krai/republic). Empty string
  /// when GeoNames had no admin1 mapping for this entry.
  final String regionNameRu;

  /// Population as reported by GeoNames at build time. Used as a
  /// secondary sort key — when two settlements share a name, the bigger
  /// one floats up.
  final int population;

  /// True when another settlement in the same country shares this
  /// display name (е.g. «Мирный» в Якутии и в Архангельской области).
  /// Computed dataset-wide in `_parseCities`; drives [shortLabel] —
  /// ambiguous names must carry the region or the report reader can't
  /// tell which city was meant.
  final bool isNameAmbiguous;

  // Pre-computed lowercase + ё→е normalisation for fast `contains`.
  // Stored on the instance so `search()` does zero allocation per
  // candidate during a query — important when the dataset is ~5K rows
  // and the user types fast.
  final String _foldedRu;
  final String _foldedEn;

  static String _fold(String s) =>
      s.toLowerCase().replaceAll('ё', 'е').replaceAll('Ё', 'е');

  /// Region name for subtitles/suffixes, or `null` when it's missing
  /// or duplicates the city name (federal cities like Москва /
  /// Санкт-Петербург where admin1 == city).
  String? get distinctRegionRu {
    if (regionNameRu.isEmpty) return null;
    if (regionNameRu.toLowerCase() == displayNameRu.toLowerCase()) return null;
    return regionNameRu;
  }

  /// Compact label written into form fields and report payloads:
  /// just «Краснодар», or «Мирный, Архангельская область» when several
  /// settlements in the same country share the name. The app is
  /// RU-only, so the country prefix is pure noise for the reader —
  /// [displayLabel] keeps the full form for round-trips with drafts
  /// saved before the rollout.
  String get shortLabel {
    final region = distinctRegionRu;
    if (isNameAmbiguous && region != null) return '$displayNameRu, $region';
    return displayNameRu;
  }

  /// Full "Country, Region, City" label. No longer written anywhere,
  /// but `findByExactRu` still matches it so drafts saved while this
  /// was the picker's output format stay valid.
  String get displayLabel {
    final parts = <String>[];
    if (countryNameRu.isNotEmpty) parts.add(countryNameRu);
    final region = distinctRegionRu;
    if (region != null) parts.add(region);
    parts.add(displayNameRu);
    return parts.join(', ');
  }

  /// Round-trip (asset → object) constructor. Tolerant to extra fields
  /// in case the build script grows the schema later. Ambiguity is a
  /// dataset-wide property, so it can't be derived from a single row —
  /// `_parseCities` passes it in after counting name collisions.
  factory City.fromJson(
    Map<String, dynamic> j, {
    bool isNameAmbiguous = false,
  }) => City(
    nameRu: (j['r'] ?? '') as String,
    nameEn: (j['e'] ?? '') as String,
    countryCode: (j['c'] ?? '') as String,
    countryNameRu: (j['cn'] ?? '') as String,
    regionNameRu: (j['a'] ?? '') as String,
    population: (j['p'] is num) ? (j['p'] as num).toInt() : 0,
    isNameAmbiguous: isNameAmbiguous,
  );

  @override
  String toString() => '$displayNameRu, $countryNameRu';
}

const Map<String, String> _ruCityDisplayOverrides = {
  'kurortnyy': 'Курортный',
  'gorod solnetchnogorsk': 'Солнечногорск',
};

String _displayNameForRu(String countryCode, String rawName) {
  final value = rawName.trim();
  if (value.isEmpty || countryCode != 'RU') return rawName;
  if (!RegExp(r'[A-Za-z]').hasMatch(value)) return rawName;
  final override = _ruCityDisplayOverrides[value.toLowerCase()];
  if (override != null) return override;
  return _transliterateAsciiRu(value);
}

String _transliterateAsciiRu(String value) {
  return value
      .split(RegExp(r'\s+'))
      .map(_transliterateAsciiRuWord)
      .where((part) => part.isNotEmpty)
      .join(' ');
}

String _transliterateAsciiRuWord(String word) {
  var source = word.trim().toLowerCase();
  if (source.isEmpty) return '';
  source = source.replaceAll(RegExp(r'[^a-z]+'), '');
  if (source.isEmpty) return word;
  if (source.endsWith('yy')) {
    final stem = _transliterateAsciiRuWord(
      source.substring(0, source.length - 2),
    );
    return '$stemый';
  }
  const digraphs = <String, String>{
    'shch': 'щ',
    'sch': 'щ',
    'yo': 'ё',
    'yu': 'ю',
    'ya': 'я',
    'ye': 'е',
    'zh': 'ж',
    'kh': 'х',
    'ts': 'ц',
    'ch': 'ч',
    'sh': 'ш',
  };
  const chars = <String, String>{
    'a': 'а',
    'b': 'б',
    'c': 'к',
    'd': 'д',
    'e': 'е',
    'f': 'ф',
    'g': 'г',
    'h': 'х',
    'i': 'и',
    'j': 'й',
    'k': 'к',
    'l': 'л',
    'm': 'м',
    'n': 'н',
    'o': 'о',
    'p': 'п',
    'q': 'к',
    'r': 'р',
    's': 'с',
    't': 'т',
    'u': 'у',
    'v': 'в',
    'w': 'в',
    'x': 'кс',
    'y': 'ы',
    'z': 'з',
  };
  final out = StringBuffer();
  var index = 0;
  while (index < source.length) {
    var matched = false;
    for (final entry in digraphs.entries) {
      if (!source.startsWith(entry.key, index)) continue;
      out.write(entry.value);
      index += entry.key.length;
      matched = true;
      break;
    }
    if (matched) continue;
    final char = source[index];
    out.write(chars[char] ?? char);
    index += 1;
  }
  final result = out.toString();
  if (result.isEmpty) return word;
  return '${result[0].toUpperCase()}${result.substring(1)}';
}

/// Loads `assets/data/cities_ru_cis.json` once per app session and
/// answers `search()` / `findByExactRu()` queries against the in-memory
/// list. Singleton because the dataset is immutable and there is no
/// reason to keep more than one copy of ~5K entries in RAM.
///
/// Construction note: `CityRepository.instance` is the runtime path.
/// `CityRepository.test(jsonString)` is a test seam that bypasses
/// `rootBundle` — pure-Dart unit tests don't need to wire up Flutter
/// asset bundles.
class CityRepository {
  CityRepository._();

  static final CityRepository instance = CityRepository._();

  /// Test-only constructor: skips rootBundle, parses immediately. Lets
  /// `test/city_repository_test.dart` run as a plain Dart test without
  /// `WidgetsFlutterBinding.ensureInitialized()`.
  factory CityRepository.test(String jsonSource) {
    final repo = CityRepository._();
    repo._loadFromString(jsonSource);
    return repo;
  }

  /// Test-only: pre-populates the singleton's data so widget tests can
  /// open the picker without going through `rootBundle`. Production
  /// code should never call this.
  @visibleForTesting
  static void installSingletonForTest(String jsonSource) {
    instance._loadFromString(jsonSource);
    instance._loading = Future.value();
  }

  /// Test-only: clears the singleton's loaded data so each test starts
  /// from a known state. Production code should never call this.
  @visibleForTesting
  static void resetSingletonForTest() {
    instance._cities = null;
    instance._loading = null;
  }

  static const String _assetPath = 'assets/data/cities_ru_cis.json';

  List<City>? _cities;
  Future<void>? _loading;

  /// True once the JSON has been parsed and `_cities` is populated.
  /// Synchronous callers (e.g. completion rules in spark_joy) check
  /// this before invoking `findByExactRu`; if false, they kick off
  /// `init()` and re-check after `setState`.
  bool get isReady => _cities != null;

  /// Test seam: how to fetch the JSON source. Production path goes
  /// through `rootBundle`; tests can swap this to inject canned data
  /// or simulate I/O failures without wiring up an asset bundle.
  @visibleForTesting
  Future<String> Function() loaderForTest = () =>
      rootBundle.loadString(_assetPath);

  /// Load the dataset. Idempotent — concurrent callers share the same
  /// `Future` (in-flight requests deduplicate). Safe to call from
  /// `initState` / draft-hydration paths even before the picker is
  /// opened.
  ///
  /// On failure (asset missing, JSON malformed) `_loading` is reset to
  /// `null` so the next caller gets a fresh attempt. Without this
  /// reset, a single transient failure during app boot would lock the
  /// repository into a permanently-rejected state and the picker
  /// would silently never recover until the app restarts.
  Future<void> init() {
    if (_cities != null) return Future.value();
    return _loading ??= _runLoad();
  }

  Future<void> _runLoad() async {
    try {
      final source = await loaderForTest();
      // 429 КБ JSON → ~5К City-объектов (плюс фолдинг строк в каждом
      // конструкторе): синхронный парс держал главный изолят десятки мс
      // ровно в момент открытия city-пикера — шторка дёргалась на входе.
      // City — плоские строки/int, так что копия результата из compute()
      // дёшева. Тестовые швы (CityRepository.test / installSingletonForTest)
      // остаются на синхронном _loadFromString.
      _cities = await compute(_parseCities, source);
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  void _loadFromString(String source) {
    _cities = _parseCities(source);
  }

  static List<City> _parseCities(String source) {
    final raw = jsonDecode(source);
    if (raw is! List) {
      throw const FormatException(
        'cities_ru_cis.json: expected top-level JSON array',
      );
    }
    final maps = raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList(growable: false);
    // Two-pass: count display-name collisions per country first, so
    // each City knows whether its shortLabel needs the region
    // («Мирный» есть и в Якутии, и в Архангельской области).
    final nameCount = <String, int>{};
    for (final m in maps) {
      nameCount.update(_collisionKey(m), (v) => v + 1, ifAbsent: () => 1);
    }
    return maps
        .map(
          (m) => City.fromJson(
            m,
            isNameAmbiguous: (nameCount[_collisionKey(m)] ?? 0) > 1,
          ),
        )
        .toList(growable: false);
  }

  static String _collisionKey(Map<String, dynamic> m) {
    final country = (m['c'] ?? '') as String;
    final display = _displayNameForRu(country, (m['r'] ?? '') as String);
    return '$country|${City._fold(display)}';
  }

  /// Returns up to [limit] cities matching [query] (case-insensitive,
  /// ё→е folded, matches both Russian and ASCII names). Empty query
  /// returns the [limit] most populous cities — that's what the picker
  /// shows before the user types, so the likely answers (Москва,
  /// Санкт-Петербург, миллионники) surface without a keystroke. When
  /// [countryCode] is set, filters to that country only.
  ///
  /// Sort: `startsWith` matches first, then `contains`, then by
  /// descending population. This brings "Москва" up when typing "мос"
  /// even though "Подмосковье" technically `contains` "мос" too.
  ///
  /// Throws [StateError] if called before [init] completes — caller
  /// should `await init()` or check [isReady].
  List<City> search(String query, {String? countryCode, int limit = 200}) {
    final cities = _cities;
    if (cities == null) {
      throw StateError(
        'CityRepository.search() called before init() completed',
      );
    }
    final q = City._fold(query.trim());

    Iterable<City> filtered = cities;
    if (countryCode != null && countryCode.isNotEmpty) {
      filtered = filtered.where((c) => c.countryCode == countryCode);
    }
    if (q.isEmpty) {
      // The dataset ships alphabetically sorted; taking the head would
      // open the picker on «Абаза, Абакан, …». Sort by population
      // descending instead (alphabetical tie-break keeps the order
      // deterministic — List.sort is not stable).
      final byPopulation = filtered.toList()
        ..sort((a, b) {
          final byPop = b.population - a.population;
          if (byPop != 0) return byPop;
          return a._foldedRu.compareTo(b._foldedRu);
        });
      return byPopulation.take(limit).toList(growable: false);
    }

    // Score: 0 = startsWith ru, 1 = startsWith en, 2 = contains ru,
    // 3 = contains en. Reject everything else.
    final scored = <_ScoredCity>[];
    for (final c in filtered) {
      int score;
      if (c._foldedRu.startsWith(q)) {
        score = 0;
      } else if (c._foldedEn.startsWith(q)) {
        score = 1;
      } else if (c._foldedRu.contains(q)) {
        score = 2;
      } else if (c._foldedEn.contains(q)) {
        score = 3;
      } else {
        continue;
      }
      scored.add(_ScoredCity(c, score));
    }
    scored.sort((a, b) {
      final s = a.score - b.score;
      if (s != 0) return s;
      return b.city.population - a.city.population;
    });
    return scored.take(limit).map((s) => s.city).toList(growable: false);
  }

  /// Strict round-trip lookup: returns the [City] whose name (or one
  /// of its label forms) equals [s] case-insensitively after trim.
  /// Matches ALL formats the picker has ever written so that:
  ///   - Old drafts with just "Краснодар" stay valid (matched via
  ///     `nameRu`).
  ///   - Ambiguous-name drafts with "Мирный, Архангельская область"
  ///     are valid (matched via `shortLabel`).
  ///   - Legacy drafts with "Россия, Краснодарский край, Краснодар"
  ///     are also valid (matched via `displayLabel`).
  ///
  /// Returns null when nothing matches — the spark_joy / auto_request
  /// submit gate then surfaces the "out-of-list" warning.
  City? findByExactRu(String s) {
    final cities = _cities;
    if (cities == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    final folded = City._fold(t);
    for (final c in cities) {
      if (c._foldedRu == folded) return c;
      // shortLabel differs from the bare folded name only for
      // ambiguous entries — skip the extra fold for the ~99% rest.
      if (c.isNameAmbiguous && City._fold(c.shortLabel) == folded) return c;
      if (City._fold(c.displayLabel) == folded) return c;
    }
    return null;
  }
}

class _ScoredCity {
  _ScoredCity(this.city, this.score);
  final City city;
  final int score;
}

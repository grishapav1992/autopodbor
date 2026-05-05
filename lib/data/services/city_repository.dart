import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
  })  : _foldedRu = _fold(nameRu),
        _foldedEn = _fold(nameEn);

  /// Russian name as displayed (e.g. "Москва", "Санкт-Петербург"). This
  /// is also what gets written into the report's `cityInspection`
  /// payload when the user picks the city.
  final String nameRu;

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

  // Pre-computed lowercase + ё→е normalisation for fast `contains`.
  // Stored on the instance so `search()` does zero allocation per
  // candidate during a query — important when the dataset is ~5K rows
  // and the user types fast.
  final String _foldedRu;
  final String _foldedEn;

  static String _fold(String s) =>
      s.toLowerCase().replaceAll('ё', 'е').replaceAll('Ё', 'е');

  /// Full "Country, Region, City" label that's written into the
  /// inspection report and shown in the picker tile. Skips the region
  /// when it's missing or duplicates the city name (federal cities
  /// like Москва / Санкт-Петербург where admin1 == city).
  String get displayLabel {
    final parts = <String>[];
    if (countryNameRu.isNotEmpty) parts.add(countryNameRu);
    if (regionNameRu.isNotEmpty &&
        regionNameRu.toLowerCase() != nameRu.toLowerCase()) {
      parts.add(regionNameRu);
    }
    parts.add(nameRu);
    return parts.join(', ');
  }

  /// Round-trip (asset → object) constructor. Tolerant to extra fields
  /// in case the build script grows the schema later.
  factory City.fromJson(Map<String, dynamic> j) => City(
        nameRu: (j['r'] ?? '') as String,
        nameEn: (j['e'] ?? '') as String,
        countryCode: (j['c'] ?? '') as String,
        countryNameRu: (j['cn'] ?? '') as String,
        regionNameRu: (j['a'] ?? '') as String,
        population: (j['p'] is num) ? (j['p'] as num).toInt() : 0,
      );

  @override
  String toString() => '$nameRu, $countryNameRu';
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
  Future<String> Function() loaderForTest =
      () => rootBundle.loadString(_assetPath);

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
      _loadFromString(source);
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  void _loadFromString(String source) {
    final raw = jsonDecode(source);
    if (raw is! List) {
      throw const FormatException(
        'cities_ru_cis.json: expected top-level JSON array',
      );
    }
    _cities = raw
        .whereType<Map>()
        .map((m) => City.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// Returns up to [limit] cities matching [query] (case-insensitive,
  /// ё→е folded, matches both Russian and ASCII names). Empty query
  /// returns the first [limit] entries from the master list. When
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
      throw StateError('CityRepository.search() called before init() completed');
    }
    final q = City._fold(query.trim());

    Iterable<City> filtered = cities;
    if (countryCode != null && countryCode.isNotEmpty) {
      filtered = filtered.where((c) => c.countryCode == countryCode);
    }
    if (q.isEmpty) {
      return filtered.take(limit).toList(growable: false);
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

  /// Strict round-trip lookup: returns the [City] whose name (or full
  /// "Country, Region, City" display label) equals [s] case-
  /// insensitively after trim. Matches BOTH formats so that:
  ///   - Old drafts with just "Краснодар" stay valid (matched via
  ///     `nameRu`).
  ///   - New drafts with "Россия, Краснодарский край, Краснодар" are
  ///     also valid (matched via `displayLabel`).
  ///
  /// Returns null when neither matches — the spark_joy / auto_request
  /// submit gate then surfaces the "out-of-list" warning.
  City? findByExactRu(String s) {
    final cities = _cities;
    if (cities == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    final folded = City._fold(t);
    for (final c in cities) {
      if (c._foldedRu == folded) return c;
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

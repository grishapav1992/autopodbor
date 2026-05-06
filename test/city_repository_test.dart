// Pure-Dart tests for CityRepository — no Flutter binding required.
// We bypass `rootBundle` via the `CityRepository.test(jsonString)`
// constructor and feed a small handcrafted fixture covering the
// behaviours that matter:
//
//   - case-insensitive matching
//   - ё→е folding
//   - Latin-keyboard fallback (`almaty` → Алматы)
//   - prefix-first ranking
//   - country chip filter
//   - exact-match lookup used by the spark_joy submit gate

import 'dart:convert';

import 'package:flutter_application_1/data/services/city_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = [
  {
    'r': 'Москва',
    'e': 'Moscow',
    'c': 'RU',
    'cn': 'Россия',
    'a': 'Москва',
    'p': 10381222,
  },
  {
    'r': 'Санкт-Петербург',
    'e': 'Saint Petersburg',
    'c': 'RU',
    'cn': 'Россия',
    'a': 'Санкт-Петербург',
    'p': 5351935,
  },
  {
    'r': 'Подмосковье',
    'e': 'Podmoskovye',
    'c': 'RU',
    'cn': 'Россия',
    'a': 'Московская область',
    'p': 200000,
  },
  {
    'r': 'Алматы',
    'e': 'Almaty',
    'c': 'KZ',
    'cn': 'Казахстан',
    'a': 'Алматы',
    'p': 1977011,
  },
  {
    'r': 'Астана',
    'e': 'Astana',
    'c': 'KZ',
    'cn': 'Казахстан',
    'a': 'Астана',
    'p': 1000000,
  },
  {
    'r': 'Ёлкино',
    'e': 'Yolkino',
    'c': 'RU',
    'cn': 'Россия',
    'a': '',
    'p': 5500,
  },
];

CityRepository _build() => CityRepository.test(jsonEncode(_fixture));

void main() {
  group('CityRepository.search', () {
    test('returns "Москва" first when query is "мос"', () {
      final repo = _build();
      final results = repo.search('мос');
      expect(results, isNotEmpty);
      expect(results.first.nameRu, 'Москва');
    });

    test('case-insensitive: "МОСКВА" hits "Москва"', () {
      final repo = _build();
      expect(repo.search('МОСКВА').first.nameRu, 'Москва');
    });

    test('ё→е folding: query "елкино" hits "Ёлкино"', () {
      final repo = _build();
      expect(repo.search('елкино').first.nameRu, 'Ёлкино');
    });

    test('latin-keyboard fallback: "almaty" hits "Алматы"', () {
      final repo = _build();
      expect(repo.search('almaty').first.nameRu, 'Алматы');
    });

    test('startsWith ranks above contains', () {
      // "мос" matches "Москва" (startsWith) and "Подмосковье"
      // (contains). The startsWith hit must come first.
      final repo = _build();
      final ranked = repo.search('мос');
      expect(ranked[0].nameRu, 'Москва');
      // "Подмосковье" should still appear, just lower ranked.
      expect(ranked.any((c) => c.nameRu == 'Подмосковье'), isTrue);
      expect(
        ranked.indexWhere((c) => c.nameRu == 'Подмосковье'),
        greaterThan(0),
      );
    });

    test('countryCode filter narrows result set', () {
      final repo = _build();
      final kz = repo.search('а', countryCode: 'KZ');
      expect(kz, isNotEmpty);
      expect(kz.every((c) => c.countryCode == 'KZ'), isTrue);
      // Sanity: Russian cities with "а" exist in the fixture but must
      // NOT bleed into the KZ-filtered results.
      expect(kz.any((c) => c.nameRu == 'Москва'), isFalse);
    });

    test('empty result for nonsense query', () {
      final repo = _build();
      expect(repo.search('xyzqwerty'), isEmpty);
    });

    test('limit caps the result count', () {
      final repo = _build();
      final two = repo.search('', limit: 2);
      expect(two.length, 2);
    });

    test('throws StateError when called before init', () {
      // Singleton path has no fixture loaded — but we test the
      // private path directly via a fresh test-construct that we
      // never feed JSON to. To exercise this, we build the
      // singleton-like via the runtime constructor, which we don't
      // expose; instead, verify the message via the singleton if
      // its `_cities` is null at session start. Since other tests
      // may have populated `instance` already, skip without a
      // shared-state contract — covered by the StateError throw in
      // search() implementation, exercised in widget test where
      // the picker waits for the future before searching.
    }, skip: 'Singleton state leaks across tests; covered by widget test');
  });

  group('CityRepository.findByExactRu', () {
    test('exact-match lookup by bare nameRu (legacy form)', () {
      final repo = _build();
      expect(repo.findByExactRu('Москва')?.nameEn, 'Moscow');
    });

    test('matches the new full "Country, Region, City" displayLabel', () {
      // After the displayLabel rollout the picker writes a full
      // "Россия, ..." string into the controller. findByExactRu must
      // accept that form too, otherwise a freshly-saved draft would
      // be marked out-of-list when reopened.
      final repo = _build();
      final m = repo.findByExactRu('Россия, Москва');
      expect(m, isNotNull);
      expect(m!.nameEn, 'Moscow');

      // A federal city without a separate admin1 still has the same
      // displayLabel format — "Country, City".
      final p = repo.findByExactRu('Россия, Санкт-Петербург');
      expect(p?.nameEn, 'Saint Petersburg');
    });

    test('case-insensitive exact match', () {
      final repo = _build();
      expect(repo.findByExactRu('москва')?.nameEn, 'Moscow');
      expect(repo.findByExactRu('россия, москва')?.nameEn, 'Moscow');
    });

    test('trim is applied', () {
      final repo = _build();
      expect(repo.findByExactRu('  Москва  ')?.nameEn, 'Moscow');
    });

    test('ё→е folded equality', () {
      final repo = _build();
      expect(repo.findByExactRu('Ёлкино'), isNotNull);
      expect(repo.findByExactRu('Елкино'), isNotNull);
    });

    test('null when not found — abbreviations like "Мск" are NOT fuzzy-matched',
        () {
      // The product decision is "no free-text fallback" — short forms
      // must not silently match. The user has to reselect.
      final repo = _build();
      expect(repo.findByExactRu('Мск'), isNull);
      expect(repo.findByExactRu('Питер'), isNull);
    });

    test('null for empty/whitespace input', () {
      final repo = _build();
      expect(repo.findByExactRu(''), isNull);
      expect(repo.findByExactRu('   '), isNull);
    });
  });

  group('City.displayLabel', () {
    test('joins country + region + name when all present', () {
      final c = City.fromJson({
        'r': 'Краснодар',
        'e': 'Krasnodar',
        'c': 'RU',
        'cn': 'Россия',
        'a': 'Краснодарский край',
        'p': 899541,
      });
      expect(c.displayLabel, 'Россия, Краснодарский край, Краснодар');
    });

    test('drops region when it duplicates the city (federal city)', () {
      // Москва has admin1 == "Москва" — the duplicate would read
      // "Россия, Москва, Москва", which is ugly. The getter dedupes.
      final c = City.fromJson({
        'r': 'Москва',
        'e': 'Moscow',
        'c': 'RU',
        'cn': 'Россия',
        'a': 'Москва',
        'p': 10381222,
      });
      expect(c.displayLabel, 'Россия, Москва');
    });

    test('drops region when empty', () {
      final c = City.fromJson({
        'r': 'Душанбе',
        'e': 'Dushanbe',
        'c': 'TJ',
        'cn': 'Таджикистан',
        'a': '',
        'p': 679400,
      });
      expect(c.displayLabel, 'Таджикистан, Душанбе');
    });
  });

  group('CityRepository.isReady', () {
    test('test constructor reports ready immediately', () {
      final repo = _build();
      expect(repo.isReady, isTrue);
    });
  });

  group('CityRepository.init — retry semantics', () {
    setUp(CityRepository.resetSingletonForTest);
    tearDown(CityRepository.resetSingletonForTest);

    test('singleton init() retries after a transient load failure',
        () async {
      // Reproduce the bug guarded by the rollback fix in `_runLoad`:
      // the FIRST `init()` throws (e.g. asset bundle hiccup); a
      // SECOND `init()` must NOT inherit the rejected future and
      // must actually re-run the loader. Without the
      // `_loading = null` reset on catch, the second call returns
      // the cached failure instantly and the picker never recovers
      // until the app restarts.
      var attempts = 0;
      CityRepository.instance.loaderForTest = () async {
        attempts++;
        if (attempts == 1) {
          throw const FormatException('simulated transient failure');
        }
        return jsonEncode(_fixture);
      };

      await expectLater(
        CityRepository.instance.init(),
        throwsA(isA<FormatException>()),
      );
      expect(attempts, 1);
      expect(CityRepository.instance.isReady, isFalse);

      // Second attempt must succeed because `_loading` was reset.
      await CityRepository.instance.init();
      expect(attempts, 2);
      expect(CityRepository.instance.isReady, isTrue);
      expect(
        CityRepository.instance.findByExactRu('Москва'),
        isNotNull,
      );
    });

    test('concurrent init() calls dedupe to a single load', () async {
      // The `_loading ??= ...` guard means N parallel callers share
      // one underlying load — important to avoid re-parsing the
      // 600 KB JSON several times when the picker, the spark_joy
      // hydrator, and the auto_request initState all fire init at
      // app startup.
      var attempts = 0;
      CityRepository.instance.loaderForTest = () async {
        attempts++;
        // Simulate non-trivial work so concurrent callers actually
        // overlap. Without the delay, a microtask-bound test could
        // resolve the first call before the others observe it.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonEncode(_fixture);
      };

      await Future.wait([
        CityRepository.instance.init(),
        CityRepository.instance.init(),
        CityRepository.instance.init(),
      ]);
      expect(attempts, 1);
      expect(CityRepository.instance.isReady, isTrue);
    });
  });

  group('City.fromJson', () {
    test('unpacks short keys into named fields', () {
      final c = City.fromJson({
        'r': 'X',
        'e': 'X',
        'c': 'RU',
        'cn': 'Россия',
        'a': 'обл',
        'p': 1234,
      });
      expect(c.nameRu, 'X');
      expect(c.countryNameRu, 'Россия');
      expect(c.population, 1234);
    });

    test('tolerates missing fields with empty defaults', () {
      final c = City.fromJson({});
      expect(c.nameRu, '');
      expect(c.population, 0);
    });
  });
}

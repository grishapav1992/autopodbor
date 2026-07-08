import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/car_catalog_repository.dart';
import 'package:flutter_application_1/data/services/car_catalog_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory store: считает вызовы save*, позволяет подложить записи с
/// нужным savedAtMs (свежие/протухшие).
class _FakeStore implements CarCatalogStore {
  bool generationsSupported = true;
  CarCatalogStoreEntry<BrandItem>? brandsEntry;
  final Map<int, CarCatalogStoreEntry<ModelItem>> modelsEntries = {};
  final Map<int, CarCatalogStoreEntry<GenerationItem>> generationsEntries = {};
  int saveBrandsCalls = 0;
  int saveModelsCalls = 0;
  int saveGenerationsCalls = 0;

  @override
  bool get supportsGenerations => generationsSupported;

  @override
  Future<CarCatalogStoreEntry<BrandItem>?> loadBrands() async => brandsEntry;

  @override
  Future<bool> saveBrands(List<BrandItem> items) async {
    saveBrandsCalls++;
    brandsEntry = CarCatalogStoreEntry(
      items: items,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  @override
  Future<CarCatalogStoreEntry<ModelItem>?> loadModels(int brandId) async =>
      modelsEntries[brandId];

  @override
  Future<bool> saveModels(int brandId, List<ModelItem> items) async {
    saveModelsCalls++;
    modelsEntries[brandId] = CarCatalogStoreEntry(
      items: items,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  @override
  Future<CarCatalogStoreEntry<GenerationItem>?> loadGenerations(
    int modelCarId,
  ) async => generationsEntries[modelCarId];

  @override
  Future<bool> saveGenerations(
    int modelCarId,
    List<GenerationItem> items,
  ) async {
    saveGenerationsCalls++;
    generationsEntries[modelCarId] = CarCatalogStoreEntry(
      items: items,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  @override
  Future<int?> generationsSavedAtMs(int modelCarId) async =>
      generationsEntries[modelCarId]?.savedAtMs;
}

int _staleMs() =>
    DateTime.now().millisecondsSinceEpoch -
    (kCarCatalogTtl + const Duration(days: 1)).inMilliseconds;

BrandCatalog _catalogOf(List<BrandItem> items) {
  final names = items.map((b) => b.name).toSet().toList()..sort();
  return BrandCatalog(
    items: items,
    names: names,
    rusByName: {
      for (final b in items)
        if (b.nameRus.isNotEmpty) b.name: b.nameRus,
    },
    idByName: {for (final b in items) b.name: b.id},
  );
}

final _skoda = BrandItem(id: 1, name: 'Skoda', nameRus: 'Шкода');
final _lada = BrandItem(id: 2, name: 'Lada', nameRus: 'Лада');
final _octavia = ModelItem(
  id: 11,
  brandId: 1,
  model: 'Octavia',
  modelRus: 'Октавия',
);
final _rapid = ModelItem(id: 12, brandId: 1, model: 'Rapid', modelRus: '');

/// Пара тиков event loop — фоновые stale-рефреши успевают дойти до конца.
Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeStore store;
  late CarCatalogRepository repo;
  int brandsFetches = 0;
  int generationsFetches = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();

    CarCatalogRepository.resetSingletonForTest();
    repo = CarCatalogRepository.instance;
    store = _FakeStore();
    repo.store = store;
    brandsFetches = 0;
    generationsFetches = 0;
    repo.brandsFetcher = () async {
      brandsFetches++;
      return _catalogOf([_lada, _skoda]); // порядок бэка: Lada раньше Skoda
    };
    repo.modelsFetcher = (brandId) async {
      if (brandId == 1) return [_octavia, _rapid];
      return <ModelItem>[];
    };
    repo.generationsFetcher = (modelCarId) async {
      generationsFetches++;
      return <GenerationItem>[];
    };
  });

  tearDown(CarCatalogRepository.resetSingletonForTest);

  group('cache-first', () {
    test('свежий store → 0 сетевых вызовов, порядок бэка сохранён', () async {
      store.brandsEntry = CarCatalogStoreEntry(
        items: [_lada, _skoda],
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final brands = await repo.getBrands();
      expect(brands.map((b) => b.name).toList(), ['Lada', 'Skoda']);
      expect(brandsFetches, 0);
      expect(repo.isReady, isTrue);
    });

    test('пустой store → сеть + write-through + revision', () async {
      final revBefore = repo.revision.value;
      final brands = await repo.getBrands();
      expect(brands.length, 2);
      expect(brandsFetches, 1);
      expect(store.saveBrandsCalls, 1);
      expect(repo.revision.value, greaterThan(revBefore));

      // повторный вызов — из памяти
      await repo.getBrands();
      expect(brandsFetches, 1);
    });

    test('протухший store: отдаём кэш сразу, тихо обновляем в фоне', () async {
      store.brandsEntry = CarCatalogStoreEntry(
        items: [_skoda],
        savedAtMs: _staleMs(),
      );
      final brands = await repo.getBrands();
      expect(
        brands.map((b) => b.name).toList(),
        ['Skoda'],
        reason: 'протухший кэш должен отдаваться немедленно',
      );

      await _drainMicrotasks();
      expect(
        brandsFetches,
        1,
        reason: 'фоновый рефреш должен был сходить в сеть',
      );
      final refreshed = await repo.getBrands();
      expect(refreshed.map((b) => b.name).toList(), ['Lada', 'Skoda']);
    });

    test(
      'кэша нет и сеть упала → throw; после починки — retry работает',
      () async {
        repo.brandsFetcher = () async => throw Exception('offline');
        await expectLater(repo.getBrands(), throwsA(isA<Exception>()));

        repo.brandsFetcher = () async {
          brandsFetches++;
          return _catalogOf([_skoda]);
        };
        final brands = await repo.getBrands();
        expect(brands.single.name, 'Skoda');
      },
    );

    test(
      'пустой список моделей/поколений — валидный кэш, сеть не дёргается повторно',
      () async {
        final gens = await repo.getGenerations(999);
        expect(gens, isEmpty);
        expect(generationsFetches, 1);

        final again = await repo.getGenerations(999);
        expect(again, isEmpty);
        expect(
          generationsFetches,
          1,
          reason: 'пустой результат должен кэшироваться',
        );
      },
    );
  });

  group('resolveCar', () {
    setUp(() {
      store.brandsEntry = CarCatalogStoreEntry(
        items: [_lada, _skoda],
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      store.modelsEntries[1] = CarCatalogStoreEntry(
        items: [_octavia, _rapid],
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });

    test('точный матч по латинице', () async {
      final match = await repo.resolveCar('Skoda', 'Octavia');
      expect(match, isNotNull);
      expect(match!.full, isTrue);
      expect(match.brand.id, 1);
      expect(match.model!.id, 11);
    });

    test('регистр/пробелы/русские имена', () async {
      final match = await repo.resolveCar('  шкода ', 'ОКТАВИЯ');
      expect(match!.full, isTrue);
      expect(match.model!.model, 'Octavia');
    });

    test('ё→е фолдинг', () async {
      store.brandsEntry = CarCatalogStoreEntry(
        items: [BrandItem(id: 3, name: 'Citroen', nameRus: 'Ситроён')],
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      CarCatalogRepository.resetSingletonForTest();
      repo = CarCatalogRepository.instance..store = store;
      final match = await repo.resolveCar('ситроен', '');
      expect(match, isNotNull);
      expect(match!.brand.id, 3);
      expect(match.full, isFalse);
    });

    test('марка есть, модель неизвестна → частичный матч', () async {
      final match = await repo.resolveCar('Skoda', 'Fabia RS');
      expect(match, isNotNull);
      expect(match!.full, isFalse);
      expect(match.brand.id, 1);
      expect(match.model, isNull);
    });

    test('марки нет в каталоге → null', () async {
      expect(await repo.resolveCar('Packard', 'Eight'), isNull);
    });

    test('каталог недоступен (пусто+офлайн) → null, не throw', () async {
      store.brandsEntry = null;
      CarCatalogRepository.resetSingletonForTest();
      repo = CarCatalogRepository.instance
        ..store = store
        ..brandsFetcher = (() async => throw Exception('offline'));
      expect(await repo.resolveCar('Skoda', 'Octavia'), isNull);
    });
  });

  group('синхронные выборки', () {
    setUp(() async {
      store.brandsEntry = CarCatalogStoreEntry(
        items: [_lada, _skoda], // порядок бэка
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await repo.getBrands();
    });

    test('brandNamesSorted — алфавит, searchBrands("") — порядок бэка', () {
      expect(repo.brandNamesSorted, ['Lada', 'Skoda']);
      expect(repo.searchBrands('').map((b) => b.name).toList(), [
        'Lada',
        'Skoda',
      ]);
      expect(repo.brandIdByName['Skoda'], 1);
      expect(repo.brandRusByName['Lada'], 'Лада');
    });

    test('searchBrands: startsWith выше contains, ищет и по nameRus', () {
      expect(repo.searchBrands('шко').map((b) => b.name).toList(), ['Skoda']);
      expect(
        repo.searchBrands('da').map((b) => b.name).toList(),
        containsAll(['Lada', 'Skoda']),
      );
    });

    test('searchModels работает после getModels', () async {
      await repo.getModels(1);
      expect(repo.searchModels(1, 'окт').map((m) => m.model).toList(), [
        'Octavia',
      ]);
      expect(repo.searchModels(2, 'окт'), isEmpty);
    });
  });

  group('поколения', () {
    test('putGenerations обрезает фото до 3 лучших', () async {
      final photos = List.generate(
        6,
        (i) => PhotoItem(
          id: i,
          size: i == 0 ? 'xl' : 's',
          urlX1: 'https://x/$i.jpg',
          urlX2: '',
        ),
      );
      repo.generationsFetcher = (modelCarId) async {
        generationsFetches++;
        return [
          GenerationItem(
            id: 1,
            modelCarId: modelCarId,
            generation: 1,
            frames: const [],
            restylings: [
              RestylingItem(
                id: 1,
                restyling: 'r',
                yearStart: null,
                yearEnd: null,
                frames: const [],
                photos: photos,
              ),
            ],
          ),
        ];
      };

      final gens = await repo.getGenerations(11);
      final saved = gens.single.restylings.single.photos;
      expect(saved.length, 3);
      expect(saved.first.size, 'xl', reason: 'лучшее фото должно выжить');
      expect(
        store
            .generationsEntries[11]!
            .items
            .single
            .restylings
            .single
            .photos
            .length,
        3,
        reason: 'в персист уходит уже обрезанный список',
      );
    });

    test(
      'недавно открытые модели пишутся в prefs для приоритета синка',
      () async {
        await repo.getGenerations(11);
        await repo.getGenerations(12);
        await _drainMicrotasks();
        expect(await repo.recentModelIds(), [12, 11]);
      },
    );
  });

  group('hasFreshModels', () {
    test(
      'false без кэша, true после putModels, false для протухшего',
      () async {
        expect(await repo.hasFreshModels(1), isFalse);

        await repo.putModels(1, [_octavia]);
        expect(await repo.hasFreshModels(1), isTrue);

        store.modelsEntries[2] = CarCatalogStoreEntry(
          items: [_rapid],
          savedAtMs: _staleMs(),
        );
        expect(await repo.hasFreshModels(2), isFalse);
      },
    );
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/car_catalog_repository.dart';
import 'package:flutter_application_1/data/services/car_catalog_store.dart';
import 'package:flutter_application_1/data/services/car_catalog_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStore implements CarCatalogStore {
  bool generationsSupported = true;
  CarCatalogStoreEntry<BrandItem>? brandsEntry;
  final Map<int, CarCatalogStoreEntry<ModelItem>> modelsEntries = {};
  final Map<int, CarCatalogStoreEntry<GenerationItem>> generationsEntries = {};

  @override
  bool get supportsGenerations => generationsSupported;

  @override
  Future<CarCatalogStoreEntry<BrandItem>?> loadBrands() async => brandsEntry;

  @override
  Future<bool> saveBrands(List<BrandItem> items) async {
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

BrandCatalog _catalogOf(List<BrandItem> items) => BrandCatalog(
  items: items,
  names: items.map((b) => b.name).toList()..sort(),
  rusByName: const {},
  idByName: {for (final b in items) b.name: b.id},
);

// Порядок бэка нарочно НЕ по популярности: Zotye раньше Lada.
final _zotye = BrandItem(id: 9, name: 'Zotye', nameRus: '');
final _lada = BrandItem(id: 2, name: 'Lada', nameRus: 'Лада');
final _vesta = ModelItem(id: 21, brandId: 2, model: 'Vesta', modelRus: 'Веста');
final _granta = ModelItem(id: 22, brandId: 2, model: 'Granta', modelRus: '');
final _t600 = ModelItem(id: 91, brandId: 9, model: 'T600', modelRus: '');

Map<String, dynamic> _readMeta() {
  final raw = UserSimplePreferences.pref!.getString('car_catalog_sync_meta_v1');
  return raw == null ? const {} : Map<String, dynamic>.from(jsonDecode(raw));
}

void main() {
  late _FakeStore store;
  late CarCatalogRepository repo;
  late CarCatalogSyncService sync;
  late List<Duration> sleeps;
  late List<int> modelsLog;
  late List<int> generationsLog;
  int brandsFetches = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();

    CarCatalogRepository.resetSingletonForTest();
    CarCatalogSyncService.resetSingletonForTest();
    repo = CarCatalogRepository.instance;
    sync = CarCatalogSyncService.instance;

    store = _FakeStore();
    repo.store = store;
    sleeps = [];
    modelsLog = [];
    generationsLog = [];
    brandsFetches = 0;

    repo.brandsFetcher = () async {
      brandsFetches++;
      return _catalogOf([_zotye, _lada]);
    };
    repo.modelsFetcher = (brandId) async {
      modelsLog.add(brandId);
      if (brandId == 2) return [_vesta, _granta];
      if (brandId == 9) return [_t600];
      return <ModelItem>[];
    };
    repo.generationsFetcher = (modelCarId) async {
      generationsLog.add(modelCarId);
      return <GenerationItem>[];
    };

    sync.tokenReader = () async => 'live-token';
    sync.sleeper = (d) async {
      sleeps.add(d);
    };
  });

  tearDown(() {
    CarCatalogRepository.resetSingletonForTest();
    CarCatalogSyncService.resetSingletonForTest();
  });

  test('без токена — no-op', () async {
    sync.tokenReader = () async => null;
    await sync.start();
    expect(brandsFetches, 0);
    expect(modelsLog, isEmpty);
  });

  test('полный ран: фазы, приоритеты, штампы, троттлинг', () async {
    await sync.start();

    expect(brandsFetches, 1);
    // Фаза 1: популярная Lada раньше Zotye, хотя бэк отдал наоборот.
    expect(modelsLog, [2, 9]);
    // Фаза 2: модели Lada первыми, внутри марки Granta популярнее Vesta.
    expect(generationsLog, [22, 21, 91]);

    final meta = _readMeta();
    expect(meta['brandsSyncedAtMs'], greaterThan(0));
    expect(meta['modelsDoneAtMs'], greaterThan(0));
    expect(meta['lastRunAtMs'], greaterThan(0));
    expect(Map<String, dynamic>.from(meta['genIndex'] as Map).keys.toSet(), {
      '21',
      '22',
      '91',
    });

    // Паузы: по одной на каждый сетевой вызов моделей и поколений.
    expect(
      sleeps.where((d) => d == sync.modelsGap).length,
      2,
      reason: 'gap перед каждым вызовом GetModelCar',
    );
    expect(sleeps.where((d) => d == sync.generationsGap).length, 3);
    expect(sync.isRunning, isFalse);
  });

  test('резюм: свежий genIndex не перекачивается', () async {
    await UserSimplePreferences.pref!.setString(
      'car_catalog_sync_meta_v1',
      jsonEncode({
        'schema': 1,
        'genIndex': {'22': DateTime.now().millisecondsSinceEpoch},
      }),
    );
    await sync.start();
    expect(generationsLog, [21, 91], reason: 'Granta уже синхронизирована');
  });

  test(
    'оппортунистический зачёт: скачанное пикером не перекачивается',
    () async {
      // Пикер уже загрузил поколения Vesta (write-through в store).
      store.generationsEntries[21] = CarCatalogStoreEntry(
        items: const [],
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await sync.start();
      expect(generationsLog, [22, 91]);
      final genIndex = Map<String, dynamic>.from(
        _readMeta()['genIndex'] as Map,
      );
      expect(genIndex.keys.toSet(), {
        '21',
        '22',
        '91',
      }, reason: 'зачтённая модель тоже штампуется');
    },
  );

  test('недавно открытые модели качаются первыми', () async {
    await UserSimplePreferences.pref!.setStringList(
      'car_catalog_recent_models_v1',
      ['91'],
    );
    await sync.start();
    expect(generationsLog.first, 91);
  });

  test('429 → slowdown и 30с пауза, ран не падает', () async {
    var first = true;
    repo.modelsFetcher = (brandId) async {
      if (first) {
        first = false;
        throw Exception('HTTP 429 from Storage.GetModelCar');
      }
      modelsLog.add(brandId);
      if (brandId == 2) return [_vesta, _granta];
      return [_t600];
    };

    await sync.start();

    expect(sleeps, contains(const Duration(seconds: 30)));
    expect(
      sleeps,
      contains(sync.modelsGap * 2),
      reason: 'после 429 паузы удваиваются',
    );
    // Упавшая марка пропущена в этом ране → фаза моделей не завершена.
    expect(_readMeta()['modelsDoneAtMs'], anyOf(isNull, 0));
    expect(sync.isRunning, isFalse);
  });

  test('лимит подряд идущих фейлов прерывает ран, прогресс сохранён', () async {
    repo.brandsFetcher = () async => _catalogOf([
      for (var i = 1; i <= 8; i++) BrandItem(id: i, name: 'B$i', nameRus: ''),
    ]);
    var attempts = 0;
    repo.modelsFetcher = (brandId) async {
      attempts++;
      throw Exception('boom');
    };

    await sync.start();

    expect(
      attempts,
      5,
      reason: '5 фейлов подряд → abort, 6-я марка не пробуется',
    );
    expect(generationsLog, isEmpty);
    expect(
      _readMeta()['brandsSyncedAtMs'],
      greaterThan(0),
      reason: 'прогресс фазы 0 переживает abort',
    );
    expect(sync.isRunning, isFalse);
  });

  test('SessionExpiredException прерывает ран сразу', () async {
    var attempts = 0;
    repo.modelsFetcher = (brandId) async {
      attempts++;
      throw const SessionExpiredException();
    };
    await sync.start();
    expect(attempts, 1);
    expect(generationsLog, isEmpty);
    expect(sync.isRunning, isFalse);
  });

  test('web (без персиста поколений): фаза 2 пропускается', () async {
    store.generationsSupported = false;
    await sync.start();
    expect(modelsLog, [2, 9]);
    expect(generationsLog, isEmpty);
    expect(_readMeta()['lastRunAtMs'], greaterThan(0));
  });

  test(
    'stop() посреди рана: остаток не качается, старт заново резюмит',
    () async {
      sync.sleeper = (d) async {
        sleeps.add(d);
        if (sleeps.length == 1) sync.stop();
      };
      await sync.start();
      expect(modelsLog, isEmpty, reason: 'стоп сработал на первой же паузе');

      // Повторный старт продолжает с места остановки.
      sync.sleeper = (d) async {};
      await sync.start();
      expect(modelsLog, [2, 9]);
      expect(generationsLog, [22, 21, 91]);
    },
  );

  test('повторный start() во время рана — no-op', () async {
    final firstGap = Completer<void>();
    var slept = 0;
    sync.sleeper = (d) async {
      slept++;
      if (slept == 1) await firstGap.future;
    };

    final run = sync.start();
    while (slept == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sync.isRunning, isTrue);
    final brandsBefore = brandsFetches;

    await sync.start(); // должен выйти мгновенно
    expect(brandsFetches, brandsBefore);

    firstGap.complete();
    await run;
    expect(sync.isRunning, isFalse);
  });
}

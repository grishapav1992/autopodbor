import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/car_catalog_repository.dart';
import 'package:flutter_application_1/data/services/car_catalog_store.dart';
import 'package:flutter_application_1/data/services/car_catalog_sync_service.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/auto_request_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_car_catalog_store.dart';

// Регрессия бага «офлайн-заявка уходила с пустыми restylings»: раньше
// RemoteCarCatalog офлайн падал на хардкодный 3-марочный список БЕЗ
// restylingId → createRequest слал requestCars:[{restylings: []}].
// Теперь: без кэша — честно пусто (форма показывает баннер и блокирует
// сабмит), с кэшем — полный офлайн-резолв вплоть до restylingId.

final _skoda = BrandItem(id: 1, name: 'Skoda', nameRus: 'Шкода');
final _octavia = ModelItem(id: 11, brandId: 1, model: 'Octavia', modelRus: '');

GenerationItem _octaviaGen() => GenerationItem(
  id: 3,
  modelCarId: 11,
  generation: 4,
  frames: const [],
  restylings: [
    RestylingItem(
      id: 555,
      restyling: 'Рестайлинг',
      yearStart: 2020,
      yearEnd: null,
      frames: [FrameItem(id: 7, frame: 'NX')],
      photos: const [],
    ),
  ],
);

void main() {
  late FakeCarCatalogStore store;
  late CarCatalogRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();

    CarCatalogRepository.resetSingletonForTest();
    CarCatalogSyncService.resetSingletonForTest();
    RemoteCarCatalog.resetForTest();

    repo = CarCatalogRepository.instance;
    store = FakeCarCatalogStore();
    repo.store = store;
    // По умолчанию — «офлайн»: любые сетевые фетчи падают.
    repo.brandsFetcher = () async => throw Exception('offline');
    repo.modelsFetcher = (_) async => throw Exception('offline');
    repo.generationsFetcher = (_) async => throw Exception('offline');
    // Синк в этих тестах не должен ходить в сеть.
    CarCatalogSyncService.instance.tokenReader = () async => null;
  });

  tearDown(() {
    CarCatalogRepository.resetSingletonForTest();
    CarCatalogSyncService.resetSingletonForTest();
    RemoteCarCatalog.resetForTest();
  });

  test(
    'офлайн без кэша: пусто и brandsFailed — хардкодного фолбэка больше нет',
    () async {
      await RemoteCarCatalog.ensureBrands();

      expect(RemoteCarCatalog.brandsFailed, isTrue);
      expect(
        RemoteCarCatalog.makes(),
        isEmpty,
        reason: 'раньше тут всплывали хардкодные Toyota/Ford/Volkswagen',
      );
      expect(RemoteCarCatalog.modelsFor('Toyota'), isEmpty);
      expect(RemoteCarCatalog.restylingsFor('Toyota', 'Camry'), isEmpty);
      expect(
        RemoteCarCatalog.restylingIdFor('Toyota', 'Camry', 'XV70'),
        isNull,
      );
    },
  );

  test('тёплый кэш: полный офлайн-резолв вплоть до restylingId', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    store.brandsEntry = CarCatalogStoreEntry(items: [_skoda], savedAtMs: now);
    store.modelsEntries[1] = CarCatalogStoreEntry(
      items: [_octavia],
      savedAtMs: now,
    );
    store.generationsEntries[11] = CarCatalogStoreEntry(
      items: [_octaviaGen()],
      savedAtMs: now,
    );

    await RemoteCarCatalog.ensureBrands();
    expect(RemoteCarCatalog.brandsFailed, isFalse);
    expect(RemoteCarCatalog.makes(), ['Skoda']);
    expect(RemoteCarCatalog.brandIdByName['Skoda'], 1);

    await RemoteCarCatalog.ensureModels('Skoda');
    expect(RemoteCarCatalog.modelsFor('Skoda'), ['Octavia']);

    await RemoteCarCatalog.ensureRestylings('Skoda', 'Octavia');
    final restylings = RemoteCarCatalog.restylingsFor('Skoda', 'Octavia');
    expect(restylings, ['rest:555']);
    expect(
      RemoteCarCatalog.restylingIdFor('Skoda', 'Octavia', 'rest:555'),
      555,
      reason: 'идентичность авто для createRequest резолвится офлайн',
    );
  });

  test(
    'revision-хук: фоновый синк оживляет фасад после офлайн-старта',
    () async {
      await RemoteCarCatalog.ensureBrands();
      expect(RemoteCarCatalog.brandsFailed, isTrue);

      // Симулируем фоновый синк: репозиторий получил марки (write-through).
      await repo.putBrands([_skoda]);
      // Листенер revision синхронный — фасад уже обновлён.
      expect(RemoteCarCatalog.brandNames, ['Skoda']);
      expect(RemoteCarCatalog.brandsFailed, isFalse);
      expect(RemoteCarCatalog.makes(), ['Skoda']);
    },
  );
}

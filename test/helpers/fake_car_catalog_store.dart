import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/data/services/car_catalog_store.dart';

/// In-memory CarCatalogStore для тестов: записи можно подкладывать заранее
/// (в т.ч. с протухшим savedAtMs), save* считаются.
class FakeCarCatalogStore implements CarCatalogStore {
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

// Web (PWA) реализация CarCatalogStore: SharedPreferences (localStorage).
//
// Персистятся только марки и модели (~сотни КБ суммарно). Поколения на
// web НЕ персистятся: полный набор — мегабайты, а квота localStorage ~5 МБ
// на origin; supportsGenerations=false отключает фазу «поколения» в
// фоновом синке, пикер поколений на web работает как раньше — по сети
// (+ память сессии в репозитории). Квота-ошибки записи глотаются: кэш
// деградирует в network-only, но ничего не ломает.

import 'dart:convert';

import '../preferences/user_preferences.dart';
import '../api/storage_api_models.dart';
import 'car_catalog_store.dart';

CarCatalogStore createPlatformCarCatalogStore() => WebCarCatalogStore();

class WebCarCatalogStore implements CarCatalogStore {
  static const String brandsKey = 'car_catalog_brands_v1';
  static const String modelsKey = 'car_catalog_models_v1';

  @override
  bool get supportsGenerations => false;

  @override
  Future<CarCatalogStoreEntry<BrandItem>?> loadBrands() async {
    final raw = UserSimplePreferences.pref?.getString(brandsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _entryFromMap(decoded, BrandItem.tryFromJson);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> saveBrands(List<BrandItem> items) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return false;
    try {
      return await pref.setString(
        brandsKey,
        jsonEncode({
          'v': 1,
          'savedAtMs': DateTime.now().millisecondsSinceEpoch,
          'items': items.map((b) => b.toJson()).toList(growable: false),
        }),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CarCatalogStoreEntry<ModelItem>?> loadModels(int brandId) async {
    final byBrand = _readModelsMap();
    final entry = byBrand['$brandId'];
    if (entry is! Map) return null;
    return _entryFromMap(entry, ModelItem.tryFromJson);
  }

  @override
  Future<bool> saveModels(int brandId, List<ModelItem> items) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return false;
    final byBrand = _readModelsMap();
    byBrand['$brandId'] = {
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
      'items': items.map((m) => m.toJson()).toList(growable: false),
    };
    try {
      return await pref.setString(
        modelsKey,
        jsonEncode({'v': 1, 'byBrand': byBrand}),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CarCatalogStoreEntry<GenerationItem>?> loadGenerations(
    int modelCarId,
  ) async => null;

  @override
  Future<bool> saveGenerations(
    int modelCarId,
    List<GenerationItem> items,
  ) async => false;

  @override
  Future<int?> generationsSavedAtMs(int modelCarId) async => null;

  Map<String, dynamic> _readModelsMap() {
    final raw = UserSimplePreferences.pref?.getString(modelsKey);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, dynamic>{};
      final byBrand = decoded['byBrand'];
      if (byBrand is! Map) return <String, dynamic>{};
      return Map<String, dynamic>.from(byBrand);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  CarCatalogStoreEntry<T>? _entryFromMap<T>(
    Map<dynamic, dynamic> map,
    T? Function(dynamic) parseItem,
  ) {
    final rawItems = map['items'];
    if (rawItems is! List) return null;
    final savedAtRaw = map['savedAtMs'];
    final savedAtMs = savedAtRaw is num ? savedAtRaw.toInt() : 0;
    final items = <T>[];
    for (final raw in rawItems) {
      final parsed = parseItem(raw);
      if (parsed != null) items.add(parsed);
    }
    return CarCatalogStoreEntry<T>(items: items, savedAtMs: savedAtMs);
  }
}

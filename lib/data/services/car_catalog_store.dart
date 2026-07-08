// Персист офлайн-каталога авто (марки → модели → поколения).
//
// Фасад с conditional import (паттерн vin_ocr_service.dart):
//  - IO (Android/iOS/desktop): файлы в Documents/car_catalog_v1/ —
//    каталог с поколениями весит мегабайты, SharedPreferences для такого
//    не годится (одна XML/plist-простыня целиком в памяти).
//  - Web (PWA): SharedPreferences (localStorage) — только марки и модели;
//    поколения не персистятся из-за квоты ~5 МБ. Это зеркалит принятую
//    политику «тяжёлое на web не персистится» (как медиа отчёта).
//
// Store — тупой слой хранения: никакой сети, TTL-решений и обрезки фото
// (это делает CarCatalogRepository). Ошибки чтения = «нет данных» (null),
// ошибки записи = false; наружу ничего не бросается — битый кэш не имеет
// права ломать пикеры.

import '../api/storage_api_models.dart';
import 'car_catalog_store_io.dart'
    if (dart.library.html) 'car_catalog_store_web.dart'
    as impl;

/// Результат чтения из store: элементы + момент записи (для TTL-решений
/// в репозитории/синке).
class CarCatalogStoreEntry<T> {
  const CarCatalogStoreEntry({required this.items, required this.savedAtMs});

  final List<T> items;
  final int savedAtMs;
}

abstract class CarCatalogStore {
  /// false на web — поколения там живут только в памяти сессии, и фаза
  /// «поколения» фонового синка пропускается целиком.
  bool get supportsGenerations;

  Future<CarCatalogStoreEntry<BrandItem>?> loadBrands();

  /// true — записано; false — не удалось (квота/диск). Порядок [items]
  /// сохраняется как есть: для брендов это порядок бэка (популярность).
  Future<bool> saveBrands(List<BrandItem> items);

  Future<CarCatalogStoreEntry<ModelItem>?> loadModels(int brandId);

  Future<bool> saveModels(int brandId, List<ModelItem> items);

  Future<CarCatalogStoreEntry<GenerationItem>?> loadGenerations(int modelCarId);

  Future<bool> saveGenerations(int modelCarId, List<GenerationItem> items);

  /// Дешёвый штамп записи поколений модели (без парсинга содержимого):
  /// mtime файла на IO, null на web/при отсутствии. Нужен фоновому синку,
  /// чтобы засчитывать оппортунистические загрузки из пикеров и не
  /// перечитывать тысячи файлов при планировании фазы «поколения».
  Future<int?> generationsSavedAtMs(int modelCarId);
}

CarCatalogStore createCarCatalogStore() => impl.createPlatformCarCatalogStore();

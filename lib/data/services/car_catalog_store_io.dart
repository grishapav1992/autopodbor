// Файловая реализация CarCatalogStore (Android/iOS/desktop).
//
// Раскладка: Documents/car_catalog_v1/
//   brands.json                    {"v":1,"savedAtMs":…,"items":[BrandItem…]}
//   models_<brandId>.json          {"v":1,"savedAtMs":…,"items":[ModelItem…]}
//   generations_<modelCarId>.json  {"v":1,"savedAtMs":…,"items":[GenerationItem…]}
//
// Запись атомарная (tmp + rename): kill приложения посреди записи может
// потерять максимум одну сущность и никогда не портит уже записанную.
// Битый файл при чтении удаляется и считается отсутствующим (перекачаем).
// Смена схемы = новый суффикс каталога (_v2, …); старые версии сметаются
// при первом обращении.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:path_provider/path_provider.dart';

import '../api/storage_api_models.dart';
import 'car_catalog_store.dart';

CarCatalogStore createPlatformCarCatalogStore() => IoCarCatalogStore();

/// Порог, с которого JSON-декод уезжает в изолят — те же 16 КБ, что и в
/// SparkJoyStorage: файл поколений крупной модели может быть десятки КБ,
/// и парсить его на главном изоляте в момент открытия пикера не хочется.
const int _jsonIsolateThresholdBytes = 16 * 1024;

dynamic _decodeJsonString(String source) => jsonDecode(source);

class IoCarCatalogStore implements CarCatalogStore {
  IoCarCatalogStore({Directory? rootOverride}) : _rootOverride = rootOverride;

  static const String dirName = 'car_catalog_v1';

  /// Тестовый шов: подложить корень вместо path_provider.
  final Directory? _rootOverride;

  Future<Directory>? _rootFuture;

  @override
  bool get supportsGenerations => true;

  Future<Directory> _root() => _rootFuture ??= _prepareRoot();

  Future<Directory> _prepareRoot() async {
    final docs = _rootOverride ?? await getApplicationDocumentsDirectory();
    // Снос кэшей прежних схем (car_catalog_v0/_v2/…) — один раз за сессию.
    try {
      await for (final entity in docs.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = entity.uri.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
        if (name != dirName && RegExp(r'^car_catalog_v\d+$').hasMatch(name)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    final dir = Directory('${docs.path}/$dirName');
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async {
    final dir = await _root();
    return File('${dir.path}/$name');
  }

  Future<CarCatalogStoreEntry<T>?> _load<T>(
    String fileName,
    T? Function(dynamic) parseItem,
  ) async {
    File? file;
    try {
      file = await _file(fileName);
      if (!await file.exists()) return null;
      final source = await file.readAsString();
      if (source.trim().isEmpty) return null;
      final decoded = source.length > _jsonIsolateThresholdBytes
          ? await compute(_decodeJsonString, source)
          : _decodeJsonString(source);
      if (decoded is! Map) throw const FormatException('not a map');
      final rawItems = decoded['items'];
      if (rawItems is! List) throw const FormatException('items missing');
      final savedAtRaw = decoded['savedAtMs'];
      final savedAtMs = savedAtRaw is num ? savedAtRaw.toInt() : 0;
      final items = <T>[];
      for (final raw in rawItems) {
        final parsed = parseItem(raw);
        if (parsed != null) items.add(parsed);
      }
      return CarCatalogStoreEntry<T>(items: items, savedAtMs: savedAtMs);
    } catch (_) {
      // Битый/недописанный файл → удалить и считать отсутствующим.
      try {
        await file?.delete();
      } catch (_) {}
      return null;
    }
  }

  Future<bool> _save(String fileName, List<Map<String, dynamic>> items) async {
    try {
      final file = await _file(fileName);
      final tmp = File('${file.path}.tmp');
      final payload = jsonEncode({
        'v': 1,
        'savedAtMs': DateTime.now().millisecondsSinceEpoch,
        'items': items,
      });
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CarCatalogStoreEntry<BrandItem>?> loadBrands() =>
      _load('brands.json', BrandItem.tryFromJson);

  @override
  Future<bool> saveBrands(List<BrandItem> items) => _save(
    'brands.json',
    items.map((b) => b.toJson()).toList(growable: false),
  );

  @override
  Future<CarCatalogStoreEntry<ModelItem>?> loadModels(int brandId) =>
      _load('models_$brandId.json', ModelItem.tryFromJson);

  @override
  Future<bool> saveModels(int brandId, List<ModelItem> items) => _save(
    'models_$brandId.json',
    items.map((m) => m.toJson()).toList(growable: false),
  );

  @override
  Future<CarCatalogStoreEntry<GenerationItem>?> loadGenerations(
    int modelCarId,
  ) => _load('generations_$modelCarId.json', GenerationItem.tryFromJson);

  @override
  Future<bool> saveGenerations(int modelCarId, List<GenerationItem> items) =>
      _save(
        'generations_$modelCarId.json',
        items.map((g) => g.toJson()).toList(growable: false),
      );
}

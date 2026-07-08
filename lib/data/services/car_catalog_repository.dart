// Офлайн-репозиторий каталога авто (марка → модель → поколение/рестайлинг/
// кузов). Единая точка каталога для всех трёх поверхностей выбора авто
// (отчёт spark_joy, заявка компании, клиентская заявка) + для резолва
// «имя → id» у VIN-конвертера, скана СТС и выгрузки отчёта.
//
// Контракт чтения (cache-first, stale-while-revalidate):
//  - память → store → сеть; сеть всегда write-through в store;
//  - если кэш есть, но старше [kCarCatalogTtl] — отдаём кэш сразу и тихо
//    обновляем в фоне (bump [revision], UI перерисуется);
//  - throw только когда кэша нет совсем И сеть упала — это состояние
//    «каталог ещё не загружен», пикеры показывают empty-state.
//
// Форма класса — по образцу CityRepository: синглтон, идемпотентный init(),
// isReady, @visibleForTesting-швы. Персист — CarCatalogStore (файлы на
// mobile, prefs на web), сеть — StorageApi.fetchBrandCatalog/fetchModels/
// fetchGenerations (подменяемые в тестах фетчеры).

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../api/storage_api.dart';
import '../preferences/user_preferences.dart';
import 'car_catalog_photo_ranking.dart';
import 'car_catalog_store.dart';

/// TTL кэша каталога. Бэк не отдаёт updated_at/version (проверено по DTO),
/// так что инвалидация только по времени. Каталог меняется редко (новые
/// модели — раз в месяцы), 7 дней — компромисс между свежестью и трафиком
/// полного обхода (~1–2.5 тыс. RPC). Просроченный кэш продолжает работать
/// офлайн — TTL лишь планирует фоновое обновление.
const Duration kCarCatalogTtl = Duration(days: 7);

/// Результат строгого резолва «имя марки/модели → каталог».
/// full=true — найдены и марка, и модель.
typedef CatalogCarMatch = ({BrandItem brand, ModelItem? model, bool full});

class CarCatalogRepository {
  CarCatalogRepository._();

  static CarCatalogRepository instance = CarCatalogRepository._();

  /// Тест-шов: полный сброс состояния (включая подменённые фетчеры/store).
  @visibleForTesting
  static void resetSingletonForTest() {
    instance = CarCatalogRepository._();
  }

  /// Инкрементится при каждой мутации кэша (сеть/фоновое обновление).
  /// UI-фасады (например `RemoteCarCatalog.stamp`) подписываются и
  /// перерисовывают списки, когда фоновый рефреш принёс свежие данные.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  // ── Тестовые швы ──────────────────────────────────────────────────────

  @visibleForTesting
  CarCatalogStore store = createCarCatalogStore();

  @visibleForTesting
  Future<BrandCatalog> Function() brandsFetcher = StorageApi.fetchBrandCatalog;

  @visibleForTesting
  Future<List<ModelItem>> Function(int brandId) modelsFetcher =
      _defaultModelsFetcher;

  @visibleForTesting
  Future<List<GenerationItem>> Function(int modelCarId) generationsFetcher =
      _defaultGenerationsFetcher;

  static Future<List<ModelItem>> _defaultModelsFetcher(int brandId) =>
      StorageApi.fetchModels(brandId: brandId);

  static Future<List<GenerationItem>> _defaultGenerationsFetcher(
    int modelCarId,
  ) => StorageApi.fetchGenerations(modelCarId: modelCarId);

  // ── Состояние ─────────────────────────────────────────────────────────

  List<BrandItem>? _brands;
  int _brandsSavedAtMs = 0;
  List<String>? _brandNamesSortedMemo;
  Map<String, String>? _brandRusByNameMemo;
  Map<String, int>? _brandIdByNameMemo;

  final Map<int, List<ModelItem>> _modelsByBrandId = {};
  final Map<int, int> _modelsSavedAtMs = {};

  /// Поколения — LRU-ограниченный мемо: полный набор всех моделей в RAM
  /// не нужен (persist есть в store), держим последние открытые.
  static const int _generationsMemoCap = 32;
  final LinkedHashMap<int, List<GenerationItem>> _generationsByModelId =
      LinkedHashMap();
  final Map<int, int> _generationsSavedAtMs = {};

  bool _storeChecked = false;
  Future<void>? _initFuture;
  Future<List<BrandItem>>? _brandsLoading;
  final Map<int, Future<List<ModelItem>>> _modelsLoading = {};
  final Map<int, Future<List<GenerationItem>>> _generationsLoading = {};

  bool _brandsBgRefresh = false;
  final Set<int> _modelsBgRefresh = {};
  final Set<int> _generationsBgRefresh = {};

  /// true, когда список марок доступен синхронно (из store или сети).
  bool get isReady => _brands != null && _brands!.isNotEmpty;

  // ── Инициализация ─────────────────────────────────────────────────────

  /// Подтягивает марки из персиста в память. Идемпотентно, конкурентные
  /// вызовы делят один Future. Не бросает: битый персист = пустой старт
  /// (марки придут из сети при первом getBrands()).
  Future<void> init() {
    if (_storeChecked || _brands != null) return Future.value();
    return _initFuture ??= _runInit();
  }

  Future<void> _runInit() async {
    try {
      final entry = await store.loadBrands();
      if (entry != null && entry.items.isNotEmpty) {
        _brands = List<BrandItem>.unmodifiable(entry.items);
        _brandsSavedAtMs = entry.savedAtMs;
        _invalidateBrandMemos();
        revision.value++;
      }
    } catch (_) {
      // store не бросает по контракту, но страхуемся: init обязан завершаться.
    } finally {
      _storeChecked = true;
      _initFuture = null;
    }
  }

  // ── Чтение (cache-first) ──────────────────────────────────────────────

  /// Марки в порядке бэка (популярность). См. контракт чтения в шапке.
  Future<List<BrandItem>> getBrands() async {
    await init();
    final cached = _brands;
    if (cached != null && cached.isNotEmpty) {
      if (_isStale(_brandsSavedAtMs)) _refreshBrandsQuietly();
      return cached;
    }
    return _brandsLoading ??= _fetchBrandsFromNetwork().whenComplete(() {
      _brandsLoading = null;
    });
  }

  /// Модели марки. Пустой список — валидный кэш (марка без моделей),
  /// иначе каждый повторный вход в пикер дёргал бы сеть заново.
  Future<List<ModelItem>> getModels(int brandId) {
    final memo = _modelsByBrandId[brandId];
    if (memo != null) {
      if (_isStale(_modelsSavedAtMs[brandId] ?? 0)) {
        _refreshModelsQuietly(brandId);
      }
      return Future.value(memo);
    }
    return _modelsLoading.putIfAbsent(
      brandId,
      () => _loadModels(brandId).whenComplete(() {
        _modelsLoading.remove(brandId);
      }),
    );
  }

  /// Поколения модели (внутри — рестайлинги, кузова, фото). Пустой список —
  /// валидный кэш: у многих моделей поколений в каталоге нет.
  Future<List<GenerationItem>> getGenerations(int modelCarId) {
    _noteRecentModel(modelCarId);
    final memo = _generationsByModelId.remove(modelCarId);
    if (memo != null) {
      _generationsByModelId[modelCarId] = memo; // LRU-touch
      if (_isStale(_generationsSavedAtMs[modelCarId] ?? 0)) {
        _refreshGenerationsQuietly(modelCarId);
      }
      return Future.value(memo);
    }
    return _generationsLoading.putIfAbsent(
      modelCarId,
      () => _loadGenerations(modelCarId).whenComplete(() {
        _generationsLoading.remove(modelCarId);
      }),
    );
  }

  Future<List<BrandItem>> _fetchBrandsFromNetwork() async {
    final catalog = await brandsFetcher();
    if (catalog.items.isEmpty) {
      // Пустой GetBrand — аномалия бэка; кэш (если есть) не затираем.
      final cached = _brands;
      if (cached != null && cached.isNotEmpty) return cached;
      throw StateError('car_catalog: Storage.GetBrand вернул пустой список');
    }
    await putBrands(catalog.items);
    return _brands!;
  }

  Future<List<ModelItem>> _loadModels(int brandId) async {
    try {
      final entry = await store.loadModels(brandId);
      if (entry != null) {
        _modelsByBrandId[brandId] = List<ModelItem>.unmodifiable(entry.items);
        _modelsSavedAtMs[brandId] = entry.savedAtMs;
        if (_isStale(entry.savedAtMs)) _refreshModelsQuietly(brandId);
        return _modelsByBrandId[brandId]!;
      }
    } catch (_) {}
    final items = await modelsFetcher(brandId);
    await putModels(brandId, items);
    return _modelsByBrandId[brandId] ?? const <ModelItem>[];
  }

  Future<List<GenerationItem>> _loadGenerations(int modelCarId) async {
    try {
      final entry = await store.loadGenerations(modelCarId);
      if (entry != null) {
        _putGenerationsMemo(modelCarId, entry.items, entry.savedAtMs);
        if (_isStale(entry.savedAtMs)) _refreshGenerationsQuietly(modelCarId);
        return _generationsByModelId[modelCarId]!;
      }
    } catch (_) {}
    final items = await generationsFetcher(modelCarId);
    await putGenerations(modelCarId, items);
    return _generationsByModelId[modelCarId] ?? const <GenerationItem>[];
  }

  // ── Принудительное обновление (фоновый синк) ──────────────────────────

  /// Сеть → write-through, ошибки пробрасываются (throttle/backoff — на
  /// стороне CarCatalogSyncService).
  Future<void> refreshBrands() async {
    await (_brandsLoading ??= _fetchBrandsFromNetwork().whenComplete(() {
      _brandsLoading = null;
    }));
  }

  Future<void> refreshModels(int brandId) async {
    final items = await modelsFetcher(brandId);
    await putModels(brandId, items);
  }

  Future<void> refreshGenerations(int modelCarId) async {
    final items = await generationsFetcher(modelCarId);
    await putGenerations(modelCarId, items);
  }

  /// Персистятся ли поколения на этой платформе (false на web) — фоновый
  /// синк без персиста фазу «поколения» пропускает.
  bool get supportsGenerations => store.supportsGenerations;

  /// Штамп персиста поколений модели (mtime файла) — для планировщика
  /// синка; null = не записаны/web.
  Future<int?> generationsPersistStampMs(int modelCarId) =>
      store.generationsSavedAtMs(modelCarId);

  /// Свежи ли персистнутые модели марки (для планирования фазы 1 синка).
  /// Заодно прогревает мемо, чтобы синк не перечитывал файл.
  Future<bool> hasFreshModels(int brandId) async {
    final memoAt = _modelsSavedAtMs[brandId];
    if (memoAt != null && _modelsByBrandId.containsKey(brandId)) {
      return !_isStale(memoAt);
    }
    try {
      final entry = await store.loadModels(brandId);
      if (entry == null) return false;
      _modelsByBrandId[brandId] = List<ModelItem>.unmodifiable(entry.items);
      _modelsSavedAtMs[brandId] = entry.savedAtMs;
      return !_isStale(entry.savedAtMs);
    } catch (_) {
      return false;
    }
  }

  // ── Запись (write-through) ────────────────────────────────────────────

  Future<void> putBrands(List<BrandItem> items) async {
    if (items.isEmpty) return;
    _brands = List<BrandItem>.unmodifiable(items);
    _brandsSavedAtMs = DateTime.now().millisecondsSinceEpoch;
    _invalidateBrandMemos();
    revision.value++;
    await store.saveBrands(items);
  }

  Future<void> putModels(int brandId, List<ModelItem> items) async {
    _modelsByBrandId[brandId] = List<ModelItem>.unmodifiable(items);
    _modelsSavedAtMs[brandId] = DateTime.now().millisecondsSinceEpoch;
    revision.value++;
    await store.saveModels(brandId, items);
  }

  /// Фото рестайлингов обрезаются до лучших [kCarCatalogMaxPhotosPerRestyling]
  /// — полный список раздувал бы файловый кэш в разы без пользы для UI.
  Future<void> putGenerations(
    int modelCarId,
    List<GenerationItem> items,
  ) async {
    final trimmed = items
        .map(carCatalogTrimGenerationPhotos)
        .toList(growable: false);
    _putGenerationsMemo(
      modelCarId,
      trimmed,
      DateTime.now().millisecondsSinceEpoch,
    );
    revision.value++;
    await store.saveGenerations(modelCarId, trimmed);
  }

  void _putGenerationsMemo(
    int modelCarId,
    List<GenerationItem> items,
    int savedAtMs,
  ) {
    _generationsByModelId.remove(modelCarId);
    _generationsByModelId[modelCarId] = List<GenerationItem>.unmodifiable(
      items,
    );
    _generationsSavedAtMs[modelCarId] = savedAtMs;
    while (_generationsByModelId.length > _generationsMemoCap) {
      final oldest = _generationsByModelId.keys.first;
      _generationsByModelId.remove(oldest);
      _generationsSavedAtMs.remove(oldest);
    }
  }

  // ── Синхронные выборки для пикеров (после isReady) ────────────────────

  /// Поиск марок по подстроке (name/nameRus, регистронезависимо, ё→е).
  /// Пустой запрос — все марки в порядке бэка. startsWith-совпадения выше
  /// contains, внутри ранга порядок бэка сохраняется.
  List<BrandItem> searchBrands(String query, {int limit = 200}) {
    final brands = _brands ?? const <BrandItem>[];
    final q = _fold(query);
    if (q.isEmpty) return brands.take(limit).toList(growable: false);
    final starts = <BrandItem>[];
    final contains = <BrandItem>[];
    for (final b in brands) {
      final name = _fold(b.name);
      final rus = _fold(b.nameRus);
      if (name.startsWith(q) || rus.startsWith(q)) {
        starts.add(b);
      } else if (name.contains(q) || rus.contains(q)) {
        contains.add(b);
      }
      if (starts.length >= limit) break;
    }
    return [...starts, ...contains].take(limit).toList(growable: false);
  }

  /// Поиск моделей марки по уже загруженному кэшу ([getModels] должен
  /// отработать раньше); без кэша — пусто.
  List<ModelItem> searchModels(int brandId, String query, {int limit = 200}) {
    final models = _modelsByBrandId[brandId] ?? const <ModelItem>[];
    final q = _fold(query);
    if (q.isEmpty) return models.take(limit).toList(growable: false);
    final starts = <ModelItem>[];
    final contains = <ModelItem>[];
    for (final m in models) {
      final name = _fold(m.model);
      final rus = _fold(m.modelRus);
      if (name.startsWith(q) || rus.startsWith(q)) {
        starts.add(m);
      } else if (name.contains(q) || rus.contains(q)) {
        contains.add(m);
      }
      if (starts.length >= limit) break;
    }
    return [...starts, ...contains].take(limit).toList(growable: false);
  }

  /// Имена марок по алфавиту — то, что раньше давал `BrandCatalog.names`
  /// (его сортировку сохраняем для `RemoteCarCatalog`/фильтров).
  List<String> get brandNamesSorted => _brandNamesSortedMemo ??= () {
    final names = <String>{};
    for (final b in _brands ?? const <BrandItem>[]) {
      if (b.name.isNotEmpty) names.add(b.name);
    }
    return names.toList()..sort();
  }();

  Map<String, String> get brandRusByName => _brandRusByNameMemo ??= () {
    final map = <String, String>{};
    for (final b in _brands ?? const <BrandItem>[]) {
      if (b.name.isNotEmpty && b.nameRus.isNotEmpty) map[b.name] = b.nameRus;
    }
    return map;
  }();

  Map<String, int> get brandIdByName => _brandIdByNameMemo ??= () {
    final map = <String, int>{};
    for (final b in _brands ?? const <BrandItem>[]) {
      if (b.name.isNotEmpty) map[b.name] = b.id;
    }
    return map;
  }();

  // ── Строгий резолв «имя → каталог» ────────────────────────────────────

  /// Матчит марку/модель (как их вернул конвертер/скан/черновик) с
  /// каталогом. null — марки в каталоге нет ЛИБО каталог недоступен
  /// (кэш пуст + офлайн): в обоих случаях привязать авто нечем и вызывающий
  /// оставляет выбор за пользователем. Сетевые ошибки внутрь не пробрасываем
  /// — резолв фоновый и не имеет права ронять UI.
  Future<CatalogCarMatch?> resolveCar(String brand, String model) async {
    if (brand.trim().isEmpty) return null;
    List<BrandItem> brands;
    try {
      brands = await getBrands();
    } catch (_) {
      return null;
    }
    final qBrand = _fold(brand);
    BrandItem? matchedBrand;
    for (final b in brands) {
      if (_fold(b.name) == qBrand || _fold(b.nameRus) == qBrand) {
        matchedBrand = b;
        break;
      }
    }
    if (matchedBrand == null) return null;
    if (model.trim().isEmpty) {
      return (brand: matchedBrand, model: null, full: false);
    }
    try {
      final models = await getModels(matchedBrand.id);
      final qModel = _fold(model);
      for (final m in models) {
        if (_fold(m.model) == qModel || _fold(m.modelRus) == qModel) {
          return (brand: matchedBrand, model: m, full: true);
        }
      }
    } catch (_) {
      // модели недоступны → частичный матч (как раньше при падении GetModelCar)
    }
    return (brand: matchedBrand, model: null, full: false);
  }

  // ── «Недавние модели» для приоритета фонового синка ───────────────────

  static const String _recentModelsKey = 'car_catalog_recent_models_v1';
  static const int _recentModelsCap = 50;

  /// Модели, чьи поколения пользователь реально открывал — синк качает их
  /// первыми. Best-effort: без prefs просто не записывается.
  Future<List<int>> recentModelIds() async {
    final raw =
        UserSimplePreferences.pref?.getStringList(_recentModelsKey) ??
        const <String>[];
    return raw
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toList(growable: false);
  }

  void _noteRecentModel(int modelCarId) {
    if (modelCarId <= 0) return;
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    final list = pref.getStringList(_recentModelsKey) ?? <String>[];
    final id = '$modelCarId';
    if (list.isNotEmpty && list.first == id) return;
    list.remove(id);
    list.insert(0, id);
    while (list.length > _recentModelsCap) {
      list.removeLast();
    }
    unawaited(pref.setStringList(_recentModelsKey, list));
  }

  // ── Служебное ─────────────────────────────────────────────────────────

  bool _isStale(int savedAtMs) {
    if (savedAtMs <= 0) return true;
    return DateTime.now().millisecondsSinceEpoch - savedAtMs >
        kCarCatalogTtl.inMilliseconds;
  }

  void _invalidateBrandMemos() {
    _brandNamesSortedMemo = null;
    _brandRusByNameMemo = null;
    _brandIdByNameMemo = null;
  }

  void _refreshBrandsQuietly() {
    if (_brandsBgRefresh) return;
    _brandsBgRefresh = true;
    unawaited(
      refreshBrands()
          .catchError((_) {})
          .whenComplete(() => _brandsBgRefresh = false),
    );
  }

  void _refreshModelsQuietly(int brandId) {
    if (!_modelsBgRefresh.add(brandId)) return;
    unawaited(
      refreshModels(
        brandId,
      ).catchError((_) {}).whenComplete(() => _modelsBgRefresh.remove(brandId)),
    );
  }

  void _refreshGenerationsQuietly(int modelCarId) {
    if (!_generationsBgRefresh.add(modelCarId)) return;
    unawaited(
      refreshGenerations(modelCarId)
          .catchError((_) {})
          .whenComplete(() => _generationsBgRefresh.remove(modelCarId)),
    );
  }

  static String _fold(String s) => s.trim().toLowerCase().replaceAll('ё', 'е');
}

// Фоновая закачка каталога авто в офлайн-кэш (CarCatalogRepository).
//
// Фазы:
//   0. Марки — 1 вызов Storage.GetBrand (если протухли).
//   1. Модели — по вызову Storage.GetModelCar на марку (~90 шт.),
//      популярные марки (kPopularMakesRu) первыми, пауза [modelsGap].
//   2. Поколения — медленный трикл Storage.GetModelGeneration по모델ям
//      (тысячи вызовов), пауза [generationsGap]; только на платформах с
//      персистом поколений (не web). Резюмится между запусками по
//      genIndex в prefs; порядок: недавно открытые модели → модели
//      популярных марок (внутри — популярные модели первыми) → остальные.
//
// Троттлинг обязателен: nginx перед бэком режет ~20 r/s с IP (HTTP 429).
// Паузы 400мс/1200мс держат синк на порядок ниже лимита и оставляют
// запас пользовательским запросам. На 429 — slowdown ×2 (до ×8) + сон;
// на прочие ошибки — экспоненциальный backoff; 5 фейлов подряд — ран
// прерывается (прогресс уже в персисте, следующий start() продолжит).
//
// Запускается ТОЛЬКО с живым токеном (методы каталога — auth-only):
// success-path SparkJoyStorage.syncRoleFromServer() + страховочные кики
// с экранов выбора авто. Останавливается на logout и смерти сессии.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/constants/popular_cars_ru.dart';
import '../api/storage_api.dart';
import '../preferences/user_preferences.dart';
import 'car_catalog_repository.dart';

/// Прерывание рана: сессия умерла / лимит фейлов / stop(). Прогресс
/// персистится по ходу, так что просто выходим.
class _CarCatalogSyncAborted implements Exception {
  const _CarCatalogSyncAborted(this.reason);
  final String reason;

  @override
  String toString() => 'CarCatalogSync aborted: $reason';
}

class CarCatalogSyncService {
  CarCatalogSyncService._();

  static CarCatalogSyncService instance = CarCatalogSyncService._();

  @visibleForTesting
  static void resetSingletonForTest() {
    instance = CarCatalogSyncService._();
  }

  static const String _metaKey = 'car_catalog_sync_meta_v1';
  static const int _maxConsecutiveFailures = 5;
  static const int _metaFlushEvery = 10;

  // ── Тестовые швы ──────────────────────────────────────────────────────

  /// Пауза между вызовами моделей (~2.5 r/s с запасом до nginx-лимита).
  @visibleForTesting
  Duration modelsGap = const Duration(milliseconds: 400);

  /// Пауза трикла поколений (<1 r/s — фаза длинная, спешить некуда).
  @visibleForTesting
  Duration generationsGap = const Duration(milliseconds: 1200);

  @visibleForTesting
  Future<void> Function(Duration) sleeper = _defaultSleeper;

  @visibleForTesting
  Future<String?> Function() tokenReader = UserSimplePreferences.getAccessToken;

  static Future<void> _defaultSleeper(Duration d) => Future<void>.delayed(d);

  // ── Состояние рана ────────────────────────────────────────────────────

  bool _running = false;
  bool _stopRequested = false;
  int _consecutiveFailures = 0;
  int _slowdown = 1;

  bool get isRunning => _running;

  /// Идемпотентный пинок синка. No-op: уже бежит / нет токена (не залогинен)
  /// / всё свежее. Ошибки внутри не выпускает — это фоновая задача.
  Future<void> start() async {
    if (_running) return;
    String? token;
    try {
      token = await tokenReader();
    } catch (_) {
      return;
    }
    if (token == null || token.trim().isEmpty) return;

    _running = true;
    _stopRequested = false;
    _consecutiveFailures = 0;
    _slowdown = 1;
    try {
      await _run();
    } on _CarCatalogSyncAborted catch (e) {
      if (kDebugMode) debugPrint('[car_catalog_sync] $e');
    } catch (e) {
      if (kDebugMode) debugPrint('[car_catalog_sync] run failed: $e');
    } finally {
      _running = false;
    }
  }

  /// Прервать текущий ран (logout / смерть сессии). Прогресс сохранён,
  /// следующий start() продолжит с места остановки.
  void stop() {
    _stopRequested = true;
  }

  // ── Основной цикл ─────────────────────────────────────────────────────

  Future<void> _run() async {
    final repo = CarCatalogRepository.instance;
    await repo.init();
    final meta = await _loadMeta();

    // Фаза 0: марки.
    if (!repo.isReady || _isStale(meta.brandsSyncedAtMs)) {
      final ok = await _guarded(() => repo.refreshBrands());
      if (ok) {
        meta.brandsSyncedAtMs = _nowMs();
        await _saveMeta(meta);
      }
    }
    final brands = await repo.getBrands();
    final orderedBrands = _popularBrandsFirst(brands);

    // Фаза 1: модели по маркам.
    var modelsPhaseComplete = true;
    for (final brand in orderedBrands) {
      _checkStop();
      if (await repo.hasFreshModels(brand.id)) continue;
      await sleeper(modelsGap * _slowdown);
      _checkStop();
      final ok = await _guarded(() => repo.refreshModels(brand.id));
      if (!ok) modelsPhaseComplete = false;
    }
    if (modelsPhaseComplete) {
      meta.modelsDoneAtMs = _nowMs();
    }
    await _saveMeta(meta);

    // Фаза 2: поколения (только где есть персист — на web пропускаем).
    if (repo.supportsGenerations) {
      await _syncGenerations(repo, orderedBrands, meta);
    }

    meta.lastRunAtMs = _nowMs();
    await _saveMeta(meta);
  }

  Future<void> _syncGenerations(
    CarCatalogRepository repo,
    List<BrandItem> orderedBrands,
    _SyncMeta meta,
  ) async {
    // Модели уже в памяти после фазы 1 (hasFreshModels/refreshModels греют
    // мемо); сетевых вызовов этот сбор не делает.
    final modelsByBrand = <int, List<ModelItem>>{};
    for (final brand in orderedBrands) {
      _checkStop();
      try {
        modelsByBrand[brand.id] = await repo.getModels(brand.id);
      } catch (_) {
        // марка без моделей в этом ране — догоним в следующем
      }
    }

    final queue = await _generationQueue(repo, orderedBrands, modelsByBrand);
    // Мусор из genIndex (модели, исчезнувшие из каталога) не копим — но
    // чистим только когда модели собрались для ВСЕХ марок: иначе временно
    // недоступная марка стёрла бы валидные штампы своих моделей.
    if (orderedBrands.every((b) => modelsByBrand.containsKey(b.id))) {
      final knownIds = queue.map((m) => m.id).toSet();
      meta.genIndex.removeWhere((id, _) => !knownIds.contains(id));
    }

    var sinceFlush = 0;
    for (final model in queue) {
      _checkStop();
      final stamped = meta.genIndex[model.id];
      if (stamped != null && !_isStale(stamped)) continue;

      // Оппортунистический зачёт: пикер уже скачал поколения этой модели
      // (write-through в store) — сеть не нужна, просто штампуем.
      final persisted = await repo.generationsPersistStampMs(model.id);
      if (persisted != null && !_isStale(persisted)) {
        meta.genIndex[model.id] = persisted;
        if (++sinceFlush >= _metaFlushEvery) {
          await _saveMeta(meta);
          sinceFlush = 0;
        }
        continue;
      }

      await sleeper(generationsGap * _slowdown);
      _checkStop();
      final ok = await _guarded(() => repo.refreshGenerations(model.id));
      if (ok) {
        meta.genIndex[model.id] = _nowMs();
        if (++sinceFlush >= _metaFlushEvery) {
          await _saveMeta(meta);
          sinceFlush = 0;
        }
      }
    }
    await _saveMeta(meta);
  }

  /// Очередь фазы 2: недавно открытые → модели популярных марок (внутри
  /// марки — популярные модели первыми) → остальные в порядке марок.
  Future<List<ModelItem>> _generationQueue(
    CarCatalogRepository repo,
    List<BrandItem> orderedBrands,
    Map<int, List<ModelItem>> modelsByBrand,
  ) async {
    final byId = <int, ModelItem>{};
    final queue = <ModelItem>[];
    final queued = <int>{};

    void enqueue(ModelItem model) {
      if (queued.add(model.id)) queue.add(model);
    }

    for (final brand in orderedBrands) {
      for (final model in modelsByBrand[brand.id] ?? const <ModelItem>[]) {
        byId[model.id] = model;
      }
    }

    for (final id in await repo.recentModelIds()) {
      final model = byId[id];
      if (model != null) enqueue(model);
    }

    final brandNameById = {for (final b in orderedBrands) b.id: b.name};
    for (final brand in orderedBrands) {
      final models = List<ModelItem>.from(
        modelsByBrand[brand.id] ?? const <ModelItem>[],
      );
      final brandName = brandNameById[brand.id] ?? '';
      models.sort(
        (a, b) => compareModelsByPopularity(brandName, a.model, b.model),
      );
      models.forEach(enqueue);
    }
    return queue;
  }

  List<BrandItem> _popularBrandsFirst(List<BrandItem> brands) {
    String fold(String s) => s.trim().toLowerCase();
    final popularRank = <String, int>{
      for (var i = 0; i < kPopularMakesRu.length; i++)
        fold(kPopularMakesRu[i]): i,
    };
    final popular = <BrandItem>[];
    final rest = <BrandItem>[];
    for (final brand in brands) {
      if (popularRank.containsKey(fold(brand.name)) ||
          popularRank.containsKey(fold(brand.nameRus))) {
        popular.add(brand);
      } else {
        rest.add(brand);
      }
    }
    popular.sort((a, b) {
      final ra = popularRank[fold(a.name)] ?? popularRank[fold(a.nameRus)]!;
      final rb = popularRank[fold(b.name)] ?? popularRank[fold(b.nameRus)]!;
      return ra.compareTo(rb);
    });
    return [...popular, ...rest];
  }

  // ── Ошибки / троттлинг ────────────────────────────────────────────────

  /// true — вызов прошёл; false — упал (item пропущен, догоним в следующем
  /// ране). Бросает [_CarCatalogSyncAborted] на смерти сессии и лимите
  /// подряд идущих фейлов.
  Future<bool> _guarded(Future<void> Function() fn) async {
    try {
      await fn();
      _consecutiveFailures = 0;
      return true;
    } on SessionExpiredException {
      stop();
      throw const _CarCatalogSyncAborted('session expired');
    } catch (e) {
      _consecutiveFailures++;
      if ('$e'.contains('HTTP 429')) {
        // Уперлись в nginx-лимит: замедляемся и пережидаем окно.
        // Детекция строковая — _postRpc кидает нетипизированный
        // Exception('HTTP 429 from …'); при смене формата сообщения
        // деградирует до обычного backoff ниже, не ломаясь.
        _slowdown = math.min(_slowdown * 2, 8);
        await sleeper(const Duration(seconds: 30));
      } else {
        final backoff = math.min(
          5 * math.pow(2, _consecutiveFailures - 1).toInt(),
          300,
        );
        await sleeper(Duration(seconds: backoff));
      }
      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        throw const _CarCatalogSyncAborted('too many consecutive failures');
      }
      return false;
    }
  }

  void _checkStop() {
    if (_stopRequested) {
      throw const _CarCatalogSyncAborted('stop requested');
    }
  }

  // ── Мета (prefs) ──────────────────────────────────────────────────────

  Future<_SyncMeta> _loadMeta() async {
    final raw = UserSimplePreferences.pref?.getString(_metaKey);
    return _SyncMeta.parse(raw);
  }

  Future<void> _saveMeta(_SyncMeta meta) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    try {
      await pref.setString(_metaKey, meta.encode());
    } catch (_) {}
  }

  bool _isStale(int savedAtMs) {
    if (savedAtMs <= 0) return true;
    return _nowMs() - savedAtMs > kCarCatalogTtl.inMilliseconds;
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}

class _SyncMeta {
  _SyncMeta({
    this.brandsSyncedAtMs = 0,
    this.modelsDoneAtMs = 0,
    this.lastRunAtMs = 0,
    Map<int, int>? genIndex,
  }) : genIndex = genIndex ?? {};

  int brandsSyncedAtMs;
  int modelsDoneAtMs;
  int lastRunAtMs;

  /// modelCarId → когда его поколения были синхронизированы (мс). Маркер
  /// резюмируемости фазы 2 между запусками приложения.
  final Map<int, int> genIndex;

  static _SyncMeta parse(String? raw) {
    if (raw == null || raw.isEmpty) return _SyncMeta();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _SyncMeta();
      final genRaw = decoded['genIndex'];
      final genIndex = <int, int>{};
      if (genRaw is Map) {
        genRaw.forEach((key, value) {
          final id = int.tryParse('$key');
          if (id != null && value is num) genIndex[id] = value.toInt();
        });
      }
      int readMs(String key) {
        final v = decoded[key];
        return v is num ? v.toInt() : 0;
      }

      return _SyncMeta(
        brandsSyncedAtMs: readMs('brandsSyncedAtMs'),
        modelsDoneAtMs: readMs('modelsDoneAtMs'),
        lastRunAtMs: readMs('lastRunAtMs'),
        genIndex: genIndex,
      );
    } catch (_) {
      return _SyncMeta();
    }
  }

  String encode() => jsonEncode({
    'schema': 1,
    'brandsSyncedAtMs': brandsSyncedAtMs,
    'modelsDoneAtMs': modelsDoneAtMs,
    'lastRunAtMs': lastRunAtMs,
    'genIndex': {
      for (final entry in genIndex.entries) '${entry.key}': entry.value,
    },
  });
}

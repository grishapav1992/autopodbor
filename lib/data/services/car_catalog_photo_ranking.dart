// Ранжирование фото рестайлингов каталога. Логика жила приватно в
// RemoteCarCatalog (auto_request_screen.dart) и понадобилась в data-слое:
// файловый кэш каталога хранит не больше [kCarCatalogMaxPhotosPerRestyling]
// лучших фото на рестайлинг (полный список с бэка раздувает файл в разы,
// а UI всё равно показывает одно-два). Клиентская форма делегирует сюда же,
// чтобы «лучшее фото» в пикере и в кэше выбиралось одинаково.

import '../api/storage_api_models.dart';

/// Сколько фото на рестайлинг переживает запись в кэш каталога.
const int kCarCatalogMaxPhotosPerRestyling = 3;

/// Ранг размера фото по строке `size` бэка (xl/l/m/s/thumb…): больше — лучше.
int carCatalogPhotoSizeRank(String size) {
  final value = size.toLowerCase();
  if (value == 'xl' || value.contains('xlarge') || value.contains('original')) {
    return 6;
  }
  if (value == 'l' || value.contains('large')) return 5;
  if (value == 'm' || value.contains('medium')) return 4;
  if (value == 's' || value.contains('small')) return 3;
  if (value.contains('thumb') || value.contains('preview')) return 1;
  return 2;
}

/// Эвристика качества по самому URL (orig/large/размеры в пути — плюс,
/// thumb/preview/small — минус).
int carCatalogPhotoUrlQualityScore(String raw) {
  final value = raw.toLowerCase();
  var score = 0;
  if (value.contains('orig') ||
      value.contains('original') ||
      value.contains('full') ||
      value.contains('hd')) {
    score += 5;
  }
  if (value.contains('large') || value.contains('_l') || value.contains('-l')) {
    score += 3;
  }
  final match = RegExp(r'(\d{2,4})x(\d{2,4})').firstMatch(value);
  if (match != null) {
    final w = int.tryParse(match.group(1) ?? '') ?? 0;
    final h = int.tryParse(match.group(2) ?? '') ?? 0;
    score += ((w * h) / 100000).round();
  }
  if (value.contains('thumb') ||
      value.contains('thumbnail') ||
      value.contains('preview') ||
      value.contains('small') ||
      value.contains('_s') ||
      value.contains('-s')) {
    score -= 3;
  }
  return score;
}

/// Приводит URL к абсолютному виду; пустая строка = «не показывать».
String carCatalogNormalizePhotoUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  if (value.startsWith('//')) return 'https:$value';
  if (value.startsWith('/')) return '';
  if (value.startsWith('www.')) return 'https://$value';
  if (RegExp(r'^[A-Za-z0-9.-]+\.[A-Za-z]{2,}').hasMatch(value)) {
    return 'https://$value';
  }
  return value;
}

/// Список URL фото рестайлинга, лучшие первыми (дедуп по URL).
List<String> carCatalogBestPhotoUrlsForRestyling(RestylingItem rest) {
  final scored = <String, int>{};
  for (final photo in rest.photos) {
    final sizeScore = carCatalogPhotoSizeRank(photo.size) * 100;
    for (final raw in [photo.urlX2, photo.urlX1]) {
      final url = carCatalogNormalizePhotoUrl(raw);
      if (url.isEmpty) continue;
      final total = sizeScore + carCatalogPhotoUrlQualityScore(url);
      final prev = scored[url];
      if (prev == null || total > prev) {
        scored[url] = total;
      }
    }
  }
  final entries = scored.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => e.key).toList();
}

int _photoScore(PhotoItem photo) {
  final sizeScore = carCatalogPhotoSizeRank(photo.size) * 100;
  var best = -1 << 20;
  for (final raw in [photo.urlX2, photo.urlX1]) {
    final url = carCatalogNormalizePhotoUrl(raw);
    if (url.isEmpty) continue;
    final total = sizeScore + carCatalogPhotoUrlQualityScore(url);
    if (total > best) best = total;
  }
  return best;
}

/// Рестайлинг с фото, обрезанными до [maxPhotos] лучших (для записи в кэш).
/// Фото без единого валидного URL выбрасываются всегда.
RestylingItem carCatalogTrimRestylingPhotos(
  RestylingItem rest, {
  int maxPhotos = kCarCatalogMaxPhotosPerRestyling,
}) {
  if (rest.photos.length <= maxPhotos &&
      rest.photos.every(
        (p) =>
            carCatalogNormalizePhotoUrl(p.urlX1).isNotEmpty ||
            carCatalogNormalizePhotoUrl(p.urlX2).isNotEmpty,
      )) {
    return rest;
  }
  final withUrl =
      rest.photos
          .where(
            (p) =>
                carCatalogNormalizePhotoUrl(p.urlX1).isNotEmpty ||
                carCatalogNormalizePhotoUrl(p.urlX2).isNotEmpty,
          )
          .toList()
        ..sort((a, b) => _photoScore(b).compareTo(_photoScore(a)));
  return RestylingItem(
    id: rest.id,
    restyling: rest.restyling,
    yearStart: rest.yearStart,
    yearEnd: rest.yearEnd,
    frames: rest.frames,
    photos: withUrl.take(maxPhotos).toList(growable: false),
  );
}

/// Поколение с обрезанными фото всех рестайлингов.
GenerationItem carCatalogTrimGenerationPhotos(GenerationItem generation) {
  var changed = false;
  final restylings = <RestylingItem>[];
  for (final rest in generation.restylings) {
    final trimmed = carCatalogTrimRestylingPhotos(rest);
    if (!identical(trimmed, rest)) changed = true;
    restylings.add(trimmed);
  }
  if (!changed) return generation;
  return GenerationItem(
    id: generation.id,
    modelCarId: generation.modelCarId,
    generation: generation.generation,
    frames: generation.frames,
    restylings: restylings,
  );
}

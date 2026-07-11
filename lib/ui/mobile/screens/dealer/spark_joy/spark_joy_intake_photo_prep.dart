import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Подготовка фото интейка «Фото автомобиля» перед заливкой в S3:
/// даунскейл длинной стороны до [kIntakePhotoMaxSide] + пере-энкод в JPEG.
/// Требование: «перед отправкой в S3 надо делать сжатие» — vision-токены и
/// время ответа ИИ считаются по РАЗРЕШЕНИЮ, а канал мобильный.
///
/// В отличие от досмотра СТС (`_sparkPrepareDocScanPhoto`) контраст НЕ
/// поднимаем — фото осмотра должны остаться цветово-достоверными (ЛКП,
/// подтёки), 2560px хватает и для дефектов, и для будущей ИИ-раскладки.
///
/// Top-level чистая функция — гоняется через `compute()` в изоляте
/// (декод ~5-мегапиксельного JPEG морозил бы UI-поток).
const int kIntakePhotoMaxSide = 2560;
const int kIntakePhotoJpegQuality = 82;

/// Best-effort: любые сбои декода (например HEIC, который package:image не
/// умеет) возвращают исходные байты — файл уйдёт в S3 как есть, это хуже
/// по трафику, но не ломает загрузку.
Uint8List sparkPrepareIntakePhoto(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    // EXIF-ориентация теряется при пере-энкоде — запекаем поворот в пиксели.
    var im = img.bakeOrientation(decoded);
    final needsResize =
        im.width > kIntakePhotoMaxSide || im.height > kIntakePhotoMaxSide;
    if (needsResize) {
      im = im.width >= im.height
          ? img.copyResize(im, width: kIntakePhotoMaxSide)
          : img.copyResize(im, height: kIntakePhotoMaxSide);
    }
    final encoded = Uint8List.fromList(
      img.encodeJpg(im, quality: kIntakePhotoJpegQuality),
    );
    // После даунскейла JPEG возвращаем всегда (важно РАЗРЕШЕНИЕ — vision-
    // токены и канал). Без ресайза пере-энкод маленького уже-сжатого файла
    // может только РАЗДУТЬ его — тогда оригинал честнее.
    if (needsResize) return encoded;
    return encoded.length < bytes.length ? encoded : bytes;
  } catch (_) {
    return bytes;
  }
}

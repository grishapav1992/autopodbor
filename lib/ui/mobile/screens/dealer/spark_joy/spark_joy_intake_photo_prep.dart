import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
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

/// Любой принятый результат — JPEG. Если декодировать исходник нельзя,
/// бросаем [FormatException]: отправлять оригинал под видом сжатой копии
/// нельзя, иначе нарушается контракт интейка и vision может получить HEIC с
/// заголовком image/jpeg. Локальный оригинал при этом остаётся нетронутым.
Uint8List sparkPrepareIntakePhoto(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Формат изображения не поддерживается');
    }
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
    // Возвращаем JPEG всегда, даже если маленький исходник был компактнее:
    // для временного vision-объекта важнее единый читаемый формат, чем
    // экономия нескольких килобайт.
    return encoded;
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('Не удалось подготовить изображение: $e');
  }
}

/// SHA-256 именно оригинальных байт. Вызывается до сжатия и загрузки, поэтому
/// hash стабильно сопоставляет ответ ИИ с локальным оригиналом.
String sparkIntakeSha256Hex(Uint8List bytes) =>
    crypto.sha256.convert(bytes).toString();

import 'dart:typed_data';

import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_intake_photo_prep.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _pngOfSize(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 60, 30));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('крупное фото даунскейлится до 2560 по длинной стороне и уходит в JPEG',
      () {
    final source = _pngOfSize(3000, 2000);
    final prepared = sparkPrepareIntakePhoto(source);
    final decoded = img.decodeImage(prepared);
    expect(decoded, isNotNull);
    expect(decoded!.width, kIntakePhotoMaxSide);
    expect(decoded.height, lessThanOrEqualTo(kIntakePhotoMaxSide));
    // JPEG-магия: FF D8. Сравнение размера с синтетическим одноцветным PNG
    // бессмысленно (тот жмётся почти в ноль) — важен именно даунскейл.
    expect(prepared[0], 0xFF);
    expect(prepared[1], 0xD8);
  });

  test('портретная ориентация скейлится по высоте', () {
    final source = _pngOfSize(1000, 4000);
    final prepared = sparkPrepareIntakePhoto(source);
    final decoded = img.decodeImage(prepared)!;
    expect(decoded.height, kIntakePhotoMaxSide);
    expect(decoded.width, lessThanOrEqualTo(kIntakePhotoMaxSide));
  });

  test('маленькое фото не апскейлится', () {
    final source = _pngOfSize(300, 200);
    final prepared = sparkPrepareIntakePhoto(source);
    final decoded = img.decodeImage(prepared)!;
    expect(decoded.width, 300);
    expect(decoded.height, 200);
  });

  test('недекодируемые байты возвращаются как есть (HEIC-фолбэк)', () {
    final garbage = Uint8List.fromList(List<int>.generate(64, (i) => i * 3));
    final prepared = sparkPrepareIntakePhoto(garbage);
    expect(prepared, same(garbage));
  });

  test('пере-энкод, раздувающий маленький JPEG, откатывается к оригиналу', () {
    final tiny = img.Image(width: 8, height: 8);
    img.fill(tiny, color: img.ColorRgb8(10, 20, 30));
    final source = Uint8List.fromList(img.encodeJpg(tiny, quality: 10));
    final prepared = sparkPrepareIntakePhoto(source);
    expect(prepared.length, lessThanOrEqualTo(source.length));
  });
}

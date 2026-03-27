import 'dart:typed_data';

import 'vin_ocr_types.dart';
import 'vin_ocr_service_io.dart'
    if (dart.library.html) 'vin_ocr_service_web.dart'
    as impl;

bool get vinOcrSupported => impl.vinOcrSupported;

Future<VinOcrResult> scanVinFromImageBytes(Uint8List bytes) {
  return impl.scanVinFromImageBytes(bytes);
}

Future<Uint8List?> pickVinImageBytes({required bool preferCamera}) {
  return impl.pickVinImageBytes(preferCamera: preferCamera);
}

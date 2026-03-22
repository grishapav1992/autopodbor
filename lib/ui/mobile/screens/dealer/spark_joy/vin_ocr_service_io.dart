import 'dart:typed_data';

import 'vin_ocr_types.dart';

bool get vinOcrSupported => false;

Future<VinOcrResult> scanVinFromImageBytes(Uint8List bytes) async {
  return const VinOcrResult.unsupported();
}

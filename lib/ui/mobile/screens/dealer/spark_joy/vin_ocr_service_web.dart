// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'dart:html' as html;

import 'vin_ocr_types.dart';

bool get vinOcrSupported {
  final fn = js_util.getProperty<Object?>(html.window, 'vinOcrScan');
  return fn != null;
}

Uint8List? _decodeDataUrlBytes(String dataUrl) {
  if (!dataUrl.startsWith('data:')) return null;
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex <= 0 || commaIndex >= dataUrl.length - 1) return null;
  final payload = dataUrl.substring(commaIndex + 1);
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> pickVinImageBytes({required bool preferCamera}) async {
  final fn = js_util.getProperty<Object?>(html.window, 'vinPickImage');
  if (fn == null) return null;
  try {
    final promise = js_util.callMethod<Object?>(html.window, 'vinPickImage', [
      preferCamera,
    ]);
    final result = await js_util.promiseToFuture<Object?>(promise as Object);
    final dataUrl = (result ?? '').toString();
    if (dataUrl.isEmpty) return null;
    return _decodeDataUrlBytes(dataUrl);
  } catch (_) {
    return null;
  }
}

String _detectImageMime(Uint8List bytes) {
  // ISO-BMFF container (HEIC/HEIF/AVIF and others)
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
    const heicBrands = {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'mif1',
      'msf1',
    };
    if (heicBrands.contains(brand)) {
      return 'image/heic';
    }
    const avifBrands = {'avif', 'avis'};
    if (avifBrands.contains(brand)) {
      return 'image/avif';
    }
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

Future<VinOcrResult> scanVinFromImageBytes(Uint8List bytes) async {
  final fn = js_util.getProperty<Object?>(html.window, 'vinOcrScan');
  if (fn == null) {
    return const VinOcrResult(
      supported: false,
      vin: '',
      rawText: '',
      error: 'OCR модуль не загружен.',
    );
  }

  final mimeType = _detectImageMime(bytes);
  final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
  try {
    final promise = js_util.callMethod<Object?>(html.window, 'vinOcrScan', [
      dataUrl,
    ]);
    final result = await js_util.promiseToFuture<Object>(promise as Object);
    if (result == null) {
      return const VinOcrResult(
        supported: true,
        vin: '',
        rawText: '',
        error: 'OCR не вернул результат.',
      );
    }

    final vin = (js_util.getProperty<Object?>(result, 'vin') ?? '')
        .toString()
        .trim();
    final rawText = (js_util.getProperty<Object?>(result, 'rawText') ?? '')
        .toString();
    final rawError = js_util.getProperty<Object?>(result, 'error');

    return VinOcrResult(
      supported: true,
      vin: vin,
      rawText: rawText,
      error: rawError?.toString(),
    );
  } catch (e) {
    return VinOcrResult(
      supported: true,
      vin: '',
      rawText: '',
      error: 'Ошибка OCR: $e',
    );
  }
}

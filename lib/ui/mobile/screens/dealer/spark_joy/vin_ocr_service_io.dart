import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'vin_ocr_types.dart';

const _vinLength = 17;
final _vinCharPattern = RegExp(r'[A-HJ-NPR-Z0-9]');

bool get vinOcrSupported => Platform.isAndroid || Platform.isIOS;

String _normalizeVinOcrText(String value) {
  if (value.isEmpty) return '';
  final normalized = value
      .toUpperCase()
      .replaceAll(' ', '')
      .replaceAll('\n', '')
      .replaceAll('\r', '')
      .replaceAll('\t', '')
      .replaceAll('С', 'C')
      .replaceAll('В', 'B')
      .replaceAll('Е', 'E')
      .replaceAll('Н', 'H')
      .replaceAll('К', 'K')
      .replaceAll('М', 'M')
      .replaceAll('Р', 'P')
      .replaceAll('Т', 'T')
      .replaceAll('У', 'Y')
      .replaceAll('Х', 'X')
      .replaceAll('О', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1');
  final chars = _vinCharPattern
      .allMatches(normalized)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  return chars.join();
}

String _extractStrictVinFromText(String value) {
  final cleaned = _normalizeVinOcrText(value);
  if (cleaned.length < _vinLength) return '';
  for (var i = 0; i <= cleaned.length - _vinLength; i++) {
    final candidate = cleaned.substring(i, i + _vinLength);
    if (candidate.contains('I') ||
        candidate.contains('O') ||
        candidate.contains('Q')) {
      continue;
    }
    return candidate;
  }
  return '';
}

Future<VinOcrResult> scanVinFromImageBytes(Uint8List bytes) async {
  if (!vinOcrSupported) {
    return const VinOcrResult.unsupported();
  }

  final fileName = 'vin_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg';
  final imageFile = File('${Directory.systemTemp.path}/$fileName');
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  try {
    await imageFile.writeAsBytes(bytes, flush: true);
    final input = InputImage.fromFilePath(imageFile.path);
    final recognized = await recognizer.processImage(input);
    final rawText = recognized.text.trim();
    final vin = _extractStrictVinFromText(rawText);

    if (vin.isNotEmpty) {
      return VinOcrResult(supported: true, vin: vin, rawText: rawText);
    }

    return VinOcrResult(
      supported: true,
      vin: '',
      rawText: rawText,
      error: rawText.isEmpty
          ? 'Не удалось распознать текст VIN.'
          : 'Не удалось выделить VIN из распознанного текста.',
    );
  } catch (e) {
    return VinOcrResult(
      supported: true,
      vin: '',
      rawText: '',
      error: 'Ошибка OCR: $e',
    );
  } finally {
    await recognizer.close();
    if (await imageFile.exists()) {
      try {
        await imageFile.delete();
      } catch (_) {}
    }
  }
}

Future<Uint8List?> pickVinImageBytes({required bool preferCamera}) async {
  return null;
}

import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'vin_text_extraction.dart';
import 'vin_ocr_types.dart';

bool get vinOcrSupported => Platform.isAndroid || Platform.isIOS;

Future<VinOcrResult> scanVinFromImageBytes(Uint8List bytes) async {
  if (!vinOcrSupported) {
    return const VinOcrResult.unsupported();
  }

  final fileName = 'vin_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg';
  // Не Directory.systemTemp: на Android он указывает в корневой /tmp-путь
  // вне песочницы приложения — запись падает, и OCR умирал бы на первом шаге.
  final tempDir = await getTemporaryDirectory();
  final imageFile = File('${tempDir.path}/$fileName');
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  try {
    await imageFile.writeAsBytes(bytes, flush: true);
    final input = InputImage.fromFilePath(imageFile.path);
    final recognized = await recognizer.processImage(input);
    final rawText = recognized.text.trim();
    // Strict намеренно: result.vin уходит потребителям «голым» 17-токеном,
    // мягкое извлечение здесь отмывало бы мусор в правдоподобный кандидат.
    // Построчный текст MLKit сохраняем в rawText — мягкие потребители
    // (ручной сканер) переизвлекают из него сами.
    final vin = extractVinFromOcrText(rawText, mode: VinExtractionMode.strict);

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

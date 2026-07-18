import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

/// Дымовой тест генерации PDF «Материалов проверки»: проверяем, что пакет `pdf`
/// собирает документ, забандленный Roboto встраивается и кириллица не роняет
/// рендер. Шрифт читаем с диска (не через rootBundle) — тестовой среде не нужен
/// asset-манифест, а нам важна именно связка pdf + Cyrillic-глифы.
void main() {
  test('legal review PDF builds with bundled Cyrillic Roboto', () async {
    ByteData load(String path) {
      final bytes = File(path).readAsBytesSync();
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    }

    final regular = pw.Font.ttf(load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(load('assets/fonts/Roboto-Bold.ttf'));
    final medium = pw.Font.ttf(load('assets/fonts/Roboto-Medium.ttf'));

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Материалы юридической проверки',
            style: pw.TextStyle(font: bold, fontSize: 18),
          ),
          pw.Text('Определение автомобиля (конвертер ApiCloud)'),
          pw.Text('Залог (нотариат) — чисто'),
          pw.Text('Такси (ФГИС) — найдено', style: pw.TextStyle(font: medium)),
          pw.Text('ГОСТ-сертификат — VOLKSWAGEN TIGUAN · 2020 · 2.0 л'),
        ],
      ),
    );

    final bytes = await doc.save();

    expect(bytes.length, greaterThan(2000), reason: 'PDF подозрительно пуст');
    expect(
      String.fromCharCodes(bytes.take(5)),
      '%PDF-',
      reason: 'нет сигнатуры PDF-файла',
    );
  });
}

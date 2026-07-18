part of 'spark_joy_create_report_screen.dart';

/// Стабильный id сгенерированного PDF-материала в [_legalFiles]. Фиксированный,
/// чтобы перегенерация (повтор «Обновить») заменяла файл, а не плодила копии,
/// и чтобы восстановленный из черновика PDF узнавался как «уже есть».
const String _kLegalReviewPdfItemId = 'spark-legal-review-pdf';

/// Отображаемое имя PDF в списке материалов (оно же уезжает в S3-манифест).
const String _kLegalReviewPdfName = 'Отчёт о проверке ApiCloud.pdf';

/// Ленивая (одноразовая) загрузка забандленного Roboto для PDF: без встроенного
/// шрифта dart_pdf берёт Helvetica и кириллица превращается в пустые квадраты.
pw.Font? _legalPdfFontRegular;
pw.Font? _legalPdfFontMedium;
pw.Font? _legalPdfFontBold;

// Палитра документа = фирменные цвета приложения (см. app_colors.dart), плюс
// светлые подложки для баннеров. `fromInt` не const → держим top-level final.
final pdf.PdfColor _pdfNavy = pdf.PdfColor.fromInt(0xFF0F2A44); // kSecondaryColor
final pdf.PdfColor _pdfNavyDeep = pdf.PdfColor.fromInt(0xFF1B3A57); // kBlueColor
final pdf.PdfColor _pdfInk = pdf.PdfColor.fromInt(0xFF1F2933); // kTertiaryColor
final pdf.PdfColor _pdfBorder = pdf.PdfColor.fromInt(0xFFD7DCE2); // kBorderColor
final pdf.PdfColor _pdfGrey = pdf.PdfColor.fromInt(0xFF6B7280); // kGreyColor
final pdf.PdfColor _pdfGreen = pdf.PdfColor.fromInt(0xFF2E7D32); // kGreenColor
final pdf.PdfColor _pdfOrange = pdf.PdfColor.fromInt(0xFFC2410C); // kOrangeColor
final pdf.PdfColor _pdfRed = pdf.PdfColor.fromInt(0xFFC62828); // kRedColor

extension _SparkJoyLegalPdf on _SparkJoyCreateReportScreenState {
  /// Собирает PDF из результатов проверок ApiCloud и кладёт его в [_legalFiles]
  /// под фиксированным id. Файл дальше уезжает в отчёт наравне с остальными
  /// материалами (тег `legal_file`) и открывается штатным pdfrx-вьюером.
  ///
  /// [regenerate] == true — пересобрать и заменить существующий (после свежего
  /// прогона проверок). false — собрать, только если файла ещё нет (возврат к
  /// черновику с уже терминальными результатами, но без PDF).
  Future<void> _ensureLegalReviewPdf({required bool regenerate}) async {
    // Просмотр завершённого отчёта: материалы приходят уже загруженными с
    // сервера, локально ничего не генерируем и не переписываем.
    if (widget.readOnly) return;

    final settledChecks = _legalCheckResults
        .where(_legalCheckSettled)
        .toList(growable: false);
    if (settledChecks.isEmpty) return;

    final existingIndex = _legalFiles.indexWhere(
      (f) => f.id == _kLegalReviewPdfItemId,
    );
    if (existingIndex >= 0 && !regenerate) return;

    Uint8List bytes;
    try {
      bytes = await _buildLegalReviewPdfBytes(settledChecks);
    } catch (e) {
      debugPrint('[LegalReview] сборка PDF не удалась: $e');
      return;
    }
    if (bytes.isEmpty || !mounted) return;

    String? source;
    if (kIsWeb) {
      source = 'data:application/pdf;base64,${base64Encode(bytes)}';
    } else {
      source = await _persistBytesToAppStorage(
        bytes: bytes,
        mimeType: 'application/pdf',
        prefix: 'legalpdf',
        originalFileName: _kLegalReviewPdfName,
      );
    }
    if (source == null || source.trim().isEmpty || !mounted) return;

    // Предыдущий локальный файл (перегенерация даёт новое имя на диске) —
    // удаляем best-effort, чтобы не копить сироты в песочнице приложения.
    final previousSource = existingIndex >= 0
        ? _legalFiles[existingIndex].dataUrl
        : null;

    final item = UploadedItem(
      id: _kLegalReviewPdfItemId,
      name: _kLegalReviewPdfName,
      originalName: _kLegalReviewPdfName,
      displayName: _kLegalReviewPdfName,
      mimeType: 'application/pdf',
      dataUrl: source,
    );
    _setStateSafely(() {
      final next = [..._legalFiles];
      final idx = next.indexWhere((f) => f.id == _kLegalReviewPdfItemId);
      if (idx >= 0) {
        next[idx] = item;
      } else {
        next.add(item);
      }
      _legalFiles = next;
    });
    _markDraftDirty();

    if (previousSource != null &&
        previousSource != source &&
        previousSource.startsWith('file://')) {
      unawaited(_deleteLocalFileQuietly(previousSource));
    }
  }

  Future<void> _deleteLocalFileQuietly(String fileUri) async {
    try {
      final path = Uri.parse(fileUri).toFilePath();
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Косметическая уборка — молча игнорируем.
    }
  }

  Future<Uint8List> _buildLegalReviewPdfBytes(
    List<Map<String, dynamic>> checks,
  ) async {
    _legalPdfFontRegular ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    _legalPdfFontMedium ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Medium.ttf'),
    );
    _legalPdfFontBold ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

    final theme = pw.ThemeData.withFont(
      base: _legalPdfFontRegular!,
      bold: _legalPdfFontBold!,
      italic: _legalPdfFontRegular!,
      boldItalic: _legalPdfFontBold!,
    );

    final vin = _sanitizeVin(_vinController.text);
    final plate = _plateController.text.trim();
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final markModel = [brand, model].where((s) => s.isNotEmpty).join(' ');

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
        footer: _legalPdfFooter,
        build: (context) => [
          _legalPdfHeader(markModel: markModel, vin: vin, plate: plate),
          pw.SizedBox(height: 16),
          _legalPdfConclusionBanner(checks),
          pw.SizedBox(height: 16),
          _legalPdfSectionTitle('Идентификация автомобиля'),
          pw.SizedBox(height: 8),
          _legalPdfVehicleBox(
            vin: vin,
            plate: plate,
            markModel: markModel,
          ),
          pw.SizedBox(height: 18),
          _legalPdfSectionTitle('Результаты проверок (${checks.length})'),
          pw.SizedBox(height: 4),
          _legalPdfLegend(),
          pw.SizedBox(height: 8),
          ...checks.map(_legalPdfCheckBlock),
          pw.SizedBox(height: 10),
          _legalPdfDisclaimer(),
        ],
      ),
    );
    return doc.save();
  }

  // ── Шапка ──────────────────────────────────────────────────────────────
  pw.Widget _legalPdfHeader({
    required String markModel,
    required String vin,
    required String plate,
  }) {
    final subject = [
      if (markModel.isNotEmpty) markModel,
      if (plate.isNotEmpty) plate else if (vin.isNotEmpty) 'VIN $vin',
    ].join(' · ');
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [_pdfNavy, _pdfNavyDeep],
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Отчёт о юридической проверке',
                style: pw.TextStyle(
                  font: _legalPdfFontBold,
                  fontSize: 19,
                  color: pdf.PdfColors.white,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdf.PdfColors.white, width: 0.7),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'ApiCloud',
                  style: pw.TextStyle(
                    font: _legalPdfFontMedium,
                    fontSize: 8.5,
                    color: pdf.PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          if (subject.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              subject,
              style: pw.TextStyle(
                fontSize: 11,
                color: pdf.PdfColors.blueGrey100,
              ),
            ),
          ],
          pw.SizedBox(height: 2),
          pw.Text(
            'Дата формирования: $_legalPdfTimestamp',
            style: pw.TextStyle(
              fontSize: 9,
              color: pdf.PdfColors.blueGrey200,
            ),
          ),
        ],
      ),
    );
  }

  // ── Общий вывод ────────────────────────────────────────────────────────
  pw.Widget _legalPdfConclusionBanner(List<Map<String, dynamic>> checks) {
    final foundText = sparkJoyLegalFoundBanner(checks);
    final hasError = checks.any(
      (c) => sparkJoyLegalRowTone(c) == SparkJoyLegalTone.error,
    );

    final pdf.PdfColor accent;
    final pdf.PdfColor bg;
    final String title;
    final String body;
    if (foundText != null) {
      accent = _pdfOrange;
      bg = pdf.PdfColors.orange50;
      title = 'Обнаружены замечания';
      body = foundText;
    } else if (hasError) {
      accent = _pdfGrey;
      bg = pdf.PdfColors.grey100;
      title = 'Проверка выполнена частично';
      body = 'Часть проверок не удалось выполнить — см. статусы ниже.';
    } else {
      accent = _pdfGreen;
      bg = pdf.PdfColors.green50;
      title = 'Замечаний не обнаружено';
      body = 'Все проверки пройдены, записей о рисках не найдено.';
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: accent, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 11,
            height: 11,
            margin: const pw.EdgeInsets.only(top: 1),
            decoration: pw.BoxDecoration(
              color: accent,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: _legalPdfFontBold,
                    fontSize: 12,
                    color: accent,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  body,
                  style: pw.TextStyle(fontSize: 9.5, color: _pdfInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Идентификация авто ─────────────────────────────────────────────────
  pw.Widget _legalPdfVehicleBox({
    required String vin,
    required String plate,
    required String markModel,
  }) {
    final rows = <pw.Widget>[
      if (markModel.isNotEmpty) _legalPdfKvRow('Марка/модель', markModel),
      if (vin.isNotEmpty) _legalPdfKvRow('VIN', vin),
      if (plate.isNotEmpty) _legalPdfKvRow('Госномер', plate),
    ];
    if (rows.isEmpty) {
      rows.add(
        _legalPdfKvRow('Идентификатор', 'VIN/госномер не указан'),
      );
    }
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: pdf.PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _pdfBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  // ── Карточка проверки ──────────────────────────────────────────────────
  pw.Widget _legalPdfCheckBlock(Map<String, dynamic> check) {
    final type = (check['checkType'] ?? '').toString();
    final tone = sparkJoyLegalRowTone(check);
    final dataEmpty = sparkJoyLegalDataEmpty(check);
    final toneColor = _legalPdfToneColor(tone, dataEmpty: dataEmpty);
    final title = type.isEmpty ? 'Проверка' : sparkJoyLegalCheckTypeLabel(type);
    final verdict = sparkJoyLegalVerdictLabel(tone, dataEmpty: dataEmpty);
    final subtitle = _legalRowSubtitle(check);
    final pairs = _legalPdfDetailPairs(check);

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: pdf.PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _pdfBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Цветная точка — мгновенно читаемый статус проверки.
              pw.Container(
                width: 9,
                height: 9,
                margin: const pw.EdgeInsets.only(top: 2, right: 7),
                decoration: pw.BoxDecoration(
                  color: toneColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: _legalPdfFontBold,
                    fontSize: 11.5,
                    color: _pdfInk,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              _legalPdfVerdictPill(verdict, toneColor),
            ],
          ),
          if (subtitle.trim().isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16),
              child: pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 9.5, color: _pdfGrey),
              ),
            ),
          ],
          if (pairs.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              margin: const pw.EdgeInsets.only(left: 16),
              padding: const pw.EdgeInsets.all(9),
              decoration: pw.BoxDecoration(
                color: pdf.PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: pairs
                    .map((e) => _legalPdfKvRow(e.key, e.value))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _legalPdfVerdictPill(String verdict, pdf.PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        verdict.toUpperCase(),
        style: pw.TextStyle(
          font: _legalPdfFontMedium,
          fontSize: 7.5,
          color: pdf.PdfColors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Легенда / подпись / футер ──────────────────────────────────────────
  pw.Widget _legalPdfLegend() {
    pw.Widget dot(pdf.PdfColor c, String label) => pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 7,
          height: 7,
          decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _pdfGrey)),
      ],
    );
    return pw.Row(
      children: [
        dot(_pdfGreen, 'чисто'),
        pw.SizedBox(width: 12),
        dot(_pdfOrange, 'найдено'),
        pw.SizedBox(width: 12),
        dot(_pdfNavyDeep, 'данные'),
        pw.SizedBox(width: 12),
        dot(_pdfRed, 'ошибка'),
      ],
    );
  }

  pw.Widget _legalPdfSectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        font: _legalPdfFontBold,
        fontSize: 13,
        color: _pdfInk,
      ),
    );
  }

  pw.Widget _legalPdfDisclaimer() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _pdfBorder)),
      ),
      child: pw.Text(
        'Документ сформирован автоматически на основании данных сервиса '
        'ApiCloud на дату проверки и носит информационный характер. '
        'Актуальность сведений в официальных реестрах может измениться.',
        style: pw.TextStyle(fontSize: 7.5, color: _pdfGrey, lineSpacing: 1.5),
      ),
    );
  }

  pw.Widget _legalPdfFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Отчёт о проверке ApiCloud',
            style: pw.TextStyle(fontSize: 8, color: _pdfGrey),
          ),
          pw.Text(
            'Стр. ${context.pageNumber} из ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _pdfGrey),
          ),
        ],
      ),
    );
  }

  pw.Widget _legalPdfKvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: _pdfGrey),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: _legalPdfFontMedium,
                fontSize: 9.5,
                color: _pdfInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Пары «метка — значение» для деталей проверки в PDF. Повторяет выборку
  /// полей из [_gostCertDetailRows] / [_legalDetailScaffoldRows] (те строят
  /// виджеты; здесь — текст для документа).
  List<MapEntry<String, String>> _legalPdfDetailPairs(
    Map<String, dynamic> check,
  ) {
    final type = (check['checkType'] ?? '').toString();
    final normalized = check['responseNormalized'];
    final pairs = <MapEntry<String, String>>[];

    if (type == 'api_cloud_gost_certificate') {
      final cert = gostCertificateFields(normalized);
      if (cert != null) pairs.addAll(_legalPdfGostPairs(cert));
    }

    if (type == 'api_cloud_zalog_notary' ||
        type == 'api_cloud_zalog_fedresurs') {
      final items = gostListField(normalized, 'items');
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        String f(String k) => (it[k] ?? '').toString().trim();
        final suffix = items.length > 1 ? ' (${i + 1})' : '';
        final pledgee = f('pledgee').isNotEmpty ? f('pledgee') : f('name');
        final date = f('date').isNotEmpty ? f('date') : f('registration_date');
        final regNum = f('number').isNotEmpty ? f('number') : f('reg_number');
        if (pledgee.isNotEmpty) {
          pairs.add(MapEntry('Залогодержатель$suffix', pledgee));
        }
        if (date.isNotEmpty) pairs.add(MapEntry('Дата$suffix', date));
        if (regNum.isNotEmpty) pairs.add(MapEntry('№ записи$suffix', regNum));
      }
    }

    if (type == 'api_cloud_fgis_taxi_search') {
      final permit = gostMapField(normalized, 'permit');
      if (permit != null) {
        String f(String k) => (permit[k] ?? '').toString().trim();
        if (f('number').isNotEmpty) {
          pairs.add(MapEntry('№ разрешения', f('number')));
        }
        if (f('status').isNotEmpty) {
          pairs.add(MapEntry('Статус разрешения', f('status')));
        }
        if (f('region').isNotEmpty) pairs.add(MapEntry('Регион', f('region')));
        if (f('valid_until').isNotEmpty) {
          pairs.add(MapEntry('Действует до', f('valid_until')));
        }
      }
    }

    return pairs;
  }

  List<MapEntry<String, String>> _legalPdfGostPairs(Map<String, dynamic> cert) {
    String f(String k) => (cert[k] ?? '').toString().trim();
    final pairs = <MapEntry<String, String>>[];
    final markModel = [
      f('product'),
      f('tradename'),
    ].where((s) => s.isNotEmpty).join(' ');
    if (markModel.isNotEmpty) pairs.add(MapEntry('Марка/модель', markModel));
    if (_gostHas(f('yearofmanufacturing'))) {
      pairs.add(MapEntry('Год выпуска', f('yearofmanufacturing')));
    }
    final cc = int.tryParse(
      RegExp(r'\d+').firstMatch(f('enginecylindersusefulcapacity'))?.group(0) ??
          '',
    );
    if (cc != null && cc > 0) {
      pairs.add(
        MapEntry('Объём двигателя', '${(cc / 1000).toStringAsFixed(1)} л'),
      );
    }
    if (_gostHas(f('enginepetrol'))) {
      pairs.add(MapEntry('Топливо', f('enginepetrol')));
    }
    if (_gostHas(f('transmission'))) {
      pairs.add(MapEntry('КПП', f('transmission')));
    }
    if (_gostHas(f('enginemaxpower'))) {
      pairs.add(MapEntry('Мощность', f('enginemaxpower')));
    }
    if (_gostHas(f('bodytype'))) pairs.add(MapEntry('Кузов', f('bodytype')));
    if (_gostHas(f('category'))) pairs.add(MapEntry('Категория', f('category')));
    if (_gostHas(f('fullmass'))) pairs.add(MapEntry('Масса, кг', f('fullmass')));
    if (_gostHas(f('eco'))) pairs.add(MapEntry('Эко-класс', f('eco')));
    if (_gostHas(f('numberofcertificate'))) {
      pairs.add(MapEntry('№ сертификата', f('numberofcertificate')));
    }
    return pairs;
  }

  pdf.PdfColor _legalPdfToneColor(
    SparkJoyLegalTone tone, {
    required bool dataEmpty,
  }) {
    if (dataEmpty) return _pdfGrey;
    switch (tone) {
      case SparkJoyLegalTone.clean:
        return _pdfGreen;
      case SparkJoyLegalTone.found:
        return _pdfOrange;
      case SparkJoyLegalTone.data:
        return _pdfNavyDeep;
      case SparkJoyLegalTone.error:
        return _pdfRed;
    }
  }

  String get _legalPdfTimestamp {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.day)}.${two(n.month)}.${n.year} ${two(n.hour)}:${two(n.minute)}';
  }
}

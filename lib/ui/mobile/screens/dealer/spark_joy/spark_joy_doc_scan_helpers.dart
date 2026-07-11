part of 'spark_joy_create_report_screen.dart';

/// Готовит фото документа к vision-распознаванию: печёт EXIF-ориентацию
/// (после пере-энкода EXIF теряется — без bake текст лёг бы боком),
/// даунскейлит длинную сторону до [_kDocScanMaxSide] и поднимает контраст
/// (мелкий текст на защитной сетке СТС/ПТС читается моделью лучше), затем
/// пережимает JPEG. **Сжатие ОБЯЗАТЕЛЬНО** (требование бэка): токены vision
/// считаются по РАЗРЕШЕНИЮ, не по размеру файла — без даунскейла больше
/// токенов и дольше ответ. 2000px по длинной стороне сохраняет читаемость
/// VIN (17 символов ≈ сотни px). Best-effort: при сбое декода — исходные
/// байты (скан важнее предобработки). Тяжёлая (полный декод пикселей) —
/// на нативе через `compute` (изолят), на web синхронно (там изолятов нет).
const int _kDocScanMaxSide = 2000;

Uint8List _sparkPrepareDocScanPhoto(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    var im = img.bakeOrientation(decoded);
    if (im.width > _kDocScanMaxSide || im.height > _kDocScanMaxSide) {
      im = im.width >= im.height
          ? img.copyResize(im, width: _kDocScanMaxSide)
          : img.copyResize(im, height: _kDocScanMaxSide);
    }
    final adjusted = img.adjustColor(im, contrast: 1.15);
    return Uint8List.fromList(img.encodeJpg(adjusted, quality: 82));
  } catch (_) {
    return bytes;
  }
}

/// Скан СТС/ПТС: фото документа → S3 `temp/` (lifecycle-правило бакета удаляет
/// через 1 день) → AiQueue vision (`fileUrls`) → строгий JSON → превью →
/// only-empty автозаполнение «Автомобиля» и «Параметров».
///
/// Экономика ApiCloud и взаимодействие с VIN-конвейером:
///   • когда скан дал марку И модель, дедуп-флаг `_lastVinIdentityResolved`
///     сидируется распознанным VIN — `_maybeAutoResolveIdentityFromVin`
///     выходит по нему ДО stale-блока, поэтому платный конвертер не
///     запускается, а `_resolvedVinYear` (год из документа) не затирается;
///   • `_startLegalLoading` дёргает конвертер только при пустом VIN — после
///     скана VIN заполнен, конверсия госномер→VIN не оплачивается;
///   • значения документа пишутся БЕЗ `_vinAutofilledValues`-трекинга (как
///     ручной ввод): stale-очистка конвейера их не стирает, а ИИ-шаг
///     `_autofillParamsFromVinWithAi` уважает их через only-empty и
///     дозаполняет только недостающие КПП/привод;
///   • марка/модель маппятся на каталог ДО записи в поля (строгий режим,
///     `CarCatalogRepository.resolveCar`): пишутся только каноничные
///     значения с ID (бэк требует brandId/modelCarId); несовпавшее — в
///     снекбар «выберите вручную».
///
/// Распознаёт ТОЛЬКО нейронка (AiQueue vision) — OCR-фолбэка в этом флоу
/// нет (решение Григория 2026-07-08); при сбое — штатный снэкбар ошибок с
/// кодом и этапом. Отдельный OCR-сканер VIN у поля VIN не тронут.
extension _SparkJoyDocScanHelpers on _SparkJoyCreateReportScreenState {
  /// Единая точка автозаполнения (иконка у поля VIN + кнопка «Заполнить» в
  /// карточке «Автозаполнение»). Показывает выбор источника фото и запускает
  /// объединённый OCR-first + ИИ поток (см. [_runAutofillScan]).
  Future<void> _openAutofillScan() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xxxl,
            vertical: SparkSpace.xxl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.xl),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: SparkSize.modalNarrow),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpace.xxxl,
                SparkSpace.xxxl,
                SparkSpace.xxxl,
                SparkSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MyText(
                    text: 'Скан СТС / ПТС',
                    size: SparkTextSize.titleLg,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: SparkSpace.xs),
                  const MyText(
                    text:
                        'Прочитаем документ и заполним VIN, госномер, '
                        'марку и параметры.',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                  const SizedBox(height: SparkSpace.xl),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Открыть камеру'),
                  ),
                  const SizedBox(height: SparkSpace.md),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Из галереи'),
                  ),
                  const SizedBox(height: SparkSpace.sm),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;
    await _runAutofillScan(source);
  }

  /// Объединённый поток: одно фото → сначала локальный OCR (офлайн, ML Kit) для
  /// VIN, затем, если сеть доступна — ещё и ИИ (AiQueue vision) для полного
  /// набора полей. Прогресс — модал-чеклист [_DocScanProgressDialog]. При сбое
  /// сети/ИИ уходим в OCR-only (VIN), без красной ошибки, если VIN распознан.
  Future<void> _runAutofillScan(ImageSource source) async {
    if (_docScanBusy || widget.readOnly) return;
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        // Мелкий шрифт СТС: сильнее жать нельзя. imageQuality заодно
        // транскодирует HEIC (iOS-камера) в JPEG — AiQueue его понимает.
        maxWidth: 2560,
        imageQuality: 88,
      );
    } catch (e) {
      if (mounted) {
        showSparkJoyErrorSnackBar(context, e, fallback: 'Камера недоступна');
      }
      return;
    }
    if (picked == null || !mounted) return; // отмена выбора
    final raw = await picked.readAsBytes();
    if (!mounted) return;
    if (raw.isEmpty) {
      showSparkJoyErrorSnackBar(
        context,
        Exception('Пустой файл фото'),
        fallback: 'Не удалось прочитать фото',
      );
      return;
    }

    // Ручная обрезка (натив): пользователь сам кадрирует документ/VIN как нужно
    // — это заметно поднимает точность и OCR, и vision (меньше лишнего текста и
    // фона в кадре). Отмена в кроппере (null) → прекращаем скан. Ошибка кроппера
    // → полное фото (fallbackBytes). На web нативного кроппера нет — полное фото.
    final Uint8List bytes;
    if (kIsWeb) {
      bytes = raw;
    } else {
      final cropped = await _cropVinWithNativeCropper(
        sourcePath: picked.path,
        fallbackBytes: raw,
        title: 'Обрежьте документ',
      );
      if (cropped == null || !mounted) return; // отмена обрезки
      bytes = cropped;
    }

    // 0=обработка, 1=загрузка, 2=распознавание, 3=готово.
    final stage = ValueNotifier<int>(0);
    final offline = ValueNotifier<bool>(false);
    _setStateSafely(() {
      _docScanBusy = true;
      _docScanStage = 'Обработка фото…';
    });
    // Barrier-диалог прогресса. Не await'им — закрываем программно ниже.
    // `dialogOpen` + PopScope(canPop:false) страхуют от закрытия системной
    // «назад»: иначе pop в finally увёл бы со всего шага, а не с диалога.
    // Навигатор захватываем ЗАРАНЕЕ (root): если State размонтируется за время
    // длинного await ИИ, `Navigator.of(context)` в finally бросил бы на
    // defunct-контексте, а диалог (canPop:false, non-dismissible) остался бы
    // неубиваемым. Root-навигатор живёт над экраном и валиден после unmount.
    final progressNavigator = Navigator.of(context, rootNavigator: true);
    var dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => PopScope(
          canPop: false,
          child: _DocScanProgressDialog(stage: stage, offline: offline),
        ),
      ).whenComplete(() => dialogOpen = false),
    );

    DocScanAiResult? aiResult;
    var ocrVin = '';
    Object? aiError;
    try {
      // Шаг 0: OCR-первым (натив; на web OCR нет — vinOcrSupported == false).
      // Best-effort: сбой OCR не должен ломать поток — ИИ ещё впереди.
      if (vinOcrSupported) {
        try {
          final ocr = await scanVinFromImageBytes(bytes);
          ocrVin = _extractVinFromOcrResult(ocr);
        } catch (_) {}
      }
      // Даунскейл+контраст+пережатие ОБЯЗАТЕЛЬНЫ (требование бэка: без сжатия
      // больше токенов vision и дольше ответ). На нативе — в изоляте (compute).
      final prepared = kIsWeb
          ? _sparkPrepareDocScanPhoto(bytes)
          : await compute(_sparkPrepareDocScanPhoto, bytes);

      // Шаги 1–2: ИИ, если сеть доступна. Любой сбой транспорта/ИИ → OCR-only.
      try {
        stage.value = 1;
        _docScanStage = 'Загрузка фото…';
        // Случайный суффикс к имени: файл кладётся в ОБЩУЮ папку temp/, сервер
        // подписывает view-URL по любому имени без проверки владельца —
        // предсказуемый ключ дал бы перебор чужого фото документа с ПДн.
        final nonce = math.Random.secure().nextInt(1 << 32).toRadixString(16);
        final filename =
            'doc_scan_${DateTime.now().millisecondsSinceEpoch}_$nonce.jpg';
        final upload = await storage_api.StorageApi.getTemporaryUploadUrl(
          reportNumber: 'temp',
          filename: filename,
        );
        await storage_api.StorageApi.uploadBytesToPresignedUrl(
          url: upload.url,
          bytes: prepared,
          contentType: 'image/jpeg',
        );
        final viewUrl = await storage_api.StorageApi.getTemporaryViewUrl(
          reportNumber: 'temp',
          filename: filename,
          // Дефолтные 10с не переживают холодный бэк (7-47с на первом хите).
          timeout: const Duration(seconds: 30),
          // URL на один vision-вызов (≤75с) — не держим сутки живую ссылку на
          // документ с ПДн (дефолт сервера 86400с).
          expiresInSeconds: 120,
        );
        if (viewUrl.isEmpty) {
          throw Exception(
            'Не удалось получить ссылку на загруженное фото '
            '(сервер не ответил вовремя)',
          );
        }
        stage.value = 2;
        _docScanStage = 'Распознавание…';
        final chatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
        final result = await AiQueueApi.chatCompletions(
          chatId: chatId,
          text: 'Распознай документ на фото.',
          cliche: AiQueueClicheBuilder.buildDocScanCliche(),
          fileUrls: [viewUrl],
          timeout: const Duration(seconds: 75),
        );
        // Документ (с ПДн владельца) виден модели — чистим историю чата
        // AiQueue (KV бэка ~6ч). Best-effort: сбой очистки не роняет скан.
        unawaited(
          AiQueueApi.clearChatHistory(chatId: chatId).catchError((_) {}),
        );
        aiResult = parseDocScanAiResult(result.text);
      } catch (e) {
        // Сеть/ИИ недоступны → остаёмся на OCR-only (VIN).
        aiError = e;
        offline.value = true;
        debugPrint('Autofill AI stage failed at "$_docScanStage": $e');
      }
      stage.value = 3;
    } finally {
      // Закрываем barrier-диалог прогресса захваченным root-навигатором (он
      // всегда наверху — между показом и этим местом мы ничего не пушим). Не
      // гейтим на `mounted`: иначе при unmount за время await диалог остался бы
      // неубиваемым. dialogOpen страхует от двойного pop (whenComplete снимет
      // его, если диалог уже закрыт снятием маршрута).
      if (dialogOpen) {
        dialogOpen = false;
        progressNavigator.pop();
      }
      _setStateSafely(() {
        _docScanBusy = false;
        _docScanStage = '';
      });
    }

    if (!mounted) return;
    final merged = _mergeAutofillResults(aiResult, ocrVin);
    if (merged == null || !hasAnyDocScanData(merged)) {
      if (aiError != null && ocrVin.isEmpty) {
        // Ни OCR, ни ИИ — и ИИ упал: показываем код/этап ошибки.
        showSparkJoyErrorSnackBar(
          context,
          aiError,
          fallback: 'Не удалось распознать документ',
        );
      } else {
        // ИИ ответил, но не разобрал полей (или офлайн без VIN) — проблема в
        // фото. Подсказываем, как переснять.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось прочитать документ на этом фото. Снимите документ '
              'целиком, без бликов, и попробуйте ещё раз.',
            ),
          ),
        );
      }
      return;
    }
    await _showDocScanPreviewDialog(merged, ocrOnly: aiResult == null);
  }

  /// Сливает OCR-VIN и результат ИИ. VIN от ИИ приоритетен, когда валиден;
  /// иначе берём OCR-VIN. Если ИИ не отработал — возвращаем результат только с
  /// VIN (офлайн-ветка) либо `null`, если и VIN нет.
  DocScanAiResult? _mergeAutofillResults(DocScanAiResult? ai, String ocrVin) {
    final validOcrVin = _isStrictVin(ocrVin) ? ocrVin : '';
    if (ai == null) {
      if (validOcrVin.isEmpty) return null;
      return (
        docType: 'unknown',
        vin: validOcrVin,
        gosNumber: '',
        brand: '',
        model: '',
        year: '',
        color: '',
      );
    }
    // Выбор VIN между ИИ и OCR:
    //  • ИИ невалиден по формату → берём OCR (если есть), иначе сырой ИИ;
    //  • оба валидны и РАСХОДЯТСЯ → тай-брейк по контрольной сумме ISO 3779:
    //    берём OCR, только если он проходит сумму, а ИИ — нет (частый кейс —
    //    ИИ «додумал» правдоподобный VIN, а OCR прочитал реальный). Саму сумму
    //    гейтом НЕ делаем: у многих валидных РФ-VIN контрольная цифра не по ISO,
    //    поэтому по умолчанию доверяем ИИ (видит весь документ);
    //  • совпадают → без разницы.
    final String vin;
    if (!_isStrictVin(ai.vin)) {
      vin = validOcrVin.isNotEmpty ? validOcrVin : ai.vin;
    } else if (validOcrVin.isNotEmpty &&
        validOcrVin != ai.vin &&
        _isValidVinChecksum(validOcrVin) &&
        !_isValidVinChecksum(ai.vin)) {
      vin = validOcrVin;
    } else {
      vin = ai.vin;
    }
    return (
      docType: ai.docType,
      vin: vin,
      gosNumber: ai.gosNumber,
      brand: ai.brand,
      model: ai.model,
      year: ai.year,
      color: ai.color,
    );
  }

  /// Превью распознанного перед применением: юзер видит, что именно легло бы
  /// в отчёт, и решает. Заполняются ТОЛЬКО пустые поля (ручной ввод
  /// неприкосновенен). Чекбокс «сразу запустить проверки» показывается,
  /// когда проверки ещё не запускались и право есть.
  Future<void> _showDocScanPreviewDialog(
    DocScanAiResult r, {
    bool ocrOnly = false,
  }) async {
    final currentVin = _sanitizeVin(_vinController.text);
    final vinConflict =
        currentVin.length == 17 && r.vin.isNotEmpty && r.vin != currentVin;
    final canOfferChecks =
        _legalCanRunReview &&
        !_legalPurchased &&
        !_legalLoading &&
        !_legalLoaded &&
        (_legalBatchNumber ?? '').isEmpty &&
        (r.vin.isNotEmpty || currentVin.length == 17);
    var runChecks = canOfferChecks;

    final docLabel = switch (r.docType) {
      'sts' => 'СТС',
      'pts' => 'ПТС',
      'epts' => 'выписка ЭПТС',
      _ => 'документ',
    };
    final rows = <(String, String)>[
      if (r.vin.isNotEmpty) ('VIN', r.vin),
      if (r.gosNumber.isNotEmpty) ('Госномер', r.gosNumber),
      if (r.brand.isNotEmpty) ('Марка', r.brand),
      if (r.model.isNotEmpty) ('Модель', r.model),
      if (r.year.isNotEmpty) ('Год', r.year),
      if (r.color.isNotEmpty) ('Цвет', r.color),
    ];

    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xxl,
            vertical: SparkSpace.xxl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.xl),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: SparkSize.modalNarrow),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpace.xxl,
                SparkSpace.xxl,
                SparkSpace.xxl,
                SparkSpace.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MyText(
                    text: 'Распознано: $docLabel',
                    size: SparkTextSize.titleLg,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: SparkSpace.md),
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SparkSpace.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 128,
                            child: MyText(
                              text: label,
                              size: SparkTextSize.caption,
                              color: kGreyColor,
                            ),
                          ),
                          Expanded(
                            child: MyText(
                              text: value,
                              size: SparkTextSize.body,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: SparkSpace.sm),
                  const MyText(
                    text:
                        'Заполняются только пустые поля — введённое вручную '
                        'не перезаписывается.',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                  const SizedBox(height: SparkSpace.xxs),
                  const MyText(
                    text:
                        'Объём двигателя и тип топлива определятся '
                        'автоматически по VIN.',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                  if (ocrOnly) ...[
                    const SizedBox(height: SparkSpace.xs),
                    const MyText(
                      text:
                          'Нет сети — распознан только VIN. Остальное можно '
                          'добавить позже или переснять онлайн.',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                  if (vinConflict) ...[
                    const SizedBox(height: SparkSpace.xs),
                    const MyText(
                      text:
                          'В отчёте уже указан другой VIN — он останется '
                          'без изменений.',
                      size: SparkTextSize.caption,
                      color: kRedColor,
                    ),
                  ],
                  if (canOfferChecks) ...[
                    const SizedBox(height: SparkSpace.sm),
                    InkWell(
                      onTap: () => setDialogState(() => runChecks = !runChecks),
                      borderRadius: BorderRadius.circular(SparkRadius.md),
                      child: Row(
                        children: [
                          Checkbox(
                            value: runChecks,
                            onChanged: (v) =>
                                setDialogState(() => runChecks = v ?? false),
                            activeColor: kSecondaryColor,
                          ),
                          const Expanded(
                            child: MyText(
                              text:
                                  'Сразу запустить проверки по VIN '
                                  '(ГОСТ, такси, залоги)',
                              size: SparkTextSize.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: SparkSpace.md),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Заполнить'),
                  ),
                  const SizedBox(height: SparkSpace.sm),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (apply == true && mounted) {
      await _applyDocScanResult(r, runChecks: runChecks && canOfferChecks);
    }
  }

  Future<void> _applyDocScanResult(
    DocScanAiResult r, {
    required bool runChecks,
    bool showFeedback = true,
  }) async {
    // Строгий режим: сырой текст с документа в поля марки/модели НЕ пишем —
    // сперва маппим на каталог (cache-first, офлайн работает от персиста)
    // и записываем только каноничные значения с ID. Несовпавшее честно
    // попадает в снекбар «выберите вручную».
    CatalogCarMatch? carMatch;
    if (r.brand.isNotEmpty) {
      carMatch = await CarCatalogRepository.instance.resolveCar(
        r.brand,
        r.model,
      );
    }
    if (!mounted) return;
    final filled = <String>[];
    final unmatched = <String>[];
    var identityWritten = false;
    var vinWrittenFromScan = false;
    _setStateSafely(() {
      final brandWasEmpty = _brandController.text.trim().isEmpty;
      final modelWasEmpty = _modelController.text.trim().isEmpty;
      if (carMatch != null) {
        if (brandWasEmpty) {
          _brandController.text = carMatch.brand.name;
          _selectedBrandId = carMatch.brand.id;
          _selectedModelCarId = null;
          identityWritten = true;
          filled.add('марка');
        }
        final model = carMatch.model;
        // Модель пишем только когда марка в поле — та же, что в матче
        // (иначе получили бы модель чужой марки).
        if (model != null &&
            modelWasEmpty &&
            _selectedBrandId == carMatch.brand.id) {
          _modelController.text = model.model;
          _selectedModelCarId = model.id;
          identityWritten = true;
          filled.add('модель');
        }
      }
      if (r.brand.isNotEmpty && carMatch == null && brandWasEmpty) {
        unmatched.add('марка «${r.brand}»');
      }
      if (r.model.isNotEmpty &&
          modelWasEmpty &&
          (carMatch == null || carMatch.model == null)) {
        unmatched.add('модель «${r.model}»');
      }
      if (identityWritten) {
        // Каталожная мета (фото/рестайлинг/frameId) прежнего выбора к новой
        // идентичности не относится; сами ID мы только что проставили.
        _clearCatalogCarMeta();
      }
      if (r.year.isNotEmpty && _resolvedVinYear.isEmpty) {
        // UI-поля года нет — год работает грунтовкой ИИ-параметров.
        _resolvedVinYear = r.year;
      }
      if (r.vin.isNotEmpty && _sanitizeVin(_vinController.text).isEmpty) {
        _vinUnreadable = false;
        _vinController.text = r.vin;
        vinWrittenFromScan = true;
        filled.add('VIN');
      }
      if (r.gosNumber.isNotEmpty && _plateController.text.trim().isEmpty) {
        _applyDetectedPlate(r.gosNumber);
        filled.add('госномер');
      }
      // Цвет пишем как РУЧНОЙ ввод (документ авторитетен; при смене VIN не
      // чистится автоматически — как любой ручной ввод). Движковые параметры
      // (объём/тип/КПП/привод) из СТС НЕ берём — их дозаполнит VIN-шаг
      // _autofillParamsFromVinWithAi после установки VIN выше.
      if (r.color.isNotEmpty && _colorController.text.trim().isEmpty) {
        _colorController.text = r.color;
        filled.add('цвет');
      }
    });
    final vinNow = _sanitizeVin(_vinController.text);
    final brandNow = _brandController.text.trim();
    // Блокируем автоматический VIN-резолвер (_maybeAutoResolveIdentityFromVin),
    // сидируя его дедуп-флаг записанным VIN, если идентичность уже известна:
    //   • марка легла в поле (каталог совпал) — иначе год из документа сотрёт
    //     stale-блок резолвера ДО чтения его only-empty гейтом; ЛИБО
    //   • VIN проставлен этим сканом И документ сам дал марку (даже когда
    //     каталог промахнулся) — платный конвертер лишь re-derive'нул бы ту же
    //     марку (тоже вне каталога), т.е. чистое списание за то, что уже есть;
    //     пользователю показан снек «выберите вручную», это и есть развязка.
    // Порядок записи полей ни при чём — гейт читает контроллеры через 600мс.
    if (vinNow.length == 17 &&
        (brandNow.isNotEmpty || (vinWrittenFromScan && r.brand.isNotEmpty))) {
      _lastVinIdentityResolved = vinNow;
    }
    _markDraftDirty();
    if (mounted && showFeedback) {
      final parts = <String>[
        if (filled.isNotEmpty) 'Заполнено с документа: ${filled.join(', ')}',
        if (filled.isEmpty && unmatched.isEmpty)
          'Все распознанные поля уже заполнены — ничего не изменено',
        // Строгий режим: несовпавшее с каталогом в поля не пишется.
        if (unmatched.isNotEmpty)
          'Не найдено в каталоге: ${unmatched.join(', ')} — выберите вручную',
      ];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(parts.join('. '))));
    }
    if (runChecks) _autoStartLegalChecksAfterDocScan();
  }

  /// Автозапуск платных проверок после скана (юзер согласился чекбоксом).
  /// В новом отчёте набор проверок ещё не выбран — берём все содержательные
  /// типы из каталога (без конвертера), как их видит шаг «Материалы проверки».
  void _autoStartLegalChecksAfterDocScan() {
    if (_legalSelectedCheckTypes.isEmpty) {
      final defaults = _legalAvailableCheckTypes
          .map((t) => t.value)
          .where((v) => v != 'api_cloud_converter_search')
          .toList();
      if (defaults.isEmpty) {
        // Каталог типов ещё не доехал (медленная сеть / _ensureLegalReviewMeta
        // в полёте) — говорим честно, а не молча съедаем данное согласие.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Не получилось запустить проверки автоматически — '
                'запустите их в шаге «Материалы проверки»',
              ),
            ),
          );
        }
        return;
      }
      _legalSelectedCheckTypes = defaults;
      _markDraftDirty();
    }
    unawaited(_startLegalLoading());
  }
}

/// Модал-чеклист прогресса объединённого автозаполнения (см.
/// [_SparkJoyDocScanHelpers._runAutofillScan]). Три стадии: обработка фото,
/// загрузка, распознавание. [stage] — текущий индекс (0..3, 3 = готово);
/// [offline] помечает шаги загрузки/распознавания «пропущено», когда сеть
/// недоступна и поток ушёл в OCR-only.
class _DocScanProgressDialog extends StatelessWidget {
  const _DocScanProgressDialog({required this.stage, required this.offline});

  final ValueListenable<int> stage;
  final ValueListenable<bool> offline;

  static const List<String> _labels = [
    'Обработка фото',
    'Загрузка фото',
    'Распознавание документа',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xxxl,
        vertical: SparkSpace.xxl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SparkRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: SparkSize.modalNarrow),
        child: Padding(
          padding: const EdgeInsets.all(SparkSpace.xxl),
          child: AnimatedBuilder(
            animation: Listenable.merge([stage, offline]),
            builder: (context, _) {
              final current = stage.value;
              final isOffline = offline.value;
              // Без большого спиннера и заголовка «Распознавание…»
              // (фидбек 2026-07-10) — компактный чек-лист стадий сам
              // показывает прогресс мини-индикатором активной строки.
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SparkSpace.sm),
                      child: _row(i, current, isOffline),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(int index, int current, bool isOffline) {
    // Шаги загрузки/распознавания пропущены, когда сеть недоступна.
    final skipped = isOffline && index >= 1;
    final done = current > index && !skipped;
    final active = current == index && !skipped;

    final Widget leading;
    if (done) {
      leading = const Icon(
        Icons.check_circle_rounded,
        color: kGreenColor,
        size: 20,
      );
    } else if (active) {
      leading = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (skipped) {
      leading = const Icon(
        Icons.remove_circle_outline_rounded,
        color: kGreyColor,
        size: 20,
      );
    } else {
      leading = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kBorderColor, width: 2),
        ),
      );
    }

    return Row(
      children: [
        leading,
        const SizedBox(width: SparkSpace.md),
        Expanded(
          child: MyText(
            text: skipped ? '${_labels[index]} — пропущено' : _labels[index],
            size: SparkTextSize.body,
            weight: active ? FontWeight.w700 : FontWeight.w500,
            color: (done || active) ? kTertiaryColor : kGreyColor,
          ),
        ),
      ],
    );
  }
}

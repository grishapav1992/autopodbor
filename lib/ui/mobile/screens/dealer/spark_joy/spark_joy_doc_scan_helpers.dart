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
  Future<void> _openDocScanSourceModal() async {
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
                        'ИИ прочитает документ и заполнит VIN, госномер, '
                        'марку и параметры. Фото хранится в облаке 1 день.',
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
    await _runDocScan(source);
  }

  Future<void> _runDocScan(ImageSource source) async {
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
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) {
      showSparkJoyErrorSnackBar(
        context,
        Exception('Пустой файл фото'),
        fallback: 'Не удалось прочитать фото',
      );
      return;
    }
    _setStateSafely(() {
      _docScanBusy = true;
      _docScanStage = 'Обработка фото…';
    });
    try {
      // Даунскейл+контраст+пережатие ОБЯЗАТЕЛЬНЫ (требование бэка: без сжатия
      // больше токенов vision и дольше ответ) — поэтому гоняем на ВСЕХ
      // платформах, web включительно. На нативе — в изоляте (compute), на web
      // compute = синхронный no-op в главном потоке: короткая пауза под
      // спиннером «Обработка фото…» приемлемее жирного аплоада несжатого фото.
      final prepared = kIsWeb
          ? _sparkPrepareDocScanPhoto(bytes)
          : await compute(_sparkPrepareDocScanPhoto, bytes);
      if (!mounted) return;
      _setStateSafely(() => _docScanStage = 'Загрузка фото…');
      // Случайный суффикс к имени: файл кладётся в ОБЩУЮ папку temp/, а сервер
      // подписывает view-URL по любому запрошенному имени без проверки
      // владельца. Предсказуемый ключ (только время в мс) дал бы другому
      // авторизованному юзеру перебором вытащить чужое фото документа с ПДн.
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
        // Дефолтные 10с не переживают холодный бэк (7-47с на первом хите
        // после простоя) — а сам метод глотает таймаут и возвращает ''.
        timeout: const Duration(seconds: 30),
        // URL нужен на один vision-вызов (≤75с) — не держим сутки живую ссылку
        // на документ с ПДн (дефолт сервера 86400с).
        expiresInSeconds: 120,
      );
      if (viewUrl.isEmpty) {
        throw Exception(
          'Не удалось получить ссылку на загруженное фото '
          '(сервер не ответил вовремя)',
        );
      }
      if (!mounted) return;
      _setStateSafely(() => _docScanStage = 'Распознавание…');
      final chatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: chatId,
        text: 'Распознай документ на фото.',
        cliche: AiQueueClicheBuilder.buildDocScanCliche(),
        fileUrls: [viewUrl],
        timeout: const Duration(seconds: 75),
      );
      // Документ (с ПДн владельца, которые фича намеренно НЕ извлекает) виден
      // модели — не оставляем его в истории чата AiQueue (KV бэка живёт ~6ч).
      // Best-effort: сбой очистки не должен ронять успешный скан.
      unawaited(AiQueueApi.clearChatHistory(chatId: chatId).catchError((_) {}));
      if (!mounted) return;
      final parsed = parseDocScanAiResult(result.text);
      if (!hasAnyDocScanData(parsed)) {
        // Модель ответила, но не разобрала ни одного поля — проблема в фото,
        // а не в транспорте. Подсказываем, как переснять.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ИИ не смог прочитать документ на этом фото. Снимите документ '
              'целиком, без бликов, и попробуйте ещё раз.',
            ),
          ),
        );
        return;
      }
      await _showDocScanPreviewDialog(parsed);
    } catch (e) {
      debugPrint('Doc scan failed at "$_docScanStage": $e');
      if (!mounted) return;
      // Штатный снэкбар ошибок: код (NET-xx/SRV-xx/…) + «Скопировать» —
      // по нему видно, на каком этапе и почему упало распознавание.
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback:
            'Не удалось распознать документ (этап: '
            '${_docScanStage.isEmpty ? 'распознавание' : _docScanStage})',
      );
    } finally {
      if (mounted) {
        _setStateSafely(() {
          _docScanBusy = false;
          _docScanStage = '';
        });
      }
    }
  }

  /// Превью распознанного перед применением: юзер видит, что именно легло бы
  /// в отчёт, и решает. Заполняются ТОЛЬКО пустые поля (ручной ввод
  /// неприкосновенен). Чекбокс «сразу запустить проверки» показывается,
  /// когда проверки ещё не запускались и право есть.
  Future<void> _showDocScanPreviewDialog(DocScanAiResult r) async {
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
                      onTap: () =>
                          setDialogState(() => runChecks = !runChecks),
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
    if (mounted) {
      final parts = <String>[
        if (filled.isNotEmpty) 'Заполнено с документа: ${filled.join(', ')}',
        if (filled.isEmpty && unmatched.isEmpty)
          'Все распознанные поля уже заполнены — ничего не изменено',
        // Строгий режим: несовпавшее с каталогом в поля не пишется.
        if (unmatched.isNotEmpty)
          'Не найдено в каталоге: ${unmatched.join(', ')} — выберите вручную',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.join('. '))),
      );
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

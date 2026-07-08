part of 'spark_joy_create_report_screen.dart';

/// Готовит фото документа к vision-распознаванию: печёт EXIF-ориентацию
/// (после пере-энкода EXIF теряется — без bake текст лёг бы боком),
/// поднимает контраст (мелкий текст на защитной сетке СТС/ПТС читается
/// моделью заметно лучше) и пережимает JPEG компактнее. Best-effort: при
/// сбое декода возвращает исходные байты — скан важнее предобработки.
/// Запускать через `compute`: полный декод фото 2560px — десятки МБ
/// пикселей, на UI-потоке это заметный джанк.
Uint8List _sparkPrepareDocScanPhoto(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final oriented = img.bakeOrientation(decoded);
    final adjusted = img.adjustColor(oriented, contrast: 1.15);
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
/// Фолбэк без сети/ИИ — существующий офлайн OCR-сканер VIN (ML Kit).
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
      // Контраст/ориентация/пережатие в изоляте — текст документа становится
      // читабельнее для модели, а платим меньшим трафиком.
      final prepared = await compute(_sparkPrepareDocScanPhoto, bytes);
      if (!mounted) return;
      _setStateSafely(() => _docScanStage = 'Загрузка фото…');
      final filename =
          'doc_scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      );
      if (viewUrl.isEmpty) {
        throw Exception('Не удалось получить ссылку на загруженное фото');
      }
      if (!mounted) return;
      _setStateSafely(() => _docScanStage = 'Распознавание…');
      final result = await AiQueueApi.chatCompletions(
        chatId: DateTime.now().microsecondsSinceEpoch.toUnsigned(32),
        text: 'Распознай документ на фото.',
        cliche: AiQueueClicheBuilder.buildDocScanCliche(),
        fileUrls: [viewUrl],
        timeout: const Duration(seconds: 75),
      );
      if (!mounted) return;
      final parsed = parseDocScanAiResult(
        result.text,
        allowedEngineTypes: _SparkJoyVehicleRegistry.engineTypes,
        allowedEngineVolumes: _SparkJoyVehicleRegistry.engineVolumeOptions,
      );
      if (!hasAnyDocScanData(parsed)) {
        await _showDocScanFallbackDialog(
          'ИИ не смог прочитать документ на фото. Попробуйте другое фото '
          '(без бликов, документ целиком) или офлайн-сканер VIN.',
          source,
        );
        return;
      }
      await _showDocScanPreviewDialog(parsed);
    } catch (e) {
      debugPrint('Doc scan failed: $e');
      if (!mounted) return;
      await _showDocScanFallbackDialog(
        'ИИ-распознавание сейчас недоступно. Можно распознать VIN '
        'офлайн-сканером (без интернета).',
        source,
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

  /// Сеть/ИИ недоступны или ничего не распозналось → предлагаем существующий
  /// офлайн OCR-сканер VIN (ML Kit) — тот самый «если нет интернета, выбрать
  /// OCR-распознавание».
  Future<void> _showDocScanFallbackDialog(
    String message,
    ImageSource source,
  ) async {
    if (!mounted) return;
    final useOcr = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkRadius.xl),
        ),
        title: const MyText(
          text: 'Распознавание не удалось',
          size: SparkTextSize.titleLg,
          weight: FontWeight.w700,
        ),
        content: MyText(
          text: message,
          size: SparkTextSize.body,
          color: kTertiaryColor,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Закрыть'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('OCR-сканер VIN'),
          ),
        ],
      ),
    );
    if (useOcr == true && mounted) {
      await _openVinScannerDialog(initialSource: source);
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
      if (r.engineVolume.isNotEmpty) ('Объём двигателя', '${r.engineVolume} л'),
      if (r.engineType.isNotEmpty) ('Тип топлива', r.engineType),
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
        filled.add('VIN');
      }
      if (r.gosNumber.isNotEmpty && _plateController.text.trim().isEmpty) {
        _applyDetectedPlate(r.gosNumber);
        filled.add('госномер');
      }
      // Объём/топливо/цвет пишем как РУЧНОЙ ввод — НАМЕРЕННО без
      // _vinAutofilledValues: запись туда пометила бы значения документа
      // «ИИ-остатками прежней машины», и stale-очистка
      // _autofillParamsFromVinWithAi стёрла бы их через 600 мс, заменив
      // догадками модели. Документ авторитетнее ИИ; цена — при смене VIN
      // эти поля не чистятся автоматически (как и любой ручной ввод).
      final byKey = _vinParamTargetsByKey();
      if (r.engineVolume.isNotEmpty &&
          byKey['engineVolume']!.text.trim().isEmpty) {
        byKey['engineVolume']!.text = r.engineVolume;
        filled.add('объём');
      }
      if (r.engineType.isNotEmpty &&
          byKey['engineType']!.text.trim().isEmpty) {
        byKey['engineType']!.text = r.engineType;
        filled.add('топливо');
      }
      if (r.color.isNotEmpty && _colorController.text.trim().isEmpty) {
        _colorController.text = r.color;
        filled.add('цвет');
      }
    });
    final vinNow = _sanitizeVin(_vinController.text);
    final brandNow = _brandController.text.trim();
    final modelNow = _modelController.text.trim();
    if (vinNow.length == 17 && brandNow.isNotEmpty && modelNow.isNotEmpty) {
      // Идентификация известна → платному VIN→марка/модель резолву делать
      // нечего. Блокируем ЯВНО, дедуп-флагом конвейера: первая проверка
      // _maybeAutoResolveIdentityFromVin выходит по нему ДО stale-блока,
      // поэтому и _resolvedVinYear (год из документа) уцелеет. Полагаться
      // на порядок записи полей нельзя — гейт читает состояние контроллеров
      // через 600 мс дебаунса, а не в момент записи.
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

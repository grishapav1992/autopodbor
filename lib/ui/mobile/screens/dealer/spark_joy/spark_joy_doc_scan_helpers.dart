part of 'spark_joy_create_report_screen.dart';

/// Скан СТС/ПТС: фото документа → S3 `temp/` (lifecycle-правило бакета удаляет
/// через 1 день) → AiQueue vision (`fileUrls`) → строгий JSON → превью →
/// only-empty автозаполнение «Автомобиля» и «Параметров».
///
/// Экономика ApiCloud заложена в порядок записи полей:
///   • марка/модель пишутся ДО VIN, поэтому когда дебаунс-конвейер
///     `_maybeResolveFromVin` доходит до `_maybeAutoResolveIdentityFromVin`,
///     идентификация уже заполнена → платный конвертер НЕ запускается;
///   • `_startLegalLoading` дёргает конвертер только при пустом VIN — после
///     скана VIN заполнен, конверсия госномер→VIN не оплачивается;
///   • недостающие КПП/привод дозаполнит существующий бесплатный ИИ-шаг
///     `_autofillParamsFromVinWithAi`, который триггерится записью VIN.
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
      _docScanStage = 'Загрузка фото…';
    });
    try {
      final filename =
          'doc_scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final upload = await storage_api.StorageApi.getTemporaryUploadUrl(
        reportNumber: 'temp',
        filename: filename,
      );
      await storage_api.StorageApi.uploadBytesToPresignedUrl(
        url: upload.url,
        bytes: bytes,
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
      _applyDocScanResult(r, runChecks: runChecks && canOfferChecks);
    }
  }

  void _applyDocScanResult(DocScanAiResult r, {required bool runChecks}) {
    final filled = <String>[];
    _setStateSafely(() {
      // Идентификация ДО VIN: когда дебаунс-конвейер дойдёт до
      // _maybeAutoResolveIdentityFromVin, марка/модель уже стоят →
      // only-empty гейт вернёт true без платного конвертера.
      var identityWritten = false;
      if (r.brand.isNotEmpty && _brandController.text.trim().isEmpty) {
        _brandController.text = r.brand;
        identityWritten = true;
        filled.add('марка');
      }
      if (r.model.isNotEmpty && _modelController.text.trim().isEmpty) {
        _modelController.text = r.model;
        identityWritten = true;
        filled.add('модель');
      }
      if (identityWritten) {
        // Сырой текст с документа ≠ каталожный выбор — сбрасываем привязку
        // (тот же контракт, что у конвертера в _startLegalLoading).
        _clearCatalogCarMeta();
        _selectedBrandId = null;
        _selectedModelCarId = null;
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
      final byKey = _vinParamTargetsByKey();
      final params = <String, String>{
        'engineVolume': r.engineVolume,
        'engineType': r.engineType,
      };
      params.forEach((key, value) {
        if (value.isEmpty) return;
        final controller = byKey[key]!;
        if (controller.text.trim().isNotEmpty) return;
        controller.text = value;
        // Документ — источник того же ранга, что ГОСТ-серт: трекаем запись,
        // чтобы смена VIN чистила незатронутое (staleVinAutofillKeys), а
        // ИИ-шаг не перетёр (его only-empty это уважает).
        _vinAutofilledValues[key] = value;
        filled.add(key == 'engineVolume' ? 'объём' : 'топливо');
      });
      if (r.color.isNotEmpty && _colorController.text.trim().isEmpty) {
        // Цвет вне _vinParamTargetsByKey (VIN-ИИ его не определяет) — пишем
        // без stale-трекинга.
        _colorController.text = r.color;
        filled.add('цвет');
      }
    });
    _markDraftDirty();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            filled.isEmpty
                ? 'Все распознанные поля уже заполнены — ничего не изменено'
                : 'Заполнено с документа: ${filled.join(', ')}',
          ),
        ),
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
      if (defaults.isEmpty) return; // каталог не загрузился — запустят вручную
      _legalSelectedCheckTypes = defaults;
      _markDraftDirty();
    }
    unawaited(_startLegalLoading());
  }
}

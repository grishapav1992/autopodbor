part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyVehicleBusinessHelpers on _SparkJoyCreateReportScreenState {
  String _dateLabel(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  Future<void> _loadBusinessStatusFromStorage() async {
    final businessType = await SparkJoyStorage.currentBusinessType();
    final verifiedInn = await SparkJoyStorage.currentVerifiedInn();
    if (!mounted) return;
    _setStateSafely(() {
      _accountBusinessType ??= businessType;
      _accountVerifiedInn ??= verifiedInn;
    });
  }

  bool _hasBusinessStatus() {
    return _accountBusinessType == 'company' || _accountBusinessType == 'ip';
  }

  String _currentCompanyName() {
    final company = sparkCompanies.firstWhere(
      (item) => (item['id'] ?? '').toString() == kSparkCompanyId,
      orElse: () => const {'name': 'Компания'},
    );
    final name = (company['name'] ?? '').toString().trim();
    return name.isEmpty ? 'Компания' : name;
  }

  String _resolveSpecialistName(String specialistId) {
    if (specialistId.trim().isEmpty) return '';
    final specialist = sparkSpecialists.firstWhere(
      (item) => (item['id'] ?? '').toString() == specialistId,
      orElse: () => const {},
    );
    return (specialist['name'] ?? '').toString();
  }

  InputDecoration _fieldDecoration(String hint) {
    return sparkInputDecoration(hint);
  }

  String _carName() {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final generation = _generationController.text.trim();
    return [brand, model, generation].where((e) => e.isNotEmpty).join(' ');
  }

  /// Compact `brand, model, generation, restyling, engine + transmission`
  /// string for AI cliché. Empty → returns `null` so the cliché can
  /// skip the «Контекст автомобиля» block entirely instead of
  /// rendering an awkward `Контекст автомобиля: .` line.
  String? _carContextForAi() {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final generation = _generationController.text.trim();
    final restyling = _restylingLabel.trim();
    final frames = _carFrames.trim();
    final volume = _engineVolumeController.text.trim();
    final engineType = _engineTypeController.text.trim();
    final gearbox = _gearboxTypeController.text.trim();
    final drive = _driveTypeController.text.trim();

    final core = [brand, model].where((s) => s.isNotEmpty).join(' ');
    final genPart = generation.isEmpty ? '' : 'поколение $generation';
    final yearPart = frames.isEmpty ? '' : frames; // e.g. «2014-2017»
    final engineParts = <String>[
      if (volume.isNotEmpty) volume,
      if (engineType.isNotEmpty) engineType,
    ].join(' ');
    // Gearbox + drive go as separate items so the model can't read
    // them as one phrase like «АКПП передний». «передний привод»
    // is the canonical full form so the model has unambiguous tokens.
    final segments = <String>[
      if (core.isNotEmpty) core,
      if (genPart.isNotEmpty) genPart,
      // Поле «Поколение» теперь несёт период выбранного рестайлинга, поэтому
      // подпись рестайлинга часто совпадает с ним — не дублируем.
      if (restyling.isNotEmpty && restyling != generation) restyling,
      if (yearPart.isNotEmpty) yearPart,
      if (engineParts.isNotEmpty) engineParts,
      if (gearbox.isNotEmpty) gearbox,
      if (drive.isNotEmpty) '$drive привод',
    ];
    if (segments.isEmpty) return null;
    return segments.join(', ');
  }

  String _sanitizeVin(String value) {
    final cleaned = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceAll(RegExp(r'[IOQ]'), '');
    return cleaned.length > 17 ? cleaned.substring(0, 17) : cleaned;
  }

  /// Сопоставляет марку/модель (как их вернул конвертер/скан/черновик) с
  /// каталогом — тонкий адаптер над [CarCatalogRepository.resolveCar]
  /// (cache-first: офлайн работает от персиста; сетевые ошибки внутри →
  /// null). Возвращает каноничные имена + серверные id (`full=true`, если
  /// нашлись и марка, и модель), либо `null`, если марки нет в каталоге или
  /// каталог недоступен (кэш пуст + офлайн). Поколение здесь не трогаем —
  /// его пользователь выбирает сам (поле необязательное).
  Future<
    ({String brand, String model, int? brandId, int? modelCarId, bool full})?
  >
  _resolveCarFromCatalog(String brand, String model) async {
    final match = await CarCatalogRepository.instance.resolveCar(brand, model);
    if (match == null) return null;
    return (
      brand: match.brand.name,
      model: match.model?.model ?? model,
      brandId: match.brand.id,
      modelCarId: match.model?.id,
      full: match.full,
    );
  }

  /// Ре-байнд легаси-черновика к каталогу: строгий режим всегда пишет ID, но
  /// старые черновики хранят свободный текст марки/модели. Успех → канон +
  /// ID (как выбор руками); неуспех (нет в каталоге / кэш пуст офлайн) —
  /// поля остаются как есть, карточка показывает пометку «не привязано к
  /// каталогу», а выгрузку в самом конце всё равно гейтит
  /// [_ensureModelCarIdForUpload] (RPT-01).
  Future<void> _rebindCarFromCatalogIfNeeded() async {
    final brand = _brandController.text.trim();
    if (brand.isEmpty || _selectedBrandId != null) return;
    final model = _modelController.text.trim();
    final resolved = await _resolveCarFromCatalog(brand, model);
    if (!mounted || resolved == null) return;
    // Пользователь успел поменять поля, пока резолвили — не затираем.
    if (_brandController.text.trim() != brand ||
        _modelController.text.trim() != model ||
        _selectedBrandId != null) {
      return;
    }
    _setStateSafely(() {
      _brandController.text = resolved.brand;
      _selectedBrandId = resolved.brandId;
      if (resolved.full && resolved.modelCarId != null) {
        _modelController.text = resolved.model;
        _selectedModelCarId = resolved.modelCarId;
      }
    });
    _markDraftDirty();
  }

  /// Единый VIN из результата OCR: `rawText` разбирается построчно (см.
  /// [extractVinCandidatesFromOcrText]), а платформенный `result.vin`
  /// участвует как ещё одна отдельная строка-кандидат, НЕ как доверенное
  /// значение. ВНИМАНИЕ (web): web/vin_ocr.js до сих пор извлекает свой
  /// `vin` «супом» по всему тексту — сейчас это безопасно только потому, что
  /// строгий потребитель (OCR-свип интейка) на web мёртв (dart:io File);
  /// при оживлении web-свипа JS-извлечение нужно переводить на построчное.
  String _extractVinFromOcrResult(
    VinOcrResult result, {
    VinExtractionMode mode = VinExtractionMode.lenient,
  }) {
    final combined = result.vin.trim().isEmpty
        ? result.rawText
        : '${result.rawText}\n${result.vin}';
    return extractVinFromOcrText(combined, mode: mode);
  }

  bool _isStrictVin(String value) => isStrictVin(value);

  bool _isValidVinChecksum(String vin) => isValidVinChecksum(vin);

  String _sanitizePlate(String value) {
    // Country-aware sanitization. The active [_plateCountry] decides
    // which alphabet is allowed (Cyrillic ABEKMHOPCTYX for РФ/BY,
    // Latin A-Z for KZ/AM/KG/UZ) and the max length cap. See
    // [spark_joy_plate_formats.dart].
    return sanitizePlate(value, _plateFormat);
  }

  String _formatPlate(String sanitized) {
    return formatPlate(sanitized, _plateFormat);
  }

  String? _vinError() {
    final vin = _vinController.text.trim().toUpperCase();
    if (vin.isEmpty) return null;
    if (vin.length < 17) return 'Введено ${vin.length} из 17 символов';
    if (RegExp(r'[IOQ]').hasMatch(vin)) {
      return 'VIN не может содержать буквы I, O, Q';
    }
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin)) {
      return 'Некорректный формат VIN';
    }
    if (!RegExp(r'[A-Z]').hasMatch(vin) || !RegExp(r'\d').hasMatch(vin)) {
      return 'VIN должен содержать буквы и цифры';
    }
    return null;
  }

  String? _plateError() {
    // Не показываем ошибку формата пока инспектор печатает — только
    // после первой потери фокуса. На свежем экране это даёт спокойный
    // ввод; при возврате к черновику blur уже выставлен в init.
    if (!_plateBlurred) return null;
    return plateError(_plateController.text.trim(), _plateFormat);
  }
}

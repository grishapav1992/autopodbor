part of 'spark_joy_create_report_screen.dart';

const List<int> _vinWeights = [
  8,
  7,
  6,
  5,
  4,
  3,
  2,
  10,
  0,
  9,
  8,
  7,
  6,
  5,
  4,
  3,
  2,
];

const Map<String, int> _vinTransliteration = {
  'A': 1,
  'B': 2,
  'C': 3,
  'D': 4,
  'E': 5,
  'F': 6,
  'G': 7,
  'H': 8,
  'J': 1,
  'K': 2,
  'L': 3,
  'M': 4,
  'N': 5,
  'P': 7,
  'R': 9,
  'S': 2,
  'T': 3,
  'U': 4,
  'V': 5,
  'W': 6,
  'X': 7,
  'Y': 8,
  'Z': 9,
  '0': 0,
  '1': 1,
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
};

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

  String _normalizeVinOcrText(String value) {
    return value
        .toUpperCase()
        .replaceAll('А', 'A')
        .replaceAll('В', 'B')
        .replaceAll('С', 'C')
        .replaceAll('Е', 'E')
        .replaceAll('Н', 'H')
        .replaceAll('К', 'K')
        .replaceAll('М', 'M')
        .replaceAll('Р', 'P')
        .replaceAll('Т', 'T')
        .replaceAll('У', 'Y')
        .replaceAll('Х', 'X')
        .replaceAll('З', '3')
        .replaceAll('Б', '6')
        .replaceAll('І', '1')
        .replaceAll('|', '1')
        .replaceAll('I', '1')
        .replaceAll('O', '0')
        .replaceAll('Q', '0');
  }

  String _extractStrictVinFromText(String text) {
    final cleaned = _normalizeVinOcrText(
      text,
    ).replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length < 17) return '';
    for (var i = 0; i <= cleaned.length - 17; i++) {
      final candidate = cleaned.substring(i, i + 17);
      if (_isStrictVin(candidate)) {
        return _maybeFixVinOcrAmbiguity(candidate);
      }
    }
    return '';
  }

  String _extractVinFromOcrResult(VinOcrResult result) {
    final direct = _extractStrictVinFromText(result.vin);
    if (direct.isNotEmpty) return direct;
    return _extractStrictVinFromText(result.rawText);
  }

  bool _isStrictVin(String value) {
    final vin = value.trim().toUpperCase();
    if (vin.length != 17) return false;
    if (RegExp(r'[IOQ]').hasMatch(vin)) return false;
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin)) return false;
    if (!RegExp(r'[A-Z]').hasMatch(vin) || !RegExp(r'\d').hasMatch(vin)) {
      return false;
    }
    return true;
  }

  bool _isValidVinChecksum(String vin) {
    if (!_isStrictVin(vin)) return false;
    var sum = 0;
    for (var i = 0; i < vin.length; i++) {
      final value = _vinTransliteration[vin[i]];
      if (value == null) return false;
      sum += value * _vinWeights[i];
    }
    final remainder = sum % 11;
    final expected = remainder == 10 ? 'X' : remainder.toString();
    return vin[8] == expected;
  }

  String _toggleVinAmbiguousChar(String vin, int index) {
    if (index < 0 || index >= vin.length) return vin;
    final ch = vin[index];
    if (ch != '1' && ch != 'L') return vin;
    final replacement = ch == '1' ? 'L' : '1';
    return vin.substring(0, index) + replacement + vin.substring(index + 1);
  }

  String _maybeFixVinOcrAmbiguity(String value) {
    final vin = value.trim().toUpperCase();
    if (!_isStrictVin(vin)) return vin;
    if (_isValidVinChecksum(vin)) return vin;

    final ambiguousIndexes = <int>[];
    for (var i = 0; i < vin.length; i++) {
      if (i == 8) continue;
      if (vin[i] == '1' || vin[i] == 'L') {
        ambiguousIndexes.add(i);
      }
    }
    if (ambiguousIndexes.isEmpty) return vin;

    final validCandidates = <String>{};

    for (final index in ambiguousIndexes) {
      final candidate = _toggleVinAmbiguousChar(vin, index);
      if (_isStrictVin(candidate) && _isValidVinChecksum(candidate)) {
        validCandidates.add(candidate);
      }
    }

    const maxPairChecks = 28;
    var pairChecks = 0;
    for (var i = 0; i < ambiguousIndexes.length; i++) {
      for (var j = i + 1; j < ambiguousIndexes.length; j++) {
        if (pairChecks >= maxPairChecks) break;
        pairChecks += 1;
        final first = _toggleVinAmbiguousChar(vin, ambiguousIndexes[i]);
        final candidate = _toggleVinAmbiguousChar(first, ambiguousIndexes[j]);
        if (_isStrictVin(candidate) && _isValidVinChecksum(candidate)) {
          validCandidates.add(candidate);
        }
      }
      if (pairChecks >= maxPairChecks) break;
    }

    if (validCandidates.length == 1) {
      return validCandidates.first;
    }
    return vin;
  }

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

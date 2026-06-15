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
      if (restyling.isNotEmpty) restyling,
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

  /// Сопоставляет марку/модель (как их вернул конвертер по VIN/госномеру) с
  /// каталогом — чтобы результат совпадал с ручным выбором. Приоритет —
  /// онлайн `GetBrand`/`GetModel` (`fetchBrandCatalog`/`fetchModels`); при
  /// отсутствии сети — фолбэк на локальный `_SparkJoyVehicleRegistry`.
  /// Возвращает каноничные имена из каталога (`full=true`, если нашлись и
  /// марка, и модель), либо `null`, если марки в каталоге нет совсем. Поколение
  /// здесь не трогаем — его пользователь выбирает сам (поле необязательное).
  Future<
    ({String brand, String model, int? brandId, int? modelCarId, bool full})?
  >
  _resolveCarFromCatalog(String brand, String model) async {
    bool eq(String a, String b) =>
        a.trim().isNotEmpty && a.trim().toLowerCase() == b.trim().toLowerCase();
    if (brand.trim().isEmpty) return null;

    // 1) Онлайн-каталог (приоритет): GetBrand → GetModel. Возвращаем и
    // серверные id (brandId/modelCarId) — они привязывают авто к каталогу
    // (как ручной выбор из списка) и нужны автокомплиту моделей.
    try {
      final catalog = await storage_api.StorageApi.fetchBrandCatalog();
      for (final b in catalog.items) {
        if (!eq(b.name, brand) && !eq(b.nameRus, brand)) continue;
        try {
          final models = await storage_api.StorageApi.fetchModels(
            brandId: b.id,
          );
          for (final m in models) {
            if (eq(m.model, model) || eq(m.modelRus, model)) {
              return (
                brand: b.name,
                model: m.model,
                brandId: b.id,
                modelCarId: m.id,
                full: true,
              );
            }
          }
        } catch (_) {}
        return (
          brand: b.name,
          model: model,
          brandId: b.id,
          modelCarId: null,
          full: false,
        );
      }
    } catch (_) {
      // нет сети / бэк недоступен → локальный фолбэк ниже
    }

    // 2) Локальный каталог (офлайн-фолбэк) — без серверных id.
    for (final b in _SparkJoyVehicleRegistry.carCatalog) {
      if (!eq(b.name, brand)) continue;
      for (final m in b.models) {
        if (eq(m.name, model)) {
          return (
            brand: b.name,
            model: m.name,
            brandId: null,
            modelCarId: null,
            full: true,
          );
        }
      }
      return (
        brand: b.name,
        model: model,
        brandId: null,
        modelCarId: null,
        full: false,
      );
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────────
  //  Автокомплит марки/модели из каталога (Storage.GetBrand / GetModelCar)
  // ──────────────────────────────────────────────────────────────────

  /// Лениво (один раз) грузит весь каталог марок для автокомплита; дальше
  /// фильтрация локальная. Безопасно звать из onTap/optionsBuilder — guard
  /// `_brandCatalogLoadStarted` держит единственный сетевой запрос; при ошибке
  /// guard сбрасывается, чтобы повторный фокус попробовал снова.
  Future<void> _ensureBrandCatalogLoaded() async {
    if (_brandCatalogLoadStarted || _brandCatalogCache.isNotEmpty) return;
    _brandCatalogLoadStarted = true;
    try {
      final catalog = await storage_api.StorageApi.fetchBrandCatalog();
      if (!mounted) return;
      _setStateSafely(() => _brandCatalogCache = catalog.items);
    } catch (_) {
      // Офлайн / бэк недоступен → подсказок нет, но свободный ввод работает.
      _brandCatalogLoadStarted = false;
    }
  }

  /// Догружает модели для выбранной марки (`_selectedBrandId`) в кэш. Зовём при
  /// фокусе поля модели — покрывает все источники привязки (автокомплит марки,
  /// конвертер, пикер, восстановленный черновик).
  Future<void> _ensureModelsForSelectedBrand() async {
    final brandId = _selectedBrandId;
    if (brandId == null) return;
    await _prefetchModels(brandId);
  }

  /// Грузит модели для марки в кэш `_modelsByBrandId` (один раз на brandId).
  /// Кэш по id делает поздний ответ при быстрой смене марки безвредным.
  Future<void> _prefetchModels(int brandId) async {
    if (_modelsByBrandId.containsKey(brandId)) return;
    try {
      final models = await storage_api.StorageApi.fetchModels(brandId: brandId);
      if (!mounted) return;
      _setStateSafely(() => _modelsByBrandId[brandId] = models);
    } catch (_) {
      // Офлайн → подсказок моделей не будет; свободный ввод работает.
    }
  }

  /// Опции автокомплита марки: локальная фильтрация кэша по name/nameRus.
  Iterable<storage_api.BrandItem> _brandAutocompleteOptions(String query) {
    if (_brandCatalogCache.isEmpty) return const <storage_api.BrandItem>[];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _brandCatalogCache;
    return _brandCatalogCache.where(
      (b) =>
          b.name.toLowerCase().contains(q) ||
          b.nameRus.toLowerCase().contains(q),
    );
  }

  /// Опции автокомплита модели для выбранной марки. Без выбранной марки —
  /// пусто (поле ведёт себя как обычный TextField).
  Iterable<storage_api.ModelItem> _modelAutocompleteOptions(String query) {
    final brandId = _selectedBrandId;
    if (brandId == null) return const <storage_api.ModelItem>[];
    final models = _modelsByBrandId[brandId];
    if (models == null || models.isEmpty) {
      return const <storage_api.ModelItem>[];
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return models;
    return models.where(
      (m) =>
          m.model.toLowerCase().contains(q) ||
          m.modelRus.toLowerCase().contains(q),
    );
  }

  /// Выбор марки из списка: каноничное имя + привязка к каталогу; сброс
  /// модели/поколения/каталожной меты (как пикер при смене марки) + префетч
  /// моделей. Пишем `.text` ПРОГРАММНО → `TextField.onChanged` не сработает,
  /// поэтому `_onCarIdentityEdited` не затрёт только что выставленную привязку.
  void _onBrandAutocompleteSelected(storage_api.BrandItem brand) {
    _setStateSafely(() {
      _brandController.text = brand.name;
      _selectedBrandId = brand.id;
      _modelController.clear();
      _generationController.clear();
      _selectedModelCarId = null;
      _clearCatalogCarMeta();
    });
    _markDraftDirty();
    unawaited(_prefetchModels(brand.id));
  }

  /// Выбор модели из списка: каноничное имя + привязка. Поколение/фото на
  /// уровне модели не определяются (как `buildSelectionForModel` в пикере) —
  /// для них есть кнопка «Выбрать из каталога».
  void _onModelAutocompleteSelected(storage_api.ModelItem model) {
    _setStateSafely(() {
      _modelController.text = model.model;
      _selectedModelCarId = model.id;
      _selectedBrandId ??= model.brandId;
      _generationController.clear();
      _clearCatalogCarMeta();
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
    if (_vinUnreadable) return null;
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

  /// Открывает modal bottom sheet с выбором страны для госномера.
  /// Sheet возвращает `(auto: bool, country: PlateCountry?)`:
  /// - dismissed (null) → ничего не делаем.
  /// - auto=true → снимаем lock, прогоняем текущий текст через детектор;
  ///   если матч → показываем флаг и переформатируем, иначе → переходим
  ///   в `PlateCountry.other` (UI: «Не определено»).
  /// - auto=false + country=X → ставим lock на X, пересушиваем текст под
  ///   X-whitelist и применяем X-раскладку (RU→KZ выкинет кириллицу,
  ///   RU→AB обрежет регион и т.п.).
  Future<void> _showPlateCountryPicker(
    BuildContext context,
    void Function(VoidCallback fn) setStateFn,
  ) async {
    final picked = await showModalBottomSheet<_PlatePicked>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PlateCountryPickerSheet(
        current: _plateCountry,
        locked: _plateCountryLocked,
      ),
    );
    if (picked == null) return;
    if (picked.auto) {
      // Если уже в auto и страна не меняется — выходим без ререндера.
      if (!_plateCountryLocked) return;
      setStateFn(() {
        _plateCountryLocked = false;
        final permissive = sanitizePlatePermissive(_plateController.text);
        final detected = detectPlateCountry(permissive);
        _plateCountry = detected ?? PlateCountry.other;
        final String formatted;
        if (detected != null) {
          final fmt = plateFormatFor(detected);
          formatted = formatPlate(sanitizePlate(permissive, fmt), fmt);
        } else {
          formatted = permissive;
        }
        _plateController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      });
      _markDraftDirty();
      return;
    }
    final country = picked.country!;
    if (_plateCountryLocked && country == _plateCountry) return;
    setStateFn(() {
      _plateCountryLocked = true;
      _plateCountry = country;
      final resanitized = _sanitizePlate(_plateController.text);
      final reformatted = _formatPlate(resanitized);
      _plateController.value = TextEditingValue(
        text: reformatted,
        selection: TextSelection.collapsed(offset: reformatted.length),
      );
    });
    _markDraftDirty();
  }
}

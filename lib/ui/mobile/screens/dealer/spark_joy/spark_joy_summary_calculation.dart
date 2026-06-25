part of 'spark_joy_create_report_screen.dart';

extension _SparkJoySummaryCalculation on _SparkJoyCreateReportScreenState {
  /// Поллит `GetBatchLegalReviewResults` пока все проверки не выйдут из
  /// pending (или пока не упрёмся в потолок попыток → `_legalTimedOut`).
  /// [token] отсекает устаревший прогон; выходим, если экран закрыт или
  /// стартовал новый прогон.
  Future<void> _pollLegalBatchResults(int token, String batchNumber) async {
    const interval = Duration(seconds: 3);
    // ~180s потолок: live ApiCloud-проверки идут десятки секунд, но отдельные
    // (zalog_notary) доходили до ~104с — берём запас, чтобы не таймаутить почти
    // готовое. Недозавершённые к таймауту не теряются — hydrator подтянет их
    // по batches при повторном открытии завершённого отчёта.
    const maxAttempts = 60;
    var emptyStreak = 0;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future<void>.delayed(interval);
      if (!mounted || token != _legalLoadToken) return;
      Map<String, dynamic> result;
      try {
        result = await storage_api.StorageApi.getBatchLegalReviewResults(
          batchNumber: batchNumber,
        );
      } catch (_) {
        continue; // transient — повторим на следующем тике
      }
      if (!mounted || token != _legalLoadToken) return;
      final rawChecks = result['checks'];
      final checks = rawChecks is List
          ? rawChecks
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      if (checks.isEmpty) {
        // Пустой ответ: бэкенд ещё не зарегистрировал проверки или batch пуст.
        // Несколько коротких попыток вместо траты всего ~120с потолка.
        if (++emptyStreak >= 3) break;
        continue;
      }
      emptyStreak = 0;
      _setStateSafely(() => _legalCheckResults = checks);
      if (!storage_api.legalReviewBatchPending(checks)) {
        _setStateSafely(() {
          _legalLoading = false;
          _legalLoaded = true;
          _legalTimedOut = false;
        });
        _markDraftDirty();
        // ГОСТ-сертификат пришёл с проверками → дозаполнить «Параметры»
        // (объём/тип двигателя/КПП) официальными данными серта, приоритетнее
        // ИИ. Идемпотентно (см. _autofillParamsFromGostCert в dictation_rules).
        _autofillParamsFromGostCert();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Материалы проверки готовы')),
          );
        }
        return;
      }
    }
    if (!mounted || token != _legalLoadToken) return;
    _setStateSafely(() {
      _legalLoading = false;
      _legalTimedOut = true;
    });
    _markDraftDirty();
    // ГОСТ мог доехать терминально даже при таймауте батча — пробуем (no-op,
    // если сертификата нет / уже заполнено).
    _autofillParamsFromGostCert();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Проверки ещё выполняются — подтянутся позже'),
        ),
      );
    }
  }

  /// Однократно подгружает мета-данные шага «Материалы проверки»:
  /// право `run_legal_review` (из кэша прав, который B1 сидит на старте) и
  /// каталог доступных типов проверок. Безопасно звать из build шага —
  /// guard `_legalReviewMetaLoadStarted` гарантирует один запуск, а setState
  /// происходит только после await (не во время build).
  Future<void> _ensureLegalReviewMeta() async {
    // Право читаем НЕ один раз: на первом логине кэш прав ещё пуст (его пишет
    // PermissionsController.syncFromServer параллельно), и одноразовый guard
    // навсегда спрятал бы фичу у авторизованного юзера. Перечитываем prefs
    // (дёшево) на каждый вызов, пока право не появится; как только выдано —
    // больше не перечитываем.
    if (!_legalCanRunReview) {
      try {
        final perms = await UserSimplePreferences.getPermissions();
        if (mounted && perms.contains('run_legal_review')) {
          _setStateSafely(() => _legalCanRunReview = true);
        }
      } catch (_) {}
    }
    // Каталог типов проверок — сетевой запрос, тянем один раз.
    if (_legalReviewMetaLoadStarted) return;
    _legalReviewMetaLoadStarted = true;
    try {
      final types =
          await storage_api.StorageApi.getAvailableLegalReviewCheckTypes();
      // Конвертер (api_cloud_converter_search) — инструмент идентификации в
      // шаге «Автомобиль», а НЕ материал проверки. В «Материалах проверки»
      // показываем только содержательные проверки (залог/ГОСТ/такси/ФГИС).
      final filtered = types
          .where((t) => t.value != 'api_cloud_converter_search')
          .toList();
      if (mounted && filtered.isNotEmpty) {
        _setStateSafely(() => _legalAvailableCheckTypes = filtered);
      }
    } catch (_) {}
  }

  // ── Дедуп/кэш конвертера ───────────────────────────────────────────────
  // Конвертер платный (RunBatchLegalReview). Один и тот же вход не должен
  // оплачиваться повторно: кэшируем терминальный результат и схлопываем
  // одновременные запросы на один вход (single-flight). timedOut НЕ кэшируем —
  // даём повторить позже, когда воркер ApiCloud догонит.
  String _converterKey({String? vin, String? gosNumber}) {
    final v = (vin ?? '').trim().toUpperCase();
    if (v.isNotEmpty) return 'vin:$v';
    return 'gos:${(gosNumber ?? '').trim().toUpperCase()}';
  }

  Future<storage_api.VinPlateConverterResult> _runConverterDeduped({
    String? vin,
    String? gosNumber,
    void Function(int pollIndex, Duration elapsed)? onProgress,
  }) {
    final key = _converterKey(vin: vin, gosNumber: gosNumber);
    final cached = _converterResultCache[key];
    if (cached != null) return Future.value(cached);
    final inFlight = _converterInFlight[key];
    if (inFlight != null) return inFlight;
    final future =
        _resolveConverterReusingBatch(
              key: key,
              vin: vin,
              gosNumber: gosNumber,
              onProgress: onProgress,
            )
            .then((r) {
              // Кэшируем только терминальный итог (found/not_found). timedOut —
              // транзиентный (воркер лагает), кэшировать нельзя, иначе залипнет.
              if (!r.timedOut) _converterResultCache[key] = r;
              return r;
            })
            .whenComplete(() {
              // Стрелочный callback вернул бы значение Map.remove — тот же самый
              // отслеживаемый Future. Future.whenComplete начал бы ждать сам себя,
              // поэтому UI-await/finally никогда бы не продолжились.
              _converterInFlight.remove(key);
            });
    _converterInFlight[key] = future;
    return future;
  }

  /// Резолвит конвертер, ПЕРЕИСПОЛЬЗУЯ уже оплаченный батч, если он сохранён
  /// (в пределах TTL). Платный [startVinPlateConverter] вызывается ТОЛЬКО когда
  /// живого батча для входа нет. Иначе — бесплатный дочит существующего
  /// (`pollVinPlateConverterBatch`). Это и спасает медленный (~84с) результат,
  /// потерянный при перезагрузке страницы, и не даёт повторному тапу оплатить
  /// тот же вход ещё раз. batchNumber сохраняется ДО опроса, чтобы прерывание
  /// не потеряло оплаченный запуск.
  Future<storage_api.VinPlateConverterResult> _resolveConverterReusingBatch({
    required String key,
    String? vin,
    String? gosNumber,
    void Function(int pollIndex, Duration elapsed)? onProgress,
  }) async {
    var batchNumber = await SparkJoyStorage.loadConverterBatchNumber(key);
    final reused = batchNumber != null && batchNumber.isNotEmpty;
    if (!reused) {
      batchNumber = await storage_api.StorageApi.startVinPlateConverter(
        vin: vin,
        gosNumber: gosNumber,
      );
      if (batchNumber.isEmpty) {
        return (
          found: false,
          vin: '',
          gosNumber: '',
          brand: '',
          model: '',
          year: null,
          timedOut: false,
        );
      }
      await SparkJoyStorage.saveConverterBatchNumber(key, batchNumber);
    }
    final result = await storage_api.StorageApi.pollVinPlateConverterBatch(
      batchNumber,
      onProgress: onProgress,
    );
    if (reused && result.timedOut) {
      // Переиспользованный батч так и не доехал → сбрасываем, чтобы следующая
      // попытка стартовала свежий чек, а не опрашивала «мёртвый» вечно.
      await SparkJoyStorage.removeConverterBatchNumber(key);
    }
    return result;
  }

  /// Фоновая канонизация марки/модели по каталогу (GetBrand/GetModelCar) после
  /// конвертера. Вызывается через `unawaited`, поэтому НЕ держит спиннер
  /// конвертера (`_vinConverterBusy`): сырой результат уже показан, а медленный
  /// каталог на перегруженном бэке больше не «крутит» заявку (регресс fd4ce65).
  /// Каноничные имена + brandId/modelCarId применяем ТОЛЬКО если пользователь
  /// ещё не тронул идентичность (поля по-прежнему равны сырому результату) —
  /// иначе не затираем ручную правку / другой выбор из автокомплита.
  Future<void> _canonicalizeCarFromCatalog(String rawBrand, String rawModel) async {
    final catalogCar = await _resolveCarFromCatalog(rawBrand, rawModel);
    if (!mounted || catalogCar == null) return;
    if (_brandController.text.trim() != rawBrand.trim() ||
        _modelController.text.trim() != rawModel.trim()) {
      return;
    }
    _setStateSafely(() {
      if (catalogCar.brand.trim().isNotEmpty) {
        _brandController.text = catalogCar.brand;
      }
      if (catalogCar.model.trim().isNotEmpty) {
        _modelController.text = catalogCar.model;
      }
      _selectedBrandId = catalogCar.brandId;
      _selectedModelCarId = catalogCar.modelCarId;
    });
    _markDraftDirty();
  }

  /// P2 — ApiCloud VIN↔госномер конвертер. [fromVin]=true: по VIN подставить
  /// госномер+марку+модель; false: по госномеру подставить VIN+марку+модель.
  /// Платно, требует `run_legal_review` (гейт + 403 → snackbar из B1).
  Future<void> _runVinPlateConverter({required bool fromVin}) async {
    if (_vinConverterBusy) return;
    if (!_legalCanRunReview) {
      if (mounted) {
        showSparkJoyErrorSnackBar(
          context,
          Exception('permission_denied'),
          fallback: 'Недостаточно прав для определения по VIN',
        );
      }
      return;
    }
    final vin = _vinController.text.trim();
    final plate = _sanitizePlate(_plateController.text.trim());
    if (fromVin && vin.isEmpty) {
      if (mounted) {
        showSparkJoyErrorSnackBar(
          context,
          Exception('vin_required'),
          fallback: 'Введите VIN',
        );
      }
      return;
    }
    if (!fromVin && plate.isEmpty) {
      if (mounted) {
        showSparkJoyErrorSnackBar(
          context,
          Exception('gos_number_required'),
          fallback: 'Введите госномер',
        );
      }
      return;
    }
    _setStateSafely(() {
      _vinConverterBusy = true;
      _vinLookupInfo = const <String, String>{};
    });
    var resumeVinParamsAutofill = false;
    try {
      final r = await _runConverterDeduped(
        vin: fromVin ? vin : null,
        gosNumber: fromVin ? null : plate,
      );
      if (!mounted) return;

      // Бэк не успел исполнить проверку в окне поллинга (ApiCloud-воркер может
      // лагать) — это не «не найдено». Просим повторить позже, не блокируя UI.
      if (r.timedOut) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ApiCloud ещё обрабатывает запрос. Попробуйте позже.'),
          ),
        );
        return;
      }

      final info = <String, String>{};
      var resolvedVin = fromVin ? vin : r.vin;

      // Конвертер нашёл авто → СРАЗУ ставим сырой результат (быстро), а
      // канонизацию по каталогу делаем В ФОНЕ — иначе медленный
      // GetBrand/GetModelCar на перегруженном бэке держит спиннер конвертера,
      // хотя результат уже получен (регресс fd4ce65).
      if (r.found) {
        _setStateSafely(() {
          // Новая идентичность от конвертера → каталожная мета (фото/frameId/
          // рестайлинг) от прошлого выбора больше не относится к этому авто.
          _clearCatalogCarMeta();
          if (fromVin) {
            if (r.gosNumber.isNotEmpty) _applyDetectedPlate(r.gosNumber);
          } else {
            if (r.vin.isNotEmpty) _vinController.text = _sanitizeVin(r.vin);
          }
          if (r.brand.isNotEmpty) _brandController.text = r.brand;
          if (r.model.isNotEmpty) _modelController.text = r.model;
          _resolvedVinYear = r.year?.toString() ?? '';
          // Сменили авто по VIN/госномеру → старое поколение относится к
          // прежней машине. Конвертер поколение не возвращает (его выбирают
          // вручную / через каталог), поэтому очищаем, иначе оно «зависает».
          _generationController.clear();
          // Привязку проставит фоновая канонизация (если каталог ответит).
          _selectedBrandId = null;
          _selectedModelCarId = null;
        });
        _markDraftDirty();
        // Канонизация имён + brandId/modelCarId по каталогу — в фоне, НЕ держит
        // спиннер конвертера.
        unawaited(_canonicalizeCarFromCatalog(r.brand, r.model));
        if (r.brand.isNotEmpty) info['Марка'] = r.brand;
        if (r.model.isNotEmpty) info['Модель'] = r.model;
        if (r.year != null) info['Год'] = '${r.year}';
        final shownVin = fromVin ? vin : r.vin;
        if (shownVin.isNotEmpty) info['VIN'] = shownVin;
        final shownPlate = fromVin ? r.gosNumber : plate;
        if (shownPlate.isNotEmpty) info['Госномер'] = shownPlate;
        resolvedVin = shownVin;
        resumeVinParamsAutofill = true;
      }

      // Доп. инфа из DecodeVin (бесплатный WMI-декод) по доступному VIN —
      // как обогащение (регион/страна) и как фолбэк, если конвертер не нашёл
      // (производитель + диапазон годов — чтобы пользователь получил хоть что-то).
      if (resolvedVin.isNotEmpty) {
        try {
          final dv = await storage_api.StorageApi.decodeVin(vin: resolvedVin);
          if (mounted) {
            final manufacturer = (dv['manufacturer'] ?? '').toString().trim();
            final region = (dv['region'] ?? '').toString().trim();
            final country = (dv['country'] ?? '').toString().trim();
            final my = dv['modelYear'];
            if (!r.found && manufacturer.isNotEmpty) {
              info['Производитель'] = manufacturer;
            }
            if (!r.found && my is List && my.length == 2) {
              info['Годы выпуска'] = '${my.first}–${my.last}';
            }
            if (region.isNotEmpty) info['Регион'] = region;
            if (country.isNotEmpty) info['Страна'] = country;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      if (info.isEmpty) {
        showSparkJoyErrorSnackBar(
          context,
          Exception('not_found'),
          fallback: fromVin
              ? 'По VIN ничего не найдено'
              : 'По госномеру ничего не найдено',
        );
        return;
      }
      _setStateSafely(() => _vinLookupInfo = info);
      final name = [info['Марка'] ?? '', info['Модель'] ?? '']
          .where((e) => e.isNotEmpty)
          .join(' ');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              name.isEmpty ? 'Информация найдена' : 'Найдено: $name',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось определить по VIN/госномеру',
      );
    } finally {
      if (mounted) {
        _setStateSafely(() {
          _vinConverterBusy = false;
        });
        // Запись найденного VIN/марки/модели триггерит debounce ещё во время
        // busy и тот корректно прекращается. После снятия busy запускаем его
        // повторно, чтобы AI-параметры (включая объём двигателя) не терялись.
        if (resumeVinParamsAutofill) _maybeResolveFromVin();
      }
    }
  }

  /// Программно проставляет госномер с авто-детектом страны/формата —
  /// `TextField.onChanged` на программный `.text =` не срабатывает, поэтому
  /// повторяем ту же логику, что в обработчике ввода (spark_joy_step_vehicle).
  void _applyDetectedPlate(String raw) {
    final permissive = sanitizePlatePermissive(raw);
    final detected = detectPlateCountry(permissive);
    _plateCountry = detected ?? PlateCountry.other;
    _plateController.text = detected != null
        ? formatPlate(
            sanitizePlate(permissive, plateFormatFor(detected)),
            plateFormatFor(detected),
          )
        : permissive;
    _plateBlurred = true;
  }

  /// Сбрасывает каталожные данные авто (фото / рестайлинг / фреймы / frameId).
  /// Они валидны только когда выбраны АТОМАРНО через каталог-пикер; при ручной
  /// правке марки/модели/поколения или после VIN-конвертера относились бы к
  /// другому авто (в отчёт утекли бы чужие фото/frameId). Только присваивания —
  /// без setState (зовётся как из setState-блока, так и из [_onCarIdentityEdited]).
  void _clearCatalogCarMeta() {
    _carPhotoUrl = '';
    _restylingLabel = '';
    _carFrames = '';
    _modelGenerationRestylingFrameId = null;
  }

  /// onChanged для ручных полей марка/модель/поколение: пользователь отходит от
  /// каталожного выбора → сбрасываем каталожную мету и перерисовываем карточку.
  void _onCarIdentityEdited() {
    _setStateSafely(() {
      _clearCatalogCarMeta();
      // Свободный ввод марки/модели → авто больше НЕ привязано к каталогу.
      // (Программная запись `.text =` из автокомплита/конвертера/пикера не
      // дёргает TextField.onChanged, поэтому только что выставленную привязку
      // этот сброс не затрагивает.)
      _selectedBrandId = null;
      _selectedModelCarId = null;
    });
    _markDraftDirty();
  }

  Future<void> _startLegalLoading() async {
    if (_legalLoading) return;
    // Конвертер не запускается в «Материалах проверки» (он только для
    // идентификации в шаге «Автомобиль») — фильтруем на случай stale-драфта.
    final checkTypes = _legalSelectedCheckTypes
        .where((t) => t != 'api_cloud_converter_search')
        .toList();
    if (checkTypes.isEmpty) {
      if (mounted) {
        showSparkJoyErrorSnackBar(
          context,
          Exception('Выберите хотя бы одну проверку'),
          fallback: 'Не выбрано ни одной проверки',
        );
      }
      return;
    }
    final token = _legalLoadToken + 1;
    _setStateSafely(() {
      _legalLoadToken = token;
      _legalPurchased = true;
      _legalSkipped = false;
      _legalTimedOut = false;
      _legalLoading = true;
      _legalLoaded = false;
    });
    _markDraftDirty();

    var vin = _vinController.text.trim();
    final plate = _sanitizePlate(_plateController.text.trim());
    try {
      // Проверки ApiCloud ищут по VIN (подтверждено бэком). Если VIN ещё нет,
      // но есть госномер — сперва конвертируем госномер→VIN (флоу «2 запроса»),
      // иначе vin-проверки ничего не найдут.
      if (vin.isEmpty && plate.isNotEmpty) {
        final conv = await _runConverterDeduped(gosNumber: plate);
        if (!mounted || token != _legalLoadToken) return;
        if (conv.found && conv.vin.trim().isNotEmpty) {
          vin = _sanitizeVin(conv.vin);
          _setStateSafely(() {
            _vinController.text = vin;
            if (conv.brand.isNotEmpty) _brandController.text = conv.brand;
            if (conv.model.isNotEmpty) _modelController.text = conv.model;
            // Сырые имена из конвертера (без резолва в каталог) → сбрасываем
            // каталожную привязку, чтобы автокомплит не подсказывал модели от
            // прежнего brandId.
            _selectedBrandId = null;
            _selectedModelCarId = null;
          });
          _markDraftDirty();
        } else if (conv.timedOut) {
          // Конвертер не успел — не висим, просим повторить позже.
          _setStateSafely(() {
            _legalLoading = false;
            _legalTimedOut = true;
          });
          _markDraftDirty();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'ApiCloud ещё обрабатывает определение VIN. Попробуйте позже.',
                ),
              ),
            );
          }
          return;
        }
        // conv.found == false → продолжаем с тем, что есть (fgis ищет по
        // госномеру; для остального бэк попробует доступные поля).
      }
      final started = await storage_api.StorageApi.runBatchLegalReview(
        checkTypes: checkTypes,
        vin: vin.isEmpty ? null : vin,
        gosNumber: plate.isEmpty ? null : plate,
        // searchString не задаём — для gost/taxi/converter бэкенд сам делает
        // fallback vin → gosNumber (подтверждено рабочим live-запросом).
        // Враппер всё равно отправит полную структуру params + extra:{}.
      );
      if (!mounted || token != _legalLoadToken) return;
      final batchNumber = (started['batchNumber'] ?? '').toString().trim();
      if (batchNumber.isEmpty) {
        throw Exception('Бэкенд не вернул batchNumber');
      }
      _setStateSafely(() => _legalBatchNumber = batchNumber);
      _markDraftDirty();
      await _pollLegalBatchResults(token, batchNumber);
    } catch (e) {
      if (!mounted || token != _legalLoadToken) return;
      _setStateSafely(() {
        _legalLoading = false;
        _legalTimedOut = true;
      });
      _markDraftDirty();
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось запустить проверки',
      );
    }
  }

  _CalculatedSummary _calculateSummary() {
    var penalty = 0;
    final sections = <Map<String, dynamic>>[];
    final checklist = <String>[];

    final vin = _vinController.text.trim();
    final plateRaw = _sanitizePlate(_plateController.text.trim());
    final plate = plateRaw.isEmpty ? '' : _formatPlate(plateRaw);
    final adLink = _adLinkController.text.trim();
    final carName = _carName();
    final hasVinData = vin.isNotEmpty || _vinUnreadable;

    if (!hasVinData) {
      penalty += 8;
      checklist.add(_SparkJoySummaryTextsRegistry.checklistVinMissing);
    }

    final mileage = _mileageController.text.trim();
    if (mileage.isEmpty) {
      penalty += 5;
      checklist.add(_SparkJoySummaryTextsRegistry.checklistMileageMissing);
    }
    if (_mileageMismatch == true) {
      penalty += 5;
      checklist.add(_SparkJoySummaryTextsRegistry.checklistMileageMismatch);
    }

    sections.add({
      'title': _SparkJoySummaryTextsRegistry.sectionVehicle,
      'status': hasVinData && mileage.isNotEmpty ? 'ok' : 'warn',
      'required': true,
      'details': [
        {
          'label': 'VIN',
          'value': _vinUnreadable
              ? 'Нечитабельный (отмечено)'
              : (vin.isEmpty ? 'Не указан' : vin),
          'severity': hasVinData ? 'ok' : 'minor',
        },
        {
          'label': 'Пробег',
          'value': mileage.isEmpty ? 'Не указан' : '$mileage км',
          'severity': mileage.isEmpty ? 'minor' : 'ok',
        },
        {
          'label': 'Пробег по состоянию',
          'value': _mileageMismatch == null
              ? 'Не указано'
              : (_mileageMismatch == true
                    ? 'Не соответствует'
                    : 'Соответствует'),
          'severity': _mileageMismatch == null
              ? 'info'
              : (_mileageMismatch == true ? 'minor' : 'ok'),
        },
        if (_ownersCountController.text.trim().isNotEmpty)
          {
            'label': 'Владельцев',
            'value': _ownersCountController.text.trim(),
            'severity': 'ok',
          },
        if (_inspectionCityController.text.trim().isNotEmpty)
          {
            'label': 'Город осмотра',
            'value': _inspectionCityController.text.trim(),
            'severity': 'ok',
          },
        if (plate.isNotEmpty)
          {'label': 'Госномер', 'value': plate, 'severity': 'ok'},
        if (adLink.isNotEmpty)
          {'label': 'Объявление', 'value': adLink, 'severity': 'ok'},
      ],
    });

    final hasParamsDetails =
        carName.trim().isNotEmpty ||
        _engineVolumeController.text.trim().isNotEmpty ||
        _engineTypeController.text.trim().isNotEmpty ||
        _gearboxTypeController.text.trim().isNotEmpty ||
        _driveTypeController.text.trim().isNotEmpty ||
        _colorController.text.trim().isNotEmpty ||
        _trimController.text.trim().isNotEmpty;

    sections.add({
      'title': _SparkJoySummaryTextsRegistry.sectionParams,
      'status': hasParamsDetails ? 'ok' : 'info',
      'required': false,
      'details': [
        {
          'label': 'Марка / модель',
          'value': carName.isEmpty ? 'Не указано' : carName,
          'severity': carName.isEmpty ? 'info' : 'ok',
        },
        if (_engineVolumeController.text.trim().isNotEmpty)
          {
            'label': 'Объём ДВС',
            'value': _engineVolumeController.text.trim(),
            'severity': 'ok',
          },
        if (_engineTypeController.text.trim().isNotEmpty)
          {
            'label': 'Тип ДВС',
            'value': _engineTypeController.text.trim(),
            'severity': 'ok',
          },
        if (_gearboxTypeController.text.trim().isNotEmpty)
          {
            'label': 'КПП',
            'value': _gearboxTypeController.text.trim(),
            'severity': 'ok',
          },
        if (_driveTypeController.text.trim().isNotEmpty)
          {
            'label': 'Привод',
            'value': _driveTypeController.text.trim(),
            'severity': 'ok',
          },
        if (_colorController.text.trim().isNotEmpty)
          {
            'label': 'Цвет',
            'value': _colorController.text.trim(),
            'severity': 'ok',
          },
        if (_trimController.text.trim().isNotEmpty)
          {
            'label': 'Комплектация',
            'value': _trimController.text.trim(),
            'severity': 'ok',
          },
      ],
    });

    final docsAllAnswered =
        _docsOwnerMatch != null &&
        _docsVinMatch != null &&
        _docsEngineMatch != null;
    final docsAllTrue =
        _docsOwnerMatch == true &&
        _docsVinMatch == true &&
        _docsEngineMatch == true;
    final docsMismatchComment = _docsMismatchCommentController.text.trim();

    if (!docsAllAnswered) {
      penalty += 5;
      checklist.add(_SparkJoySummaryTextsRegistry.checklistDocsIncomplete);
    } else {
      if (_docsOwnerMatch == false) {
        penalty += 10;
        checklist.add(_SparkJoySummaryTextsRegistry.checklistDocsOwnerMismatch);
      }
      if (_docsVinMatch == false) {
        penalty += 14;
        checklist.add(_SparkJoySummaryTextsRegistry.checklistDocsVinMismatch);
      }
      if (_docsEngineMatch == false) {
        penalty += 10;
        checklist.add(
          _SparkJoySummaryTextsRegistry.checklistDocsEngineMismatch,
        );
      }
    }

    sections.add({
      'title': _SparkJoySummaryTextsRegistry.sectionDocsCheck,
      'status': docsAllTrue ? 'ok' : (docsAllAnswered ? 'bad' : 'warn'),
      'required': true,
      'details': [
        {
          'label': 'Владелец',
          'value': _triStateLabel(_docsOwnerMatch),
          'severity': _docsOwnerMatch == false
              ? 'serious'
              : (_docsOwnerMatch == true ? 'ok' : 'minor'),
        },
        {
          'label': 'VIN',
          'value': _triStateLabel(_docsVinMatch),
          'severity': _docsVinMatch == false
              ? 'serious'
              : (_docsVinMatch == true ? 'ok' : 'minor'),
        },
        {
          'label': 'Модель двигателя',
          'value': _triStateLabel(_docsEngineMatch),
          'severity': _docsEngineMatch == false
              ? 'serious'
              : (_docsEngineMatch == true ? 'ok' : 'minor'),
        },
        if (docsMismatchComment.isNotEmpty)
          {
            'label': 'Комментарий',
            'value': docsMismatchComment,
            'severity': 'ok',
          },
      ],
    });

    final legalHasManualData =
        _legalFiles.isNotEmpty || _legalNoteController.text.trim().isNotEmpty;

    if (!_legalLoaded && !_legalSkipped && !legalHasManualData) {
      penalty += _legalSkipped ? 5 : 3;
      checklist.add(
        _legalSkipped
            ? _SparkJoySummaryTextsRegistry.checklistLegalSkipped
            : _SparkJoySummaryTextsRegistry.checklistLegalUnconfirmed,
      );
    }

    sections.add({
      'title': _SparkJoySummaryTextsRegistry.sectionLegal,
      // Status mirrors the same source-of-truth as the detail value
      // below: report-formation flags (_legalLoaded / _legalLoading /
      // _legalSkipped) are no longer reachable from UI, so leaning on
      // them would produce a green "ok" badge with a "Не заполнено"
      // detail line on legacy drafts. Keep the chip honest about
      // what the user can actually see.
      'status': legalHasManualData ? 'ok' : 'empty',
      'required': false,
      'details': [
        {
          'label': 'Статус',
          // Step renamed «Юр. проверка» → «Материалы проверки» and the
          // report-formation card is hidden behind `_kShowLegalReportCard`.
          // The legalLoaded / legalLoading / legalSkipped flags can still
          // be `true` on legacy drafts, but the user has no UI to reach
          // that flow anymore — surface neutral wording instead of
          // "Юридический отчёт сформирован" which points to a feature
          // they can't see.
          'value': legalHasManualData ? 'Материалы добавлены' : 'Не заполнено',
          'severity': legalHasManualData ? 'ok' : 'info',
        },
        if (_legalFiles.isNotEmpty)
          {
            'label': 'Файлы',
            'value': '${_legalFiles.length} файл(ов)',
            'severity': 'ok',
          },
        if (_legalNoteController.text.trim().isNotEmpty)
          {
            'label': 'Комментарий',
            'value': _legalNoteController.text.trim(),
            'severity': 'minor',
          },
      ],
    });

    for (final config in _SparkJoyMediaGroupRegistry.groups) {
      final state = _mediaState[config.key]!;
      final mediaCount = _parseUrls(state.rawUrls).length + state.files.length;
      final hasCoverage = mediaCount > 0;
      final hasIssue = _groupHasIssue(state);
      final requiredForSummary = _SparkJoySummaryRegistry
          .requiredMediaKeysForSummary
          .contains(config.key);

      var status = hasCoverage ? 'ok' : 'empty';
      if (!hasCoverage) {
        status = 'empty';
      } else if (hasIssue && config.severeIfIssue) {
        status = 'bad';
      } else if (hasIssue) {
        status = 'warn';
      }

      if (requiredForSummary && !hasCoverage) {
        penalty += 4;
        checklist.add(
          _SparkJoySummaryTextsRegistry.checklistMediaCoverageMissing(
            config.title,
          ),
        );
      }

      if (hasIssue) {
        penalty += config.severeIfIssue ? 12 : 6;
        checklist.add(
          _SparkJoySummaryTextsRegistry.checklistMediaIssuesFound(config.title),
        );
      }

      sections.add({
        'title': config.title,
        'status': status,
        'required': config.required,
        'details': [
          {
            'label': 'Состояние',
            'value': !hasCoverage
                ? 'Не осмотрено'
                : (hasIssue ? 'Есть замечания' : 'Без замечаний'),
            'severity': !hasCoverage
                ? (requiredForSummary ? 'minor' : 'info')
                : (hasIssue
                      ? (config.severeIfIssue ? 'serious' : 'minor')
                      : 'ok'),
          },
          {
            'label': 'Медиа',
            'value': mediaCount == 0 ? 'Не добавлено' : '$mediaCount файл(ов)',
            'severity': mediaCount == 0
                ? (requiredForSummary ? 'minor' : 'info')
                : 'ok',
          },
          if (state.note.trim().isNotEmpty)
            {
              'label': 'Комментарий',
              'value': state.note.trim(),
              'severity': hasIssue ? 'minor' : 'ok',
            },
        ],
      });
    }

    final tdConducted = _tdConductedValue();
    if (tdConducted == null) {
      penalty += 3;
      checklist.add(_SparkJoySummaryTextsRegistry.checklistTdStatusMissing);
    }

    final tdState = <String, Map<String, dynamic>>{
      'Двигатель на ходу': {'ok': _tdEngineOk, 'tags': _tdEngineTags},
      'Работа КПП': {'ok': _tdGearboxOk, 'tags': _tdGearboxTags},
      'Рулевое управление': {'ok': _tdSteeringOk, 'tags': _tdSteeringTags},
      'Подвеска и комфорт': {'ok': _tdRideOk, 'tags': _tdRideTags},
      'Торможение': {'ok': _tdBrakeOk, 'tags': _tdBrakeTags},
    };

    tdState.forEach((title, state) {
      if (tdConducted != true ||
          _tdMode == _SparkJoyTestDriveRegistry.modeAllGood) {
        return;
      }
      final ok = state['ok'] == true;
      final tags = (state['tags'] as List<String>? ?? const []).length;
      if (!ok || tags > 0) {
        penalty += 5;
        checklist.add(
          _SparkJoySummaryTextsRegistry.checklistTdIssuesFound(title),
        );
      }
    });

    final hasTdIssues = tdState.values.any((state) {
      if (tdConducted != true ||
          _tdMode == _SparkJoyTestDriveRegistry.modeAllGood) {
        return false;
      }
      final ok = state['ok'] == true;
      final tags = (state['tags'] as List<String>? ?? const []).length;
      return !ok || tags > 0;
    });
    if (_isTdCommentRequired() && _tdNoteController.text.trim().isEmpty) {
      penalty += 4;
      checklist.add(_SparkJoySummaryTextsRegistry.checklistTdCommentRequired);
    }
    sections.add({
      'title': _SparkJoySummaryTextsRegistry.sectionTestDrive,
      'status': tdConducted == true && !hasTdIssues ? 'ok' : 'warn',
      'required': true,
      'details': [
        {
          'label': 'Проведен',
          'value': _tdMode == _SparkJoyTestDriveRegistry.modeAllGood
              ? 'Да, все исправно'
              : (_tdMode == _SparkJoyTestDriveRegistry.modeProblems
                    ? 'Да, есть проблемы'
                    : (_tdMode == _SparkJoyTestDriveRegistry.modeNotConducted
                          ? 'Нет'
                          : 'Не указано')),
          'severity': tdConducted == true ? 'ok' : 'minor',
        },
        ...tdState.entries.map(
          (entry) => {
            'label': entry.key,
            'value': tdConducted != true
                ? 'Не проверено'
                : (_tdMode == _SparkJoyTestDriveRegistry.modeAllGood
                      ? 'Без замечаний'
                      : (entry.value['ok'] == true &&
                                ((entry.value['tags'] as List<String>).isEmpty)
                            ? 'Без замечаний'
                            : 'Есть замечания')),
            'severity': tdConducted != true
                ? 'minor'
                : (_tdMode == _SparkJoyTestDriveRegistry.modeAllGood
                      ? 'ok'
                      : (entry.value['ok'] == true &&
                                ((entry.value['tags'] as List<String>).isEmpty)
                            ? 'ok'
                            : 'minor')),
          },
        ),
        if (_tdNoteController.text.trim().isNotEmpty)
          {
            'label': 'Комментарий',
            'value': _tdNoteController.text.trim(),
            'severity': hasTdIssues ? 'minor' : 'ok',
          },
      ],
    });

    final score = math.max(0, 100 - penalty);

    String verdict;
    String verdictLabel;
    if (score >= 70) {
      verdict = _SparkJoySummaryTextsRegistry.verdictRecommended;
      verdictLabel = _SparkJoySummaryTextsRegistry.verdictLabelRecommended;
    } else if (score >= 40) {
      verdict = _SparkJoySummaryTextsRegistry.verdictWithReservations;
      verdictLabel = _SparkJoySummaryTextsRegistry.verdictLabelWithReservations;
    } else {
      verdict = _SparkJoySummaryTextsRegistry.verdictNotRecommended;
      verdictLabel = _SparkJoySummaryTextsRegistry.verdictLabelNotRecommended;
    }

    if (checklist.isEmpty) {
      checklist.add(_SparkJoySummaryTextsRegistry.checklistNoCritical);
    }

    checklist.add(
      verdict == _SparkJoySummaryTextsRegistry.verdictRecommended
          ? _SparkJoySummaryTextsRegistry.checklistRecommended
          : verdict == _SparkJoySummaryTextsRegistry.verdictWithReservations
          ? _SparkJoySummaryTextsRegistry.checklistWithReservations
          : _SparkJoySummaryTextsRegistry.checklistNotRecommended,
    );

    return _CalculatedSummary(
      score: score,
      verdict: verdict,
      verdictLabel: verdictLabel,
      sections: sections,
      checklist: checklist,
      fullInspection: _isFullInspection(),
    );
  }
}

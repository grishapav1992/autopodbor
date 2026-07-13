part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyDictationRulesMethods on _SparkJoyCreateReportScreenState {
  Future<void> _ensureTdSpeech() async {
    if (_tdSpeechAvailable) return;
    if (_tdSpeechInitializing) return;
    _tdSpeechInitializing = true;

    try {
      _tdSpeechAvailable = await _tdSpeechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            _resetDictationFlags();
          }
        },
        onError: (_) {
          if (!mounted) return;
          _resetDictationFlags();
        },
      );
      if (_tdSpeechAvailable) {
        _speechPermissionGranted = true;
      } else {
        _showErrorSnack(
          'Надиктовка недоступна. Проверьте доступ к микрофону и распознаванию речи.',
        );
      }
    } catch (_) {
      _tdSpeechAvailable = false;
      _showErrorSnack('Не удалось инициализировать распознавание речи');
    } finally {
      _tdSpeechInitializing = false;
    }
  }

  void _resetDictationFlags() {
    _setStateSafely(() {
      _tdIsDictating = false;
      _docsIsDictating = false;
      _legalIsDictating = false;
      _summaryIsDictating = false;
    });
  }

  void _appendRecognizedText(
    TextEditingController controller,
    String transcript,
  ) {
    final next = SparkJoyCommentUtils.appendRecognizedTranscript(
      previous: controller.text,
      transcript: transcript,
    );
    if (next == controller.text) return;
    controller
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    _markDraftDirty();
    _setStateSafely(() {});
  }

  Future<void> _startDocsDictation() async {
    _docsShouldDictate = true;
    if (_docsIsDictating) return;
    if (_tdIsDictating) await _stopTdDictation();
    if (_legalIsDictating) await _stopLegalDictation();
    if (_summaryIsDictating) await _stopSummaryDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_docsShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(
            _docsMismatchCommentController,
            result.recognizedWords,
          );
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _docsIsDictating = true);
    } catch (_) {
      _docsShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopDocsDictation() async {
    _docsShouldDictate = false;
    if (!_docsIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _docsIsDictating = false);
  }

  Future<void> _startLegalDictation() async {
    _legalShouldDictate = true;
    if (_legalIsDictating) return;
    if (_tdIsDictating) await _stopTdDictation();
    if (_docsIsDictating) await _stopDocsDictation();
    if (_summaryIsDictating) await _stopSummaryDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_legalShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(_legalNoteController, result.recognizedWords);
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _legalIsDictating = true);
    } catch (_) {
      _legalShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopLegalDictation() async {
    _legalShouldDictate = false;
    if (!_legalIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _legalIsDictating = false);
  }

  Future<void> _startTdDictation() async {
    _tdShouldDictate = true;
    if (_tdIsDictating) return;
    if (_docsIsDictating) await _stopDocsDictation();
    if (_legalIsDictating) await _stopLegalDictation();
    if (_summaryIsDictating) await _stopSummaryDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_tdShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(_tdNoteController, result.recognizedWords);
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _tdIsDictating = true);
    } catch (_) {
      _tdShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopTdDictation() async {
    _tdShouldDictate = false;
    if (!_tdIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _tdIsDictating = false);
  }

  /// Dictation for the unified «Итог осмотра» field — replaced the
  /// old expert dictation after the «Сводка» + «Итог специалиста»
  /// cards were merged. Writes recognized text into `_summaryController`.
  Future<void> _startSummaryDictation() async {
    _summaryShouldDictate = true;
    if (_summaryIsDictating) return;
    if (_tdIsDictating) await _stopTdDictation();
    if (_docsIsDictating) await _stopDocsDictation();
    if (_legalIsDictating) await _stopLegalDictation();
    await _ensureTdSpeech();
    if (!_tdSpeechAvailable || !_summaryShouldDictate) return;

    try {
      await _tdSpeechToText.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          _appendRecognizedText(_summaryController, result.recognizedWords);
        },
      );
      if (!mounted) return;
      _setStateSafely(() => _summaryIsDictating = true);
    } catch (_) {
      _summaryShouldDictate = false;
      _showErrorSnack('Не удалось запустить надиктовку');
    }
  }

  Future<void> _stopSummaryDictation() async {
    _summaryShouldDictate = false;
    if (!_summaryIsDictating) return;
    try {
      await _tdSpeechToText.stop();
    } catch (_) {}
    if (!mounted) return;
    _setStateSafely(() => _summaryIsDictating = false);
  }

  /// AI-fill for the «Комментарий по расхождениям» field in the
  /// docs check step. The three yes/no values above are baked into
  /// the prompt via `buildDocsCheckCommentCliche` so the model sees
  /// which fields are mismatching even when the typed comment is
  /// short. Result lands in `_docsMismatchCommentController`.
  Future<void> _generateDocsCommentWithAi() async {
    if (_docsCommentAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _docsCommentAiBusy = true);
    try {
      final cliche = AiQueueClicheBuilder.buildDocsCheckCommentCliche(
        ownerMatch: _docsOwnerMatch,
        vinMatch: _docsVinMatch,
        engineMatch: _docsEngineMatch,
      );
      final inputText = _docsMismatchCommentController.text.trim();
      // Fresh chatId — no carry-over of prior turns.
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: inputText.isEmpty ? '—' : inputText,
        cliche: cliche,
      );
      final text = result.text.trim();
      if (text.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _docsMismatchCommentController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _docsCommentAiBusy = false);
      }
    }
  }

  /// Единый VIN→всё конвейер: сначала идентификация (заполняет `_carContextForAi`
  /// для грунтовки ИИ), затем параметры. Оба шага само-гардятся (дедуп/only-empty/
  /// busy) → идемпотентны. Тихий best-effort. Зовётся из `_maybeResolveFromVin`.
  Future<void> _resolveAllFromVin(String vin) async {
    final identityReady = await _maybeAutoResolveIdentityFromVin(vin);
    // Идентификация в полёте (наш резолв или кнопочный конвертер) либо
    // транзиентно сорвалась → params НЕ запускаем: ИИ-вызов ушёл бы без
    // грунтовки, а дедуп `_lastVinAutofilled` «сжёг» бы VIN до появления
    // марки/модели. Listener ре-триггернёт конвейер, когда поля запишутся.
    if (!mounted || !identityReady) return;
    await _autofillParamsFromVinWithAi(vin);
  }

  /// Авто-резолв идентификации (марка/модель/год) по полному VIN через платный
  /// конвертер `_runConverterDeduped` (ungated/дедуп/кэш — НЕ зависит от права
  /// run_legal_review, в отличие от кнопочного `_runVinPlateConverter`). Only-empty:
  /// трогаем только недостающие поля; когда заполнены И марка, И модель — не
  /// платим. Дедуп по VIN, busy-гард, тихо. Строгий каталог: результат
  /// конвертера резолвим в каталог и пишем ТОЛЬКО канон+ID
  /// (`_selectedBrandId`/`_selectedModelCarId`); не совпало — оставляем пусто,
  /// сырой текст в поля НЕ пишем. Год → `_resolvedVinYear` (грунтовка ИИ).
  ///
  /// Возвращает true, когда идентификация ТЕРМИНАЛЬНО определена (свежий
  /// found/not_found, дедуп-хит или ручная марка/модель) — params можно
  /// грунтовать. false = резолв в полёте/сорвался → params отложить до
  /// ре-триггера listener'ом (см. `_resolveAllFromVin`).
  Future<bool> _maybeAutoResolveIdentityFromVin(String vin) async {
    if (widget.readOnly) return false;
    if (_identityResolveBusy || _vinConverterBusy) return false;
    if (vin == _lastVinIdentityResolved) return true;

    // Смена VIN → чистим прежнюю АВТО-идентификацию, не тронутую пользователем
    // (current == записанному нами), чтобы новый VIN пере-резолвился. Ручной
    // ввод и каталожный выбор не трогаем. Год прежнего VIN недействителен в
    // любом случае (в т.ч. когда map пуст — резолв без записей полей).
    final hasPriorAutoIdentity =
        _vinAutoIdentityValues.isNotEmpty ||
        (_lastVinIdentityResolved.isNotEmpty &&
            _lastVinIdentityResolved != vin);
    if (hasPriorAutoIdentity) {
      final stale = staleVinAutofillKeys(_vinAutoIdentityValues, {
        'brand': _brandController.text,
        'model': _modelController.text,
      });
      _setStateSafely(() {
        // Чистим каталожные ID вместе с текстом (авто-идентичность строгая:
        // текст+ID ставились парой) — иначе от прежнего VIN остался бы
        // «висячий» ID при пустом поле.
        if (stale.contains('brand')) {
          _brandController.clear();
          _selectedBrandId = null;
        }
        if (stale.contains('model')) {
          _modelController.clear();
          _selectedModelCarId = null;
        }
        _resolvedVinYear = '';
        _vinAutoIdentityValues.clear();
      });
    }

    // Only-empty гейт: обе части идентичности уже заполнены (вручную/каталог/
    // скан документа) → уважаем их и не платим. Если не хватает хотя бы одной
    // части, конвертер нужен как fallback: типичный кейс — СТС дало VIN и
    // марку, а написание модели не совпало с каталогом.
    if (_brandController.text.trim().isNotEmpty &&
        _modelController.text.trim().isNotEmpty) {
      return true;
    }

    _lastVinIdentityResolved = vin; // дедуп ДО await
    _setStateSafely(() => _identityResolveBusy = true);
    try {
      final r = await _runConverterDeduped(
        vin: vin,
      ); // чёрный ящик (WIP), ungated
      if (!mounted) return false;
      if (_sanitizeVin(_vinController.text) != vin) {
        // VIN сменили за время await — результат про прежнюю машину, не пишем.
        // Дедуп снимаем: вернутся к этому VIN → повторный резолв бесплатен
        // (терминальный итог уже в кэше _runConverterDeduped).
        _lastVinIdentityResolved = '';
        return false;
      }
      if (r.timedOut) {
        _lastVinIdentityResolved = ''; // транзиент → ретрай при след. триггере
        return false;
      }
      final plan = planIdentityFill(
        brandEmpty: _brandController.text.trim().isEmpty,
        modelEmpty: _modelController.text.trim().isEmpty,
        found: r.found,
        timedOut: r.timedOut,
        resolvedBrand: r.brand,
        resolvedModel: r.model,
      );
      // Строгий каталог: сырой текст конвертера в поля НЕ пишем — это был бы
      // обход «только из каталога» (марка/модель без brandId/modelCarId позже
      // ломают выгрузку отчёта). Резолвим в каталог, пишем ТОЛЬКО канон+ID; не
      // совпало — оставляем пусто (пользователь выберет из readOnly-селектора).
      // Тихо, без снека «выберите вручную»: авто-триггер на ввод VIN спамить нельзя.
      CatalogCarMatch? match;
      if (plan.brand.isNotEmpty || plan.model.isNotEmpty) {
        match = await CarCatalogRepository.instance.resolveCar(
          r.brand,
          r.model,
        );
        if (!mounted) return false;
        if (_sanitizeVin(_vinController.text) != vin) {
          _lastVinIdentityResolved = ''; // VIN сменили за резолв → не пишем
          return false;
        }
      }
      _setStateSafely(() {
        if (match != null) {
          final brandWasEmpty = _brandController.text.trim().isEmpty;
          if (brandWasEmpty && _selectedBrandId == null) {
            _brandController.text = match.brand.name;
            _selectedBrandId = match.brand.id;
            _vinAutoIdentityValues['brand'] = match.brand.name;
          }

          // Модель можно дозаполнить и при уже известной марке (например,
          // марку скан СТС сопоставил, а модель — нет). Но только если текущая
          // марка привязана к той же записи каталога: модель другой марки сюда
          // попасть не должна.
          final m = match.model;
          final sameCatalogBrand = _selectedBrandId == match.brand.id;
          if (m != null &&
              sameCatalogBrand &&
              _modelController.text.trim().isEmpty &&
              _selectedModelCarId == null) {
            _modelController.text = m.model;
            _selectedModelCarId = m.id;
            _vinAutoIdentityValues['model'] = m.model;
          }
        }
        // Год с документа авторитетнее fallback-конвертера. Конвертер лишь
        // дозаполняет его, когда скан ничего не прочитал.
        if (_resolvedVinYear.isEmpty && r.found && r.year != null) {
          _resolvedVinYear = '${r.year}';
        }
      });
      // Записи .text= метят черновик dirty через autosave-listener.
      return true; // терминально (found / not_found) → params можно грунтовать
    } catch (e) {
      _lastVinIdentityResolved = ''; // транзиент → ретрай
      debugPrint('VIN identity auto-resolve failed (silent): $e');
      return false;
    } finally {
      if (mounted) _setStateSafely(() => _identityResolveBusy = false);
    }
  }

  /// Авто-дозаполнение шага «Параметры» по полному VIN через AiQueue.
  /// Авто-триггер, best-effort: при любой ошибке — тихо (`debugPrint`), без
  /// error-снэкбара (фича срабатывает сама, спамить нельзя). Заполняет
  /// ТОЛЬКО пустые из 5 целевых полей, никогда не перетирает введённое
  /// вручную. Успех → один снэкбар, если хоть одно поле легло. Первый
  /// структурированный AI-вывод (JSON) — парсится `parseVinParamsAiResult`
  /// и нормализуется к опциям дропдаунов.
  Future<void> _autofillParamsFromVinWithAi(String vin) async {
    if (_vinParamsAiBusy || widget.readOnly) return;
    if (vin == _lastVinAutofilled) return; // этот VIN уже обработан (дедуп)
    // Помечаем VIN обработанным СРАЗУ (до await) — дедуп против повторных
    // событий listener'а, пока запрос в полёте. Уважает и ручную очистку
    // поля позже (повторно заполнять не будем). При сетевой ошибке ниже
    // снимаем пометку, чтобы следующий триггер повторил (см. catch).
    _lastVinAutofilled = vin;
    // Сменился VIN → значения, записанные ИИ для ПРЕЖНЕЙ машины и не тронутые
    // пользователем, относятся не к той машине: чистим их (ручной ввод
    // сохраняем — см. staleVinAutofillKeys), чтобы подтянуть данные нового VIN.
    if (_vinAutofilledValues.isNotEmpty) {
      final byKey = _vinParamTargetsByKey();
      final stale = staleVinAutofillKeys(_vinAutofilledValues, {
        for (final e in byKey.entries) e.key: e.value.text,
      });
      _setStateSafely(() {
        for (final key in stale) {
          byKey[key]!.clear();
        }
        _vinAutofilledValues.clear();
      });
    }
    // Поля могли заполниться вручную за время дебаунса (600 мс) — не тратим
    // платный вызов ИИ впустую.
    if (!_hasAnyEmptyParamTarget()) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _vinParamsAiBusy = true);
    try {
      // Грунтовка бесплатным backend-DecodeVin (WMI): производитель/страна/
      // годы. Не фатально при ошибке — промпт обойдётся carContext'ом.
      String? wmiInfo;
      try {
        final dv = await storage_api.StorageApi.decodeVin(vin: vin);
        final manufacturer = (dv['manufacturer'] ?? '').toString().trim();
        final country = (dv['country'] ?? '').toString().trim();
        final my = dv['modelYear'];
        final years = (my is List && my.length == 2)
            ? '${my.first}–${my.last}'
            : '';
        final parts = <String>[
          if (manufacturer.isNotEmpty) 'производитель $manufacturer',
          if (country.isNotEmpty) 'страна $country',
          if (years.isNotEmpty) 'годы $years',
          // Точный год из конвертера (если был) — сужает варианты двигателя.
          if (_resolvedVinYear.isNotEmpty) 'точный год $_resolvedVinYear',
        ];
        if (parts.isNotEmpty) wmiInfo = parts.join(', ');
      } catch (_) {
        // грунтовка опциональна
      }
      if (!mounted) return;

      final cliche = AiQueueClicheBuilder.buildVinParamsCliche(
        vin: vin,
        carContext: _carContextForAi(),
        wmiInfo: wmiInfo,
      );
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: vin,
        cliche: cliche,
      );
      if (!mounted) return;

      final parsed = parseVinParamsAiResult(
        result.text,
        allowedEngineTypes: _SparkJoyVehicleRegistry.engineTypes,
        allowedGearboxTypes: _SparkJoyVehicleRegistry.gearboxTypes,
        allowedDriveTypes: _SparkJoyVehicleRegistry.driveTypes,
        allowedEngineVolumes: _SparkJoyVehicleRegistry.engineVolumeOptions,
      );

      final byKey = _vinParamTargetsByKey();
      // Комплектация (parsed.equipment) намеренно НЕ заполняется: по VIN её
      // надёжно не определить, ИИ угадывал бы. Заполняем только определимые поля.
      final values = <String, String>{
        'engineVolume': parsed.engineVolume,
        'engineType': parsed.engineType,
        'transmission': parsed.transmission,
        'driveType': parsed.driveType,
      };
      var filledAny = false;
      _setStateSafely(() {
        values.forEach((key, value) {
          if (value.isEmpty) return;
          final controller = byKey[key]!;
          if (controller.text.trim().isNotEmpty) return; // only-empty, не перетираем
          controller.text = value;
          _vinAutofilledValues[key] = value; // запоминаем запись ИИ (для #3)
          filledAny = true;
        });
      });

      // Черновик уже помечен dirty через autosave-listener (записи .text=),
      // явный _markDraftDirty() не нужен.
      if (filledAny && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Параметры дозаполнены по VIN')),
        );
      }
    } on storage_api.SessionExpiredException {
      // Сессия истекла — без релогина не починится, повтор бессмыслен:
      // _lastVinAutofilled НЕ сбрасываем (иначе пойдут повторные фейлы).
      debugPrint('VIN params autofill: session expired (silent)');
    } catch (e) {
      // Транзиентная ошибка (сеть/таймаут/бэкенд) — снимаем пометку, чтобы
      // следующий триггер (правка любого поля) повторил попытку.
      _lastVinAutofilled = '';
      debugPrint('VIN params autofill failed (silent): $e');
    } finally {
      if (mounted) _setStateSafely(() => _vinParamsAiBusy = false);
    }
  }

  /// Дозаполняет «Параметры» (объём/тип двигателя/КПП) из сертификата ГОСТ в
  /// `_legalCheckResults`. Бесплатно + синхронно. ГОСТ авторитетнее ИИ:
  /// заполняет пустое И перетирает ТОЛЬКО ранее ИИ-заполненное (ручной ввод не
  /// трогаем). Пишет в общий `_vinAutofilledValues` → следующий ИИ-шаг only-empty
  /// его не перетрёт, смена авто корректно чистит (stale). Идемпотентно.
  void _autofillParamsFromGostCert() {
    if (widget.readOnly) return;
    Map<String, dynamic>? cert;
    for (final c in _legalCheckResults) {
      if ((c['checkType'] ?? '').toString() == 'api_cloud_gost_certificate') {
        cert = gostCertificateFields(c['responseNormalized']);
        break;
      }
    }
    if (cert == null) return; // нет / found:false / пустой certificate
    final parsed = parseGostCertificateParams(
      cert,
      allowedEngineTypes: _SparkJoyVehicleRegistry.engineTypes,
      allowedGearboxTypes: _SparkJoyVehicleRegistry.gearboxTypes,
      allowedEngineVolumes: _SparkJoyVehicleRegistry.engineVolumeOptions,
    );
    final byKey = _vinParamTargetsByKey();
    final values = <String, String>{
      'engineVolume': parsed.engineVolume,
      'engineType': parsed.engineType,
      'transmission': parsed.transmission, // → _gearboxTypeController
    };
    var filledAny = false;
    _setStateSafely(() {
      values.forEach((key, value) {
        if (value.isEmpty) return;
        final controller = byKey[key]!;
        final current = controller.text.trim();
        if (current == value) return; // уже стоит → no-op (идемпотентность)
        final wasAiOnly =
            current.isNotEmpty && _vinAutofilledValues[key] == controller.text;
        // only-empty ИЛИ перетираем ровно ИИ-значение (ГОСТ приоритетнее ИИ);
        // ручной ввод (непусто и не равно записи ИИ) не трогаем.
        if (current.isNotEmpty && !wasAiOnly) return;
        controller.text = value;
        _vinAutofilledValues[key] = value; // value-tracking как у ИИ
        filledAny = true;
      });
    });
    if (filledAny && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Параметры дозаполнены по сертификату')),
      );
    }
  }

  /// Терминальные ApiCloud-проверки (залог/такси/ГОСТ/ФГИС) → строки
  /// «<тип> — <результат>». Конвертер (api_cloud_converter_search) и
  /// нетерминальные статусы (pending/processing/…) исключены. Единый источник
  /// для legal-комментария И итоговой сводки осмотра (не дублируем логику).
  List<String> _legalCheckFactLines() {
    final lines = <String>[];
    for (final c in _legalCheckResults) {
      final type = (c['checkType'] ?? '').toString();
      if (type == 'api_cloud_converter_search') continue; // не материал проверки
      final status = (c['status'] ?? '').toString().toLowerCase();
      if (status.isEmpty ||
          status == 'pending' ||
          status == 'processing' ||
          status == 'in_progress' ||
          status == 'running') {
        continue; // ещё не доехало — не включаем
      }
      final title =
          type.isEmpty ? 'Проверка' : sparkJoyLegalCheckTypeLabel(type);
      // ГОСТ-сертификат: вместо «Обнаружено» — реальные факты сертификата
      // (марка/модель/год/двигатель/топливо/КПП/мощность/№). Бэк отдаёт их в
      // certificate[]; _legalNormalizedToText их теряет, поэтому достаём сами.
      if (type == 'api_cloud_gost_certificate') {
        final gost = _gostCertFactLine(c['responseNormalized']);
        if (gost.isNotEmpty) {
          lines.add('$title — $gost');
          continue;
        }
      }
      final summary = _legalNormalizedToText(c['responseNormalized']).trim();
      final result = summary.isNotEmpty
          ? summary
          : (status == 'not_found'
                ? 'не найдено'
                : (status == 'error' || status == 'failed'
                      ? 'ошибка проверки'
                      : 'выполнено'));
      lines.add('$title — $result');
    }
    return lines;
  }

  /// Факт-строка по ГОСТ-сертификату для ИИ (сводка/legal-комментарий): только
  /// факты, без рекомендаций (гард «не советовать» — в cliché-билдерах). Пусто,
  /// если сертификата нет.
  String _gostCertFactLine(dynamic normalized) {
    final cert = gostCertificateFields(normalized);
    if (cert == null) return '';
    String f(String k) => (cert[k] ?? '').toString().trim();
    final parts = <String>[];
    final mm = [
      f('product'),
      f('tradename'),
    ].where((s) => s.isNotEmpty).join(' ');
    if (mm.isNotEmpty) parts.add(mm);
    if (f('yearofmanufacturing').isNotEmpty) {
      parts.add('${f('yearofmanufacturing')} г.');
    }
    final cc = int.tryParse(
      RegExp(r'\d+').firstMatch(f('enginecylindersusefulcapacity'))?.group(0) ??
          '',
    );
    final engineBits = <String>[
      if (cc != null && cc > 0) 'двигатель ${(cc / 1000).toStringAsFixed(1)} л',
      if (f('enginepetrol').isNotEmpty) f('enginepetrol'),
    ];
    if (engineBits.isNotEmpty) parts.add(engineBits.join(', '));
    if (f('transmission').isNotEmpty) parts.add('КПП ${f('transmission')}');
    if (f('enginemaxpower').isNotEmpty) {
      parts.add('мощность ${f('enginemaxpower')}');
    }
    if (f('numberofcertificate').isNotEmpty) {
      parts.add('№ сертификата ${f('numberofcertificate')}');
    }
    return parts.join('; ');
  }

  /// AI-fill for the «Комментарий специалиста» field on the «Материалы
  /// проверки» step. В промпт идут только факты выполненных ApiCloud-проверок
  /// (имена/содержимое приложенных файлов ИИ недоступны) + текст инспектора.
  /// Результат ложится в `_legalNoteController`.
  Future<void> _generateLegalCommentWithAi() async {
    if (_legalCommentAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _legalCommentAiBusy = true);
    try {
      // Содержимое приложенных документов ИИ не читает (файлы в вызов не
      // передаются), поэтому имена/количество в промпт НЕ кладём — только
      // человекочитаемые результаты ApiCloud-проверок (терминальные) + текст
      // инспектора. Так ИИ опирается на залог/такси/ГОСТ/ФГИС, а не на файлы.
      final checkLines = _legalCheckFactLines();
      final cliche = AiQueueClicheBuilder.buildLegalCommentCliche(
        checksInfo: checkLines.join('; '),
      );
      final inputText = _legalNoteController.text.trim();
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: inputText.isEmpty ? '—' : inputText,
        cliche: cliche,
      );
      final text = result.text.trim();
      if (text.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _legalNoteController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
      _markDraftDirty();
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _legalCommentAiBusy = false);
      }
    }
  }

  /// AI-fill for the «Комментарий по тест-драйву» field. The mode
  /// (всё ок / есть проблемы / не проводился) plus per-subsystem
  /// yes/no answers and selected tags are baked into the prompt via
  /// `buildTdCommentCliche` so the model sees the structured findings
  /// regardless of how short the typed comment is.
  Future<void> _generateTdCommentWithAi() async {
    if (_tdCommentAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _tdCommentAiBusy = true);
    try {
      final cliche = AiQueueClicheBuilder.buildTdCommentCliche(
        tdMode: _tdMode ?? '',
        subsystemStatus: <String, bool?>{
          'engine': _tdEngineOk,
          'gearbox': _tdGearboxOk,
          'steering': _tdSteeringOk,
          'ride': _tdRideOk,
          'brake': _tdBrakeOk,
        },
        subsystemTags: <String, List<String>>{
          'engine': _tdEngineTags,
          'gearbox': _tdGearboxTags,
          'steering': _tdSteeringTags,
          'ride': _tdRideTags,
          'brake': _tdBrakeTags,
        },
        carContext: _carContextForAi(),
      );
      final inputText = _tdNoteController.text.trim();
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: inputText.isEmpty ? '—' : inputText,
        cliche: cliche,
      );
      final text = result.text.trim();
      if (text.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _tdNoteController
        ..text = text
        ..selection = TextSelection.collapsed(offset: text.length);
      _markDraftDirty();
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _tdCommentAiBusy = false);
      }
    }
  }

  /// AI-fill for the «Сводка по данным осмотра» card. Fact-only —
  /// no buy/don't-buy advice (that role belongs to the expert
  /// conclusion generator above). The user-text payload combines
  /// the deterministic rule-based summary template (always
  /// available) with the per-element AI chat histories when
  /// present, so the model sees both raw fields and assistant
  /// interpretations and can produce a single readable recap.
  /// Result lands in `_summaryController` so autosave persists it
  /// to the draft and it ships to the server with the report.
  Future<void> _generateSummaryNoteWithAi() async {
    if (_summaryNoteAiBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    _setStateSafely(() => _summaryNoteAiBusy = true);
    try {
      final summary = _calculateSummary();
      final structured = _summaryTemplate(summary).trim();

      final chatIds = _reportController.aiChatIdBySourceKey.values
          .where((id) => id > 0)
          .toSet()
          .toList();

      final historyChunks = <String>[];
      if (chatIds.isNotEmpty) {
        try {
          final histories = await AiQueueApi.getChatHistories(ids: chatIds);
          for (final session in histories.chats.values) {
            final assistantTurns = session.messages
                .where((m) => m.role.toLowerCase() == 'assistant')
                .map((m) => m.content.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (assistantTurns.isEmpty) continue;
            historyChunks.add(assistantTurns.join('\n'));
          }
        } catch (_) {
          // Non-fatal: structured rule-based dump alone is enough
          // context for the model.
        }
      }

      final contextParts = <String>[];
      if (structured.isNotEmpty) {
        contextParts.add(
          '=== Структурированные данные осмотра ===\n$structured',
        );
      }
      // Юридические проверки и материалы — терминальные результаты + коммент
      // инспектора. Раньше в сводку не попадали (шаблон только флажил «не
      // выполнена»), из-за чего ИИ не учитывал залог/такси/ГОСТ/ФГИС.
      final legalLines = _legalCheckFactLines();
      final legalNote = _legalNoteController.text.trim();
      if (legalLines.isNotEmpty || legalNote.isNotEmpty) {
        final buf = StringBuffer('=== Юридические проверки и материалы ===\n');
        if (legalLines.isNotEmpty) buf.writeln(legalLines.join('\n'));
        if (legalNote.isNotEmpty) {
          buf.writeln('Комментарий по материалам проверки: $legalNote');
        }
        contextParts.add(buf.toString().trim());
      }
      // Идентификация и технические параметры — раньше жили только во
      // внутреннем carContext и в сводку не шли. Кладём как факты.
      final idLines = <String>[];
      void addId(String label, String value) {
        final v = value.trim();
        if (v.isNotEmpty) idLines.add('$label: $v');
      }

      addId('Автомобиль', _carName());
      if (_vinUnreadable) {
        idLines.add('VIN: не читается');
      } else {
        addId('VIN', _vinController.text);
      }
      addId(
        'Госномер',
        _formatPlate(_sanitizePlate(_plateController.text.trim())),
      );
      addId('Пробег', _mileageController.text);
      if (_mileageMismatch == true) {
        idLines.add('Пробег: расхождение с заявленным/состоянием');
      }
      addId('Владельцев по документам', _ownersCountController.text);
      addId('Объём двигателя', _engineVolumeController.text);
      addId('Тип двигателя', _engineTypeController.text);
      addId('КПП', _gearboxTypeController.text);
      addId('Привод', _driveTypeController.text);
      addId('Цвет', _colorController.text);
      addId('Комплектация', _trimController.text);
      addId('Город осмотра', _inspectionCityController.text);
      final docMismatches = <String>[];
      if (_docsOwnerMatch == false) docMismatches.add('владелец');
      if (_docsVinMatch == false) docMismatches.add('VIN');
      if (_docsEngineMatch == false) docMismatches.add('двигатель');
      if (docMismatches.isNotEmpty) {
        idLines.add(
          'Сверка документов: расхождения — ${docMismatches.join(', ')}',
        );
      }
      final docsComment = _docsMismatchCommentController.text.trim();
      if (docsComment.isNotEmpty) {
        idLines.add('Комментарий по сверке документов: $docsComment');
      }
      if (idLines.isNotEmpty) {
        contextParts.add(
          '=== Идентификация и технические параметры ===\n'
          '${idLines.join('\n')}',
        );
      }
      // Свободный комментарий по тест-драйву (структурный шаблон его не несёт).
      final tdNote = _tdNoteController.text.trim();
      if (tdNote.isNotEmpty) {
        contextParts.add('=== Комментарий по тест-драйву ===\n$tdNote');
      }
      if (historyChunks.isNotEmpty) {
        contextParts.add(
          '=== AI-комментарии по элементам ===\n'
          '${historyChunks.join('\n---\n')}',
        );
      }
      // Current text — feed it back to the model as «previous draft» so
      // regeneration preserves manual edits
      // (corrections, dictation notes, deletions). Without this block
      // the AI overwrites their work each time the button is pressed.
      // Goes LAST in the context so the model treats it as the most
      // recent state and the structured/AI blocks as supporting info.
      final previousDraft = _summaryController.text.trim();
      if (previousDraft.isNotEmpty) {
        contextParts.add(
          '=== Предыдущий черновик (сохрани факты и правки, но '
          'переоформи в шаблон с заголовками) ===\n'
          '$previousDraft',
        );
      }
      if (contextParts.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Заполните хотя бы один раздел осмотра, чтобы AI было из чего собирать сводку.',
            ),
          ),
        );
        return;
      }

      final cliche = AiQueueClicheBuilder.buildReportFactsCliche(
        reportLabel: _reportNameController.text.trim(),
        carContext: _carContextForAi(),
      );
      // Fresh chatId per generation so the model gets a clean slate
      // and doesn't keep "polishing" the same answer.
      final newChatId = DateTime.now().microsecondsSinceEpoch.toUnsigned(32);
      final result = await AiQueueApi.chatCompletions(
        chatId: newChatId,
        text: contextParts.join('\n\n'),
        cliche: cliche,
      );
      final note = result.text.trim();
      if (note.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('AI вернул пустой ответ. Попробуйте ещё раз.'),
          ),
        );
        return;
      }
      _summaryController
        ..text = note
        ..selection = TextSelection.collapsed(offset: note.length);
      // Autosave listener attached to `_summaryController` already
      // marks the draft dirty, no explicit _markDraftDirty needed.
    } on storage_api.SessionExpiredException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('AI-помощник недоступен. Попробуйте позже.'),
        ),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _summaryNoteAiBusy = false);
      }
    }
  }

  Widget _commentInputPanel({
    required TextEditingController controller,
    required bool isDictating,
    required VoidCallback onToggleDictation,
    required VoidCallback onAiFormat,
    String hint = 'Добавьте комментарий',
    bool aiBusy = false,
    bool suppressOnboarding = false,
  }) {
    return SparkJoyCommentInputPanel(
      controller: controller,
      isDictating: isDictating,
      onToggleDictation: onToggleDictation,
      onAiFormat: onAiFormat,
      aiBusy: aiBusy,
      onDismissKeyboard: _dismissKeyboard,
      hint: hint,
      suppressOnboarding: suppressOnboarding,
    );
  }
}

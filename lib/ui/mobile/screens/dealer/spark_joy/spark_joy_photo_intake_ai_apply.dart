part of 'spark_joy_create_report_screen.dart';

/// Связывает data-layer интейка с моделью редактируемого отчёта. Сервис
/// владеет hash/S3/ИИ/ретраями, а здесь готовый план единожды применяется к
/// локальным оригиналам и только после успешного сохранения подтверждается.
extension _SparkJoyPhotoIntakeAiApply on _SparkJoyCreateReportScreenState {
  void _initializePhotoIntakeAi() {
    final taxonomy = _SparkJoyMediaGroupRegistry.groups
        .map((group) {
          final elements =
              (_SparkJoyMediaTagRegistry.mediaElementOptionsByGroup[group
                          .key] ??
                      const <_MediaOption>[])
                  .map((element) => (id: element.id, label: element.label))
                  .toList(growable: false);
          return (key: group.key, title: group.title, elements: elements);
        })
        .toList(growable: false);
    final config = SparkIntakeAiConfig(
      cliche: AiQueueClicheBuilder.buildIntakeDistributionCliche(
        inspectionGroups: taxonomy,
      ),
      videoCliche: AiQueueClicheBuilder.buildIntakeVideoDistributionCliche(
        inspectionGroups: taxonomy,
      ),
      elementsByGroup: <String, Set<String>>{
        for (final group in taxonomy)
          group.key: group.elements.map((element) => element.id).toSet(),
      },
    );
    final listenable = SparkJoyIntakeUploadService.instance.watch(_draftId);
    _intakeListenable = listenable;
    listenable.addListener(_onPhotoIntakeStateChanged);
    SparkJoyIntakeUploadService.instance.configureAi(_draftId, config);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onPhotoIntakeStateChanged();
    });
  }

  void _disposePhotoIntakeAi() {
    _intakeListenable?.removeListener(_onPhotoIntakeStateChanged);
    _intakeListenable = null;
  }

  void _onPhotoIntakeStateChanged() {
    if (!mounted) return;
    final snapshot = SparkJoyIntakeUploadService.instance.snapshotOf(_draftId);
    // Локальный OCR-поиск VIN стартует вместе с заливкой (эмит startUpload)
    // и после рестарта приложения (hydrate доводит снапшот до uploadRequested).
    // Сам метод дёшево выходит, если VIN уже есть или всё просканировано.
    if (snapshot.uploadRequested && snapshot.files.isNotEmpty) {
      unawaited(_runIntakeVinOcrSweep());
    }
    // OCR-кандидат VIN применяется по исходу vision-пути: done — СТС VIN
    // не дал (сеть доказана заливкой, автопроверки уместны), failed —
    // офлайн-сценарий (заполняем поле, проверки подождут сеть).
    if (snapshot.phase == SparkIntakePhase.failed) {
      unawaited(_maybeApplyIntakeOcrVin(allowChecks: false));
    } else if (snapshot.phase == SparkIntakePhase.done) {
      unawaited(_maybeApplyIntakeOcrVin(allowChecks: true));
    }
    if (_intakeApplyRunning) {
      _intakeApplyRequested = true;
      return;
    }
    if (snapshot.phase != SparkIntakePhase.classified) return;
    unawaited(_applyClassifiedPhotoIntake());
  }

  Future<void> _applyClassifiedPhotoIntake() async {
    if (_intakeApplyRunning || !mounted) return;
    _intakeApplyRunning = true;
    _intakeApplyRequested = false;
    try {
      final snapshot = SparkJoyIntakeUploadService.instance.snapshotOf(
        _draftId,
      );
      final records = snapshot.files.where(_intakeRecordIsApplicable).toList();
      if (records.isEmpty) return;

      final vinBeforeApply = _sanitizeVin(_vinController.text);
      final docResults = <DocScanAiResult>[];
      final appliedIds = <String>{};
      final videoThumbs = await _resolveIntakeVideoThumbs(records);
      if (!mounted) return;
      _setStateSafely(() {
        for (final record in records) {
          final videoThumbPath = videoThumbs[record.id];
          if (record.isVideo) {
            if (videoThumbPath == null) {
              _videoThumbsUnavailable.add(record.id);
            } else {
              _videoThumbsUnavailable.remove(record.id);
            }
          }
          final item = UploadedItem(
            id: record.id,
            name: record.name,
            originalName: record.originalName,
            displayName: record.displayName,
            mimeType: record.mimeType,
            dataUrl: record.localPath,
            videoThumbPath: videoThumbPath,
            inspection: record.aiSection == SparkIntakeAiSection.inspection
                ? MediaInspection(
                    elementType: record.aiElement.isEmpty
                        ? null
                        : record.aiElement,
                    isDraft: false,
                  )
                : const MediaInspection(),
          );

          if (record.isDocument ||
              record.aiSection == SparkIntakeAiSection.materials) {
            final existingIndex = _legalFiles.indexWhere(
              (existing) => _intakeItemMatches(existing, item),
            );
            if (existingIndex < 0) {
              _legalFiles = [..._legalFiles, item];
            } else if (videoThumbPath != null &&
                _legalFiles[existingIndex].videoThumbPath == null) {
              final updated = [..._legalFiles];
              updated[existingIndex] = updated[existingIndex].copyWith(
                videoThumbPath: videoThumbPath,
              );
              _legalFiles = updated;
            }
            final parsed = _intakeDocResult(record.aiDocJson);
            if (parsed != null && hasAnyDocScanData(parsed)) {
              docResults.add(parsed);
            }
            appliedIds.add(record.id);
            continue;
          }

          final group = _mediaState[record.aiGroup];
          if (group == null) continue;
          final existingIndex = group.files.indexWhere(
            (existing) => _intakeItemMatches(existing, item),
          );
          if (existingIndex < 0 ||
              (videoThumbPath != null &&
                  group.files[existingIndex].videoThumbPath == null)) {
            final files = [...group.files];
            if (existingIndex < 0) {
              files.add(item);
            } else {
              files[existingIndex] = files[existingIndex].copyWith(
                videoThumbPath: videoThumbPath,
              );
            }
            final partInspection = _syncPartInspectionWithFiles(
              partInspection: group.partInspection,
              files: files,
              deriveNoteFromFiles: true,
            );
            _mediaState[record.aiGroup] = group.copyWith(
              files: files,
              partInspection: partInspection,
              note: partInspection.note.trim(),
              hasIssue: files.any(_mediaItemHasIssue),
            );
          }
          appliedIds.add(record.id);
        }
      });

      final docReplaced = <String>{};
      for (final result in docResults) {
        if (!mounted) return;
        final applied = await _applyDocScanResult(
          result,
          runChecks: false,
          showFeedback: false,
        );
        docReplaced.addAll(applied.replaced);
      }
      // VIN из СТС/ПТС — целевой источник. Он заполняет пустое поле И
      // заменяет прежнее значение (например, чужое авто, подтянутое
      // конвертером по госномеру) — в обоих случаях «владение» переходит
      // интейку (нужно автопроверкам в повторных проходах). Кандидат
      // локального OCR — второй приоритет: применится, только если поле всё
      // ещё пусто.
      final vinAfterDocs = _sanitizeVin(_vinController.text);
      final docsChangedVin =
          vinAfterDocs.isNotEmpty &&
          (vinBeforeApply.isEmpty || docReplaced.contains('VIN'));
      if (docsChangedVin) {
        _intakeVinAutoFilled = vinAfterDocs;
      }
      await _maybeApplyIntakeOcrVin(allowChecks: false);
      if (!mounted || appliedIds.isEmpty) return;
      _markDraftDirty(scheduleAutosave: false);
      await _saveDraft(showToast: false);
      if (_draftSaveFailed) return;
      await SparkJoyIntakeUploadService.instance.acknowledgeApplied(
        _draftId,
        appliedIds,
      );
      if (mounted) {
        final message = StringBuffer(
          'ИИ распределил ${sparkIntakeFilesCountLabel(appliedIds.length)}',
        );
        if (docReplaced.isNotEmpty) {
          // Документ перезаписал уже заполненные поля — молчать нельзя:
          // пользователь должен видеть, что идентичность авто изменилась.
          message.write('. Обновлено по документу: ${docReplaced.join(', ')}');
          if (docReplaced.contains('VIN') && _intakeChecksAlreadyStarted) {
            message.write(
              '. Материалы проверки относятся к прежнему VIN — '
              'обновите их в шаге «Материалы проверки»',
            );
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message.toString())));
      }
      // Автопроверки: только когда VIN принадлежит интейку — заполнен или
      // заменён им в этом проходе (СТС/кандидат) или раньше (офлайн-заполнение
      // кандидатом, после которого вернулась сеть). Ручной VIN автозапуск
      // не трогает.
      final vinIntakeOwned =
          vinBeforeApply.isEmpty ||
          docsChangedVin ||
          (_intakeVinAutoFilled.isNotEmpty &&
              vinBeforeApply == _intakeVinAutoFilled);
      if (mounted &&
          vinIntakeOwned &&
          _sanitizeVin(_vinController.text).length == 17) {
        await _maybeAutoStartIntakeChecks();
      }
    } finally {
      _intakeApplyRunning = false;
      if (mounted && _intakeApplyRequested) {
        // Только реальная нотификация, пришедшая за время await, запускает
        // следующий проход. Ошибка сохранения не превращается в hot-loop.
        _intakeApplyRequested = false;
        _onPhotoIntakeStateChanged();
      }
    }
  }

  Future<Map<String, String?>> _resolveIntakeVideoThumbs(
    List<SparkIntakeFileRecord> records,
  ) async {
    final result = <String, String?>{};
    for (final record in records) {
      if (!record.isVideo) continue;
      final existing = record.videoThumbPath?.trim();
      if (existing != null && existing.isNotEmpty) {
        try {
          if (await File(existing).exists()) {
            result[record.id] = existing;
            continue;
          }
        } catch (_) {}
      }
      final localPath = _extractLocalMediaPath(record.localPath);
      result[record.id] = localPath == null
          ? null
          : await _resolveSparkJoyVideoThumb(localPath);
    }
    return result;
  }

  bool _intakeRecordIsApplicable(SparkIntakeFileRecord record) {
    if (record.isDocument) return record.isUploaded;
    return switch (record.aiSection) {
      SparkIntakeAiSection.materials =>
        record.aiDocumentKind != SparkIntakeDocumentKind.vehicleDoc ||
            record.aiDocJson.isNotEmpty,
      SparkIntakeAiSection.inspection =>
        record.aiGroup.isNotEmpty && _mediaState.containsKey(record.aiGroup),
      _ => false,
    };
  }

  bool _intakeItemMatches(UploadedItem item, UploadedItem candidate) =>
      item.id == candidate.id ||
      item.dataUrl.trim() == candidate.dataUrl.trim();

  DocScanAiResult? _intakeDocResult(String rawJson) {
    if (rawJson.trim().isEmpty) return null;
    try {
      final raw = jsonDecode(rawJson);
      if (raw is! Map) return null;
      String read(String key) => raw[key]?.toString().trim() ?? '';
      return (
        docType: read('docType'),
        vin: read('vin'),
        gosNumber: read('gosNumber'),
        brand: read('brand'),
        model: read('model'),
        year: read('year'),
        color: read('color'),
      );
    } catch (_) {
      return null;
    }
  }

  // ── VIN из фото интейка ────────────────────────────────────────────────

  /// Локальный OCR-проход по фото интейка (MLKit на устройстве, бесплатно и
  /// офлайн): стартует с «Распределить файлы», ищет VIN на снимках (лобовое
  /// стекло, шильдик, СТС), но НЕ применяет находку сразу. Извлечение —
  /// СТРОГИЙ построчный режим [extractVinCandidatesFromOcrText]: свип
  /// безнадзорный, его находка автозаполняет поле и запускает платные вызовы,
  /// поэтому «суп» из склеенного текста фото недопустим (инцидент 2026-07-21:
  /// левый VIN с фото без VIN ушёл в материалы проверки). Целевой источник
  /// VIN — vision-скан СТС/ПТС (он видит весь документ), а он приезжает
  /// после заливки и раскладки. Первый строгий VIN здесь — только кандидат
  /// ([_intakeOcrVinCandidate]), который применяется:
  ///  • сразу — когда заливка упала (офлайн-сценарий: OCR и нужен без сети);
  ///    без автопроверок — сети всё равно нет, их запустит apply после
  ///    восстановления (VIN числится за интейком);
  ///  • после раскладки (apply/done) — когда СТС в пачке не нашлось или VIN
  ///    с него не прочитался: «лобовое» — второй приоритет, сеть доказана
  ///    заливкой, автопроверки уместны;
  ///  • никогда — когда СТС уже дал VIN или поле заполнено вручную
  ///    (only-empty, ручной ввод неприкосновенен).
  Future<void> _runIntakeVinOcrSweep() async {
    if (!vinOcrSupported || widget.readOnly || _intakeVinSweepRunning) return;
    if (_sanitizeVin(_vinController.text).length == 17) return;
    _intakeVinSweepRunning = true;
    try {
      final files = SparkJoyIntakeUploadService.instance
          .snapshotOf(_draftId)
          .files;
      for (final record in files) {
        if (!mounted) return;
        // «Прервать» снимает uploadRequested — после явной отмены не гоняем
        // OCR дальше и тем более не запускаем платные операции.
        if (!SparkJoyIntakeUploadService.instance
            .snapshotOf(_draftId)
            .uploadRequested) {
          return;
        }
        if (_sanitizeVin(_vinController.text).length == 17) return;
        if (!record.isImage) continue;
        // Каждую запись гоняем через MLKit один раз за сессию — набор
        // переживает проход и защищает от рескана на каждом эмите сервиса.
        if (!_intakeVinSweepScanned.add(record.id)) continue;
        final localPath = _extractLocalMediaPath(record.localPath);
        if (localPath == null) continue;
        Uint8List bytes;
        try {
          bytes = await File(localPath).readAsBytes();
        } catch (_) {
          continue;
        }
        if (bytes.isEmpty) continue;
        String vin;
        try {
          final ocr = await scanVinFromImageBytes(bytes);
          // Strict: находка без человека автозаполнит поле и запустит платные
          // вызовы (конвертер + материалы проверки) — построчный строгий
          // экстрактор и есть защита денег от «VIN» с шин/наклеек/номеров
          // (инцидент 2026-07-21). Мягкий режим — только там, где кандидата
          // подтверждает пользователь (ручной сканер, скан СТС).
          vin = _extractVinFromOcrResult(ocr, mode: VinExtractionMode.strict);
        } catch (_) {
          continue;
        }
        if (vin.isEmpty || !_isStrictVin(vin)) continue;
        if (!mounted) return;
        // Отмена могла прийти за время OCR этого фото.
        if (!SparkJoyIntakeUploadService.instance
            .snapshotOf(_draftId)
            .uploadRequested) {
          return;
        }
        _intakeOcrVinCandidate = vin;
        // СТС — целевой источник: пока заливка/раскладка живы, ждём его
        // вердикта. Кандидат применяется сразу, только если vision-путь
        // уже закончился (done) или сломался (failed = офлайн).
        final phase = SparkJoyIntakeUploadService.instance
            .snapshotOf(_draftId)
            .phase;
        if (phase == SparkIntakePhase.failed) {
          await _maybeApplyIntakeOcrVin(allowChecks: false);
        } else if (phase == SparkIntakePhase.done) {
          await _maybeApplyIntakeOcrVin(allowChecks: true);
        }
        return;
      }
    } finally {
      _intakeVinSweepRunning = false;
    }
  }

  /// Применяет OCR-кандидата VIN (второй приоритет после СТС, см.
  /// [_runIntakeVinOcrSweep]). Only-empty: ручной ввод и VIN из СТС
  /// неприкосновенны. [allowChecks] == false в офлайн-ветке (фаза failed):
  /// сети нет и платный батч всё равно не уйдёт; когда заливка доедет,
  /// автопроверки запустит apply — VIN числится за интейком через
  /// [_intakeVinAutoFilled].
  Future<void> _maybeApplyIntakeOcrVin({required bool allowChecks}) async {
    if (widget.readOnly || !mounted) return;
    final candidate = _intakeOcrVinCandidate;
    if (candidate.isEmpty) return;
    if (_sanitizeVin(_vinController.text).isNotEmpty) return;
    _setStateSafely(() {
      _vinUnreadable = false;
      _vinController.text = candidate;
    });
    _intakeVinAutoFilled = candidate;
    // Listener контроллера дёрнет конвейер VIN→марка/модель/параметры сам,
    // но явный вызов страхует сценарии без подписки (как в
    // _applyDocScanResult).
    _maybeResolveFromVin();
    _markDraftDirty();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('VIN распознан с фото: $candidate')),
    );
    if (allowChecks) {
      await _maybeAutoStartIntakeChecks();
    }
  }

  /// Автозапуск платных проверок после того, как интейк сам добыл VIN
  /// (локальный OCR или vision-скан СТС/ПТС). Согласием считается нажатие
  /// «Распределить файлы» — задумка фичи: материалы проверки подтягиваются
  /// по найденному VIN автоматически. Решение Григория 2026-07-21: UI-
  /// подтверждение перед платным запуском НЕ добавляем — защита от мусорного
  /// VIN целиком лежит на строгом построчном экстракторе
  /// (vin_text_extraction.dart); то же касается платного конвертера, который
  /// стреляет ещё раньше, из _maybeResolveFromVin. Гарды повторяют чекбокс
  /// ручного скана: проверки ещё не запускались, право run_legal_review
  /// есть, VIN строгий.
  Future<void> _maybeAutoStartIntakeChecks() async {
    if (widget.readOnly || !mounted) return;
    final vin = _sanitizeVin(_vinController.text);
    if (vin.length != 17 || !_isStrictVin(vin)) return;
    if (_intakeChecksAlreadyStarted) return;
    // Право и каталог типов грузятся лениво из шагов и могли быть в полёте
    // (in-flight-гард _ensureLegalReviewMeta выходит мгновенно, кулдаун 3с) —
    // несколько терпеливых заходов вместо молчаливой потери автозапуска.
    for (var attempt = 0; ; attempt++) {
      await _ensureLegalReviewMeta();
      if (!mounted || _intakeChecksAlreadyStarted) return;
      if (_sanitizeVin(_vinController.text) != vin) return;
      if (_legalCanRunReview && _legalAvailableCheckTypes.isNotEmpty) break;
      if (attempt >= 2) {
        // Права так и нет — молчим: у роли его может не быть вовсе, снек был
        // бы шумом. Право есть, но каталог не доехал — дальше честный снек
        // скажет _autoStartLegalChecksAfterDocScan.
        if (!_legalCanRunReview) return;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Запускаю проверки по распознанному VIN')),
    );
    _autoStartLegalChecksAfterDocScan();
  }

  /// Проверки уже когда-то стартовали (куплены/идут/загружены) — автозапуску
  /// делать нечего.
  bool get _intakeChecksAlreadyStarted =>
      _legalPurchased ||
      _legalLoading ||
      _legalLoaded ||
      (_legalBatchNumber ?? '').trim().isNotEmpty;
}

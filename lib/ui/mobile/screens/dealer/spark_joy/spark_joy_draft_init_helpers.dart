part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyDraftInitHelpers on _SparkJoyCreateReportScreenState {
  void _loadDraftIntoState({
    required Map<String, dynamic> draft,
    required Map<String, dynamic> assignment,
    required DateTime now,
  }) {
    _draftId = _read(
      draft,
      'id',
      fallback: 'spark_draft_${now.microsecondsSinceEpoch}',
    );

    _createdAt = _read(draft, 'createdAt', fallback: _dateLabel(now));
    _reportCode = _read(
      draft,
      'reportNumber',
      fallback: _read(draft, 'reportCode'),
    );
    _lastDraftSavedAt = DateTime.tryParse(_read(draft, 'lastSavedAtIso'));

    _assignmentId = _read(
      draft,
      'assignmentId',
      fallback: _read(assignment, 'id'),
    );
    final draftRequestId = _readInt(draft, 'requestId');
    final assignmentRequestId = _readInt(assignment, 'requestId');
    _requestId = draftRequestId > 0
        ? draftRequestId
        : (assignmentRequestId > 0 ? assignmentRequestId : null);
    final draftBusinessType = _read(draft, 'businessType');
    _accountBusinessType = draftBusinessType.isEmpty ? null : draftBusinessType;
    final draftVerifiedInn = _read(draft, 'verifiedInn');
    _accountVerifiedInn = draftVerifiedInn.isEmpty ? null : draftVerifiedInn;
    _staffInviteLink = _read(
      draft,
      'staffInviteLink',
      fallback: widget.initialStaffInviteLink ?? '',
    );

    _stepIndex = _reportFlowController.sanitizeStepIndex(
      _readInt(draft, 'currentStep', fallback: 1) - 1,
      totalSteps: _SparkJoyStepRegistry.steps.length,
    );

    final fallbackCar = _read(
      draft,
      'car',
      fallback: _read(assignment, 'vehicle'),
    );
    final fallbackCarParts = fallbackCar.trim().split(RegExp(r'\s+'));

    _reportNameController = TextEditingController(
      text: _read(
        draft,
        'reportName',
        fallback:
            widget.initialReportName?.trim() ?? _read(assignment, 'title'),
      ),
    );
    _inlineReportNameController = TextEditingController(
      text: _reportNameController.text,
    );
    _vinController = TextEditingController(
      text: _read(draft, 'vin', fallback: _read(assignment, 'vin')),
    );
    // Ручной выбор страны больше не используется. Даже если старый черновик
    // хранит выбранную страну и lock, восстанавливаем номер через актуальный
    // автоматический детектор, чтобы поведение совпадало с обычным вводом.
    final normalizedPlate = normalizePlateAutomatically(_read(draft, 'plate'));
    _plateCountry = normalizedPlate.country ?? PlateCountry.other;
    _plateController = TextEditingController(text: normalizedPlate.text);
    if (normalizedPlate.text.isNotEmpty) {
      // У восстановленного черновика поле уже наполнено — валидация
      // должна работать сразу, без ожидания нового blur'а.
      _plateBlurred = true;
    }
    _brandController = TextEditingController(
      text: _read(
        draft,
        'brand',
        fallback: fallbackCarParts.isNotEmpty ? fallbackCarParts.first : '',
      ),
    );
    _modelController = TextEditingController(
      text: _read(
        draft,
        'model',
        fallback: fallbackCarParts.length > 1
            ? fallbackCarParts.sublist(1).join(' ')
            : '',
      ),
    );
    _generationController = TextEditingController(
      text: _read(draft, 'generation'),
    );
    _restylingLabel = _read(draft, 'restyling');
    _carPhotoUrl = _read(draft, 'carPhotoUrl');
    _carFrames = _read(draft, 'carFrames');
    _listingPdfUrl = _read(draft, 'listingPdfUrl');
    // Draft-shape key + fallback to the characteristicsStep.* path the
    // server response uses. Lets hydrateCompletedReport piggy-back on
    // `_normalizeSpecialistReportMap` without extra flattening.
    final rawFrameId = draft['modelGenerationRestylingFrameId'];
    final characteristics = draft['characteristicsStep'];
    final frameIdFromCar = rawFrameId is int
        ? rawFrameId
        : (rawFrameId is num
              ? rawFrameId.toInt()
              : int.tryParse('${rawFrameId ?? ''}'));
    final frameIdFromChar = characteristics is Map
        ? (characteristics['modelGenerationRestylingFrameId'] is int
              ? characteristics['modelGenerationRestylingFrameId'] as int
              : int.tryParse(
                  '${characteristics['modelGenerationRestylingFrameId'] ?? ''}',
                ))
        : null;
    _modelGenerationRestylingFrameId =
        (frameIdFromCar != null && frameIdFromCar > 0)
        ? frameIdFromCar
        : ((frameIdFromChar != null && frameIdFromChar > 0)
              ? frameIdFromChar
              : null);
    // Каталожная привязка марки/модели (если черновик сохранён новым кодом) —
    // позволяет автокомплиту сразу предложить модели для brandId. Legacy без
    // этих ключей → null, восстановление по требованию при фокусе поля модели.
    final rawBrandId = draft['brandId'];
    final parsedBrandId = rawBrandId is int
        ? rawBrandId
        : (rawBrandId is num
              ? rawBrandId.toInt()
              : int.tryParse('${rawBrandId ?? ''}'));
    _selectedBrandId = (parsedBrandId != null && parsedBrandId > 0)
        ? parsedBrandId
        : null;
    final rawModelCarId = draft['modelCarId'];
    final parsedModelCarId = rawModelCarId is int
        ? rawModelCarId
        : (rawModelCarId is num
              ? rawModelCarId.toInt()
              : int.tryParse('${rawModelCarId ?? ''}'));
    _selectedModelCarId = (parsedModelCarId != null && parsedModelCarId > 0)
        ? parsedModelCarId
        : null;
    final rawGenerationNumber = draft['generationNumber'];
    final parsedGenerationNumber = rawGenerationNumber is int
        ? rawGenerationNumber
        : (rawGenerationNumber is num
              ? rawGenerationNumber.toInt()
              : int.tryParse('${rawGenerationNumber ?? ''}'));
    _selectedGenerationNumber =
        (parsedGenerationNumber != null && parsedGenerationNumber > 0)
        ? parsedGenerationNumber
        : null;
    _adLinkController = TextEditingController(
      text: _read(draft, 'adLink', fallback: _read(assignment, 'listingUrl')),
    );

    _mileageController = TextEditingController(text: _read(draft, 'mileage'));
    _engineVolumeController = TextEditingController(
      text: _read(draft, 'engineVolume', fallback: _read(draft, 'engine')),
    );
    _engineTypeController = TextEditingController(
      text: _read(draft, 'engineType'),
    );
    _gearboxTypeController = TextEditingController(
      text: _read(draft, 'gearboxType', fallback: _read(draft, 'transmission')),
    );
    _driveTypeController = TextEditingController(
      text: _read(draft, 'driveType', fallback: _read(draft, 'drive')),
    );
    _colorController = TextEditingController(text: _read(draft, 'color'));
    _trimController = TextEditingController(text: _read(draft, 'trim'));
    _ownersCountController = TextEditingController(
      text: _read(draft, 'ownersCount', fallback: _read(draft, 'owners')),
    );
    _inspectionCityController = TextEditingController(
      text: _read(draft, 'inspectionCity', fallback: _read(assignment, 'city')),
    );
    _inspectionDateController = TextEditingController(
      text: _read(draft, 'inspectionDate', fallback: _dateLabel(now)),
    );

    _docsMismatchCommentController = TextEditingController(
      text: _read(
        draft,
        'docsMismatchComment',
        fallback: _read(draft, 'docsConflictComment'),
      ),
    );
    _legalNoteController = TextEditingController(
      text: _read(draft, 'legalNote'),
    );
    _tdNoteController = TextEditingController(text: _read(draft, 'tdNote'));
    // Single «Итог осмотра» field — supersedes the old двойник
    // «Сводка» + «Итог специалиста». For legacy drafts where both
    // wire keys (`summaryNote`/`summary` and `expertConclusion`) are
    // populated, merge them via `\n\n` so nothing is lost. New drafts
    // pre-2026-05-06 had only `summaryNote`; freshly-saved drafts
    // post-merge replicate the same text into both keys, so reading
    // either key alone is correct for them.
    final legacySummary = _read(
      draft,
      'summaryNote',
      fallback: _read(draft, 'summary'),
    ).trim();
    final legacyExpert = _normalizeInitialExpertConclusion(draft).trim();
    final mergedSummary = (legacySummary == legacyExpert)
        ? legacySummary
        : <String>[
            legacySummary,
            legacyExpert,
          ].where((s) => s.isNotEmpty).join('\n\n');
    _summaryController = TextEditingController(text: mergedSummary);
    _inspectorController = TextEditingController(
      text: _read(draft, 'inspector', fallback: 'Специалист'),
    );
    _assignedSpecialistId = _read(
      draft,
      'assignedSpecialistId',
      fallback: _read(
        draft,
        'specialistId',
        fallback:
            widget.initialAssignedSpecialistId ??
            _read(assignment, 'specialistId'),
      ),
    );
    _assignedSpecialistName = _read(
      draft,
      'assignedSpecialistName',
      fallback: _read(
        draft,
        'specialistName',
        fallback:
            widget.initialAssignedSpecialistName ??
            _read(assignment, 'specialistName'),
      ),
    );
    if (_assignedSpecialistName.isEmpty && _assignedSpecialistId.isNotEmpty) {
      _assignedSpecialistName = _resolveSpecialistName(_assignedSpecialistId);
    }

    _mileageMismatch = _readTriState(draft['mileageMismatch']);
    if (_mileageMismatch == null &&
        draft.containsKey('mileageMatchesClaimed')) {
      final legacyMatchesClaimed = _readTriState(
        draft['mileageMatchesClaimed'],
      );
      if (legacyMatchesClaimed != null) {
        _mileageMismatch = !legacyMatchesClaimed;
      }
    }
    _vinUnreadable = _readBool(draft, 'vinUnreadable');

    _docsOwnerMatch = _readTriState(draft['docsOwnerMatch']);
    _docsVinMatch = _readTriState(draft['docsVinMatch']);
    _docsEngineMatch = _readTriState(draft['docsEngineMatch']);

    _legalLoading = _readBool(draft, 'legalLoading');
    _legalLoaded = _readBool(draft, 'legalLoaded');
    _legalSkipped = _readBool(draft, 'legalSkipped');
    _legalTimedOut = _readBool(draft, 'legalTimedOut');
    _legalPurchased = _readBool(draft, 'legalPurchased');
    // B2 — ApiCloud legal-review state.
    final rawBatch = draft['legalBatchNumber'];
    _legalBatchNumber = (rawBatch is String && rawBatch.trim().isNotEmpty)
        ? rawBatch.trim()
        : null;
    final rawSelectedChecks = draft['legalSelectedCheckTypes'];
    _legalSelectedCheckTypes = rawSelectedChecks is List
        ? rawSelectedChecks
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];
    final rawCheckResults = draft['legalCheckResults'];
    _legalCheckResults = rawCheckResults is List
        ? rawCheckResults
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    _legalFiles = _readUploadedList(draft['legalFiles']);
    _docsCommentAudioFiles = _readUploadedList(draft['docsCommentAudioFiles']);
    _legalCommentAudioFiles = _readUploadedList(
      draft['legalCommentAudioFiles'],
    );
    _bodyPaintFrom = _readDouble(draft, 'bodyPaintFrom', fallback: 80);
    _bodyPaintTo = _readDouble(draft, 'bodyPaintTo', fallback: 200);
    _structPaintFrom = _readDouble(draft, 'structPaintFrom', fallback: 80);
    _structPaintTo = _readDouble(draft, 'structPaintTo', fallback: 200);

    final legacyTdConducted = _readTriState(draft['tdConducted']);
    _tdEngineOk = _readBool(
      draft,
      'tdEngineOk',
      fallback: !_readBool(draft, 'tdEngineIssue'),
    );
    _tdGearboxOk = _readBool(
      draft,
      'tdGearboxOk',
      fallback: !_readBool(draft, 'tdGearboxIssue'),
    );
    _tdSteeringOk = _readBool(
      draft,
      'tdSteeringOk',
      fallback: !_readBool(draft, 'tdSteeringIssue'),
    );
    _tdRideOk = _readBool(
      draft,
      'tdRideOk',
      fallback: !_readBool(draft, 'tdRideIssue'),
    );
    _tdBrakeOk = _readBool(
      draft,
      'tdBrakeOk',
      fallback: !_readBool(draft, 'tdBrakeIssue'),
    );
    _tdEngineTags = _readStringList(draft['tdEngineTags']);
    _tdGearboxTags = _readStringList(draft['tdGearboxTags']);
    _tdSteeringTags = _readStringList(draft['tdSteeringTags']);
    _tdRideTags = _readStringList(draft['tdRideTags']);
    _tdBrakeTags = _readStringList(draft['tdBrakeTags']);
    _tdCommentAudioFiles = _readUploadedList(draft['tdCommentAudioFiles']);
    _tdMode = _normalizeTdMode(_read(draft, 'tdConductedMode'));
    if (_tdMode == null && legacyTdConducted != null) {
      if (legacyTdConducted == false) {
        _tdMode = _SparkJoyTestDriveRegistry.modeNotConducted;
      } else if (_areAllTdSectionsClean()) {
        _tdMode = _SparkJoyTestDriveRegistry.modeAllGood;
      } else {
        _tdMode = _SparkJoyTestDriveRegistry.modeProblems;
      }
    }
    _expertAudioFiles = _readUploadedList(draft['expertAudioFiles']);

    _mediaState = _initMediaState(draft);
    // Restored drafts keep their persisted videoThumbPath, but pre-feature
    // drafts (or JPEGs the OS purged) need a one-time regeneration. Run it
    // after the first frame so restore never blocks, reusing the same
    // serialized generator as the pick path — already-resolved items are
    // skipped, so this is a no-op when thumbnails are intact.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final entry in _mediaState.entries) {
        unawaited(_generateVideoThumbsForGroup(entry.key, entry.value.files));
      }
    });
    _mediaCustomTagsByScope = _readStringListMap(draft['mediaCustomTags']);
    _mediaCustomSeriousTagsByScope = _readStringListMap(
      draft['mediaCustomSeriousTags'],
    );
    _mediaDisabledDefaultTagsByScope = _readStringListMap(
      draft['mediaDisabledDefaultTags'],
    );
    _mediaTagOrderByScope = _readStringListMap(draft['mediaTagOrder']);
    final rawBackendUploadState = draft['backendUploadState'];
    if (rawBackendUploadState is Map) {
      _backendUploadState = cloneMap(
        Map<String, dynamic>.from(rawBackendUploadState),
      );
    } else {
      _backendUploadState = <String, dynamic>{};
    }
    final rawAiQueue = draft['aiQueue'];
    final aiQueueMap = rawAiQueue is Map
        ? Map<String, dynamic>.from(rawAiQueue)
        : null;
    _reportController.hydrateAiChatStateFromDraft(aiQueueMap);
    // Hydrate the offline runner synchronously: it walks an in-memory
    // map and never hits I/O, so we don't pay much for awaiting and we
    // close a real race window — a `runner.enqueue` racing the rebuild
    // would otherwise be wiped by `state.pending.clear()` here.
    AiQueueOfflineRunner.instance.hydrateFromDraft(
      draftId: _draftId,
      rawAiQueue: aiQueueMap,
    );
    // Интейк «Фото автомобиля»: тот же синхронный гидрейт (гонка с
    // stageFiles закрывается до первого кадра); reconcile с БД задач
    // транспорта и авто-дозаливка — его асинхронный хвост. Read-only
    // просмотр завершённого отчёта заливками не управляет.
    if (!widget.readOnly) {
      final rawPhotoIntake = draft['photoIntake'];
      SparkJoyIntakeUploadService.instance.hydrateFromDraft(
        draftId: _draftId,
        rawPhotoIntake: rawPhotoIntake is Map
            ? Map<String, dynamic>.from(rawPhotoIntake)
            : null,
      );
    }

    unawaited(_compactInlineDraftMediaIfNeeded());
    unawaited(_loadBusinessStatusFromStorage());
    // Recompute city validity against the bundled list. Existing
    // drafts may carry free-form values from before the picker
    // existed; this lets the completion rule know whether they're
    // canonical without forcing the inspector to open the picker.
    unawaited(_refreshInspectionCityValidity());
  }
}

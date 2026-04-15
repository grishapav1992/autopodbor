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
    _vinController = TextEditingController(
      text: _read(draft, 'vin', fallback: _read(assignment, 'vin')),
    );
    _plateController = TextEditingController(text: _read(draft, 'plate'));
    final initialPlate = _sanitizePlate(_plateController.text);
    if (initialPlate.isNotEmpty) {
      _plateController.text = _formatPlate(initialPlate);
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
    _summaryController = TextEditingController(
      text: _read(draft, 'summaryNote', fallback: _read(draft, 'summary')),
    );
    _expertController = TextEditingController(
      text: _normalizeInitialExpertConclusion(draft),
    );
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
    unawaited(_compactInlineDraftMediaIfNeeded());
    unawaited(_loadBusinessStatusFromStorage());
  }
}

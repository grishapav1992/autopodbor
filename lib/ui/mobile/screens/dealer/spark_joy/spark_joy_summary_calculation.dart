part of 'spark_joy_create_report_screen.dart';

extension _SparkJoySummaryCalculation on _SparkJoyCreateReportScreenState {
  /// Поллит `GetBatchLegalReviewResults` пока все проверки не выйдут из
  /// pending (или пока не упрёмся в потолок попыток → `_legalTimedOut`).
  /// [token] отсекает устаревший прогон; выходим, если экран закрыт или
  /// стартовал новый прогон.
  Future<void> _pollLegalBatchResults(int token, String batchNumber) async {
    const interval = Duration(seconds: 3);
    // ~120s потолок: live ApiCloud-проверки идут десятки секунд (zalog/taxi/
    // converter). Недозавершённые к таймауту не теряются — hydrator подтянет
    // их по batchIds при повторном открытии завершённого отчёта.
    const maxAttempts = 40;
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
      _setStateSafely(() => _legalCheckResults = checks);
      final stillPending = storage_api.legalReviewBatchPending(checks);
      if (!stillPending) {
        _setStateSafely(() {
          _legalLoading = false;
          _legalLoaded = true;
          _legalTimedOut = false;
        });
        _markDraftDirty();
        return;
      }
    }
    if (!mounted || token != _legalLoadToken) return;
    _setStateSafely(() {
      _legalLoading = false;
      _legalTimedOut = true;
    });
    _markDraftDirty();
  }

  /// Однократно подгружает мета-данные шага «Материалы проверки»:
  /// право `run_legal_review` (из кэша прав, который B1 сидит на старте) и
  /// каталог доступных типов проверок. Безопасно звать из build шага —
  /// guard `_legalReviewMetaLoadStarted` гарантирует один запуск, а setState
  /// происходит только после await (не во время build).
  Future<void> _ensureLegalReviewMeta() async {
    if (_legalReviewMetaLoadStarted) return;
    _legalReviewMetaLoadStarted = true;
    try {
      final perms = await UserSimplePreferences.getPermissions();
      if (mounted) {
        _setStateSafely(
          () => _legalCanRunReview = perms.contains('run_legal_review'),
        );
      }
    } catch (_) {}
    try {
      final types =
          await storage_api.StorageApi.getAvailableLegalReviewCheckTypes();
      if (mounted && types.isNotEmpty) {
        _setStateSafely(() => _legalAvailableCheckTypes = types);
      }
    } catch (_) {}
  }

  Future<void> _startLegalLoading() async {
    if (_legalLoading) return;
    final checkTypes = _legalSelectedCheckTypes.toList();
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

    final vin = _vinController.text.trim();
    final plate = _sanitizePlate(_plateController.text.trim());
    try {
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

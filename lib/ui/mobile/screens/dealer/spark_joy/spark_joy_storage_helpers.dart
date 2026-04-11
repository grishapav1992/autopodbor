part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyStorageHelpers on _SparkJoyCreateReportScreenState {
  bool _isDataUrl(String source) {
    return source.trimLeft().startsWith('data:');
  }

  Future<void> _prepareStoragePaths() async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
    } catch (_) {}
  }

  String _normalizeDocumentsLocalPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty || kIsWeb) return normalized;
    final docsPath = _appDocumentsPath;
    if (docsPath == null || docsPath.isEmpty) return normalized;
    const marker = '/Documents/';
    final markerIndex = normalized.indexOf(marker);
    if (markerIndex < 0) return normalized;
    final relative = normalized.substring(markerIndex + marker.length).trim();
    if (relative.isEmpty) return normalized;
    return '$docsPath/$relative';
  }

  String? _extractLocalMediaPath(String source) {
    final normalized = source.trim();
    if (normalized.isEmpty || _isDataUrl(normalized)) return null;
    final parsed = Uri.tryParse(normalized);
    if (parsed == null) return _normalizeDocumentsLocalPath(normalized);
    if (!parsed.hasScheme) return _normalizeDocumentsLocalPath(normalized);
    if (parsed.scheme == 'file') {
      try {
        return _normalizeDocumentsLocalPath(parsed.toFilePath());
      } catch (_) {
        final plain = normalized
            .replaceFirst(RegExp(r'^file://'), '')
            .replaceFirst(RegExp(r'^file:'), '');
        return _normalizeDocumentsLocalPath(plain);
      }
    }
    return null;
  }

  Uri _mediaSourceUri(String source) {
    final localPath = _extractLocalMediaPath(source);
    if (localPath != null) {
      return Uri.file(localPath);
    }
    return Uri.parse(source);
  }

  Source _audioPlayerSource(String source) {
    final localPath = _extractLocalMediaPath(source);
    if (!kIsWeb && localPath != null) {
      return DeviceFileSource(localPath);
    }
    return UrlSource(source);
  }

  Future<Source> _audioPlayerSourceForPlayback(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) {
      return UrlSource(source);
    }

    if (_resolvedAudioPlaybackSources.containsKey(normalized)) {
      final resolved = _resolvedAudioPlaybackSources[normalized]!;
      return _audioPlayerSource(resolved);
    }

    if (_isDataUrl(normalized) && !kIsWeb) {
      final persisted = await _persistDataUrlToAppStorage(
        normalized,
        mimeType: _dataUrlMimeType(normalized),
        prefix: 'audio_play',
      );
      if ((persisted ?? '').isNotEmpty) {
        _resolvedAudioPlaybackSources[normalized] = persisted!;
        return _audioPlayerSource(persisted);
      }
      throw StateError('Не удалось подготовить аудиофайл для воспроизведения');
    }

    return _audioPlayerSource(normalized);
  }

  Future<void> _playAudioSource(AudioPlayer player, String source) async {
    if (source.trim().isEmpty) {
      throw StateError('Пустой аудиофайл');
    }
    final preparedSource = await _audioPlayerSourceForPlayback(source);
    await player.play(preparedSource);
  }

  String _extensionForMimeType(String mimeType) {
    final normalized = mimeType.toLowerCase();
    if (normalized.contains('image/png')) return 'png';
    if (normalized.contains('image/jpeg')) return 'jpg';
    if (normalized.contains('image/webp')) return 'webp';
    if (normalized.contains('image/heic')) return 'heic';
    if (normalized.contains('image/heif')) return 'heif';
    if (normalized.contains('video/mp4')) return 'mp4';
    if (normalized.contains('video/quicktime')) return 'mov';
    if (normalized.contains('video/webm')) return 'webm';
    if (normalized.contains('audio/wav')) return 'wav';
    if (normalized.contains('audio/mpeg')) return 'mp3';
    if (normalized.contains('audio/mp4')) return 'm4a';
    if (normalized.contains('audio/aac')) return 'aac';
    if (normalized.contains('audio/ogg')) return 'ogg';
    return 'bin';
  }

  Future<String?> _persistBytesToAppStorage({
    required Uint8List bytes,
    required String mimeType,
    required String prefix,
  }) async {
    if (kIsWeb || bytes.isEmpty) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      _localMediaFileCounter += 1;
      final extension = _extensionForMimeType(mimeType);
      final fileName =
          'spark_${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_localMediaFileCounter.$extension';
      final filePath = '${directory.path}/$fileName';
      final xFile = XFile.fromData(bytes, name: fileName, mimeType: mimeType);
      await xFile.saveTo(filePath);
      return Uri.file(filePath).toString();
    } catch (_) {
      return null;
    }
  }

  String _dataUrlMimeType(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex <= 0) return 'application/octet-stream';
    final header = dataUrl.substring(0, commaIndex);
    final semicolonIndex = header.indexOf(';');
    final mimeStart = header.startsWith('data:') ? 5 : 0;
    if (semicolonIndex > mimeStart) {
      return header.substring(mimeStart, semicolonIndex);
    }
    final value = header.substring(mimeStart).trim();
    return value.isEmpty ? 'application/octet-stream' : value;
  }

  Future<String?> _persistDataUrlToAppStorage(
    String dataUrl, {
    String? mimeType,
    required String prefix,
  }) async {
    if (kIsWeb || !_isDataUrl(dataUrl)) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= dataUrl.length - 1) return null;
    final header = dataUrl.substring(0, commaIndex).toLowerCase();
    if (!header.contains(';base64')) return null;
    try {
      final bytes = base64Decode(dataUrl.substring(commaIndex + 1));
      if (bytes.isEmpty) return null;
      final effectiveMimeType = (mimeType ?? '').trim().isEmpty
          ? _dataUrlMimeType(dataUrl)
          : mimeType!.trim();
      return _persistBytesToAppStorage(
        bytes: bytes,
        mimeType: effectiveMimeType,
        prefix: prefix,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _persistXFileToAppStorage(
    XFile file, {
    required String fileName,
    required String mimeType,
    required String prefix,
  }) async {
    if (kIsWeb) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      _localMediaFileCounter += 1;
      final extension = _extensionForMimeType(mimeType);
      final targetName =
          'spark_${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_localMediaFileCounter.$extension';
      final targetPath = '${directory.path}/$targetName';
      await file.saveTo(targetPath);
      return Uri.file(targetPath).toString();
    } catch (_) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return null;
        return _persistBytesToAppStorage(
          bytes: bytes,
          mimeType: mimeType,
          prefix: prefix,
        );
      } catch (_) {
        return null;
      }
    }
  }

  Map<String, dynamic> _buildDraftPayload() {
    final now = DateTime.now();
    final mediaPayload = <String, dynamic>{};
    for (final entry in _mediaState.entries) {
      mediaPayload[entry.key] = {
        'hasIssue': _groupHasIssue(entry.value),
        'note': entry.value.note,
        'rawUrls': entry.value.rawUrls,
        'files': _uploadedToJson(entry.value.files),
        'partInspection': entry.value.partInspection.toJson(),
      };
    }
    final customTagsPayload = <String, List<String>>{};
    for (final entry in _mediaCustomTagsByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      customTagsPayload[entry.key] = tags;
    }
    final customSeriousTagsPayload = <String, List<String>>{};
    for (final entry in _mediaCustomSeriousTagsByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      customSeriousTagsPayload[entry.key] = tags;
    }
    final disabledDefaultsPayload = <String, List<String>>{};
    for (final entry in _mediaDisabledDefaultTagsByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      disabledDefaultsPayload[entry.key] = tags;
    }
    final tagOrderPayload = <String, List<String>>{};
    for (final entry in _mediaTagOrderByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      tagOrderPayload[entry.key] = tags;
    }

    return {
      'id': _draftId,
      'assignmentId': _assignmentId,
      'reportCode': _reportCode,
      'createdAt': _createdAt,
      'updatedAt': _dateLabel(now),
      'currentStep': _stepIndex + 1,
      'totalSteps': _SparkJoyStepRegistry.steps.length,
      'reportName': _reportNameController.text.trim(),
      'car': _carName(),
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'generation': _generationController.text.trim(),
      'restyling': _restylingLabel.trim(),
      'carPhotoUrl': _carPhotoUrl.trim(),
      'carFrames': _carFrames.trim(),
      'vin': _vinController.text.trim(),
      'vinUnreadable': _vinUnreadable,
      'plate': _sanitizePlate(_plateController.text.trim()),
      'adLink': _adLinkController.text.trim(),
      'mileage': _mileageController.text.trim(),
      'mileageMismatch': _mileageMismatch,
      'engineVolume': _engineVolumeController.text.trim(),
      'engineType': _engineTypeController.text.trim(),
      'gearboxType': _gearboxTypeController.text.trim(),
      'driveType': _driveTypeController.text.trim(),
      'color': _colorController.text.trim(),
      'trim': _trimController.text.trim(),
      'ownersCount': _ownersCountController.text.trim(),
      'inspectionCity': _inspectionCityController.text.trim(),
      'inspectionDate': _inspectionDateController.text.trim(),
      'docsOwnerMatch': _docsOwnerMatch,
      'docsVinMatch': _docsVinMatch,
      'docsEngineMatch': _docsEngineMatch,
      'docsMismatchComment': _docsMismatchCommentController.text.trim(),
      'docsCommentAudioFiles': _uploadedToJson(_docsCommentAudioFiles),
      'legalLoading': _legalLoading,
      'legalLoaded': _legalLoaded,
      'legalSkipped': _legalSkipped,
      'legalTimedOut': _legalTimedOut,
      'legalPurchased': _legalPurchased,
      'legalFiles': _uploadedToJson(_legalFiles),
      'legalNote': _legalNoteController.text.trim(),
      'legalCommentAudioFiles': _uploadedToJson(_legalCommentAudioFiles),
      'bodyPaintFrom': _bodyPaintFrom,
      'bodyPaintTo': _bodyPaintTo,
      'structPaintFrom': _structPaintFrom,
      'structPaintTo': _structPaintTo,
      'tdConducted': _tdConductedValue(),
      'tdConductedMode': _tdMode,
      'tdEngineOk': _tdEngineOk,
      'tdGearboxOk': _tdGearboxOk,
      'tdSteeringOk': _tdSteeringOk,
      'tdRideOk': _tdRideOk,
      'tdBrakeOk': _tdBrakeOk,
      'tdEngineIssue': !_tdEngineOk || _tdEngineTags.isNotEmpty,
      'tdGearboxIssue': !_tdGearboxOk || _tdGearboxTags.isNotEmpty,
      'tdSteeringIssue': !_tdSteeringOk || _tdSteeringTags.isNotEmpty,
      'tdRideIssue': !_tdRideOk || _tdRideTags.isNotEmpty,
      'tdBrakeIssue': !_tdBrakeOk || _tdBrakeTags.isNotEmpty,
      'tdEngineTags': _tdEngineTags,
      'tdGearboxTags': _tdGearboxTags,
      'tdSteeringTags': _tdSteeringTags,
      'tdRideTags': _tdRideTags,
      'tdBrakeTags': _tdBrakeTags,
      'tdNote': _tdNoteController.text.trim(),
      'tdCommentAudioFiles': _uploadedToJson(_tdCommentAudioFiles),
      'summaryNote': _summaryController.text.trim(),
      'expertConclusion': _expertController.text.trim(),
      'expertConclusionTouched': _expertController.text.trim().isNotEmpty,
      'expertAudioFiles': _uploadedToJson(_expertAudioFiles),
      'inspector': _inspectorController.text.trim(),
      'companyId': _hasBusinessStatus() ? kSparkCompanyId : '',
      'companyName': _hasBusinessStatus() ? _currentCompanyName() : '',
      'assignedSpecialistId': _assignedSpecialistId.trim(),
      'assignedSpecialistName': _assignedSpecialistName.trim(),
      'specialistId': _assignedSpecialistId.trim(),
      'specialistName': _assignedSpecialistName.trim(),
      'businessType': _accountBusinessType ?? '',
      'verifiedInn': _accountVerifiedInn ?? '',
      'staffInviteLink': _staffInviteLink.trim(),
      'mediaGroupsState': mediaPayload,
      'mediaCustomTags': customTagsPayload,
      'mediaCustomSeriousTags': customSeriousTagsPayload,
      'mediaDisabledDefaultTags': disabledDefaultsPayload,
      'mediaTagOrder': tagOrderPayload,
    };
  }

  void _markDraftDirty({bool scheduleAutosave = true}) {
    if (_hasUnsavedDraftChanges && !_draftSaveFailed) {
      if (scheduleAutosave) {
        _scheduleDraftAutosave();
      }
      return;
    }
    if (mounted) {
      _setStateSafely(() {
        _hasUnsavedDraftChanges = true;
        _draftSaveFailed = false;
      });
    } else {
      _hasUnsavedDraftChanges = true;
      _draftSaveFailed = false;
    }
    if (scheduleAutosave) {
      _scheduleDraftAutosave();
    }
  }

  void _scheduleDraftAutosave() {
    _draftAutosaveDebounce?.cancel();
    _draftAutosaveDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      unawaited(_saveDraft(showToast: false, fromAutosave: true));
    });
  }

  String _draftSaveStatusText() {
    if (_draftSaveInProgress) return 'Сохраняется локально...';
    if (_draftSaveFailed) return 'Ошибка локального сохранения';
    if (_hasUnsavedDraftChanges) return 'Есть несохранённые изменения';
    final lastSavedAt = _lastDraftSavedAt;
    if (lastSavedAt == null) return 'Локальный черновик';
    final hours = lastSavedAt.hour.toString().padLeft(2, '0');
    final minutes = lastSavedAt.minute.toString().padLeft(2, '0');
    return 'Сохранено локально в $hours:$minutes';
  }

  Color _draftSaveStatusColor() {
    if (_draftSaveInProgress) return kSecondaryColor;
    if (_draftSaveFailed) return kRedColor;
    if (_hasUnsavedDraftChanges) return kYellowColor;
    return kGreenColor;
  }

  Future<void> _saveDraft({
    bool showToast = true,
    bool fromAutosave = false,
  }) async {
    if (_draftSaveInProgress) {
      if (fromAutosave) {
        _autosaveRequestedWhileSaving = true;
      }
      return;
    }

    if (mounted) {
      _setStateSafely(() {
        _draftSaveInProgress = true;
        _draftSaveFailed = false;
      });
    } else {
      _draftSaveInProgress = true;
      _draftSaveFailed = false;
    }

    try {
      await SparkJoyStorage.upsertDraft(_buildDraftPayload());
      _draftAutosaveDebounce?.cancel();
      if (mounted) {
        _setStateSafely(() {
          _draftSaveInProgress = false;
          _hasUnsavedDraftChanges = false;
          _draftSaveFailed = false;
          _lastDraftSavedAt = DateTime.now();
        });
      } else {
        _draftSaveInProgress = false;
        _hasUnsavedDraftChanges = false;
        _draftSaveFailed = false;
        _lastDraftSavedAt = DateTime.now();
      }

      if (!mounted || !showToast) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Черновик сохранен')));
    } catch (_) {
      if (mounted) {
        _setStateSafely(() {
          _draftSaveInProgress = false;
          _draftSaveFailed = true;
        });
      } else {
        _draftSaveInProgress = false;
        _draftSaveFailed = true;
      }
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить черновик')),
        );
      }
    } finally {
      if (_autosaveRequestedWhileSaving) {
        _autosaveRequestedWhileSaving = false;
        _scheduleDraftAutosave();
      }
    }
  }

  Map<String, dynamic> _buildCompletedReport() {
    final now = DateTime.now();
    final date = _dateLabel(now);
    final summary = _calculateSummary();

    final mediaGroups = <String, List<Map<String, dynamic>>>{};
    final flatImages = <String>[];

    for (final config in _SparkJoyMediaGroupRegistry.groups) {
      final state = _mediaState[config.key]!;
      final urls = _parseUrls(state.rawUrls);
      if (urls.isEmpty && state.files.isEmpty) continue;
      final items = <Map<String, dynamic>>[];

      for (var i = 0; i < urls.length; i++) {
        final raw = urls[i];
        final isVideo = raw.contains('data:video/');
        final item = {
          'id': '${config.key}_${now.microsecondsSinceEpoch}_$i',
          'url': raw,
          'type': isVideo ? 'video' : 'image',
          'inspection': {
            'noDamage': !_groupHasIssue(state),
            'isDraft': false,
            'tags': _groupHasIssue(state) ? ['issue'] : [],
          },
        };
        items.add(item);
        if (!isVideo) flatImages.add(raw);
      }

      for (var i = 0; i < state.files.length; i++) {
        final file = state.files[i];
        final isVideo = file.isVideo;
        final item = {
          'id':
              '${config.key}_${now.microsecondsSinceEpoch}_${urls.length + i}',
          'url': file.dataUrl,
          'type': isVideo ? 'video' : 'image',
          'inspection': file.inspection.toJson(),
        };
        items.add(item);
        if (!isVideo) flatImages.add(file.dataUrl);
      }
      mediaGroups[config.key] = items;
    }

    if (flatImages.isEmpty) {
      const fallback =
          'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop';
      flatImages.add(fallback);
      mediaGroups['overview'] = [
        {
          'id': 'overview_${now.microsecondsSinceEpoch}',
          'url': fallback,
          'type': 'image',
          'inspection': {'noDamage': true, 'isDraft': false, 'tags': []},
        },
      ];
    }

    final overview = <Map<String, dynamic>>[];
    mediaGroups.forEach((groupName, items) {
      final state = _mediaState[groupName];
      if (state == null || _groupHasIssue(state)) return;
      overview.addAll(items);
    });
    if (overview.isNotEmpty) {
      mediaGroups['overview'] = overview;
    }

    final checklist = [
      for (final line in summary.checklist) {'text': line, 'severity': 'minor'},
    ];

    final reportName = _reportNameController.text.trim();
    final carName = _carName();
    final issueLines = summary.checklist
        .where(
          (line) =>
              !line.contains('Покупка') &&
              !line.contains('Критичных замечаний не выявлено'),
        )
        .take(3)
        .toList();

    return {
      'id': 'spark_report_${now.microsecondsSinceEpoch}',
      'assignmentId': _assignmentId,
      'createdAt': date,
      'updatedAt': date,
      'reportCode': _reportCode,
      'reportName': reportName,
      'car': carName.isEmpty ? 'Автомобиль' : carName,
      'make': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'generation': _generationController.text.trim(),
      'restyling': _restylingLabel.trim(),
      'carPhotoUrl': _carPhotoUrl.trim(),
      'carFrames': _carFrames.trim(),
      'inspector': _inspectorController.text.trim().isEmpty
          ? 'Специалист'
          : _inspectorController.text.trim(),
      'companyId': _hasBusinessStatus() ? kSparkCompanyId : '',
      'companyName': _hasBusinessStatus() ? _currentCompanyName() : '',
      'assignedSpecialistId': _assignedSpecialistId.trim(),
      'assignedSpecialistName': _assignedSpecialistName.trim(),
      'specialistId': _assignedSpecialistId.trim(),
      'specialistName': _assignedSpecialistName.trim(),
      'date': date,
      'verdict': summary.verdict,
      'verdictLabel': summary.verdictLabel,
      'score': '${summary.score}/100',
      'price': '—',
      'issues': issueLines.isEmpty
          ? 'Без критичных замечаний'
          : issueLines.join(' '),
      'summary': _summaryController.text.trim(),
      'vin': _vinController.text.trim(),
      'plate': _sanitizePlate(_plateController.text.trim()),
      'mileage': _mileageController.text.trim(),
      'owners': _ownersCountController.text.trim(),
      'docsMismatchComment': _docsMismatchCommentController.text.trim(),
      'docsCommentAudioFiles': _uploadedToJson(_docsCommentAudioFiles),
      'engine': [
        _engineVolumeController.text.trim(),
        _engineTypeController.text.trim(),
      ].where((e) => e.isNotEmpty).join(' '),
      'transmission': _gearboxTypeController.text.trim(),
      'drive': _driveTypeController.text.trim(),
      'reportsCount': 1,
      'images': flatImages,
      'sections': summary.sections,
      'checklist': checklist,
      'mediaGroups': mediaGroups,
      'legalFiles': _uploadedToJson(_legalFiles),
      'legalCommentAudioFiles': _uploadedToJson(_legalCommentAudioFiles),
      'tdCommentAudioFiles': _uploadedToJson(_tdCommentAudioFiles),
      'expertAudioFiles': _uploadedToJson(_expertAudioFiles),
      'summaryNote': _summaryController.text.trim(),
      'expertConclusion': _expertController.text.trim(),
      'expertConclusionTouched': _expertController.text.trim().isNotEmpty,
      'fullInspection': summary.fullInspection,
      'businessType': _accountBusinessType ?? '',
      'verifiedInn': _accountVerifiedInn ?? '',
      'staffInviteLink': _staffInviteLink.trim(),
    };
  }

  Future<void> _finishReport() async {
    final missingReasons = _summaryMissingReasons();
    if (missingReasons.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(missingReasons.join('\n'))));
      return;
    }

    _ensureSummaryAutofill(force: true);
    final completed = _buildCompletedReport();
    final uploaded = await _uploadReportToBackend(completed);
    if (!uploaded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выгрузить отчёт')),
      );
      return;
    }
    await SparkJoyStorage.purgeDraftAfterUpload(_draftId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Отчёт выгружен')));
    Navigator.of(context).pop(true);
  }

  Future<bool> _uploadReportToBackend(Map<String, dynamic> payload) async {
    // TODO(grigory): replace with real backend API integration.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return payload.isNotEmpty;
  }
}

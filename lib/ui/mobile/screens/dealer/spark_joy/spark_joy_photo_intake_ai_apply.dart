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
    if (_intakeApplyRunning) {
      _intakeApplyRequested = true;
      return;
    }
    final snapshot = SparkJoyIntakeUploadService.instance.snapshotOf(_draftId);
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

      for (final result in docResults) {
        if (!mounted) return;
        await _applyDocScanResult(
          result,
          runChecks: false,
          showFeedback: false,
        );
      }
      if (!mounted || appliedIds.isEmpty) return;
      _markDraftDirty(scheduleAutosave: false);
      await _saveDraft(showToast: false);
      if (_draftSaveFailed) return;
      await SparkJoyIntakeUploadService.instance.acknowledgeApplied(
        _draftId,
        appliedIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ИИ распределил ${sparkIntakeFilesCountLabel(appliedIds.length)}',
            ),
          ),
        );
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
}

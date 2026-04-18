part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaStateHelpers on _SparkJoyCreateReportScreenState {
  Map<String, _MediaGroupState> _initMediaState(Map<String, dynamic> draft) {
    final byKey = <String, _MediaGroupState>{};
    final raw = draft['mediaGroupsState'];

    for (final config in _SparkJoyMediaGroupRegistry.groups) {
      String note = '';
      String rawUrls = '';
      bool hasIssue = false;
      var files = const <UploadedItem>[];
      _MediaPartInspection partInspection = const _MediaPartInspection();

      if (raw is Map && raw[config.key] is Map) {
        final group = Map<String, dynamic>.from(raw[config.key] as Map);
        note = _read(group, 'note');
        rawUrls = _read(group, 'rawUrls');
        hasIssue = _readBool(group, 'hasIssue');
        files = _readUploadedList(group['files']);
        partInspection = _readMediaPartInspection(group['partInspection']);
        if (!hasIssue && files.any(_mediaItemHasIssue)) {
          hasIssue = true;
        }
      }

      if (_mediaPartInspectionIsEmpty(partInspection)) {
        partInspection = _deriveGroupPartInspection(
          files: files,
          fallbackNote: note,
        );
      }

      byKey[config.key] = _MediaGroupState(
        config: config,
        hasIssue: hasIssue,
        note: note,
        rawUrls: rawUrls,
        files: files,
        partInspection: partInspection,
      );
    }

    return byKey;
  }

  Future<void> _compactInlineDraftMediaIfNeeded() async {
    if (kIsWeb) return;

    var changed = false;

    Future<String> compactSource(
      String source, {
      String? mimeType,
      required String prefix,
    }) async {
      final normalized = source.trim();
      if (!_isDataUrl(normalized)) return normalized;
      final persisted = await _persistDataUrlToAppStorage(
        normalized,
        mimeType: mimeType,
        prefix: prefix,
      );
      if (persisted == null || persisted.isEmpty) return normalized;
      if (persisted != normalized) {
        changed = true;
        _dataUrlImageBytesCache.remove(normalized);
      }
      return persisted;
    }

    Future<List<String>> compactAudioRecordings(
      List<String> values, {
      String prefix = 'audio',
    }) async {
      if (values.isEmpty) return values;
      final next = <String>[];
      for (final item in values) {
        final converted = await compactSource(
          item,
          mimeType: 'audio/wav',
          prefix: prefix,
        );
        next.add(converted);
      }
      return next;
    }

    final nextLegalFiles = <UploadedItem>[];
    for (final file in _legalFiles) {
      final nextSource = await compactSource(
        file.dataUrl,
        mimeType: file.mimeType,
        prefix: 'legal',
      );
      final nextAudio = await compactAudioRecordings(
        file.inspection.audioRecordings,
      );
      final inspectionChanged = !listEquals(
        nextAudio,
        file.inspection.audioRecordings,
      );
      final nextInspection = inspectionChanged
          ? file.inspection.copyWith(audioRecordings: nextAudio)
          : file.inspection;
      nextLegalFiles.add(
        file.copyWith(dataUrl: nextSource, inspection: nextInspection),
      );
    }

    final nextExpertAudioFiles = <UploadedItem>[];
    for (final file in _expertAudioFiles) {
      final nextSource = await compactSource(
        file.dataUrl,
        mimeType: file.mimeType,
        prefix: 'expert_audio',
      );
      nextExpertAudioFiles.add(file.copyWith(dataUrl: nextSource));
    }

    final nextDocsCommentAudioFiles = <UploadedItem>[];
    for (final file in _docsCommentAudioFiles) {
      final nextSource = await compactSource(
        file.dataUrl,
        mimeType: file.mimeType,
        prefix: 'docs_comment_audio',
      );
      nextDocsCommentAudioFiles.add(file.copyWith(dataUrl: nextSource));
    }

    final nextLegalCommentAudioFiles = <UploadedItem>[];
    for (final file in _legalCommentAudioFiles) {
      final nextSource = await compactSource(
        file.dataUrl,
        mimeType: file.mimeType,
        prefix: 'legal_comment_audio',
      );
      nextLegalCommentAudioFiles.add(file.copyWith(dataUrl: nextSource));
    }

    final nextTdCommentAudioFiles = <UploadedItem>[];
    for (final file in _tdCommentAudioFiles) {
      final nextSource = await compactSource(
        file.dataUrl,
        mimeType: file.mimeType,
        prefix: 'td_comment_audio',
      );
      nextTdCommentAudioFiles.add(file.copyWith(dataUrl: nextSource));
    }

    final nextMediaState = <String, _MediaGroupState>{};
    for (final entry in _mediaState.entries) {
      final groupKey = entry.key;
      final state = entry.value;
      final sourceRemap = <String, String>{};
      final nextFiles = <UploadedItem>[];

      for (final file in state.files) {
        final nextSource = await compactSource(
          file.dataUrl,
          mimeType: file.mimeType,
          prefix: groupKey,
        );
        if (nextSource != file.dataUrl) {
          sourceRemap[file.dataUrl] = nextSource;
        }
        final nextAudio = await compactAudioRecordings(
          file.inspection.audioRecordings,
        );
        final nextInspection =
            !listEquals(nextAudio, file.inspection.audioRecordings)
            ? file.inspection.copyWith(audioRecordings: nextAudio)
            : file.inspection;
        nextFiles.add(
          file.copyWith(dataUrl: nextSource, inspection: nextInspection),
        );
      }

      final nextRawUrls = <String>[];
      for (final raw in _parseUrls(state.rawUrls)) {
        final remapped = sourceRemap[raw];
        if (remapped != null) {
          nextRawUrls.add(remapped);
          continue;
        }
        final compacted = await compactSource(
          raw,
          mimeType: _guessMimeType(raw),
          prefix: groupKey,
        );
        nextRawUrls.add(compacted);
      }

      final partAudio = await compactAudioRecordings(
        state.partInspection.audioRecordings,
      );
      final nextTagPhotos = <String, List<String>>{};
      for (final tagEntry in state.partInspection.tagPhotos.entries) {
        final urls = <String>[];
        for (final source in tagEntry.value) {
          final remapped = sourceRemap[source] ?? source;
          urls.add(remapped);
        }
        nextTagPhotos[tagEntry.key] = urls;
      }
      final nextPartInspection = state.partInspection.copyWith(
        audioRecordings: partAudio,
        tagPhotos: nextTagPhotos,
      );

      nextMediaState[groupKey] = state.copyWith(
        files: nextFiles,
        rawUrls: nextRawUrls.join('\n'),
        hasIssue: nextFiles.any(_mediaItemHasIssue),
        partInspection: nextPartInspection,
      );
    }

    if (!changed || !mounted) return;

    _setStateSafely(() {
      _legalFiles = nextLegalFiles;
      _expertAudioFiles = nextExpertAudioFiles;
      _docsCommentAudioFiles = nextDocsCommentAudioFiles;
      _legalCommentAudioFiles = nextLegalCommentAudioFiles;
      _tdCommentAudioFiles = nextTdCommentAudioFiles;
      _mediaState = nextMediaState;
    });
    await _saveDraft(showToast: false);
  }
}

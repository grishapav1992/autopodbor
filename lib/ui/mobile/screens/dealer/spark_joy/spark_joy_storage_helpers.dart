part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyStorageHelpers on _SparkJoyCreateReportScreenState {
  // ──────────────────────────────────────────────────────────────────
  //  Read-only completed-report actions
  // ──────────────────────────────────────────────────────────────────

  /// Generates a shareable URL for the completed report currently being
  /// viewed in read-only mode, copies it to the clipboard, and surfaces a
  /// SnackBar confirming the action. The reportId is resolved from the
  /// draft payload passed into the screen; if the local payload lacks a
  /// numeric id we fall back to [StorageApi.resolveSpecialistReportId].
  Future<void> _shareCompletedReport(BuildContext context) async {
    if (_shareInProgress) return;
    final report = widget.draft ?? const <String, dynamic>{};
    _setStateSafely(() => _shareInProgress = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var reportId = _readIntField(report, const [
        'id',
        'reportId',
        'report_id',
      ]);
      reportId ??= await storage_api.StorageApi.resolveSpecialistReportId(
        report: report,
      );
      if (reportId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось определить ID отчёта')),
        );
        return;
      }
      final generated = await storage_api.StorageApi
          .createSpecialistReportShareUrl(reportId: reportId);
      final url = generated.url.trim();
      if (url.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ссылка не была сгенерирована')),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ссылка скопирована: $url'),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось сгенерировать ссылку')),
      );
    } finally {
      if (mounted) {
        _setStateSafely(() => _shareInProgress = false);
      } else {
        _shareInProgress = false;
      }
    }
  }

  int? _readIntField(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final raw = map[key];
      if (raw == null) continue;
      if (raw is int) return raw;
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) return parsed;
      }
      if (raw is num) return raw.toInt();
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────────
  //  Tag ID resolution — GetUserTags / AddUserTag integration
  //
  //  Thin wrappers over [SparkJoyTagService]. The service owns the
  //  name → server-id cache and all RPC calls; these helpers collect
  //  host-state context (media state, test-drive tag lists) and delegate.
  // ──────────────────────────────────────────────────────────────────

  /// Refreshes the tag cache from the server. Forwards already-picked
  /// tag IDs so results come back sorted by relevance (changelog
  /// 2026-04-15 — see SparkJoyTagService.loadTagIdsFromServer).
  Future<void> _loadTagIdsFromServer() async {
    // Seed from persisted catalog first — makes id resolution work offline
    // and before the server fan-out completes.
    await _tagService.hydrateFromCache();
    _seedCustomTagsFromServer();
    final inspectionSelected = _collectSelectedTagIdsByApiSection();
    final genericInspection = <int>{
      for (final ids in inspectionSelected.values) ...ids,
    }.toList(growable: false);
    await _tagService.loadTagIdsFromServer(
      selectedInspectionIdsBySection: inspectionSelected,
      genericInspectionSelectedIds: genericInspection,
      testDriveSelectedIds: _tagService.resolveTagIds(
        _collectTestDriveTagNames(),
        step: 'test_drive',
      ),
    );
    // Re-seed after server fan-out lands — first call covered the
    // offline cache, this one picks up tags added in other devices /
    // sessions since the cache was last persisted.
    _seedCustomTagsFromServer();
  }

  /// Folds the user's server-owned inspection tags (where
  /// `userId != null`) into `_mediaCustomTagsByScope` /
  /// `_mediaCustomSeriousTagsByScope`. Without this, tags created in
  /// previous sessions render in the editor as system-style chips
  /// (no delete affordance). Local-only entries already in the maps
  /// are preserved — server data is unioned in, never overwrites.
  void _seedCustomTagsFromServer() {
    final byGroup = _tagService.customInspectionTagsByGroupKey();
    if (byGroup.isEmpty) return;
    final next = <String, List<String>>{
      for (final e in _mediaCustomTagsByScope.entries) e.key: [...e.value],
    };
    final nextSerious = <String, List<String>>{
      for (final e in _mediaCustomSeriousTagsByScope.entries) e.key: [...e.value],
    };
    var changed = false;
    for (final entry in byGroup.entries) {
      final groupKey = entry.key;
      // Use the plain group key as scope — interior_dashboard /
      // diagnostics sub-typed scopes inherit from the parent scope at
      // render time; the server doesn't split tags by elementType,
      // so we don't either.
      final scope = groupKey;
      final existing = next[scope] ?? const <String>[];
      final existingLower = existing.map((s) => s.toLowerCase()).toSet();
      final mergedSerious = nextSerious[scope] ?? <String>[];
      final mergedSeriousLower = mergedSerious.map((s) => s.toLowerCase()).toSet();
      final list = [...existing];
      for (final tag in entry.value) {
        final isNameNew = existingLower.add(tag.name.toLowerCase());
        if (isNameNew) {
          list.add(tag.name);
          changed = true;
        }
        if (tag.isSerious) {
          final isSeriousNew = mergedSeriousLower.add(tag.name.toLowerCase());
          if (isSeriousNew) {
            mergedSerious.add(tag.name);
            changed = true;
            if (!isNameNew) {
              // Local catalog tracked this label as non-serious (in
              // the names list but not in the serious set); server
              // disagrees. Server is authoritative — log so the silent
              // upgrade is visible during debugging.
              debugPrint(
                '[TagSync] severity override: "${tag.name}" '
                '(group=$groupKey) was tracked locally as non-serious; '
                'server marks it serious — using server value.',
              );
            }
          }
        }
      }
      if (list.isNotEmpty) next[scope] = list;
      if (mergedSerious.isNotEmpty) nextSerious[scope] = mergedSerious;
    }
    if (!changed) return;
    _mediaCustomTagsByScope = next;
    _mediaCustomSeriousTagsByScope = nextSerious;
  }

  /// Collects already-picked inspection tag IDs grouped by API section
  /// (`body`, `interior`, …). Empty map if no tags have been picked yet or
  /// if names cannot be resolved to IDs.
  Map<String, List<int>> _collectSelectedTagIdsByApiSection() {
    final result = <String, List<int>>{};
    for (final entry in _mediaState.entries) {
      final section = SparkJoyTagService.groupKeyToApiSection[entry.key];
      if (section == null) continue;
      final names = <String>{
        for (final item in entry.value.files)
          ...item.inspection.tags
              .map((tag) => tag.trim())
              .where((t) => t.isNotEmpty),
      };
      if (names.isEmpty) continue;
      final ids = _tagService.resolveTagIds(
        names,
        step: 'inspection',
        section: section,
      );
      if (ids.isEmpty) continue;
      result[section] = ids;
    }
    return result;
  }

  /// Aggregates all test-drive tag names already picked by the user.
  List<String> _collectTestDriveTagNames() {
    final names = <String>{
      ..._tdEngineTags,
      ..._tdGearboxTags,
      ..._tdSteeringTags,
    };
    return names
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  /// Sync wrapper used by the inspection editor (media group key → section).
  Future<int?> _syncInspectionCustomTag({
    required String groupKey,
    required String tagName,
    required String severity,
  }) {
    return _tagService.addInspectionTag(
      groupKey: groupKey,
      tagName: tagName,
      severity: severity,
    );
  }

  /// Sync wrapper used by the test-drive step (no section).
  Future<int?> _syncTestDriveCustomTag({
    required String tagName,
    required String severity,
  }) {
    return _tagService.addTestDriveTag(
      tagName: tagName,
      severity: severity,
    );
  }

  /// Fire-and-forget delete for a user-created inspection tag. Called when
  /// the user taps the X affordance in the inspection tag editor. The call
  /// is best-effort: local UI state is updated regardless of server result.
  Future<bool> _removeInspectionCustomTag({
    required String groupKey,
    required String tagName,
  }) {
    return _tagService.removeInspectionTag(
      groupKey: groupKey,
      tagName: tagName,
    );
  }

  /// Re-fetches the inspection tag suggestions for [groupKey] with the
  /// currently selected tags as `selectedTagIds`. The server uses that
  /// to sort unselected tags by co-occurrence — tags often picked
  /// alongside the current selection float to the top. Per spec, this
  /// only changes ordering for `step=inspection`; the test-drive step
  /// always returns alphabetically, so callers there should skip this.
  ///
  /// Returns the new label order — selected labels first (preserving
  /// the user's tap order via [selectedTagNames]) followed by the
  /// server's prioritized list of unselected labels. Returns `null` on
  /// network failure or when the server returns nothing actionable;
  /// callers keep their existing local order in that case.
  Future<List<String>?> _refreshInspectionTagOrder({
    required String groupKey,
    required List<String> selectedTagNames,
  }) async {
    final apiSection = SparkJoyTagService.groupKeyToApiSection[groupKey];
    if (apiSection == null) return null;
    final selectedIds = _tagService.resolveTagIds(
      selectedTagNames,
      step: 'inspection',
      section: apiSection,
    );
    try {
      final tags = await storage_api.StorageApi.getUserTags(
        step: 'inspection',
        section: apiSection,
        selectedTagIds: selectedIds.isEmpty ? null : selectedIds,
      );
      // Build the new order: keep the user's selection at the top in
      // tap order (server omits selected tags from the response), then
      // append the server-sorted unselected tail. De-dupe by lowercase
      // so capitalisation drift between catalogs doesn't double-list.
      final seen = <String>{};
      final out = <String>[];
      for (final name in selectedTagNames) {
        final key = name.toLowerCase();
        if (seen.add(key)) out.add(name);
      }
      for (final tag in tags) {
        final name = tag.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (seen.add(key)) out.add(name);
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  /// Guarantees every tag name referenced by the current report has an ID
  /// cached in [_tagService]. Must be awaited once before building the
  /// final `Storage.PrepareSpecialistReport` payload.
  Future<void> _ensureAllTagIdsResolved() {
    final contexts = _collectTagSyncContexts();
    if (contexts.isEmpty) return Future<void>.value();

    final inspectionSelected = _collectSelectedTagIdsByApiSection();
    final genericInspection = <int>{
      for (final ids in inspectionSelected.values) ...ids,
    }.toList(growable: false);

    return _tagService.ensureAllTagIdsResolved(
      contexts: contexts,
      selectedInspectionIdsBySection: inspectionSelected,
      genericInspectionSelectedIds: genericInspection,
      testDriveSelectedIds: _tagService.resolveTagIds(
        _collectTestDriveTagNames(),
        step: 'test_drive',
      ),
    );
  }

  /// Builds the list of [TagSyncContext]s for every tag currently referenced
  /// by the report. Pure host-state → contexts transformation; the actual
  /// RPC work lives in [SparkJoyTagService.ensureAllTagIdsResolved].
  List<TagSyncContext> _collectTagSyncContexts() {
    // Dedupe key must include step + section — the same label in two
    // sections resolves to different server tags and must be created twice.
    final contexts = <String, TagSyncContext>{};
    String bucketKey(String step, String? section, String name) =>
        '$step|${section ?? ''}|${name.toLowerCase()}';

    void registerInspection({
      required String groupKey,
      required String tagName,
      required String severity,
    }) {
      final trimmed = tagName.trim();
      if (trimmed.isEmpty) return;
      final section = SparkJoyTagService.groupKeyToApiSection[groupKey];
      if (_tagService.idFor(
            step: 'inspection',
            section: section,
            name: trimmed,
          ) !=
          null) {
        return;
      }
      contexts.putIfAbsent(
        bucketKey('inspection', section, trimmed),
        () => TagSyncContext(
          name: trimmed,
          step: 'inspection',
          section: section,
          type: severity == 'serious' ? 'serious' : 'nonserious',
        ),
      );
    }

    void registerTestDrive(List<String> tags, String severityFallback) {
      for (final raw in tags) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        if (_tagService.idFor(step: 'test_drive', name: trimmed) != null) {
          continue;
        }
        contexts.putIfAbsent(
          bucketKey('test_drive', null, trimmed),
          () => TagSyncContext(
            name: trimmed,
            step: 'test_drive',
            section: null,
            type: severityFallback,
          ),
        );
      }
    }

    // Inspection tags from media files (per-section, per-severity).
    for (final entry in _mediaState.entries) {
      final groupKey = entry.key;
      final state = entry.value;
      for (final file in state.files) {
        for (final tag in file.inspection.tags) {
          final severity = _mediaTagSeverity(
            groupKey,
            tag,
            elementType: file.inspection.elementType,
          );
          registerInspection(
            groupKey: groupKey,
            tagName: tag,
            severity: severity,
          );
        }
      }
      for (final tag in state.partInspection.tags) {
        final severity = _mediaTagSeverity(
          groupKey,
          tag,
          elementType: state.partInspection.elementType,
        );
        registerInspection(
          groupKey: groupKey,
          tagName: tag,
          severity: severity,
        );
      }
    }

    // Test-drive tags (default to nonserious; server-side preset tags
    // already carry a stored type — local creation only applies to
    // custom entries).
    registerTestDrive(_tdEngineTags, 'nonserious');
    registerTestDrive(_tdGearboxTags, 'nonserious');
    registerTestDrive(_tdSteeringTags, 'nonserious');
    registerTestDrive(_tdRideTags, 'nonserious');
    registerTestDrive(_tdBrakeTags, 'nonserious');

    return contexts.values.toList(growable: false);
  }

  /// Resolves inspection-step tag names for a specific API section.
  List<int> _resolveInspectionTagIds(List<String> tagNames, String section) =>
      _tagService.resolveTagIds(
        tagNames,
        step: 'inspection',
        section: section,
      );

  /// Resolves test-drive-step tag names (no section).
  List<int> _resolveTestDriveTagIds(List<String> tagNames) =>
      _tagService.resolveTagIds(tagNames, step: 'test_drive');

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

  String _sanitizeLocalFileName(
    String raw, {
    required String fallbackPrefix,
    required String fallbackExtension,
  }) {
    var name = raw.trim();
    if (name.isEmpty) {
      name =
          '${fallbackPrefix}_${DateTime.now().microsecondsSinceEpoch}.$fallbackExtension';
    }
    name = name
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    if (name.isEmpty) {
      name =
          '${fallbackPrefix}_${DateTime.now().microsecondsSinceEpoch}.$fallbackExtension';
    }

    final dotIndex = name.lastIndexOf('.');
    final hasExtension = dotIndex > 0 && dotIndex < name.length - 1;
    if (!hasExtension) {
      name = '$name.$fallbackExtension';
    }
    return name;
  }

  String _nextLocalStorageFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final hasExtension = dotIndex > 0 && dotIndex < fileName.length - 1;
    final baseName = hasExtension ? fileName.substring(0, dotIndex) : fileName;
    final extension = hasExtension ? fileName.substring(dotIndex) : '';
    final normalizedKey = fileName.toLowerCase();
    final usage = _localSavedFileNameUsages[normalizedKey] ?? 0;
    _localSavedFileNameUsages[normalizedKey] = usage + 1;
    if (usage == 0) return fileName;
    return '${baseName}_${usage + 1}$extension';
  }

  Future<String?> _persistBytesToAppStorage({
    required Uint8List bytes,
    required String mimeType,
    required String prefix,
    String? originalFileName,
  }) async {
    if (kIsWeb || bytes.isEmpty) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      final extension = _extensionForMimeType(mimeType);
      final fallbackPrefix = 'spark_$prefix';
      final fileName = _sanitizeLocalFileName(
        originalFileName ?? '',
        fallbackPrefix: fallbackPrefix,
        fallbackExtension: extension,
      );
      final targetName = _nextLocalStorageFileName(fileName);
      final filePath = '${directory.path}/$targetName';
      final xFile = XFile.fromData(bytes, name: targetName, mimeType: mimeType);
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
      final extension = _extensionForMimeType(mimeType);
      final targetName = _sanitizeLocalFileName(
        fileName,
        fallbackPrefix: 'spark_$prefix',
        fallbackExtension: extension,
      );
      final finalTargetName = _nextLocalStorageFileName(targetName);
      final targetPath = '${directory.path}/$finalTargetName';
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
          originalFileName: fileName,
        );
      } catch (_) {
        return null;
      }
    }
  }

  List<UploadedItem> _collectUniqueUploadItems() {
    final bySource = <String, UploadedItem>{};

    void consume(UploadedItem item) {
      final source = item.dataUrl.trim();
      if (source.isEmpty) return;
      if (!_isAttachmentSourceLikelyValid(source)) return;
      bySource.putIfAbsent(source, () => item);
    }

    for (final group in _mediaState.values) {
      for (final item in group.files) {
        consume(item);
      }
    }
    for (final item in _legalFiles) {
      consume(item);
    }
    for (final item in _docsCommentAudioFiles) {
      consume(item);
    }
    for (final item in _legalCommentAudioFiles) {
      consume(item);
    }
    for (final item in _tdCommentAudioFiles) {
      consume(item);
    }
    for (final item in _expertAudioFiles) {
      consume(item);
    }
    return bySource.values.toList(growable: false);
  }

  String _preferredUploadFileNameForItem(UploadedItem item, int index) {
    return item.name.trim();
  }

  Future<Uint8List?> _readUploadBytesFromSource(UploadedItem item) async {
    final source = item.dataUrl.trim();
    if (source.isEmpty) return null;

    if (_isDataUrl(source)) {
      final commaIndex = source.indexOf(',');
      if (commaIndex <= 0 || commaIndex >= source.length - 1) return null;
      final header = source.substring(0, commaIndex).toLowerCase();
      if (!header.contains(';base64')) return null;
      try {
        final bytes = base64Decode(source.substring(commaIndex + 1));
        if (bytes.isEmpty) return null;
        return bytes;
      } catch (_) {
        return null;
      }
    }

    final localPath = _extractLocalMediaPath(source);
    if (localPath == null || localPath.trim().isEmpty) return null;
    try {
      final bytes = await XFile(localPath).readAsBytes();
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  String _uploadStateText(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  int _uploadStateInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _uploadStateBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return false;
  }

  Map<String, dynamic> _backendUploadFilesState() {
    final raw = _backendUploadState['files'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      final mapped = raw.map((key, value) => MapEntry(key.toString(), value));
      _backendUploadState['files'] = mapped;
      return mapped;
    }
    final created = <String, dynamic>{};
    _backendUploadState['files'] = created;
    return created;
  }

  Map<int, String> _readUploadedPartsFromState(Map<String, dynamic> fileState) {
    final result = <int, String>{};
    final raw = fileState['parts'];
    if (raw is! Map) return result;
    for (final entry in raw.entries) {
      final partNumber = int.tryParse(entry.key.toString());
      final etag = entry.value?.toString().trim() ?? '';
      if (partNumber == null || partNumber <= 0 || etag.isEmpty) continue;
      result[partNumber] = etag;
    }
    return result;
  }

  void _writeUploadedPartsToState(
    Map<String, dynamic> fileState,
    Map<int, String> parts,
  ) {
    final encoded = <String, String>{};
    final keys = parts.keys.toList()..sort();
    for (final key in keys) {
      final etag = parts[key]?.trim() ?? '';
      if (etag.isEmpty) continue;
      encoded[key.toString()] = etag;
    }
    fileState['parts'] = encoded;
  }

  Future<void> _persistBackendUploadStateToDraft() async {
    try {
      await SparkJoyStorage.upsertDraft(_buildDraftPayload());
    } catch (_) {}
  }

  void _setBackendUploadProgress({
    required bool inProgress,
    String? statusText,
    int? currentFile,
    int? totalFiles,
    int? currentPart,
    int? totalParts,
  }) {
    void apply() {
      _backendUploadInProgress = inProgress;
      if (statusText != null) {
        _backendUploadStatusText = statusText;
      }
      if (currentFile != null) {
        _backendUploadCurrentFile = currentFile;
      }
      if (totalFiles != null) {
        _backendUploadTotalFiles = totalFiles;
      }
      if (currentPart != null) {
        _backendUploadCurrentPart = currentPart;
      }
      if (totalParts != null) {
        _backendUploadTotalParts = totalParts;
      }
    }

    if (mounted) {
      _setStateSafely(apply);
    } else {
      apply();
    }
  }

  String _backendUploadProgressSourceKey(UploadedItem item, int index) {
    final source = item.dataUrl.trim();
    if (source.isNotEmpty) return source;
    return 'idx:$index:${item.id}';
  }

  String _backendUploadDisplayName(UploadedItem item, int index) {
    final name = item.name.trim();
    if (name.isNotEmpty) return name;
    return 'Файл ${index + 1}';
  }

  void _setBackendUploadFilesProgress(List<BackendUploadFileProgress> files) {
    void apply() {
      _backendUploadFilesProgress = files;
    }

    if (mounted) {
      _setStateSafely(apply);
    } else {
      apply();
    }
  }

  void _initializeBackendUploadFilesProgress({
    required List<UploadedItem> items,
  }) {
    final next = <BackendUploadFileProgress>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      next.add(
        BackendUploadFileProgress(
          sourceKey: _backendUploadProgressSourceKey(item, i),
          fileName: _backendUploadDisplayName(item, i),
          index: i + 1,
          total: items.length,
        ),
      );
    }
    _setBackendUploadFilesProgress(next);
  }

  void _updateBackendUploadFileProgress({
    required UploadedItem item,
    required int index,
    required int totalItems,
    String? fileName,
    double? progress,
    int? uploadedParts,
    int? totalParts,
    BackendUploadFileStatus? status,
    String? errorText,
  }) {
    final sourceKey = _backendUploadProgressSourceKey(item, index);
    final current = _backendUploadFilesProgress;
    final itemIndex = current.indexWhere(
      (entry) => entry.sourceKey == sourceKey,
    );
    if (itemIndex < 0) return;
    final previous = current[itemIndex];
    final resolvedFileName = (fileName ?? previous.fileName).trim();
    final nextItem = previous.copyWith(
      fileName: resolvedFileName.isEmpty ? previous.fileName : resolvedFileName,
      index: index + 1,
      total: totalItems,
      progress: progress == null
          ? previous.progress
          : progress.clamp(0.0, 1.0).toDouble(),
      uploadedParts: uploadedParts ?? previous.uploadedParts,
      totalParts: totalParts ?? previous.totalParts,
      status: status ?? previous.status,
      errorText: errorText ?? previous.errorText,
    );
    final next = List<BackendUploadFileProgress>.from(current);
    next[itemIndex] = nextItem;
    _setBackendUploadFilesProgress(next);
  }

  String _backendUploadStatusLabel() {
    final explicit = _backendUploadStatusText.trim();
    if (explicit.isNotEmpty) return explicit;
    if (_backendUploadTotalFiles <= 0) return 'Подготовка выгрузки...';
    if (_backendUploadCurrentFile <= 0) {
      return 'Подготавливаем файлы к выгрузке...';
    }
    final maxIndex = math.max(0, _backendUploadFilesProgress.length - 1);
    final currentIndex = math.max(
      0,
      math.min(_backendUploadCurrentFile - 1, maxIndex),
    );
    final currentFileName = _backendUploadFilesProgress.isEmpty
        ? ''
        : _backendUploadFilesProgress[currentIndex].fileName.trim();
    final fileLabel = currentFileName.isEmpty
        ? 'Файл $_backendUploadCurrentFile/$_backendUploadTotalFiles'
        : '$_backendUploadCurrentFile/$_backendUploadTotalFiles · $currentFileName';
    if (_backendUploadTotalParts <= 0) return fileLabel;
    final part = _backendUploadCurrentPart.clamp(0, _backendUploadTotalParts);
    return '$fileLabel · часть $part/$_backendUploadTotalParts';
  }

  Duration _multipartPartTimeoutForBytes(int byteCount) {
    const bytesPerWindow = 5 * 1024 * 1024;
    final safeBytes = math.max(1, byteCount);
    final windows = (safeBytes / bytesPerWindow).ceil().clamp(1, 120);
    return Duration(seconds: windows * 60);
  }

  Future<String> _uploadPartWithRetry({
    required String url,
    required List<int> bytes,
    required String contentType,
    required Duration timeout,
    required int fileIndex,
    required int totalFiles,
    required int partNumber,
    required int partCount,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await storage_api.StorageApi.uploadBytesToPresignedUrl(
          url: url,
          bytes: bytes,
          contentType: contentType,
          timeout: timeout,
        );
      } catch (error) {
        lastError = error;
        _backendUploadErrorText =
            'Файл $fileIndex/$totalFiles, часть $partNumber/$partCount: $error';
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
      }
    }
    throw Exception(lastError?.toString() ?? 'Неизвестная ошибка загрузки');
  }

  bool _isMultipartCompleteTransientError(Object error) {
    final text = error.toString().toLowerCase();
    if (!text.contains('objectstorage.completemultipartupload')) return false;
    return text.contains('http 502') ||
        text.contains(' eof') ||
        text.contains(': eof') ||
        text.contains('bad gateway') ||
        text.contains('upstream') ||
        text.contains('timed out') ||
        text.contains('timeout');
  }

  Future<List<storage_api.MultipartUploadedPart>> _refreshMultipartParts({
    required String reportNumber,
    required String filename,
    required String uploadId,
    required List<storage_api.MultipartUploadedPart> currentParts,
  }) async {
    final listed = await storage_api.StorageApi.listMultipartParts(
      reportNumber: reportNumber,
      filename: filename,
      uploadId: uploadId,
    );
    final byPart = <int, String>{};
    for (final part in currentParts) {
      final etag = part.etag.trim();
      if (etag.isEmpty) continue;
      byPart[part.partNumber] = etag;
    }
    for (final part in listed.parts) {
      final etag = part.etag.trim();
      if (etag.isEmpty) continue;
      byPart[part.partNumber] = etag;
    }
    final keys = byPart.keys.toList()..sort();
    return keys
        .map(
          (partNumber) => storage_api.MultipartUploadedPart(
            partNumber: partNumber,
            etag: byPart[partNumber]!,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _completeMultipartUploadWithRetry({
    required String reportNumber,
    required String filename,
    required String uploadId,
    required List<storage_api.MultipartUploadedPart> parts,
    required int fileIndex,
    required int totalFiles,
  }) async {
    Object? lastError;
    var partsForAttempt = List<storage_api.MultipartUploadedPart>.from(parts);
    const maxAttempts = 4;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 1) {
          _setBackendUploadProgress(
            inProgress: true,
            statusText:
                'Файл $fileIndex/$totalFiles: завершаем загрузку (попытка $attempt/$maxAttempts)...',
            currentFile: fileIndex,
            totalFiles: totalFiles,
          );
        }
        await storage_api.StorageApi.completeMultipartUpload(
          reportNumber: reportNumber,
          filename: filename,
          uploadId: uploadId,
          parts: partsForAttempt,
          timeout: const Duration(seconds: 60),
        );
        return;
      } catch (error) {
        lastError = error;
        if (!_isMultipartCompleteTransientError(error)) {
          rethrow;
        }
        if (attempt < maxAttempts) {
          try {
            partsForAttempt = await _refreshMultipartParts(
              reportNumber: reportNumber,
              filename: filename,
              uploadId: uploadId,
              currentParts: partsForAttempt,
            );
          } catch (_) {
            // Keep current parts list and retry completion.
          }
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      }
    }

    throw Exception(
      (lastError?.toString().trim().isNotEmpty ?? false)
          ? lastError.toString().trim()
          : 'Не удалось завершить multipart-загрузку',
    );
  }

  bool _isCompleteReportTransientError(Object error) {
    final text = error.toString().toLowerCase();
    if (!text.contains('storage.completespecialistreport')) return false;
    return text.contains('http 502') ||
        text.contains('bad gateway') ||
        text.contains(' e0f') ||
        text.contains('upstream');
  }

  Future<storage_api.SpecialistReportCompletionResult?>
  _completeSpecialistReportWithRetry({required String reportNumber}) async {
    Object? lastError;
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 1) {
          _setBackendUploadProgress(
            inProgress: true,
            statusText: 'Финализация отчёта: попытка $attempt/$maxAttempts...',
          );
        }
        final completion = await storage_api
            .StorageApi.completeSpecialistReport(reportNumber: reportNumber);
        return completion;
      } catch (error) {
        lastError = error;
        if (!_isCompleteReportTransientError(error)) {
          rethrow;
        }
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      }
    }

    throw Exception(
      (lastError?.toString().trim().isNotEmpty ?? false)
          ? lastError.toString().trim()
          : 'Не удалось завершить отчёт на сервере',
    );
  }

  double _backendUploadProgressValue() {
    if (_backendUploadTotalFiles <= 0) return 0;
    final totalFiles = _backendUploadTotalFiles;
    final fileIndex = (_backendUploadCurrentFile - 1).clamp(0, totalFiles);
    double fileProgress = 0;
    if (_backendUploadTotalParts > 0) {
      fileProgress = (_backendUploadCurrentPart / _backendUploadTotalParts)
          .clamp(0.0, 1.0);
    } else if (_backendUploadCurrentFile > 0) {
      fileProgress = 1;
    }
    final progress = (fileIndex + fileProgress) / totalFiles;
    return progress.clamp(0.0, 1.0);
  }

  DateTime? _parseBackendUploadDateTime(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  int? _parseDigitsInt(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  double? _parseDecimal(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  int? _asIntFromDynamic(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  dynamic _normalizeOptionalValue(dynamic value, {bool keepEmptyMaps = false}) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map) {
      final map = <String, dynamic>{};
      for (final entry in value.entries) {
        final normalized = _normalizeOptionalValue(
          entry.value,
          keepEmptyMaps: true,
        );
        if (normalized == null) continue;
        map[entry.key.toString()] = normalized;
      }
      if (map.isEmpty) {
        return keepEmptyMaps ? <String, dynamic>{} : null;
      }
      return map;
    }
    if (value is Iterable) {
      final list = <dynamic>[];
      for (final item in value) {
        final normalized = _normalizeOptionalValue(item);
        if (normalized == null) continue;
        if (normalized is Map && normalized.isEmpty) continue;
        if (normalized is List && normalized.isEmpty) continue;
        list.add(normalized);
      }
      return list.isEmpty ? null : list;
    }
    return value;
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num || value is bool) return true;
    if (value is Map) {
      for (final nested in value.values) {
        if (_hasMeaningfulValue(nested)) return true;
      }
      return false;
    }
    if (value is Iterable) {
      for (final nested in value) {
        if (_hasMeaningfulValue(nested)) return true;
      }
      return false;
    }
    return true;
  }

  Map<String, dynamic> _normalizeOptionalObject(Map<String, dynamic> source) {
    final normalized = <String, dynamic>{};
    for (final entry in source.entries) {
      final value = _normalizeOptionalValue(entry.value, keepEmptyMaps: true);
      if (value == null) continue;
      normalized[entry.key] = value;
    }
    return _hasMeaningfulValue(normalized) ? normalized : <String, dynamic>{};
  }

  int _resolveModelGenerationRestylingFrameId(Map<String, dynamic> payload) {
    final stateId = _modelGenerationRestylingFrameId;
    if (stateId != null && stateId > 0) return stateId;
    final fromPayload = payload['characteristicsStep'];
    if (fromPayload is Map) {
      final id = _asIntFromDynamic(
        fromPayload['modelGenerationRestylingFrameId'],
      );
      if (id != null && id > 0) return id;
    }
    final fromDraft = widget.draft?['characteristicsStep'];
    if (fromDraft is Map) {
      final id = _asIntFromDynamic(
        fromDraft['modelGenerationRestylingFrameId'],
      );
      if (id != null && id > 0) return id;
    }
    return 1;
  }

  Map<String, dynamic> _buildCharacteristicsStepPayload(
    Map<String, dynamic> payload,
  ) {
    // Per OpenRPC spec (`docs/openrpc_doc_2026-04-26.json`,
    // §characteristicsStep.required) **все 7 полей required и
    // non-nullable**. Раньше тут был `orNull` — для null-tolerant
    // версии спеки. Сейчас спека ужесточилась: пустые значения
    // больше не валидны. Гейтим в `_summaryMissingReasons` и
    // отправляем как есть; если что-то пустое проскочило — server
    // вернёт honest validation error.
    return <String, dynamic>{
      'modelGenerationRestylingFrameId':
          _resolveModelGenerationRestylingFrameId(payload),
      'engineVolume': _parseDecimal(_engineVolumeController.text),
      'engineType': _engineTypeController.text.trim(),
      'transmission': _gearboxTypeController.text.trim(),
      'driveType': _driveTypeController.text.trim(),
      'color': _colorController.text.trim(),
      'equipment': _trimController.text.trim(),
    };
  }

  Map<String, dynamic> _buildDocumentReconciliationStepPayload({
    required int? ownersCount,
  }) {
    return <String, dynamic>{
      'ownersCount': ownersCount,
      'ownerFullNameMatchWithPTSOrSTS': _docsOwnerMatch ?? true,
      'vinOnBodyMatchWithPTSOrSTS': _docsVinMatch ?? true,
      'engineModelMatchWithPTSOrSTS': _docsEngineMatch ?? true,
    };
  }

  String _prepareFileTypeFromMime(String mimeType) {
    final normalized = mimeType.trim().toLowerCase();
    if (normalized.startsWith('image/')) return 'image';
    if (normalized.startsWith('video/')) return 'video';
    return 'document';
  }

  Map<String, dynamic> _buildLegalReviewStepPayload() {
    final legalReview = _normalizeOptionalObject({
      'comment': _legalNoteController.text.trim(),
    });
    final otherLegalReviews = _legalFiles
        .map((file) {
          final filename = file.name.trim();
          if (filename.isEmpty) return null;
          return <String, dynamic>{
            'filename': filename,
            'type': _prepareFileTypeFromMime(file.mimeType),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    return <String, dynamic>{
      'otherLegalReviews': otherLegalReviews,
      'legalReview': legalReview,
    };
  }

  Map<String, dynamic> _buildInspectionStepPayload(
    Map<String, dynamic> payload,
  ) {
    const requiredSections = <String, List<String>>{
      'bodySection': <String>[
        'bodyElementHoodCollection',
        'bodyElementFrontBumperCollection',
        'bodyElementRearBumperCollection',
        'bodyElementRoofCollection',
        'bodyElementTrunkCollection',
        'bodyElementLeftFrontWingCollection',
        'bodyElementRightFrontWingCollection',
        'bodyElementRightRearWingCollection',
        'bodyElementLeftRearWingCollection',
        'bodyElementLeftFrontDoorCollection',
        'bodyElementLeftRearDoorCollection',
        'bodyElementRightRearDoorCollection',
        'bodyElementRightFrontDoorCollection',
        'bodyElementUnderHoodCollection',
        'bodyElementInsideTrunkCollection',
      ],
      'bodyReinforcementElementsSection': <String>[
        'bodyReinforcementElementFrontLeftPillarCollection',
        'bodyReinforcementElementFrontRightPillarCollection',
        'bodyReinforcementElementCenterRightPillarCollection',
        'bodyReinforcementElementCenterLeftPillarCollection',
        'bodyReinforcementElementRearLeftPillarCollection',
        'bodyReinforcementElementRearRightPillarCollection',
        'bodyReinforcementElementLeftSideBeamCollection',
        'bodyReinforcementElementRightSideBeamCollection',
        'bodyReinforcementElementLeftSillCollection',
        'bodyReinforcementElementRightSillCollection',
        'bodyReinforcementElementLeftFrontMudguardCollection',
        'bodyReinforcementElementRightFrontMudguardCollection',
        'bodyReinforcementElementLeftRearMudguardCollection',
        'bodyReinforcementElementRightRearMudguardCollection',
        'bodyReinforcementElementGeneralConditionCollection',
      ],
      'glassSection': <String>[
        'glassElementFrontCollection',
        'glassElementFrontLeftCollection',
        'glassElementFrontRightCollection',
        'glassElementRearRightCollection',
        'glassElementRearLeftCollection',
        'glassElementSideLeftCollection',
        'glassElementSideRightCollection',
        'glassElementGeneralConditionCollection',
      ],
      'interiorSection': <String>[
        'interiorElementFrontSeatsCollection',
        'interiorElementRearSeatsCollection',
        'interiorElementCeilingCollection',
        'interiorElementTrunkCompartmentCollection',
        'interiorElementSteeringWheelCollection',
        'interiorElementDashboardCollection',
        'interiorElementInstrumentClusterCollection',
        'interiorElementCentralMonitorCollection',
        'interiorElementClimateControlUnitCollection',
        'interiorElementCenterConsoleCollection',
        'interiorElementGearSelectorAreaCollection',
        'interiorElementButtonsLeftOfSteeringWheelCollection',
        'interiorElementGeneralConditionCollection',
      ],
      'underHoodSpaceSection': <String>[
        'underHoodElementEngineCollection',
        'underHoodElementAttachmentsCollection',
        'underHoodElementCoolingSystemCollection',
        'underHoodElementIntakeOrTurbineCollection',
        'underHoodElementReleaseOrEcologyCollection',
        'underHoodElementElectricsCollection',
        'underHoodElementBrakingSystemCollection',
        'underHoodElementSteeringControlCollection',
        'underHoodElementGeneralConditionCollection',
      ],
      'wheelsAndBrakesSection': <String>[
        'wheelsAndBrakesElementFrontLeftWheelCollection',
        'wheelsAndBrakesElementFrontRightWheelCollection',
        'wheelsAndBrakesElementRearLeftWheelCollection',
        'wheelsAndBrakesElementRearRightWheelCollection',
        'wheelsAndBrakesElementSpareWheelCollection',
        'wheelsAndBrakesElementFrontLeftBrakeCollection',
        'wheelsAndBrakesElementFrontRightBrakeCollection',
        'wheelsAndBrakesElementRearLeftBrakeCollection',
        'wheelsAndBrakesElementRearRightBrakeCollection',
        'wheelsAndBrakesElementGeneralConditionCollection',
      ],
      'lightningSection': <String>[
        'lightningElementFrontLightsCollection',
        'lightningElementRearLightsCollection',
        'lightningElementDaytimeRunningLightsCollection',
        'lightningElementFogLightsCollection',
        'lightningElementTurnSignalsCollection',
        'lightningElementBrakeLightsCollection',
        'lightningElementNumberPlateLightsCollection',
        'lightningElementGeneralConditionCollection',
      ],
      'computerDiagnosticsSection': <String>[
        'computerDiagnosticsElementEngineCollection',
        'computerDiagnosticsElementTransmissionCollection',
        'computerDiagnosticsElementAbsEspBrakeCollection',
        'computerDiagnosticsElementSrsAirbagCollection',
        'computerDiagnosticsElementElectricalCollection',
        'computerDiagnosticsElementEcologyExhaustCollection',
        'computerDiagnosticsElementBodyElectronicsCollection',
        'computerDiagnosticsElementSteeringSuspensionCollection',
        'computerDiagnosticsElementFourWheelDriveCollection',
        'computerDiagnosticsElementClimateCollection',
        'computerDiagnosticsElementImmobilizerCollection',
        'computerDiagnosticsElementGeneralConditionCollection',
      ],
    };
    const sectionByGroup = <String, String>{
      _SparkJoyMediaGroupRegistry.keyBody: 'bodySection',
      _SparkJoyMediaGroupRegistry.keyStructural:
          'bodyReinforcementElementsSection',
      _SparkJoyMediaGroupRegistry.keyGlass: 'glassSection',
      _SparkJoyMediaGroupRegistry.keyLighting: 'lightningSection',
      _SparkJoyMediaGroupRegistry.keyUnderhood: 'underHoodSpaceSection',
      _SparkJoyMediaGroupRegistry.keyInterior: 'interiorSection',
      _SparkJoyMediaGroupRegistry.keyWheels: 'wheelsAndBrakesSection',
      _SparkJoyMediaGroupRegistry.keyDiagnostics: 'computerDiagnosticsSection',
    };
    const defaultCollectionByGroup = <String, String>{
      _SparkJoyMediaGroupRegistry.keyBody: 'bodyElementHoodCollection',
      _SparkJoyMediaGroupRegistry.keyStructural:
          'bodyReinforcementElementGeneralConditionCollection',
      _SparkJoyMediaGroupRegistry.keyGlass:
          'glassElementGeneralConditionCollection',
      _SparkJoyMediaGroupRegistry.keyLighting:
          'lightningElementGeneralConditionCollection',
      _SparkJoyMediaGroupRegistry.keyUnderhood:
          'underHoodElementGeneralConditionCollection',
      _SparkJoyMediaGroupRegistry.keyInterior:
          'interiorElementGeneralConditionCollection',
      _SparkJoyMediaGroupRegistry.keyWheels:
          'wheelsAndBrakesElementGeneralConditionCollection',
      _SparkJoyMediaGroupRegistry.keyDiagnostics:
          'computerDiagnosticsElementGeneralConditionCollection',
    };
    const collectionByElement = <String, String>{
      'hood': 'bodyElementHoodCollection',
      'front_bumper': 'bodyElementFrontBumperCollection',
      'rear_bumper': 'bodyElementRearBumperCollection',
      'roof': 'bodyElementRoofCollection',
      'trunk': 'bodyElementTrunkCollection',
      'left_front_fender': 'bodyElementLeftFrontWingCollection',
      'right_front_fender': 'bodyElementRightFrontWingCollection',
      'right_rear_fender': 'bodyElementRightRearWingCollection',
      'left_rear_fender': 'bodyElementLeftRearWingCollection',
      'left_front_door': 'bodyElementLeftFrontDoorCollection',
      'left_rear_door': 'bodyElementLeftRearDoorCollection',
      'right_rear_door': 'bodyElementRightRearDoorCollection',
      'right_front_door': 'bodyElementRightFrontDoorCollection',
      'uh_body_elements': 'bodyElementUnderHoodCollection',
      'inner_trunk_lid': 'bodyElementInsideTrunkCollection',
      'body_general': 'bodyElementHoodCollection',
      'a_pillar_left': 'bodyReinforcementElementFrontLeftPillarCollection',
      'a_pillar_right': 'bodyReinforcementElementFrontRightPillarCollection',
      'b_pillar_right': 'bodyReinforcementElementCenterRightPillarCollection',
      'b_pillar_left': 'bodyReinforcementElementCenterLeftPillarCollection',
      'c_pillar_left': 'bodyReinforcementElementRearLeftPillarCollection',
      'c_pillar_right': 'bodyReinforcementElementRearRightPillarCollection',
      'rail_left': 'bodyReinforcementElementLeftSideBeamCollection',
      'rail_right': 'bodyReinforcementElementRightSideBeamCollection',
      'sill_left': 'bodyReinforcementElementLeftSillCollection',
      'sill_right': 'bodyReinforcementElementRightSillCollection',
      'fender_liner_left_front':
          'bodyReinforcementElementLeftFrontMudguardCollection',
      'fender_liner_right_front':
          'bodyReinforcementElementRightFrontMudguardCollection',
      'fender_liner_left_rear':
          'bodyReinforcementElementLeftRearMudguardCollection',
      'fender_liner_right_rear':
          'bodyReinforcementElementRightRearMudguardCollection',
      'structural_general':
          'bodyReinforcementElementGeneralConditionCollection',
      'windshield': 'glassElementFrontCollection',
      'glass_front_left': 'glassElementFrontLeftCollection',
      'glass_front_right': 'glassElementFrontRightCollection',
      'glass_rear_right': 'glassElementRearRightCollection',
      'glass_rear_left': 'glassElementRearLeftCollection',
      'mirror_left': 'glassElementSideLeftCollection',
      'mirror_right': 'glassElementSideRightCollection',
      'rear_glass': 'glassElementGeneralConditionCollection',
      'glass_general': 'glassElementGeneralConditionCollection',
      'front_seats': 'interiorElementFrontSeatsCollection',
      'rear_seats': 'interiorElementRearSeatsCollection',
      'headliner': 'interiorElementCeilingCollection',
      'trunk_interior': 'interiorElementTrunkCompartmentCollection',
      'steering_wheel': 'interiorElementSteeringWheelCollection',
      'dashboard_top': 'interiorElementDashboardCollection',
      'instrument_cluster': 'interiorElementInstrumentClusterCollection',
      'center_display': 'interiorElementCentralMonitorCollection',
      'climate_panel': 'interiorElementClimateControlUnitCollection',
      'center_console': 'interiorElementCenterConsoleCollection',
      'gear_selector_area': 'interiorElementGearSelectorAreaCollection',
      'dashboard_buttons_left':
          'interiorElementButtonsLeftOfSteeringWheelCollection',
      'door_cards': 'interiorElementGeneralConditionCollection',
      'interior_general': 'interiorElementGeneralConditionCollection',
      'uh_engine': 'underHoodElementEngineCollection',
      'uh_accessories': 'underHoodElementAttachmentsCollection',
      'uh_cooling': 'underHoodElementCoolingSystemCollection',
      'uh_intake_turbo': 'underHoodElementIntakeOrTurbineCollection',
      'uh_exhaust_ecology': 'underHoodElementReleaseOrEcologyCollection',
      'uh_electrical': 'underHoodElementElectricsCollection',
      'uh_brakes': 'underHoodElementBrakingSystemCollection',
      'uh_steering': 'underHoodElementSteeringControlCollection',
      'uh_fuel': 'underHoodElementGeneralConditionCollection',
      'uh_fluids': 'underHoodElementGeneralConditionCollection',
      'uh_general': 'underHoodElementGeneralConditionCollection',
      'front_left_wheel': 'wheelsAndBrakesElementFrontLeftWheelCollection',
      'front_right_wheel': 'wheelsAndBrakesElementFrontRightWheelCollection',
      'rear_left_wheel': 'wheelsAndBrakesElementRearLeftWheelCollection',
      'rear_right_wheel': 'wheelsAndBrakesElementRearRightWheelCollection',
      'spare_wheel': 'wheelsAndBrakesElementSpareWheelCollection',
      'front_left_brake': 'wheelsAndBrakesElementFrontLeftBrakeCollection',
      'front_right_brake': 'wheelsAndBrakesElementFrontRightBrakeCollection',
      'rear_left_brake': 'wheelsAndBrakesElementRearLeftBrakeCollection',
      'rear_right_brake': 'wheelsAndBrakesElementRearRightBrakeCollection',
      'wheels_general': 'wheelsAndBrakesElementGeneralConditionCollection',
      'headlights_front': 'lightningElementFrontLightsCollection',
      'taillights_rear': 'lightningElementRearLightsCollection',
      'drl': 'lightningElementDaytimeRunningLightsCollection',
      'fog_lights': 'lightningElementFogLightsCollection',
      'turn_signals': 'lightningElementTurnSignalsCollection',
      'brake_lights': 'lightningElementBrakeLightsCollection',
      'plate_light': 'lightningElementNumberPlateLightsCollection',
      'lighting_general': 'lightningElementGeneralConditionCollection',
      'diag_engine': 'computerDiagnosticsElementEngineCollection',
      'diag_transmission': 'computerDiagnosticsElementTransmissionCollection',
      'diag_abs_esp': 'computerDiagnosticsElementAbsEspBrakeCollection',
      'diag_srs_airbag': 'computerDiagnosticsElementSrsAirbagCollection',
      'diag_electric': 'computerDiagnosticsElementElectricalCollection',
      'diag_ecology': 'computerDiagnosticsElementEcologyExhaustCollection',
      'diag_body_comfort':
          'computerDiagnosticsElementBodyElectronicsCollection',
      'diag_steering_suspension':
          'computerDiagnosticsElementSteeringSuspensionCollection',
      'diag_awd': 'computerDiagnosticsElementFourWheelDriveCollection',
      'diag_climate': 'computerDiagnosticsElementClimateCollection',
      'diag_immobilizer': 'computerDiagnosticsElementImmobilizerCollection',
      'diag_general': 'computerDiagnosticsElementGeneralConditionCollection',
    };

    final result = <String, dynamic>{};
    for (final section in requiredSections.keys) {
      final template = <String, dynamic>{
        for (final collection in requiredSections[section]!)
          collection: <dynamic>[],
      };
      if (section == 'bodySection' ||
          section == 'bodyReinforcementElementsSection') {
        final from = section == 'bodySection'
            ? _bodyPaintFrom.round()
            : _structPaintFrom.round();
        final to = section == 'bodySection'
            ? _bodyPaintTo.round()
            : _structPaintTo.round();
        template['paintworkThicknessFrom'] = from;
        template['paintworkThicknessTo'] = to;
      }
      result[section] = template;
    }

    for (final group in _SparkJoyMediaGroupRegistry.groups) {
      final state = _mediaState[group.key];
      if (state == null || state.files.isEmpty) continue;

      final sectionName = sectionByGroup[group.key];
      if (sectionName == null) continue;
      final section = result[sectionName];
      if (section is! Map<String, dynamic>) continue;

      final defaultCollection = defaultCollectionByGroup[group.key] ?? '';
      final includePaint =
          sectionName == 'bodySection' ||
          sectionName == 'bodyReinforcementElementsSection';

      for (var index = 0; index < state.files.length; index++) {
        final item = state.files[index];
        final filename = _preferredUploadFileNameForItem(item, index).trim();
        if (filename.isEmpty) continue;

        final normalizedElement =
            (item.inspection.elementType ??
                    state.partInspection.elementType ??
                    '')
                .trim()
                .toLowerCase();
        var collection =
            collectionByElement[normalizedElement] ?? defaultCollection;
        if (collection.isEmpty || section[collection] is! List) {
          final availableCollections = requiredSections[sectionName]!;
          collection = availableCollections.first;
        }

        final tags = item.inspection.tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false);
        final seriousTagNames = <String>[];
        final nonSeriousTagNames = <String>[];
        for (final tag in tags) {
          final severity = _mediaTagSeverity(
            group.key,
            tag,
            elementType: item.inspection.elementType,
          );
          if (severity == 'serious') {
            seriousTagNames.add(tag);
          } else {
            nonSeriousTagNames.add(tag);
          }
        }
        // Convert tag names to server-side integer IDs (API v2025-04-15).
        // Resolution is section-scoped: same label in different sections
        // has different server IDs — see SparkJoyTagService._composeKey.
        final apiSection =
            SparkJoyTagService.groupKeyToApiSection[group.key] ?? '';
        final seriousTagIds =
            _resolveInspectionTagIds(seriousTagNames, apiSection);
        final nonSeriousTagIds =
            _resolveInspectionTagIds(nonSeriousTagNames, apiSection);
        final note = item.inspection.note.trim();
        final paintFrom =
            (item.inspection.paintFrom ?? state.partInspection.paintFrom)
                ?.round();
        final paintTo =
            (item.inspection.paintTo ?? state.partInspection.paintTo)?.round();
        // Server rule: if noDamage=false, seriousDamageTags/noSeriousDamageTags
        // must be non-empty. If the user added a photo but didn't pick any tag,
        // we treat it as "no damage" so the backend doesn't reject the report.
        final noDamage = tags.isEmpty;
        final payloadItem = <String, dynamic>{
          // Spec (docs/api/PrepareSpecialistReport.md, §FileObject) declares
          // just {filename, type} on the request side; `key` and `stepType`
          // live only on the response's uploadFiles[] and were echoed back
          // here historically. Dropping them to avoid tripping any future
          // strict schema validator.
          'file': <String, dynamic>{
            'filename': filename,
            'type': _prepareFileTypeFromMime(item.mimeType),
          },
          if (includePaint && paintFrom != null)
            'paintworkThicknessFrom': paintFrom,
          if (includePaint && paintTo != null) 'paintworkThicknessTo': paintTo,
          'noDamage': noDamage,
          'seriousDamageTags': seriousTagIds,
          'noSeriousDamageTags': nonSeriousTagIds,
          'note': note.isEmpty ? null : note,
          'audioNotes': const <String>[],
        };
        (section[collection] as List<dynamic>).add(payloadItem);
      }
    }

    return result;
  }

  Map<String, dynamic> _buildTestDriveStepPayload() {
    final conducted = _tdConductedValue() ?? false;
    // Convert tag names → integer IDs (API v2025-04-15).
    return <String, dynamic>{
      'testDriveIsIncluded': conducted,
      'testDriveEngineTags': _resolveTestDriveTagIds(_tdEngineTags),
      'testDriveEngineIsWorkingProperly': _tdEngineOk,
      'testDriveTransmissionTags': _resolveTestDriveTagIds(_tdGearboxTags),
      'testDriveTransmissionIsWorkingProperly': _tdGearboxOk,
      'testDriveSteeringWheelTags': _resolveTestDriveTagIds(_tdSteeringTags),
      'testDriveSteeringWheelIsWorkingProperly': _tdSteeringOk,
      'testDriveSuspensionInDriveTags': _resolveTestDriveTagIds(_tdRideTags),
      'testDriveSuspensionInDriveIsWorkingProperly': _tdRideOk,
      'testDriveBrakesInDriveTags': _resolveTestDriveTagIds(_tdBrakeTags),
      'testDriveBrakesInDriveIsWorkingProperly': _tdBrakeOk,
      'testDriveNote': _tdNoteController.text.trim(),
    };
  }

  Map<String, dynamic> _buildResultStepPayload() {
    // Без silent-fallback. Если до сюда дошли с пустыми полями —
    // это баг в `_summaryMissingReasons`, не лечим тут заглушками.
    return <String, dynamic>{
      'summaryInspectionNote': _summaryController.text.trim(),
      'resultSpecialistNote': _expertController.text.trim(),
    };
  }

  String _isoDateForBackend(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    final direct = DateTime.tryParse(text);
    if (direct != null) {
      final y = direct.year.toString().padLeft(4, '0');
      final m = direct.month.toString().padLeft(2, '0');
      final d = direct.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    final ru = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(text);
    if (ru != null) {
      final day = int.tryParse(ru.group(1)!);
      final month = int.tryParse(ru.group(2)!);
      final year = int.tryParse(ru.group(3)!);
      if (day != null && month != null && year != null) {
        final y = year.toString().padLeft(4, '0');
        final m = month.toString().padLeft(2, '0');
        final d = day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }
    }
    return text;
  }

  Map<String, dynamic> _buildPrepareSpecialistReportPayload(
    Map<String, dynamic> payload,
  ) {
    final report = <String, dynamic>{};
    final mileageRaw = _mileageController.text.trim();
    final mileageInt = _parseDigitsInt(mileageRaw);
    final ownersInt = _parseDigitsInt(_ownersCountController.text.trim());
    final today = _isoDateForBackend(_dateLabel(DateTime.now()));
    final vin = _vinController.text.trim().toUpperCase();

    // Без silent-fallback'ов: hardcoded VIN ('JTDKN3DU5A0123456'),
    // 'Не указан' для города, 'Отчёт' для названия — всё это
    // маскировало реальные пустые поля от бэка. Сейчас валидация в
    // `_summaryMissingReasons` блокирует save до того, как мы тут
    // окажемся с пустыми required-полями. Если случайно проскочило —
    // server вернёт `should not be blank`, что лучше тихих заглушек.
    report['reportName'] = _reportNameController.text.trim();
    report['carStep'] = <String, dynamic>{
      'vin': vin,
      'unreadableVin': _vinUnreadable,
      'gosNumber': _sanitizePlate(_plateController.text.trim()).isEmpty
          ? null
          : _sanitizePlate(_plateController.text.trim()),
      'uriListing': _adLinkController.text.trim().isEmpty
          ? null
          : _adLinkController.text.trim(),
      'mileage': mileageInt ?? 0,
      'visuallyMileageNotMatchCondition': _mileageMismatch == true,
      'cityInspection': _inspectionCityController.text.trim(),
      'dateInspection': today,
    };
    report['characteristicsStep'] = _buildCharacteristicsStepPayload(payload);
    report['documentReconciliationStep'] =
        _buildDocumentReconciliationStepPayload(ownersCount: ownersInt);
    report['legalReviewStep'] = _buildLegalReviewStepPayload();
    report['inspectionStep'] = _buildInspectionStepPayload(payload);
    report['testDriveStep'] = _buildTestDriveStepPayload();
    report['resultStep'] = _buildResultStepPayload();
    return report;
  }

  Future<void> _cleanupStaleMultipartUploads({
    required String reportNumber,
  }) async {
    if (reportNumber.trim().isEmpty) return;
    final filesState = _backendUploadFilesState();
    if (filesState.isEmpty) return;

    final now = DateTime.now();
    const staleTtl = Duration(hours: 12);
    var changed = false;

    for (final entry in filesState.entries.toList()) {
      final rawState = entry.value;
      if (rawState is! Map) continue;
      final fileState = Map<String, dynamic>.from(rawState);
      if (_uploadStateBool(fileState, 'completed')) continue;

      final uploadId = _uploadStateText(fileState, 'uploadId');
      final filename = _uploadStateText(fileState, 'filename');
      if (uploadId.isEmpty || filename.isEmpty) continue;

      final updatedAt = _parseBackendUploadDateTime(fileState['updatedAt']);
      if (updatedAt == null) continue;
      if (now.difference(updatedAt) < staleTtl) continue;

      try {
        await storage_api.StorageApi.abortMultipartUpload(
          reportNumber: reportNumber,
          filename: filename,
          uploadId: uploadId,
        );
      } catch (_) {}

      fileState.remove('uploadId');
      fileState.remove('parts');
      fileState.remove('error');
      fileState['updatedAt'] = now.toIso8601String();
      filesState[entry.key] = fileState;
      changed = true;
    }

    if (!changed) return;
    _backendUploadState['updatedAt'] = now.toIso8601String();
    await _persistBackendUploadStateToDraft();
  }

  Future<bool> _uploadItemWithMultipart({
    required String reportNumber,
    required UploadedItem item,
    required int index,
    required int totalItems,
  }) async {
    Future<bool> runUpload() async {
      final bytes = await _readUploadBytesFromSource(item);
      if (bytes == null || bytes.isEmpty) {
        _backendUploadErrorText =
            'Не удалось прочитать файл ${index + 1}/$totalItems: ${item.name}';
        _updateBackendUploadFileProgress(
          item: item,
          index: index,
          totalItems: totalItems,
          fileName: item.name,
          status: BackendUploadFileStatus.failed,
          progress: 0,
          errorText: _backendUploadErrorText,
        );
        return false;
      }

      final sourceKey = item.dataUrl.trim();
      if (sourceKey.isEmpty) {
        _backendUploadErrorText =
            'Пустой источник файла ${index + 1}/$totalItems: ${item.name}';
        _updateBackendUploadFileProgress(
          item: item,
          index: index,
          totalItems: totalItems,
          fileName: item.name,
          status: BackendUploadFileStatus.failed,
          progress: 0,
          errorText: _backendUploadErrorText,
        );
        return false;
      }

      final filesState = _backendUploadFilesState();
      final rawFileState = filesState[sourceKey];
      final fileState = rawFileState is Map
          ? Map<String, dynamic>.from(rawFileState)
          : <String, dynamic>{};

      if (_uploadStateBool(fileState, 'completed')) {
        _updateBackendUploadFileProgress(
          item: item,
          index: index,
          totalItems: totalItems,
          fileName: _uploadStateText(fileState, 'filename'),
          status: BackendUploadFileStatus.uploaded,
          progress: 1,
          errorText: '',
        );
        return true;
      }

      var filename = _uploadStateText(fileState, 'filename');
      final originalFilename = _preferredUploadFileNameForItem(item, index);
      if (originalFilename.isNotEmpty && filename != originalFilename) {
        fileState['filename'] = originalFilename;
        fileState.remove('uploadId');
        fileState.remove('parts');
        fileState.remove('error');
        fileState.remove('completed');
        fileState.remove('completedAt');
        filename = originalFilename;
      }
      if (filename.isEmpty) {
        filename = originalFilename;
      }
      if (filename.isEmpty) {
        _backendUploadErrorText =
            'Пустое имя файла ${index + 1}/$totalItems (${item.name}).';
        _updateBackendUploadFileProgress(
          item: item,
          index: index,
          totalItems: totalItems,
          fileName: item.name,
          status: BackendUploadFileStatus.failed,
          progress: 0,
          errorText: _backendUploadErrorText,
        );
        return false;
      }

      const partSize = 5 * 1024 * 1024;
      final partCount = (bytes.length / partSize).ceil().clamp(1, 10000);
      var uploadId = _uploadStateText(fileState, 'uploadId');
      final savedPartCount = _uploadStateInt(fileState, 'partCount');
      final etagsByPart = _readUploadedPartsFromState(fileState);
      _setBackendUploadProgress(
        inProgress: true,
        statusText: 'Выгрузка файла ${index + 1}/$totalItems',
        currentFile: index + 1,
        totalFiles: totalItems,
        currentPart: etagsByPart.length,
        totalParts: partCount,
      );
      _updateBackendUploadFileProgress(
        item: item,
        index: index,
        totalItems: totalItems,
        fileName: filename,
        status: BackendUploadFileStatus.uploading,
        progress: partCount <= 0 ? 0 : etagsByPart.length / partCount,
        uploadedParts: etagsByPart.length,
        totalParts: partCount,
        errorText: '',
      );

      storage_api.MultipartUploadSession? session;
      try {
        if (uploadId.isEmpty || savedPartCount != partCount) {
          session = await storage_api.StorageApi.initiateMultipartUpload(
            reportNumber: reportNumber,
            filename: filename,
          );
          uploadId = session.uploadId;
          etagsByPart.clear();
        }
        fileState['filename'] = filename;
        fileState['mimeType'] = item.mimeType;
        fileState['source'] = sourceKey;
        fileState['size'] = bytes.length;
        fileState['partCount'] = partCount;
        fileState['uploadId'] = uploadId;
        fileState['completed'] = false;
        fileState.remove('error');
        fileState['updatedAt'] = DateTime.now().toIso8601String();
        _writeUploadedPartsToState(fileState, etagsByPart);
        filesState[sourceKey] = fileState;
        await _persistBackendUploadStateToDraft();

        final urlsResult = await storage_api.StorageApi.getPartUploadUrls(
          reportNumber: reportNumber,
          filename: filename,
          uploadId: uploadId,
          partCount: partCount,
        );

        if (urlsResult.urls.length < partCount) {
          throw Exception('Not enough part URLs');
        }

        for (var partNumber = 1; partNumber <= partCount; partNumber++) {
          _setBackendUploadProgress(
            inProgress: true,
            statusText: null,
            currentFile: index + 1,
            totalFiles: totalItems,
            currentPart: partNumber,
            totalParts: partCount,
          );
          final existingEtag = etagsByPart[partNumber];
          if (existingEtag != null && existingEtag.trim().isNotEmpty) {
            _updateBackendUploadFileProgress(
              item: item,
              index: index,
              totalItems: totalItems,
              fileName: filename,
              status: BackendUploadFileStatus.uploading,
              progress: partCount <= 0 ? 0 : partNumber / partCount,
              uploadedParts: partNumber,
              totalParts: partCount,
            );
            continue;
          }
          final metaIndex = urlsResult.urls.indexWhere(
            (part) => part.partNumber == partNumber,
          );
          if (metaIndex < 0) {
            throw Exception('Part URL not found for part=$partNumber');
          }
          final start = (partNumber - 1) * partSize;
          final end = math.min(start + partSize, bytes.length);
          final chunk = bytes.sublist(start, end);
          final partTimeout = _multipartPartTimeoutForBytes(chunk.length);
          final etag = await _uploadPartWithRetry(
            url: urlsResult.urls[metaIndex].url,
            bytes: chunk,
            contentType: item.mimeType,
            timeout: partTimeout,
            fileIndex: index + 1,
            totalFiles: totalItems,
            partNumber: partNumber,
            partCount: partCount,
          );
          if (etag.trim().isNotEmpty) {
            etagsByPart[partNumber] = etag.trim();
            fileState['updatedAt'] = DateTime.now().toIso8601String();
            _writeUploadedPartsToState(fileState, etagsByPart);
            filesState[sourceKey] = fileState;
            await _persistBackendUploadStateToDraft();
            _setBackendUploadProgress(
              inProgress: true,
              statusText: null,
              currentFile: index + 1,
              totalFiles: totalItems,
              currentPart: partNumber,
              totalParts: partCount,
            );
            _updateBackendUploadFileProgress(
              item: item,
              index: index,
              totalItems: totalItems,
              fileName: filename,
              status: BackendUploadFileStatus.uploading,
              progress: partCount <= 0 ? 0 : partNumber / partCount,
              uploadedParts: partNumber,
              totalParts: partCount,
            );
          }
        }

        if (etagsByPart.length < partCount) {
          final listed = await storage_api.StorageApi.listMultipartParts(
            reportNumber: reportNumber,
            filename: filename,
            uploadId: uploadId,
          );
          for (final part in listed.parts) {
            if (part.etag.trim().isEmpty) continue;
            etagsByPart.putIfAbsent(part.partNumber, () => part.etag.trim());
          }
          fileState['updatedAt'] = DateTime.now().toIso8601String();
          _writeUploadedPartsToState(fileState, etagsByPart);
          filesState[sourceKey] = fileState;
          await _persistBackendUploadStateToDraft();
        }

        if (etagsByPart.length < partCount) {
          throw Exception('Missing ETag(s) for uploaded parts');
        }

        final completeParts = <storage_api.MultipartUploadedPart>[];
        for (var i = 1; i <= partCount; i++) {
          final etag = etagsByPart[i];
          if (etag == null || etag.trim().isEmpty) {
            throw Exception('Missing ETag for part=$i');
          }
          completeParts.add(
            storage_api.MultipartUploadedPart(partNumber: i, etag: etag),
          );
        }

        await _completeMultipartUploadWithRetry(
          reportNumber: reportNumber,
          filename: filename,
          uploadId: uploadId,
          parts: completeParts,
          fileIndex: index + 1,
          totalFiles: totalItems,
        );
        fileState['completed'] = true;
        fileState['completedAt'] = DateTime.now().toIso8601String();
        fileState.remove('uploadId');
        fileState.remove('error');
        _writeUploadedPartsToState(fileState, etagsByPart);
        filesState[sourceKey] = fileState;
        await _persistBackendUploadStateToDraft();
        _setBackendUploadProgress(
          inProgress: true,
          statusText: 'Файл ${index + 1}/$totalItems выгружен',
          currentFile: index + 1,
          totalFiles: totalItems,
          currentPart: partCount,
          totalParts: partCount,
        );
        _updateBackendUploadFileProgress(
          item: item,
          index: index,
          totalItems: totalItems,
          fileName: filename,
          status: BackendUploadFileStatus.uploaded,
          progress: 1,
          uploadedParts: partCount,
          totalParts: partCount,
          errorText: '',
        );
        return true;
      } catch (e) {
        final currentSession = session;
        if (currentSession != null && fileState['uploadId'] == null) {
          fileState['uploadId'] = currentSession.uploadId;
        }
        fileState['error'] = e.toString();
        fileState['updatedAt'] = DateTime.now().toIso8601String();
        _writeUploadedPartsToState(fileState, etagsByPart);
        filesState[sourceKey] = fileState;
        await _persistBackendUploadStateToDraft();
        _backendUploadErrorText =
            'Ошибка файла ${index + 1}/$totalItems (${item.name}): $e';
        _updateBackendUploadFileProgress(
          item: item,
          index: index,
          totalItems: totalItems,
          fileName: fileState['filename']?.toString() ?? item.name,
          status: BackendUploadFileStatus.failed,
          progress: partCount <= 0 ? 0 : etagsByPart.length / partCount,
          uploadedParts: etagsByPart.length,
          totalParts: partCount,
          errorText: _backendUploadErrorText,
        );
        return false;
      }
    }

    while (_backendFileUploadLocked) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    _backendFileUploadLocked = true;
    try {
      return await runUpload();
    } finally {
      _backendFileUploadLocked = false;
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

    final backendReportNumber = _backendReportNumber();
    final currentReportCode = _currentReportCode();

    return {
      'id': _draftId,
      'assignmentId': _assignmentId,
      'reportCode': currentReportCode,
      if (backendReportNumber.isNotEmpty) 'reportNumber': backendReportNumber,
      'createdAt': _createdAt,
      'updatedAt': _dateLabel(now),
      'lastSavedAtIso': now.toIso8601String(),
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
      if (_modelGenerationRestylingFrameId != null &&
          _modelGenerationRestylingFrameId! > 0)
        'modelGenerationRestylingFrameId': _modelGenerationRestylingFrameId,
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
      'aiQueueChats': Map<String, dynamic>.from(_aiQueueChats),
      'backendUploadState': cloneMap(_backendUploadState),
      'mediaGroupsState': mediaPayload,
      'mediaCustomTags': customTagsPayload,
      'mediaCustomSeriousTags': customSeriousTagsPayload,
      'mediaDisabledDefaultTags': disabledDefaultsPayload,
      'mediaTagOrder': tagOrderPayload,
    };
  }

  void _markDraftDirty({bool scheduleAutosave = true}) {
    // Read-only views never dirty the draft — they render a submitted
    // report and must not leak any accidental mutation through the
    // autosave pipeline.
    if (widget.readOnly) return;
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
    if (_draftSaveInProgress) return 'Сохраняется';
    if (_draftSaveFailed) return 'Ошибка сохранения';
    if (_hasUnsavedDraftChanges) return 'Не сохранено';
    final lastSavedAt = _lastDraftSavedAt;
    if (lastSavedAt == null) return 'Сохранено';
    final hours = lastSavedAt.hour.toString().padLeft(2, '0');
    final minutes = lastSavedAt.minute.toString().padLeft(2, '0');
    return 'Сохранено в $hours:$minutes';
  }

  Color _draftSaveStatusColor() {
    if (_draftSaveInProgress) return kSecondaryColor;
    if (_draftSaveFailed) return kRedColor;
    if (_hasUnsavedDraftChanges) return kYellowColor;
    return kGreenColor;
  }

  IconData _draftSaveStatusIcon() {
    // Saving uses a spinner (rendered separately by the AppBar badge) so
    // this icon is only consulted when !_draftSaveInProgress.
    if (_draftSaveFailed) return Icons.error_outline_rounded;
    if (_hasUnsavedDraftChanges) return Icons.edit_note_rounded;
    return Icons.cloud_done_rounded;
  }

  Future<void> _saveDraft({
    bool showToast = true,
    bool fromAutosave = false,
  }) async {
    // Guardrail for the read-only path — nothing should ever call this
    // when viewing a completed report, but we also stop silently here so
    // any missed call sites don't trigger a storage write.
    if (widget.readOnly) return;
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

    final backendReportNumber = _backendReportNumber();
    final currentReportCode = _currentReportCode();

    return {
      'id': 'spark_report_${now.microsecondsSinceEpoch}',
      'assignmentId': _assignmentId,
      'createdAt': date,
      'reportDate': date,
      'updatedAt': date,
      'reportCode': currentReportCode,
      if (backendReportNumber.isNotEmpty) 'reportNumber': backendReportNumber,
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
    if (_backendUploadInProgress) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Выгрузка уже выполняется')));
      return;
    }
    final missingReasons = _summaryMissingReasons();
    if (missingReasons.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(missingReasons.join('\n'))));
      return;
    }

    _ensureSummaryAutofill(force: true);
    // Online-only: after finalizing on the server we don't persist a
    // local copy — the list reloads via Storage.GetSpecialistReport and
    // a tap opens via Storage.ViewSpecialistReport + ObjectStorage.
    // GetTemporaryViewUrl. The payload still carries everything needed
    // to build the PrepareSpecialistReport request.
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
    if (payload.isEmpty) return false;
    try {
      int? backendReportId = int.tryParse(
        (payload['id'] ?? payload['reportId'] ?? '').toString().trim(),
      );
      final cachedReportId = int.tryParse(
        (_backendUploadState['reportId'] ?? '').toString().trim(),
      );
      backendReportId ??= cachedReportId;
      _backendUploadFailed = false;
      _backendUploadErrorText = '';
      _setBackendUploadProgress(
        inProgress: true,
        statusText: 'Подготовка отчёта к выгрузке...',
        currentFile: 0,
        totalFiles: 0,
        currentPart: 0,
        totalParts: 0,
      );
      _setBackendUploadFilesProgress(const []);
      // Ensure all custom tags have server IDs before building payload.
      await _ensureAllTagIdsResolved();

      final previousReportNumber = _uploadStateText(
        _backendUploadState,
        'reportNumber',
      );
      final previousFilesState = _backendUploadFilesState();
      final backendReportPayload = _buildPrepareSpecialistReportPayload(
        payload,
      );
      final prepared = await storage_api.StorageApi.prepareSpecialistReport(
        report: backendReportPayload,
      );
      final reportNumber = prepared.reportNumber.trim();
      if (reportNumber.isEmpty) return false;
      backendReportId ??= prepared.reportId;
      final preservedFilesState =
          previousReportNumber.isNotEmpty &&
              previousReportNumber == reportNumber
          ? Map<String, dynamic>.from(previousFilesState)
          : <String, dynamic>{};
      _backendUploadState = <String, dynamic>{
        'reportNumber': reportNumber,
        if (backendReportId != null) 'reportId': backendReportId.toString(),
        'files': preservedFilesState,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _persistBackendUploadStateToDraft();
      payload['reportCode'] = reportNumber;

      if (_backendUploadState['files'] is! Map) {
        _backendUploadState['files'] = <String, dynamic>{};
      }
      _backendUploadState['updatedAt'] = DateTime.now().toIso8601String();
      await _persistBackendUploadStateToDraft();

      if (reportNumber.isEmpty) return false;
      if (payload['reportNumber'] == null ||
          payload['reportNumber'].toString().trim().isEmpty) {
        payload['reportNumber'] = reportNumber;
      }
      if (backendReportId != null) {
        payload['id'] = backendReportId.toString();
        payload['reportId'] = backendReportId.toString();
      }
      await _cleanupStaleMultipartUploads(reportNumber: reportNumber);

      final items = _collectUniqueUploadItems();
      _initializeBackendUploadFilesProgress(items: items);
      _setBackendUploadProgress(
        inProgress: true,
        statusText: items.isEmpty ? 'Файлов для загрузки нет' : null,
        currentFile: 0,
        totalFiles: items.length,
        currentPart: 0,
        totalParts: 0,
      );
      for (var i = 0; i < items.length; i++) {
        _setBackendUploadProgress(
          inProgress: true,
          statusText: null,
          currentFile: i + 1,
          totalFiles: items.length,
          currentPart: 0,
          totalParts: 0,
        );
        final uploaded = await _uploadItemWithMultipart(
          reportNumber: reportNumber,
          item: items[i],
          index: i,
          totalItems: items.length,
        );
        if (!uploaded) {
          throw Exception(
            _backendUploadErrorText.trim().isNotEmpty
                ? _backendUploadErrorText.trim()
                : 'Выгрузка остановлена на файле ${i + 1}/${items.length}',
          );
        }
      }

      _setBackendUploadProgress(
        inProgress: true,
        statusText: 'Финализируем отчёт...',
        currentFile: items.length,
        totalFiles: items.length,
        currentPart: 0,
        totalParts: 0,
      );
      final completion = await _completeSpecialistReportWithRetry(
        reportNumber: reportNumber,
      );
      backendReportId ??= completion?.reportId;
      if (backendReportId != null) {
        payload['id'] = backendReportId.toString();
        payload['reportId'] = backendReportId.toString();
        _backendUploadState['reportId'] = backendReportId.toString();
      }
      // Online-only: we no longer persist a local copy of the completed
      // report. The reports list will pick it up on the next
      // Storage.GetSpecialistReport fetch.
      _backendUploadState = <String, dynamic>{};
      await _persistBackendUploadStateToDraft();
      _setBackendUploadProgress(
        inProgress: false,
        statusText: '',
        currentFile: 0,
        totalFiles: 0,
        currentPart: 0,
        totalParts: 0,
      );
      _backendUploadFailed = false;
      _backendUploadErrorText = '';
      return true;
    } catch (e) {
      _backendUploadState['updatedAt'] = DateTime.now().toIso8601String();
      _backendUploadState['error'] = e.toString();
      await _persistBackendUploadStateToDraft();
      _backendUploadFailed = true;
      _backendUploadErrorText = e.toString();
      _setBackendUploadProgress(
        inProgress: false,
        statusText: 'Ошибка выгрузки. Попробуйте снова.',
        currentPart: 0,
        totalParts: 0,
      );
      return false;
    }
  }
}

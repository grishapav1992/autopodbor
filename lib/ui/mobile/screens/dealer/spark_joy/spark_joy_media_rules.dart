part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaRulesMethods on _SparkJoyCreateReportScreenState {
  bool _groupHasCoverage(_MediaGroupState state) {
    return _parseUrls(state.rawUrls).isNotEmpty || state.files.isNotEmpty;
  }

  List<_MediaGroupConfig> _requiredMediaGroups() {
    return _SparkJoyMediaGroupRegistry.groups
        .where((config) => config.required)
        .toList();
  }

  List<_MediaGroupConfig> _missingRequiredMediaGroups() {
    return _requiredMediaGroups().where((config) {
      final state = _mediaState[config.key];
      return state == null || !_groupHasCoverage(state);
    }).toList();
  }

  bool _isFullInspection() {
    for (final config in _requiredMediaGroups()) {
      final state = _mediaState[config.key];
      if (state == null || !_groupHasCoverage(state)) {
        return false;
      }
    }
    return true;
  }

  List<_MediaOption> _mediaElementOptions(String groupKey) {
    return _SparkJoyMediaTagRegistry.mediaElementOptionsByGroup[groupKey] ??
        const <_MediaOption>[];
  }

  String _mediaTagSourceGroup(String groupKey, {String? elementType}) {
    return groupKey == 'interior' &&
            elementType != null &&
            _SparkJoyMediaTagRegistry.interiorDashboardElementIds.contains(
              elementType,
            )
        ? 'interior_dashboard'
        : groupKey;
  }

  String _mediaTagScopeKey(String groupKey, {String? elementType}) {
    final sourceGroup = _mediaTagSourceGroup(
      groupKey,
      elementType: elementType,
    );
    final normalizedElement = (elementType ?? '').trim();

    if (normalizedElement.isNotEmpty &&
        (sourceGroup == 'interior_dashboard' || groupKey == 'diagnostics')) {
      return '$sourceGroup::$normalizedElement';
    }

    return sourceGroup;
  }

  List<_MediaTagOption> _mediaTagOptions(
    String groupKey, {
    String? elementType,
    Map<String, List<String>>? customTagsByScope,
    Map<String, List<String>>? customSeriousTagsByScope,
    Map<String, List<String>>? disabledDefaultTagsByScope,
    Map<String, List<String>>? tagOrderByScope,
    bool includeDisabledDefaults = false,
  }) {
    List<_MediaTagOption> applyOrderingAndVisibility(
      List<_MediaTagOption> source, {
      required String scopeKey,
      required Set<String> disabledDefaults,
    }) {
      final resolvedOrder = tagOrderByScope ?? _mediaTagOrderByScope;
      final order = (resolvedOrder[scopeKey] ?? const <String>[])
          .map((tag) => tag.toLowerCase())
          .toList();

      var result = source;
      if (order.isNotEmpty) {
        final indexed = <String, _MediaTagOption>{};
        for (final option in source) {
          indexed[option.label.toLowerCase()] = option;
        }
        final sorted = <_MediaTagOption>[];
        for (final key in order) {
          final option = indexed.remove(key);
          if (option != null) sorted.add(option);
        }
        for (final option in source) {
          final key = option.label.toLowerCase();
          if (indexed.containsKey(key)) {
            sorted.add(option);
            indexed.remove(key);
          }
        }
        result = sorted;
      }

      if (!includeDisabledDefaults && disabledDefaults.isNotEmpty) {
        result = result
            .where(
              (option) =>
                  option.isCustom ||
                  !disabledDefaults.contains(option.label.toLowerCase()),
            )
            .toList();
      }
      return result;
    }

    if (groupKey == 'diagnostics' &&
        elementType != null &&
        _SparkJoyMediaTagRegistry.diagnosticTagOptionsByElement.containsKey(
          elementType,
        )) {
      final options =
          _SparkJoyMediaTagRegistry.diagnosticTagOptionsByElement[elementType]!;
      final serious =
          _SparkJoyMediaTagRegistry
              .diagnosticSeriousTagsByElement[elementType] ??
          const <String>{};
      final resolvedCustom = customTagsByScope ?? _mediaCustomTagsByScope;
      final resolvedCustomSerious =
          customSeriousTagsByScope ?? _mediaCustomSeriousTagsByScope;
      final resolvedDisabled =
          disabledDefaultTagsByScope ?? _mediaDisabledDefaultTagsByScope;
      final scopeKey = _mediaTagScopeKey(groupKey, elementType: elementType);
      final custom = resolvedCustom[scopeKey] ?? const <String>[];
      final customSerious =
          (resolvedCustomSerious[scopeKey] ?? const <String>[])
              .map((tag) => tag.toLowerCase())
              .toSet();
      final disabledDefaults = (resolvedDisabled[scopeKey] ?? const <String>[])
          .map((tag) => tag.toLowerCase())
          .toSet();
      final dedup = options.toSet();
      var result = options
          .map(
            (label) => _MediaTagOption(
              label: label,
              severity: serious.contains(label) ? 'serious' : 'minor',
            ),
          )
          .toList();
      for (final label in custom) {
        if (dedup.contains(label)) continue;
        dedup.add(label);
        result.add(
          _MediaTagOption(
            label: label,
            severity: customSerious.contains(label.toLowerCase())
                ? 'serious'
                : 'minor',
            isCustom: true,
          ),
        );
      }
      return applyOrderingAndVisibility(
        result,
        scopeKey: scopeKey,
        disabledDefaults: disabledDefaults,
      );
    }

    final sourceGroup = _mediaTagSourceGroup(
      groupKey,
      elementType: elementType,
    );
    final options =
        _SparkJoyMediaTagRegistry.mediaTagOptionsByGroup[sourceGroup] ??
        const <String>[];
    final serious =
        _SparkJoyMediaTagRegistry.mediaSeriousTagsByGroup[sourceGroup] ??
        const <String>{};
    final resolvedCustom = customTagsByScope ?? _mediaCustomTagsByScope;
    final resolvedCustomSerious =
        customSeriousTagsByScope ?? _mediaCustomSeriousTagsByScope;
    final resolvedDisabled =
        disabledDefaultTagsByScope ?? _mediaDisabledDefaultTagsByScope;
    final scopeKey = _mediaTagScopeKey(groupKey, elementType: elementType);
    final custom = resolvedCustom[scopeKey] ?? const <String>[];
    final customSerious = (resolvedCustomSerious[scopeKey] ?? const <String>[])
        .map((tag) => tag.toLowerCase())
        .toSet();
    final disabledDefaults = (resolvedDisabled[scopeKey] ?? const <String>[])
        .map((tag) => tag.toLowerCase())
        .toSet();
    final dedup = options.toSet();
    var result = options
        .map(
          (label) => _MediaTagOption(
            label: label,
            severity: serious.contains(label) ? 'serious' : 'minor',
          ),
        )
        .toList();
    for (final label in custom) {
      if (dedup.contains(label)) continue;
      dedup.add(label);
      result.add(
        _MediaTagOption(
          label: label,
          severity: customSerious.contains(label.toLowerCase())
              ? 'serious'
              : 'minor',
          isCustom: true,
        ),
      );
    }
    return applyOrderingAndVisibility(
      result,
      scopeKey: scopeKey,
      disabledDefaults: disabledDefaults,
    );
  }

  List<_MediaTagGroup> _mediaTagGroups(
    String groupKey, {
    String? elementType,
    Map<String, List<String>>? customTagsByScope,
    Map<String, List<String>>? customSeriousTagsByScope,
    Map<String, List<String>>? disabledDefaultTagsByScope,
    Map<String, List<String>>? tagOrderByScope,
    bool includeDisabledDefaults = false,
  }) {
    final options = _mediaTagOptions(
      groupKey,
      elementType: elementType,
      customTagsByScope: customTagsByScope,
      customSeriousTagsByScope: customSeriousTagsByScope,
      disabledDefaultTagsByScope: disabledDefaultTagsByScope,
      tagOrderByScope: tagOrderByScope,
      includeDisabledDefaults: includeDisabledDefaults,
    );
    if (options.isEmpty) return const <_MediaTagGroup>[];

    final serious = options
        .where((option) => option.severity == 'serious')
        .toList();
    final minor = options
        .where((option) => option.severity != 'serious')
        .toList();

    final groups = <_MediaTagGroup>[];
    if (serious.isNotEmpty) {
      groups.add(
        _MediaTagGroup(
          title: 'Серьёзные',
          severity: 'serious',
          options: serious,
        ),
      );
    }
    if (minor.isNotEmpty) {
      groups.add(
        _MediaTagGroup(
          title: 'Незначительные',
          severity: 'minor',
          options: minor,
        ),
      );
    }
    return groups;
  }

  String _mediaTagSeverity(String groupKey, String tag, {String? elementType}) {
    for (final option in _mediaTagOptions(
      groupKey,
      elementType: elementType,
      includeDisabledDefaults: true,
    )) {
      if (option.label == tag) return option.severity;
    }
    return 'minor';
  }

  Color _mediaTagColor(String severity) {
    if (severity == 'serious') return kRedColor;
    return kYellowColor;
  }

  Color _mediaTagGroupTitleColor(_MediaTagGroup group) {
    final hasSerious = group.options.any(
      (option) => option.severity == 'serious',
    );
    final hasMinor = group.options.any(
      (option) => option.severity != 'serious',
    );
    if (hasSerious && !hasMinor) return kRedColor;
    if (hasMinor && !hasSerious) return kYellowColor;
    return kGreyColor;
  }

  String _mediaNoDamageLabel(String groupKey) {
    if (groupKey == 'diagnostics') return 'Без ошибок';
    return 'Без повреждений';
  }

  bool _mediaSupportsPaintThickness(String groupKey) {
    return groupKey == 'body' || groupKey == 'structural';
  }

  bool _mediaInspectionHasData(_MediaInspection inspection) {
    return inspection.noDamage ||
        inspection.tags.isNotEmpty ||
        inspection.note.trim().isNotEmpty ||
        inspection.audioRecordings.isNotEmpty ||
        (inspection.paintFrom != null && inspection.paintTo != null) ||
        (inspection.elementType ?? '').trim().isNotEmpty;
  }

  bool _mediaPartInspectionHasData(_MediaPartInspection inspection) {
    return inspection.noDamage ||
        inspection.tags.isNotEmpty ||
        inspection.note.trim().isNotEmpty ||
        inspection.audioRecordings.isNotEmpty ||
        inspection.tagPhotos.isNotEmpty ||
        (inspection.paintFrom != null && inspection.paintTo != null) ||
        (inspection.elementType ?? '').trim().isNotEmpty;
  }

  bool _mediaItemHasIssue(_UploadedItem item) {
    final inspection = item.inspection;
    if (inspection.isDraft) return false;
    if (inspection.noDamage) return false;
    return inspection.tags.isNotEmpty;
  }

  bool _groupHasIssue(_MediaGroupState state) {
    if (state.files.any(_mediaItemHasIssue)) return true;
    final partInspection = state.partInspection;
    if (!partInspection.isDraft &&
        !partInspection.noDamage &&
        partInspection.tags.isNotEmpty) {
      return true;
    }
    return state.hasIssue;
  }
}

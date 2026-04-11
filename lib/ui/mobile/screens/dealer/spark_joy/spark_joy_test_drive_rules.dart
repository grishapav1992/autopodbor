part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyTestDriveRulesMethods on _SparkJoyCreateReportScreenState {
  String? _normalizeTdMode(String rawValue) {
    final value = rawValue.trim();
    return _SparkJoyTestDriveRegistry.validModes.contains(value) ? value : null;
  }

  bool? _tdConductedValue() {
    if (_tdMode == _SparkJoyTestDriveRegistry.modeAllGood ||
        _tdMode == _SparkJoyTestDriveRegistry.modeProblems) {
      return true;
    }
    if (_tdMode == _SparkJoyTestDriveRegistry.modeNotConducted) {
      return false;
    }
    return null;
  }

  bool _areAllTdSectionsClean() {
    return _tdEngineOk &&
        _tdGearboxOk &&
        _tdSteeringOk &&
        _tdRideOk &&
        _tdBrakeOk &&
        _tdEngineTags.isEmpty &&
        _tdGearboxTags.isEmpty &&
        _tdSteeringTags.isEmpty &&
        _tdRideTags.isEmpty &&
        _tdBrakeTags.isEmpty;
  }

  void _applyTdAllGoodPreset() {
    _tdEngineOk = true;
    _tdGearboxOk = true;
    _tdSteeringOk = true;
    _tdRideOk = true;
    _tdBrakeOk = true;
    _tdEngineTags = const [];
    _tdGearboxTags = const [];
    _tdSteeringTags = const [];
    _tdRideTags = const [];
    _tdBrakeTags = const [];
  }

  void _applyTdProblemsPreset() {
    _tdEngineOk = false;
    _tdGearboxOk = false;
    _tdSteeringOk = false;
    _tdRideOk = false;
    _tdBrakeOk = false;
    _tdEngineTags = const [];
    _tdGearboxTags = const [];
    _tdSteeringTags = const [];
    _tdRideTags = const [];
    _tdBrakeTags = const [];
  }

  void _selectTdMode(String mode) {
    if (_tdMode == mode) return;
    _setStateSafely(() {
      _tdMode = mode;
      if (mode == _SparkJoyTestDriveRegistry.modeAllGood) {
        _applyTdAllGoodPreset();
      } else if (mode == _SparkJoyTestDriveRegistry.modeProblems) {
        _applyTdProblemsPreset();
      }
    });
    _markDraftDirty();
  }

  String _tdCustomTagInputKey(String scopeKey, String severity) {
    return '$scopeKey::$severity';
  }

  TextEditingController _tdCustomTagController(
    String scopeKey,
    String severity,
  ) {
    final key = _tdCustomTagInputKey(scopeKey, severity);
    return _tdCustomTagControllersByScope.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  FocusNode _tdCustomTagFocusNode(String scopeKey, String severity) {
    final key = _tdCustomTagInputKey(scopeKey, severity);
    return _tdCustomTagFocusNodesByScope.putIfAbsent(key, () => FocusNode());
  }

  List<_MediaTagGroup> _testDriveTagGroups(
    String scopeKey, {
    bool includeDisabledDefaults = false,
  }) {
    final defaults =
        _SparkJoyTestDriveRegistry.tagOptionsByScope[scopeKey] ??
        const <String>[];
    final seriousDefaults =
        _SparkJoyTestDriveRegistry.seriousTagsByScope[scopeKey] ??
        const <String>{};
    final custom = _mediaCustomTagsByScope[scopeKey] ?? const <String>[];
    final customSerious =
        (_mediaCustomSeriousTagsByScope[scopeKey] ?? const <String>[])
            .map((tag) => tag.toLowerCase())
            .toSet();
    final disabledDefaults =
        (_mediaDisabledDefaultTagsByScope[scopeKey] ?? const <String>[])
            .map((tag) => tag.toLowerCase())
            .toSet();
    final order = (_mediaTagOrderByScope[scopeKey] ?? const <String>[])
        .map((tag) => tag.toLowerCase())
        .toList();

    final options = <_MediaTagOption>[];
    final addedLower = <String>{};

    void addOption(
      String label, {
      required bool isCustom,
      required String severity,
    }) {
      final trimmed = label.trim();
      if (trimmed.isEmpty) return;
      final lower = trimmed.toLowerCase();
      if (addedLower.contains(lower)) return;
      if (!isCustom &&
          !includeDisabledDefaults &&
          disabledDefaults.contains(lower)) {
        return;
      }
      addedLower.add(lower);
      options.add(
        _MediaTagOption(label: trimmed, severity: severity, isCustom: isCustom),
      );
    }

    for (final label in defaults) {
      addOption(
        label,
        isCustom: false,
        severity: seriousDefaults.contains(label) ? 'serious' : 'minor',
      );
    }
    for (final label in custom) {
      addOption(
        label,
        isCustom: true,
        severity: customSerious.contains(label.toLowerCase())
            ? 'serious'
            : 'minor',
      );
    }

    if (order.isNotEmpty && options.isNotEmpty) {
      final indexed = <String, _MediaTagOption>{};
      for (final option in options) {
        indexed[option.label.toLowerCase()] = option;
      }
      final sorted = <_MediaTagOption>[];
      for (final key in order) {
        final option = indexed.remove(key);
        if (option != null) sorted.add(option);
      }
      for (final option in options) {
        final key = option.label.toLowerCase();
        if (indexed.containsKey(key)) {
          sorted.add(option);
          indexed.remove(key);
        }
      }
      options
        ..clear()
        ..addAll(sorted);
    }

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

  void _addTestDriveCustomTag({
    required String scopeKey,
    required String severity,
  }) {
    final controller = _tdCustomTagController(scopeKey, severity);
    final raw = controller.text.trim();
    if (raw.isEmpty) return;
    final groups = _testDriveTagGroups(scopeKey, includeDisabledDefaults: true);
    final lower = raw.toLowerCase();
    for (final group in groups) {
      for (final option in group.options) {
        if (option.label.toLowerCase() == lower) {
          controller.clear();
          return;
        }
      }
    }

    _setStateSafely(() {
      final custom = [
        ...(_mediaCustomTagsByScope[scopeKey] ?? const <String>[]),
      ];
      custom.add(raw);
      _mediaCustomTagsByScope[scopeKey] = custom;

      final serious = [
        ...(_mediaCustomSeriousTagsByScope[scopeKey] ?? const <String>[]),
      ];
      if (severity == 'serious') {
        serious.add(raw);
      } else {
        serious.removeWhere((tag) => tag.toLowerCase() == lower);
      }
      if (serious.isEmpty) {
        _mediaCustomSeriousTagsByScope.remove(scopeKey);
      } else {
        _mediaCustomSeriousTagsByScope[scopeKey] = serious;
      }

      final nextOrder = <String>[
        ...(_mediaTagOrderByScope[scopeKey] ?? const <String>[]),
        raw,
      ];
      _mediaTagOrderByScope[scopeKey] = nextOrder;
    });
    controller.clear();
    _markDraftDirty();
  }

  bool _testDriveSectionHasData(bool ok, List<String> tags) {
    return ok || tags.isNotEmpty;
  }

  bool _isTdAllSubsystemsMarkedOk() {
    return _tdEngineOk &&
        _tdGearboxOk &&
        _tdSteeringOk &&
        _tdRideOk &&
        _tdBrakeOk;
  }

  bool _isTdCommentRequired() {
    final tdConducted = _tdConductedValue();
    if (tdConducted != true) return false;
    if (_tdMode != _SparkJoyTestDriveRegistry.modeProblems) {
      return false;
    }
    return _isTdAllSubsystemsMarkedOk();
  }
}

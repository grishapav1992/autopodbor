part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCompletionRulesMethods on _SparkJoyCreateReportScreenState {
  bool _docsAllAnswered() {
    return _docsOwnerMatch != null &&
        _docsVinMatch != null &&
        _docsEngineMatch != null;
  }

  bool _docsAnyMismatch() {
    return _docsOwnerMatch == false ||
        _docsVinMatch == false ||
        _docsEngineMatch == false;
  }

  List<String> _docsCheckMissingReasons() {
    final reasons = <String>[];
    if (!_docsAllAnswered()) {
      reasons.add('Заполните все пункты сверки документов');
    }
    return reasons;
  }

  List<String> _testDriveMissingReasons() {
    final reasons = <String>[];
    final tdConducted = _tdConductedValue();
    if (tdConducted == null) {
      reasons.add('Выберите, проводился ли тест-драйв');
      return reasons;
    }
    if (tdConducted == false ||
        _tdMode == _SparkJoyTestDriveRegistry.modeAllGood) {
      return reasons;
    }

    if (!_testDriveSectionHasData(_tdEngineOk, _tdEngineTags)) {
      reasons.add('Проверьте двигатель');
    }
    if (!_testDriveSectionHasData(_tdGearboxOk, _tdGearboxTags)) {
      reasons.add('Проверьте КПП');
    }
    if (!_testDriveSectionHasData(_tdSteeringOk, _tdSteeringTags)) {
      reasons.add('Проверьте рулевое управление');
    }
    if (!_testDriveSectionHasData(_tdRideOk, _tdRideTags)) {
      reasons.add('Проверьте подвеску на ходу');
    }
    if (!_testDriveSectionHasData(_tdBrakeOk, _tdBrakeTags)) {
      reasons.add('Проверьте тормоза на ходу');
    }
    if (_isTdCommentRequired() && _tdNoteController.text.trim().isEmpty) {
      reasons.add('Добавьте комментарий по тест-драйву');
    }
    return reasons;
  }

  List<String> _summaryMissingReasons() {
    final reasons = <String>[];
    final hasVehicle = _vinController.text.trim().isNotEmpty || _vinUnreadable;
    final hasMileage = _mileageController.text.trim().isNotEmpty;
    final hasDocs =
        _docsOwnerMatch != null &&
        _docsVinMatch != null &&
        _docsEngineMatch != null;
    final requiredMediaKeys =
        _SparkJoySummaryRegistry.requiredMediaKeysForSummary;
    final missingMedia = <String>[];
    for (final key in requiredMediaKeys) {
      final state = _mediaState[key];
      if (state == null || !_groupHasCoverage(state)) {
        missingMedia.add(
          _SparkJoySummaryRegistry.mediaGroupLabelByKey[key] ?? key,
        );
      }
    }
    final hasTestDrive = _tdMode != null;
    final attachmentStats = _summaryAttachmentStats();

    if (!hasVehicle) {
      reasons.add('Автомобиль — укажите VIN');
    }
    if (!hasMileage) {
      reasons.add('Автомобиль — укажите пробег');
    }
    if (!hasDocs) {
      reasons.add('Сверка документов — ответьте на все вопросы');
    }
    if (!hasTestDrive) {
      reasons.add('Тест-драйв — отметьте проведение');
    } else {
      // Fold per-subsystem blockers from _testDriveMissingReasons so the
      // "Завершить" button cannot fire Storage.PrepareSpecialistReport
      // with IsWorkingProperly=false + empty tag list. The backend
      // validates both sides and rejects the whole report otherwise.
      // Skip the "Добавьте комментарий" entry — it's appended below
      // under its own copy to match the existing wording.
      final tdReasons = _testDriveMissingReasons().where(
        (r) => !r.startsWith('Добавьте комментарий'),
      );
      for (final reason in tdReasons) {
        reasons.add('Тест-драйв — ${_lowerFirst(reason)}');
      }
    }
    if (_isTdCommentRequired() && _tdNoteController.text.trim().isEmpty) {
      reasons.add('Тест-драйв — добавьте комментарий');
    }
    for (final label in missingMedia) {
      reasons.add('Осмотр — добавьте фото: $label');
    }
    if (attachmentStats.brokenCount > 0) {
      reasons.add(
        'Вложения — исправьте ${attachmentStats.brokenCount} некорректных файл(ов)',
      );
    }
    // Company/IP reports must have an assignee picked at creation
    // time (either a specialist or a pending invite link). Both
    // values come from the "new report" entry form.
    if (_hasBusinessStatus() &&
        _assignedSpecialistId.trim().isEmpty &&
        _staffInviteLink.trim().isEmpty) {
      reasons.add('Исполнитель — назначьте сотрудника на этапе создания');
    }
    return reasons;
  }

  String? _summaryReasonStepId(String reason) {
    return _SparkJoySummaryRegistry.stepIdByMissingReason(reason);
  }

  String? _summaryReasonMediaGroupKey(String reason) {
    return _SparkJoySummaryRegistry.mediaGroupKeyByMissingReason(reason);
  }

  String _lowerFirst(String input) {
    if (input.isEmpty) return input;
    return input[0].toLowerCase() + input.substring(1);
  }
}

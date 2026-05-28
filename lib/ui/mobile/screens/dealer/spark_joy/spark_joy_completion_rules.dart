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
    // Все проверки соответствуют `required[]` из OpenRPC спеки
    // `Storage.PrepareSpecialistReport` (см. `docs/openrpc_doc_2026-04-26.json`).
    // До этого фронт молча подставлял заглушки ('Отчёт', 'Не указан',
    // hardcoded VIN) — серверу прилетал валидный, но фактически
    // пустой отчёт. Гейтим save строго: пусто — кричим юзеру.
    final hasReportName = _reportNameController.text.trim().isNotEmpty;
    // After «Сводка» + «Итог специалиста» were merged into a single
    // «Итог осмотра», there's only one text gate here. The previous
    // `hasExpertNote` second gate is retired.
    final hasSummaryNote = _summaryController.text.trim().isNotEmpty;
    final hasVehicle = _vinController.text.trim().isNotEmpty;
    final hasMileage = _mileageController.text.trim().isNotEmpty;
    // Backend requires only a non-blank city string. The picker-validity
    // flag is useful for UI hints, but must not block completion for
    // drafts restored from company requests or older free-form values.
    final hasInspectionCity = _inspectionCityController.text.trim().isNotEmpty;
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

    if (!hasReportName) {
      reasons.add('Отчёт — укажите название');
    }
    if (!hasVehicle) {
      reasons.add('Автомобиль — укажите VIN');
    }
    if (!hasMileage) {
      reasons.add('Автомобиль — укажите пробег');
    }
    if (!hasInspectionCity) {
      reasons.add('Автомобиль — укажите город осмотра');
    }
    if (!hasSummaryNote) {
      reasons.add('Итог — заполните итог осмотра');
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
    // Profanity gate: scan each free-text field independently so the
    // user knows exactly which one to clean up. Reasons are appended
    // alongside the missing-field reasons — a field can simultaneously
    // be empty AND contain a stale draft of profanity, both surfaced.
    for (final entry in _profanityCheckTargets()) {
      final result = ProfanityModerator.moderateText(
        entry.controller.text,
        fieldLabel: entry.fieldLabel,
      );
      if (result.isBlock) {
        reasons.add('${entry.section} — текст содержит недопустимые слова');
      }
    }

    return reasons;
  }

  /// Free-text controllers that participate in the profanity gate +
  /// the section / field labels used in the user-facing reason
  /// strings. Kept on a method (not a field) so the iterable is
  /// rebuilt against current state every time `_summaryMissingReasons`
  /// runs — avoids stale references after a controller swap.
  List<_ProfanityCheckTarget> _profanityCheckTargets() => [
    _ProfanityCheckTarget(
      controller: _reportNameController,
      fieldLabel: 'Название отчёта',
      section: 'Отчёт',
    ),
    _ProfanityCheckTarget(
      controller: _docsMismatchCommentController,
      fieldLabel: 'Комментарий по документам',
      section: 'Сверка документов',
    ),
    _ProfanityCheckTarget(
      controller: _legalNoteController,
      fieldLabel: 'Юридическое заключение',
      section: 'Юр. проверка',
    ),
    _ProfanityCheckTarget(
      controller: _tdNoteController,
      fieldLabel: 'Заметка по тест-драйву',
      section: 'Тест-драйв',
    ),
    _ProfanityCheckTarget(
      controller: _summaryController,
      fieldLabel: 'Итог осмотра',
      section: 'Итог',
    ),
  ];

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

/// Pairs a free-text controller with the labels needed to render a
/// profanity-block reason. Kept as a top-level class (not nested)
/// because part-files can't declare local types inside extensions.
class _ProfanityCheckTarget {
  const _ProfanityCheckTarget({
    required this.controller,
    required this.fieldLabel,
    required this.section,
  });

  final TextEditingController controller;
  final String fieldLabel;
  final String section;
}

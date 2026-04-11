part of 'spark_joy_create_report_screen.dart';

extension _SparkJoySummaryRulesMethods on _SparkJoyCreateReportScreenState {
  String _triStateLabel(bool? value) {
    if (value == true) return 'Соответствует';
    if (value == false) return 'Не соответствует';
    return 'Не проверено';
  }

  String _docsStateLabel(bool? value) {
    if (value == true) return 'Соответствует';
    if (value == false) return 'Не соответствует';
    return '';
  }

  Color _docsStateColor(bool? value) {
    if (value == true) return kGreenColor;
    if (value == false) return kRedColor;
    return kGreyColor;
  }

  Map<String, dynamic>? _summarySectionByTitle(
    _CalculatedSummary summary,
    String title,
  ) {
    for (final section in summary.sections) {
      if ((section['title'] ?? '').toString().trim() == title) {
        return section;
      }
    }
    return null;
  }

  String _summaryCleanValue(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^[^A-Za-zА-Яа-я0-9]+'), '')
        .trim();
  }

  String _summaryStripKnownPrefixes(String value) {
    return value
        .replaceFirst(RegExp(r'^Заметка:\s*', caseSensitive: false), '')
        .replaceFirst(
          RegExp(r'^по результатам осмотра:\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  String _summaryLowerFirst(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toLowerCase()}${value.substring(1)}';
  }

  bool _summaryIsGenericPositiveValue(String value) {
    final normalized = _summaryCleanValue(value).toLowerCase();
    return {
      'без повреждений',
      'без замечаний',
      'в порядке',
      'без ошибок',
      'без дефектов',
      'норма',
      'соответствует',
      'все соответствует',
      'всё соответствует',
    }.contains(normalized);
  }

  bool _summaryIsInspectionGapValue(String value) {
    final normalized = _summaryCleanValue(value).toLowerCase();
    return normalized.contains('не осмотр') ||
        normalized.contains('не провер') ||
        normalized.contains('не провод') ||
        normalized == 'не заполнено' ||
        normalized == 'не указано';
  }

  bool _summarySectionHasGap(Map<String, dynamic>? section, RegExp matcher) {
    if (section == null) return false;
    final details = section['details'];
    if (details is! List) return false;
    for (final detail in details) {
      if (detail is! Map) continue;
      final mapped = detail.map((key, value) => MapEntry('$key', value));
      final value = _summaryCleanValue(
        (mapped['value'] ?? '').toString(),
      ).toLowerCase();
      if (matcher.hasMatch(value)) return true;
    }
    return false;
  }

  List<Map<String, String>> _summaryExtractItems(
    Map<String, dynamic>? section, {
    Set<String> severities = const {'serious', 'minor'},
  }) {
    if (section == null) return const <Map<String, String>>[];
    final details = section['details'];
    if (details is! List) return const <Map<String, String>>[];
    final result = <Map<String, String>>[];
    for (final raw in details) {
      if (raw is! Map) continue;
      final detail = raw.map((key, value) => MapEntry('$key', value));
      final severity = (detail['severity'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (!severities.contains(severity)) continue;
      final label = (detail['label'] ?? '').toString().trim();
      final value = _summaryStripKnownPrefixes(
        _summaryCleanValue((detail['value'] ?? '').toString().trim()),
      );
      if (label.isEmpty || value.isEmpty) continue;
      if (_summaryIsGenericPositiveValue(value)) continue;
      if (_summaryIsInspectionGapValue(value)) continue;
      if (label == 'Разброс ЛКП' && severity != 'serious') continue;
      result.add({'label': label, 'value': value, 'severity': severity});
    }
    return result;
  }

  List<String> _summaryExtractNotes(Map<String, dynamic>? section) {
    if (section == null) return const <String>[];
    final details = section['details'];
    if (details is! List) return const <String>[];
    final result = <String>[];
    for (final raw in details) {
      if (raw is! Map) continue;
      final detail = raw.map((key, value) => MapEntry('$key', value));
      final label = (detail['label'] ?? '').toString().trim().toLowerCase();
      if (label != 'комментарий' &&
          !label.startsWith('📝') &&
          !label.startsWith('📋')) {
        continue;
      }
      final note = _summaryStripKnownPrefixes(
        _summaryCleanValue((detail['value'] ?? '').toString()),
      );
      if (note.isEmpty) continue;
      result.add(note);
    }
    return result;
  }

  String _summaryFormatIssueList(
    List<Map<String, String>> items, {
    int limit = 3,
  }) {
    if (items.isEmpty) return '';
    final rows = <String>[];
    for (final item in items.take(limit)) {
      final label = _summaryLowerFirst((item['label'] ?? '').trim());
      final value = (item['value'] ?? '').trim();
      if (label.isEmpty || value.isEmpty) continue;
      rows.add('  ▸ $label — $value');
    }
    if (items.length > limit) {
      rows.add('  ▸ а также другие замечания');
    }
    if (rows.isEmpty) return '';
    return '\n${rows.join('\n')}';
  }

  String _summaryHumanJoin(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} и ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')} и ${items.last}';
  }

  String _summaryTemplate(_CalculatedSummary summary) {
    final lines = <String>[];
    var hasMeaningfulBlocks = false;

    final carName = _carName().trim();
    final vin = _vinController.text.trim();
    final plateRaw = _sanitizePlate(_plateController.text.trim());
    final plate = plateRaw.isEmpty ? '' : _formatPlate(plateRaw);
    final vinPart = vin.isNotEmpty
        ? ', VIN $vin'
        : (_vinUnreadable ? ', VIN не читается' : '');
    final platePart = plate.isNotEmpty ? ', г/н $plate' : '';
    lines.add(
      'Осмотрен автомобиль ${carName.isEmpty ? '—' : carName}$vinPart$platePart.',
    );
    lines.add('');

    final identityParts = <String>[];
    if (_vinUnreadable) {
      identityParts.add(
        'VIN не читается, требуется дополнительная сверка идентификационных данных.',
      );
    }
    final mileage = _mileageController.text.trim();
    if (mileage.isNotEmpty && _mileageMismatch == true) {
      identityParts.add(
        'Пробег $mileage км не соответствует заявленному продавцом.',
      );
    }
    final docsMismatch = <String>[];
    if (_docsOwnerMatch == false) {
      docsMismatch.add('владелец не соответствует документам');
    }
    if (_docsVinMatch == false) {
      docsMismatch.add('VIN в документах не совпадает');
    }
    if (_docsEngineMatch == false) {
      docsMismatch.add('модель двигателя не совпадает');
    }
    if (docsMismatch.isNotEmpty) {
      identityParts.add(
        'По результатам сверки документов выявлены несоответствия: '
        '${_summaryHumanJoin(docsMismatch)}.',
      );
    }
    if (identityParts.isNotEmpty) {
      hasMeaningfulBlocks = true;
      lines.add('По проверкам и идентификации:');
      for (final part in identityParts) {
        lines.add('  ▸ $part');
      }
      lines.add('');
    }

    void appendIssues(
      String title, {
      RegExp? skipIfGapPattern,
      Set<String> severities = const {'serious', 'minor'},
      bool includeFirstNote = false,
    }) {
      final section = _summarySectionByTitle(summary, title);
      if (section == null) return;
      if (skipIfGapPattern != null &&
          _summarySectionHasGap(section, skipIfGapPattern)) {
        return;
      }
      final issues = _summaryExtractItems(section, severities: severities);
      final formatted = _summaryFormatIssueList(issues);
      if (formatted.isNotEmpty) {
        hasMeaningfulBlocks = true;
        lines.add('$title:$formatted');
        lines.add('');
      }
      if (!includeFirstNote) return;
      final notes = _summaryExtractNotes(section);
      if (notes.isNotEmpty) {
        hasMeaningfulBlocks = true;
        lines.add(notes.first);
        lines.add('');
      }
    }

    final inspectionGapPattern = RegExp(r'не осмотр', caseSensitive: false);
    appendIssues(
      'Кузов',
      skipIfGapPattern: inspectionGapPattern,
      includeFirstNote: true,
    );
    appendIssues(
      'Силовые элементы кузова',
      skipIfGapPattern: inspectionGapPattern,
    );
    appendIssues('Остекление', skipIfGapPattern: inspectionGapPattern);
    appendIssues('Светотехника', skipIfGapPattern: inspectionGapPattern);
    appendIssues(
      'Подкапотное пространство',
      skipIfGapPattern: inspectionGapPattern,
      includeFirstNote: true,
    );
    appendIssues(
      'Компьютерная диагностика',
      skipIfGapPattern: RegExp(r'не провод', caseSensitive: false),
      includeFirstNote: true,
    );
    appendIssues(
      'Колёса и тормозные механизмы',
      skipIfGapPattern: inspectionGapPattern,
    );
    if (_tdMode != _SparkJoyTestDriveRegistry.modeNotConducted) {
      appendIssues('Тест-драйв', severities: const {'serious'});
    }
    appendIssues('Салон', skipIfGapPattern: inspectionGapPattern);

    final missing = <String>[];
    if (!_legalLoaded) {
      missing.add('юридическую проверку');
    }
    if (_tdMode == _SparkJoyTestDriveRegistry.modeNotConducted) {
      missing.add('тест-драйв');
    }
    if (_docsOwnerMatch == null ||
        _docsVinMatch == null ||
        _docsEngineMatch == null) {
      missing.add('полную сверку документов');
    }
    final bodyState = _mediaState['body'];
    if (bodyState == null || !_groupHasCoverage(bodyState)) {
      missing.add('осмотр кузова');
    }
    final glassState = _mediaState['glass'];
    if (glassState == null || !_groupHasCoverage(glassState)) {
      missing.add('осмотр остекления');
    }
    final underhoodState = _mediaState['underhood'];
    if (underhoodState == null || !_groupHasCoverage(underhoodState)) {
      missing.add('осмотр подкапотного пространства');
    }
    final interiorState = _mediaState['interior'];
    if (interiorState == null || !_groupHasCoverage(interiorState)) {
      missing.add('осмотр салона');
    }

    final uniqueMissing = <String>[];
    for (final item in missing) {
      if (!uniqueMissing.contains(item)) {
        uniqueMissing.add(item);
      }
    }
    if (uniqueMissing.isNotEmpty) {
      hasMeaningfulBlocks = true;
      lines.add(
        'Дополнительно рекомендуется выполнить: '
        '${_summaryHumanJoin(uniqueMissing)}.',
      );
    }

    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    if (!hasMeaningfulBlocks) {
      lines.add('Критичных замечаний по результатам осмотра не выявлено.');
    }
    return lines.join('\n').trim();
  }

  void _ensureSummaryAutofill({bool force = false}) {
    final summary = _calculateSummary();
    if (!force && _summaryController.text.trim().isNotEmpty) return;
    _summaryController.text = _summaryTemplate(summary);
  }
}

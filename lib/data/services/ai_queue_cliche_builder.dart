import 'package:flutter_application_1/data/api/storage_api.dart' show UserTag, UserTagType;

/// Builds the `cliche` template string passed to `AiQueue.ChatCompletions`.
///
/// The cliche is a prompt template with a literal `{text}` placeholder
/// that the backend substitutes with the `text` param. We bake every
/// piece of element-specific context (element name, tags with severity,
/// existing note) into the cliche so the model can reason from the full
/// inspection state, while the user-typed note flows through `text`.
class AiQueueClicheBuilder {
  AiQueueClicheBuilder._();

  /// [elementLabel] — human-readable element name (e.g. "Капот", "Левая
  /// передняя дверь"). The caller resolves the elementType key →
  /// label via the existing spark_joy element registry; we do not
  /// duplicate that mapping here.
  ///
  /// [tags] — full UserTag objects so we can preserve severity in the
  /// prompt. Pass an empty list when no tags are selected.
  ///
  /// [existingNote] — the inspector's typed note before AI runs. Empty
  /// string when the editor is blank.
  static String buildElementCliche({
    required String elementLabel,
    required List<UserTag> tags,
    String existingNote = '',
  }) {
    // Delegate to the labels-based variant so the «must mention each
    // tag dosslovno» framing is shared. Saves drift between the two
    // entry points — see [buildElementClicheFromLabels] for the full
    // prompt explanation.
    final labels = tags
        .map((t) => t.name.trim())
        .where((n) => n.isNotEmpty)
        .toList(growable: false);
    final seriousLabels = <String>{
      for (final t in tags)
        if (t.type == UserTagType.serious) t.name.trim(),
    }..removeWhere((n) => n.isEmpty);
    return buildElementClicheFromLabels(
      elementLabel: elementLabel,
      selectedTagLabels: labels,
      seriousTagLabels: seriousLabels,
      existingNote: existingNote,
    );
  }

  /// Cliche for the final report-level summary, called once after the
  /// per-element histories are aggregated. Kept here so the template
  /// stays alongside the per-element variant.
  static String buildSummaryCliche({required String reportLabel}) {
    final label = reportLabel.trim().isEmpty ? 'Отчёт об осмотре авто' : reportLabel.trim();
    return 'Ты эксперт по техническому осмотру автомобилей. '
        'Собери итоговое заключение по отчёту "$label" из контекста по '
        'отдельным элементам. Структурируй по разделам: кузов, салон, '
        'тест-драйв, юридическая проверка. Будь краток и по делу. '
        'Контекст из историй чата по элементам: {text}';
  }

  /// Cliche for the docs-check «Комментарий по расхождениям» field.
  /// The three yes/no answers above the comment input (Владелец /
  /// VIN / Двигатель) plus the inspector's typed text are baked
  /// into the prompt so the model sees which fields are mismatching
  /// even when the typed comment is short.
  static String buildDocsCheckCommentCliche({
    required bool? ownerMatch,
    required bool? vinMatch,
    required bool? engineMatch,
  }) {
    String label(bool? value) {
      if (value == null) return 'не указано';
      return value ? 'соответствует' : 'не соответствует';
    }

    return 'Ты эксперт по техническому осмотру авто. Дилер выполнил '
        'сверку документов и зафиксировал такие результаты:\n'
        '- Данные владельца: ${label(ownerMatch)}\n'
        '- Идентификационные номера (VIN): ${label(vinMatch)}\n'
        '- Модель двигателя: ${label(engineMatch)}\n'
        '\n'
        'На основе этих данных и комментария дилера ниже сформулируй '
        'короткий профессиональный текст для отчёта о том, что именно '
        'не сходится и какие риски это несёт для покупателя. '
        'Не выдумывай факты, которых нет в данных или комментарии. '
        'Возвращай только готовый текст без преамбулы и markdown.\n'
        '\n'
        'Комментарий дилера: {text}';
  }

  /// Cliche for the data-summary card («Сводка по данным осмотра»).
  /// Distinct from [buildSummaryCliche]: that one renders the
  /// expert's recommendation (мнение); this one renders just the
  /// facts — what's in the report, by section, no buy/don't-buy
  /// advice. Both can run in the same report and should not
  /// duplicate each other.
  static String buildReportFactsCliche({required String reportLabel}) {
    final label = reportLabel.trim().isEmpty
        ? 'Отчёт об осмотре авто'
        : reportLabel.trim();
    return 'Ты ассистент по техническому осмотру автомобилей. '
        'Сформируй короткую фактологическую сводку по данным отчёта "$label". '
        'Перечисли что именно зафиксировано по разделам: кузов, остекление, '
        'светотехника, подкапотное пространство, салон, колёса, диагностика, '
        'тест-драйв, юридическая проверка. '
        'Только факты из контекста: что осмотрено, какие замечания/теги, '
        'какие комментарии. Не давай оценок, рекомендаций по покупке или торгу — '
        'это будет в отдельном поле «Итог специалиста». '
        'Если по разделу нет данных — пропусти его. '
        'Без преамбулы, без markdown-форматирования. '
        'Контекст из историй чата по элементам и полям отчёта: {text}';
  }

  /// Same as [buildElementCliche] but takes raw tag labels + a set of
  /// labels that the UI considers "serious". Saves callers from
  /// resolving labels → [UserTag] objects when the editor already
  /// carries that data in label form.
  ///
  /// [paintFrom] / [paintFrom] — paint thickness range in micrometers
  /// from the толщиномер tool. Both must be non-null to surface in the
  /// prompt; otherwise the line is omitted. Helps the model flag
  /// suspicious values (e.g. 250+ мкм usually means body filler /
  /// repaint).
  static String buildElementClicheFromLabels({
    required String elementLabel,
    required List<String> selectedTagLabels,
    required Set<String> seriousTagLabels,
    String existingNote = '',
    double? paintFrom,
    double? paintTo,
  }) {
    final element = elementLabel.trim().isEmpty ? 'элемент авто' : elementLabel.trim();
    final cleanLabels = selectedTagLabels
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final seriousLower = seriousTagLabels.map((s) => s.toLowerCase()).toSet();
    final paintLine = (paintFrom != null && paintTo != null)
        ? 'Толщина ЛКП: ${paintFrom.round()}-${paintTo.round()} мкм '
            '(норма ~80-200 мкм; больше — возможна перекраска или шпатлёвка). '
        : '';

    // Stronger framing for the tag list: previous version inlined tags
    // as a single comma list and asked the model not to «invent»
    // anything beyond them — but didn't actually require each tag to
    // appear in the answer. Models would frequently summarize («есть
    // повреждения») without naming the specific word the inspector
    // selected. Now we surface each tag as its own bullet and add an
    // explicit rule requiring every tag's name in the output.
    final String tagsBlock;
    final String mustMentionRule;
    if (cleanLabels.isEmpty) {
      tagsBlock = 'Замечания/теги: нет.\n';
      mustMentionRule = '';
    } else {
      final bullets = cleanLabels.map((label) {
        final severity = seriousLower.contains(label.toLowerCase())
            ? 'серьёзное'
            : 'некритичное';
        return '- $label ($severity)';
      }).join('\n');
      tagsBlock =
          'Дилер выявил следующие повреждения / замечания (НЕ ИЗМЕНЯЙ названия):\n'
          '$bullets\n';
      // Use the literal tag names so the prompt nails the requirement
      // even if the model paraphrases everything else.
      final names = cleanLabels.join(', ');
      mustMentionRule =
          'ОБЯЗАТЕЛЬНО упомяни в ответе каждое из этих названий дословно: '
          '$names. ';
    }

    final noteLine = existingNote.trim().isEmpty ? '—' : existingNote.trim();

    return 'Ты эксперт по техническому осмотру автомобилей. '
        'Сформулируй короткое профессиональное замечание на русском по '
        'элементу: $element.\n\n'
        '$tagsBlock'
        '$paintLine'
        'Текущее описание инспектора: $noteLine.\n\n'
        '$mustMentionRule'
        'Если приложены фото — учитывай их визуальную информацию. '
        'Не выдумывай дефекты, которых нет в тегах и фото. '
        'Верни только финальный текст замечания, без преамбулы и markdown. '
        'Дополнительный контекст от инспектора: {text}';
  }

  /// Cliché for the «Комментарий специалиста» field on the «Материалы
  /// проверки» step. Bakes in the count and (top-3 by name length)
  /// names of the documents the inspector attached so the model can
  /// reference them in the comment without the user repeating each
  /// filename manually. The inspector's typed text flows through {text}.
  static String buildLegalCommentCliche({
    required int filesCount,
    required List<String> fileNames,
  }) {
    final filesPart = filesCount == 0
        ? 'Документы не приложены. '
        : 'Приложено документов: $filesCount '
            '(${fileNames.take(3).join(", ")}${fileNames.length > 3 ? ', …' : ''}). ';
    return 'Ты эксперт по приёмке автомобилей. '
        'Сформулируй короткий профессиональный текст для блока '
        '«Материалы проверки» отчёта. $filesPart'
        'На основе приложенных документов и комментария инспектора ниже '
        'опиши ключевые моменты: что было проверено, какие риски/'
        'нюансы выявлены, какие действия рекомендуются клиенту. '
        'Не выдумывай документы или факты, которых нет в данных. '
        'Возвращай только готовый текст без преамбулы и markdown.\n'
        '\n'
        'Комментарий инспектора: {text}';
  }

  /// Cliché for the «Комментарий по тест-драйву» field. Bakes in the
  /// test-drive mode (proceeded / not proceeded / all good / has issues)
  /// plus per-subsystem ok-flag and any selected tags so the model has
  /// full context regardless of how short the typed text is.
  ///
  /// [tdMode] — wire-string from `_SparkJoyTestDriveRegistry` (one of
  /// `all_good`, `problems`, `not_conducted`). Empty / unknown falls
  /// back to a literal echo so the prompt isn't misleading.
  ///
  /// [subsystemStatus] — map of canonical subsystem keys
  /// (`engine`, `gearbox`, `steering`, `ride`, `brake`) to a
  /// confirmed-ok flag. The flag defaults to `false` in the host
  /// state when the user hasn't visited the subsystem at all, so a
  /// raw `false` cannot be interpreted as «есть замечания» — that
  /// would tell the model the user explicitly diagnosed an issue.
  /// We surface only `true` («без замечаний») as a positive
  /// confirmation; everything else (the default + actual unset)
  /// reads as «не отмечено».
  ///
  /// [subsystemTags] — same keys to a list of selected tag labels for
  /// each subsystem. Empty lists fine.
  static String buildTdCommentCliche({
    required String tdMode,
    required Map<String, bool?> subsystemStatus,
    required Map<String, List<String>> subsystemTags,
  }) {
    String modeLabel(String mode) {
      switch (mode) {
        // Wire-strings come from `_SparkJoyTestDriveRegistry.modeAllGood`
        // etc. — `all_good` / `problems` / `not_conducted`. They live
        // in the spark_joy UI layer; we can't import that here without
        // creating a layering cycle, so the strings are duplicated and
        // a comment links the source-of-truth.
        case 'all_good':
          return 'Тест-драйв проведён, всё работает исправно';
        case 'problems':
          return 'Тест-драйв проведён, обнаружены замечания';
        case 'not_conducted':
          return 'Тест-драйв не проводился';
        default:
          return 'Тест-драйв: статус не указан';
      }
    }

    String subsystemLabel(String key) {
      switch (key) {
        case 'engine':
          return 'Двигатель';
        case 'gearbox':
          return 'Коробка передач';
        case 'steering':
          return 'Рулевое управление';
        case 'ride':
          return 'Подвеска';
        case 'brake':
          return 'Тормоза';
        default:
          return key;
      }
    }

    // Only an explicit `true` confirms «без замечаний». Default-false
    // and missing values are reported as «не отмечено» so the model
    // doesn't misread an unvisited subsystem as a confirmed issue.
    String okLabel(bool? value) {
      if (value == true) return 'без замечаний';
      return 'не отмечено';
    }

    final lines = <String>[];
    for (final entry in subsystemStatus.entries) {
      final tags = subsystemTags[entry.key] ?? const <String>[];
      final tagsPart = tags.isEmpty ? '' : ' — теги: ${tags.join(", ")}';
      lines.add('- ${subsystemLabel(entry.key)}: ${okLabel(entry.value)}$tagsPart');
    }

    return 'Ты эксперт по техническому осмотру автомобилей. Дилер '
        'провёл тест-драйв и зафиксировал такие результаты:\n'
        '${modeLabel(tdMode)}.\n'
        '${lines.isEmpty ? '' : '${lines.join("\n")}\n'}'
        '\n'
        'На основе этих данных и комментария дилера ниже сформулируй '
        'короткий профессиональный текст для отчёта о поведении '
        'автомобиля на ходу. Если есть замечания — опиши их '
        'конкретно и какие риски они несут. Не выдумывай дефекты, '
        'которых нет в данных или комментарии. Возвращай только '
        'готовый текст без преамбулы и markdown.\n'
        '\n'
        'Комментарий дилера: {text}';
  }

}

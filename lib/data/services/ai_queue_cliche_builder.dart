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
    final element = elementLabel.trim().isEmpty ? 'элемент авто' : elementLabel.trim();
    final tagsLine = _formatTags(tags);
    final noteLine = existingNote.trim().isEmpty ? '—' : existingNote.trim();

    return 'Ты эксперт по техническому осмотру автомобилей. '
        'Сформулируй короткое профессиональное замечание на русском по '
        'элементу: $element. '
        'Замечания/теги: $tagsLine. '
        'Текущее описание инспектора: $noteLine. '
        'Если приложены фото — учитывай их визуальную информацию. '
        'Не выдумывай дефекты, которых нет в тегах и фото. '
        'Верни только финальный текст замечания, без преамбулы. '
        'Дополнительный контекст от инспектора: {text}';
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

  static String _formatTags(List<UserTag> tags) {
    if (tags.isEmpty) return 'нет';
    final parts = <String>[];
    for (final tag in tags) {
      final name = tag.name.trim();
      if (name.isEmpty) continue;
      final severity = tag.type == UserTagType.serious ? 'серьёзно' : 'некритично';
      parts.add('$name ($severity)');
    }
    return parts.isEmpty ? 'нет' : parts.join(', ');
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
    final tagsLine = _formatLabelTags(selectedTagLabels, seriousTagLabels);
    final noteLine = existingNote.trim().isEmpty ? '—' : existingNote.trim();
    final paintLine = (paintFrom != null && paintTo != null)
        ? 'Толщина ЛКП: ${paintFrom.round()}-${paintTo.round()} мкм '
            '(норма ~80-200 мкм; больше — возможна перекраска или шпатлёвка). '
        : '';

    return 'Ты эксперт по техническому осмотру автомобилей. '
        'Сформулируй короткое профессиональное замечание на русском по '
        'элементу: $element. '
        'Замечания/теги: $tagsLine. '
        '$paintLine'
        'Текущее описание инспектора: $noteLine. '
        'Если приложены фото — учитывай их визуальную информацию. '
        'Не выдумывай дефекты, которых нет в тегах и фото. '
        'Верни только финальный текст замечания, без преамбулы. '
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
  /// plus per-subsystem yes/no answers and any selected tags so the
  /// model has full context regardless of how short the typed text is.
  ///
  /// [subsystemStatus] — map of canonical subsystem keys
  /// (`engine`, `gearbox`, `steering`, `ride`, `brake`) to ok-flag
  /// (`true` ok / `false` issue / `null` not answered).
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
        case 'allGood':
          return 'Тест-драйв проведён, всё работает исправно';
        case 'hasIssues':
          return 'Тест-драйв проведён, обнаружены замечания';
        case 'notConducted':
          return 'Тест-драйв не проводился';
        default:
          return 'Состояние тест-драйва: $mode';
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

    String okLabel(bool? value) {
      if (value == null) return 'не указано';
      return value ? 'без замечаний' : 'есть замечания';
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

  static String _formatLabelTags(
    List<String> labels,
    Set<String> seriousLabels,
  ) {
    final clean = labels
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (clean.isEmpty) return 'нет';
    final seriousLower = seriousLabels.map((s) => s.toLowerCase()).toSet();
    return clean
        .map((label) {
          final severity = seriousLower.contains(label.toLowerCase())
              ? 'серьёзно'
              : 'некритично';
          return '$label ($severity)';
        })
        .join(', ');
  }
}

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
  static String buildElementClicheFromLabels({
    required String elementLabel,
    required List<String> selectedTagLabels,
    required Set<String> seriousTagLabels,
    String existingNote = '',
  }) {
    final element = elementLabel.trim().isEmpty ? 'элемент авто' : elementLabel.trim();
    final tagsLine = _formatLabelTags(selectedTagLabels, seriousTagLabels);
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

import 'package:flutter_application_1/data/api/storage_api.dart' show UserTag, UserTagType;

/// Builds the `cliche` template string passed to `AiQueue.ChatCompletions`.
///
/// The cliche is a prompt template with a literal `{text}` placeholder
/// that the backend substitutes with the `text` param. We bake every
/// piece of element-specific context (element name, tags with severity,
/// existing note) into the cliche so the model can reason from the full
/// inspection state, while the user-typed note flows through `text`.
///
/// ## Cross-cutting rules
///
/// Every cliché bakes in a small shared set of guardrails — see
/// [_kAudienceTone], [_kAntiHallucination], [_kSeverityCalibration].
/// Together they:
///   • keep responses short & concrete (no «был выполнен анализ…» fluff)
///   • route them to a non-technical reader (the buyer)
///   • prevent the model from inventing facts when input is sparse
///   • calibrate the «серьёзное / некритичное» tag severity into a
///     consistent buy / haggle / refuse axis
class AiQueueClicheBuilder {
  AiQueueClicheBuilder._();

  // ── Shared cross-cutting rules ────────────────────────────────────────

  /// Reader + tone. Identical across all cliché — the recipient of
  /// every piece of AI output is the buyer reading the final report,
  /// so the voice stays the same.
  static const String _kAudienceTone =
      'Читатель — физлицо-покупатель, без технического образования. '
      'Тон деловой, без жаргона ремонтников. Сложные термины кратко '
      'поясняй в скобках. ';

  /// Anti-hallucination floor. Without this the model freely
  /// reconstructs «вероятно был удар в правое крыло» from a single
  /// «царапина» tag. This guardrail forces an explicit «нужна доп.
  /// диагностика» exit when the data isn't enough to be sure.
  static const String _kAntiHallucination =
      'Если данных или фото для уверенного вывода недостаточно — '
      'напиши явно «Требуется дополнительная диагностика» (или у '
      'какого специалиста / на каком этапе). Не реконструируй картину '
      'из общих соображений. Не выдумывай конкретные отзывные '
      'кампании, заводские дефекты или TSB — если факт неточен, '
      'формулируй обобщённо. ';

  /// Severity calibration — used by element + test-drive cliché where
  /// tags carry «серьёзное / некритичное» wire-labels. The model now
  /// has a consistent mapping of those tokens to a
  /// buy-with-haggle-or-refuse axis instead of guessing the impact
  /// each time.
  static const String _kSeverityCalibration =
      'Калибровка серьёзности тегов: '
      '«серьёзное» = блокирует покупку или существенно снижает цену '
      '(требует ремонта, скрытый ущерб, влияет на безопасность). '
      '«Некритичное» = эстетика или нормальный износ, торг возможен, '
      'безопасность не затронута. Расставляй акценты в ответе '
      'соответственно — серьёзные дефекты выходят первыми. ';

  /// Length cap for short single-field comments (element / docs-check /
  /// legal / test-drive). Keep both bounds soft — strict «N words»
  /// fights structured tag listings; «N sentences» is the natural unit.
  static const String _kShortLengthCap =
      'Длина: 2-4 коротких предложения. Без вводных фраз, без '
      'перечисления того, чего НЕ нашли. ';

  /// Coverage honesty rule for aggregated summaries — forbids the
  /// implicit «не упомянуто = ОК» trap. The structured input contains
  /// explicit «Осмотрено без замечаний: …» / «Не осмотрено: …» blocks;
  /// this rule tells the model how to surface them safely.
  static const String _kCoverageHonesty =
      'ВАЖНО про охват осмотра: '
      'Не утверждай исправность элементов, которых нет в '
      'контексте. Если в данных есть блок «Не осмотрено: …» — '
      'обязательно перечисли эти элементы отдельной фразой как '
      'непроверенные (НЕ в позитивном ключе). Если есть блок '
      '«Осмотрено без замечаний: …» — можешь подтвердить их '
      'исправность одной фразой. Не объединяй эти две группы. ';

  // ── Public cliché builders ────────────────────────────────────────────

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

  /// Same as [buildElementCliche] but takes raw tag labels + a set of
  /// labels that the UI considers "serious". Saves callers from
  /// resolving labels → [UserTag] objects when the editor already
  /// carries that data in label form.
  ///
  /// [paintFrom] / [paintTo] — paint thickness range in micrometers
  /// from the толщиномер tool. Both must be non-null to surface in the
  /// prompt; otherwise the line is omitted. Helps the model flag
  /// suspicious values (e.g. 250+ мкм usually means body filler /
  /// repaint).
  ///
  /// [carContext] — pre-formatted brand/model/generation/engine string
  /// (e.g. «Hyundai Solaris, поколение 1, бензин 1.6, АКПП»). Optional;
  /// adds model-aware framing to the answer when present. Caller
  /// builds it from the report state — the cliché doesn't try to
  /// guess the schema.
  static String buildElementClicheFromLabels({
    required String elementLabel,
    required List<String> selectedTagLabels,
    required Set<String> seriousTagLabels,
    String existingNote = '',
    double? paintFrom,
    double? paintTo,
    String? carContext,
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
    final carLine = _carContextBlock(carContext);

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
      final names = cleanLabels.join(', ');
      mustMentionRule =
          'ОБЯЗАТЕЛЬНО упомяни в ответе каждое из этих названий дословно: '
          '$names. ';
    }

    final noteLine = existingNote.trim().isEmpty ? '—' : existingNote.trim();

    return 'Ты эксперт по техническому осмотру автомобилей. '
        'Сформулируй профессиональное замечание на русском по '
        'элементу: $element.\n\n'
        '$carLine'
        '$tagsBlock'
        '$paintLine'
        'Текущее описание инспектора: $noteLine.\n\n'
        '$_kAudienceTone'
        '$_kSeverityCalibration'
        '$_kShortLengthCap'
        '$mustMentionRule'
        '$_kAntiHallucination'
        'Если приложены фото — учитывай их визуальную информацию. '
        'Верни только финальный текст замечания, без преамбулы и markdown. '
        'Дополнительный контекст от инспектора: {text}';
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
        '- Модель двигателя: ${label(engineMatch)}\n\n'
        'На основе этих данных и комментария дилера ниже сформулируй '
        'текст для отчёта о том, что именно не сходится и какие риски '
        'это несёт для покупателя.\n\n'
        '$_kAudienceTone'
        '$_kShortLengthCap'
        '$_kAntiHallucination'
        'Возвращай только готовый текст без преамбулы и markdown.\n\n'
        'Комментарий дилера: {text}';
  }

  /// Cliché for the unified «Итог осмотра» field — replaces the old
  /// двойник `buildSummaryCliche` + factual-facts split. Renders:
  ///   • структурированный вывод по разделам (заголовок + 1-3 фразы),
  ///     разделы — пустой строкой
  ///   • явные блоки «Осмотрено без замечаний» / «Не осмотрено»
  ///     (см. _kCoverageHonesty)
  ///   • обязательный verdict-маркер «РЕКОМЕНДАЦИЯ:» в конце
  ///   • уважает «Предыдущий черновик инспектора» если он есть в
  ///     контексте — сохраняет его правки и стиль
  static String buildReportFactsCliche({
    required String reportLabel,
    String? carContext,
  }) {
    final label = reportLabel.trim().isEmpty
        ? 'Отчёт об осмотре авто'
        : reportLabel.trim();
    final carLine = _carContextBlock(carContext);
    return 'Ты эксперт по тех. осмотру авто. Итог по отчёту "$label" '
        'выведи СТРОГО по шаблону ниже — заголовок раздела + 1-2 '
        'коротких фразы, пустая строка между блоками.\n\n'
        'ШАБЛОН (заголовки дословно, в этом порядке; раздел без данных '
        'пропусти целиком):\n'
        'Кузов:\n\n'
        'Остекление и оптика:\n\n'
        'Подкапотное пространство:\n\n'
        'Салон:\n\n'
        'Колёса и шины:\n\n'
        'Диагностика:\n\n'
        'Тест-драйв:\n\n'
        'Материалы проверки:\n\n'
        'Не осмотрено: <через запятую, если есть>\n\n'
        'РЕКОМЕНДАЦИЯ: <вариант>\n\n'
        'Варианты для РЕКОМЕНДАЦИЯ: '
        '«рекомендуется к покупке» / '
        '«рекомендуется с оговорками — [что именно]» / '
        '«не рекомендуется без устранения [чего]». '
        'После РЕКОМЕНДАЦИЯ ничего не пиши.\n\n'
        'Если в контексте есть «Предыдущий черновик инспектора» — '
        'возьми из него факты и формулировки, но ОБЯЗАТЕЛЬНО '
        'переоформи в шаблон выше с заголовками. Сплошной абзац НЕ '
        'допускается, даже если черновик такой.\n\n'
        '$carLine'
        '$_kAudienceTone'
        '$_kAntiHallucination'
        '$_kCoverageHonesty'
        'Без markdown (никаких **, ##, -/•). Без вступлений. '
        'Начинай сразу с «Кузов:» (или первого непропущенного '
        'заголовка).\n\n'
        'Контекст: {text}';
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
        'Сформулируй текст для блока «Материалы проверки» отчёта. '
        '$filesPart'
        'На основе приложенных документов и комментария инспектора ниже '
        'опиши ключевые моменты: что было проверено, какие риски/'
        'нюансы выявлены, какие действия рекомендуются клиенту.\n\n'
        '$_kAudienceTone'
        '$_kShortLengthCap'
        '$_kAntiHallucination'
        'Возвращай только готовый текст без преамбулы и markdown.\n\n'
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
  /// confirmed-ok flag. Only `true` is treated as positive
  /// confirmation; default-false / null = «не отмечено».
  ///
  /// [subsystemTags] — same keys to a list of selected tag labels for
  /// each subsystem. Empty lists fine.
  static String buildTdCommentCliche({
    required String tdMode,
    required Map<String, bool?> subsystemStatus,
    required Map<String, List<String>> subsystemTags,
    String? carContext,
  }) {
    String modeLabel(String mode) {
      switch (mode) {
        // Wire-strings come from `_SparkJoyTestDriveRegistry.modeAllGood`
        // etc. — `all_good` / `problems` / `not_conducted`.
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

    final carLine = _carContextBlock(carContext);

    return 'Ты эксперт по техническому осмотру автомобилей. Дилер '
        'провёл тест-драйв и зафиксировал такие результаты:\n'
        '${modeLabel(tdMode)}.\n'
        '${lines.isEmpty ? '' : '${lines.join("\n")}\n'}\n'
        '$carLine'
        'На основе этих данных и комментария дилера ниже сформулируй '
        'текст для отчёта о поведении автомобиля на ходу. Если есть '
        'замечания — опиши их конкретно и какие риски они несут. '
        'Если все системы помечены «без замечаний» — кратко подтверди '
        'исправность одной фразой, без перечисления каждой системы. '
        'Если часть систем «не отмечено» — отдельно упомяни, что эти '
        'системы дилер не проверил (это НЕ означает их исправность).\n\n'
        '$_kAudienceTone'
        '$_kSeverityCalibration'
        '$_kShortLengthCap'
        '$_kAntiHallucination'
        'Возвращай только готовый текст без преамбулы и markdown.\n\n'
        'Комментарий дилера: {text}';
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Renders the optional car-context block — empty when no context is
  /// provided so the prompt stays clean. The «не выдумывай конкретные
  /// отзывные…» guardrail lives in [_kAntiHallucination] (always
  /// included in cliché using carContext) — we don't repeat it here.
  static String _carContextBlock(String? carContext) {
    final trimmed = carContext?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    return 'Контекст автомобиля: $trimmed.\n'
        'Используй контекст только для (1) учёта возраста модели при '
        'оценке серьёзности дефектов и (2) сравнения замеров с '
        'разумной нормой для этой модели.\n\n';
  }
}

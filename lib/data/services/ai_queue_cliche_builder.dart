import 'package:flutter_application_1/data/api/storage_api.dart'
    show UserTag, UserTagType;

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
///   • order findings by «серьёзное / некритичное» severity (facts only —
///     the report never advises buy/haggle/refuse; see [_kNoPrescriptions])
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

  static const String _kReportVoice =
      'Пиши как готовый фрагмент отчёта: уверенно, от лица выполненной '
      'проверки, но без фраз от первого лица, без '
      'упоминания ИИ и без обозначения роли автора проверки. ';

  /// Anti-hallucination floor. Without this the model freely
  /// reconstructs «вероятно был удар в правое крыло» from a single
  /// «царапина» tag. This guardrail forces an explicit «данных
  /// недостаточно» exit when the data isn't enough to be sure —
  /// descriptive, without prescribing what the buyer must do.
  static const String _kAntiHallucination =
      'Если данных или фото для уверенного вывода недостаточно — '
      'прямо укажи, что по имеющимся данным однозначный вывод '
      'сделать нельзя, и какие признаки остались непроверенными. '
      'Не реконструируй картину из общих соображений. Не выдумывай '
      'конкретные отзывные кампании, заводские дефекты или TSB — '
      'если факт неточен, формулируй обобщённо. ';

  /// Vehicle context should influence reasoning but should not leak into
  /// every generated sentence. The model may use brand/model/year knowledge
  /// to calibrate typical weak points, but the final text must remain about
  /// the inspected fact unless a vehicle-identification field asks otherwise.
  static const String _kVehicleContextUse =
      'Контекст автомобиля используй как внутреннюю справку: учитывай '
      'возраст, класс, тип кузова/двигателя и типичные слабые места '
      'модели, сопоставляй их только с фактами из отчёта. '
      'Не вставляй марку, модель, поколение или название автомобиля в '
      'ответ без явной необходимости. Не пиши «для данной модели» и не '
      'перечисляй типовые болячки, если эксперт не зафиксировал '
      'связанные признаки. ';

  /// Severity calibration — used by element + test-drive cliché where
  /// tags carry «серьёзное / некритичное» wire-labels. Gives the model a
  /// consistent rule for ORDERING findings by impact (serious first). Does
  /// NOT license buy/repair advice — that's banned by [_kNoPrescriptions].
  static const String _kSeverityCalibration =
      'Калибровка серьёзности тегов: '
      '«серьёзное» = существенный дефект (влияет на безопасность, '
      'скрытый ущерб или требует ремонта). '
      '«Некритичное» = эстетика или нормальный износ, '
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

  /// Facts-only / no-prescription guard. The report states OBSERVED facts;
  /// it must not advise the buyer what to do (buy, haggle, repair, where to
  /// go) nor speculate beyond the recorded data. One carve-out: if the
  /// inspector's own input text already contains a recommendation, keep it
  /// verbatim — never invent new ones. Deliberately bans buyer-advice
  /// SEMANTICALLY (not by word-list), so factual caveats like «требуется
  /// отдельная проверка» for un-inspected items still survive.
  static const String _kNoPrescriptions =
      'Пиши только факты и зафиксированное состояние; ничего не домысливай '
      'и не предполагай сверх данных. Не давай покупателю советов и не '
      'предписывай действий — не пиши, покупать ли авто, торговаться, '
      'ремонтировать или куда-то обращаться. Оценку рисков давай нейтрально, '
      'без призыва к действию. Исключение: если рекомендация уже есть в '
      'исходном тексте ниже — сохрани её как есть, но своих не добавляй. ';

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
    final element = elementLabel.trim().isEmpty
        ? 'элемент авто'
        : elementLabel.trim();
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
      final bullets = cleanLabels
          .map((label) {
            final severity = seriousLower.contains(label.toLowerCase())
                ? 'серьёзное'
                : 'некритичное';
            return '- $label ($severity)';
          })
          .join('\n');
      tagsBlock =
          'В данных осмотра указаны следующие повреждения / замечания (НЕ ИЗМЕНЯЙ названия):\n'
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
        'Исходное описание: $noteLine.\n\n'
        '$_kAudienceTone'
        '$_kReportVoice'
        '$_kVehicleContextUse'
        '$_kSeverityCalibration'
        '$_kShortLengthCap'
        '$mustMentionRule'
        '$_kAntiHallucination'
        '$_kNoPrescriptions'
        'Если приложены фото — учитывай их визуальную информацию. '
        'Верни только финальный текст замечания, без преамбулы и markdown. '
        'Дополнительный контекст: {text}';
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

    return 'Ты эксперт по техническому осмотру авто. В сверке документов '
        'зафиксированы такие результаты:\n'
        '- Данные владельца: ${label(ownerMatch)}\n'
        '- Идентификационные номера (VIN): ${label(vinMatch)}\n'
        '- Модель двигателя: ${label(engineMatch)}\n\n'
        'На основе этих данных и исходного комментария ниже сформулируй '
        'текст для отчёта о том, что именно не сходится — только факты, '
        'без домыслов о причинах.\n\n'
        '$_kAudienceTone'
        '$_kReportVoice'
        '$_kShortLengthCap'
        '$_kAntiHallucination'
        '$_kNoPrescriptions'
        'Возвращай только готовый текст без преамбулы и markdown.\n\n'
        'Исходный комментарий: {text}';
  }

  /// Cliché для вывода тех. параметров авто по VIN. В ОТЛИЧИЕ от остальных
  /// билдеров здесь нужен СТРОГО JSON (не проза для покупателя) — это первый
  /// структурированный AI-вывод в приложении: ответ парсится кодом
  /// (`parseVinParamsAiResult`), пользователю не показывается. [vin] +
  /// [carContext] + [wmiInfo] запекаются как грунтовка — модель выводит
  /// параметры для ИЗВЕСТНОЙ машины, а не вслепую из сырого VIN.
  /// Переиспользует [_kAntiHallucination]: неизвестные поля приходят `""`
  /// вместо догадок. Enum перечислен дословно (дропдаун примет только
  /// точную строку).
  static String buildVinParamsCliche({
    required String vin,
    String? carContext,
    String? wmiInfo,
  }) {
    final carLine = (carContext == null || carContext.trim().isEmpty)
        ? ''
        : 'Известный автомобиль: ${carContext.trim()}.\n';
    final wmiLine = (wmiInfo == null || wmiInfo.trim().isEmpty)
        ? ''
        : 'Данные WMI-декода VIN: ${wmiInfo.trim()}.\n';
    return 'Ты эксперт по идентификации автомобилей. По VIN и известным '
        'данным определи технические параметры автомобиля.\n'
        'VIN: $vin.\n'
        '$carLine'
        '$wmiLine'
        '\n'
        'Верни СТРОГО один JSON-объект и НИЧЕГО больше — без markdown, без '
        '```, без пояснений до или после. Ключи и допустимые значения:\n'
        '{\n'
        '  "engineVolume": число в литрах с одним знаком после точки '
        '(например 1.6) или "" если неизвестно,\n'
        '  "engineType": ОДНО из ["Бензин","Дизель","Гибрид","Электро",'
        '"Газ/Бензин"] или "",\n'
        '  "transmission": ОДНО из ["АКПП","МКПП","Робот","Вариатор"] или "",\n'
        '  "driveType": ОДНО из ["Передний","Задний","Полный"] или ""\n'
        '}\n'
        'Enum-поля пиши ДОСЛОВНО как в списках выше (та же раскладка и '
        'регистр), иначе они не будут приняты. Для электромобиля объём '
        'двигателя неприменим — верни "". '
        '$_kAntiHallucination'
        'Если по VIN нельзя однозначно определить поле — ставь "", не '
        'угадывай. Ответ — только JSON-объект. Контекст: {text}';
  }

  /// Cliché распознавания фото СТС (осн. кейс), ПТС/ЭПТС (vision: фото уходит
  /// через `files`). Явно называет тип документа и что извлекать + маппинг
  /// подписей полей СТС → ключи JSON (заметно точнее на реальном бланке).
  /// Контракт вывода — строгий JSON, поля зеркалят `parseDocScanAiResult`
  /// (spark_joy_doc_scan_ai.dart): парсер строже промпта, всё сомнительное
  /// отбрасывает. Ключевой гард — «только текст с фото»: модель НЕ достраивает
  /// параметры по знанию модели авто (для этого отдельный buildVinParamsCliche).
  static String buildDocScanCliche() {
    return 'Ты распознаёшь российское СТС — свидетельство о регистрации '
        'транспортного средства (розовая двусторонняя карточка с подписанными '
        'полями); реже это ПТС (паспорт ТС) или выписка ЭПТС. На приложенном '
        'фото — такой документ. Прочитай ТОЛЬКО то, что реально напечатано на '
        'фото, и извлеки поля ниже.\n'
        '\n'
        'Нужно распознать РОВНО 6 полей. В СТС они подписаны — сопоставь '
        'подписи документа с ключами JSON:\n'
        '- «Регистрационный знак» (госномер) → gosNumber (русскими буквами '
        'КАК В ДОКУМЕНТЕ, НЕ транслитерируй в латиницу: «К254ТМ797», не '
        '«K254TM797»; различай букву О и цифру 0 — в «В016ОО123» после 016 '
        'идут БУКВЫ О, не нули)\n'
        '- «Идентификационный номер (VIN)» → vin\n'
        '- «Марка, модель ТС» → раздели на brand (марка) и model (модель)\n'
        '- «Год выпуска ТС» → year\n'
        '- «Цвет» → color\n'
        '\n'
        'Верни СТРОГО один JSON-объект и НИЧЕГО больше — без markdown, без '
        '```, без пояснений до или после. Ключи и значения:\n'
        '{\n'
        '  "docType": ОДНО из ["sts","pts","epts","unknown"],\n'
        '  "gosNumber": регистрационный знак как в документе (например '
        '"А123ВС77") или "",\n'
        '  "vin": ровно 17 символов (латинские буквы/цифры, букв I, O, Q в '
        'VIN не бывает — перепроверь посимвольно) или "",\n'
        '  "brand": марка или "",\n'
        '  "model": модель (коммерческое обозначение) или "",\n'
        '  "year": год изготовления числом или "",\n'
        '  "color": цвет кузова из документа или ""\n'
        '}\n'
        'Поле не читается, обрезано или в документе отсутствует → "". НЕ '
        'угадывай и НЕ дополняй по общим знаниям об этой модели авто — только '
        'текст с фото. Другие поля (объём/тип двигателя и т.п.) НЕ добавляй. '
        'Если на фото не документ ТС — верни все поля пустыми и '
        '"docType": "unknown". {text}';
  }

  /// Cliché for the unified «Итог осмотра» field — replaces the old
  /// двойник `buildSummaryCliche` + factual-facts split. Renders:
  ///   • ведущий абзац «Общая оценка состояния» — целостный СИНТЕЗ всех
  ///     данных (идентификация/параметры/осмотр/тест-драйв/юр-проверки), затем
  ///   • факты по разделам (заголовок + 1-3 фразы), разделы — пустой строкой
  ///   • явные блоки «Осмотрено без замечаний» / «Не осмотрено»
  ///     (см. _kCoverageHonesty)
  ///   • без вердикта «купить / не купить» — только описание состояния
  ///   • уважает «Предыдущий черновик» если он есть в
  ///     контексте — сохраняет его правки и стиль
  static String buildReportFactsCliche({
    required String reportLabel,
    String? carContext,
  }) {
    final label = reportLabel.trim().isEmpty
        ? 'Отчёт об осмотре авто'
        : reportLabel.trim();
    final carLine = _carContextBlock(carContext);
    return 'Ты эксперт по тех. осмотру авто. Составь ЕДИНУЮ итоговую сводку '
        'по отчёту "$label" — связный текст, который оценивает и сводит '
        'воедино ВСЕ доступные в контексте данные об автомобиле. Это не '
        'пересказ по одному элементу, а целостная картина состояния. Это '
        'СИНТЕЗ уже зафиксированных ФАКТОВ: переформулируй и объедини то, что '
        'есть в контексте, ничего не добавляя сверх данных.\n\n'
        'СТРУКТУРА ответа — ровно две части, между ними пустая строка.\n\n'
        'Часть 1 — «Общая оценка состояния»: 3-6 связных предложений одним '
        'абзацем, которые сводят воедино идентификацию и сверку (что за '
        'автомобиль по данным отчёта, VIN, госномер, пробег, число '
        'владельцев, соответствие документам), общее состояние осмотренных '
        'зон, итог тест-драйва, результаты юридических проверок и материалов, '
        'и охват осмотра. Сначала наиболее значимое (существенные дефекты, '
        'расхождения при сверке, находки по юр-проверкам), затем общее '
        'впечатление по остальным данным. В ЭТОЙ части уместно один раз '
        'назвать осматриваемый автомобиль и привести VIN, госномер, пробег и '
        'ключевые параметры, если они есть в контексте. Связывай родственные '
        'факты из разных зон в общий вывод о состоянии, но не выдумывай того, '
        'чего в контексте нет.\n\n'
        'Часть 2 — факты по разделам. Заголовки дословно и в этом порядке; '
        'раздел без данных пропусти целиком; под каждым заголовком 1-3 '
        'коротких фразы строго по фактам, пустая строка между блоками:\n'
        'Идентификация и параметры:\n\n'
        'Кузов:\n\n'
        'Остекление и оптика:\n\n'
        'Подкапотное пространство:\n\n'
        'Салон:\n\n'
        'Колёса и шины:\n\n'
        'Диагностика:\n\n'
        'Тест-драйв:\n\n'
        'Юридические проверки и материалы:\n\n'
        'Не осмотрено: <через запятую, если есть>\n\n'
        'Часть 2 раскрывает факты, упомянутые в Части 1; не противоречь '
        'самому себе, не дублируй один и тот же факт многократно и не '
        'выдумывай данные, которых нет в контексте. Не ограничивайся одним '
        'элементом или разделом — охвати все области, по которым есть '
        'данные.\n\n'
        'Если в контексте есть «Предыдущий черновик» — возьми из него факты, '
        'формулировки и ручные правки, но ОБЯЗАТЕЛЬНО переоформи под '
        'структуру выше (ведущая «Общая оценка состояния» + разделы). '
        'Устаревший пересказ по одному элементу или сплошной абзац без '
        'ведущей оценки не сохраняй.\n\n'
        '$carLine'
        '$_kAudienceTone'
        '$_kReportVoice'
        '$_kVehicleContextUse'
        '$_kAntiHallucination'
        '$_kNoPrescriptions'
        '$_kCoverageHonesty'
        'Без markdown (никаких **, ##, -/•) и без нумерованных списков в '
        'самом ответе. Без вступлений и без слов о том, что это сводка или '
        'анализ. Начинай сразу с «Общая оценка состояния».\n\n'
        'Контекст: {text}';
  }

  /// Cliché for the «Комментарий специалиста» field on the «Материалы
  /// проверки» step. Bakes in the FACTUAL ApiCloud check results
  /// ([checksInfo]) so the model summarises what was checked + the outcomes.
  /// The attached documents' CONTENT is not available to the model, so their
  /// names/count are deliberately NOT passed (knowing «ПТС.pdf ×2» without
  /// content is useless and only invites hallucination) — the prompt tells
  /// the model not to reference the documents at all. Inspector text → {text}.
  static String buildLegalCommentCliche({String checksInfo = ''}) {
    final checksPart = checksInfo.trim().isEmpty
        ? ''
        : 'Факты выполненных проверок:\n${checksInfo.trim()}\n';
    return 'Ты редактор отчёта об автомобиле. '
        'Сформулируй краткий текст для блока «Материалы проверки».\n'
        '$checksPart'
        'Используй ТОЛЬКО факты, дословно переданные выше, и содержательный '
        'исходный комментарий ниже. Назови только реально выполненные проверки '
        'и их результаты. Не называй поставщика данных, внутренние сервисы или '
        'автоматический способ проверки. Не упоминай приложенные документы и их '
        'содержимое — оно недоступно. Не добавляй отсутствующие сведения — '
        'даже в виде оговорок о том, что они не подтверждены или не проверены. '
        'Не делай общих выводов за пределами переданных фактов. '
        'Длина: 1-3 коротких предложения.\n\n'
        '$_kAudienceTone'
        '$_kReportVoice'
        '$_kNoPrescriptions'
        'Возвращай только готовый текст без преамбулы и markdown.\n\n'
        'Исходный комментарий: {text}';
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
      lines.add(
        '- ${subsystemLabel(entry.key)}: ${okLabel(entry.value)}$tagsPart',
      );
    }

    final carLine = _carContextBlock(carContext);

    return 'Ты эксперт по техническому осмотру автомобилей. По тест-драйву '
        'зафиксированы такие результаты:\n'
        '${modeLabel(tdMode)}.\n'
        '${lines.isEmpty ? '' : '${lines.join("\n")}\n'}\n'
        '$carLine'
        'На основе этих данных и исходного комментария ниже сформулируй '
        'текст для отчёта о поведении автомобиля на ходу. Если есть '
        'замечания — опиши их конкретно, только факты. '
        'Если все системы помечены «без замечаний» — кратко подтверди '
        'исправность одной фразой, без перечисления каждой системы. '
        'Если часть систем «не отмечено» — отдельно упомяни, что эти '
        'системы не проверены (это НЕ означает их исправность).\n\n'
        '$_kAudienceTone'
        '$_kReportVoice'
        '$_kVehicleContextUse'
        '$_kSeverityCalibration'
        '$_kShortLengthCap'
        '$_kAntiHallucination'
        '$_kNoPrescriptions'
        'Возвращай только готовый текст без преамбулы и markdown.\n\n'
        'Исходный комментарий: {text}';
  }

  /// Клише ИИ-раскладки интейка «Фото автомобиля»: пачка изображений →
  /// {"items":[{hash, section, documentKind, group, element}]}. Таксономию
  /// (группы
  /// осмотра с элементами) передаёт вызывающий — реестры групп/элементов
  /// приватны для библиотеки экрана отчёта, а клише должен точно совпадать
  /// с тем, что умеет принять applier.
  ///
  /// hash каждого изображения дан в тексте запроса подписью
  /// «изображение N: hash=...» — модель обязана вернуть его ДОСЛОВНО,
  /// это ключ сопоставления вердикта с локальным оригиналом фото.
  static String buildIntakeDistributionCliche({
    required List<
      ({String key, String title, List<({String id, String label})> elements})
    >
    inspectionGroups,
  }) {
    final taxonomy = StringBuffer();
    for (final group in inspectionGroups) {
      taxonomy.write('- group "${group.key}" (${group.title}); element: ');
      taxonomy.write(
        group.elements.map((e) => '"${e.id}" (${e.label})').join(', '),
      );
      taxonomy.write('\n');
    }
    return 'Ты сортируешь фотографии для отчёта об осмотре подержанного '
        'автомобиля. К сообщению приложено несколько фотографий; в тексте '
        'запроса для каждой дана подпись вида «изображение N: hash=...» — '
        'подписи идут В ТОМ ЖЕ ПОРЯДКЕ, что и приложенные изображения '
        '(изображение 1 = первое приложенное фото и т.д.).\n'
        '\n'
        'В отчёте существуют ТОЛЬКО четыре смысловых раздела:\n'
        '1. «Материалы проверки» — документы и бумаги.\n'
        '2. «Автомобиль» — VIN, госномер, марка, модель, год и цвет из СТС/ПТС.\n'
        '3. «Параметры» — характеристики, которые затем уточняются по VIN.\n'
        '4. «Осмотр» — фотографии автомобиля по группам и элементам ниже.\n'
        'Не используй и не придумывай другие разделы.\n'
        '\n'
        'Для КАЖДОГО изображения определи, куда положить ОРИГИНАЛ:\n'
        '- section="inspection" — фото автомобиля или его части (кузов снаружи, '
        'салон, подкапотное пространство, колёса, стёкла, оптика, экран '
        'диагностического сканера/приборной панели). Обязательно укажи '
        'group и element из списка ниже.\n'
        '- section="materials", documentKind="vehicle_doc" — СТС, ПТС или '
        'выписка ЭПТС. Оригинал идёт в «Материалы проверки», а данные из него '
        'отдельно заполнят «Автомобиль» и «Параметры».\n'
        '- section="materials", documentKind="document" — любой другой '
        'документ или бумага (карта, отчёт, договор, чек, распечатка).\n'
        '- section="unknown" — назначение нельзя определить уверенно.\n'
        '\n'
        'Группы и элементы осмотра (для section="inspection"; используй '
        'ТОЛЬКО эти идентификаторы, ничего не выдумывай):\n'
        '$taxonomy'
        '\n'
        'Если группа ясна, а конкретный элемент — нет, используй '
        'element="..._general" (общее состояние) этой группы. Если и группа '
        'не ясна — category="unknown".\n'
        '\n'
        'Верни СТРОГО один JSON-объект и НИЧЕГО больше — без markdown, без '
        '```, без пояснений:\n'
        '{"items":[{"hash":"<hash из подписи, ДОСЛОВНО>",'
        '"section":"inspection|materials|unknown",'
        '"documentKind":"vehicle_doc|document|",'
        '"group":"<ключ группы или пустая строка>",'
        '"element":"<ключ элемента или пустая строка>"}]}\n'
        'В items должен быть РОВНО один объект на каждое приложенное '
        'изображение, hash не искажай и не сокращай. {text}';
  }

  /// Кадры одного видео → один вердикт для hash исходного видео. Кадры
  /// передаются равномерно по времени и являются лишь доказательствами;
  /// раскладывается оригинальный видеофайл целиком.
  static String buildIntakeVideoDistributionCliche({
    required List<
      ({String key, String title, List<({String id, String label})> elements})
    >
    inspectionGroups,
  }) {
    final taxonomy = StringBuffer();
    for (final group in inspectionGroups) {
      taxonomy.write('- group "${group.key}" (${group.title}); element: ');
      taxonomy.write(
        group.elements.map((e) => '"${e.id}" (${e.label})').join(', '),
      );
      taxonomy.write('\n');
    }
    return 'Ты сортируешь ОДИН видеофайл для отчёта об осмотре подержанного '
        'автомобиля. К сообщению приложены равномерно выбранные кадры одного '
        'видео в хронологическом порядке. В тексте указан hash ОРИГИНАЛЬНОГО '
        'видео и время каждого кадра. Определи одно главное назначение всего '
        'видеофайла по совокупности кадров, а не отдельное назначение кадров.\n\n'
        'Допустимые назначения:\n'
        '- section="inspection" — видео автомобиля или его части; обязательно '
        'выбери group и element только из списка ниже. Если видео показывает '
        'несколько частей, выбери доминирующую по времени и содержанию.\n'
        '- section="materials", documentKind="vehicle_doc" — видео СТС, ПТС '
        'или выписки ЭПТС.\n'
        '- section="materials", documentKind="document" — видео другого '
        'документа или бумаги.\n'
        '- section="unknown" — уверенно определить назначение нельзя.\n\n'
        'Группы и элементы осмотра:\n$taxonomy\n'
        'Верни СТРОГО один JSON-объект без markdown и пояснений:\n'
        '{"items":[{"hash":"<hash исходного видео, ДОСЛОВНО>",'
        '"section":"inspection|materials|unknown",'
        '"documentKind":"vehicle_doc|document|",'
        '"group":"<ключ группы или пустая строка>",'
        '"element":"<ключ элемента или пустая строка>"}]}\n'
        'В items должен быть РОВНО один объект. {text}';
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
        'Используй этот контекст только для внутренней оценки: возраст, '
        'класс, конструкция, возможные типовые слабые места и разумные '
        'нормы замеров. В финальном тексте не называй автомобиль, марку, '
        'модель или поколение, если пользовательский раздел не просит '
        'идентифицировать машину.\n\n';
  }
}

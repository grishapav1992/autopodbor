/// Сервис-обёртка над [AiQueueApi] для Spark Joy editor'а.
///
/// Отвечает за:
///   • Генерацию и хранение `chatId` per element / per summary.
///   • Сборку cliche-шаблонов (per-element / summary).
///   • Сборку summary-context из historiy всех per-element чатов.
///
/// chatId хранятся в structured-map'е, которая привязывается к draft'у:
/// см. `aiQueueChats` поле в storage_helpers (добавлено отдельно).
///
/// Все методы — асинхронные. UI должен показывать spinner.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/api/ai_queue_api.dart';

/// Идентификатор «о чём говорим» — одна сущность, по которой идёт
/// диалог. Может быть конкретным элементом осмотра, заметкой
/// тест-драйва, шагом «документы», или summary всего отчёта.
@immutable
class AiAssistantTarget {
  const AiAssistantTarget._({
    required this.kind,
    required this.elementKey,
    required this.elementLabel,
    required this.sectionLabel,
    required this.tags,
  });

  /// Per-element осмотра (`groupKey/itemIndex` оборачиваем в строку).
  factory AiAssistantTarget.inspectionElement({
    required String groupKey,
    required int itemIndex,
    required String elementLabel,
    required String sectionLabel,
    List<String> tags = const <String>[],
  }) {
    return AiAssistantTarget._(
      kind: 'inspection_element',
      elementKey: 'inspection.$groupKey.$itemIndex',
      elementLabel: elementLabel,
      sectionLabel: sectionLabel,
      tags: tags,
    );
  }

  /// Per-step заметка (документы / юр. проверка / тест-драйв / итог).
  factory AiAssistantTarget.step({
    required String stepId,
    required String stepLabel,
    List<String> tags = const <String>[],
  }) {
    return AiAssistantTarget._(
      kind: 'step',
      elementKey: 'step.$stepId',
      elementLabel: stepLabel,
      sectionLabel: stepLabel,
      tags: tags,
    );
  }

  /// Summary всего отчёта.
  factory AiAssistantTarget.summary() {
    return const AiAssistantTarget._(
      kind: 'summary',
      elementKey: '__final__',
      elementLabel: 'Итоговое заключение',
      sectionLabel: 'Отчёт',
      tags: <String>[],
    );
  }

  /// `'inspection_element' | 'step' | 'summary'` — определяет
  /// какой cliche-шаблон применять.
  final String kind;

  /// Стабильный ключ внутри draft'а (используется как поле в
  /// `aiQueueChats` мапе). Никогда не должен пересекаться между
  /// разными элементами.
  final String elementKey;

  final String elementLabel;
  final String sectionLabel;

  /// Уже отмеченные пользователем теги замечаний — они подставляются
  /// в cliche чтобы AI учёл контекст.
  final List<String> tags;
}

/// Клиентское состояние одного диалога с AI-помощником.
@immutable
class AiAssistantDialogState {
  const AiAssistantDialogState({
    required this.chatId,
    required this.history,
    required this.lastResultText,
  });

  final int chatId;
  final List<AiQueueChatMessage> history;
  final String lastResultText;
}

class SparkJoyAiAssistantService {
  SparkJoyAiAssistantService._();
  static final SparkJoyAiAssistantService instance =
      SparkJoyAiAssistantService._();

  // ── chatId management ─────────────────────────────────────────────

  /// Берёт сохранённый chatId из [chatsMap] для данной [target] или
  /// генерирует новый и записывает в [chatsMap]. [chatsMap] —
  /// reference на `draft['aiQueueChats']`, мутируется in-place.
  int chatIdFor({
    required AiAssistantTarget target,
    required Map<String, dynamic> chatsMap,
  }) {
    final existing = chatsMap[target.elementKey];
    if (existing is int && existing > 0) return existing;
    if (existing is num) {
      final asInt = existing.toInt();
      if (asInt > 0) {
        chatsMap[target.elementKey] = asInt;
        return asInt;
      }
    }
    if (existing is String) {
      final parsed = int.tryParse(existing);
      if (parsed != null && parsed > 0) {
        chatsMap[target.elementKey] = parsed;
        return parsed;
      }
    }
    final fresh = _generateChatId();
    chatsMap[target.elementKey] = fresh;
    return fresh;
  }

  /// Принудительно открывает новый chat (сбрасывает историю на
  /// сервере + перегенерирует id). Полезно для «Сбросить помощника».
  Future<int> resetChat({
    required AiAssistantTarget target,
    required Map<String, dynamic> chatsMap,
  }) async {
    final old = chatsMap[target.elementKey];
    final oldId = old is int ? old : (old is num ? old.toInt() : -1);
    if (oldId > 0) {
      try {
        await AiQueueApi.clearChatHistory(oldId);
      } on AiQueueException catch (e) {
        debugPrint('[ai-assistant] clearChatHistory failed: ${e.diagnosticMessage}');
      }
    }
    final fresh = _generateChatId();
    chatsMap[target.elementKey] = fresh;
    return fresh;
  }

  /// Унифицированный генератор chatId. Микросекунды от epoch — на
  /// одном устройстве без коллизий, на разных пользователях scope
  /// серверный (NATS KV per userId).
  int _generateChatId() {
    return DateTime.now().microsecondsSinceEpoch;
  }

  // ── Cliche templates ──────────────────────────────────────────────

  /// Возвращает cliche-строку для given [target] с подставленными
  /// контекстом. Плейсхолдер `{text}` оставляется на сервер — он
  /// сам подставит `params.text` пользователя.
  String buildCliche(AiAssistantTarget target) {
    switch (target.kind) {
      case 'inspection_element':
        return _inspectionElementCliche(target);
      case 'step':
        return _stepCliche(target);
      case 'summary':
        return _summaryCliche();
      default:
        return _inspectionElementCliche(target);
    }
  }

  String _inspectionElementCliche(AiAssistantTarget t) {
    final tagsLine =
        t.tags.isEmpty ? 'не отмечены' : '«${t.tags.join('», «')}»';
    return '''
Ты — помощник автоподборщика. Сформулируй короткое (одно-два предложения) техническое замечание по элементу осмотра.

Раздел: ${t.sectionLabel}
Элемент: ${t.elementLabel}
Уже отмеченные теги: $tagsLine.

Сырая заметка специалиста: {text}.

Требования к ответу:
— нейтральный, профессиональный тон;
— без воды и эмоций;
— если в заметке есть числа (размер вмятины, толщина ЛКП) — сохрани их;
— если в заметке противоречит тегам — отметь это явно.
''';
  }

  String _stepCliche(AiAssistantTarget t) {
    return '''
Ты — помощник автоподборщика. Сформулируй заметку для шага отчёта «${t.stepLabel}».

Сырая заметка специалиста: {text}.

Требования:
— одно-два предложения;
— нейтральный, профессиональный тон;
— сохрани конкретные факты (даты, имена, реквизиты).
''';
  }

  String _summaryCliche() {
    return '''
Ты — автомобильный эксперт. Собери итоговое заключение по отчёту осмотра.

Структура:
— по разделам (Кузов / Двигатель / Тех. состояние / Юр. чистота);
— в каждом разделе — короткие выводы (одно предложение);
— в финале — общая рекомендация: «Покупать», «Покупать с торгом», «Не покупать» + краткое обоснование (одно предложение).

Тон официальный, без воды. Заметки специалиста ниже:

{text}
''';
  }

  // ── ChatCompletions wrappers ──────────────────────────────────────

  /// Per-element / per-step запрос. Возвращает текст ответа.
  /// Бросает [AiQueueException] / [Exception] при сбоях — UI решает
  /// что показать.
  Future<String> formalize({
    required AiAssistantTarget target,
    required String userText,
    required Map<String, dynamic> chatsMap,
    List<String>? fileUrls,
    String? model,
  }) async {
    if (userText.trim().isEmpty) {
      throw const AiQueueException(
        userMessage: 'Введите хотя бы пару слов — без них AI не сформулирует заметку.',
        diagnosticMessage: 'empty user text',
        code: 'empty_input',
      );
    }
    final chatId = chatIdFor(target: target, chatsMap: chatsMap);
    final cliche = buildCliche(target);
    final result = await AiQueueApi.chatCompletions(
      chatId: chatId,
      text: userText.trim(),
      cliche: cliche,
      fileUrls: fileUrls,
      model: model,
    );
    return result.text;
  }

  // ── Summary helpers ───────────────────────────────────────────────

  /// Подтягивает истории всех per-element чатов из draft'а и собирает
  /// плоский context-string. ChatId'ы у которых TTL истёк (отсутствуют
  /// в ответе сервера) — попросту пропускаются.
  ///
  /// `chatsMap` — `draft['aiQueueChats']`. Не мутирует.
  Future<String> buildSummaryContext({
    required Map<String, dynamic> chatsMap,
  }) async {
    final entries = <_ContextEntry>[];
    final ids = <int>[];
    chatsMap.forEach((key, value) {
      if (key == '__final__') return; // summary chat сам себя не включает
      final id = value is int
          ? value
          : (value is num ? value.toInt() : int.tryParse('$value'));
      if (id == null || id <= 0) return;
      ids.add(id);
      entries.add(_ContextEntry(key: key, chatId: id));
    });
    if (ids.isEmpty) return '';

    final histories = await AiQueueApi.getChatHistories(ids);
    final buf = StringBuffer();
    for (final entry in entries) {
      final history = histories[entry.chatId];
      if (history == null || history.isEmpty) continue;
      // Берём только последний assistant-turn — там итоговая
      // отформатированная заметка по этому элементу. Остальные turns
      // (юзерская заметка, уточнения) — шум для summary.
      String? lastAssistant;
      for (final m in history.messages.reversed) {
        if (m.role == 'assistant' && m.content.trim().isNotEmpty) {
          lastAssistant = m.content.trim();
          break;
        }
      }
      if (lastAssistant == null) continue;
      buf.writeln('## ${_humanLabelFor(entry.key)}');
      buf.writeln(lastAssistant);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  /// Запускает summary-чат с собранным контекстом.
  Future<String> generateSummary({
    required String context,
    required Map<String, dynamic> chatsMap,
    String? model,
  }) async {
    if (context.trim().isEmpty) {
      throw const AiQueueException(
        userMessage:
            'В отчёте нет сформулированных заметок — добавьте их через AI-помощник перед итоговым заключением.',
        diagnosticMessage: 'empty summary context',
        code: 'empty_context',
      );
    }
    final summaryTarget = AiAssistantTarget.summary();
    // Для summary всегда новый чат — старый id не реюзаем, чтобы
    // не наследовать подвисшую историю.
    final freshId = await resetChat(
      target: summaryTarget,
      chatsMap: chatsMap,
    );
    final cliche = buildCliche(summaryTarget);
    final result = await AiQueueApi.chatCompletions(
      chatId: freshId,
      text: context,
      cliche: cliche,
      model: model,
    );
    return result.text;
  }

  /// Превращает технический ключ `inspection.body.0` в
  /// «Кузов · элемент 1». Используется только для составления
  /// summary-контекста — в будущем можно мапить на реальные имена
  /// элементов из реестра.
  String _humanLabelFor(String key) {
    if (!key.startsWith('inspection.')) return key;
    final parts = key.split('.');
    if (parts.length < 3) return key;
    final group = parts[1];
    final idx = int.tryParse(parts[2]);
    final groupLabel = _inspectionGroupLabels[group] ?? group;
    return idx == null ? groupLabel : '$groupLabel · элемент ${idx + 1}';
  }

  static const Map<String, String> _inspectionGroupLabels = {
    'body': 'Кузов',
    'body_reinforcement': 'Усиление кузова',
    'glass': 'Стёкла',
    'interior': 'Салон',
    'under_hood': 'Подкапотное',
    'wheels_and_brakes': 'Колёса и тормоза',
    'lightning': 'Светотехника',
    'computer_diagnostics': 'Компьютерная диагностика',
  };
}

extension _StepCliche on AiAssistantTarget {
  String get stepLabel => sectionLabel;
}

class _ContextEntry {
  const _ContextEntry({required this.key, required this.chatId});
  final String key;
  final int chatId;
}

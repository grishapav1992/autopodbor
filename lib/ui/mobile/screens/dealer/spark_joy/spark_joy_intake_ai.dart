import 'spark_joy_vin_params_ai.dart' show extractJsonObject;

/// ИИ-раскладка интейка «Фото автомобиля»: назначения вердикта и парсер
/// ответа модели. Чистый top-level код без Flutter-зависимостей — импортится
/// и сервисом, и юнит-тестами (как spark_joy_doc_scan_ai.dart).
///
/// Контракт с моделью: на входе пачка изображений + текст с подписями
/// «изображение N: hash=...»; на выходе СТРОГО JSON
/// `{"items":[{"hash":"...","section":"...","documentKind":"...",`
/// `"group":"...","element":"..."}]}`.
/// hash — ключ сопоставления вердикта с ЛОКАЛЬНЫМ оригиналом (sha256
/// оригинальных байт; в S3 уезжает сжатая копия, поэтому серверное имя
/// файла оригинал не идентифицирует).
abstract final class SparkIntakeAiSection {
  /// Фото автомобиля/его части → «Осмотр», group+element обязательны.
  static const String inspection = 'inspection';

  /// Любой документ → «Материалы проверки». СТС/ПТС дополнительно заполняет
  /// поля автомобиля и параметров, но оригинал всё равно хранится здесь.
  static const String materials = 'materials';

  /// Не удалось классифицировать — остаётся в интейке.
  static const String unknown = 'unknown';

  static const Set<String> all = {inspection, materials, unknown};
}

abstract final class SparkIntakeDocumentKind {
  static const String vehicleDoc = 'vehicle_doc';
  static const String document = 'document';
  static const String none = '';
  static const Set<String> all = {vehicleDoc, document, none};
}

typedef SparkIntakeAiVerdict = ({
  String hash,
  String section,
  String documentKind,
  String group,
  String element,
});

/// Разбирает ответ модели. Толерантен к прозе вокруг JSON (extractJsonObject
/// берёт первый сбалансированный объект), к мусорным элементам массива и к
/// неизвестным категориям (→ unknown). Никогда не бросает; при полном
/// провале — пустой список (батч уйдёт в ретрай/unknown на стороне сервиса).
List<SparkIntakeAiVerdict> parseIntakeDistributionResult(String modelText) {
  final obj = extractJsonObject(modelText);
  if (obj == null) return const [];
  final rawItems = obj['items'];
  if (rawItems is! List) return const [];
  final verdicts = <SparkIntakeAiVerdict>[];
  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final hash = raw['hash']?.toString().trim().toLowerCase() ?? '';
    if (hash.isEmpty) continue;
    var section = raw['section']?.toString().trim().toLowerCase() ?? '';
    var documentKind =
        raw['documentKind']?.toString().trim().toLowerCase() ?? '';
    // Совместимость с результатами незавершённой первой версии клише.
    final legacyCategory =
        raw['category']?.toString().trim().toLowerCase() ?? '';
    if (section.isEmpty) {
      switch (legacyCategory) {
        case 'inspection':
          section = SparkIntakeAiSection.inspection;
        case 'vehicle_doc':
          section = SparkIntakeAiSection.materials;
          documentKind = SparkIntakeDocumentKind.vehicleDoc;
        case 'document':
          section = SparkIntakeAiSection.materials;
          documentKind = SparkIntakeDocumentKind.document;
        default:
          section = SparkIntakeAiSection.unknown;
      }
    }
    if (!SparkIntakeAiSection.all.contains(section)) {
      section = SparkIntakeAiSection.unknown;
    }
    if (!SparkIntakeDocumentKind.all.contains(documentKind)) {
      documentKind = SparkIntakeDocumentKind.none;
    }
    var group = raw['group']?.toString().trim() ?? '';
    var element = raw['element']?.toString().trim() ?? '';
    if (section != SparkIntakeAiSection.inspection) {
      group = '';
      element = '';
    }
    if (section != SparkIntakeAiSection.materials) {
      documentKind = SparkIntakeDocumentKind.none;
    } else if (documentKind.isEmpty) {
      documentKind = SparkIntakeDocumentKind.document;
    }
    verdicts.add((
      hash: hash,
      section: section,
      documentKind: documentKind,
      group: group,
      element: element,
    ));
  }
  return verdicts;
}

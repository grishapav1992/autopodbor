part of 'spark_joy_create_report_screen.dart';

class _SparkJoySummaryRegistry {
  const _SparkJoySummaryRegistry._();

  static const String reasonPrefixVehicle = 'Автомобиль —';
  static const String reasonPrefixDocsCheck = 'Сверка документов —';
  static const String reasonPrefixTestDrive = 'Тест-драйв —';
  static const String reasonPrefixMedia = 'Осмотр —';
  static const String reasonPrefixSummary = 'Итог специалиста —';

  /// Единый источник истины об обязательных медиа-группах — флаг
  /// `MediaGroupConfig.required` в реестре. Раньше тут был отдельный хардкод-
  /// сет, который дублировал флаг и разошёлся с ним (флаг был у всех false),
  /// из-за чего gate шага и fill-state не совпадали с финальной валидацией.
  static Set<String> get requiredMediaKeysForSummary =>
      _SparkJoyMediaGroupRegistry.groups
          .where((g) => g.required)
          .map((g) => g.key)
          .toSet();

  static const Map<String, String> titleToGroupKey = {
    'Кузов': _SparkJoyMediaGroupRegistry.keyBody,
    'Остекление': _SparkJoyMediaGroupRegistry.keyGlass,
    'Силовые элементы кузова': _SparkJoyMediaGroupRegistry.keyStructural,
    'Светотехника': _SparkJoyMediaGroupRegistry.keyLighting,
    'Подкапотное пространство': _SparkJoyMediaGroupRegistry.keyUnderhood,
    'Салон': _SparkJoyMediaGroupRegistry.keyInterior,
    'Колёса и шины': _SparkJoyMediaGroupRegistry.keyWheels,
    'Колёса и тормозные механизмы': _SparkJoyMediaGroupRegistry.keyWheels,
    'Компьютерная диагностика': _SparkJoyMediaGroupRegistry.keyDiagnostics,
    'Диагностика': _SparkJoyMediaGroupRegistry.keyDiagnostics,
  };

  static const Map<String, String> titleToStepId = {
    'Автомобиль': _SparkJoyStepRegistry.idVehicle,
    'Параметры': _SparkJoyStepRegistry.idParams,
    'Сверка документов': _SparkJoyStepRegistry.idDocsCheck,
    'Материалы проверки': _SparkJoyStepRegistry.idLegal,
    'Кузов': _SparkJoyStepRegistry.idMedia,
    'Остекление': _SparkJoyStepRegistry.idMedia,
    'Силовые элементы кузова': _SparkJoyStepRegistry.idMedia,
    'Светотехника': _SparkJoyStepRegistry.idMedia,
    'Подкапотное пространство': _SparkJoyStepRegistry.idMedia,
    'Салон': _SparkJoyStepRegistry.idMedia,
    'Колёса и шины': _SparkJoyStepRegistry.idMedia,
    'Колёса и тормозные механизмы': _SparkJoyStepRegistry.idMedia,
    'Компьютерная диагностика': _SparkJoyStepRegistry.idMedia,
    'Диагностика': _SparkJoyStepRegistry.idMedia,
    'Тест-драйв': _SparkJoyStepRegistry.idTestDrive,
  };

  static const Map<String, String> mediaGroupLabelByKey = {
    _SparkJoyMediaGroupRegistry.keyBody: 'Кузов',
    _SparkJoyMediaGroupRegistry.keyGlass: 'Остекление',
    _SparkJoyMediaGroupRegistry.keyLighting: 'Светотехника',
    _SparkJoyMediaGroupRegistry.keyUnderhood: 'Подкапотное пространство',
    _SparkJoyMediaGroupRegistry.keyInterior: 'Салон',
    _SparkJoyMediaGroupRegistry.keyDiagnostics: 'Компьютерная диагностика',
    _SparkJoyMediaGroupRegistry.keyStructural: 'Силовые элементы кузова',
    _SparkJoyMediaGroupRegistry.keyWheels: 'Колёса и тормозные механизмы',
  };

  static bool isSummaryStep(String? stepId) {
    return stepId == _SparkJoyStepRegistry.idSummary;
  }

  static bool isMediaStep(String? stepId) {
    return stepId == _SparkJoyStepRegistry.idMedia;
  }

  static String? stepIdByMissingReason(String reason) {
    final value = reason.trim();
    if (value.startsWith(reasonPrefixVehicle)) {
      return _SparkJoyStepRegistry.idVehicle;
    }
    if (value.startsWith(reasonPrefixDocsCheck)) {
      return _SparkJoyStepRegistry.idDocsCheck;
    }
    if (value.startsWith(reasonPrefixTestDrive)) {
      return _SparkJoyStepRegistry.idTestDrive;
    }
    if (value.startsWith(reasonPrefixMedia)) {
      return _SparkJoyStepRegistry.idMedia;
    }
    if (value.startsWith(reasonPrefixSummary)) {
      return _SparkJoyStepRegistry.idSummary;
    }
    return null;
  }

  static String? mediaGroupKeyByMissingReason(String reason) {
    if (!reason.startsWith(reasonPrefixMedia)) return null;
    final parts = reason.split(':');
    if (parts.length < 2) return null;
    final label = parts.last.trim().toLowerCase();
    for (final entry in mediaGroupLabelByKey.entries) {
      if (entry.value.toLowerCase() == label) return entry.key;
    }
    return null;
  }
}

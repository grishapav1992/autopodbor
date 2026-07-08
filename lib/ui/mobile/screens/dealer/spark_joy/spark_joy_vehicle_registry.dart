part of 'spark_joy_create_report_screen.dart';

// Хардкодный 6-брендовый `carCatalog` удалён: офлайн-каталог авто теперь
// живёт в CarCatalogRepository (персист + фоновый синк), а выбор авто —
// строго из него. Здесь остались только словари параметров.
class _SparkJoyVehicleRegistry {
  const _SparkJoyVehicleRegistry._();

  static const List<String> engineTypes = [
    'Бензин',
    'Дизель',
    'Гибрид',
    'Электро',
    'Газ/Бензин',
  ];

  static const List<String> gearboxTypes = [
    'АКПП',
    'МКПП',
    'Робот',
    'Вариатор',
  ];

  static const List<String> driveTypes = ['Передний', 'Задний', 'Полный'];

  static const List<String> colors = [
    'Белый',
    'Чёрный',
    'Серый',
    'Серебристый',
    'Синий',
    'Голубой',
    'Красный',
    'Бордовый',
    'Зелёный',
    'Жёлтый',
    'Оранжевый',
    'Коричневый',
    'Бежевый',
    'Фиолетовый',
    'Золотистый',
  ];

  static const List<String> ownersCounts = ['1', '2', '3', '4+'];

  /// Опции дропдауна объёма двигателя (0.8…5.0 л, шаг 0.1) — единый
  /// источник для UI (`_stepParams`) и нормализатора AI-вывода
  /// (`parseVinParamsAiResult`), чтобы списки не разъезжались (иначе
  /// валидный объём молча отбрасывается при несовпадении).
  static final List<String> engineVolumeOptions = List<String>.generate(
    43,
    (i) => (0.8 + i * 0.1).toStringAsFixed(1),
  );
}

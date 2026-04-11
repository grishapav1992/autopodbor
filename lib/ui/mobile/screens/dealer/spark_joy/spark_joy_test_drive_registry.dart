part of 'spark_joy_create_report_screen.dart';

class _SparkJoyTestDriveRegistry {
  const _SparkJoyTestDriveRegistry._();

  static const String modeAllGood = 'all_good';
  static const String modeProblems = 'problems';
  static const String modeNotConducted = 'not_conducted';

  static const String scopeEngine = 'test_drive_engine';
  static const String scopeGearbox = 'test_drive_gearbox';
  static const String scopeSteering = 'test_drive_steering';
  static const String scopeRide = 'test_drive_ride';
  static const String scopeBrake = 'test_drive_brake';

  static const Set<String> validModes = {
    modeAllGood,
    modeProblems,
    modeNotConducted,
  };

  static const List<String> _engineTagOptions = [
    'Вибрация двигателя',
    'Посторонний стук',
    'Потеря мощности',
    'Пропуски зажигания',
    'Дым из выхлопной',
    'Перегрев',
    'Нестабильный холостой ход',
  ];

  static const List<String> _gearboxTagOptions = [
    'Тугое переключение',
    'Задержка переключения',
    'Толчки / пинки',
    'Пробуксовка',
    'Посторонний шум КПП',
    'Вибрация на ходу',
  ];

  static const List<String> _steeringTagOptions = [
    'Люфт руля',
    'Увод в сторону',
    'Шум при повороте',
    'Тяжёлый руль',
    'Вибрация руля',
  ];

  static const List<String> _rideTagOptions = [
    'Стук подвески на ходу',
    'Раскачка кузова',
    'Снос оси',
    'Пробой подвески',
  ];

  static const List<String> _brakeTagOptions = [
    'Увод при торможении',
    'Вибрация при торможении',
    'Длинный ход педали',
    'Скрип тормозов',
    'Срабатывание ABS на ровной',
  ];

  static const Map<String, List<String>> tagOptionsByScope = {
    scopeEngine: _engineTagOptions,
    scopeGearbox: _gearboxTagOptions,
    scopeSteering: _steeringTagOptions,
    scopeRide: _rideTagOptions,
    scopeBrake: _brakeTagOptions,
  };

  static const Map<String, Set<String>> seriousTagsByScope = {
    scopeEngine: {
      'Посторонний стук',
      'Потеря мощности',
      'Пропуски зажигания',
      'Дым из выхлопной',
      'Перегрев',
    },
    scopeGearbox: {
      'Задержка переключения',
      'Толчки / пинки',
      'Пробуксовка',
      'Посторонний шум КПП',
    },
    scopeSteering: {'Люфт руля', 'Увод в сторону', 'Тяжёлый руль'},
    scopeRide: {'Стук подвески на ходу', 'Снос оси', 'Пробой подвески'},
    scopeBrake: {
      'Увод при торможении',
      'Вибрация при торможении',
      'Длинный ход педали',
    },
  };
}

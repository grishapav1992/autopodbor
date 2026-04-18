part of 'spark_joy_create_report_screen.dart';

class _SparkJoyMediaGroupRegistry {
  const _SparkJoyMediaGroupRegistry._();

  static const String keyBody = 'body';
  static const String keyStructural = 'structural';
  static const String keyGlass = 'glass';
  static const String keyLighting = 'lighting';
  static const String keyUnderhood = 'underhood';
  static const String keyInterior = 'interior';
  static const String keyWheels = 'wheels';
  static const String keyDiagnostics = 'diagnostics';

  static const List<MediaGroupConfig> groups = [
    MediaGroupConfig(
      key: keyBody,
      title: 'Кузов',
      description: 'ЛКП, вмятины, царапины, дефекты элементов',
      required: false,
      severeIfIssue: false,
    ),
    MediaGroupConfig(
      key: keyStructural,
      title: 'Силовые элементы кузова',
      description: 'Лонжероны, стойки, пороги, геометрия',
      required: false,
      severeIfIssue: true,
    ),
    MediaGroupConfig(
      key: keyGlass,
      title: 'Остекление',
      description: 'Лобовое, боковые, заднее стекло',
      required: false,
      severeIfIssue: false,
    ),
    MediaGroupConfig(
      key: keyLighting,
      title: 'Светотехника',
      description: 'Фары, фонари, ПТФ, корректоры',
      required: false,
      severeIfIssue: false,
    ),
    MediaGroupConfig(
      key: keyUnderhood,
      title: 'Подкапотное пространство',
      description: 'Течи, крепеж, ремни, агрегаты',
      required: false,
      severeIfIssue: true,
    ),
    MediaGroupConfig(
      key: keyInterior,
      title: 'Салон',
      description: 'Износ, электроника, функции и опции',
      required: false,
      severeIfIssue: false,
    ),
    MediaGroupConfig(
      key: keyWheels,
      title: 'Колёса и тормозные механизмы',
      description: 'Резина, диски, тормоза, подвеска',
      required: false,
      severeIfIssue: false,
    ),
    MediaGroupConfig(
      key: keyDiagnostics,
      title: 'Компьютерная диагностика',
      description: 'Ошибки блоков, коды, комментарии',
      required: false,
      severeIfIssue: true,
    ),
  ];
}

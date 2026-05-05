part of 'spark_joy_create_report_screen.dart';

class _SparkJoyStepRegistry {
  const _SparkJoyStepRegistry._();

  static const String idVehicle = 'vehicle';
  static const String idParams = 'params';
  static const String idDocsCheck = 'docs_check';
  static const String idLegal = 'legal';
  static const String idMedia = 'media';
  static const String idTestDrive = 'test_drive';
  static const String idSummary = 'summary';

  static const List<_StepConfig> steps = [
    _StepConfig(
      id: idVehicle,
      title: 'Автомобиль',
      description:
          'VIN, госномер, марка/модель, пробег, владельцы и город осмотра',
    ),
    _StepConfig(
      id: idParams,
      title: 'Параметры',
      description: 'Двигатель, КПП, привод, цвет, комплектация',
    ),
    _StepConfig(
      id: idDocsCheck,
      title: 'Сверка документов',
      description: 'Проверка совпадения владельца, VIN и модели двигателя',
    ),
    _StepConfig(
      id: idLegal,
      title: 'Материалы проверки',
      description: 'Файлы и комментарий специалиста',
    ),
    _StepConfig(
      id: idMedia,
      title: 'Осмотр',
      description: 'Группы осмотра, заметки и ссылки на фото/видео',
    ),
    _StepConfig(
      id: idTestDrive,
      title: 'Тест-драйв',
      description: 'Проверка автомобиля на ходу',
    ),
    _StepConfig(
      id: idSummary,
      title: 'Итог',
      description: 'Итоговый вердикт, чеклист и заключение специалиста',
    ),
  ];

  static const Map<String, IconData> _stepIcons = {
    idVehicle: Icons.directions_car_outlined,
    idParams: Icons.tune_rounded,
    idDocsCheck: Icons.badge_outlined,
    idLegal: Icons.fact_check_outlined,
    idMedia: Icons.photo_library_outlined,
    idTestDrive: Icons.route_rounded,
    idSummary: Icons.task_alt_rounded,
  };

  static const Set<String> _hiddenProgressStepIds = {
    idVehicle,
    idParams,
    idDocsCheck,
    idLegal,
    idMedia,
    idTestDrive,
  };

  static IconData iconFor(String? stepId) {
    return _stepIcons[stepId] ?? Icons.description_outlined;
  }

  static bool hidesProgressBar(String stepId) {
    return _hiddenProgressStepIds.contains(stepId);
  }

  static int indexById(String stepId) {
    return steps.indexWhere((step) => step.id == stepId);
  }

  static String idAt(int index) {
    if (steps.isEmpty) return idVehicle;
    if (index < 0 || index >= steps.length) return steps.first.id;
    return steps[index].id;
  }

  static _StepConfig stepAt(int index) {
    if (steps.isEmpty) {
      return const _StepConfig(
        id: idVehicle,
        title: 'Автомобиль',
        description: '',
      );
    }
    if (index < 0 || index >= steps.length) return steps.first;
    return steps[index];
  }

  static bool isSummaryStepId(String? stepId) {
    return stepId == idSummary;
  }

  static bool isMediaStepId(String? stepId) {
    return stepId == idMedia;
  }
}

part of 'spark_joy_create_report_screen.dart';

class _SparkJoySummaryTextsRegistry {
  const _SparkJoySummaryTextsRegistry._();

  static const String sectionVehicle = 'Автомобиль';
  static const String sectionParams = 'Параметры';
  static const String sectionDocsCheck = 'Сверка документов';
  static const String sectionLegal = 'Материалы проверки';
  static const String sectionTestDrive = 'Тест-драйв';

  static const String checklistVinMissing =
      'VIN не заполнен и не отмечен как нечитаемый.';
  static const String checklistMileageMissing = 'Не указан пробег автомобиля.';
  static const String checklistMileageMismatch =
      'Пробег вызывает сомнения по состоянию автомобиля.';
  static const String checklistDocsIncomplete =
      'Сверка документов заполнена не полностью.';
  static const String checklistDocsOwnerMismatch =
      'Есть расхождение по владельцу в документах.';
  static const String checklistDocsVinMismatch =
      'VIN в документах не совпадает с автомобилем.';
  static const String checklistDocsEngineMismatch =
      'Модель двигателя в документах не совпадает.';
  static const String checklistLegalSkipped =
      'Материалы проверки не добавлены.';
  static const String checklistLegalUnconfirmed =
      'Материалы проверки не подтверждены.';
  static const String checklistTdStatusMissing =
      'Статус тест-драйва не заполнен.';
  static const String checklistTdCommentRequired =
      'Тест-драйв: добавьте комментарий, если выбран режим «Да, есть проблемы».';
  static const String checklistNoCritical = 'Критичных замечаний не выявлено.';
  static const String checklistRecommended =
      'Покупка возможна после стандартной проверки сделки.';
  static const String checklistWithReservations =
      'Нужна дополнительная проверка и торг по замечаниям.';
  static const String checklistNotRecommended =
      'Покупка не рекомендуется без устранения рисков.';

  static const String verdictRecommended = 'recommended';
  static const String verdictWithReservations = 'with_reservations';
  static const String verdictNotRecommended = 'not_recommended';

  static const String verdictLabelRecommended = 'Рекомендуется к покупке';
  static const String verdictLabelWithReservations = 'С оговорками';
  static const String verdictLabelNotRecommended = 'Не рекомендуется';

  static String checklistMediaCoverageMissing(String sectionTitle) {
    return '$sectionTitle: нет фото/видео подтверждения осмотра.';
  }

  static String checklistMediaIssuesFound(String sectionTitle) {
    return '$sectionTitle: зафиксированы замечания.';
  }

  static String checklistTdIssuesFound(String sectionTitle) {
    return 'Тест-драйв: замечания по пункту "$sectionTitle".';
  }
}

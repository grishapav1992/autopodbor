part of 'spark_joy_create_report_screen.dart';

class _SparkJoyOverviewState {
  const _SparkJoyOverviewState({
    required this.completed,
    required this.total,
    required this.progress,
    required this.remaining,
    required this.currentTitle,
    required this.sectionValues,
  });

  final int completed;
  final int total;
  final double progress;
  final int remaining;
  final String currentTitle;
  final Map<String, String> sectionValues;
}

class _SparkJoyOverviewController {
  const _SparkJoyOverviewController();

  static const String completedStatTitle = 'Заполнено';
  static const String remainingStatTitle = 'Осталось';
  static const String sectionsHeaderTitle = 'Разделы отчёта';
  static const String currentStepPrefix = 'Текущий';

  _SparkJoyOverviewState build(_SparkJoyCreateReportScreenState s) {
    final total = _SparkJoyStepRegistry.steps.length;
    final values = <String, String>{};
    var completed = 0;

    for (final step in _SparkJoyStepRegistry.steps) {
      final value = sectionValue(s, step.id);
      values[step.id] = value;
      if (value.isNotEmpty) completed++;
    }

    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final remaining = (total - completed).clamp(0, total);
    final currentTitle = total == 0
        ? ''
        : _SparkJoyStepRegistry.stepAt(s._stepIndex).title;

    return _SparkJoyOverviewState(
      completed: completed,
      total: total,
      progress: progress,
      remaining: remaining,
      currentTitle: currentTitle,
      sectionValues: values,
    );
  }

  String sectionValue(_SparkJoyCreateReportScreenState s, String stepId) {
    switch (stepId) {
      case _SparkJoyStepRegistry.idVehicle:
        final chunks = <String>[];
        if (s._carName().isNotEmpty) chunks.add(s._carName());
        if (s._vinController.text.trim().isNotEmpty) {
          chunks.add(s._vinController.text.trim());
        } else if (s._vinUnreadable) {
          chunks.add('VIN нечитаемый');
        }
        if (s._plateController.text.trim().isNotEmpty) {
          chunks.add(
            s._formatPlate(s._sanitizePlate(s._plateController.text.trim())),
          );
        }
        if (s._mileageController.text.trim().isNotEmpty) {
          chunks.add('${s._mileageController.text.trim()} км');
        }
        return chunks.join(' · ');
      case _SparkJoyStepRegistry.idParams:
        final chunks = <String>[];
        if (s._engineVolumeController.text.trim().isNotEmpty) {
          chunks.add('${s._engineVolumeController.text.trim()} л');
        }
        if (s._engineTypeController.text.trim().isNotEmpty) {
          chunks.add(s._engineTypeController.text.trim());
        }
        return chunks.join(' · ');
      case _SparkJoyStepRegistry.idDocsCheck:
        if (!s._docsAllAnswered()) {
          return '';
        }
        if (s._docsAnyMismatch()) {
          return s._docsMismatchCommentController.text.trim().isNotEmpty
              ? 'Есть расхождения'
              : 'Есть расхождения (без комментария)';
        }
        return 'Все соответствует';
      case _SparkJoyStepRegistry.idLegal:
        if (s._legalLoaded) return 'Юридический отчёт готов';
        if (s._legalSkipped) return 'Пропущено';
        if (s._legalLoading) return 'Формирование отчёта...';
        if (s._legalFiles.isNotEmpty) return 'Файлов: ${s._legalFiles.length}';
        if (s._legalNoteController.text.trim().isNotEmpty) {
          return 'Есть комментарий';
        }
        return '';
      case _SparkJoyStepRegistry.idMedia:
        final covered = s._mediaState.values.where(s._groupHasCoverage).length;
        return covered == 0 ? '' : 'Групп с файлами: $covered';
      case _SparkJoyStepRegistry.idTestDrive:
        if (s._tdMode == null) return '';
        if (s._tdMode == _SparkJoyTestDriveRegistry.modeNotConducted) {
          return 'Не проводился';
        }
        if (s._tdMode == _SparkJoyTestDriveRegistry.modeAllGood) {
          return 'Да, всё исправно';
        }
        return 'Да, есть проблемы';
      case _SparkJoyStepRegistry.idSummary:
        if (s._summaryController.text.trim().isEmpty) return '';
        return 'Итог заполнен';
      default:
        return '';
    }
  }

  IconData sectionIcon(String? stepId) {
    return _SparkJoyStepRegistry.iconFor(stepId);
  }
}

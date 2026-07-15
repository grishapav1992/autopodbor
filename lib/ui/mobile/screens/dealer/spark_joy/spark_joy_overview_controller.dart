part of 'spark_joy_create_report_screen.dart';

class _SparkJoyOverviewState {
  const _SparkJoyOverviewState({required this.sectionFillStates});

  final Map<String, SparkJoySectionFillState> sectionFillStates;
}

class _SparkJoyOverviewController {
  const _SparkJoyOverviewController();

  _SparkJoyOverviewState build(_SparkJoyCreateReportScreenState s) {
    final fillStates = <String, SparkJoySectionFillState>{};

    for (final step in _SparkJoyStepRegistry.steps) {
      fillStates[step.id] = sectionFillState(s, step.id);
    }

    return _SparkJoyOverviewState(sectionFillStates: fillStates);
  }

  SparkJoySectionFillState sectionFillState(
    _SparkJoyCreateReportScreenState s,
    String stepId,
  ) {
    switch (stepId) {
      case _SparkJoyStepRegistry.idVehicle:
        if (s._vinConverterBusy) return SparkJoySectionFillState.loading;
        final hasAny =
            s._vinController.text.trim().isNotEmpty ||
            s._vinUnreadable ||
            s._plateController.text.trim().isNotEmpty ||
            s._mileageController.text.trim().isNotEmpty ||
            s._inspectionCityController.text.trim().isNotEmpty;
        final done = s._isVehicleReadyForContinue();
        if (done) return SparkJoySectionFillState.done;
        if (hasAny) return SparkJoySectionFillState.partial;
        return SparkJoySectionFillState.empty;
      case _SparkJoyStepRegistry.idParams:
        final hasAny =
            s._brandController.text.trim().isNotEmpty ||
            s._modelController.text.trim().isNotEmpty ||
            s._generationController.text.trim().isNotEmpty ||
            s._engineVolumeController.text.trim().isNotEmpty ||
            s._engineTypeController.text.trim().isNotEmpty ||
            s._gearboxTypeController.text.trim().isNotEmpty ||
            s._driveTypeController.text.trim().isNotEmpty ||
            s._colorController.text.trim().isNotEmpty ||
            s._trimController.text.trim().isNotEmpty;
        final done =
            s._brandController.text.trim().isNotEmpty &&
            s._modelController.text.trim().isNotEmpty;
        if (done) return SparkJoySectionFillState.done;
        if (hasAny) return SparkJoySectionFillState.partial;
        return SparkJoySectionFillState.empty;
      case _SparkJoyStepRegistry.idDocsCheck:
        final answeredCount = [
          s._docsOwnerMatch,
          s._docsVinMatch,
          s._docsEngineMatch,
        ].where((value) => value != null).length;
        final hasAny =
            answeredCount > 0 ||
            s._docsMismatchCommentController.text.trim().isNotEmpty ||
            s._docsCommentAudioFiles.isNotEmpty;
        final done = s._docsCheckMissingReasons().isEmpty;
        if (done) return SparkJoySectionFillState.done;
        if (hasAny) return SparkJoySectionFillState.partial;
        return SparkJoySectionFillState.empty;
      case _SparkJoyStepRegistry.idLegal:
        if (s._legalLoading) return SparkJoySectionFillState.loading;
        final hasAny =
            s._legalLoading ||
            s._legalLoaded ||
            s._legalSkipped ||
            s._legalTimedOut ||
            s._legalPurchased ||
            s._legalFiles.isNotEmpty ||
            s._legalNoteController.text.trim().isNotEmpty ||
            s._legalCommentAudioFiles.isNotEmpty;
        final done =
            s._legalLoaded ||
            s._legalSkipped ||
            s._legalFiles.isNotEmpty ||
            s._legalNoteController.text.trim().isNotEmpty;
        if (done) return SparkJoySectionFillState.done;
        if (hasAny) return SparkJoySectionFillState.partial;
        return SparkJoySectionFillState.empty;
      case _SparkJoyStepRegistry.idMedia:
        final covered = s._mediaState.values.where(s._groupHasCoverage).length;
        final done = s._missingRequiredMediaGroups().isEmpty && covered > 0;
        if (done) return SparkJoySectionFillState.done;
        if (covered > 0) return SparkJoySectionFillState.partial;
        return SparkJoySectionFillState.empty;
      case _SparkJoyStepRegistry.idTestDrive:
        if (s._tdMode == null) return SparkJoySectionFillState.empty;
        final done = s._testDriveMissingReasons().isEmpty;
        if (done) return SparkJoySectionFillState.done;
        return SparkJoySectionFillState.partial;
      case _SparkJoyStepRegistry.idSummary:
        final hasAny = s._summaryController.text.trim().isNotEmpty;
        final done = s._summaryMissingReasons().isEmpty;
        if (done) return SparkJoySectionFillState.done;
        if (hasAny) return SparkJoySectionFillState.partial;
        return SparkJoySectionFillState.empty;
      default:
        return SparkJoySectionFillState.empty;
    }
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
        // Step renamed «Юр. проверка» → «Материалы проверки».
        // Report-formation flow is hidden; show only file/comment
        // signals. legalLoaded/Loading/Skipped status messages would
        // surface a feature the user can't see anymore.
        final fileCount = s._legalFiles.length;
        final hasNote = s._legalNoteController.text.trim().isNotEmpty;
        if (fileCount > 0 && hasNote) {
          return 'Файлов: $fileCount · комментарий';
        }
        if (fileCount > 0) return 'Файлов: $fileCount';
        if (hasNote) return 'Есть комментарий';
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

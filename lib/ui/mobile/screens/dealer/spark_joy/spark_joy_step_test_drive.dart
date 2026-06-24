part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepTestDrive(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
  required String modeAllGood,
  required String modeProblems,
  required String scopeEngine,
  required String scopeGearbox,
  required String scopeSteering,
  required String scopeRide,
  required String scopeBrake,
}) {
  final tdConducted = s._tdConductedValue();
  final showSubsystemCards = tdConducted == true && s._tdMode != modeAllGood;

  return Column(
    children: [
      s._requiredLegend('— обязательное поле'),
      if (tdConducted == null) ...[
        const SparkHintCard(
          text: 'Сначала выберите режим тест-драйва.',
          icon: Icons.info_outline_rounded,
        ),
        const SizedBox(height: SparkSpace.lg),
      ],
      s._testDriveConductedSelector(),
      if (showSubsystemCards) ...[
        const SizedBox(height: SparkSpace.lg),
        s._sectionHeading(
          'Проверка узлов',
          icon: Icons.build_circle_outlined,
          subtitle: 'Отметьте исправность или добавьте повреждения',
        ),
        s._testDriveSubsystemCard(
          sectionLabel: 'Двигатель',
          tagScopeKey: scopeEngine,
          ok: s._tdEngineOk,
          onOkChanged: (value) {
            setStateFn(() {
              if (s._tdMode == modeAllGood && !value) {
                s._tdMode = modeProblems;
              }
              s._tdEngineOk = value;
              if (value) s._tdEngineTags = const [];
            });
          },
          okLabel: 'Двигатель работает исправно',
          selected: s._tdEngineTags,
          onTagsChanged: (value) {
            setStateFn(() {
              s._tdEngineTags = value;
            });
            s._markDraftDirty();
          },
        ),
        const SizedBox(height: SparkSpace.lg),
        s._testDriveSubsystemCard(
          sectionLabel: 'КПП',
          tagScopeKey: scopeGearbox,
          ok: s._tdGearboxOk,
          onOkChanged: (value) {
            setStateFn(() {
              if (s._tdMode == modeAllGood && !value) {
                s._tdMode = modeProblems;
              }
              s._tdGearboxOk = value;
              if (value) s._tdGearboxTags = const [];
            });
          },
          okLabel: 'КПП работает исправно',
          selected: s._tdGearboxTags,
          onTagsChanged: (value) {
            setStateFn(() {
              s._tdGearboxTags = value;
            });
            s._markDraftDirty();
          },
        ),
        const SizedBox(height: SparkSpace.lg),
        s._testDriveSubsystemCard(
          sectionLabel: 'Рулевое управление',
          tagScopeKey: scopeSteering,
          ok: s._tdSteeringOk,
          onOkChanged: (value) {
            setStateFn(() {
              if (s._tdMode == modeAllGood && !value) {
                s._tdMode = modeProblems;
              }
              s._tdSteeringOk = value;
              if (value) s._tdSteeringTags = const [];
            });
          },
          okLabel: 'Рулевое без замечаний',
          selected: s._tdSteeringTags,
          onTagsChanged: (value) {
            setStateFn(() {
              s._tdSteeringTags = value;
            });
            s._markDraftDirty();
          },
        ),
        const SizedBox(height: SparkSpace.lg),
        s._testDriveSubsystemCard(
          sectionLabel: 'Подвеска на ходу',
          tagScopeKey: scopeRide,
          ok: s._tdRideOk,
          onOkChanged: (value) {
            setStateFn(() {
              if (s._tdMode == modeAllGood && !value) {
                s._tdMode = modeProblems;
              }
              s._tdRideOk = value;
              if (value) s._tdRideTags = const [];
            });
          },
          okLabel: 'Подвеска без замечаний на ходу',
          selected: s._tdRideTags,
          onTagsChanged: (value) {
            setStateFn(() {
              s._tdRideTags = value;
            });
            s._markDraftDirty();
          },
        ),
        const SizedBox(height: SparkSpace.lg),
        s._testDriveSubsystemCard(
          sectionLabel: 'Тормоза на ходу',
          tagScopeKey: scopeBrake,
          ok: s._tdBrakeOk,
          onOkChanged: (value) {
            setStateFn(() {
              if (s._tdMode == modeAllGood && !value) {
                s._tdMode = modeProblems;
              }
              s._tdBrakeOk = value;
              if (value) s._tdBrakeTags = const [];
            });
          },
          okLabel: 'Тормоза работают исправно',
          selected: s._tdBrakeTags,
          onTagsChanged: (value) {
            setStateFn(() {
              s._tdBrakeTags = value;
            });
            s._markDraftDirty();
          },
        ),
        const SizedBox(height: SparkSpace.lg),
        s._sectionHeading('Комментарий', icon: Icons.comment_outlined),
        s._testDriveNoteBlock(
          s._tdMode == modeAllGood
              ? 'Комментарий по тест-драйву...'
              : 'Замечания по тест-драйву...',
        ),
      ],
      if (tdConducted == false) ...[
        const SizedBox(height: SparkSpace.lg),
        s._sectionHeading('Комментарий', icon: Icons.comment_outlined),
        s._testDriveNoteBlock('Причина отсутствия тест-драйва...'),
      ],
    ],
  );
}

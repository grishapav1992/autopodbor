part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepParams(
  _SparkJoyCreateReportScreenState s, {
  required List<String> engineVolumes,
  required List<String> colors,
  required List<String> engineTypes,
  required List<String> gearboxTypes,
  required List<String> driveTypes,
}) {
  return Column(
    children: [
      // Brand/Model picker moved to the «Автомобиль» step alongside
      // VIN and госномер — basic vehicle identification belongs together.
      s._sectionHeading(
        'Технические параметры',
        icon: Icons.settings_suggest_outlined,
      ),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            s._dropdownField(
              s._engineVolumeController,
              'Объём двигателя (л)',
              engineVolumes,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.md),
            s._dropdownField(
              s._engineTypeController,
              'Тип двигателя',
              engineTypes,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.md),
            s._dropdownField(
              s._gearboxTypeController,
              'Коробка передач',
              gearboxTypes,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.md),
            s._dropdownField(
              s._driveTypeController,
              'Привод',
              driveTypes,
              clearable: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._sectionHeading('Дополнительно', icon: Icons.palette_outlined),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            s._dropdownField(
              s._colorController,
              'Цвет',
              colors,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.md),
            s._input(
              s._trimController,
              'Комплектация',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => s._dismissKeyboard(),
            ),
          ],
        ),
      ),
    ],
  );
}

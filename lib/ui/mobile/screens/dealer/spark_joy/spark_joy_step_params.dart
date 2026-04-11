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
      s._sectionHeading(
        'Марка и модель',
        icon: Icons.directions_car_filled_outlined,
      ),
      s._carSelectionCard(),
      const SizedBox(height: SparkSpace.lg),
      s._sectionHeading(
        'Технические параметры',
        icon: Icons.settings_suggest_outlined,
        subtitle: 'Силовой агрегат, трансмиссия, привод',
      ),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Силовой агрегат',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            s._dropdownField(
              s._engineVolumeController,
              'Объём двигателя (л)',
              engineVolumes,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.lg),
            s._dropdownField(
              s._engineTypeController,
              'Тип двигателя',
              engineTypes,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.lg),
            s._dropdownField(
              s._gearboxTypeController,
              'Коробка передач',
              gearboxTypes,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.lg),
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
      s._sectionHeading(
        'Дополнительно',
        icon: Icons.palette_outlined,
        subtitle: 'Цвет и комплектация',
      ),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Исполнение',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            s._dropdownField(
              s._colorController,
              'Цвет',
              colors,
              clearable: true,
            ),
            const SizedBox(height: SparkSpace.lg),
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

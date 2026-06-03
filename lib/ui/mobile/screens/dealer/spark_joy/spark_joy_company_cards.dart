part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCompanyCards on _SparkJoyCreateReportScreenState {
  Widget _carSelectionCard() {
    // P2 — раздельные поля: марку/модель можно ввести вручную, выбрать из
    // каталога («Выбрать из каталога») или подставить авто-конвертером по
    // VIN/госномеру (шаг «Идентификация»). Поколение — необязательное
    // (валидация требует только марку+модель). Все три пишут в те же
    // контроллеры (_brand/_model/_generationController), что и каталог-пикер.
    final photo = _carPhotoUrl.trim();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Марка',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.sm),
          TextField(
            controller: _brandController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _onCarIdentityEdited(),
            decoration: _fieldDecoration('Напр. LADA'),
          ),
          const SizedBox(height: SparkSpace.md),
          const MyText(
            text: 'Модель',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.sm),
          TextField(
            controller: _modelController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _onCarIdentityEdited(),
            decoration: _fieldDecoration('Напр. VESTA'),
          ),
          const SizedBox(height: SparkSpace.md),
          const MyText(
            text: 'Поколение (необязательно)',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.sm),
          TextField(
            controller: _generationController,
            onChanged: (_) => _onCarIdentityEdited(),
            decoration: _fieldDecoration('Можно не заполнять'),
          ),
          const SizedBox(height: SparkSpace.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openCarPickerDialog,
              icon: const Icon(Icons.list_alt_rounded, size: SparkSize.iconSm),
              label: const Text('Выбрать из каталога'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kBorderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.lg),
                ),
              ),
            ),
          ),
          // Фото из каталога (если авто выбрано через каталог-пикер).
          if (photo.isNotEmpty) ...[
            const SizedBox(height: SparkSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.sm),
              child: CachedNetworkImage(
                imageUrl: photo,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorWidget: (context, url, error) {
                  return Container(
                    width: double.infinity,
                    height: SparkSize.mediaCardThumb,
                    color: kLightGreyColor,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.directions_car_outlined,
                      color: kGreyColor,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

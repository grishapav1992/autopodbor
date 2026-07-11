part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCompanyCards on _SparkJoyCreateReportScreenState {
  Widget _carSelectionCard() {
    // Строгий режим: марка/модель/поколение выбираются ТОЛЬКО из каталога.
    // Бэк принимает авто лишь каталожными ID (modelCarId / frameId) —
    // свободный текст всё равно ронял выгрузку в самом конце
    // (reportModelUnresolved), теперь несоответствие невозможно по
    // построению. Единственная точка входа — кнопка ниже: она открывает
    // каталог-визард с шага «Марка» (раньше это делали три поля-дублёра).
    // Марка/модель/поколение показываются статичными блоками без фокуса и
    // анимации поля ввода. Конвертер VIN/госномера и
    // скан СТС пишут сюда уже привязанные к каталогу значения (см.
    // _bindConverterCarToCatalog).
    final photo = _carPhotoUrl.trim();
    final hasBrand = _brandController.text.trim().isNotEmpty;
    final hasModel = _modelController.text.trim().isNotEmpty;
    final hasGeneration = _generationController.text.trim().isNotEmpty;
    final hasCar = hasBrand || hasModel;
    final brandUnbound = hasBrand && _selectedBrandId == null;
    final modelUnbound = hasModel && _selectedModelCarId == null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasCar) ...[
            // Марка и модель — в один ряд (как в макете), теперь как
            // отображение (не открывают пикер).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: 'Марка',
                        size: SparkTextSize.body,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: SparkSpace.sm),
                      _catalogDisplayField(
                        controller: _brandController,
                        hint: '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: 'Модель',
                        size: SparkTextSize.body,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: SparkSpace.sm),
                      _catalogDisplayField(
                        controller: _modelController,
                        hint: '—',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasGeneration) ...[
              const SizedBox(height: SparkSpace.md),
              const MyText(
                text: 'Поколение',
                size: SparkTextSize.body,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: SparkSpace.sm),
              _catalogDisplayField(
                controller: _generationController,
                hint: '—',
              ),
            ],
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
            if (brandUnbound || modelUnbound) ...[
              const SizedBox(height: SparkSpace.sm),
              const MyText(
                text:
                    'Авто из старого черновика не привязано к каталогу — '
                    'нажмите «Изменить авто» и выберите из каталога',
                size: SparkTextSize.caption,
                color: kRedColor,
              ),
            ],
            const SizedBox(height: SparkSpace.md),
          ],
          // Единая кнопка — единственная точка входа в каталог-визард.
          if (!widget.readOnly)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => unawaited(
                  _openCarPickerDialog(startAt: _CarPickerStep.brand),
                ),
                icon: const Icon(Icons.directions_car_outlined),
                label: MyText(
                  text: hasCar ? 'Изменить авто' : 'Выбрать авто из каталога',
                  size: SparkTextSize.body,
                  weight: FontWeight.w600,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: kBorderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SparkRadius.lg),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Статичное отображение выбранного каталожного значения. В отличие от
  /// readOnly TextField не получает фокус и не меняет рамку при касании —
  /// единственная точка входа в каталог теперь «Выбрать/Изменить авто».
  Widget _catalogDisplayField({
    required TextEditingController controller,
    required String hint,
  }) {
    final value = controller.text.trim();
    return Semantics(
      label: value.isEmpty ? hint : value,
      readOnly: true,
      child: InputDecorator(
        decoration: _fieldDecoration(hint),
        isEmpty: value.isEmpty,
        child: value.isEmpty
            ? null
            : MyText(
                text: value,
                size: SparkTextSize.title,
                color: kTertiaryColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}

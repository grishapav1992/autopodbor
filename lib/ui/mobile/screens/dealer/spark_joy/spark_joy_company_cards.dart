part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCompanyCards on _SparkJoyCreateReportScreenState {
  Widget _carSelectionCard() {
    // Строгий режим: марка/модель/поколение выбираются ТОЛЬКО из каталога.
    // Бэк принимает авто лишь каталожными ID (modelCarId / frameId) —
    // свободный текст всё равно ронял выгрузку в самом конце
    // (reportModelUnresolved), теперь несоответствие невозможно по
    // построению. Поля readOnly и открывают каталог-визард на своём шаге;
    // конвертер VIN/госномера и скан СТС пишут сюда уже привязанные к
    // каталогу значения (см. _bindConverterCarToCatalog).
    final photo = _carPhotoUrl.trim();
    final brandUnbound =
        _brandController.text.trim().isNotEmpty && _selectedBrandId == null;
    final modelUnbound =
        _modelController.text.trim().isNotEmpty && _selectedModelCarId == null;

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
          _catalogSelectorField(
            controller: _brandController,
            hint: 'Выбрать марку',
            startAt: _CarPickerStep.brand,
          ),
          const SizedBox(height: SparkSpace.md),
          const MyText(
            text: 'Модель',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.sm),
          _catalogSelectorField(
            controller: _modelController,
            hint: 'Выбрать модель',
            startAt: _CarPickerStep.model,
          ),
          const SizedBox(height: SparkSpace.md),
          const MyText(
            text: 'Поколение (необязательно)',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.sm),
          _catalogSelectorField(
            controller: _generationController,
            hint: 'Выбрать поколение',
            startAt: _CarPickerStep.generation,
            onClear: () {
              _setStateSafely(() {
                _generationController.clear();
                // Рестайлинг/фреймы/фото/frameId выбирались вместе с
                // поколением — без него теряют смысл.
                _clearCatalogCarMeta();
              });
              _markDraftDirty();
            },
          ),
          if (brandUnbound || modelUnbound) ...[
            const SizedBox(height: SparkSpace.sm),
            const MyText(
              text:
                  'Авто из старого черновика не привязано к каталогу — '
                  'нажмите на поле и выберите из списка',
              size: SparkTextSize.caption,
              color: kRedColor,
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
        ],
      ),
    );
  }

  /// readOnly-поле-селектор: тап открывает каталог-визард на [startAt].
  /// [onClear] — крестик сброса значения (для необязательного поколения).
  Widget _catalogSelectorField({
    required TextEditingController controller,
    required String hint,
    required _CarPickerStep startAt,
    VoidCallback? onClear,
  }) {
    final hasValue = controller.text.trim().isNotEmpty;
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => unawaited(_openCarPickerDialog(startAt: startAt)),
      decoration: _fieldDecoration(hint).copyWith(
        suffixIcon: onClear != null && hasValue
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: SparkSize.iconSm),
                onPressed: onClear,
                splashRadius: 18,
              )
            : const Icon(Icons.expand_more_rounded, color: kGreyColor),
      ),
    );
  }
}

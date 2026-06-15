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
          RawAutocomplete<storage_api.BrandItem>(
            textEditingController: _brandController,
            focusNode: _brandFocusNode,
            displayStringForOption: (b) => b.name,
            optionsBuilder: (value) {
              unawaited(_ensureBrandCatalogLoaded());
              return _brandAutocompleteOptions(value.text);
            },
            onSelected: _onBrandAutocompleteSelected,
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _onCarIdentityEdited(),
                onTap: () => unawaited(_ensureBrandCatalogLoaded()),
                decoration: _fieldDecoration('Напр. LADA'),
              );
            },
            optionsViewBuilder: (context, onSelected, options) =>
                _buildCatalogAutocompleteOptions<storage_api.BrandItem>(
                  context: context,
                  onSelected: onSelected,
                  options: options,
                  labelOf: (b) => b.nameRus.trim().isNotEmpty
                      ? '${b.name} · ${b.nameRus}'
                      : b.name,
                ),
          ),
          const SizedBox(height: SparkSpace.md),
          const MyText(
            text: 'Модель',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.sm),
          RawAutocomplete<storage_api.ModelItem>(
            textEditingController: _modelController,
            focusNode: _modelFocusNode,
            displayStringForOption: (m) => m.model,
            optionsBuilder: (value) {
              unawaited(_ensureModelsForSelectedBrand());
              return _modelAutocompleteOptions(value.text);
            },
            onSelected: _onModelAutocompleteSelected,
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _onCarIdentityEdited(),
                onTap: () => unawaited(_ensureModelsForSelectedBrand()),
                decoration: _fieldDecoration('Напр. VESTA'),
              );
            },
            optionsViewBuilder: (context, onSelected, options) =>
                _buildCatalogAutocompleteOptions<storage_api.ModelItem>(
                  context: context,
                  onSelected: onSelected,
                  options: options,
                  labelOf: (m) => m.modelRus.trim().isNotEmpty
                      ? '${m.model} · ${m.modelRus}'
                      : m.model,
                ),
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

/// Общий overlay-список подсказок для RawAutocomplete марки/модели: карточка
/// с прокручиваемым списком шириной примерно с поле ввода.
Widget _buildCatalogAutocompleteOptions<T extends Object>({
  required BuildContext context,
  required AutocompleteOnSelected<T> onSelected,
  required Iterable<T> options,
  required String Function(T) labelOf,
}) {
  final items = options.toList(growable: false);
  final maxWidth = MediaQuery.of(context).size.width - SparkSpace.lg * 2;
  return Align(
    alignment: Alignment.topLeft,
    child: Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(SparkRadius.sm),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 260, maxWidth: maxWidth),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final option = items[index];
            return InkWell(
              onTap: () => onSelected(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.md,
                  vertical: SparkSpace.sm,
                ),
                child: MyText(text: labelOf(option), size: SparkTextSize.body),
              ),
            );
          },
        ),
      ),
    ),
  );
}

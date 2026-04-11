part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCarPickerHelpers on _SparkJoyCreateReportScreenState {
  Future<void> _openCarPickerDialog() async {
    bool same(String left, String right) {
      return left.trim().toLowerCase() == right.trim().toLowerCase();
    }

    _CarCatalogBrand? selectedBrand;
    _CarCatalogModel? selectedModel;
    _CarCatalogGeneration? selectedGeneration;
    _CarPickerStep step = _CarPickerStep.brand;
    var search = '';

    final savedBrand = _brandController.text.trim();
    final savedModel = _modelController.text.trim();
    final savedGeneration = _generationController.text.trim();
    final savedRestyling = _restylingLabel.trim();

    for (final brand in _SparkJoyVehicleRegistry.carCatalog) {
      if (!same(brand.name, savedBrand)) continue;
      selectedBrand = brand;
      for (final model in brand.models) {
        if (!same(model.name, savedModel)) continue;
        selectedModel = model;
        for (final generation in model.generations) {
          if (!same(generation.name, savedGeneration)) continue;
          selectedGeneration = generation;
          break;
        }
        break;
      }
      break;
    }

    if (selectedBrand != null) {
      step = _CarPickerStep.model;
    }
    if (selectedModel != null) {
      step = _CarPickerStep.generation;
    }
    if (selectedGeneration != null && savedRestyling.isNotEmpty) {
      step = _CarPickerStep.restyling;
    }

    String titleForStep(_CarPickerStep value) {
      switch (value) {
        case _CarPickerStep.brand:
          return 'Выберите марку';
        case _CarPickerStep.model:
          return 'Выберите модель';
        case _CarPickerStep.generation:
          return 'Выберите поколение';
        case _CarPickerStep.restyling:
          return 'Выберите рестайлинг';
      }
    }

    String breadcrumb() {
      final parts = <String>[
        if (selectedBrand != null) selectedBrand!.name,
        if (selectedModel != null) selectedModel!.name,
        if (selectedGeneration != null && step == _CarPickerStep.restyling)
          'Пок. ${selectedGeneration!.name}',
      ];
      return parts.join(' -> ');
    }

    _CarPickerSelection? buildSelection(_CarCatalogRestyling restyling) {
      if (selectedBrand == null ||
          selectedModel == null ||
          selectedGeneration == null) {
        return null;
      }
      return _CarPickerSelection(
        brand: selectedBrand!.name,
        model: selectedModel!.name,
        generation: selectedGeneration!.name,
        restyling: restyling.label,
        frames: restyling.frames,
        photoUrl: restyling.photoUrl,
      );
    }

    final selection = await showDialog<_CarPickerSelection>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final showSearch =
                step == _CarPickerStep.brand || step == _CarPickerStep.model;
            final searchHint = step == _CarPickerStep.brand
                ? 'Поиск марки...'
                : 'Поиск модели...';
            final currentBreadcrumb = breadcrumb();

            void goBack() {
              if (step == _CarPickerStep.brand) {
                Navigator.of(context).pop();
                return;
              }
              setLocalState(() {
                if (step == _CarPickerStep.model) {
                  step = _CarPickerStep.brand;
                  selectedBrand = null;
                  selectedModel = null;
                  selectedGeneration = null;
                  search = '';
                  return;
                }
                if (step == _CarPickerStep.generation) {
                  step = _CarPickerStep.model;
                  selectedModel = null;
                  selectedGeneration = null;
                  search = '';
                  return;
                }
                if (step == _CarPickerStep.restyling) {
                  step = _CarPickerStep.generation;
                  search = '';
                }
              });
            }

            Widget listContent() {
              if (step == _CarPickerStep.brand) {
                final brands = _SparkJoyVehicleRegistry.carCatalog
                    .where(
                      (brand) => search.trim().isEmpty
                          ? true
                          : brand.name.toLowerCase().contains(
                              search.trim().toLowerCase(),
                            ),
                    )
                    .toList();
                if (brands.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: brands.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final brand = brands[index];
                    return ListTile(
                      title: Text(brand.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        setLocalState(() {
                          selectedBrand = brand;
                          selectedModel = null;
                          selectedGeneration = null;
                          step = _CarPickerStep.model;
                          search = '';
                        });
                      },
                    );
                  },
                );
              }

              if (step == _CarPickerStep.model) {
                final models =
                    (selectedBrand?.models ?? const <_CarCatalogModel>[])
                        .where(
                          (model) => search.trim().isEmpty
                              ? true
                              : model.name.toLowerCase().contains(
                                  search.trim().toLowerCase(),
                                ),
                        )
                        .toList();
                if (models.isEmpty) {
                  return const Center(child: Text('Нет моделей'));
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: models.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final model = models[index];
                    return ListTile(
                      title: Text(model.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        setLocalState(() {
                          selectedModel = model;
                          selectedGeneration = null;
                          step = _CarPickerStep.generation;
                          search = '';
                        });
                      },
                    );
                  },
                );
              }

              if (step == _CarPickerStep.generation) {
                final generations =
                    selectedModel?.generations ??
                    const <_CarCatalogGeneration>[];
                if (generations.isEmpty) {
                  return const Center(child: Text('Нет поколений'));
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: generations.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final generation = generations[index];
                    return ListTile(
                      title: Text('Поколение ${generation.name}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        setLocalState(() {
                          selectedGeneration = generation;
                          step = _CarPickerStep.restyling;
                          search = '';
                        });
                      },
                    );
                  },
                );
              }

              final restylings =
                  selectedGeneration?.restylings ??
                  const <_CarCatalogRestyling>[];
              if (restylings.isEmpty) {
                return const Center(child: Text('Нет рестайлингов'));
              }
              return ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: restylings.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final restyling = restylings[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(SparkRadius.sm),
                      child: Image.network(
                        restyling.photoUrl,
                        width: SparkSize.inputHeight,
                        height: SparkSize.inputHeight,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(restyling.label),
                    subtitle: Text(restyling.frames),
                    trailing: const Icon(Icons.check_rounded),
                    onTap: () {
                      final result = buildSelection(restyling);
                      if (result == null) return;
                      Navigator.of(context).pop(result);
                    },
                  );
                },
              );
            }

            final dialogHeight = math.min(
              MediaQuery.sizeOf(context).height * 0.82,
              SparkSize.modalTall + 180,
            );
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.xl,
                vertical: SparkSize.iconXl,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.xl),
              ),
              child: SizedBox(
                width: SparkSize.modalWide,
                height: dialogHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SparkSpace.xl,
                    SparkSpace.xl,
                    SparkSpace.xl,
                    SparkSpace.md,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: goBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                            splashRadius: 20,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  text: titleForStep(step),
                                  size: SparkTextSize.title,
                                  weight: FontWeight.w700,
                                ),
                                if (currentBreadcrumb.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: SparkSpace.xxs,
                                    ),
                                    child: MyText(
                                      text: currentBreadcrumb,
                                      size: SparkTextSize.body,
                                      color: kGreyColor,
                                      maxLines: 1,
                                      textOverflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SparkSpace.md),
                      if (showSearch) ...[
                        TextField(
                          onTapOutside: (_) => _dismissKeyboard(),
                          onChanged: (value) {
                            setLocalState(() {
                              search = value;
                            });
                          },
                          decoration: _fieldDecoration(searchHint),
                        ),
                        const SizedBox(height: SparkSpace.md),
                      ],
                      Expanded(child: listContent()),
                      const SizedBox(height: SparkSpace.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Отмена'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selection == null || !mounted) return;
    _setStateSafely(() {
      _brandController.text = selection.brand;
      _modelController.text = selection.model;
      _generationController.text = selection.generation;
      _restylingLabel = selection.restyling;
      _carFrames = selection.frames;
      _carPhotoUrl = selection.photoUrl;
    });
  }
}

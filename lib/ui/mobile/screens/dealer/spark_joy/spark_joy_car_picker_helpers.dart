part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCarPickerHelpers on _SparkJoyCreateReportScreenState {
  Future<void> _openCarPickerDialog() async {
    if (_carPickerOpening) return;
    _carPickerOpening = true;
    try {
      await _openCarPickerDialogBody();
    } finally {
      _carPickerOpening = false;
    }
  }

  Future<void> _openCarPickerDialogBody() async {
    bool same(String left, String right) {
      return left.trim().toLowerCase() == right.trim().toLowerCase();
    }

    // Brand/model labels always use the English name. Russian variants are
    // still used for search matching below, but never shown in UI.
    String brandLabel(storage_api.BrandItem brand) {
      final name = brand.name.trim();
      if (name.isNotEmpty) return name;
      return brand.nameRus.trim();
    }

    String modelLabel(storage_api.ModelItem model) {
      final name = model.model.trim();
      if (name.isNotEmpty) return name;
      return model.modelRus.trim();
    }

    _CarCatalogBrand? selectedBrand;
    _CarCatalogModel? selectedModel;
    _CarCatalogGeneration? selectedGeneration;
    storage_api.BrandItem? selectedRemoteBrand;
    storage_api.ModelItem? selectedRemoteModel;
    List<storage_api.BrandItem> remoteBrands = const [];
    final remoteModelsByBrandId = <int, List<storage_api.ModelItem>>{};
    final remoteGenerationsByModelId = <int, List<_CarCatalogGeneration>>{};
    var remoteModelsLoading = false;
    var remoteModelsFailed = false;
    var remoteGenerationsLoading = false;
    var remoteGenerationsFailed = false;
    var useRemoteCatalog = false;
    const remoteCatalogLoadTimeout = Duration(seconds: 12);
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

    _CarCatalogBrand? findLocalBrandForRemote(
      storage_api.BrandItem remoteBrand,
    ) {
      for (final item in _SparkJoyVehicleRegistry.carCatalog) {
        if (same(item.name, remoteBrand.name) ||
            same(item.name, remoteBrand.nameRus)) {
          return item;
        }
      }
      return null;
    }

    _CarCatalogModel? findLocalModelForRemote(
      _CarCatalogBrand localBrand,
      storage_api.ModelItem remoteModel,
    ) {
      for (final item in localBrand.models) {
        if (same(item.name, remoteModel.model) ||
            same(item.name, remoteModel.modelRus)) {
          return item;
        }
      }
      return null;
    }

    Future<List<storage_api.ModelItem>> loadRemoteModels(
      storage_api.BrandItem brand,
    ) async {
      final cached = remoteModelsByBrandId[brand.id];
      if (cached != null) return cached;
      final models = await storage_api.StorageApi.fetchModels(
        brandId: brand.id,
      );
      remoteModelsByBrandId[brand.id] = models;
      return models;
    }

    _CarCatalogGeneration mapRemoteGeneration(
      storage_api.GenerationItem source,
    ) {
      final restylings = source.restylings.map((restyling) {
        final years = [
          if (restyling.yearStart != null) restyling.yearStart.toString(),
          if (restyling.yearEnd != null) restyling.yearEnd.toString(),
        ].join('-');
        final frames = restyling.frames.map((item) => item.frame).join(', ');
        final frameIds = restyling.frames
            .map((item) => item.id)
            .where((id) => id > 0)
            .toList(growable: false);
        final photo = restyling.photos.firstWhere(
          (item) =>
              item.urlX2.trim().isNotEmpty || item.urlX1.trim().isNotEmpty,
          orElse: () =>
              storage_api.PhotoItem(id: 0, size: '', urlX1: '', urlX2: ''),
        );
        final photoUrl = photo.urlX2.trim().isNotEmpty
            ? photo.urlX2.trim()
            : photo.urlX1.trim();
        final labelParts = <String>[
          if (restyling.restyling.trim().isNotEmpty) restyling.restyling.trim(),
          if (years.isNotEmpty) years,
        ];
        return _CarCatalogRestyling(
          label: labelParts.isEmpty ? 'Рестайлинг' : labelParts.join(' · '),
          frames: frames,
          photoUrl: photoUrl,
          frameIds: frameIds,
        );
      }).toList();

      if (restylings.isEmpty) {
        final frames = source.frames.map((item) => item.frame).join(', ');
        final frameIds = source.frames
            .map((item) => item.id)
            .where((id) => id > 0)
            .toList(growable: false);
        restylings.add(
          _CarCatalogRestyling(
            label: 'Базовая версия',
            frames: frames,
            photoUrl: '',
            frameIds: frameIds,
          ),
        );
      }

      return _CarCatalogGeneration(
        name: source.generation.toString(),
        restylings: restylings,
      );
    }

    Future<List<_CarCatalogGeneration>> loadRemoteGenerations(
      storage_api.ModelItem model,
    ) async {
      final cached = remoteGenerationsByModelId[model.id];
      if (cached != null) return cached;
      final generations = await storage_api.StorageApi.fetchGenerations(
        modelCarId: model.id,
      );
      final mapped = generations.map(mapRemoteGeneration).toList();
      remoteGenerationsByModelId[model.id] = mapped;
      return mapped;
    }

    bool matchesRemoteBrand(storage_api.BrandItem brand, String savedValue) {
      return same(brand.name, savedValue) || same(brand.nameRus, savedValue);
    }

    bool matchesRemoteModel(storage_api.ModelItem model, String savedValue) {
      return same(model.model, savedValue) || same(model.modelRus, savedValue);
    }

    try {
      final catalog = await storage_api.StorageApi.fetchBrandCatalog();
      if (catalog.items.isNotEmpty) {
        // Keep the backend order — it already returns brands sorted by
        // popularity. The previous alphabetical re-sort overrode that (T3).
        remoteBrands = List<storage_api.BrandItem>.from(catalog.items);
        useRemoteCatalog = true;
      }
    } catch (_) {
      useRemoteCatalog = false;
    }

    if (useRemoteCatalog) {
      for (final brand in remoteBrands) {
        if (!matchesRemoteBrand(brand, savedBrand)) continue;
        selectedRemoteBrand = brand;
        selectedBrand ??= findLocalBrandForRemote(brand);
        break;
      }

      if (selectedRemoteBrand != null && savedModel.isNotEmpty) {
        try {
          final models = await loadRemoteModels(selectedRemoteBrand);
          for (final model in models) {
            if (!matchesRemoteModel(model, savedModel)) continue;
            selectedRemoteModel = model;
            if (selectedBrand != null) {
              selectedModel = findLocalModelForRemote(selectedBrand, model);
            }
            break;
          }
        } catch (_) {}
      }

      if (selectedRemoteModel != null &&
          !remoteGenerationsByModelId.containsKey(selectedRemoteModel.id)) {
        try {
          await loadRemoteGenerations(selectedRemoteModel);
        } catch (_) {}
      }

      if (selectedRemoteModel != null && savedGeneration.isNotEmpty) {
        try {
          final generations = await loadRemoteGenerations(selectedRemoteModel);
          for (final generation in generations) {
            final label = 'Поколение ${generation.name}';
            if (!same(generation.name, savedGeneration) &&
                !same(label, savedGeneration)) {
              continue;
            }
            selectedGeneration = generation;
            break;
          }
        } catch (_) {}
      }
    }

    if (selectedBrand != null &&
        (selectedRemoteBrand == null || !useRemoteCatalog)) {
      step = _CarPickerStep.model;
    }
    if (selectedModel != null) {
      step = _CarPickerStep.generation;
    }
    if (selectedGeneration != null && savedRestyling.isNotEmpty) {
      step = _CarPickerStep.restyling;
    }
    if (useRemoteCatalog &&
        selectedRemoteModel != null &&
        selectedGeneration == null) {
      step = _CarPickerStep.generation;
    }
    if (useRemoteCatalog &&
        selectedRemoteBrand != null &&
        selectedRemoteModel == null &&
        selectedModel == null) {
      step = _CarPickerStep.model;
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
        if (selectedBrand != null)
          selectedBrand!.name
        else if (selectedRemoteBrand != null)
          brandLabel(selectedRemoteBrand!),
        if (selectedModel != null)
          selectedModel!.name
        else if (selectedRemoteModel != null)
          modelLabel(selectedRemoteModel!),
        if (selectedGeneration != null && step == _CarPickerStep.restyling)
          'Пок. ${selectedGeneration!.name}',
      ];
      return parts.join(' -> ');
    }

    _CarPickerSelection? buildSelection(_CarCatalogRestyling restyling) {
      final brand = selectedBrand?.name ?? selectedRemoteBrand?.name ?? '';
      final model = selectedModel?.name ?? selectedRemoteModel?.model ?? '';
      if (brand.trim().isEmpty ||
          model.trim().isEmpty ||
          selectedGeneration == null) {
        return null;
      }
      return _CarPickerSelection(
        brand: brand,
        model: model,
        generation: selectedGeneration!.name,
        restyling: restyling.label,
        frames: restyling.frames,
        photoUrl: restyling.photoUrl,
        frameId: restyling.frameIds.isNotEmpty
            ? restyling.frameIds.first
            : null,
      );
    }

    _CarPickerSelection buildSelectionForModel({
      required String brand,
      required String model,
    }) {
      return _CarPickerSelection(
        brand: brand,
        model: model,
        generation: '',
        restyling: '',
        frames: '',
        photoUrl: '',
      );
    }

    if (!mounted) return;
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
                  selectedRemoteBrand = null;
                  selectedRemoteModel = null;
                  remoteModelsLoading = false;
                  remoteModelsFailed = false;
                  remoteGenerationsLoading = false;
                  remoteGenerationsFailed = false;
                  search = '';
                  return;
                }
                if (step == _CarPickerStep.generation) {
                  step = _CarPickerStep.model;
                  selectedModel = null;
                  selectedGeneration = null;
                  selectedRemoteModel = null;
                  remoteGenerationsLoading = false;
                  remoteGenerationsFailed = false;
                  search = '';
                  return;
                }
                if (step == _CarPickerStep.restyling) {
                  step = _CarPickerStep.generation;
                  search = '';
                }
              });
            }

            Widget pickerEmpty(IconData icon, String title) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: SparkSpace.xxxl),
                child: Center(
                  child: SparkEmptyState(icon: icon, title: title, topPadding: 0),
                ),
              );
            }

            Widget listContent() {
              if (step == _CarPickerStep.brand) {
                if (useRemoteCatalog) {
                  final brands = remoteBrands
                      .where(
                        (brand) => search.trim().isEmpty
                            ? true
                            : [
                                brand.name.trim().toLowerCase(),
                                brand.nameRus.trim().toLowerCase(),
                              ].any(
                                (value) =>
                                    value.contains(search.trim().toLowerCase()),
                              ),
                      )
                      .toList();
                  if (brands.isEmpty) {
                    return pickerEmpty(
                      Icons.search_off_rounded,
                      'Ничего не найдено',
                    );
                  }
                  return ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: brands.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final brand = brands[index];
                      final title = brandLabel(brand);
                      return ListTile(
                        title: Text(title),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          setLocalState(() {
                            selectedRemoteBrand = brand;
                            selectedRemoteModel = null;
                            selectedBrand = findLocalBrandForRemote(brand);
                            selectedModel = null;
                            selectedGeneration = null;
                            step = _CarPickerStep.model;
                            search = '';
                            remoteModelsLoading = true;
                            remoteModelsFailed = false;
                            remoteGenerationsLoading = false;
                            remoteGenerationsFailed = false;
                          });
                          var failed = false;
                          try {
                            await loadRemoteModels(
                              brand,
                            ).timeout(remoteCatalogLoadTimeout);
                          } catch (_) {
                            failed = true;
                          } finally {
                            if (mounted) {
                              setLocalState(() {
                                remoteModelsLoading = false;
                                remoteModelsFailed = failed;
                              });
                            }
                          }
                        },
                      );
                    },
                  );
                }

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
                  return pickerEmpty(
                    Icons.search_off_rounded,
                    'Ничего не найдено',
                  );
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
                if (useRemoteCatalog) {
                  final remoteBrand = selectedRemoteBrand;
                  if (remoteBrand == null) {
                    return pickerEmpty(
                      Icons.arrow_upward_rounded,
                      'Сначала выберите марку',
                    );
                  }

                  final remoteModels =
                      remoteModelsByBrandId[remoteBrand.id] ??
                      const <storage_api.ModelItem>[];

                  if (remoteModelsLoading && remoteModels.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (remoteModels.isNotEmpty) {
                    final models = remoteModels
                        .where(
                          (model) => search.trim().isEmpty
                              ? true
                              : [
                                  model.model.trim().toLowerCase(),
                                  model.modelRus.trim().toLowerCase(),
                                ].any(
                                  (value) => value.contains(
                                    search.trim().toLowerCase(),
                                  ),
                                ),
                        )
                        .toList();
                    if (models.isEmpty) {
                      return pickerEmpty(
                        Icons.directions_car_outlined,
                        'Нет моделей',
                      );
                    }
                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: models.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final model = models[index];
                        final title = modelLabel(model);
                        return ListTile(
                          title: Text(title),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final dialogNavigator = Navigator.of(context);
                            final localBrand = selectedBrand;
                            final localModel = localBrand == null
                                ? null
                                : findLocalModelForRemote(localBrand, model);
                            setLocalState(() {
                              selectedRemoteModel = model;
                              selectedModel = localModel;
                              selectedGeneration = null;
                              step = _CarPickerStep.generation;
                              search = '';
                              remoteGenerationsLoading = true;
                              remoteGenerationsFailed = false;
                            });
                            var failed = false;
                            try {
                              await loadRemoteGenerations(
                                model,
                              ).timeout(remoteCatalogLoadTimeout);
                            } catch (_) {
                              failed = true;
                            } finally {
                              if (mounted) {
                                final remoteGenerations =
                                    remoteGenerationsByModelId[model.id] ??
                                    const <_CarCatalogGeneration>[];
                                final localGenerations =
                                    localModel?.generations ??
                                    const <_CarCatalogGeneration>[];
                                if (remoteGenerations.isEmpty &&
                                    localGenerations.isEmpty) {
                                  dialogNavigator.pop(
                                    buildSelectionForModel(
                                      brand: remoteBrand.name,
                                      model: model.model,
                                    ),
                                  );
                                } else {
                                  setLocalState(() {
                                    remoteGenerationsLoading = false;
                                    remoteGenerationsFailed = failed;
                                  });
                                }
                              }
                            }
                          },
                        );
                      },
                    );
                  }

                  if (remoteModelsFailed && selectedBrand != null) {
                    final fallbackModels = selectedBrand!.models
                        .where(
                          (model) => search.trim().isEmpty
                              ? true
                              : model.name.toLowerCase().contains(
                                  search.trim().toLowerCase(),
                                ),
                        )
                        .toList();
                    if (fallbackModels.isNotEmpty) {
                      return ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: fallbackModels.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final model = fallbackModels[index];
                          return ListTile(
                            title: Text(model.name),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              setLocalState(() {
                                selectedRemoteModel = null;
                                selectedModel = model;
                                selectedGeneration = null;
                                step = _CarPickerStep.generation;
                                search = '';
                                remoteGenerationsLoading = false;
                                remoteGenerationsFailed = false;
                              });
                            },
                          );
                        },
                      );
                    }
                  }

                  return pickerEmpty(
                    Icons.directions_car_outlined,
                    'Нет моделей',
                  );
                }

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
                  return pickerEmpty(
                    Icons.directions_car_outlined,
                    'Нет моделей',
                  );
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
                          selectedRemoteModel = null;
                          selectedModel = model;
                          selectedGeneration = null;
                          step = _CarPickerStep.generation;
                          search = '';
                          remoteGenerationsLoading = false;
                          remoteGenerationsFailed = false;
                        });
                      },
                    );
                  },
                );
              }

              if (step == _CarPickerStep.generation) {
                List<_CarCatalogGeneration> generations =
                    selectedModel?.generations ??
                    const <_CarCatalogGeneration>[];
                if (useRemoteCatalog && selectedRemoteModel != null) {
                  final remoteGenerations =
                      remoteGenerationsByModelId[selectedRemoteModel!.id] ??
                      const <_CarCatalogGeneration>[];
                  if (remoteGenerationsLoading && remoteGenerations.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (remoteGenerations.isNotEmpty) {
                    generations = remoteGenerations;
                  } else if (remoteGenerationsFailed && generations.isEmpty) {
                    return pickerEmpty(
                      Icons.layers_outlined,
                      'Нет поколений',
                    );
                  }
                }
                if (generations.isEmpty) {
                  return pickerEmpty(
                    Icons.layers_outlined,
                    'Нет поколений',
                  );
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  // +1 leading row: «Без модификации» finalizes at the model
                  // level (skip поколение/модификацию) — useful when there
                  // is no actual modification or it's unknown.
                  itemCount: generations.length + 1,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: kSecondaryColor,
                        ),
                        title: const Text('Без модификации'),
                        subtitle: const Text('Остановиться на модели'),
                        onTap: () {
                          final brand =
                              selectedBrand?.name ??
                              selectedRemoteBrand?.name ??
                              '';
                          final model =
                              selectedModel?.name ??
                              selectedRemoteModel?.model ??
                              '';
                          Navigator.of(context).pop(
                            buildSelectionForModel(brand: brand, model: model),
                          );
                        },
                      );
                    }
                    final generation = generations[index - 1];
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
                return pickerEmpty(
                  Icons.tune_rounded,
                  'Нет рестайлингов',
                );
              }
              return ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: restylings.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final restyling = restylings[index];
                  return ListTile(
                    leading: restyling.photoUrl.trim().isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(SparkRadius.sm),
                            child: Image.network(
                              restyling.photoUrl,
                              width: SparkSize.inputHeight,
                              height: SparkSize.inputHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: SparkSize.inputHeight,
                                  height: SparkSize.inputHeight,
                                  alignment: Alignment.center,
                                  color: kLightGreyColor,
                                  child: const Icon(
                                    Icons.directions_car_outlined,
                                    color: kGreyColor,
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            width: SparkSize.inputHeight,
                            height: SparkSize.inputHeight,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kLightGreyColor,
                              borderRadius: BorderRadius.circular(
                                SparkRadius.sm,
                              ),
                            ),
                            child: const Icon(
                              Icons.directions_car_outlined,
                              color: kGreyColor,
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
      _modelGenerationRestylingFrameId = selection.frameId;
    });
    // Persist a frame-id → metadata entry so the completed-report
    // hydrator can restore brand/model/generation/restyling/photoUrl
    // when the user (or another device owned by them) opens the same
    // finalized report later. Fire-and-forget — a failure just means
    // the hydrator will show placeholders.
    final frameId = selection.frameId;
    if (frameId != null && frameId > 0) {
      unawaited(
        SparkJoyStorage.upsertFrameCatalogEntry(
          frameId: frameId,
          entry: <String, dynamic>{
            'brand': selection.brand,
            'model': selection.model,
            'generation': selection.generation,
            'restyling': selection.restyling,
            'frames': selection.frames,
            'photoUrl': selection.photoUrl,
          },
        ),
      );
    }
  }
}

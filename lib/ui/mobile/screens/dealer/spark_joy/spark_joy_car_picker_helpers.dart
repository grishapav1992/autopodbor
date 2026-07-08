part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCarPickerHelpers on _SparkJoyCreateReportScreenState {
  /// [startAt] — с какого шага открыть визард: тапы по полям «Марка» /
  /// «Модель» / «Поколение» шага «Автомобиль» ведут на соответствующий
  /// шаг; null (кнопка «Выбрать из каталога») — «умное» продолжение с
  /// места текущей привязки.
  Future<void> _openCarPickerDialog({_CarPickerStep? startAt}) async {
    if (_carPickerOpening) return;
    _carPickerOpening = true;
    try {
      await _openCarPickerDialogBody(startAt: startAt);
    } finally {
      _carPickerOpening = false;
    }
  }

  Future<void> _openCarPickerDialogBody({_CarPickerStep? startAt}) async {
    final catalog = CarCatalogRepository.instance;

    // Строгий режим: каталог — единственный источник авто (бэк принимает
    // только ID). Кэша ещё нет И сети нет → пикер не открываем: объясняем,
    // пинаем фоновый синк — при появлении сети каталог доедет сам.
    List<storage_api.BrandItem> brands;
    try {
      brands = await catalog.getBrands();
    } catch (_) {
      unawaited(CarCatalogSyncService.instance.start());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Каталог авто ещё не загружен. Подключите интернет — '
            'каталог сохранится и дальше будет работать офлайн.',
          ),
          action: SnackBarAction(
            label: 'Повторить',
            onPressed: () => unawaited(_openCarPickerDialog(startAt: startAt)),
          ),
        ),
      );
      return;
    }

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

    storage_api.BrandItem? selectedBrand;
    storage_api.ModelItem? selectedModel;
    _CarCatalogGeneration? selectedGeneration;
    final generationsByModelId = <int, List<_CarCatalogGeneration>>{};
    var modelsLoading = false;
    var modelsFailed = false;
    var generationsLoading = false;
    var generationsFailed = false;
    const catalogLoadTimeout = Duration(seconds: 12);
    _CarPickerStep step = _CarPickerStep.brand;
    var search = '';

    final savedBrand = _brandController.text.trim();
    final savedModel = _modelController.text.trim();
    final savedGeneration = _generationController.text.trim();
    final savedRestyling = _restylingLabel.trim();

    // Репозиторий мемоизирует и офлайн отдаёт персист — диалогу свой кэш
    // моделей не нужен.
    Future<List<storage_api.ModelItem>> loadModels(
      storage_api.BrandItem brand,
    ) {
      return catalog.getModels(brand.id);
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

    Future<List<_CarCatalogGeneration>> loadGenerations(
      storage_api.ModelItem model,
    ) async {
      final cached = generationsByModelId[model.id];
      if (cached != null) return cached;
      final generations = await catalog.getGenerations(model.id);
      final mapped = generations.map(mapRemoteGeneration).toList();
      generationsByModelId[model.id] = mapped;
      return mapped;
    }

    // ── Пре-резолв текущей привязки: сперва по сохранённым ID (строгий
    // режим их всегда пишет), затем по имени (легаси-черновики со
    // свободным текстом).
    final savedBrandId = _selectedBrandId;
    if (savedBrandId != null) {
      for (final brand in brands) {
        if (brand.id == savedBrandId) {
          selectedBrand = brand;
          break;
        }
      }
    }
    if (selectedBrand == null && savedBrand.isNotEmpty) {
      for (final brand in brands) {
        if (same(brand.name, savedBrand) || same(brand.nameRus, savedBrand)) {
          selectedBrand = brand;
          break;
        }
      }
    }

    final preBrand = selectedBrand;
    if (preBrand != null) {
      try {
        final models = await loadModels(preBrand);
        final savedModelId = _selectedModelCarId;
        if (savedModelId != null) {
          for (final model in models) {
            if (model.id == savedModelId) {
              selectedModel = model;
              break;
            }
          }
        }
        if (selectedModel == null && savedModel.isNotEmpty) {
          for (final model in models) {
            if (same(model.model, savedModel) ||
                same(model.modelRus, savedModel)) {
              selectedModel = model;
              break;
            }
          }
        }
      } catch (_) {
        // Офлайн и моделей этой марки ещё нет в кэше — шаг модели покажет
        // офлайн-состояние с «Повторить».
        modelsFailed = true;
      }
    }

    final preModel = selectedModel;
    if (preModel != null) {
      try {
        final generations = await loadGenerations(preModel);
        if (savedGeneration.isNotEmpty) {
          for (final generation in generations) {
            final label = 'Поколение ${generation.name}';
            if (same(generation.name, savedGeneration) ||
                same(label, savedGeneration)) {
              selectedGeneration = generation;
              break;
            }
          }
        }
      } catch (_) {
        generationsFailed = true;
      }
    }

    if (selectedBrand != null) step = _CarPickerStep.model;
    if (selectedModel != null) step = _CarPickerStep.generation;
    if (selectedGeneration != null && savedRestyling.isNotEmpty) {
      step = _CarPickerStep.restyling;
    }

    // Явная точка входа с конкретного поля шага «Автомобиль».
    if (startAt != null) {
      switch (startAt) {
        case _CarPickerStep.brand:
          step = _CarPickerStep.brand;
        case _CarPickerStep.model:
          step = selectedBrand != null
              ? _CarPickerStep.model
              : _CarPickerStep.brand;
        case _CarPickerStep.generation:
          step = selectedModel != null
              ? _CarPickerStep.generation
              : (selectedBrand != null
                    ? _CarPickerStep.model
                    : _CarPickerStep.brand);
        case _CarPickerStep.restyling:
          break; // естественный step уже максимально глубокий
      }
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
      final brand = selectedBrand;
      final model = selectedModel;
      final parts = <String>[
        if (brand != null) brandLabel(brand),
        if (model != null) modelLabel(model),
        if (selectedGeneration != null && step == _CarPickerStep.restyling)
          'Пок. ${selectedGeneration!.name}',
      ];
      return parts.join(' -> ');
    }

    _CarPickerSelection? buildSelection(_CarCatalogRestyling restyling) {
      final brand = selectedBrand;
      final model = selectedModel;
      final generation = selectedGeneration;
      if (brand == null || model == null || generation == null) {
        return null;
      }
      return _CarPickerSelection(
        brand: brand.name,
        model: model.model,
        generation: generation.name,
        restyling: restyling.label,
        frames: restyling.frames,
        photoUrl: restyling.photoUrl,
        frameId: restyling.frameIds.isNotEmpty
            ? restyling.frameIds.first
            : null,
        brandId: brand.id,
        modelCarId: model.id,
      );
    }

    // Финализация на уровне модели («Без модификации» / у модели нет
    // поколений в каталоге): brandId+modelCarId достаточно для выгрузки.
    _CarPickerSelection? buildSelectionForModel() {
      final brand = selectedBrand;
      final model = selectedModel;
      if (brand == null || model == null) return null;
      return _CarPickerSelection(
        brand: brand.name,
        model: model.model,
        generation: '',
        restyling: '',
        frames: '',
        photoUrl: '',
        brandId: brand.id,
        modelCarId: model.id,
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
                  modelsLoading = false;
                  modelsFailed = false;
                  generationsLoading = false;
                  generationsFailed = false;
                  search = '';
                  return;
                }
                if (step == _CarPickerStep.generation) {
                  step = _CarPickerStep.model;
                  selectedModel = null;
                  selectedGeneration = null;
                  generationsLoading = false;
                  generationsFailed = false;
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
                  child: SparkEmptyState(
                    icon: icon,
                    title: title,
                    topPadding: 0,
                  ),
                ),
              );
            }

            // Офлайн-состояние шага: этой части каталога ещё нет в кэше.
            Widget pickerRetry(String title, Future<void> Function() onRetry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: SparkSpace.xxxl),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SparkEmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: title,
                        topPadding: 0,
                      ),
                      const SizedBox(height: SparkSpace.sm),
                      TextButton(
                        onPressed: () => unawaited(onRetry()),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              );
            }

            Future<void> reloadModels(storage_api.BrandItem brand) async {
              setLocalState(() {
                modelsLoading = true;
                modelsFailed = false;
              });
              var failed = false;
              try {
                await loadModels(brand).timeout(catalogLoadTimeout);
              } catch (_) {
                failed = true;
              } finally {
                if (mounted) {
                  setLocalState(() {
                    modelsLoading = false;
                    modelsFailed = failed;
                  });
                }
              }
            }

            Future<void> reloadGenerations(storage_api.ModelItem model) async {
              setLocalState(() {
                generationsLoading = true;
                generationsFailed = false;
              });
              var failed = false;
              try {
                await loadGenerations(model).timeout(catalogLoadTimeout);
              } catch (_) {
                failed = true;
              } finally {
                if (mounted) {
                  setLocalState(() {
                    generationsLoading = false;
                    generationsFailed = failed;
                  });
                }
              }
            }

            Widget listContent() {
              if (step == _CarPickerStep.brand) {
                final query = search.trim().toLowerCase();
                final filtered = brands
                    .where(
                      (brand) => query.isEmpty
                          ? true
                          : [
                              brand.name.trim().toLowerCase(),
                              brand.nameRus.trim().toLowerCase(),
                            ].any((value) => value.contains(query)),
                    )
                    .toList();
                if (filtered.isEmpty) {
                  return pickerEmpty(
                    Icons.search_off_rounded,
                    'Ничего не найдено',
                  );
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final brand = filtered[index];
                    return ListTile(
                      title: Text(brandLabel(brand)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        setLocalState(() {
                          selectedBrand = brand;
                          selectedModel = null;
                          selectedGeneration = null;
                          step = _CarPickerStep.model;
                          search = '';
                          generationsLoading = false;
                          generationsFailed = false;
                        });
                        await reloadModels(brand);
                      },
                    );
                  },
                );
              }

              if (step == _CarPickerStep.model) {
                final brand = selectedBrand;
                if (brand == null) {
                  return pickerEmpty(
                    Icons.arrow_upward_rounded,
                    'Сначала выберите марку',
                  );
                }

                final models = catalog.searchModels(brand.id, search);
                if (modelsLoading && models.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (modelsFailed && models.isEmpty) {
                  return pickerRetry(
                    'Модели этой марки ещё не в офлайн-каталоге.\nПроверьте интернет и повторите',
                    () => reloadModels(brand),
                  );
                }
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
                      title: Text(modelLabel(model)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final dialogNavigator = Navigator.of(context);
                        setLocalState(() {
                          selectedModel = model;
                          selectedGeneration = null;
                          step = _CarPickerStep.generation;
                          search = '';
                          generationsLoading = true;
                          generationsFailed = false;
                        });
                        var failed = false;
                        try {
                          await loadGenerations(
                            model,
                          ).timeout(catalogLoadTimeout);
                        } catch (_) {
                          failed = true;
                        } finally {
                          if (mounted) {
                            final generations =
                                generationsByModelId[model.id] ??
                                const <_CarCatalogGeneration>[];
                            var finalized = false;
                            if (!failed && generations.isEmpty) {
                              // У модели нет поколений в каталоге — честно
                              // финализируемся на уровне модели (ID есть).
                              final selection = buildSelectionForModel();
                              if (selection != null) {
                                dialogNavigator.pop(selection);
                                finalized = true;
                              }
                            }
                            if (!finalized) {
                              setLocalState(() {
                                generationsLoading = false;
                                generationsFailed = failed;
                              });
                            }
                          }
                        }
                      },
                    );
                  },
                );
              }

              if (step == _CarPickerStep.generation) {
                final model = selectedModel;
                if (model == null) {
                  return pickerEmpty(
                    Icons.arrow_upward_rounded,
                    'Сначала выберите модель',
                  );
                }
                final generations =
                    generationsByModelId[model.id] ??
                    const <_CarCatalogGeneration>[];
                if (generationsLoading && generations.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (generations.isEmpty) {
                  // Пусто из-за офлайна (поколения ещё не в кэше) или их нет
                  // в каталоге вовсе. В обоих случаях выбор можно честно
                  // завершить на уровне модели — для выгрузки достаточно
                  // modelCarId; поколение/рестайлинг/фото уточнятся позже,
                  // когда каталог доедет. Иначе офлайн-пользователь застрял
                  // бы на «Повторить» с уже выбранными маркой и моделью.
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: kSecondaryColor,
                        ),
                        title: const Text('Без модификации'),
                        subtitle: const Text('Остановиться на модели'),
                        onTap: () {
                          final selection = buildSelectionForModel();
                          if (selection == null) return;
                          Navigator.of(context).pop(selection);
                        },
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: generationsFailed
                            ? pickerRetry(
                                'Поколения этой модели ещё не в офлайн-каталоге.\nПроверьте интернет и повторите',
                                () => reloadGenerations(model),
                              )
                            : pickerEmpty(
                                Icons.layers_outlined,
                                'Нет поколений',
                              ),
                      ),
                    ],
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
                          final selection = buildSelectionForModel();
                          if (selection == null) return;
                          Navigator.of(context).pop(selection);
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
                return pickerEmpty(Icons.tune_rounded, 'Нет рестайлингов');
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
      // Каталожная привязка из пикера → селекторы марки/модели сразу
      // консистентны (модели подтянутся для этого brandId).
      _selectedBrandId = selection.brandId;
      _selectedModelCarId = selection.modelCarId;
    });
    _markDraftDirty();
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

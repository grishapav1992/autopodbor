part of 'spark_joy_create_report_screen.dart';

/// Источник запроса в api-cloud.ru/converter — определяет, какое поле
/// было инициатором (влияет только на snackbar-сообщение).
enum _ConverterSource { vin, plate }

/// Мост между [ConverterApi] и контроллерами формы авто.
///
/// Общая идея: юзер жмёт кнопку «Подтянуть ГРЗ и данные авто» или
/// «Подтянуть VIN и данные авто». Мы выясняем, что уже введено, дёргаем
/// API, если нашлось — применяем (с подтверждением при конфликтах) и
/// фоново пытаемся сматчить в локальный каталог марок/моделей, чтобы
/// подставить поколение и `modelGenerationRestylingFrameId`.
///
/// Сетевой слой (`ConverterApi`) сам разбирается с offline/timeout —
/// сюда прилетает уже [ConverterException] с `userMessage`. Форма
/// целиком работает и без этих кнопок — если интернета нет, юзер
/// заполнит поля вручную, а снекбар скажет, почему помощник не
/// сработал.
///
/// Про `// ignore: invalid_use_of_protected_member` на `setState`:
/// `setState` у `State<T>` помечен `@protected`, а мы зовём его из
/// extension'а. В рантайме всё работает (Dart допускает), анализатор
/// ругается. Часто практикуемый обход (см., например, flutter_hooks и
/// тонну packages на pub.dev) — локальный ignore-комментарий. Поднимать
/// выделенный `reassemble()`-wrapper в `State` ради четырёх мест
/// перебор: это не скрытое нарушение инкапсуляции, а осознанный
/// использование protected API в том же классе, просто вынесенное в
/// `part of`-extension ради навигации.
extension _SparkJoyConverterHelpers on _SparkJoyCreateReportScreenState {
  /// Валидность VIN для lookup (17 символов, допустимые символы).
  bool _canLookupByVin() {
    final vin = _vinController.text.trim().toUpperCase();
    if (vin.length != 17) return false;
    return RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin);
  }

  /// Валидность ГРЗ для lookup — используем существующий `_plateError`,
  /// чтобы логика не расходилась с валидацией самого поля.
  bool _canLookupByPlate() {
    final plate = _sanitizePlate(_plateController.text);
    if (plate.isEmpty) return false;
    return _plateError() == null;
  }

  /// Главная точка входа. Источник ([source]) определяет только UX —
  /// API один и тот же.
  Future<void> _lookupByVinOrPlate(_ConverterSource source) async {
    if (_converterLoading) return;

    final query = source == _ConverterSource.vin
        ? _vinController.text.trim().toUpperCase()
        : _sanitizePlate(_plateController.text);

    if (query.isEmpty) return;

    // ignore: invalid_use_of_protected_member
    setState(() => _converterLoading = true);

    ConverterResult? result;
    String? errorMessage;
    try {
      result = await ConverterApi.instance().lookup(query);
    } on ConverterException catch (e) {
      // Для пользователя — userMessage (admin-коды скрыты за
      // обобщённым «временно недоступен»). Диагностика — в лог.
      developer.log(
        'converter lookup failed: ${e.diagnosticMessage} (kind=${e.kind.name})',
        name: 'SparkJoy.Converter',
      );
      errorMessage = e.userMessage;
    } catch (e, stack) {
      developer.log(
        'converter lookup unexpected',
        name: 'SparkJoy.Converter',
        error: e,
        stackTrace: stack,
      );
      errorMessage = 'Не удалось подтянуть данные. Попробуйте позже.';
    }

    if (!mounted) return;
    // ignore: invalid_use_of_protected_member
    setState(() => _converterLoading = false);

    if (errorMessage != null) {
      _showConverterSnack(errorMessage);
      return;
    }

    if (result == null || !result.found) {
      _showConverterSnack(
        'По этому ${source == _ConverterSource.vin ? "VIN" : "госномеру"} '
        'данных не найдено. Введите оставшиеся поля вручную.',
      );
      return;
    }

    // Если какие-то поля уже заполнены и РАСХОДЯТСЯ с найденным —
    // спрашиваем. Совпадения не считаем конфликтом.
    final conflicts = _detectConverterConflicts(result);
    if (conflicts.isNotEmpty) {
      final accepted = await _showConverterConfirmDialog(result, conflicts);
      if (accepted != true) return;
    }

    await _applyConverterResult(result, source);

    final summary = <String>[
      if (result.brandModel.isNotEmpty) result.brandModel,
      if (result.year > 0) '${result.year}',
    ].join(', ');
    _showConverterSnack(
      summary.isEmpty ? 'Данные подтянуты' : 'Данные подтянуты: $summary',
    );
  }

  List<String> _detectConverterConflicts(ConverterResult r) {
    bool diff(String current, String incoming) {
      if (current.trim().isEmpty) return false;
      if (incoming.isEmpty) return false;
      return current.trim().toLowerCase() != incoming.trim().toLowerCase();
    }

    final conflicts = <String>[];
    if (diff(_brandController.text, r.brand)) conflicts.add('Марка');
    if (diff(_modelController.text, r.model)) conflicts.add('Модель');
    // Для VIN сравниваем в верхнем регистре — юзер мог ввести как-то иначе.
    if (diff(_vinController.text.toUpperCase(), r.vin.toUpperCase())) {
      conflicts.add('VIN');
    }
    // Для ГРЗ нормализуем обе стороны (латиница→кириллица, без пробелов),
    // иначе «А001АА 77» и «А001АА77» будут выглядеть как конфликт.
    final currentPlate = _sanitizePlate(_plateController.text);
    final incomingPlate = _sanitizePlate(r.regNumber);
    if (currentPlate.isNotEmpty &&
        incomingPlate.isNotEmpty &&
        currentPlate != incomingPlate) {
      conflicts.add('Госномер');
    }
    if (r.year > 0 && _generationController.text.trim().isNotEmpty) {
      // Поколение не сравниваем точно — там «Поколение 6», а у API только
      // год. Считаем поколение потенциальным конфликтом, если оно вручную
      // выставлено.
      conflicts.add('Поколение');
    }
    return conflicts;
  }

  Future<bool?> _showConverterConfirmDialog(
    ConverterResult r,
    List<String> conflicts,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заменить введённые данные?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('По запросу нашлось:'),
              const SizedBox(height: SparkSpace.sm),
              if (r.brandModel.isNotEmpty) Text('• ${r.brandModel}'),
              if (r.year > 0) Text('• Год: ${r.year}'),
              if (r.vin.isNotEmpty) Text('• VIN: ${r.vin}'),
              if (r.regNumber.isNotEmpty) Text('• Госномер: ${r.regNumber}'),
              const SizedBox(height: SparkSpace.md),
              Text(
                'Расходятся с введёнными: ${conflicts.join(", ")}.',
                style: const TextStyle(color: kGreyColor),
              ),
              const SizedBox(height: SparkSpace.sm),
              const Text(
                'Если на госномере была смена авто, в ответе могут '
                'оказаться данные предыдущего владельца.',
                style: TextStyle(fontSize: 11, color: kGreyColor),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Оставить моё'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Заменить'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyConverterResult(
    ConverterResult r,
    _ConverterSource source,
  ) async {
    // VIN/ГРЗ заполняем противоположное полю-источнику. Если source=vin,
    // пользователь и так уже написал VIN; подтягиваем только ГРЗ.
    if (source == _ConverterSource.vin && r.regNumber.isNotEmpty) {
      final formatted = _formatPlate(_sanitizePlate(r.regNumber));
      _plateController.text = formatted;
    }
    if (source == _ConverterSource.plate && r.vin.isNotEmpty) {
      _vinController.text = r.vin.toUpperCase();
    }
    if (r.brand.isNotEmpty) _brandController.text = r.brand;
    if (r.model.isNotEmpty) _modelController.text = r.model;

    // Ре-рендер после изменения контроллеров — иначе UI покажет
    // старые значения до следующего «внешнего» rebuild.
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(() {});
    }
    _markDraftDirty();

    // Сматчить в каталог пытаемся фоном — если не получится, юзер
    // руками откроет модалку выбора, она подхватит введённые строки.
    if (r.brand.isNotEmpty && r.model.isNotEmpty && r.year > 0) {
      unawaited(_tryMatchCatalogForConverter(r));
    }
  }

  /// Ищет в `StorageApi` бренд → модель → единственный `RestylingItem`,
  /// чей диапазон лет включает `result.year`. Если всё нашлось —
  /// выставляет `_generationController`, `_restylingLabel` и
  /// `_modelGenerationRestylingFrameId`. Если совпадений 0 или 2+ —
  /// оставляет юзеру выбрать вручную через модалку.
  Future<void> _tryMatchCatalogForConverter(ConverterResult r) async {
    try {
      final catalog = await storage_api.StorageApi.fetchBrandCatalog();

      int? brandId;
      for (final item in catalog.items) {
        if (item.name.toLowerCase() == r.brand.toLowerCase() ||
            item.nameRus.toLowerCase() == r.brand.toLowerCase()) {
          brandId = item.id;
          break;
        }
      }
      if (brandId == null) return;

      final models = await storage_api.StorageApi.fetchModels(
        brandId: brandId,
      );
      storage_api.ModelItem? matchedModel;
      for (final m in models) {
        if (m.model.toLowerCase() == r.model.toLowerCase() ||
            m.modelRus.toLowerCase() == r.model.toLowerCase()) {
          matchedModel = m;
          break;
        }
      }
      if (matchedModel == null) return;

      final gens = await storage_api.StorageApi.fetchGenerations(
        modelCarId: matchedModel.id,
      );

      storage_api.GenerationItem? matchedGen;
      storage_api.RestylingItem? matchedRestyling;
      var matchCount = 0;
      for (final g in gens) {
        for (final rr in g.restylings) {
          final ys = rr.yearStart;
          final ye = rr.yearEnd;
          if (ys == null) continue;
          if (r.year < ys) continue;
          if (ye != null && r.year > ye) continue;
          matchedGen = g;
          matchedRestyling = rr;
          matchCount++;
        }
      }

      if (matchCount != 1 || matchedGen == null || matchedRestyling == null) {
        return;
      }

      final frames = matchedRestyling.frames;
      final frameId = frames.isNotEmpty ? frames.first.id : null;

      if (!mounted) return;
      // ignore: invalid_use_of_protected_member
      setState(() {
        _generationController.text = 'Поколение ${matchedGen!.generation}';
        _restylingLabel = matchedRestyling!.restyling;
        if (frameId != null) {
          _modelGenerationRestylingFrameId = frameId;
        }
      });
      _markDraftDirty();
    } catch (e, stack) {
      developer.log(
        'converter catalog match failed: $e',
        name: 'SparkJoy.Converter',
        error: e,
        stackTrace: stack,
      );
      // Молчаливо — юзер сам выберет через модалку.
    }
  }

  void _showConverterSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

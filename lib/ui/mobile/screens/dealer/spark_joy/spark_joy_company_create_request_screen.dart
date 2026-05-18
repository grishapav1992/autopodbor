import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/data/services/city_repository.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';
import 'package:flutter_application_1/ui/common/widgets/city_picker_bottom_sheet.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_specialist_picker.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Форма создания заявки от компании. Поля:
///  * **Автомобиль** (required): Марка → Модель → Поколение → Рестайлинг
///  * Опционально внутри car-item: телефон продавца, ссылка на объявление
///  * **Заметка** (опционально): свободный текст до 5000 chars
///  * **Параметры подбора** (опционально): город (RU-only picker),
///    бюджет от/до, макс. пробег, макс. число владельцев
///  * **Специалист**: 2-режимный picker (Из штата / По телефону).
///    Реальное назначение пока невозможно — нужны backend-методы
///    `Storage.GetCompanyStaff` + `Storage.FindUserByPhone`. Заявка
///    создаётся без `assignedSpecialistId` + показывается warning.
///  * **Срок** (required): RU-date input с дефолтом +7 дней
class SparkJoyCompanyCreateRequestScreen extends StatefulWidget {
  const SparkJoyCompanyCreateRequestScreen({super.key});

  @override
  State<SparkJoyCompanyCreateRequestScreen> createState() =>
      _SparkJoyCompanyCreateRequestScreenState();
}

class _SparkJoyCompanyCreateRequestScreenState
    extends State<SparkJoyCompanyCreateRequestScreen> {
  // Car picker state
  BrandItem? _brand;
  ModelItem? _model;
  GenerationItem? _generation;
  RestylingItem? _restyling;

  // Car-item optional fields
  final _sellerPhoneController = TextEditingController();
  final _sellerUrlController = TextEditingController();

  // Optional search params
  String _city = '';
  final _budgetFromController = TextEditingController();
  final _budgetToController = TextEditingController();
  final _maxMileageController = TextEditingController();
  final _ownersCountController = TextEditingController();

  // Specialist
  SelectedAssignee? _assignee;

  // Due date
  final _dueAtController = TextEditingController();

  // Note
  final _noteController = TextEditingController();

  // Submit state
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final defaultDue = DateTime.now().add(const Duration(days: 7));
    _dueAtController.text = _formatRuDate(defaultDue);
  }

  @override
  void dispose() {
    _sellerPhoneController.dispose();
    _sellerUrlController.dispose();
    _budgetFromController.dispose();
    _budgetToController.dispose();
    _maxMileageController.dispose();
    _ownersCountController.dispose();
    _dueAtController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ─── Car pickers ────────────────────────────────────────────────────

  Future<void> _pickBrand() async {
    final picked = await _showSimpleListSheet<BrandItem>(
      context: context,
      title: 'Выберите марку',
      fetch: () => storage_api.StorageApi.fetchBrandCatalog().then(
        (c) => c.items..sort((a, b) => a.name.compareTo(b.name)),
      ),
      labelOf: (b) => b.name.isNotEmpty ? b.name : b.nameRus,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _brand = picked;
      _model = null;
      _generation = null;
      _restyling = null;
    });
  }

  Future<void> _pickModel() async {
    final brand = _brand;
    if (brand == null) return;
    final picked = await _showSimpleListSheet<ModelItem>(
      context: context,
      title: 'Выберите модель',
      fetch: () => storage_api.StorageApi.fetchModels(brandId: brand.id),
      labelOf: (m) => m.model.isNotEmpty ? m.model : m.modelRus,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _model = picked;
      _generation = null;
      _restyling = null;
    });
  }

  Future<void> _pickGeneration() async {
    final model = _model;
    if (model == null) return;
    final picked = await _showSimpleListSheet<GenerationItem>(
      context: context,
      title: 'Выберите поколение',
      fetch: () => storage_api.StorageApi.fetchGenerations(
        modelCarId: model.id,
      ),
      labelOf: (g) {
        final restCount = g.restylings.length;
        final restWord = restCount == 1
            ? 'рестайлинг'
            : (restCount > 1 && restCount < 5
                ? 'рестайлинга'
                : 'рестайлингов');
        return '${g.label} · $restCount $restWord';
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _generation = picked;
      _restyling = null;
      if (picked.restylings.length == 1) {
        _restyling = picked.restylings.first;
      }
    });
  }

  Future<void> _pickRestyling() async {
    final generation = _generation;
    if (generation == null) return;
    if (generation.restylings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'У выбранного поколения нет рестайлингов в каталоге. '
            'Выберите другое поколение.',
          ),
        ),
      );
      return;
    }
    final picked = await _showSimpleListSheet<RestylingItem>(
      context: context,
      title: 'Выберите рестайлинг',
      fetch: () async => generation.restylings,
      labelOf: (r) {
        final name = r.restyling.trim().isEmpty
            ? 'Без рестайлинга'
            : r.restyling.trim();
        final years = [
          if (r.yearStart != null) r.yearStart.toString(),
          if (r.yearEnd != null) r.yearEnd.toString(),
        ].join('–');
        return years.isEmpty ? name : '$name ($years)';
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _restyling = picked);
  }

  // ─── City picker ─────────────────────────────────────────────────────

  Future<void> _pickCity() async {
    final City? picked = await showCityPickerBottomSheet(
      context,
      currentValue: _city.isEmpty ? null : _city,
    );
    if (picked == null || !mounted) return;
    setState(() => _city = picked.nameRu);
  }

  // ─── Specialist picker ──────────────────────────────────────────────

  Future<void> _pickAssignee() async {
    final picked = await showSpecialistPicker(context);
    if (picked == null || !mounted) return;
    setState(() => _assignee = picked);
  }

  void _clearAssignee() {
    setState(() => _assignee = null);
  }

  // ─── Submit ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitError = null);

    final restyling = _restyling;
    if (restyling == null) {
      setState(() => _submitError = 'Выберите автомобиль');
      return;
    }

    final dueAt = _parseRuDate(_dueAtController.text);
    if (dueAt == null) {
      setState(() => _submitError = 'Срок: формат ДД.ММ.ГГГГ');
      return;
    }
    if (dueAt.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      setState(() => _submitError = 'Срок не может быть в прошлом');
      return;
    }

    final budgetFrom = int.tryParse(_budgetFromController.text.trim());
    final budgetTo = int.tryParse(_budgetToController.text.trim());
    if (budgetFrom != null && budgetTo != null && budgetTo < budgetFrom) {
      setState(() => _submitError = 'Бюджет «до» должен быть не меньше «от»');
      return;
    }
    final maxMileage = int.tryParse(_maxMileageController.text.trim());
    final ownersCount = int.tryParse(_ownersCountController.text.trim());

    final sellerPhone = _sellerPhoneController.text.trim();
    final sellerUrl = _sellerUrlController.text.trim();

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final result = await storage_api.StorageApi.createRequest(
        requestType: 'by_car',
        requestCars: [
          {
            'restylings': [restyling.id],
            if (sellerPhone.isNotEmpty) 'phone': sellerPhone,
            if (sellerUrl.isNotEmpty) 'url': sellerUrl,
          },
        ],
        dueAt: _formatIsoDate(dueAt),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        city: _city.isEmpty ? null : _city,
        budgetFrom: budgetFrom,
        budgetTo: budgetTo,
        maxMileage: maxMileage,
        ownersCount: ownersCount,
        // Передаём ID только когда picker вернул integer (т.е. бэк
        // поддерживает лукап). Сейчас всегда null — заявка создаётся
        // без назначения, юзер уже видит warning об этом.
        assignedSpecialistId: _assignee?.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Заявка №${result.requestNumber} создана',
          ),
          backgroundColor: kGreenColor,
          duration: const Duration(seconds: 6),
        ),
      );
      Navigator.of(context).pop();
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Сессия истекла — войдите заново';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Не удалось создать заявку: $e';
      });
    }
  }

  // ─── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const MyText(
          text: 'Создать заявку',
          size: SparkTextSize.titleLg,
          weight: FontWeight.w800,
        ),
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
        ),
      ),
      body: SparkScreenList(
        bottomInset: 24,
        children: [
          // ── Автомобиль ───────────────────────────────────────────────
          const SparkSectionTitle('Автомобиль'),
          SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.sm,
            ),
            child: Column(
              children: [
                SparkProfileRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Марка',
                  required: true,
                  value: _brand == null
                      ? 'Не выбрана'
                      : (_brand!.name.isNotEmpty
                          ? _brand!.name
                          : _brand!.nameRus),
                  valueIsPlaceholder: _brand == null,
                  onTap: _pickBrand,
                ),
                SparkProfileRow(
                  icon: Icons.list_alt_outlined,
                  label: 'Модель',
                  required: true,
                  value: _model == null
                      ? (_brand == null
                          ? 'Сначала выберите марку'
                          : 'Не выбрана')
                      : (_model!.model.isNotEmpty
                          ? _model!.model
                          : _model!.modelRus),
                  valueIsPlaceholder: _model == null,
                  onTap: _brand == null ? null : _pickModel,
                ),
                SparkProfileRow(
                  icon: Icons.event_note_outlined,
                  label: 'Поколение',
                  required: true,
                  value: _generation == null
                      ? (_model == null
                          ? 'Сначала выберите модель'
                          : 'Не выбрано')
                      : 'Поколение ${_generation!.generation}',
                  valueIsPlaceholder: _generation == null,
                  onTap: _model == null ? null : _pickGeneration,
                ),
                SparkProfileRow(
                  icon: Icons.tune_rounded,
                  label: 'Рестайлинг',
                  required: true,
                  value: _restyling == null
                      ? (_generation == null
                          ? 'Сначала выберите поколение'
                          : 'Не выбран')
                      : (_restyling!.restyling.trim().isEmpty
                          ? 'Без рестайлинга'
                          : _restyling!.restyling),
                  valueIsPlaceholder: _restyling == null,
                  onTap: _generation == null ? null : _pickRestyling,
                ),
              ],
            ),
          ),
          const SizedBox(height: SparkSpace.md),
          SparkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldLabel(text: 'Телефон продавца', required: false),
                TextField(
                  controller: _sellerPhoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [RuPhoneFormatter()],
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: sparkInputDecoration('+7-___-___-__-__'),
                ),
                const SizedBox(height: SparkSpace.lg),
                const _FieldLabel(
                  text: 'Ссылка на объявление',
                  required: false,
                ),
                TextField(
                  controller: _sellerUrlController,
                  keyboardType: TextInputType.url,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: sparkInputDecoration(
                    'https://auto.ru/cars/...',
                  ),
                ),
              ],
            ),
          ),

          // ── Заметка ──────────────────────────────────────────────────
          // Подняли сразу под «Автомобиль» — заметка про авто (VIN,
          // госномер, инструкции) логически ближе к car-блоку чем к
          // параметрам подбора / специалисту.
          const SparkSectionTitle('Заметка', top: SparkSpace.xxl),
          SparkCard(
            child: TextField(
              controller: _noteController,
              maxLines: 5,
              minLines: 3,
              maxLength: 5000,
              buildCounter: (_, {
                required int currentLength,
                required int? maxLength,
                required bool isFocused,
              }) => null,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: sparkInputDecoration(
                'VIN, госномер, инструкция специалисту…',
              ),
            ),
          ),

          // ── Параметры подбора ────────────────────────────────────────
          const SparkSectionTitle(
            'Параметры подбора',
            top: SparkSpace.xxl,
          ),
          SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.sm,
            ),
            child: SparkProfileRow(
              icon: Icons.location_on_outlined,
              label: 'Город',
              value: _city.isEmpty ? 'Не указан' : _city,
              valueIsPlaceholder: _city.isEmpty,
              onTap: _pickCity,
            ),
          ),
          const SizedBox(height: SparkSpace.md),
          SparkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel(
                            text: 'Бюджет от',
                            required: false,
                          ),
                          TextField(
                            controller: _budgetFromController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              // 9 digits (макс. 999_999_999 ₽) — sane
                              // максимум для авто, помещается в int32 на
                              // случай если бэк не 64-bit.
                              LengthLimitingTextInputFormatter(9),
                            ],
                            onTapOutside: (_) => FocusManager
                                .instance.primaryFocus
                                ?.unfocus(),
                            decoration: sparkInputDecoration('₽'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel(
                            text: 'Бюджет до',
                            required: false,
                          ),
                          TextField(
                            controller: _budgetToController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            onTapOutside: (_) => FocusManager
                                .instance.primaryFocus
                                ?.unfocus(),
                            decoration: sparkInputDecoration('₽'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.lg),
                const _FieldLabel(
                  text: 'Макс. пробег, км',
                  required: false,
                ),
                TextField(
                  controller: _maxMileageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: sparkInputDecoration('например, 150000'),
                ),
                const SizedBox(height: SparkSpace.lg),
                const _FieldLabel(
                  text: 'Макс. число владельцев',
                  required: false,
                ),
                TextField(
                  controller: _ownersCountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: sparkInputDecoration('например, 2'),
                ),
              ],
            ),
          ),

          // ── Специалист ───────────────────────────────────────────────
          const SparkSectionTitle('Специалист', top: SparkSpace.xxl),
          SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.sm,
            ),
            child: SparkProfileRow(
              icon: Icons.person_outline,
              label: 'Назначен',
              value: _assignee == null
                  ? 'Не выбран'
                  : _assignee!.displayName,
              valueIsPlaceholder: _assignee == null,
              trailing: _assignee == null
                  ? null
                  : IconButton(
                      onPressed: _clearAssignee,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: SparkSize.iconMd,
                        color: kGreyColor,
                      ),
                      tooltip: 'Очистить',
                    ),
              onTap: _pickAssignee,
            ),
          ),

          // ── Срок ─────────────────────────────────────────────────────
          const SparkSectionTitle('Срок', top: SparkSpace.xxl),
          SparkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldLabel(text: 'Срок исполнения', required: true),
                TextField(
                  controller: _dueAtController,
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [_RuDateFormatter()],
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: sparkInputDecoration('ДД.ММ.ГГГГ'),
                ),
              ],
            ),
          ),

          if (_submitError != null) ...[
            const SizedBox(height: SparkSpace.lg),
            SparkCard(
              backgroundColor: kRedColor.withValues(alpha: 0.06),
              borderColor: kRedColor.withValues(alpha: 0.35),
              child: MyText(
                text: _submitError!,
                size: SparkTextSize.body,
                color: kRedColor,
                weight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: SparkSpace.xxl),
          SparkPrimaryActionButton(
            label: _submitting ? 'Отправляем...' : 'Отправить',
            icon: Icons.send_rounded,
            busy: _submitting,
            onTap: _submit,
          ),
          const SizedBox(height: SparkSpace.lg),
        ],
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────

/// Label сверху над input'ом, опционально с красной * для обязательных.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.required});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.sm),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: text,
              style: const TextStyle(
                fontSize: SparkTextSize.body,
                color: kGreyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: SparkTextSize.body,
                  color: kRedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Simple list sheet (для car pickers) ──────────────────────────────

Future<T?> _showSimpleListSheet<T>({
  required BuildContext context,
  required String title,
  required Future<List<T>> Function() fetch,
  required String Function(T) labelOf,
}) async {
  return await showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kWhiteColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SparkRadius.lg),
      ),
    ),
    builder: (ctx) {
      return _SimpleListSheet<T>(
        title: title,
        fetch: fetch,
        labelOf: labelOf,
      );
    },
  );
}

class _SimpleListSheet<T> extends StatefulWidget {
  const _SimpleListSheet({
    required this.title,
    required this.fetch,
    required this.labelOf,
  });

  final String title;
  final Future<List<T>> Function() fetch;
  final String Function(T) labelOf;

  @override
  State<_SimpleListSheet<T>> createState() => _SimpleListSheetState<T>();
}

class _SimpleListSheetState<T> extends State<_SimpleListSheet<T>> {
  List<T>? _items;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = 'Не удалось загрузить: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final List<T> filtered = items == null
        ? <T>[]
        : _query.trim().isEmpty
            ? items
            : items
                .where((it) => widget
                    .labelOf(it)
                    .toLowerCase()
                    .contains(_query.trim().toLowerCase()))
                .toList();
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(SparkSpace.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: widget.title,
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: SparkSpace.sm),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: sparkInputDecoration(
                  'Поиск',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: kGreyColor,
                  ),
                  dense: true,
                ),
              ),
              const SizedBox(height: SparkSpace.md),
              Expanded(
                child: () {
                  if (items == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SparkSpace.xl),
                        child: MyText(
                          text: _error!,
                          size: SparkTextSize.body,
                          color: kRedColor,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (filtered.isEmpty) {
                    return const Center(
                      child: MyText(
                        text: 'Ничего не найдено',
                        size: SparkTextSize.body,
                        color: kGreyColor,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: kBorderColor),
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SparkSpace.md,
                              vertical: SparkSpace.lg,
                            ),
                            child: MyText(
                              text: widget.labelOf(item),
                              size: SparkTextSize.body,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date utilities ───────────────────────────────────────────────────

DateTime? _parseRuDate(String value) {
  final raw = value.trim();
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(raw);
  if (match == null) return null;
  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > lastDay) return null;
  return DateTime(year, month, day);
}

String _formatRuDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

String _formatIsoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _RuDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final length = digits.length.clamp(0, 8);
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

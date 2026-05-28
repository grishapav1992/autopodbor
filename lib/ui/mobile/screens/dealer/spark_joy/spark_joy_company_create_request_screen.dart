import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
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
import 'spark_joy_external_link.dart';
import 'spark_joy_storage.dart';
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
  Timer? _draftAutosaveDebounce;
  bool _draftHydrating = true;
  bool _draftSubmitted = false;

  @override
  void initState() {
    super.initState();
    final defaultDue = DateTime.now().add(const Duration(days: 7));
    _dueAtController.text = _formatRuDate(defaultDue);
    _addDraftListeners();
    unawaited(_loadDraft());
  }

  @override
  void dispose() {
    if (!_draftSubmitted && !_draftHydrating) {
      unawaited(SparkJoyStorage.saveCompanyRequestDraft(_buildDraftPayload()));
    }
    _draftAutosaveDebounce?.cancel();
    _removeDraftListeners();
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

  void _addDraftListeners() {
    for (final controller in _draftTextControllers) {
      controller.addListener(_onDraftFieldChanged);
    }
  }

  void _removeDraftListeners() {
    for (final controller in _draftTextControllers) {
      controller.removeListener(_onDraftFieldChanged);
    }
  }

  List<TextEditingController> get _draftTextControllers => [
    _sellerPhoneController,
    _sellerUrlController,
    _budgetFromController,
    _budgetToController,
    _maxMileageController,
    _ownersCountController,
    _dueAtController,
    _noteController,
  ];

  void _onDraftFieldChanged() {
    if (_draftHydrating || _draftSubmitted) return;
    _scheduleDraftAutosave();
  }

  Future<void> _loadDraft() async {
    final draft = await SparkJoyStorage.loadCompanyRequestDraft();
    if (!mounted) return;
    if (draft == null) {
      _draftHydrating = false;
      return;
    }
    _draftHydrating = true;
    setState(() {
      _brand = _brandFromDraft(draft['brand']);
      _model = _modelFromDraft(draft['model']);
      _generation = _generationFromDraft(draft['generation']);
      _restyling = _restylingFromDraft(draft['restyling']);
      _city = _draftString(draft['city']);
      _assignee = _assigneeFromDraft(draft['assignee']);
      _sellerPhoneController.text = _draftString(draft['sellerPhone']);
      _sellerUrlController.text = _draftString(draft['sellerUrl']);
      _budgetFromController.text = _draftString(draft['budgetFrom']);
      _budgetToController.text = _draftString(draft['budgetTo']);
      _maxMileageController.text = _draftString(draft['maxMileage']);
      _ownersCountController.text = _draftString(draft['ownersCount']);
      final dueAt = _draftString(draft['dueAt']);
      if (dueAt.isNotEmpty) {
        _dueAtController.text = dueAt;
      }
      _noteController.text = _draftString(draft['note']);
    });
    _draftHydrating = false;
  }

  void _scheduleDraftAutosave() {
    if (_draftSubmitted) return;
    _draftAutosaveDebounce?.cancel();
    _draftAutosaveDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _draftSubmitted) return;
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    if (_draftSubmitted) return;
    await SparkJoyStorage.saveCompanyRequestDraft(_buildDraftPayload());
  }

  Map<String, dynamic> _buildDraftPayload() {
    return {
      'version': 1,
      'updatedAtIso': DateTime.now().toIso8601String(),
      'brand': _brandToDraft(_brand),
      'model': _modelToDraft(_model),
      'generation': _generationToDraft(_generation),
      'restyling': _restylingToDraft(_restyling),
      'sellerPhone': _sellerPhoneController.text,
      'sellerUrl': _sellerUrlController.text,
      'city': _city,
      'budgetFrom': _budgetFromController.text,
      'budgetTo': _budgetToController.text,
      'maxMileage': _maxMileageController.text,
      'ownersCount': _ownersCountController.text,
      'dueAt': _dueAtController.text,
      'note': _noteController.text,
      'assignee': _assigneeToDraft(_assignee),
    };
  }

  // ─── Car pickers ────────────────────────────────────────────────────

  Future<void> _openCarPickerDialog() async {
    const catalogLoadTimeout = Duration(seconds: 12);

    final List<BrandItem> brands;
    try {
      final catalog = await storage_api.StorageApi.fetchBrandCatalog().timeout(
        catalogLoadTimeout,
      );
      brands = List<BrandItem>.from(catalog.items)
        ..sort(
          (a, b) => _brandLabel(
            a,
          ).toLowerCase().compareTo(_brandLabel(b).toLowerCase()),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось загрузить каталог авто: $e'),
          backgroundColor: kRedColor,
        ),
      );
      return;
    }

    if (!mounted) return;

    final selection = await showDialog<_RequestCarPickerSelection>(
      context: context,
      builder: (context) {
        return _RequestCarPickerDialog(
          brands: brands,
          initialBrand: _brand,
          initialModel: _model,
          initialGeneration: _generation,
          initialRestyling: _restyling,
          loadModels: (brand) => storage_api.StorageApi.fetchModels(
            brandId: brand.id,
          ).timeout(catalogLoadTimeout),
          loadGenerations: (model) => storage_api.StorageApi.fetchGenerations(
            modelCarId: model.id,
          ).timeout(catalogLoadTimeout),
        );
      },
    );
    if (selection == null || !mounted) return;
    setState(() {
      _brand = selection.brand;
      _model = selection.model;
      _generation = selection.generation;
      _restyling = selection.restyling;
    });
    _scheduleDraftAutosave();
  }

  String get _carButtonName {
    if (_brand == null || _model == null) return '';
    return '${_brandLabel(_brand!)} ${_modelLabel(_model!)}';
  }

  String get _carName {
    final parts = <String>[
      if (_brand != null) _brandLabel(_brand!),
      if (_model != null) _modelLabel(_model!),
      if (_generation != null) _generation!.generation.toString(),
    ];
    return parts.where((value) => value.trim().isNotEmpty).join(' ');
  }

  String get _carMetaLabel {
    final parts = <String>[
      if (_generation != null) 'Поколение ${_generation!.generation}',
      if (_restyling != null) _restylingLabel(_restyling!),
      if (_restyling != null && _restyling!.frames.isNotEmpty)
        _restyling!.frames.map((item) => item.frame).join(', '),
    ];
    return parts.where((value) => value.trim().isNotEmpty).join(' · ');
  }

  String get _carPhotoUrl {
    final restyling = _restyling;
    if (restyling == null) return '';
    return _restylingPhotoUrl(restyling);
  }

  // ─── City picker ─────────────────────────────────────────────────────

  Future<void> _pickCity() async {
    final City? picked = await showCityPickerBottomSheet(
      context,
      currentValue: _city.isEmpty ? null : _city,
    );
    if (picked == null || !mounted) return;
    setState(() => _city = picked.displayNameRu);
    _scheduleDraftAutosave();
  }

  // ─── Specialist picker ──────────────────────────────────────────────

  Future<void> _pickAssignee() async {
    final picked = await showSpecialistPicker(context);
    if (picked == null || !mounted) return;
    setState(() => _assignee = picked);
    _scheduleDraftAutosave();
  }

  void _clearAssignee() {
    setState(() => _assignee = null);
    _scheduleDraftAutosave();
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
    if (_assignee == null) {
      setState(() => _submitError = 'Назначьте специалиста');
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
    final rawSellerUrl = _sellerUrlController.text.trim();
    final sellerUrl = sparkNormalizeExternalUrl(rawSellerUrl);
    if (rawSellerUrl.isNotEmpty && sellerUrl.isEmpty) {
      setState(() => _submitError = 'Ссылка: укажите корректный адрес');
      return;
    }

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
          content: Text('Заявка №${result.requestNumber} создана'),
          backgroundColor: kGreenColor,
          duration: const Duration(seconds: 6),
        ),
      );
      _draftSubmitted = true;
      _draftAutosaveDebounce?.cancel();
      await SparkJoyStorage.clearCompanyRequestDraft();
      if (!mounted) return;
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
          _carSelectionCard(),
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
                  text: 'Ссылка на сторонний ресурс',
                  required: false,
                ),
                TextField(
                  controller: _sellerUrlController,
                  keyboardType: TextInputType.url,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: sparkInputDecoration(
                    'auto.ru, avito.ru, drive.google.com/...',
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
              buildCounter:
                  (
                    _, {
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
          const SparkSectionTitle('Параметры подбора', top: SparkSpace.xxl),
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
                          const _FieldLabel(text: 'Бюджет от', required: false),
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
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
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
                          const _FieldLabel(text: 'Бюджет до', required: false),
                          TextField(
                            controller: _budgetToController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: sparkInputDecoration('₽'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.lg),
                const _FieldLabel(text: 'Макс. пробег, км', required: false),
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
              value: _assignee == null ? 'Не выбран' : _assignee!.displayName,
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

  Widget _carSelectionCard() {
    final carButtonTitle = _carButtonName;
    final carTitle = _carName;
    final carMeta = _carMetaLabel;
    final carPhotoUrl = _carPhotoUrl;
    final showDetails =
        carPhotoUrl.trim().isNotEmpty ||
        carTitle != carButtonTitle ||
        carMeta.isNotEmpty;

    return SparkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _openCarPickerDialog,
            borderRadius: BorderRadius.circular(SparkRadius.lg),
            child: Container(
              height: SparkSize.inputHeightLg,
              padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xl),
              decoration: BoxDecoration(
                border: Border.all(color: kBorderColor),
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: _restyling == null
                          ? 'Выбрать автомобиль'
                          : carButtonTitle,
                      size: SparkTextSize.bodyLg,
                      color: _restyling == null ? kGreyColor : kTertiaryColor,
                      maxLines: 1,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: kGreyColor),
                ],
              ),
            ),
          ),
          if (showDetails) ...[
            const SizedBox(height: SparkSpace.md),
            SparkCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.lg,
                vertical: SparkSpace.md,
              ),
              elevated: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (carPhotoUrl.trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(SparkRadius.sm),
                            child: CachedNetworkImage(
                              imageUrl: carPhotoUrl.trim(),
                              width: double.infinity,
                              height: SparkSize.mediaCardThumb,
                              fit: BoxFit.cover,
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
                          if (carTitle != carButtonTitle || carMeta.isNotEmpty)
                            const SizedBox(height: SparkSpace.md),
                        ],
                        if (carTitle != carButtonTitle && carTitle.isNotEmpty)
                          MyText(
                            text: carTitle,
                            size: SparkTextSize.body,
                            weight: FontWeight.w700,
                          ),
                        if (carMeta.isNotEmpty) ...[
                          if (carTitle != carButtonTitle && carTitle.isNotEmpty)
                            const SizedBox(height: SparkSpace.xxs),
                          MyText(
                            text: carMeta,
                            size: SparkTextSize.caption,
                            color: kGreyColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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

// ── Car picker dialog ────────────────────────────────────────────────

enum _RequestCarPickerStep { brand, model, generation, restyling }

class _RequestCarPickerSelection {
  const _RequestCarPickerSelection({
    required this.brand,
    required this.model,
    required this.generation,
    required this.restyling,
  });

  final BrandItem brand;
  final ModelItem model;
  final GenerationItem generation;
  final RestylingItem restyling;
}

class _RequestCarPickerDialog extends StatefulWidget {
  const _RequestCarPickerDialog({
    required this.brands,
    required this.loadModels,
    required this.loadGenerations,
    this.initialBrand,
    this.initialModel,
    this.initialGeneration,
    this.initialRestyling,
  });

  final List<BrandItem> brands;
  final Future<List<ModelItem>> Function(BrandItem brand) loadModels;
  final Future<List<GenerationItem>> Function(ModelItem model) loadGenerations;
  final BrandItem? initialBrand;
  final ModelItem? initialModel;
  final GenerationItem? initialGeneration;
  final RestylingItem? initialRestyling;

  @override
  State<_RequestCarPickerDialog> createState() =>
      _RequestCarPickerDialogState();
}

class _RequestCarPickerDialogState extends State<_RequestCarPickerDialog> {
  final _modelsByBrandId = <int, List<ModelItem>>{};
  final _generationsByModelId = <int, List<GenerationItem>>{};

  _RequestCarPickerStep _step = _RequestCarPickerStep.brand;
  BrandItem? _selectedBrand;
  ModelItem? _selectedModel;
  GenerationItem? _selectedGeneration;
  RestylingItem? _selectedRestyling;
  String _search = '';
  bool _modelsLoading = false;
  bool _modelsFailed = false;
  bool _generationsLoading = false;
  bool _generationsFailed = false;

  @override
  void initState() {
    super.initState();
    _selectedBrand = _brandFromCatalog(widget.initialBrand);
    _selectedModel = widget.initialModel;
    _selectedGeneration = widget.initialGeneration;
    _selectedRestyling = widget.initialRestyling;

    if (_selectedBrand != null) _step = _RequestCarPickerStep.model;
    if (_selectedModel != null) _step = _RequestCarPickerStep.generation;
    if (_selectedGeneration != null) _step = _RequestCarPickerStep.restyling;

    final brand = _selectedBrand;
    if (brand != null) {
      unawaited(_ensureModels(brand));
    }
    final model = _selectedModel;
    if (model != null) {
      unawaited(_ensureGenerations(model));
    }
  }

  BrandItem? _brandFromCatalog(BrandItem? source) {
    if (source == null) return null;
    for (final brand in widget.brands) {
      if (brand.id == source.id) return brand;
    }
    return source;
  }

  Future<void> _ensureModels(BrandItem brand) async {
    if (_modelsByBrandId.containsKey(brand.id)) return;
    setState(() {
      _modelsLoading = true;
      _modelsFailed = false;
    });
    try {
      final models = await widget.loadModels(brand);
      if (!mounted) return;
      setState(() {
        _modelsByBrandId[brand.id] = List<ModelItem>.from(models)
          ..sort(
            (a, b) => _modelLabel(
              a,
            ).toLowerCase().compareTo(_modelLabel(b).toLowerCase()),
          );
        _modelsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _modelsLoading = false;
        _modelsFailed = true;
      });
    }
  }

  Future<void> _ensureGenerations(ModelItem model) async {
    if (_generationsByModelId.containsKey(model.id)) return;
    setState(() {
      _generationsLoading = true;
      _generationsFailed = false;
    });
    try {
      final generations = await widget.loadGenerations(model);
      if (!mounted) return;
      setState(() {
        _generationsByModelId[model.id] = List<GenerationItem>.from(generations)
          ..sort((a, b) => a.generation.compareTo(b.generation));
        _generationsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generationsLoading = false;
        _generationsFailed = true;
      });
    }
  }

  void _goBack() {
    if (_step == _RequestCarPickerStep.brand) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _search = '';
      if (_step == _RequestCarPickerStep.model) {
        _step = _RequestCarPickerStep.brand;
        _selectedBrand = null;
        _selectedModel = null;
        _selectedGeneration = null;
        _selectedRestyling = null;
        _modelsFailed = false;
        _generationsFailed = false;
        return;
      }
      if (_step == _RequestCarPickerStep.generation) {
        _step = _RequestCarPickerStep.model;
        _selectedModel = null;
        _selectedGeneration = null;
        _selectedRestyling = null;
        _generationsFailed = false;
        return;
      }
      _step = _RequestCarPickerStep.generation;
      _selectedGeneration = null;
      _selectedRestyling = null;
    });
  }

  void _selectBrand(BrandItem brand) {
    setState(() {
      _selectedBrand = brand;
      _selectedModel = null;
      _selectedGeneration = null;
      _selectedRestyling = null;
      _step = _RequestCarPickerStep.model;
      _search = '';
      _generationsFailed = false;
    });
    unawaited(_ensureModels(brand));
  }

  void _selectModel(ModelItem model) {
    setState(() {
      _selectedModel = model;
      _selectedGeneration = null;
      _selectedRestyling = null;
      _step = _RequestCarPickerStep.generation;
      _search = '';
    });
    unawaited(_ensureGenerations(model));
  }

  void _selectGeneration(GenerationItem generation) {
    setState(() {
      _selectedGeneration = generation;
      _selectedRestyling = null;
      _step = _RequestCarPickerStep.restyling;
      _search = '';
    });
  }

  void _selectRestyling(RestylingItem restyling) {
    final brand = _selectedBrand;
    final model = _selectedModel;
    final generation = _selectedGeneration;
    if (brand == null || model == null || generation == null) return;
    Navigator.of(context).pop(
      _RequestCarPickerSelection(
        brand: brand,
        model: model,
        generation: generation,
        restyling: restyling,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSearch =
        _step == _RequestCarPickerStep.brand ||
        _step == _RequestCarPickerStep.model;
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
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MyText(
                          text: _titleForStep,
                          size: SparkTextSize.title,
                          weight: FontWeight.w700,
                        ),
                        if (_breadcrumb.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: SparkSpace.xxs),
                            child: MyText(
                              text: _breadcrumb,
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
                  key: ValueKey(_step),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: (value) => setState(() => _search = value),
                  decoration: sparkInputDecoration(
                    _step == _RequestCarPickerStep.brand
                        ? 'Поиск марки...'
                        : 'Поиск модели...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: kGreyColor,
                    ),
                    dense: true,
                  ),
                ),
                const SizedBox(height: SparkSpace.md),
              ],
              Expanded(child: _listContent()),
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
  }

  String get _titleForStep {
    switch (_step) {
      case _RequestCarPickerStep.brand:
        return 'Выберите марку';
      case _RequestCarPickerStep.model:
        return 'Выберите модель';
      case _RequestCarPickerStep.generation:
        return 'Выберите поколение';
      case _RequestCarPickerStep.restyling:
        return 'Выберите рестайлинг';
    }
  }

  String get _breadcrumb {
    final parts = <String>[
      if (_selectedBrand != null) _brandLabel(_selectedBrand!),
      if (_selectedModel != null) _modelLabel(_selectedModel!),
      if (_selectedGeneration != null &&
          _step == _RequestCarPickerStep.restyling)
        'Пок. ${_selectedGeneration!.generation}',
    ];
    return parts.join(' -> ');
  }

  Widget _listContent() {
    switch (_step) {
      case _RequestCarPickerStep.brand:
        return _brandList();
      case _RequestCarPickerStep.model:
        return _modelList();
      case _RequestCarPickerStep.generation:
        return _generationList();
      case _RequestCarPickerStep.restyling:
        return _restylingList();
    }
  }

  Widget _brandList() {
    final query = _search.trim().toLowerCase();
    final brands = widget.brands
        .where(
          (brand) => query.isEmpty
              ? true
              : [
                  brand.name.trim().toLowerCase(),
                  brand.nameRus.trim().toLowerCase(),
                ].any((value) => value.contains(query)),
        )
        .toList();
    if (brands.isEmpty) {
      return _pickerEmpty(Icons.search_off_rounded, 'Ничего не найдено');
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: brands.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final brand = brands[index];
        return ListTile(
          title: Text(_brandLabel(brand)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _selectBrand(brand),
        );
      },
    );
  }

  Widget _modelList() {
    final brand = _selectedBrand;
    if (brand == null) {
      return _pickerEmpty(Icons.arrow_upward_rounded, 'Сначала выберите марку');
    }
    final models = _modelsByBrandId[brand.id] ?? const <ModelItem>[];
    if (_modelsLoading && models.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_modelsFailed && models.isEmpty) {
      return _pickerError(
        'Не удалось загрузить модели',
        () => _ensureModels(brand),
      );
    }
    final query = _search.trim().toLowerCase();
    final filtered = models
        .where(
          (model) => query.isEmpty
              ? true
              : [
                  model.model.trim().toLowerCase(),
                  model.modelRus.trim().toLowerCase(),
                ].any((value) => value.contains(query)),
        )
        .toList();
    if (filtered.isEmpty) {
      return _pickerEmpty(Icons.directions_car_outlined, 'Нет моделей');
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final model = filtered[index];
        return ListTile(
          title: Text(_modelLabel(model)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _selectModel(model),
        );
      },
    );
  }

  Widget _generationList() {
    final model = _selectedModel;
    if (model == null) {
      return _pickerEmpty(
        Icons.arrow_upward_rounded,
        'Сначала выберите модель',
      );
    }
    final generations =
        _generationsByModelId[model.id] ?? const <GenerationItem>[];
    if (_generationsLoading && generations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_generationsFailed && generations.isEmpty) {
      return _pickerError(
        'Не удалось загрузить поколения',
        () => _ensureGenerations(model),
      );
    }
    if (generations.isEmpty) {
      return _pickerEmpty(Icons.layers_outlined, 'Нет поколений');
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: generations.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final generation = generations[index];
        final restCount = generation.restylings.length;
        return ListTile(
          title: Text('Поколение ${generation.generation}'),
          subtitle: Text(_restylingCountLabel(restCount)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _selectGeneration(generation),
        );
      },
    );
  }

  Widget _restylingList() {
    final generation = _selectedGeneration;
    final restylings = generation?.restylings ?? const <RestylingItem>[];
    if (generation == null) {
      return _pickerEmpty(
        Icons.arrow_upward_rounded,
        'Сначала выберите поколение',
      );
    }
    if (restylings.isEmpty) {
      return _pickerEmpty(Icons.tune_rounded, 'Нет рестайлингов');
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: restylings.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final restyling = restylings[index];
        final frames = restyling.frames.map((item) => item.frame).join(', ');
        final isSelected = restyling.id == _selectedRestyling?.id;
        return ListTile(
          leading: _RestylingThumb(url: _restylingPhotoUrl(restyling)),
          title: Text(_restylingLabel(restyling)),
          subtitle: frames.trim().isEmpty ? null : Text(frames),
          trailing: Icon(
            isSelected ? Icons.check_circle_rounded : Icons.check_rounded,
            color: isSelected ? kSecondaryColor : null,
          ),
          onTap: () => _selectRestyling(restyling),
        );
      },
    );
  }

  Widget _pickerEmpty(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SparkSpace.xxxl),
      child: Center(
        child: SparkEmptyState(icon: icon, title: title, topPadding: 0),
      ),
    );
  }

  Widget _pickerError(String title, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SparkEmptyState(
            icon: Icons.cloud_off_rounded,
            title: title,
            topPadding: 0,
          ),
          const SizedBox(height: SparkSpace.md),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class _RestylingThumb extends StatelessWidget {
  const _RestylingThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: SparkSize.inputHeight,
      height: SparkSize.inputHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kLightGreyColor,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
      ),
      child: const Icon(Icons.directions_car_outlined, color: kGreyColor),
    );
    if (url.trim().isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(SparkRadius.sm),
      child: Image.network(
        url,
        width: SparkSize.inputHeight,
        height: SparkSize.inputHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}

String _brandLabel(BrandItem brand) {
  final name = brand.name.trim();
  if (name.isNotEmpty) return name;
  return brand.nameRus.trim();
}

String _modelLabel(ModelItem model) {
  final name = model.model.trim();
  if (name.isNotEmpty) return name;
  return model.modelRus.trim();
}

String _restylingLabel(RestylingItem restyling) {
  final name = restyling.restyling.trim().isEmpty
      ? 'Без рестайлинга'
      : restyling.restyling.trim();
  final years = [
    if (restyling.yearStart != null) restyling.yearStart.toString(),
    if (restyling.yearEnd != null) restyling.yearEnd.toString(),
  ].join('-');
  return years.isEmpty ? name : '$name · $years';
}

String _restylingPhotoUrl(RestylingItem restyling) {
  for (final photo in restyling.photos) {
    final urlX2 = photo.urlX2.trim();
    if (urlX2.isNotEmpty) return urlX2;
    final urlX1 = photo.urlX1.trim();
    if (urlX1.isNotEmpty) return urlX1;
  }
  return '';
}

String _restylingCountLabel(int count) {
  if (count == 1) return '1 рестайлинг';
  if (count > 1 && count < 5) return '$count рестайлинга';
  return '$count рестайлингов';
}

Map<String, dynamic>? _brandToDraft(BrandItem? brand) {
  if (brand == null) return null;
  return {'id': brand.id, 'name': brand.name, 'nameRus': brand.nameRus};
}

BrandItem? _brandFromDraft(dynamic raw) {
  final map = _draftMap(raw);
  if (map.isEmpty) return null;
  final id = _draftInt(map['id']);
  if (id == null) return null;
  return BrandItem(
    id: id,
    name: _draftString(map['name']),
    nameRus: _draftString(map['nameRus']),
  );
}

Map<String, dynamic>? _modelToDraft(ModelItem? model) {
  if (model == null) return null;
  return {
    'id': model.id,
    'brandId': model.brandId,
    'model': model.model,
    'modelRus': model.modelRus,
  };
}

ModelItem? _modelFromDraft(dynamic raw) {
  final map = _draftMap(raw);
  if (map.isEmpty) return null;
  final id = _draftInt(map['id']);
  final brandId = _draftInt(map['brandId']);
  if (id == null || brandId == null) return null;
  return ModelItem(
    id: id,
    brandId: brandId,
    model: _draftString(map['model']),
    modelRus: _draftString(map['modelRus']),
  );
}

Map<String, dynamic>? _generationToDraft(GenerationItem? generation) {
  if (generation == null) return null;
  return {
    'id': generation.id,
    'modelCarId': generation.modelCarId,
    'generation': generation.generation,
    'frames': generation.frames.map(_frameToDraft).toList(growable: false),
    'restylings': generation.restylings
        .map(_restylingToDraft)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false),
  };
}

GenerationItem? _generationFromDraft(dynamic raw) {
  final map = _draftMap(raw);
  if (map.isEmpty) return null;
  final id = _draftInt(map['id']);
  final modelCarId = _draftInt(map['modelCarId']);
  final generation = _draftInt(map['generation']);
  if (id == null || modelCarId == null || generation == null) return null;
  return GenerationItem(
    id: id,
    modelCarId: modelCarId,
    generation: generation,
    frames: _framesFromDraft(map['frames']),
    restylings: _restylingsFromDraft(map['restylings']),
  );
}

Map<String, dynamic>? _restylingToDraft(RestylingItem? restyling) {
  if (restyling == null) return null;
  return {
    'id': restyling.id,
    'restyling': restyling.restyling,
    'yearStart': restyling.yearStart,
    'yearEnd': restyling.yearEnd,
    'frames': restyling.frames.map(_frameToDraft).toList(growable: false),
    'photos': restyling.photos.map(_photoToDraft).toList(growable: false),
  };
}

RestylingItem? _restylingFromDraft(dynamic raw) {
  final map = _draftMap(raw);
  if (map.isEmpty) return null;
  final id = _draftInt(map['id']);
  if (id == null) return null;
  return RestylingItem(
    id: id,
    restyling: _draftString(map['restyling']),
    yearStart: _draftInt(map['yearStart']),
    yearEnd: _draftInt(map['yearEnd']),
    frames: _framesFromDraft(map['frames']),
    photos: _photosFromDraft(map['photos']),
  );
}

Map<String, dynamic> _frameToDraft(FrameItem frame) {
  return {'id': frame.id, 'frame': frame.frame};
}

List<FrameItem> _framesFromDraft(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map(_draftMap)
      .map((map) {
        final id = _draftInt(map['id']);
        if (id == null) return null;
        return FrameItem(id: id, frame: _draftString(map['frame']));
      })
      .whereType<FrameItem>()
      .toList(growable: false);
}

Map<String, dynamic> _photoToDraft(PhotoItem photo) {
  return {
    'id': photo.id,
    'size': photo.size,
    'urlX1': photo.urlX1,
    'urlX2': photo.urlX2,
  };
}

List<PhotoItem> _photosFromDraft(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map(_draftMap)
      .map((map) {
        final id = _draftInt(map['id']);
        if (id == null) return null;
        return PhotoItem(
          id: id,
          size: _draftString(map['size']),
          urlX1: _draftString(map['urlX1']),
          urlX2: _draftString(map['urlX2']),
        );
      })
      .whereType<PhotoItem>()
      .toList(growable: false);
}

List<RestylingItem> _restylingsFromDraft(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map(_restylingFromDraft)
      .whereType<RestylingItem>()
      .toList(growable: false);
}

Map<String, dynamic>? _assigneeToDraft(SelectedAssignee? assignee) {
  if (assignee == null) return null;
  return {
    'displayName': assignee.displayName,
    'source': assignee.source.name,
    'userId': assignee.userId,
    'phone': assignee.phone,
    'urlAvatar': assignee.urlAvatar,
    'city': assignee.city,
  };
}

SelectedAssignee? _assigneeFromDraft(dynamic raw) {
  final map = _draftMap(raw);
  if (map.isEmpty) return null;
  final userId = _draftInt(map['userId']);
  if (userId == null) return null;
  final source = _draftString(map['source']) == AssigneeSource.phone.name
      ? AssigneeSource.phone
      : AssigneeSource.staff;
  return SelectedAssignee(
    displayName: _draftString(map['displayName']),
    source: source,
    userId: userId,
    phone: _draftNullableString(map['phone']),
    urlAvatar: _draftNullableString(map['urlAvatar']),
    city: _draftNullableString(map['city']),
  );
}

Map<String, dynamic> _draftMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String _draftString(dynamic raw) {
  if (raw == null) return '';
  return raw.toString();
}

String? _draftNullableString(dynamic raw) {
  final value = _draftString(raw).trim();
  return value.isEmpty ? null : value;
}

int? _draftInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(_draftString(raw));
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
    final selectionOffset = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final digitsBeforeCursor = newValue.text
        .substring(0, selectionOffset)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final clampedDigitsBeforeCursor = digitsBeforeCursor.clamp(0, 8).toInt();
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
      selection: TextSelection.collapsed(
        offset: _cursorOffsetForDigits(text, clampedDigitsBeforeCursor),
      ),
    );
  }

  int _cursorOffsetForDigits(String text, int digitCount) {
    if (digitCount <= 0) return 0;
    var seen = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        seen++;
        if (seen == digitCount) return i + 1;
      }
    }
    return text.length;
  }
}

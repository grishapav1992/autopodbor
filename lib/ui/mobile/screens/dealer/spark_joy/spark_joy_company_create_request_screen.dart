import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/data/services/car_catalog_repository.dart';
import 'package:flutter_application_1/data/services/car_catalog_sync_service.dart';
import 'package:flutter_application_1/data/services/city_repository.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';
import 'package:flutter_application_1/ui/common/widgets/city_picker_bottom_sheet.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_specialist_picker.dart';
import 'spark_joy_error_snackbar.dart';
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
///    Выбранный специалист передаётся в `Storage.CreateRequest` как
///    `assignedSpecialistId`.
///  * **Срок** (required): RU-date input с дефолтом +7 дней
class SparkJoyCompanyCreateRequestScreen extends StatefulWidget {
  const SparkJoyCompanyCreateRequestScreen({super.key});

  @override
  State<SparkJoyCompanyCreateRequestScreen> createState() =>
      _SparkJoyCompanyCreateRequestScreenState();
}

class _SparkJoyCompanyCreateRequestScreenState
    extends State<SparkJoyCompanyCreateRequestScreen> {
  // Assigned request creation also writes assignment state and sends the
  // specialist notification. The old generic 12s RPC timeout produced false
  // NET-02 banners while the server was still completing that work.
  static const _assignedCreateRequestTimeout = Duration(seconds: 45);

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

  // Due date (tap-to-pick; default +7 дней). В черновике хранится как
  // RU-строка ДД.ММ.ГГГГ — обратная совместимость со старым форматом,
  // когда срок был текстовым полем.
  DateTime _dueAt = DateTime.now().add(const Duration(days: 7));

  // Note
  final _noteController = TextEditingController();

  // Submit state
  bool _submitting = false;
  String? _submitErrorTitle;
  String? _submitError;
  String? _submitErrorCopyText;
  String _submitErrorCode = '';
  Timer? _draftAutosaveDebounce;
  bool _draftHydrating = true;
  bool _draftSubmitted = false;

  @override
  void initState() {
    super.initState();
    _addDraftListeners();
    unawaited(_loadDraft());
    // Страховочный пинок фонового синка каталога (идемпотентный): если
    // основной старт (после GetProfile) не сработал — например, приложение
    // поднялось офлайн, а сеть появилась позже — экран выбора авто самое
    // место наверстать.
    unawaited(CarCatalogSyncService.instance.start());
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
      final dueAt = _parseRuDate(_draftString(draft['dueAt']));
      if (dueAt != null) {
        _dueAt = dueAt;
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
      'dueAt': _formatRuDate(_dueAt),
      'note': _noteController.text,
      'assignee': _assigneeToDraft(_assignee),
    };
  }

  // ─── Car pickers ────────────────────────────────────────────────────

  Future<void> _openCarPickerDialog() async {
    const catalogLoadTimeout = Duration(seconds: 12);

    final List<BrandItem> brands;
    try {
      // Cache-first: после первого онлайн-захода (или фонового синка)
      // открывается и офлайн. Timeout — страховка холодного сетевого пути.
      final items = await CarCatalogRepository.instance.getBrands().timeout(
        catalogLoadTimeout,
      );
      brands = List<BrandItem>.from(items)
        ..sort(
          (a, b) => _brandLabel(
            a,
          ).toLowerCase().compareTo(_brandLabel(b).toLowerCase()),
        );
    } catch (e) {
      // Репозиторий бросает только когда кэша ещё нет И сети нет.
      // Пинаем фоновый синк — при появлении сети каталог доедет сам.
      unawaited(CarCatalogSyncService.instance.start());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Каталог авто ещё не загружен. Подключите интернет — '
            'каталог сохранится и дальше будет работать офлайн.',
          ),
          backgroundColor: kRedColor,
        ),
      );
      return;
    }

    if (!mounted) return;

    final selection =
        await showAppAdaptiveBottomSheet<_RequestCarPickerSelection>(
          context: context,
          extent: AppBottomSheetExtent.expanded,
          builder: (context) {
            return _RequestCarPickerDialog(
              brands: brands,
              initialBrand: _brand,
              initialModel: _model,
              initialGeneration: _generation,
              initialRestyling: _restyling,
              loadModels: (brand) => CarCatalogRepository.instance
                  .getModels(brand.id)
                  .timeout(catalogLoadTimeout),
              loadGenerations: (model) => CarCatalogRepository.instance
                  .getGenerations(model.id)
                  .timeout(catalogLoadTimeout),
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

  String get _carMetaLabel {
    final parts = <String>[
      if (_generation != null) 'Поколение ${_generation!.yearRangeOrNumber}',
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
    // shortLabel, не displayNameRu: для одноимённых городов (Мирный,
    // Киров…) в заявке нужен регион, иначе специалист не поймёт, куда
    // ехать.
    setState(() => _city = picked.shortLabel);
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

  // ─── Due date ───────────────────────────────────────────────────────

  Future<void> _pickDueDate() async {
    final picked = await showAppAdaptiveBottomSheet<DateTime>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (context) => _DueDatePickerSheet(initial: _dueAt),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueAt = picked);
    _scheduleDraftAutosave();
  }

  /// «19.07.2026 · через 7 дней» — value для тап-строки срока.
  String get _dueValueLabel => '${_formatRuDate(_dueAt)} · ${_dueRelativeLabel(_dueAt)}';

  // ─── Submit ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    _clearSubmitError();

    final restyling = _restyling;
    if (restyling == null) {
      _setSubmitValidationError('Выберите автомобиль');
      return;
    }
    if (_assignee == null) {
      _setSubmitValidationError('Назначьте специалиста');
      return;
    }

    final dueAt = _dueAt;
    if (dueAt.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      _setSubmitValidationError('Срок не может быть в прошлом');
      return;
    }

    final budgetFrom = int.tryParse(_budgetFromController.text.trim());
    final budgetTo = int.tryParse(_budgetToController.text.trim());
    if (budgetFrom != null && budgetTo != null && budgetTo < budgetFrom) {
      _setSubmitValidationError('Бюджет «до» должен быть не меньше «от»');
      return;
    }
    final maxMileage = int.tryParse(_maxMileageController.text.trim());
    final ownersCount = int.tryParse(_ownersCountController.text.trim());

    final sellerPhone = _sellerPhoneController.text.trim();
    final rawSellerUrl = _sellerUrlController.text.trim();
    final sellerUrl = sparkNormalizeExternalUrl(rawSellerUrl);
    if (rawSellerUrl.isNotEmpty && sellerUrl.isEmpty) {
      _setSubmitValidationError('Ссылка: укажите корректный адрес');
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
        assignedSpecialistId: _assignee?.userId,
        timeout: _assignedCreateRequestTimeout,
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
    } on storage_api.SessionExpiredException catch (e) {
      if (!mounted) return;
      _setSubmitRequestError(e, fallback: 'Сессия истекла. Войдите заново.');
    } catch (e) {
      if (!mounted) return;
      _setSubmitRequestError(e);
    }
  }

  void _clearSubmitError() {
    setState(() {
      _submitErrorTitle = null;
      _submitError = null;
      _submitErrorCopyText = null;
      _submitErrorCode = '';
    });
  }

  void _setSubmitValidationError(String message) {
    setState(() {
      _submitErrorTitle = 'Проверьте заявку';
      _submitError = message;
      _submitErrorCopyText = message;
      _submitErrorCode = '';
    });
  }

  void _setSubmitRequestError(Object error, {String? fallback}) {
    final readable = sparkJoyReadableError(error, fallback: fallback);
    setState(() {
      _submitting = false;
      _submitErrorTitle = 'Не удалось создать заявку';
      _submitError = readable.message;
      _submitErrorCopyText = <String>[
        'Ошибка создания заявки',
        readable.supportText,
      ].where((line) => line.trim().isNotEmpty).join('\n');
      _submitErrorCode = readable.code == SparkJoyErrorCode.serverRejected
          ? ''
          : readable.code;
    });
  }

  // ─── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final progress = _ProgressState.from(
      carDone: _restyling != null,
      specialistDone: _assignee != null,
      dueDone: !_dueAt.isBefore(_todayMidnight()),
    );
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: _CreateRequestAppBar(
        progress: progress.fraction,
        rightLabel: progress.rightLabel,
        hint: progress.hint,
      ),
      bottomNavigationBar: SafeArea(top: false, child: _submitFooter()),
      body: SparkScreenList(
        bottomInset: SparkSize.pageBottomInset,
        children: [
          // ── Автомобиль (required) ────────────────────────────────────
          _carCard(),
          const SizedBox(height: SparkSpace.lg),

          // ── Специалист (required) ────────────────────────────────────
          _tapRowCard(
            icon: Icons.person_outline_rounded,
            label: 'Специалист',
            value: _assignee == null
                ? 'Выбрать исполнителя'
                : _assignee!.displayName,
            placeholder: _assignee == null,
            required: true,
            onTap: _pickAssignee,
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
                    visualDensity: VisualDensity.compact,
                  ),
          ),
          const SizedBox(height: SparkSpace.lg),

          // ── Срок (required) ──────────────────────────────────────────
          _tapRowCard(
            icon: Icons.event_rounded,
            label: 'Срок исполнения',
            value: _dueValueLabel,
            placeholder: false,
            required: true,
            onTap: _pickDueDate,
          ),
          const SizedBox(height: SparkSpace.lg),

          // ── Контакты продавца ────────────────────────────────────────
          _sectionCard(
            icon: Icons.call_outlined,
            title: 'Контакты продавца',
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
                  decoration: sparkInputDecoration(
                    '+7-___-___-__-__',
                    dense: true,
                  ),
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
                    'auto.ru, avito.ru, drive.google.com/…',
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SparkSpace.lg),

          // ── Заметка ──────────────────────────────────────────────────
          _sectionCard(
            icon: Icons.sticky_note_2_outlined,
            title: 'Заметка для специалиста',
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
          const SizedBox(height: SparkSpace.lg),

          // ── Параметры подбора ────────────────────────────────────────
          _sectionCard(
            icon: Icons.tune_rounded,
            title: 'Параметры подбора',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cityRow(),
                const SizedBox(height: SparkSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _budgetFromController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          // 9 digits (макс. 999_999_999 ₽) — sane максимум
                          // для авто, помещается в int32 на случай если бэк
                          // не 64-bit.
                          LengthLimitingTextInputFormatter(9),
                        ],
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: sparkInputDecoration(
                          'Бюджет от, ₽',
                          dense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: SparkSpace.lg),
                    Expanded(
                      child: TextField(
                        controller: _budgetToController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(9),
                        ],
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: sparkInputDecoration('до, ₽', dense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maxMileageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(7),
                        ],
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: sparkInputDecoration(
                          'Пробег до, км',
                          dense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: SparkSpace.lg),
                    Expanded(
                      child: TextField(
                        controller: _ownersCountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: sparkInputDecoration(
                          'Владельцев',
                          dense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_submitError != null) ...[
            const SizedBox(height: SparkSpace.lg),
            SparkErrorState(
              title: _submitErrorTitle ?? 'Ошибка',
              subtitle: _submitErrorCode.isEmpty
                  ? _submitError!
                  : '${_submitError!}\nКод ошибки: $_submitErrorCode — '
                        'назовите его поддержке',
              copyText: _submitErrorCopyText,
              topPadding: 0,
            ),
          ],
        ],
      ),
    );
  }

  // ─── UI helpers ─────────────────────────────────────────────────────

  /// Sticky-footer с основной кнопкой отправки (белая подложка + верхняя
  /// граница, как в макете). Оборачивается в SafeArea выше по дереву.
  Widget _submitFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: kWhiteColor,
        border: Border(top: BorderSide(color: kBorderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.xxxl,
        SparkSpace.xl,
        SparkSpace.xxxl,
        SparkSpace.xxxl,
      ),
      child: SparkPrimaryActionButton(
        label: _submitting ? 'Отправляем…' : 'Отправить заявку',
        icon: Icons.send_rounded,
        busy: _submitting,
        onTap: _submit,
      ),
    );
  }

  /// 44×44 скруглённый квадрат с иконкой — leading-акцент tap-строк.
  Widget _iconSquare(IconData icon) {
    return Container(
      width: SparkSize.icon5xl,
      height: SparkSize.icon5xl,
      decoration: BoxDecoration(
        color: kSurfaceTint,
        borderRadius: BorderRadius.circular(SparkRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: SparkSize.iconLg, color: kSecondaryColor),
    );
  }

  /// Caption-label над value в tap-строке; с красной `*` для обязательных.
  Widget _rowLabel(String text, bool required) {
    if (!required) {
      return MyText(text: text, size: SparkTextSize.body, color: kGreyColor);
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text,
            style: const TextStyle(
              fontSize: SparkTextSize.body,
              color: kGreyColor,
            ),
          ),
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
    );
  }

  /// Тапабельная карточка-строка (иконка-квадрат + label/value + шеврон).
  /// Используется для «Специалист» и «Срок».
  Widget _tapRowCard({
    required IconData icon,
    required String label,
    required String value,
    required bool placeholder,
    required VoidCallback onTap,
    bool required = false,
    Widget? trailing,
  }) {
    return SparkCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SparkSpace.xxl),
      child: Row(
        children: [
          _iconSquare(icon),
          const SizedBox(width: SparkSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _rowLabel(label, required),
                const SizedBox(height: SparkSpace.xxs),
                MyText(
                  text: value,
                  size: SparkTextSize.label,
                  weight: placeholder ? FontWeight.w500 : FontWeight.w600,
                  color: placeholder ? kGreyColor : kTertiaryColor,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SparkSpace.sm),
            trailing,
          ],
          const SizedBox(width: SparkSpace.xs),
          const Icon(
            Icons.chevron_right_rounded,
            size: SparkSize.iconLg,
            color: kGreyColor,
          ),
        ],
      ),
    );
  }

  /// Карточка-секция с header-строкой (иконка + заголовок) и телом.
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return SparkCard(
      padding: const EdgeInsets.all(SparkSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: SparkSize.iconLg, color: kSecondaryColor),
              const SizedBox(width: SparkSpace.xl),
              Expanded(
                child: MyText(
                  text: title,
                  size: SparkTextSize.label,
                  weight: FontWeight.w700,
                  color: kTertiaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.xl),
          child,
        ],
      ),
    );
  }

  /// Строка выбора города внутри «Параметры подбора».
  Widget _cityRow() {
    return InkWell(
      onTap: _pickCity,
      borderRadius: BorderRadius.circular(SparkRadius.md),
      child: Container(
        height: SparkSize.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xl),
        decoration: BoxDecoration(
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(SparkRadius.md),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: SparkSize.iconMd,
              color: kGreyColor,
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: MyText(
                text: _city.isEmpty ? 'Город подбора' : _city,
                size: SparkTextSize.bodyLg,
                color: _city.isEmpty ? kGreyColor : kTertiaryColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: SparkSize.iconMd,
              color: kGreyColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка автомобиля. Пусто — тапабельная строка-приглашение; выбрано —
  /// фото-баннер каталога (целиком, без обрезки) + название + «Изменить».
  Widget _carCard() {
    if (_restyling == null) {
      return _tapRowCard(
        icon: Icons.directions_car_outlined,
        label: 'Автомобиль',
        value: 'Выбрать из каталога',
        placeholder: true,
        required: true,
        onTap: _openCarPickerDialog,
      );
    }
    final meta = _carMetaLabel;
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(SparkRadius.lg),
        border: Border.all(color: kBorderColor),
        boxShadow: _kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CarPhotoBanner(url: _carPhotoUrl.trim()),
          Padding(
            padding: const EdgeInsets.all(SparkSpace.xxl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: 'Автомобиль',
                        size: SparkTextSize.body,
                        color: kGreyColor,
                      ),
                      const SizedBox(height: SparkSpace.xxs),
                      MyText(
                        text: _carButtonName,
                        size: SparkTextSize.sectionTitle,
                        weight: FontWeight.w700,
                        color: kTertiaryColor,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: SparkSpace.xxs),
                        MyText(
                          text: meta,
                          size: SparkTextSize.body,
                          color: kGreyColor,
                          maxLines: 2,
                          textOverflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: SparkSpace.xl),
                OutlinedButton(
                  onPressed: _openCarPickerDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kSecondaryColor,
                    backgroundColor: kWhiteColor,
                    side: const BorderSide(color: kBorderColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.xl,
                    ),
                    minimumSize: const Size(0, SparkSize.actionCompactHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SparkRadius.sm),
                    ),
                    textStyle: const TextStyle(
                      fontSize: SparkTextSize.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Изменить'),
                ),
              ],
            ),
          ),
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

// ── Redesign primitives ──────────────────────────────────────────────

/// Подложка фото-баннера каталога (совпадает с fallback-фоном макета).
const Color _kCarPhotoBg = Color(0xFFEDF1F6);

/// Трек прогресс-бара в шапке.
const Color _kProgressTrack = Color(0xFFE1E6EC);

/// Высота фото-баннера авто (по макету).
const double _kCarPhotoHeight = 158;

/// Тень карточки (совпадает с SparkCard.elevated).
const List<BoxShadow> _kCardShadow = [
  BoxShadow(
    color: kShadowColor,
    blurRadius: 24,
    offset: Offset(0, 8),
    spreadRadius: -4,
  ),
];

/// Производное состояние прогресса заполнения обязательных полей
/// (авто / специалист / срок). Питает прогресс-бар и подсказку в шапке.
class _ProgressState {
  const _ProgressState({
    required this.fraction,
    required this.rightLabel,
    required this.hint,
  });

  final double fraction;
  final String rightLabel;
  final String hint;

  factory _ProgressState.from({
    required bool carDone,
    required bool specialistDone,
    required bool dueDone,
  }) {
    final done = [carDone, specialistDone, dueDone].where((e) => e).length;
    final fraction = done / 3;
    String? next;
    if (!carDone) {
      next = 'выбрать автомобиль';
    } else if (!specialistDone) {
      next = 'назначить специалиста';
    } else if (!dueDone) {
      next = 'указать срок';
    }
    return _ProgressState(
      fraction: fraction,
      rightLabel: next == null ? 'Готово' : '${(fraction * 100).round()}%',
      hint: next == null ? 'Можно отправлять заявку' : 'Осталось: $next',
    );
  }
}

/// Шапка экрана: «Назад» + заголовок + прогресс-бар и подсказка снизу.
class _CreateRequestAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _CreateRequestAppBar({
    required this.progress,
    required this.rightLabel,
    required this.hint,
  });

  final double progress;
  final String rightLabel;
  final String hint;

  static const double _titleHeight = 52;
  static const double _progressHeight = 58;

  @override
  Size get preferredSize =>
      const Size.fromHeight(_titleHeight + _progressHeight);

  @override
  Widget build(BuildContext context) {
    final complete = progress >= 1;
    return AppBar(
      backgroundColor: kPrimaryColor,
      foregroundColor: kSecondaryColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: _titleHeight,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const MyText(
        text: 'Создать заявку',
        size: SparkTextSize.titleLg,
        weight: FontWeight.w800,
        color: kSecondaryColor,
      ),
      shape: const Border(
        bottom: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_progressHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.section,
            SparkSpace.xs,
            SparkSpace.section,
            SparkSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _GradientProgressBar(value: progress)),
                  const SizedBox(width: SparkSpace.lg),
                  MyText(
                    text: rightLabel,
                    size: SparkTextSize.body,
                    weight: FontWeight.w700,
                    color: complete ? kGreenColor : kSecondaryColor,
                    tabularFigures: true,
                  ),
                ],
              ),
              const SizedBox(height: SparkSpace.sm),
              MyText(
                text: hint,
                size: SparkTextSize.body,
                color: kGreyColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Скруглённый прогресс-бар с брендовым сине-градиентным заполнением.
class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(SparkRadius.pill),
      child: SizedBox(
        height: SparkSize.progressThin,
        child: ColoredBox(
          color: _kProgressTrack,
          child: AnimatedFractionallySizedBox(
            duration: SparkMotion.regular,
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kAccentColor, kAccentGlow]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Фото-баннер выбранного авто. Показывает картинку каталога ЦЕЛИКОМ
/// (BoxFit.contain на подложке) — раньше BoxFit.cover обрезал широкие
/// рендеры. При отсутствии/ошибке — аккуратный fallback как в макете.
class _CarPhotoBanner extends StatelessWidget {
  const _CarPhotoBanner({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kCarPhotoHeight,
      width: double.infinity,
      color: _kCarPhotoBg,
      alignment: Alignment.center,
      child: url.isEmpty
          ? const _CarPhotoFallback()
          : CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              height: _kCarPhotoHeight,
              fit: BoxFit.contain,
              errorWidget: (context, _, _) => const _CarPhotoFallback(),
              placeholder: (context, _) => const Center(
                child: SizedBox(
                  width: SparkSize.spinner,
                  height: SparkSize.spinner,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
    );
  }
}

class _CarPhotoFallback extends StatelessWidget {
  const _CarPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: SparkSize.icon6xl,
          height: SparkSize.icon6xl,
          decoration: const BoxDecoration(
            color: kWhiteColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kShadowColor,
                blurRadius: 10,
                offset: Offset(0, 3),
                spreadRadius: -2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.directions_car_outlined,
            size: SparkSize.iconXxl,
            color: kGreyColor,
          ),
        ),
        const SizedBox(height: SparkSpace.lg),
        const MyText(
          text: 'Фото из каталога недоступно',
          size: SparkTextSize.body,
          color: kGreyColor,
        ),
      ],
    );
  }
}

/// Bottom-sheet выбора срока: быстрые пресеты + ручной RU-ввод. Заменяет
/// нативный showDatePicker (в приложении нет flutter_localizations — он
/// был бы англоязычным).
class _DueDatePickerSheet extends StatefulWidget {
  const _DueDatePickerSheet({required this.initial});

  final DateTime initial;

  @override
  State<_DueDatePickerSheet> createState() => _DueDatePickerSheetState();
}

class _DueDatePickerSheetState extends State<_DueDatePickerSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatRuDate(widget.initial));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyPreset(int days) {
    setState(() {
      _controller.text = _formatRuDate(_todayMidnight().add(Duration(days: days)));
      _error = null;
    });
  }

  void _confirm() {
    final parsed = _parseRuDate(_controller.text);
    if (parsed == null) {
      setState(() => _error = 'Формат даты: ДД.ММ.ГГГГ');
      return;
    }
    if (parsed.isBefore(_todayMidnight())) {
      setState(() => _error = 'Срок не может быть в прошлом');
      return;
    }
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.section,
        0,
        SparkSpace.section,
        SparkSpace.section,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MyText(
            text: 'Срок исполнения',
            size: SparkTextSize.modalTitle,
            weight: FontWeight.w800,
          ),
          const SizedBox(height: SparkSpace.xs),
          const MyText(
            text: 'Когда специалист должен выполнить заявку',
            size: SparkTextSize.body,
            color: kGreyColor,
          ),
          const SizedBox(height: SparkSpace.xl),
          Wrap(
            spacing: SparkSpace.md,
            runSpacing: SparkSpace.md,
            children: [
              _DuePresetChip(label: 'Через 3 дня', onTap: () => _applyPreset(3)),
              _DuePresetChip(label: 'Неделя', onTap: () => _applyPreset(7)),
              _DuePresetChip(label: '2 недели', onTap: () => _applyPreset(14)),
              _DuePresetChip(label: 'Месяц', onTap: () => _applyPreset(30)),
            ],
          ),
          const SizedBox(height: SparkSpace.xl),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.datetime,
            inputFormatters: [_RuDateFormatter()],
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: sparkInputDecoration(
              'ДД.ММ.ГГГГ',
              prefixIcon: const Icon(Icons.event_rounded, color: kGreyColor),
              errorText: _error,
            ),
          ),
          const SizedBox(height: SparkSpace.xl),
          SparkPrimaryActionButton(
            label: 'Готово',
            icon: Icons.check_rounded,
            onTap: _confirm,
          ),
        ],
      ),
    );
  }
}

class _DuePresetChip extends StatelessWidget {
  const _DuePresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.chipX,
            vertical: SparkSpace.lg,
          ),
          decoration: BoxDecoration(
            color: kSurfaceTint,
            borderRadius: BorderRadius.circular(SparkRadius.pill),
            border: Border.all(color: kBorderColor),
          ),
          child: MyText(
            text: label,
            size: SparkTextSize.label,
            weight: FontWeight.w700,
            color: kSecondaryColor,
          ),
        ),
      ),
    );
  }
}

/// Сегодняшняя дата в полночь (для сравнения сроков без времени).
DateTime _todayMidnight() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// «сегодня» / «завтра» / «через N дней» / «просрочен» для строки срока.
String _dueRelativeLabel(DateTime due) {
  final diff = DateTime(
    due.year,
    due.month,
    due.day,
  ).difference(_todayMidnight()).inDays;
  if (diff < 0) return 'просрочен';
  if (diff == 0) return 'сегодня';
  if (diff == 1) return 'завтра';
  return 'через $diff ${_pluralDays(diff)}';
}

String _pluralDays(int n) {
  final mod100 = n % 100;
  final mod10 = n % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'дней';
  if (mod10 == 1) return 'день';
  if (mod10 >= 2 && mod10 <= 4) return 'дня';
  return 'дней';
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.xl,
        0,
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
                prefixIcon: const Icon(Icons.search_rounded, color: kGreyColor),
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
        'Пок. ${_selectedGeneration!.yearRangeOrNumber}',
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
        'Модели этой марки ещё не в офлайн-каталоге.\nПроверьте интернет и повторите',
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
        'Поколения этой модели ещё не в офлайн-каталоге.\nПроверьте интернет и повторите',
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
          title: Text('Поколение ${generation.yearRangeOrNumber}'),
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

// Каталожные объекты в черновике сериализуются штатными toJson/tryFromJson
// моделей (storage_api_models.dart) — тот же набор ключей, что и раньше
// (см. голден-тест storage_api_models_json_test.dart), поэтому старые
// черновики читаются без миграции; формат разделён с файловым кэшем
// каталога.
Map<String, dynamic>? _brandToDraft(BrandItem? brand) => brand?.toJson();

BrandItem? _brandFromDraft(dynamic raw) => BrandItem.tryFromJson(raw);

Map<String, dynamic>? _modelToDraft(ModelItem? model) => model?.toJson();

ModelItem? _modelFromDraft(dynamic raw) => ModelItem.tryFromJson(raw);

Map<String, dynamic>? _generationToDraft(GenerationItem? generation) =>
    generation?.toJson();

GenerationItem? _generationFromDraft(dynamic raw) =>
    GenerationItem.tryFromJson(raw);

Map<String, dynamic>? _restylingToDraft(RestylingItem? restyling) =>
    restyling?.toJson();

RestylingItem? _restylingFromDraft(dynamic raw) =>
    RestylingItem.tryFromJson(raw);

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

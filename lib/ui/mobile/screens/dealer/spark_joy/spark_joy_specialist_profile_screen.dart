import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoySpecialistProfileScreen extends StatefulWidget {
  const SparkJoySpecialistProfileScreen({
    super.key,
    this.onBusinessStatusChanged,
  });

  final ValueChanged<String?>? onBusinessStatusChanged;

  @override
  State<SparkJoySpecialistProfileScreen> createState() =>
      _SparkJoySpecialistProfileScreenState();
}

class _SparkJoySpecialistProfileScreenState
    extends State<SparkJoySpecialistProfileScreen> {
  static const List<String> _presetSpecializations = <String>[
    'Подбор под ключ',
    'Осмотр кузова',
    'Техническая диагностика',
    'Компьютерная диагностика',
    'Проверка документов',
    'Юридическая проверка',
    'Выездной осмотр',
    'Экспертное заключение',
  ];

  final _profileFormKey = GlobalKey<FormState>();
  final _innController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _customSpecializationController = TextEditingController();
  final _experienceController = TextEditingController();
  final List<String> _selectedSpecializations = <String>[];
  final List<String> _customSpecializations = <String>[];

  bool _isVerifying = false;
  bool _isSavingProfile = false;
  bool _profileDirty = false;

  // View-by-default for "Информация". The profile opens as a read-only
  // summary (SparkInfoRow list + non-interactive specialization chips);
  // tapping the pencil action flips this flag and reveals the Form with
  // inputs + Save/Cancel buttons. Reduces visual noise on a screen users
  // visit often to glance, rarely to edit.
  bool _profileEditMode = false;
  String? _innError;
  String? _verifiedInn;
  String? _businessType;
  Map<String, dynamic>? _specialistProfile;

  // Real counts of saved drafts + completed reports, loaded from local
  // storage. Fall back to the seed value from sparkSpecialists only while
  // the first load is in flight so the cards never show "0" during a
  // cold start.
  int? _localDraftCount;
  int? _localCompletedCount;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBusinessStatus();
    _loadReportCounts();
  }

  Future<void> _loadReportCounts() async {
    final drafts = await SparkJoyStorage.loadDrafts();
    final completed = await SparkJoyStorage.loadCompleted();
    if (!mounted) return;
    setState(() {
      _localDraftCount = drafts.length;
      _localCompletedCount = completed.length;
    });
  }

  @override
  void dispose() {
    _innController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _customSpecializationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _fallbackSpecialist() {
    return cloneMap(
      sparkSpecialists.firstWhere(
        (s) => sjRead(s, 'id') == kSparkSpecialistId,
        orElse: () => sparkSpecialists.first,
      ),
    );
  }

  Map<String, dynamic> _specialist() {
    final fallback = _fallbackSpecialist();
    final profile = _specialistProfile;
    if (profile == null) return fallback;
    return {...fallback, ...profile};
  }

  void _applyProfileToControllers(Map<String, dynamic> profile) {
    _nameController.text = sjRead(profile, 'name');
    _cityController.text = sjRead(profile, 'city');
    _phoneController.text = sjRead(profile, 'phone');
    _emailController.text = sjRead(profile, 'email');
    _experienceController.text = sjRead(profile, 'experience');
    _applySpecializations(_extractSpecializations(profile));
  }

  bool _containsIgnoreCase(Iterable<String> values, String needle) {
    final normalizedNeedle = needle.trim().toLowerCase();
    if (normalizedNeedle.isEmpty) return false;
    return values.any((item) => item.trim().toLowerCase() == normalizedNeedle);
  }

  List<String> _extractSpecializations(Map<String, dynamic> profile) {
    final fromList = profile['specializations'];
    final result = <String>[];
    if (fromList is List) {
      for (final raw in fromList) {
        final value = raw.toString().trim();
        if (value.isEmpty) continue;
        if (_containsIgnoreCase(result, value)) continue;
        result.add(value);
      }
      if (result.isNotEmpty) return result;
    }
    final fallback = sjRead(profile, 'specialization').trim();
    if (fallback.isEmpty) return result;
    for (final part in fallback.split(RegExp(r'[,;\n]'))) {
      final value = part.trim();
      if (value.isEmpty) continue;
      if (_containsIgnoreCase(result, value)) continue;
      result.add(value);
    }
    return result;
  }

  void _applySpecializations(List<String> values) {
    _selectedSpecializations
      ..clear()
      ..addAll(values);
    _customSpecializations
      ..clear()
      ..addAll(
        values.where(
          (value) => !_containsIgnoreCase(_presetSpecializations, value),
        ),
      );
    _customSpecializationController.clear();
  }

  void _setProfileDirty() {
    if (_profileDirty) return;
    setState(() => _profileDirty = true);
  }

  void _togglePresetSpecialization(String specialization) {
    final index = _selectedSpecializations.indexWhere(
      (item) => item.toLowerCase() == specialization.toLowerCase(),
    );
    setState(() {
      if (index >= 0) {
        _selectedSpecializations.removeAt(index);
      } else {
        _selectedSpecializations.add(specialization);
      }
    });
    _setProfileDirty();
  }

  void _removeCustomSpecialization(String value) {
    setState(() {
      _customSpecializations.removeWhere(
        (item) => item.toLowerCase() == value.toLowerCase(),
      );
      _selectedSpecializations.removeWhere(
        (item) => item.toLowerCase() == value.toLowerCase(),
      );
    });
    _setProfileDirty();
  }

  void _addCustomSpecialization() {
    final raw = _customSpecializationController.text.trim();
    if (raw.isEmpty) return;
    final existsInPreset = _containsIgnoreCase(_presetSpecializations, raw);
    final existsInCustom = _containsIgnoreCase(_customSpecializations, raw);
    final alreadySelected = _containsIgnoreCase(_selectedSpecializations, raw);
    setState(() {
      if (!existsInPreset && !existsInCustom) {
        _customSpecializations.add(raw);
      }
      if (!alreadySelected) {
        _selectedSpecializations.add(raw);
      }
      _customSpecializationController.clear();
    });
    _setProfileDirty();
    FocusScope.of(context).unfocus();
  }

  List<String> _currentSpecializations() {
    final result = <String>[];
    for (final specialization in _selectedSpecializations) {
      final value = specialization.trim();
      if (value.isEmpty) continue;
      if (_containsIgnoreCase(result, value)) continue;
      result.add(value);
    }
    return result;
  }

  Future<void> _loadProfile() async {
    final profile = await SparkJoyStorage.loadSpecialistProfile();
    if (!mounted) return;
    _applyProfileToControllers(profile);
    setState(() {
      _specialistProfile = profile;
      _profileDirty = false;
    });
  }

  Future<void> _loadBusinessStatus() async {
    final inn = await SparkJoyStorage.currentVerifiedInn();
    final businessType = await SparkJoyStorage.currentBusinessType();
    if (!mounted) return;
    setState(() {
      _verifiedInn = inn;
      _businessType = businessType;
      if (inn != null && inn.isNotEmpty) {
        _innController.text = inn;
      }
    });
  }

  String _businessTypeLabel() {
    if (_businessType == 'ip') return 'ИП';
    return 'Компания';
  }

  String? _innValidator(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Введите ИНН';
    final normalized = SparkJoyStorage.normalizeInn(raw);
    if (normalized.length != 10 && normalized.length != 12) {
      return 'ИНН должен содержать 10 или 12 цифр';
    }
    if (!SparkJoyStorage.isValidInn(normalized, strict: false)) {
      return 'Введите корректный ИНН';
    }
    return null;
  }

  Future<void> _verifyInn() async {
    if (_isVerifying) return;
    final validationError = _innValidator(_innController.text);
    if (validationError != null) {
      setState(() {
        _innError = validationError;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isVerifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final businessType = await SparkJoyStorage.verifyInnAndPromote(
      _innController.text,
    );

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
    });

    if (businessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось подтвердить ИНН')),
      );
      return;
    }

    final inn = SparkJoyStorage.normalizeInn(_innController.text);
    setState(() {
      _businessType = businessType;
      _verifiedInn = inn;
      _innController.text = inn;
      _innError = null;
    });

    widget.onBusinessStatusChanged?.call(businessType);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          businessType == 'ip'
              ? 'Тех. проверка пройдена: статус ИП'
              : 'Тех. проверка пройдена: статус Компания',
        ),
      ),
    );
  }

  Future<void> _resetBusinessStatus() async {
    if (_isVerifying) return;
    await SparkJoyStorage.resetBusinessVerification();
    if (!mounted) return;
    setState(() {
      _verifiedInn = null;
      _businessType = null;
    });
    widget.onBusinessStatusChanged?.call(null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Статус сброшен: теперь вы специалист')),
    );
  }

  String? _requiredValidator(String? value, String fieldLabel) {
    if ((value ?? '').trim().isEmpty) {
      return 'Заполните поле: $fieldLabel';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      return 'Введите корректный телефон';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final isValid = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(raw);
    if (!isValid) return 'Введите корректный Email';
    return null;
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSavingProfile = true);
    final current = _specialist();
    final next = {
      ...current,
      'id': sjRead(current, 'id', fallback: kSparkSpecialistId),
      'name': _nameController.text.trim(),
      'city': _cityController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'specialization': _currentSpecializations().join(', '),
      'specializations': _currentSpecializations(),
      'experience': _experienceController.text.trim(),
    };
    await SparkJoyStorage.saveSpecialistProfile(next);

    if (!mounted) return;
    setState(() {
      _specialistProfile = next;
      _profileDirty = false;
      _isSavingProfile = false;
      // Collapse back to the read-only summary after a successful save
      // — users want to see the result of their edit, not stay in
      // edit-mode with the same buttons.
      _profileEditMode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Профиль сохранен')));
  }

  void _cancelProfileEdit() {
    final specialist = _specialist();
    _applyProfileToControllers(specialist);
    setState(() {
      _profileDirty = false;
      _profileEditMode = false;
    });
  }

  Widget _buildProfileInfoRead(Map<String, dynamic> specialist) {
    final specs = _currentSpecializations();
    String valueOrDash(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '—' : trimmed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: hint + pencil "Изменить" action.
        Row(
          children: [
            const Expanded(
              child: MyText(
                text: 'Контактные данные и специализация',
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _profileEditMode = true);
              },
              icon: const Icon(Icons.edit_outlined, size: SparkSize.iconSm),
              label: const Text('Изменить'),
              style: TextButton.styleFrom(
                foregroundColor: kSecondaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.md,
                  vertical: SparkSpace.xs,
                ),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.md),
        SparkInfoRow(
          label: 'ФИО',
          value: valueOrDash(
            _nameController.text.isEmpty
                ? sjRead(specialist, 'name')
                : _nameController.text,
          ),
        ),
        SparkInfoRow(
          label: 'Город',
          value: valueOrDash(
            _cityController.text.isEmpty
                ? sjRead(specialist, 'city')
                : _cityController.text,
          ),
        ),
        // Specialization — read-only chips so the scale is obvious at a
        // glance without re-reading a comma-separated list.
        const SizedBox(height: SparkSpace.md),
        const MyText(
          text: 'Специализация',
          size: SparkTextSize.body,
          color: kGreyColor,
        ),
        const SizedBox(height: SparkSpace.sm),
        if (specs.isEmpty)
          const MyText(
            text: '—',
            size: SparkTextSize.body,
            color: kGreyColor,
          )
        else
          Wrap(
            spacing: SparkSpace.sm,
            runSpacing: SparkSpace.sm,
            children: specs
                .map(
                  (s) => SparkChip(
                    text: s,
                    background: kSecondaryColor.withValues(alpha: 0.08),
                    color: kSecondaryColor,
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: SparkSpace.md),
        SparkInfoRow(
          label: 'Опыт',
          value: valueOrDash(
            _experienceController.text.isEmpty
                ? sjRead(specialist, 'experience')
                : _experienceController.text,
          ),
        ),
        SparkInfoRow(
          label: 'Телефон',
          value: valueOrDash(
            _phoneController.text.isEmpty
                ? sjRead(specialist, 'phone')
                : _phoneController.text,
          ),
        ),
        SparkInfoRow(
          label: 'Email',
          value: valueOrDash(
            _emailController.text.isEmpty
                ? sjRead(specialist, 'email')
                : _emailController.text,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoEdit() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileTextField(
            controller: _nameController,
            label: 'ФИО',
            hint: 'Имя специалиста',
            validator: (value) => _requiredValidator(value, 'ФИО'),
          ),
          _profileTextField(
            controller: _cityController,
            label: 'Город',
            hint: 'Город осмотров',
            validator: (value) => _requiredValidator(value, 'Город'),
          ),
          _buildSpecializationEditor(),
          _profileTextField(
            controller: _experienceController,
            label: 'Опыт',
            hint: 'Например: 8 лет',
          ),
          _profileTextField(
            controller: _phoneController,
            label: 'Телефон',
            hint: '+7...',
            keyboardType: TextInputType.phone,
            validator: _phoneValidator,
          ),
          _profileTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          const SizedBox(height: SparkSpace.xs),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: SparkSize.actionHeight,
                  child: OutlinedButton(
                    onPressed: _isSavingProfile ? null : _cancelProfileEdit,
                    child: const Text('Отмена'),
                  ),
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: SizedBox(
                  height: SparkSize.actionHeight,
                  child: FilledButton(
                    onPressed: _isSavingProfile ? null : _saveProfile,
                    child: Text(
                      _isSavingProfile ? 'Сохраняем...' : 'Сохранить',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(
            text: label,
            size: SparkTextSize.body,
            color: kGreyColor,
            paddingBottom: SparkSpace.sm,
          ),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => _setProfileDirty(),
            decoration: sparkInputDecoration(hint ?? label),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationChip(String specialization) {
    final isCustom = _containsIgnoreCase(
      _customSpecializations,
      specialization,
    );
    final selected = _containsIgnoreCase(
      _selectedSpecializations,
      specialization,
    );
    return InputChip(
      selected: selected,
      label: Text(specialization),
      onSelected: (_) => _togglePresetSpecialization(specialization),
      onDeleted: isCustom
          ? () => _removeCustomSpecialization(specialization)
          : null,
      selectedColor: kSecondaryColor.withValues(alpha: 0.14),
      backgroundColor: isCustom ? kWhiteColor : kInputBgColor,
      side: BorderSide(color: selected ? kSecondaryColor : kBorderColor),
      labelStyle: TextStyle(
        color: selected ? kSecondaryColor : kTertiaryColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: SparkTextSize.body,
      ),
      deleteIconColor: kSecondaryColor,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
    );
  }

  List<String> _allSpecializationOptions() {
    final result = <String>[];
    for (final item in _presetSpecializations) {
      if (_containsIgnoreCase(result, item)) continue;
      result.add(item);
    }
    for (final item in _customSpecializations) {
      if (_containsIgnoreCase(result, item)) continue;
      result.add(item);
    }
    return result;
  }

  Widget _buildSpecializationEditor() {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Специализация',
            size: SparkTextSize.body,
            color: kGreyColor,
            paddingBottom: SparkSpace.md,
          ),
          Wrap(
            spacing: SparkSpace.md,
            runSpacing: SparkSpace.md,
            children: _allSpecializationOptions()
                .map(_buildSpecializationChip)
                .toList(growable: false),
          ),
          const SizedBox(height: SparkSpace.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MyText(
                      text: 'Своя специализация',
                      size: SparkTextSize.body,
                      color: kGreyColor,
                      paddingBottom: SparkSpace.sm,
                    ),
                    TextField(
                      controller: _customSpecializationController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addCustomSpecialization(),
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: sparkInputDecoration('Напишите вручную'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              SizedBox(
                width: 120,
                height: SparkSize.actionHeight,
                child: OutlinedButton.icon(
                  onPressed: _addCustomSpecialization,
                  icon: const Icon(Icons.add_rounded, size: SparkSize.iconSm),
                  label: const Text('Добавить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final specialist = _specialist();
    final profileName = _nameController.text.trim().isEmpty
        ? sjRead(specialist, 'name', fallback: 'Специалист')
        : _nameController.text.trim();
    final hasVerifiedBusiness = (_verifiedInn ?? '').isNotEmpty;

    return SparkScreenList(
      bottomInset: 56,
      onRefresh: () async {
        await Future.wait([
          _loadProfile(),
          _loadBusinessStatus(),
          _loadReportCounts(),
        ]);
      },
      children: [
        const SparkPageHeader(
          title: 'Мой профиль',
          subtitle: 'Данные специалиста и статус компании',
        ),
        SparkCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SparkInitialsAvatar(
                name: profileName,
                size: SparkSize.icon6xl,
                textSize: SparkTextSize.modalTitle,
              ),
              const SizedBox(width: SparkSpace.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: profileName,
                      size: SparkTextSize.title,
                      weight: FontWeight.w800,
                      lineHeight: 1.30,
                      tracking: true,
                    ),
                    const SizedBox(height: SparkSpace.xs),
                    Wrap(
                      spacing: SparkSpace.sm,
                      runSpacing: SparkSpace.sm,
                      children: [
                        SparkChip(
                          text:
                              sparkFormatLabels[sjRead(specialist, 'format')] ??
                              'Специалист',
                          background: kSecondaryColor.withValues(alpha: 0.1),
                          color: kSecondaryColor,
                        ),
                        SparkChip(
                          text: sjRead(specialist, 'status') == 'active'
                              ? 'Активен'
                              : 'Неактивен',
                          background: sjRead(specialist, 'status') == 'active'
                              ? kGreenColor.withValues(alpha: 0.15)
                              : kGreyColor.withValues(alpha: 0.15),
                          color: sjRead(specialist, 'status') == 'active'
                              ? kGreenColor
                              : kGreyColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Reordered: Stats before Info before Business. The old order
        // (Info → Business → Stats at the very bottom) buried the
        // glanceable counters under a 6-field form. Users read stats
        // often and edit profile rarely, so the top-to-bottom ordering
        // matches actual interaction frequency.
        const SparkSectionTitle('Статистика', top: SparkSpace.xxl),
        Row(
          children: [
            Expanded(
              child: SparkCard(
                child: Column(
                  children: [
                    MyText(
                      text: (_localCompletedCount ?? 0).toString(),
                      size: SparkSize.iconXl,
                      weight: FontWeight.w800,
                      color: kSecondaryColor,
                      tabularFigures: true,
                    ),
                    const MyText(
                      text: 'Отчётов',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SparkSpace.lg),
            Expanded(
              child: SparkCard(
                child: Column(
                  children: [
                    MyText(
                      text: (_localDraftCount ?? 0).toString(),
                      size: SparkSize.iconXl,
                      weight: FontWeight.w800,
                      color: kSecondaryColor,
                      tabularFigures: true,
                    ),
                    const MyText(
                      text: 'Активных осмотров',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SparkSectionTitle('Информация', top: SparkSpace.xxl),
        SparkCard(
          child: _profileEditMode
              ? _buildProfileInfoEdit()
              : _buildProfileInfoRead(specialist),
        ),
        const SparkSectionTitle('Проверка компании', top: SparkSpace.xxl),
        SparkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasVerifiedBusiness) ...[
                SparkInfoRow(label: 'Статус', value: _businessTypeLabel()),
                SparkInfoRow(label: 'Подтвержденный ИНН', value: _verifiedInn!),
                const SizedBox(height: SparkSpace.md),
              ] else
                const MyText(
                  text:
                      'Добавьте ИНН для тех. проверки статуса компании или ИП',
                  size: SparkTextSize.body,
                  color: kGreyColor,
                  paddingBottom: SparkSpace.md,
                ),
              const MyText(
                text: 'ИНН',
                size: SparkTextSize.body,
                color: kGreyColor,
                paddingBottom: SparkSpace.sm,
              ),
              TextField(
                controller: _innController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (_) {
                  if (_innError != null) {
                    setState(() => _innError = null);
                  }
                },
                decoration: sparkInputDecoration(
                  '10 или 12 цифр',
                  errorText: _innError,
                ),
              ),
              const SizedBox(height: SparkSpace.lg),
              // Business verification is an *occasional* action on this
              // screen — demoting from FilledButton to OutlinedButton
              // leaves a single primary (Информация → «Сохранить» in
              // edit mode) and stops these two buttons from fighting for
              // visual weight. Also bumps height to actionHeight (44pt)
              // so the tap target matches iOS/Android minimums.
              SizedBox(
                height: SparkSize.actionHeight,
                child: OutlinedButton(
                  onPressed: _isVerifying ? null : _verifyInn,
                  child: Text(
                    _isVerifying
                        ? 'Проверяем...'
                        : hasVerifiedBusiness
                        ? 'Проверить снова'
                        : 'Проверить ИНН',
                  ),
                ),
              ),
              if (hasVerifiedBusiness) ...[
                const SizedBox(height: SparkSpace.md),
                SizedBox(
                  height: SparkSize.actionHeight,
                  child: TextButton(
                    onPressed: _resetBusinessStatus,
                    style: TextButton.styleFrom(foregroundColor: kRedColor),
                    child: const Text('Сбросить статус до специалиста'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

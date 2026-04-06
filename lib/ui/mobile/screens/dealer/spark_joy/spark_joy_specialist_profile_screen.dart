import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_storage.dart';
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
  String? _innError;
  String? _verifiedInn;
  String? _businessType;
  Map<String, dynamic>? _specialistProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBusinessStatus();
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
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Профиль сохранен')));
  }

  void _resetProfileDraft() {
    final specialist = _specialist();
    _applyProfileToControllers(specialist);
    setState(() => _profileDirty = false);
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        onChanged: (_) => _setProfileDirty(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSpecializationChip(String specialization) {
    final isCustom = _containsIgnoreCase(_customSpecializations, specialization);
    final selected = _containsIgnoreCase(
      _selectedSpecializations,
      specialization,
    );
    return InputChip(
      selected: selected,
      label: Text(specialization),
      onSelected: (_) => _togglePresetSpecialization(specialization),
      onDeleted: isCustom ? () => _removeCustomSpecialization(specialization) : null,
      selectedColor: kSecondaryColor.withValues(alpha: 0.14),
      backgroundColor: isCustom ? kWhiteColor : kInputBgColor,
      side: BorderSide(color: selected ? kSecondaryColor : kBorderColor),
      labelStyle: TextStyle(
        color: selected ? kSecondaryColor : kTertiaryColor,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 12,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Специализация',
            size: 12,
            color: kGreyColor,
            paddingBottom: 8,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allSpecializationOptions()
                .map(_buildSpecializationChip)
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customSpecializationController,
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onSubmitted: (_) => _addCustomSpecialization(),
                  decoration: const InputDecoration(
                    labelText: 'Своя специализация',
                    hintText: 'Напишите вручную',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                height: 44,
                child: MyBorderButton(
                  buttonText: 'Добавить',
                  textSize: 12,
                  onTap: _addCustomSpecialization,
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

    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        const MyText(text: 'Мой профиль', size: 22, weight: FontWeight.w700),
        const SizedBox(height: 12),
        SparkCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kSecondaryColor.withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: MyText(
                  text: sjInitials(profileName),
                  size: 20,
                  weight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: profileName,
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
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
        const SparkSectionTitle('Информация', top: 14),
        SparkCard(
          child: Form(
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
                const SizedBox(height: 4),
                SizedBox(
                  height: 40,
                  child: MyButton(
                    buttonText: _isSavingProfile
                        ? 'Сохраняем...'
                        : 'Сохранить профиль',
                    onTap: _isSavingProfile ? () {} : _saveProfile,
                    bgColor: _isSavingProfile ? kGreyColor : kSecondaryColor,
                  ),
                ),
                if (_profileDirty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: MyBorderButton(
                      buttonText: 'Отменить изменения',
                      textSize: 12,
                      onTap: _resetProfileDraft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SparkSectionTitle('Проверка компании', top: 14),
        SparkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasVerifiedBusiness) ...[
                SparkInfoRow(label: 'Статус', value: _businessTypeLabel()),
                SparkInfoRow(label: 'Подтвержденный ИНН', value: _verifiedInn!),
                const SizedBox(height: 8),
              ] else
                const MyText(
                  text:
                      'Добавьте ИНН для тех. проверки статуса компании или ИП',
                  size: 12,
                  color: kGreyColor,
                  paddingBottom: 8,
                ),
              TextField(
                controller: _innController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                onChanged: (_) {
                  if (_innError != null) {
                    setState(() => _innError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'ИНН',
                  hintText: '10 или 12 цифр',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: _innError,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: MyButton(
                  buttonText: _isVerifying
                      ? 'Проверяем...'
                      : hasVerifiedBusiness
                      ? 'Проверить снова'
                      : 'Проверить ИНН',
                  onTap: _isVerifying ? () {} : _verifyInn,
                  bgColor: _isVerifying ? kGreyColor : kSecondaryColor,
                ),
              ),
              if (hasVerifiedBusiness) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: MyBorderButton(
                    buttonText: 'Сбросить статус до специалиста',
                    textSize: 12,
                    onTap: _resetBusinessStatus,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SparkSectionTitle('Статистика', top: 14),
        Row(
          children: [
            Expanded(
              child: SparkCard(
                child: Column(
                  children: [
                    MyText(
                      text: sjRead(specialist, 'reportCount', fallback: '0'),
                      size: 24,
                      weight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                    const MyText(text: 'Отчётов', size: 11, color: kGreyColor),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SparkCard(
                child: Column(
                  children: [
                    MyText(
                      text: sjRead(
                        specialist,
                        'activeInspections',
                        fallback: '0',
                      ),
                      size: 24,
                      weight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                    const MyText(
                      text: 'Активных осмотров',
                      size: 11,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
  final _formKey = GlobalKey<FormState>();
  final _innController = TextEditingController();

  bool _isVerifying = false;
  String? _verifiedInn;
  String? _businessType;

  @override
  void initState() {
    super.initState();
    _loadBusinessStatus();
  }

  @override
  void dispose() {
    _innController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _specialist() {
    return cloneMap(
      sparkSpecialists.firstWhere(
        (s) => sjRead(s, 'id') == kSparkSpecialistId,
        orElse: () => sparkSpecialists.first,
      ),
    );
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
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

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

  @override
  Widget build(BuildContext context) {
    final specialist = _specialist();
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
                  text: sjInitials(sjRead(specialist, 'name')),
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
                      text: sjRead(specialist, 'name', fallback: 'Специалист'),
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
          child: Column(
            children: [
              SparkInfoRow(
                label: 'Город',
                value: sjRead(specialist, 'city', fallback: '-'),
              ),
              SparkInfoRow(
                label: 'Специализация',
                value: sjRead(specialist, 'specialization', fallback: '-'),
              ),
              SparkInfoRow(
                label: 'Опыт',
                value: sjRead(specialist, 'experience', fallback: '-'),
              ),
              SparkInfoRow(
                label: 'Рейтинг',
                value: '⭐ ${sjRead(specialist, 'rating', fallback: '-')}',
              ),
              SparkInfoRow(
                label: 'Телефон',
                value: sjRead(specialist, 'phone', fallback: '-'),
              ),
              SparkInfoRow(
                label: 'Email',
                value: sjRead(specialist, 'email', fallback: '-'),
              ),
            ],
          ),
        ),
        const SparkSectionTitle('Проверка компании', top: 14),
        SparkCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasVerifiedBusiness) ...[
                  SparkInfoRow(label: 'Статус', value: _businessTypeLabel()),
                  SparkInfoRow(
                    label: 'Подтвержденный ИНН',
                    value: _verifiedInn!,
                  ),
                  const SizedBox(height: 8),
                ] else
                  const MyText(
                    text:
                        'Добавьте ИНН для тех. проверки статуса компании или ИП',
                    size: 12,
                    color: kGreyColor,
                    paddingBottom: 8,
                  ),
                TextFormField(
                  controller: _innController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  validator: _innValidator,
                  decoration: const InputDecoration(
                    labelText: 'ИНН',
                    hintText: '10 или 12 цифр',
                    border: OutlineInputBorder(),
                    isDense: true,
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
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: MyBorderButton(
            buttonText: 'Редактировать профиль',
            textSize: 12,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Редактирование профиля в разработке'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

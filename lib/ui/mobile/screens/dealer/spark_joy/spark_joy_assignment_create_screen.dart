import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoyAssignmentCreateScreen extends StatefulWidget {
  const SparkJoyAssignmentCreateScreen({super.key});

  @override
  State<SparkJoyAssignmentCreateScreen> createState() =>
      _SparkJoyAssignmentCreateScreenState();
}

class _SparkJoyAssignmentCreateScreenState
    extends State<SparkJoyAssignmentCreateScreen> {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  final _commentController = TextEditingController();
  final _phoneController = TextEditingController(text: '+7');

  String _specialistId = '';
  String _phoneError = '';

  List<Map<String, dynamic>> get _specialists {
    return sparkSpecialists
        .where((s) => sjRead(s, 'companyId') == kSparkCompanyId)
        .map(cloneMap)
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _commentController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '+7';
    if (digits.startsWith('7') || digits.startsWith('8')) {
      return '+7${digits.substring(1, digits.length > 11 ? 11 : digits.length)}';
    }
    return '+7${digits.substring(0, digits.length > 10 ? 10 : digits.length)}';
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^\+7\d{10}$').hasMatch(value);
  }

  void _create() {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() => _phoneError = 'Введите номер в формате +7XXXXXXXXXX');
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Заявка создана')));
    Navigator.of(context).pop(true);
  }

  Widget _label(String text) {
    return MyText(
      text: text,
      size: 12,
      color: kGreyColor,
      weight: FontWeight.w600,
      paddingBottom: 6,
      paddingTop: 2,
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: kWhiteColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kSecondaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая заявка')),
      body: ListView(
        padding: AppSizes.DEFAULT.copyWith(bottom: 24),
        children: [
          _label('Название заявки'),
          TextField(
            controller: _titleController,
            decoration: _fieldDecoration(
              'Например: Осмотр Audi A4 для клиента',
            ),
          ),
          const SizedBox(height: 10),
          _label('Ссылка на объявление'),
          TextField(
            controller: _urlController,
            decoration: _fieldDecoration('https://auto.ru/...'),
          ),
          const SizedBox(height: 10),
          _label('Телефон для связи'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (value) {
              final formatted = _formatPhone(value);
              if (formatted == _phoneController.text) return;
              _phoneController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
              if (_phoneError.isNotEmpty) {
                setState(() => _phoneError = '');
              }
            },
            decoration: _fieldDecoration(
              '+79528168245',
            ).copyWith(errorText: _phoneError.isEmpty ? null : _phoneError),
          ),
          const SizedBox(height: 10),
          _label('Специалист'),
          DropdownButtonFormField<String>(
            value: _specialistId.isEmpty ? null : _specialistId,
            decoration: _fieldDecoration('Выберите специалиста'),
            items: _specialists
                .map(
                  (specialist) => DropdownMenuItem<String>(
                    value: sjRead(specialist, 'id'),
                    child: Text(
                      '${sjRead(specialist, 'name')} · ${sparkFormatLabels[sjRead(specialist, 'format')] ?? ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _specialistId = value ?? ''),
          ),
          const SizedBox(height: 10),
          _label('Комментарий'),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: _fieldDecoration('Доп. информация для специалиста...'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: MyBorderButton(
                    buttonText: 'Отмена',
                    textSize: 12,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: MyButton(
                    buttonText: 'Создать',
                    textSize: 12,
                    onTap: _create,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

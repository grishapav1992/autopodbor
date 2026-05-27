import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_error_snackbar.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyInviteByPhoneDialog extends StatefulWidget {
  const SparkJoyInviteByPhoneDialog({super.key, required this.onInvite});

  final Future<String> Function(String phone) onInvite;

  @override
  State<SparkJoyInviteByPhoneDialog> createState() =>
      _SparkJoyInviteByPhoneDialogState();
}

class _SparkJoyInviteByPhoneDialogState
    extends State<SparkJoyInviteByPhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final name = await widget.onInvite(_phoneController.text);
      if (!mounted) return;
      Navigator.of(context).pop(name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = sparkJoyReadableErrorText(e);
      });
    }
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'Введите телефон специалиста';
    }
    final significantDigits =
        digits.length == 11 &&
            (digits.startsWith('7') || digits.startsWith('8'))
        ? digits.substring(1)
        : digits;
    if (significantDigits.length < 10) {
      return 'Введите номер полностью';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = math.min(
      SparkSize.modalWide,
      screenWidth - SparkSpace.section * 2,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.section,
        vertical: SparkSpace.section,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SparkRadius.xl),
      ),
      child: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.section,
            SparkSpace.section,
            SparkSpace.section,
            SparkSpace.xxxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: SparkSize.icon5xl,
                      height: SparkSize.icon5xl,
                      decoration: BoxDecoration(
                        color: kSurfaceTint,
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: kSecondaryColor,
                        size: SparkSize.iconXl,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.xl),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: 'Пригласить в штат',
                            size: SparkTextSize.modalTitle,
                            weight: FontWeight.w700,
                          ),
                          SizedBox(height: SparkSpace.sm),
                          MyText(
                            text:
                                'Введите телефон зарегистрированного специалиста. После принятия приглашения он появится в штате компании.',
                            size: SparkTextSize.bodyLg,
                            color: kGreyColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.section),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [RuPhoneFormatter()],
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validatePhone,
                  onChanged: (_) {
                    if (_error == null) return;
                    setState(() {
                      _error = null;
                    });
                  },
                  onFieldSubmitted: (_) => _submit(),
                  decoration: sparkInputDecoration(
                    '+7___-___-__-__',
                    labelText: 'Телефон специалиста',
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: kGreyColor,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: SparkSpace.md),
                  Container(
                    padding: const EdgeInsets.all(SparkSpace.xl),
                    decoration: BoxDecoration(
                      color: kRedColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(SparkRadius.md),
                      border: Border.all(
                        color: kRedColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: MyText(
                      text: _error!,
                      size: SparkTextSize.body,
                      color: kRedColor,
                    ),
                  ),
                ],
                const SizedBox(height: SparkSpace.section),
                SizedBox(
                  height: SparkSize.actionHeight,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(
                            width: SparkSize.spinner,
                            height: SparkSize.spinner,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kWhiteColor,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Отправляем...' : 'Отправить'),
                  ),
                ),
                const SizedBox(height: SparkSpace.md),
                SizedBox(
                  height: SparkSize.actionHeight,
                  child: OutlinedButton(
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).pop<String>(),
                    child: const Text('Отмена'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

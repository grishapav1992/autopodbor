import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_ui.dart';

class SparkJoyNewReportNameScreen extends StatefulWidget {
  const SparkJoyNewReportNameScreen({super.key, this.companyMode = false});

  final bool companyMode;

  @override
  State<SparkJoyNewReportNameScreen> createState() =>
      _SparkJoyNewReportNameScreenState();
}

class _SparkJoyNewReportNameScreenState
    extends State<SparkJoyNewReportNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Создаёт отчёт и открывает степпер — компания/специалист заполняет его
  /// сам. Назначение отчёта на сотрудника здесь убрано: теперь это делается
  /// через раздел «Заявки» (создать заявку → выбрать исполнителя).
  Future<void> _create() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final name = _controller.text.trim();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(initialReportName: name),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(created == true);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _controller.text.trim().isNotEmpty;
    return SparkPageScaffold(
      appBar: sparkAppBar(title: 'Новый отчёт'),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SparkCard(
                padding: const EdgeInsets.all(SparkSpace.xl),
                radius: SparkRadius.md,
                backgroundColor: kWhiteColor,
                child: Row(
                  children: [
                    Container(
                      width: SparkSize.navStepBadge,
                      height: SparkSize.navStepBadge,
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(SparkRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.description_outlined,
                        color: kSecondaryColor,
                        size: SparkSize.iconSm,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: MyText(
                        text: widget.companyMode
                            ? 'Создайте отчёт и начните осмотр. Назначить '
                                  'исполнителя можно через раздел «Заявки».'
                            : 'Введите название и начните осмотр',
                        size: SparkTextSize.body,
                        color: kGreyColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SparkSpace.xl),
              SparkCard(
                padding: const EdgeInsets.fromLTRB(
                  SparkSpace.xl,
                  SparkSpace.xl,
                  SparkSpace.xl,
                  SparkSpace.md,
                ),
                radius: SparkRadius.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MyText(
                      text: 'Название отчёта',
                      size: SparkTextSize.title,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: SparkSpace.md),
                    TextFormField(
                      controller: _controller,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => unawaited(_create()),
                      validator: (value) {
                        final normalized = (value ?? '').trim();
                        if (normalized.isEmpty) {
                          return 'Введите название отчёта';
                        }
                        return null;
                      },
                      decoration: sparkInputDecoration(
                        'Например: Toyota Camry для клиента',
                      ),
                    ),
                    const SizedBox(height: SparkSpace.sm),
                    const MyText(
                      text: 'Название поможет быстро найти отчёт в списке',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SparkSpace.section),
              IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.55,
                  child: SparkPrimaryActionButton(
                    label: 'Создать и начать осмотр',
                    showIcon: false,
                    onTap: () => unawaited(_create()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';

import 'spark_joy_assignee_picker.dart';
import 'spark_joy_create_report_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_storage.dart';
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
  SparkJoyAssigneeSelection _assignee = const SparkJoyAssigneeSelection();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "Создать" action. Branches on the assignee selection:
  ///   • empty selection → open the full stepper so the company (or
  ///     specialist) can fill the report themselves.
  ///   • specialist / phone / invite → persist a minimal "pending"
  ///     draft so it shows up for the assignee, fire a notification
  ///     stub, and close the form with a toast. The company does not
  ///     open the stepper for work they're not doing.
  Future<void> _create() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final name = _controller.text.trim();

    if (_assignee.isEmpty) {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SparkJoyCreateReportScreen(
            initialReportName: name,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created == true);
      return;
    }

    await _createAssignedDraft(name);
  }

  Future<void> _createAssignedDraft(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final draftId = 'spark_draft_${now.microsecondsSinceEpoch}';
    final businessType = await SparkJoyStorage.currentBusinessType();
    final verifiedInn = await SparkJoyStorage.currentVerifiedInn();

    // Minimal shape consumed by `_loadDraftIntoState` + the reports-list
    // `_isVisibleDraft` filter. Fields left empty fall through the
    // draft-init `_read` fallbacks without breaking anything.
    final draft = <String, dynamic>{
      'id': draftId,
      'reportName': name,
      'reportNumber': '',
      'currentStep': 1,
      'createdAt': _formatDate(now),
      'lastSavedAtIso': now.toIso8601String(),
      'companyId': kSparkCompanyId,
      'companyName': _companyName(),
      'businessType': businessType ?? 'company',
      'verifiedInn': verifiedInn ?? '',
      'assignedSpecialistId': _assignee.specialistId,
      'assignedSpecialistName': _assignee.specialistName,
      'specialistId': _assignee.specialistId,
      'specialistName': _assignee.specialistName,
      'staffInviteLink': _assignee.inviteLink,
      'status': _assignee.inviteLink.isNotEmpty ? 'awaiting_invite' : 'assigned',
    };

    await SparkJoyStorage.upsertDraft(draft);

    // TODO(spark-joy): replace with real push/SMS dispatch when backend
    // lands. Call sites already modeled:
    //   • specialistId → direct notification to the specialist
    //   • inviteLink   → invite sent, push arrives after user installs
    if (_assignee.specialistId.isNotEmpty) {
      debugPrint(
        '[spark_joy] assign-notification → user=${_assignee.specialistId} '
        '(${_assignee.specialistName}) report=$draftId',
      );
    } else {
      debugPrint(
        '[spark_joy] invite-pending → link=${_assignee.inviteLink} '
        'report=$draftId',
      );
    }

    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(_successSnackbar())));
    Navigator.of(context).pop(true);
  }

  String _successSnackbar() {
    if (_assignee.specialistId.isNotEmpty) {
      final who = _assignee.specialistName.isEmpty
          ? 'исполнителю'
          : _assignee.specialistName;
      return 'Отчёт создан и отправлен $who';
    }
    return 'Отчёт создан, ссылка-приглашение готова';
  }

  String _companyName() {
    final c = sparkCompanies.firstWhere(
      (it) => (it['id'] ?? '').toString() == kSparkCompanyId,
      orElse: () => const {'name': 'Компания'},
    );
    return (c['name'] ?? 'Компания').toString();
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  /// Button label reflects what will actually happen: "открыть степпер"
  /// vs "отправить и закрыть". Keeps the user from wondering what a
  /// single "Создать" button does in two different flows.
  String _primaryButtonLabel() {
    if (_assignee.isEmpty) return 'Создать и начать осмотр';
    if (_assignee.specialistId.isNotEmpty) {
      final who = _assignee.specialistName.isEmpty
          ? 'исполнителю'
          : _assignee.specialistName;
      return 'Создать и отправить $who';
    }
    return 'Создать и отправить по ссылке';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _controller.text.trim().isNotEmpty;
    return SparkPageScaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Новый отчёт')),
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
                            ? 'Создайте отчёт и назначьте исполнителя'
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
              if (widget.companyMode) ...[
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
                        text: 'Исполнитель отчёта',
                        size: SparkTextSize.title,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: SparkSpace.md),
                      SparkJoyAssigneeField(
                        companyId: kSparkCompanyId,
                        selection: _assignee,
                        onChanged: (sel) =>
                            setState(() => _assignee = sel),
                      ),
                      const SizedBox(height: SparkSpace.sm),
                      const MyText(
                        text:
                            'Можно назначить позже — компания, сотрудник или ссылка-приглашение.',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: SparkSpace.section),
              IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1 : 0.55,
                  child: SparkPrimaryActionButton(
                    label: _primaryButtonLabel(),
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

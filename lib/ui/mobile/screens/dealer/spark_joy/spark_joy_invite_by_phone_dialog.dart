import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_error_snackbar.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Итог распознавания введённого телефона в конкретного специалиста.
/// Зеркалит логику вкладки «По телефону» в выборе специалиста для заявки
/// (`spark_joy_company_specialist_picker.dart`): по номеру однозначно
/// определяем человека и показываем его ещё до отправки приглашения.
enum InvitePhoneLookupStatus {
  /// По номеру никого не нашли (специалист не зарегистрирован).
  notFound,

  /// Специалист найден, но уже состоит в штате компании.
  alreadyInStaff,

  /// Специалист найден и его можно пригласить.
  available,
}

class InvitePhoneLookupResult {
  const InvitePhoneLookupResult.notFound()
    : status = InvitePhoneLookupStatus.notFound,
      specialist = null;
  const InvitePhoneLookupResult.alreadyInStaff(this.specialist)
    : status = InvitePhoneLookupStatus.alreadyInStaff;
  const InvitePhoneLookupResult.available(this.specialist)
    : status = InvitePhoneLookupStatus.available;

  final InvitePhoneLookupStatus status;
  final SpecialistItem? specialist;
}

class SparkJoyInviteByPhoneDialog extends StatefulWidget {
  const SparkJoyInviteByPhoneDialog({
    super.key,
    required this.onLookup,
    required this.onInvite,
  });

  /// Определяет специалиста по введённому телефону (без побочных эффектов).
  /// Вызывается автоматически с дебаунсом по мере ввода номера.
  final Future<InvitePhoneLookupResult> Function(String phone) onLookup;

  /// Отправляет приглашение по подтверждённому номеру и возвращает имя
  /// приглашённого специалиста.
  final Future<String> Function(String phone) onInvite;

  @override
  State<SparkJoyInviteByPhoneDialog> createState() =>
      _SparkJoyInviteByPhoneDialogState();
}

class _SparkJoyInviteByPhoneDialogState
    extends State<SparkJoyInviteByPhoneDialog> {
  final _phoneController = TextEditingController();
  Timer? _searchDebounce;

  /// Последние 10 значащих цифр введённого номера, либо '' если номер ещё
  /// не полный. Используется как ключ против гонки устаревших ответов.
  String _normalized = '';
  bool _searching = false;
  bool _sending = false;
  String? _lookupError;
  String? _sendError;
  InvitePhoneLookupResult? _lookup;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _phoneController.removeListener(_onChanged);
    _phoneController.dispose();
    super.dispose();
  }

  bool get _canSend =>
      !_sending && _lookup?.status == InvitePhoneLookupStatus.available;

  void _onChanged() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;
    final next = tail.length == 10 ? tail : '';
    if (next == _normalized) {
      // Номер по сути не изменился — только гасим прежнюю ошибку отправки.
      if (_sendError != null) {
        setState(() => _sendError = null);
      }
      return;
    }
    _searchDebounce?.cancel();
    setState(() {
      _normalized = next;
      // Сбрасываем прежний результат, чтобы для нового номера не висел
      // старый «найден / не найден».
      _lookup = null;
      _lookupError = null;
      _sendError = null;
      _searching = next.isNotEmpty;
    });
    if (next.isEmpty) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _runLookup(next),
    );
  }

  Future<void> _runLookup(String normalized) async {
    if (normalized.isEmpty) return;
    setState(() {
      _searching = true;
      _lookupError = null;
      _lookup = null;
    });
    try {
      final result = await widget.onLookup('+7$normalized');
      if (!mounted || _normalized != normalized) return;
      setState(() {
        _lookup = result;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || _normalized != normalized) return;
      setState(() {
        _searching = false;
        _lookupError = sparkJoyReadableErrorText(e);
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final name = await widget.onInvite(_phoneController.text);
      if (!mounted) return;
      Navigator.of(context).pop(name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = sparkJoyReadableErrorText(e);
      });
    }
  }

  void _onFieldSubmitted() {
    if (_canSend) {
      _submit();
    } else if (_normalized.isNotEmpty && _lookup == null && !_searching) {
      _searchDebounce?.cancel();
      _runLookup(_normalized);
    }
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
                              'Введите телефон специалиста — мы найдём его в '
                              'системе по номеру. После принятия приглашения '
                              'он появится в штате компании.',
                          size: SparkTextSize.bodyLg,
                          color: kGreyColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SparkSpace.section),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [RuPhoneFormatter()],
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onFieldSubmitted(),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: sparkInputDecoration(
                  '+7___-___-__-__',
                  labelText: 'Телефон специалиста',
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: kGreyColor,
                  ),
                ),
              ),
              const SizedBox(height: SparkSpace.lg),
              _buildLookupArea(),
              if (_sendError != null) ...[
                const SizedBox(height: SparkSpace.md),
                _errorBox(_sendError!),
              ],
              const SizedBox(height: SparkSpace.section),
              SizedBox(
                height: SparkSize.actionHeight,
                child: FilledButton.icon(
                  onPressed: _canSend ? _submit : null,
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
    );
  }

  Widget _buildLookupArea() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: SparkSpace.sm),
        child: Row(
          children: [
            SizedBox(
              width: SparkSize.spinner,
              height: SparkSize.spinner,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: SparkSpace.md),
            MyText(
              text: 'Ищем специалиста...',
              size: SparkTextSize.body,
              color: kGreyColor,
            ),
          ],
        ),
      );
    }
    if (_lookupError != null) {
      return _errorBox(_lookupError!);
    }
    final lookup = _lookup;
    if (lookup == null) {
      return MyText(
        text: _normalized.isEmpty
            ? 'Введите полный номер телефона — специалист определится '
                  'автоматически.'
            : '',
        size: SparkTextSize.caption,
        color: kGreyColor,
        lineHeight: 1.4,
      );
    }
    switch (lookup.status) {
      case InvitePhoneLookupStatus.notFound:
        return _hintBox(
          'Специалист с этим номером не найден. Возможно, он ещё не '
          'зарегистрирован в системе.',
        );
      case InvitePhoneLookupStatus.alreadyInStaff:
        return _candidateCard(
          lookup.specialist!,
          highlighted: false,
          note: 'Уже в штате компании',
        );
      case InvitePhoneLookupStatus.available:
        return _candidateCard(
          lookup.specialist!,
          highlighted: true,
          note: 'Найден — можно пригласить',
        );
    }
  }

  Widget _candidateCard(
    SpecialistItem spec, {
    required bool highlighted,
    required String note,
  }) {
    final city = (spec.city ?? '').trim();
    final phone = (spec.phone ?? '').trim();
    final accent = highlighted ? kSecondaryColor : kGreyColor;
    return Container(
      padding: const EdgeInsets.all(SparkSpace.lg),
      decoration: BoxDecoration(
        color: highlighted
            ? kSecondaryColor.withValues(alpha: 0.06)
            : kSurfaceTint,
        borderRadius: BorderRadius.circular(SparkRadius.lg),
        border: Border.all(
          color: highlighted
              ? kSecondaryColor.withValues(alpha: 0.35)
              : kBorderColor,
        ),
      ),
      child: Row(
        children: [
          SparkInitialsAvatar(
            name: spec.displayName,
            size: SparkSize.icon4xl,
            imageUrl: spec.urlAvatar,
          ),
          const SizedBox(width: SparkSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MyText(
                  text: spec.displayName,
                  size: SparkTextSize.body,
                  weight: FontWeight.w700,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty)
                  MyText(
                    text: phone,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                if (city.isNotEmpty)
                  MyText(
                    text: city,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                  ),
                const SizedBox(height: SparkSpace.xs),
                Row(
                  children: [
                    Icon(
                      highlighted
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: SparkSize.iconSm,
                      color: accent,
                    ),
                    const SizedBox(width: SparkSpace.xxs),
                    Flexible(
                      child: MyText(
                        text: note,
                        size: SparkTextSize.caption,
                        weight: FontWeight.w600,
                        color: accent,
                        maxLines: 1,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SparkSpace.lg),
      decoration: BoxDecoration(
        color: kSurfaceTint,
        borderRadius: BorderRadius.circular(SparkRadius.md),
      ),
      child: MyText(
        text: text,
        size: SparkTextSize.body,
        color: kGreyColor,
        lineHeight: 1.4,
      ),
    );
  }

  Widget _errorBox(String text) {
    return Container(
      padding: const EdgeInsets.all(SparkSpace.xl),
      decoration: BoxDecoration(
        color: kRedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SparkRadius.md),
        border: Border.all(color: kRedColor.withValues(alpha: 0.22)),
      ),
      child: MyText(text: text, size: SparkTextSize.body, color: kRedColor),
    );
  }
}

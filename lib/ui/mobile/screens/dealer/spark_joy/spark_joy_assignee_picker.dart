import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_data.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Assignee-picker mode. Stored as enum to keep call sites type-safe.
enum SparkJoyAssigneeMode { staff, phone, invite }

/// The picker's current selection — the parent reads this on "Создать
/// отчёт" tap to decide what to pass into the report screen.
///
/// At most one of [specialistId] / [inviteLink] is non-empty in a
/// finalized selection. `staff` and `phone` modes both resolve to a
/// specialist id (the latter after the phone lookup succeeds and the
/// user taps "Назначить").
class SparkJoyAssigneeSelection {
  const SparkJoyAssigneeSelection({
    this.mode = SparkJoyAssigneeMode.staff,
    this.specialistId = '',
    this.specialistName = '',
    this.inviteLink = '',
  });

  final SparkJoyAssigneeMode mode;
  final String specialistId;
  final String specialistName;
  final String inviteLink;

  bool get isEmpty => specialistId.isEmpty && inviteLink.isEmpty;
}

/// 3-mode assignee picker for the company flow:
///   • staff  — dropdown of existing company specialists
///   • phone  — RU-phone lookup against the user directory
///   • invite — generate a shareable invite link
///
/// Owns all internal state (segmented-button mode, phone-lookup state,
/// invite-link building) and emits a [SparkJoyAssigneeSelection] via
/// [onChanged] whenever anything changes.
class SparkJoyAssigneePicker extends StatefulWidget {
  const SparkJoyAssigneePicker({
    super.key,
    required this.companyId,
    required this.onChanged,
    this.initialSelection = const SparkJoyAssigneeSelection(),
  });

  /// Company used for both the staff roster and the invite-link token.
  final String companyId;

  /// Initial value when reopening a partially-filled form. Rare — the
  /// picker usually starts empty on the "new report" screen.
  final SparkJoyAssigneeSelection initialSelection;

  /// Fires on every meaningful change (mode switch, staff pick, phone
  /// resolved, invite generated). Parent should cache the last value.
  final ValueChanged<SparkJoyAssigneeSelection> onChanged;

  @override
  State<SparkJoyAssigneePicker> createState() =>
      _SparkJoyAssigneePickerState();
}

// Phone-lookup UI states. Kept as a private enum to avoid stringly-
// typed state here; the outer world only sees [SparkJoyAssigneeMode].
enum _PhoneLookupState {
  idle,
  searching,
  found,
  notFound,
  blockedOwnStaff,
  blockedOtherCompany,
}

class _SparkJoyAssigneePickerState extends State<SparkJoyAssigneePicker> {
  late SparkJoyAssigneeMode _mode;
  late String _specialistId;
  late String _specialistName;
  late String _inviteLink;

  // Phone-tab local state.
  final _phoneController = TextEditingController();
  Timer? _phoneDebounce;
  String _normalizedPhone = '';
  _PhoneLookupState _phoneState = _PhoneLookupState.idle;
  String _phoneFoundId = '';
  String _phoneFoundName = '';
  String _phoneFoundCity = '';

  bool _inviteBuilding = false;

  List<Map<String, dynamic>> get _staff {
    return sparkSpecialists
        .where((s) {
          final companyId = sjRead(s, 'companyId');
          final status = sjRead(s, 'status');
          return companyId == widget.companyId && status != 'blocked';
        })
        .map(cloneMap)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialSelection.mode;
    _specialistId = widget.initialSelection.specialistId;
    _specialistName = widget.initialSelection.specialistName;
    _inviteLink = widget.initialSelection.inviteLink;
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  SparkJoyAssigneeSelection get _currentSelection => SparkJoyAssigneeSelection(
        mode: _mode,
        specialistId: _specialistId,
        specialistName: _specialistName,
        inviteLink: _inviteLink,
      );

  void _emit() => widget.onChanged(_currentSelection);

  /// Wraps mode change + emit so every path that switches tabs stays
  /// consistent (inner hint-card CTAs, segmented-button toggle).
  void _setMode(SparkJoyAssigneeMode next) {
    if (_mode == next) return;
    setState(() => _mode = next);
    _emit();
  }

  // ── Phone helpers ──────────────────────────────────────────────────

  String _digits(String raw) {
    final all = raw.replaceAll(RegExp(r'\D'), '');
    if (all.isEmpty) return '';
    var tail = all;
    if (tail.length > 10 && (tail.startsWith('7') || tail.startsWith('8'))) {
      tail = tail.substring(tail.length - 10);
    }
    if (tail.length > 10) tail = tail.substring(tail.length - 10);
    return tail;
  }

  String _formatPhone(String raw) {
    final tail = _digits(raw);
    if (tail.isEmpty) return '';
    final buf = StringBuffer('+7');
    buf.write(' (');
    buf.write(tail.substring(0, tail.length.clamp(0, 3)));
    if (tail.length >= 3) buf.write(')');
    if (tail.length > 3) {
      buf.write(' ');
      buf.write(tail.substring(3, tail.length.clamp(3, 6)));
    }
    if (tail.length > 6) {
      buf.write('-');
      buf.write(tail.substring(6, tail.length.clamp(6, 8)));
    }
    if (tail.length > 8) {
      buf.write('-');
      buf.write(tail.substring(8, tail.length.clamp(8, 10)));
    }
    return buf.toString();
  }

  String _normalize(String raw) {
    final tail = _digits(raw);
    return tail.length == 10 ? '+7$tail' : '';
  }

  /// Mock lookup — resolves against the in-memory `sparkSpecialists`
  /// demo data. Rules:
  ///   • own-staff match   → blockedOwnStaff
  ///   • other-company match → blockedOtherCompany
  ///   • free-agent match  → found
  ///   • no match          → notFound
  _MockLookupResult _mockLookup(String normalizedPhone) {
    String d(String v) => v.replaceAll(RegExp(r'\D'), '');
    final needle = d(normalizedPhone);
    if (needle.length < 10) return const _MockLookupResult(_PhoneLookupState.notFound);
    final needleTail = needle.substring(needle.length - 10);

    for (final s in sparkSpecialists) {
      final raw = sjRead(s, 'phone');
      final tail = d(raw);
      if (tail.isEmpty) continue;
      final last = tail.length >= 10 ? tail.substring(tail.length - 10) : tail;
      if (last != needleTail) continue;

      final specCompany = sjRead(s, 'companyId');
      final id = sjRead(s, 'id');
      final name = sjRead(s, 'name');
      final city = sjRead(s, 'city');
      if (specCompany == widget.companyId) {
        return _MockLookupResult(_PhoneLookupState.blockedOwnStaff,
            id: id, name: name, city: city);
      }
      if (specCompany.isNotEmpty) {
        return _MockLookupResult(_PhoneLookupState.blockedOtherCompany,
            id: id, name: name, city: city);
      }
      return _MockLookupResult(_PhoneLookupState.found,
          id: id, name: name, city: city);
    }
    return const _MockLookupResult(_PhoneLookupState.notFound);
  }

  void _schedulePhoneLookup(String rawInput) {
    _phoneDebounce?.cancel();
    final normalized = _normalize(rawInput);

    if (normalized.isEmpty) {
      if (_normalizedPhone.isEmpty && _phoneState == _PhoneLookupState.idle) return;
      setState(() {
        _normalizedPhone = '';
        _phoneState = _PhoneLookupState.idle;
        _phoneFoundId = '';
        _phoneFoundName = '';
        _phoneFoundCity = '';
      });
      return;
    }

    final sameNumberResolved = _normalizedPhone == normalized &&
        _phoneState != _PhoneLookupState.idle &&
        _phoneState != _PhoneLookupState.searching;
    if (sameNumberResolved) return;

    setState(() {
      _normalizedPhone = normalized;
      _phoneState = _PhoneLookupState.searching;
      _phoneFoundId = '';
      _phoneFoundName = '';
      _phoneFoundCity = '';
    });
    _phoneDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _runPhoneLookup(normalized),
    );
  }

  Future<void> _runPhoneLookup(String normalized) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || _normalizedPhone != normalized) return;
    final result = _mockLookup(normalized);
    setState(() {
      _phoneState = result.state;
      _phoneFoundId = result.id;
      _phoneFoundName = result.name;
      _phoneFoundCity = result.city;
    });
  }

  void _confirmPhoneAssignee() {
    if (_phoneState != _PhoneLookupState.found) return;
    if (_phoneFoundId.isEmpty) return;
    setState(() {
      _specialistId = _phoneFoundId;
      _specialistName = _phoneFoundName;
      // Clearing the invite link: a report can only have one kind of
      // assignee at a time.
      _inviteLink = '';
    });
    _emit();
    // TODO(spark-joy): replace with FCM/SMS dispatch when backend lands.
    debugPrint(
      '[spark_joy] assign-notification → user=$_specialistId ($_specialistName) reason=phone',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _specialistName.isEmpty
              ? 'Исполнитель назначен, ему отправлено уведомление'
              : '$_specialistName назначен, ему отправлено уведомление',
        ),
      ),
    );
  }

  // ── Invite-link helpers ────────────────────────────────────────────

  String _buildInviteToken() {
    final source =
        '${DateTime.now().microsecondsSinceEpoch}|${widget.companyId}';
    final encoded = base64Url.encode(utf8.encode(source)).replaceAll('=', '');
    return encoded.length <= 18 ? encoded : encoded.substring(0, 18);
  }

  Future<void> _generateInviteLink() async {
    if (_inviteBuilding) return;
    setState(() => _inviteBuilding = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final link = Uri.https('app.autocheck.local', '/invite/staff', {
      'companyId': widget.companyId,
      'token': _buildInviteToken(),
      'source': 'new_report',
    }).toString();
    if (!mounted) return;
    setState(() {
      _inviteLink = link;
      _specialistId = '';
      _specialistName = '';
      _inviteBuilding = false;
    });
    _emit();
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка приглашения скопирована')),
    );
  }

  Future<void> _copyInviteLink() async {
    if (_inviteLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }

  Future<void> _shareInviteLink() async {
    if (_inviteLink.isEmpty) return;
    if (!mounted) return;
    final link = _inviteLink;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        Future<void> launchTarget(String urlStr) async {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(sheetCtx).pop();
          var ok = false;
          try {
            ok = await launchUrl(
              Uri.parse(urlStr),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {
            ok = false;
          }
          if (!ok) {
            await Clipboard.setData(ClipboardData(text: link));
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Не удалось открыть мессенджер, ссылка скопирована',
                ),
              ),
            );
          }
        }

        final encoded = Uri.encodeComponent(link);
        final text = 'Приглашение присоединиться к штату компании: $link';
        final encodedText = Uri.encodeComponent(text);
        final mailtoSubject = Uri.encodeComponent('Приглашение в штат');

        final targets =
            <({IconData icon, Color? color, String label, String url})>[
          (
            icon: Icons.send_rounded,
            color: const Color(0xFF0088CC),
            label: 'Telegram',
            url: 'https://t.me/share/url?url=$encoded&text=$encodedText',
          ),
          (
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            label: 'WhatsApp',
            url: 'https://wa.me/?text=$encodedText',
          ),
          (
            icon: Icons.sms_outlined,
            color: null,
            label: 'SMS',
            url: 'sms:?body=$encodedText',
          ),
          (
            icon: Icons.email_outlined,
            color: null,
            label: 'Почта',
            url: 'mailto:?subject=$mailtoSubject&body=$encodedText',
          ),
        ];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: SparkSpace.sm),
                child: MyText(
                  text: 'Поделиться ссылкой',
                  size: SparkTextSize.body,
                  weight: FontWeight.w700,
                ),
              ),
              for (final t in targets)
                ListTile(
                  leading: Icon(t.icon, color: t.color),
                  title: Text(t.label),
                  onTap: () => launchTarget(t.url),
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Скопировать ссылку'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _copyInviteLink();
                },
              ),
              const SizedBox(height: SparkSpace.sm),
            ],
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeSelector(mode: _mode, onChanged: _setMode),
        if (!_currentSelection.isEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          _CurrentSelectionBanner(selection: _currentSelection),
        ],
        const SizedBox(height: SparkSpace.lg),
        switch (_mode) {
          SparkJoyAssigneeMode.staff => _buildStaffTab(),
          SparkJoyAssigneeMode.phone => _buildPhoneTab(),
          SparkJoyAssigneeMode.invite => _buildInviteTab(),
        },
      ],
    );
  }

  Widget _buildStaffTab() {
    final staff = _staff;
    final hasStaff = staff.isNotEmpty;
    final selectedInList =
        staff.any((s) => sjRead(s, 'id') == _specialistId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          // Key encodes the current selection so external changes
          // (e.g. user confirmed assignee on phone tab, then returned
          // here) force the FormField to rebuild with the new value —
          // `initialValue` alone is ignored after the first build.
          key: ValueKey('assignee-staff-dd-${selectedInList ? _specialistId : ''}'),
          initialValue: selectedInList ? _specialistId : '',
          decoration: sparkInputDecoration('Выберите сотрудника'),
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(
              value: '',
              child: Text('Без исполнителя'),
            ),
            ...staff.map((s) => DropdownMenuItem<String>(
                  value: sjRead(s, 'id'),
                  child: Text(sjRead(s, 'name')),
                )),
          ],
          onChanged: hasStaff
              ? (value) {
                  final id = value ?? '';
                  final match = staff.firstWhere(
                    (s) => sjRead(s, 'id') == id,
                    orElse: () => const {},
                  );
                  setState(() {
                    _specialistId = id;
                    _specialistName = sjRead(match, 'name');
                    _inviteLink = '';
                  });
                  _emit();
                }
              : null,
        ),
        const SizedBox(height: SparkSpace.md),
        MyText(
          text: !hasStaff
              ? 'Нет сотрудников в штате. Пригласите через вкладку «Пригласить».'
              : _specialistId.isEmpty
                  ? 'Исполнитель пока не назначен.'
                  : 'Назначен: ${_specialistName.isEmpty ? _specialistId : _specialistName}',
          size: SparkTextSize.caption,
          color: kGreyColor,
        ),
      ],
    );
  }

  Widget _buildPhoneTab() {
    final assigned = _specialistId.isNotEmpty &&
        _specialistId == _phoneFoundId &&
        _phoneState == _PhoneLookupState.found;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: sparkInputDecoration('+7 (___) ___-__-__'),
          inputFormatters: [_ParenPhoneFormatter(_formatPhone)],
          onChanged: _schedulePhoneLookup,
        ),
        const SizedBox(height: SparkSpace.md),
        _buildPhoneStateView(assigned),
      ],
    );
  }

  Widget _buildPhoneStateView(bool assigned) {
    switch (_phoneState) {
      case _PhoneLookupState.searching:
        return Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: SparkSpace.sm),
            MyText(
              text: 'Ищем пользователя...',
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ],
        );
      case _PhoneLookupState.found:
        return _FoundCard(
          name: _phoneFoundName,
          city: _phoneFoundCity,
          assigned: assigned,
          onAssign: _confirmPhoneAssignee,
        );
      case _PhoneLookupState.notFound:
        return _HintCard(
          iconColor: kYellowColor,
          icon: Icons.info_outline,
          title: 'Пользователь не найден',
          description:
              'Пригласите его в приложение — переключитесь на вкладку «Пригласить».',
          actionLabel: 'Пригласить по ссылке',
          onAction: () => _setMode(SparkJoyAssigneeMode.invite),
        );
      case _PhoneLookupState.blockedOwnStaff:
        return _HintCard(
          iconColor: kYellowColor,
          icon: Icons.group_outlined,
          title: 'Пользователь уже в вашем штате',
          description:
              'Выберите его во вкладке «Из штата» — избежим двойных назначений.',
          actionLabel: 'Открыть «Из штата»',
          onAction: () => _setMode(SparkJoyAssigneeMode.staff),
        );
      case _PhoneLookupState.blockedOtherCompany:
        return const _HintCard(
          iconColor: kRedColor,
          icon: Icons.block_outlined,
          title: 'Пользователь состоит в штате другой компании',
          description:
              'Назначить его нельзя. Попросите его выйти из штата или выберите другого исполнителя.',
        );
      case _PhoneLookupState.idle:
        return const MyText(
          text:
              'Введите номер существующего пользователя приложения — назначим его исполнителем и отправим push-уведомление.',
          size: SparkTextSize.caption,
          color: kGreyColor,
        );
    }
  }

  Widget _buildInviteTab() {
    final hasLink = _inviteLink.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _inviteBuilding ? null : _generateInviteLink,
                icon: Icon(
                  hasLink ? Icons.refresh_rounded : Icons.link_rounded,
                ),
                label: Text(
                  _inviteBuilding
                      ? 'Формируем...'
                      : hasLink
                          ? 'Обновить ссылку'
                          : 'Сформировать ссылку',
                ),
              ),
            ),
          ],
        ),
        if (hasLink) ...[
          const SizedBox(height: SparkSpace.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.lg,
              vertical: SparkSpace.md,
            ),
            decoration: BoxDecoration(
              color: kInputBgColor,
              border: Border.all(color: kBorderColor),
              borderRadius: BorderRadius.circular(SparkRadius.md),
            ),
            child: MyText(
              text: _inviteLink,
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ),
          const SizedBox(height: SparkSpace.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyInviteLink,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Копировать'),
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareInviteLink,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Поделиться'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: SparkSpace.md),
        const MyText(
          text:
              'После перехода по ссылке пользователь установит приложение и получит push-приглашение вступить в штат.',
          size: SparkTextSize.caption,
          color: kGreyColor,
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});
  final SparkJoyAssigneeMode mode;
  final ValueChanged<SparkJoyAssigneeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<SparkJoyAssigneeMode>(
        segments: const [
          ButtonSegment<SparkJoyAssigneeMode>(
            value: SparkJoyAssigneeMode.staff,
            label: Text('Из штата'),
            icon: Icon(Icons.groups_2_outlined),
          ),
          ButtonSegment<SparkJoyAssigneeMode>(
            value: SparkJoyAssigneeMode.phone,
            label: Text('По телефону'),
            icon: Icon(Icons.phone_outlined),
          ),
          ButtonSegment<SparkJoyAssigneeMode>(
            value: SparkJoyAssigneeMode.invite,
            label: Text('Пригласить'),
            icon: Icon(Icons.link_rounded),
          ),
        ],
        selected: <SparkJoyAssigneeMode>{mode},
        showSelectedIcon: false,
        onSelectionChanged: (sel) {
          if (sel.isEmpty) return;
          onChanged(sel.first);
        },
      ),
    );
  }
}

/// Persistent indicator of the current selection, shown above the
/// tabs. Prevents the "I picked A via staff, switched to phone, and
/// now it looks like nobody is selected" class of UX bugs: the user
/// sees their choice regardless of which tab is active.
class _CurrentSelectionBanner extends StatelessWidget {
  const _CurrentSelectionBanner({required this.selection});
  final SparkJoyAssigneeSelection selection;

  @override
  Widget build(BuildContext context) {
    final hasSpecialist = selection.specialistId.isNotEmpty;
    final icon = hasSpecialist ? Icons.check_circle_outline : Icons.link_rounded;
    final label = hasSpecialist
        ? 'Назначен: ${selection.specialistName.isEmpty ? selection.specialistId : selection.specialistName}'
        : 'Ссылка-приглашение сформирована';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.sm,
      ),
      decoration: BoxDecoration(
        color: kChipCompletedBg,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: SparkSize.iconSm, color: kChipCompletedFg),
          const SizedBox(width: SparkSpace.sm),
          Expanded(
            child: MyText(
              text: label,
              size: SparkTextSize.caption,
              color: kChipCompletedFg,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({
    required this.name,
    required this.city,
    required this.assigned,
    required this.onAssign,
  });

  final String name;
  final String city;
  final bool assigned;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SparkSpace.md),
      decoration: BoxDecoration(
        color: kInputBgColor,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(SparkRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_pin_circle_outlined,
                color: kSecondaryColor,
              ),
              const SizedBox(width: SparkSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: name.isEmpty ? 'Пользователь найден' : name,
                      size: SparkTextSize.body,
                      weight: FontWeight.w600,
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: SparkSpace.xxs),
                      MyText(
                        text: city,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: assigned ? null : onAssign,
              icon: Icon(
                assigned ? Icons.check_circle_outline : Icons.person_add_alt_1,
              ),
              label: Text(assigned ? 'Назначен' : 'Назначить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final Color iconColor;
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SparkSpace.md),
      decoration: BoxDecoration(
        color: kInputBgColor,
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(SparkRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: SparkSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: title,
                      size: SparkTextSize.body,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: description,
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SparkSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParenPhoneFormatter extends TextInputFormatter {
  const _ParenPhoneFormatter(this._format);
  final String Function(String raw) _format;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _MockLookupResult {
  const _MockLookupResult(this.state, {this.id = '', this.name = '', this.city = ''});
  final _PhoneLookupState state;
  final String id;
  final String name;
  final String city;
}

// ══════════════════════════════════════════════════════════════════════
// Compact trigger row + modal sheet host.
//
// `SparkJoyAssigneeField` is the one-line summary that lives on the
// form; tapping it opens a modal bottom sheet with the full
// `SparkJoyAssigneePicker` inside. Keeps the main form uncluttered —
// see the design note attached to the "Option A" decision.
// ══════════════════════════════════════════════════════════════════════

/// Opens a full-height modal bottom sheet hosting the 3-mode picker.
/// Resolves with the final selection when the user taps "Готово";
/// resolves with `null` if they close the sheet without confirming.
Future<SparkJoyAssigneeSelection?> showSparkJoyAssigneePickerSheet(
  BuildContext context, {
  required String companyId,
  SparkJoyAssigneeSelection initialSelection =
      const SparkJoyAssigneeSelection(),
}) {
  return showModalBottomSheet<SparkJoyAssigneeSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AssigneePickerSheet(
      companyId: companyId,
      initialSelection: initialSelection,
    ),
  );
}

class _AssigneePickerSheet extends StatefulWidget {
  const _AssigneePickerSheet({
    required this.companyId,
    required this.initialSelection,
  });
  final String companyId;
  final SparkJoyAssigneeSelection initialSelection;

  @override
  State<_AssigneePickerSheet> createState() => _AssigneePickerSheetState();
}

class _AssigneePickerSheetState extends State<_AssigneePickerSheet> {
  late SparkJoyAssigneeSelection _draft = widget.initialSelection;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    // 0.85 leaves room for the drag handle + backdrop peek; scrollable
    // so the phone keyboard doesn't squash the invite-link field.
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xl),
              child: Row(
                children: [
                  const Expanded(
                    child: MyText(
                      text: 'Назначить исполнителя',
                      size: SparkTextSize.title,
                      weight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SparkSpace.xl),
                child: SparkJoyAssigneePicker(
                  companyId: widget.companyId,
                  initialSelection: widget.initialSelection,
                  onChanged: (sel) => _draft = sel,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(SparkSpace.xl),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('Готово'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact trigger row rendered on the form. Shows empty-state or a
/// one-line summary of the current [selection]; tapping opens the
/// picker sheet and calls [onChanged] with the confirmed result.
///
/// A "Готово" in the sheet resolves with the new value; closing
/// without confirming is a no-op (onChanged not fired). There's also
/// an inline "Очистить" action when something is selected so users
/// can reset without reopening the sheet.
class SparkJoyAssigneeField extends StatelessWidget {
  const SparkJoyAssigneeField({
    super.key,
    required this.companyId,
    required this.selection,
    required this.onChanged,
  });

  final String companyId;
  final SparkJoyAssigneeSelection selection;
  final ValueChanged<SparkJoyAssigneeSelection> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await showSparkJoyAssigneePickerSheet(
      context,
      companyId: companyId,
      initialSelection: selection,
    );
    if (result != null) onChanged(result);
  }

  (IconData, String, String?) _rowContent() {
    if (selection.isEmpty) {
      return (Icons.person_add_alt_outlined, 'Выбрать исполнителя', null);
    }
    if (selection.specialistId.isNotEmpty) {
      final name = selection.specialistName.isEmpty
          ? selection.specialistId
          : selection.specialistName;
      final chip = switch (selection.mode) {
        SparkJoyAssigneeMode.phone => 'по телефону',
        _ => 'из штата',
      };
      return (Icons.person_rounded, name, chip);
    }
    return (Icons.link_rounded, 'Приглашение по ссылке', 'ссылка');
  }

  @override
  Widget build(BuildContext context) {
    final (icon, label, chip) = _rowContent();
    final empty = selection.isEmpty;

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(SparkRadius.lg),
      child: Container(
        constraints: const BoxConstraints(minHeight: SparkSize.inputHeightLg),
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpace.xl,
          vertical: SparkSpace.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(SparkRadius.lg),
          color: kInputBgColor,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: empty ? kLightGreyColor : kChipCompletedBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: SparkSize.iconMd,
                color: empty ? kGreyColor : kChipCompletedFg,
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyText(
                    text: label,
                    size: SparkTextSize.body,
                    weight: empty ? FontWeight.w400 : FontWeight.w600,
                    color: empty ? kGreyColor : kTertiaryColor,
                    maxLines: 1,
                  ),
                  if (chip != null) ...[
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: chip,
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                ],
              ),
            ),
            if (!empty)
              IconButton(
                tooltip: 'Очистить',
                icon: const Icon(
                  Icons.close_rounded,
                  size: SparkSize.iconMd,
                  color: kGreyColor,
                ),
                onPressed: () =>
                    onChanged(const SparkJoyAssigneeSelection()),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: kGreyColor,
            ),
          ],
        ),
      ),
    );
  }
}

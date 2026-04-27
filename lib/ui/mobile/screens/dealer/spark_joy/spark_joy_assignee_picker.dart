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
///   • staff  — always-visible roster of company specialists; tap a
///              row to assign, tap the selected row again to clear
///   • phone  — collapsible card with RU-phone lookup against the
///              user directory
///   • invite — collapsible card that generates a shareable invite
///              link
///
/// Phone and invite live in a single-open accordion below the staff
/// list (`_AltSection`); only one is expanded at a time. The picker
/// emits a [SparkJoyAssigneeSelection] via [onChanged] whenever the
/// selected assignee changes.
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

  /// Fires whenever the resolved assignee changes (staff pick, phone
  /// confirmed, invite generated, selection cleared). Expanding or
  /// collapsing alt sections does **not** emit. Parent should cache
  /// the last value.
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

// Which secondary action is currently expanded. Only one at a time —
// the staff list is always visible above and not part of this enum.
enum _AltSection { none, phone, invite }

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

  _AltSection _altSection = _AltSection.none;

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

  /// Toggle one of the alternative-action sections (phone / invite).
  /// Only one is open at a time; tapping the open one collapses it.
  void _toggleAltSection(_AltSection next) {
    setState(() {
      _altSection = _altSection == next ? _AltSection.none : next;
    });
  }

  /// Wipes the phone-lookup local state. Caller is responsible for
  /// the surrounding setState — this just centralises the field list
  /// so `_clearAll` and `_toggleStaff` stay in sync.
  void _resetPhoneState() {
    _phoneController.clear();
    _normalizedPhone = '';
    _phoneState = _PhoneLookupState.idle;
    _phoneFoundId = '';
    _phoneFoundName = '';
    _phoneFoundCity = '';
  }

  /// Resets the entire selection — used by the "Очистить" action on
  /// the selection banner and by tap-to-deselect on a staff row.
  void _clearAll() {
    setState(() {
      _mode = SparkJoyAssigneeMode.staff;
      _specialistId = '';
      _specialistName = '';
      _inviteLink = '';
      _resetPhoneState();
    });
    _emit();
  }

  /// Tap a staff row. Tapping the currently selected row clears the
  /// selection (lets the user "undo" without hunting for a separate
  /// reset control). Tapping a different row replaces it and collapses
  /// any open alternative section.
  void _toggleStaff(String id, String name) {
    if (id.isEmpty) return;
    HapticFeedback.selectionClick();
    if (_specialistId == id && _mode == SparkJoyAssigneeMode.staff) {
      _clearAll();
      return;
    }
    setState(() {
      _mode = SparkJoyAssigneeMode.staff;
      _specialistId = id;
      _specialistName = name;
      _inviteLink = '';
      _altSection = _AltSection.none;
      _resetPhoneState();
    });
    _emit();
  }

  // ── Phone helpers ──────────────────────────────────────────────────

  // The phone field's controller holds the user's 10 digits only —
  // the "+7 " prefix lives in the InputDecoration as a static prefix,
  // so the formatter never has to round-trip it through digit
  // extraction.

  String _formatGrouped(String digits) {
    if (digits.isEmpty) return '';
    final buf = StringBuffer('(');
    buf.write(digits.substring(0, digits.length.clamp(0, 3)));
    if (digits.length >= 3) buf.write(')');
    if (digits.length > 3) {
      buf.write(' ');
      buf.write(digits.substring(3, digits.length.clamp(3, 6)));
    }
    if (digits.length > 6) {
      buf.write('-');
      buf.write(digits.substring(6, digits.length.clamp(6, 8)));
    }
    if (digits.length > 8) {
      buf.write('-');
      buf.write(digits.substring(8, digits.length.clamp(8, 10)));
    }
    return buf.toString();
  }

  String _normalize(String controllerText) {
    final digits = controllerText.replaceAll(RegExp(r'\D'), '');
    final tail = digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;
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
      _mode = SparkJoyAssigneeMode.phone;
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
      _mode = SparkJoyAssigneeMode.invite;
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
    final selection = _currentSelection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!selection.isEmpty) ...[
          _CurrentSelectionBanner(
            selection: selection,
            onClear: _clearAll,
          ),
          const SizedBox(height: SparkSpace.lg),
        ],
        _buildStaffSection(),
        const SizedBox(height: SparkSpace.section),
        _buildAltSection(),
      ],
    );
  }

  Widget _buildStaffSection() {
    final staff = _staff;
    final hasStaff = staff.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: SparkSpace.xs,
            bottom: SparkSpace.sm,
          ),
          child: MyText(
            text: hasStaff
                ? 'Сотрудники штата · ${staff.length}'
                : 'Сотрудники штата',
            size: SparkTextSize.caption,
            color: kGreyColor,
            weight: FontWeight.w600,
          ),
        ),
        if (!hasStaff)
          _EmptyStaffCard(
            onInvite: () => _toggleAltSection(_AltSection.invite),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: kInputBgColor,
              border: Border.all(color: kBorderColor),
              borderRadius: BorderRadius.circular(SparkRadius.md),
            ),
            child: Column(
              children: [
                for (var i = 0; i < staff.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: SparkSpace.xxxl),
                  _StaffRow(
                    id: sjRead(staff[i], 'id'),
                    name: sjRead(staff[i], 'name'),
                    selected: _mode == SparkJoyAssigneeMode.staff &&
                        _specialistId == sjRead(staff[i], 'id'),
                    onTap: () => _toggleStaff(
                      sjRead(staff[i], 'id'),
                      sjRead(staff[i], 'name'),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAltSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: SparkSpace.xs,
            bottom: SparkSpace.sm,
          ),
          child: const MyText(
            text: 'Другие способы',
            size: SparkTextSize.caption,
            color: kGreyColor,
            weight: FontWeight.w600,
          ),
        ),
        _AltCard(
          icon: Icons.phone_outlined,
          title: 'Найти по номеру телефона',
          subtitle: 'Если уже зарегистрирован в приложении',
          expanded: _altSection == _AltSection.phone,
          onToggle: () => _toggleAltSection(_AltSection.phone),
          child: _buildPhoneBody(),
        ),
        const SizedBox(height: SparkSpace.md),
        _AltCard(
          icon: Icons.link_rounded,
          title: 'Пригласить по ссылке',
          subtitle: 'Если ещё нет в приложении',
          expanded: _altSection == _AltSection.invite,
          onToggle: () => _toggleAltSection(_AltSection.invite),
          child: _buildInviteBody(),
        ),
      ],
    );
  }

  Widget _buildPhoneBody() {
    final assigned = _specialistId.isNotEmpty &&
        _specialistId == _phoneFoundId &&
        _phoneState == _PhoneLookupState.found;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: sparkInputDecoration('(___) ___-__-__').copyWith(
            prefixText: '+7 ',
          ),
          inputFormatters: [_GroupedPhoneFormatter(_formatGrouped)],
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
              'Пригласите его в приложение — отправьте ссылку-приглашение.',
          actionLabel: 'Пригласить по ссылке',
          onAction: () => _toggleAltSection(_AltSection.invite),
        );
      case _PhoneLookupState.blockedOwnStaff:
        return const _HintCard(
          iconColor: kYellowColor,
          icon: Icons.group_outlined,
          title: 'Пользователь уже в вашем штате',
          description:
              'Выберите его в списке сотрудников выше — избежим двойных назначений.',
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

  Widget _buildInviteBody() {
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

/// Persistent indicator of the current selection, shown at the top of
/// the picker. Carries an inline "Очистить" action so the user can
/// drop the current assignee from anywhere — without hunting for the
/// previously-clicked staff row or reopening the picker.
class _CurrentSelectionBanner extends StatelessWidget {
  const _CurrentSelectionBanner({
    required this.selection,
    required this.onClear,
  });
  final SparkJoyAssigneeSelection selection;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasSpecialist = selection.specialistId.isNotEmpty;
    final icon = hasSpecialist ? Icons.check_circle_outline : Icons.link_rounded;
    final label = hasSpecialist
        ? 'Назначен: ${selection.specialistName.isEmpty ? selection.specialistId : selection.specialistName}'
        : 'Ссылка-приглашение сформирована';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.md,
        SparkSpace.sm,
        SparkSpace.xs,
        SparkSpace.sm,
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
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 0),
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.xs,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: kChipCompletedFg,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}

/// One staff member as a tappable row inside the staff list. Selected
/// row highlights and shows a check icon — tapping it again clears
/// the selection (handled by the parent `_toggleStaff`).
class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.id,
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String id;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = name.isEmpty ? id : name;
    // Material+InkWell rather than Container(color:)+InkWell so the
    // ripple paints on top of the selected-row highlight; with a raw
    // Container the background swallows the ink reaction.
    return Material(
      color: selected ? kChipCompletedBg : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.xl,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: SparkSize.iconLg,
                  color: selected ? kChipCompletedFg : kGreyColor,
                ),
                const SizedBox(width: SparkSpace.md),
                Expanded(
                  child: MyText(
                    text: label,
                    size: SparkTextSize.body,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? kChipCompletedFg : kTertiaryColor,
                    maxLines: 1,
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

/// Empty-state card shown when the company has no staff yet. Nudges
/// the user toward the invite section so they're not stuck.
class _EmptyStaffCard extends StatelessWidget {
  const _EmptyStaffCard({required this.onInvite});
  final VoidCallback onInvite;

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
          const MyText(
            text: 'В штате пока никого нет',
            size: SparkTextSize.body,
            weight: FontWeight.w600,
          ),
          const SizedBox(height: SparkSpace.xxs),
          const MyText(
            text:
                'Пригласите специалиста — он получит ссылку и сможет принять отчёт.',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
          const SizedBox(height: SparkSpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Пригласить по ссылке'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible card for an alternative-action section (phone lookup
/// or invite link). Header is always visible; body is animated on
/// expand. Behaves like a single-open accordion — the parent picker
/// owns which card is open via `_altSection`.
class _AltCard extends StatelessWidget {
  const _AltCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: kInputBgColor,
        border: Border.all(
          color: expanded ? kSecondaryColor : kBorderColor,
          width: expanded ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(SparkRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(SparkRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(SparkSpace.md),
              child: Row(
                children: [
                  Icon(icon, color: kSecondaryColor, size: SparkSize.iconLg),
                  const SizedBox(width: SparkSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MyText(
                          text: title,
                          size: SparkTextSize.body,
                          weight: FontWeight.w600,
                        ),
                        const SizedBox(height: SparkSpace.xxs),
                        MyText(
                          text: subtitle,
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: kGreyColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SparkSpace.md,
                      0,
                      SparkSpace.md,
                      SparkSpace.md,
                    ),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
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

/// Formats the controller's digits as "(XXX) XXX-XX-XX". The "+7 "
/// country prefix is rendered separately as the field's `prefixText`,
/// so the controller text only ever holds the user's 10 digits — this
/// avoids the prefix's "7" leaking back into digit extraction on
/// re-format.
///
/// Backspace heuristic: when the new text is shorter than the old but
/// the digit count didn't change, the user deleted only a delimiter
/// (paren / space / dash). Without intervention the next reformat
/// would re-insert that delimiter and the field would feel "stuck".
/// In that case we drop the trailing digit instead, so backspace
/// always shrinks the input.
class _GroupedPhoneFormatter extends TextInputFormatter {
  const _GroupedPhoneFormatter(this._format);
  final String Function(String digits) _format;

  static String _onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = _onlyDigits(oldValue.text);
    var newDigits = _onlyDigits(newValue.text);

    final shrunk = newValue.text.length < oldValue.text.length;
    if (shrunk && newDigits == oldDigits && newDigits.isNotEmpty) {
      newDigits = newDigits.substring(0, newDigits.length - 1);
    }
    if (newDigits.length > 10) {
      newDigits = newDigits.substring(newDigits.length - 10);
    }

    final formatted = _format(newDigits);
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

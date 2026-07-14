import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_invite_by_phone_dialog.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';

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
  State<SparkJoyAssigneePicker> createState() => _SparkJoyAssigneePickerState();
}

// Phone-lookup UI states. Kept as a private enum to avoid stringly-
// typed state here; the outer world only sees [SparkJoyAssigneeMode].
enum _PhoneLookupState {
  idle,
  searching,
  found,
  notFound,
  notCompanyStaff,
  error,
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
  String _phoneError = '';

  bool _staffLoading = true;
  String? _staffError;
  List<SpecialistItem> _staff = const <SpecialistItem>[];

  _AltSection _altSection = _AltSection.none;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialSelection.mode;
    _specialistId = widget.initialSelection.specialistId;
    _specialistName = widget.initialSelection.specialistName;
    _inviteLink = widget.initialSelection.inviteLink;
    _loadStaff();
  }

  @override
  void dispose() {
    _phoneDebounce?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _staffLoading = true;
      _staffError = null;
    });
    try {
      var pageNumber = 1;
      var totalPages = 1;
      final staff = <SpecialistItem>[];
      do {
        final page = await storage_api.StorageApi.getCompanySpecialistsPage(
          page: pageNumber,
          limit: 100,
        );
        staff.addAll(page.specialists);
        totalPages = page.pages <= 0 ? 1 : page.pages;
        pageNumber += 1;
      } while (pageNumber <= totalPages);
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _staffLoading = false;
      });
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() {
        _staffLoading = false;
        _staffError = 'Сессия истекла. Войдите заново.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staffLoading = false;
        _staffError = 'Не удалось загрузить штат: $e';
      });
    }
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
    _phoneError = '';
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

  void _schedulePhoneLookup(String rawInput) {
    _phoneDebounce?.cancel();
    final normalized = _normalize(rawInput);

    if (normalized.isEmpty) {
      if (_normalizedPhone.isEmpty && _phoneState == _PhoneLookupState.idle) {
        return;
      }
      setState(() {
        _normalizedPhone = '';
        _phoneState = _PhoneLookupState.idle;
        _phoneFoundId = '';
        _phoneFoundName = '';
        _phoneFoundCity = '';
        _phoneError = '';
      });
      return;
    }

    final sameNumberResolved =
        _normalizedPhone == normalized &&
        _phoneState != _PhoneLookupState.idle &&
        _phoneState != _PhoneLookupState.searching;
    if (sameNumberResolved) return;

    setState(() {
      _normalizedPhone = normalized;
      _phoneState = _PhoneLookupState.searching;
      _phoneFoundId = '';
      _phoneFoundName = '';
      _phoneFoundCity = '';
      _phoneError = '';
    });
    _phoneDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _runPhoneLookup(normalized),
    );
  }

  Future<void> _runPhoneLookup(String normalized) async {
    try {
      final page = await storage_api.StorageApi.getSpecialists(
        search: normalized,
        limit: 20,
      );
      if (!mounted || _normalizedPhone != normalized) return;
      final needle = normalized.replaceAll(RegExp(r'\D'), '');
      final needleTail = needle.substring(needle.length - 10);
      final exact = page.specialists.where((specialist) {
        final phone = (specialist.phone ?? '').replaceAll(RegExp(r'\D'), '');
        final tail = phone.length >= 10
            ? phone.substring(phone.length - 10)
            : phone;
        return tail == needleTail;
      }).toList();
      if (exact.isEmpty) {
        setState(() {
          _phoneState = _PhoneLookupState.notFound;
          _phoneFoundId = '';
          _phoneFoundName = '';
          _phoneFoundCity = '';
          _phoneError = '';
        });
        return;
      }

      final staffIds = _staff.map((s) => s.id).toSet();
      final companyStaffMatch = exact.where((s) => staffIds.contains(s.id));
      final specialist = companyStaffMatch.isNotEmpty
          ? companyStaffMatch.first
          : exact.first;
      setState(() {
        _phoneState = staffIds.contains(specialist.id)
            ? _PhoneLookupState.found
            : _PhoneLookupState.notCompanyStaff;
        _phoneFoundId = specialist.id.toString();
        _phoneFoundName = specialist.displayName;
        _phoneFoundCity = (specialist.city ?? '').trim();
        _phoneError = '';
      });
    } on storage_api.SessionExpiredException {
      if (!mounted || _normalizedPhone != normalized) return;
      setState(() {
        _phoneState = _PhoneLookupState.error;
        _phoneError = 'Сессия истекла. Войдите заново.';
      });
    } catch (e) {
      if (!mounted || _normalizedPhone != normalized) return;
      setState(() {
        _phoneState = _PhoneLookupState.error;
        _phoneError = 'Не удалось выполнить поиск: $e';
      });
    }
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

  // ── Staff invitation helpers ───────────────────────────────────────

  String _normalizeInvitePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return '';
    final tail = digits.substring(digits.length - 10);
    return '+7$tail';
  }

  /// Определяет специалиста по введённому телефону БЕЗ отправки приглашения —
  /// чтобы диалог показал, кого именно пригласят (как вкладка «По телефону»
  /// при назначении специалиста на заявку).
  Future<InvitePhoneLookupResult> _lookupSpecialistByPhone(
    String rawPhone,
  ) async {
    final phone = _normalizeInvitePhone(rawPhone);
    if (phone.isEmpty) {
      return const InvitePhoneLookupResult.notFound();
    }
    final page = await storage_api.StorageApi.getSpecialists(
      search: phone,
      limit: 20,
    );
    final phoneTail = phone.replaceAll(RegExp(r'\D'), '').substring(1);
    final exact = page.specialists.where((specialist) {
      final candidate = (specialist.phone ?? '').replaceAll(RegExp(r'\D'), '');
      final candidateTail = candidate.length >= 10
          ? candidate.substring(candidate.length - 10)
          : candidate;
      return candidateTail == phoneTail;
    }).toList();
    if (exact.isEmpty) {
      return const InvitePhoneLookupResult.notFound();
    }
    final specialist = exact.first;
    if (_staff.any((staff) => staff.id == specialist.id)) {
      return InvitePhoneLookupResult.alreadyInStaff(specialist);
    }
    return InvitePhoneLookupResult.available(specialist);
  }

  Future<String> _sendStaffInvitationByPhone(String rawPhone) async {
    final phone = _normalizeInvitePhone(rawPhone);
    if (phone.isEmpty) {
      throw Exception('Введите полный номер телефона');
    }

    final page = await storage_api.StorageApi.getSpecialists(
      search: phone,
      limit: 20,
    );
    final phoneTail = phone.replaceAll(RegExp(r'\D'), '').substring(1);
    final exact = page.specialists.where((specialist) {
      final candidate = (specialist.phone ?? '').replaceAll(RegExp(r'\D'), '');
      final candidateTail = candidate.length >= 10
          ? candidate.substring(candidate.length - 10)
          : candidate;
      return candidateTail == phoneTail;
    }).toList();
    if (exact.isEmpty) {
      throw Exception(
        'Специалист с этим номером не найден. Сейчас можно пригласить только зарегистрированного специалиста.',
      );
    }

    final specialist = exact.first;
    if (_staff.any((staff) => staff.id == specialist.id)) {
      throw Exception('${specialist.displayName} уже в штате компании');
    }

    await NotificationApi.sendNotification(
      type: NotificationType.invitation,
      recipientId: specialist.id,
      title: 'Приглашение в штат',
      body:
          'Компания приглашает вас присоединиться к штату специалистов в Autopodbor.',
      payload: <String, dynamic>{
        'source': 'spark_joy_assignee_picker',
        'phone': phone,
      },
    );
    return specialist.displayName;
  }

  Future<void> _openInviteByPhoneDialog() async {
    final invitedName = await showDialog<String>(
      context: context,
      builder: (_) => SparkJoyInviteByPhoneDialog(
        onLookup: _lookupSpecialistByPhone,
        onInvite: _sendStaffInvitationByPhone,
      ),
    );
    if (invitedName == null || !mounted) return;
    setState(() {
      _altSection = _AltSection.none;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          invitedName.isEmpty
              ? 'Приглашение отправлено'
              : 'Приглашение отправлено: $invitedName',
        ),
      ),
    );
    await _loadStaff();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selection = _currentSelection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!selection.isEmpty) ...[
          _CurrentSelectionBanner(selection: selection, onClear: _clearAll),
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
        if (_staffLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SparkSpace.md),
            decoration: BoxDecoration(
              color: kInputBgColor,
              border: Border.all(color: kBorderColor),
              borderRadius: BorderRadius.circular(SparkRadius.md),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: SparkSpace.sm),
                MyText(
                  text: 'Загрузка штата...',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
              ],
            ),
          )
        else if (_staffError != null)
          _HintCard(
            iconColor: kRedColor,
            icon: Icons.error_outline_rounded,
            title: 'Не удалось загрузить штат',
            description: _staffError!,
            actionLabel: 'Повторить',
            onAction: _loadStaff,
          )
        else if (!hasStaff)
          _EmptyStaffCard(onInvite: () => _toggleAltSection(_AltSection.invite))
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
                  if (i > 0) const Divider(height: 1, indent: SparkSpace.xxxl),
                  _StaffRow(
                    id: staff[i].id.toString(),
                    name: staff[i].displayName,
                    selected:
                        _mode == SparkJoyAssigneeMode.staff &&
                        _specialistId == staff[i].id.toString(),
                    onTap: () => _toggleStaff(
                      staff[i].id.toString(),
                      staff[i].displayName,
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
          title: 'Пригласить в штат',
          subtitle: 'По номеру зарегистрированного специалиста',
          expanded: _altSection == _AltSection.invite,
          onToggle: () => _toggleAltSection(_AltSection.invite),
          child: _buildInviteBody(),
        ),
      ],
    );
  }

  Widget _buildPhoneBody() {
    final assigned =
        _specialistId.isNotEmpty &&
        _specialistId == _phoneFoundId &&
        _phoneState == _PhoneLookupState.found;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: sparkInputDecoration(
            '(___) ___-__-__',
          ).copyWith(prefixText: '+7 '),
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
              'Сейчас можно пригласить в штат только зарегистрированного специалиста. Проверьте номер или попросите специалиста зарегистрироваться.',
        );
      case _PhoneLookupState.notCompanyStaff:
        return const _HintCard(
          iconColor: kRedColor,
          icon: Icons.block_outlined,
          title: 'Специалист не привязан к вашей компании',
          description:
              'Назначить можно только сотрудника из вашего штата. Пригласите специалиста в компанию или выберите другого исполнителя.',
        );
      case _PhoneLookupState.error:
        return _HintCard(
          iconColor: kRedColor,
          icon: Icons.error_outline_rounded,
          title: 'Ошибка поиска',
          description: _phoneError.isEmpty
              ? 'Не удалось выполнить поиск по номеру.'
              : _phoneError,
        );
      case _PhoneLookupState.idle:
        return const MyText(
          text:
              'Введите номер сотрудника из штата — найдём его через Storage.GetSpecialists и назначим исполнителем.',
          size: SparkTextSize.caption,
          color: kGreyColor,
        );
    }
  }

  Widget _buildInviteBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openInviteByPhoneDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Пригласить по телефону'),
          ),
        ),
        const SizedBox(height: SparkSpace.md),
        const MyText(
          text:
              'Специалист получит уведомление-приглашение. После принятия он появится в штате, и его можно будет назначить исполнителем.',
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
    final icon = hasSpecialist
        ? Icons.check_circle_outline
        : Icons.link_rounded;
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
                'Пригласите специалиста по телефону — он получит уведомление и сможет вступить в штат.',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
          const SizedBox(height: SparkSpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Пригласить по телефону'),
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
  return showAppAdaptiveBottomSheet<SparkJoyAssigneeSelection>(
    context: context,
    extent: AppBottomSheetExtent.expanded,
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
    return Column(
      children: [
        AppBottomSheetHeader(
          title: 'Назначить исполнителя',
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.xl,
            0,
            SparkSpace.xl,
            SparkSpace.sm,
          ),
          onClose: () => Navigator.of(context).pop(null),
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
    this.onBeforeOpen,
  });

  final String companyId;
  final SparkJoyAssigneeSelection selection;
  final ValueChanged<SparkJoyAssigneeSelection> onChanged;

  /// Optional callback fired right before the picker sheet opens. Used by
  /// the new-report screen to surface the «Назначьте исполнителя»
  /// onboarding only when the user actually engages with the picker —
  /// not on screen mount. If it returns a Future the open is awaited.
  final Future<void> Function()? onBeforeOpen;

  Future<void> _open(BuildContext context) async {
    if (onBeforeOpen != null) {
      await onBeforeOpen!();
      if (!context.mounted) return;
    }
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
    return (Icons.mark_email_read_outlined, 'Приглашение отправлено', null);
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
                onPressed: () => onChanged(const SparkJoyAssigneeSelection()),
              ),
            const Icon(Icons.chevron_right_rounded, color: kGreyColor),
          ],
        ),
      ),
    );
  }
}

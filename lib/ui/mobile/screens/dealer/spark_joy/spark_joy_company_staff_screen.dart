import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_staff_detail_screen.dart';
import 'spark_joy_error_snackbar.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_invite_by_phone_dialog.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class _StaffEntry {
  const _StaffEntry({required this.data});

  final Map<String, dynamic> data;
}

class SparkJoyCompanyStaffScreen extends StatefulWidget {
  const SparkJoyCompanyStaffScreen({super.key, this.active = false});

  final bool active;

  @override
  State<SparkJoyCompanyStaffScreen> createState() =>
      _SparkJoyCompanyStaffScreenState();
}

class _SparkJoyCompanyStaffScreenState
    extends State<SparkJoyCompanyStaffScreen> {
  static const int _pageLimit = 100;

  bool _loading = true;
  String? _loadError;
  bool _loadedOnce = false;
  bool _requestsLoaded = false;
  Future<void>? _requestsLoadFuture;
  String _search = '';
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];
  List<SpecialistItem> _staff = const <SpecialistItem>[];
  final Set<int> _unlinkingStaffIds = <int>{};

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant SparkJoyCompanyStaffScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _load();
    }
  }

  Future<List<SpecialistItem>> _loadCompanyStaff() async {
    var pageNumber = 1;
    var totalPages = 1;
    final staff = <SpecialistItem>[];

    do {
      final page = await storage_api.StorageApi.getCompanySpecialistsPage(
        page: pageNumber,
        limit: _pageLimit,
      );
      staff.addAll(page.specialists);
      totalPages = page.pages <= 0 ? 1 : page.pages;
      pageNumber += 1;
    } while (pageNumber <= totalPages);

    return staff;
  }

  Future<List<Map<String, dynamic>>> _getRequestsWithRetry() async {
    try {
      return await storage_api.StorageApi.getAllRequests();
    } on storage_api.SessionExpiredException {
      rethrow;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return storage_api.StorageApi.getAllRequests();
    }
  }

  Future<void> _refreshRequests({bool showErrors = false}) {
    final inFlight = _requestsLoadFuture;
    if (inFlight != null) return inFlight;

    final future = _refreshRequestsImpl(showErrors: showErrors);
    _requestsLoadFuture = future;
    return future.whenComplete(() {
      if (_requestsLoadFuture == future) {
        _requestsLoadFuture = null;
      }
    });
  }

  Future<void> _refreshRequestsImpl({required bool showErrors}) async {
    try {
      final requests = (await _getRequestsWithRetry())
          .map((request) => Map<String, dynamic>.from(request))
          .toList();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _requestsLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (showErrors && _requests.isNotEmpty) {
        _showRefreshErrorSnackbar(
          e,
          fallback:
              'Список сотрудников обновлён, заявки сотрудника обновить не удалось',
        );
      }
    }
  }

  Future<void> _load() async {
    final hadStableState = _loadedOnce;
    setState(() {
      _loading = !hadStableState;
      _loadError = null;
    });
    try {
      final staff = await _loadCompanyStaff();
      if (!mounted) return;
      setState(() {
        if (staff.isEmpty) {
          _requests = <Map<String, dynamic>>[];
          _requestsLoaded = true;
        } else {
          _requestsLoaded = false;
        }
        _staff = staff;
        _loading = false;
        _loadedOnce = true;
      });
      if (staff.isNotEmpty) {
        unawaited(_refreshRequests(showErrors: hadStableState));
      }
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      const msg = 'Сессия истекла. Войдите заново.';
      if (hadStableState) {
        _showRefreshErrorSnackbar(msg);
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _loadError = msg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = sjT(
        'spark.state.error.staff',
        fallback:
            'Не удалось загрузить список сотрудников. Проверьте подключение и повторите.',
      );
      if (hadStableState) {
        _showRefreshErrorSnackbar(e, fallback: msg);
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _loadError = sparkJoyReadableErrorText(e, fallback: msg);
        });
      }
    }
  }

  void _showRefreshErrorSnackbar(Object error, {String? fallback}) {
    showSparkJoyErrorSnackBar(context, error, fallback: fallback);
  }

  Map<String, dynamic> _specialistMap(SpecialistItem specialist) {
    return <String, dynamic>{
      'id': specialist.id.toString(),
      'name': specialist.displayName,
      'phone': specialist.phone ?? '',
      'email': specialist.email ?? '',
      'city': specialist.city ?? '',
      'urlAvatar': specialist.urlAvatar ?? '',
      'specialization': specialist.description ?? '',
      'rating': specialist.rating,
      'likeUp': specialist.likeUp,
      'likeDown': specialist.likeDown,
    };
  }

  int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  int? _assignedSpecialistId(Map<String, dynamic> request) {
    final rawSpecialist = request['assignedSpecialist'];
    final specialist = rawSpecialist is Map
        ? Map<String, dynamic>.from(rawSpecialist)
        : null;
    return _readInt(request['assignedSpecialistId']) ??
        _readInt(request['assignedSpecialistUserId']) ??
        _readInt(specialist?['id']);
  }

  List<Map<String, dynamic>> _requestsListForId(int specialistId) {
    return _requests
        .where((request) => _assignedSpecialistId(request) == specialistId)
        .map((request) => Map<String, dynamic>.from(request))
        .toList();
  }

  bool _isActiveRequest(Map<String, dynamic> request) {
    switch (normalizeRequestStatus(sjRead(request, 'status'))) {
      case 'created':
      case 'await_payment':
      case 'paid_escrow':
      case 'in_work':
        return true;
      default:
        return false;
    }
  }

  List<Map<String, dynamic>> _activeRequestsListForId(int specialistId) {
    return _requestsListForId(specialistId).where(_isActiveRequest).toList();
  }

  List<_StaffEntry> _buildEntries() {
    return _staff
        .map((specialist) => _StaffEntry(data: _specialistMap(specialist)))
        .toList();
  }

  List<_StaffEntry> _filter(List<_StaffEntry> all) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all.where((entry) {
      final text = [
        sjRead(entry.data, 'name'),
        sjRead(entry.data, 'phone'),
        sjRead(entry.data, 'email'),
        sjRead(entry.data, 'city'),
        sjRead(entry.data, 'specialization'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Future<void> _openSpecialist(Map<String, dynamic> specialist) async {
    final specialistId = _specialistId(specialist);
    if (specialistId == null) return;
    if (!_requestsLoaded) {
      await _refreshRequests(showErrors: true);
      if (!mounted) return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCompanyStaffDetailScreen(
          specialist: specialist,
          requests: _requestsListForId(specialistId),
        ),
      ),
    );
    unawaited(_refreshRequests(showErrors: false));
  }

  int? _specialistId(Map<String, dynamic> specialist) {
    return int.tryParse(sjRead(specialist, 'id'));
  }

  Future<bool> _confirmUnlinkSpecialist(Map<String, dynamic> specialist) async {
    final name = sjRead(specialist, 'name', fallback: 'сотрудника');
    final specialistId = _specialistId(specialist);
    final activeRequests = specialistId == null || !_requestsLoaded
        ? null
        : _activeRequestsListForId(specialistId).length;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить из штата?'),
        content: Text(
          activeRequests != null && activeRequests > 0
              ? '$name будет удалён из штата компании. Если у сотрудника есть активные заявки, сервер не позволит выполнить удаление.'
              : '$name будет удалён из штата компании.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kRedColor),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _unlinkSpecialist(Map<String, dynamic> specialist) async {
    final specialistId = _specialistId(specialist);
    if (specialistId == null || specialistId <= 0) {
      showSparkJoyErrorSnackBar(context, 'Не удалось определить ID сотрудника');
      return;
    }
    if (_unlinkingStaffIds.contains(specialistId)) return;

    final confirmed = await _confirmUnlinkSpecialist(specialist);
    if (!confirmed || !mounted) return;

    setState(() => _unlinkingStaffIds.add(specialistId));
    try {
      await storage_api.StorageApi.unlinkCompanySpecialist(
        specialistId: specialistId,
      );
      if (!mounted) return;
      setState(() {
        _staff = _staff.where((staff) => staff.id != specialistId).toList();
        _loadedOnce = true;
        _loadError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сотрудник удалён из штата')),
      );
    } on storage_api.CompanySpecialistUnlinkException catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось удалить сотрудника',
      );
    } finally {
      if (mounted) {
        setState(() => _unlinkingStaffIds.remove(specialistId));
      }
    }
  }

  String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return '';
    final tail = digits.substring(digits.length - 10);
    return '+7$tail';
  }

  Future<String> _sendStaffInvitationByPhone(String rawPhone) async {
    final phone = _normalizePhone(rawPhone);
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

    // Name the inviting company so the recipient sees WHO invites them and
    // can open the company from the notification (B6). senderId already lets
    // the recipient navigate, but the name makes the short text clear.
    var companyName = '';
    int? companyId;
    try {
      final me = await storage_api.StorageApi.getProfile();
      companyName = (me['companyName'] ?? me['name'] ?? '').toString().trim();
      final rawId = me['id'] ?? me['companyId'];
      companyId = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
    } catch (_) {
      // Best-effort enrichment — fall back to the generic copy below.
    }

    await NotificationApi.sendNotification(
      type: NotificationType.invitation,
      recipientId: specialist.id,
      title: 'Приглашение в штат',
      body: companyName.isNotEmpty
          ? 'Компания «$companyName» приглашает вас присоединиться к штату '
                'специалистов в Autopodbor.'
          : 'Компания приглашает вас присоединиться к штату специалистов в '
                'Autopodbor.',
      payload: <String, dynamic>{
        'source': 'spark_joy_company_staff',
        'phone': phone,
        if (companyName.isNotEmpty) 'companyName': companyName,
        if (companyId != null && companyId > 0) 'companyId': companyId,
      },
    );
    return specialist.displayName;
  }

  Future<void> _openInviteByPhoneDialog() async {
    final invitedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          SparkJoyInviteByPhoneDialog(onInvite: _sendStaffInvitationByPhone),
    );
    if (invitedName == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          invitedName.isEmpty
              ? 'Приглашение отправлено'
              : 'Приглашение отправлено: $invitedName',
        ),
      ),
    );
    await _load();
  }

  Widget _staffChip() {
    return SparkChip(
      text: 'В штате',
      icon: Icons.badge_outlined,
      background: kSecondaryColor.withValues(alpha: 0.08),
      color: kSecondaryColor,
    );
  }

  Widget _buildPersonCard(_StaffEntry entry) {
    final specialist = entry.data;
    final phone = sjRead(specialist, 'phone');
    final email = sjRead(specialist, 'email');
    final city = sjRead(specialist, 'city');
    final specialization = sjRead(specialist, 'specialization');
    final specialistId = _specialistId(specialist);
    final unlinking =
        specialistId != null && _unlinkingStaffIds.contains(specialistId);

    return SparkListCard(
      onTap: () => _openSpecialist(specialist),
      child: Column(
        children: [
          Row(
            children: [
              SparkInitialsAvatar(
                name: sjRead(specialist, 'name'),
                size: SparkSize.avatarSm,
                textSize: SparkTextSize.label,
                imageUrl: sjRead(specialist, 'urlAvatar'),
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: sjRead(specialist, 'name'),
                            size: SparkTextSize.bodyLg,
                            weight: FontWeight.w700,
                            maxLines: 1,
                          ),
                        ),
                        _staffChip(),
                      ],
                    ),
                    if (specialization.trim().isNotEmpty)
                      MyText(
                        text: specialization,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                        maxLines: 2,
                      ),
                    if (phone.trim().isNotEmpty)
                      MyText(
                        text: phone,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      )
                    else if (email.trim().isNotEmpty)
                      MyText(
                        text: email,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      ),
                    if (city.trim().isNotEmpty)
                      MyText(
                        text: city,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxxs,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.sm),
              SizedBox(
                width: SparkSize.actionHeight,
                height: SparkSize.actionHeight,
                child: IconButton(
                  tooltip: 'Удалить из штата',
                  onPressed: unlinking
                      ? null
                      : () => _unlinkSpecialist(specialist),
                  icon: unlinking
                      ? const SizedBox(
                          width: SparkSize.spinner,
                          height: SparkSize.spinner,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.person_remove_outlined,
                          size: SparkSize.iconMd,
                          color: kRedColor,
                        ),
                ),
              ),
              const SizedBox(width: SparkSpace.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: SparkSize.iconMd,
                color: kGreyColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _buildEntries();
    final entries = _filter(all);

    return SparkScreenList(
      bottomInset: 56,
      onRefresh: _load,
      children: [
        SizedBox(
          height: SparkSize.actionHeight,
          child: FilledButton.icon(
            onPressed: _loading ? null : _openInviteByPhoneDialog,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Пригласить по телефону'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
            ),
          ),
        ),
        const SizedBox(height: SparkSpace.xl),
        SparkSearchField(
          hint: 'Поиск по имени, телефону или городу',
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: SparkSpace.xl),
        if (_loading)
          SparkLoadingState(
            message: sjT(
              'spark.state.loading.staff',
              fallback: 'Загрузка сотрудников...',
            ),
          )
        else if (_loadError != null)
          SparkErrorState(
            title: sjT('spark.state.error.title', fallback: 'Ошибка загрузки'),
            subtitle: _loadError!,
            copyText: _loadError,
            onRetry: _load,
          )
        else if (entries.isEmpty)
          SparkHintCard(
            text: _search.trim().isEmpty
                ? sjT(
                    'spark.empty.noStaff',
                    fallback:
                        'В штате пока нет сотрудников, привязанных к компании',
                  )
                : 'По запросу ничего не найдено',
          )
        else
          ...entries.map(_buildPersonCard),
      ],
    );
  }
}

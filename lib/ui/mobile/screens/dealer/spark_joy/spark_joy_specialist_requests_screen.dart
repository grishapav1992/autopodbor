import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_error_snackbar.dart';
import 'spark_joy_external_link.dart';
import 'spark_joy_request_filter_bar.dart';
import 'spark_joy_request_refresh_bus.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoySpecialistRequestsScreen extends StatefulWidget {
  const SparkJoySpecialistRequestsScreen({super.key, this.active = false});

  final bool active;

  @override
  State<SparkJoySpecialistRequestsScreen> createState() =>
      _SparkJoySpecialistRequestsScreenState();
}

class _SparkJoySpecialistRequestsScreenState
    extends State<SparkJoySpecialistRequestsScreen> {
  List<Map<String, dynamic>>? _requests;
  bool _loading = true;
  String? _loadError;
  RequestStatusFilter _statusFilter = RequestStatusFilter.all;
  bool _reloadWhenActive = false;
  bool _loadInFlight = false;
  bool _loadQueuedWhileInFlight = false;

  @override
  void initState() {
    super.initState();
    SparkJoyRequestRefreshBus.notifier.addListener(_onExternalRequestChanged);
    if (widget.active) {
      _load();
    }
  }

  @override
  void dispose() {
    SparkJoyRequestRefreshBus.notifier.removeListener(
      _onExternalRequestChanged,
    );
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SparkJoySpecialistRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        !oldWidget.active &&
        (_requests == null || _reloadWhenActive)) {
      _reloadWhenActive = false;
      _load();
    }
  }

  void _onExternalRequestChanged() {
    if (!mounted) return;
    if (!widget.active) {
      _reloadWhenActive = true;
      return;
    }
    _load();
  }

  Future<List<Map<String, dynamic>>> _getRequestsWithRetry() async {
    final filter = _statusFilter;
    try {
      return await _getRequestsForFilter(filter);
    } on storage_api.SessionExpiredException {
      rethrow;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return _getRequestsForFilter(filter);
    }
  }

  Future<List<Map<String, dynamic>>> _getRequestsForFilter(
    RequestStatusFilter filter,
  ) async {
    if (filter == RequestStatusFilter.all) {
      return storage_api.StorageApi.getAllRequests();
    }
    final requestsById = <String, Map<String, dynamic>>{};
    for (final status in filter.statuses) {
      final page = await storage_api.StorageApi.getAllRequests(status: status);
      for (final request in page) {
        final id = (request['id'] ?? request['requestNumber'] ?? '').toString();
        requestsById[id.isEmpty ? requestsById.length.toString() : id] =
            request;
      }
    }
    return requestsById.values.toList(growable: false);
  }

  Future<void> _load() async {
    if (!mounted) return;
    // WS-пуши статусов приходят пачками (created→assigned→… даёт несколько
    // событий SparkJoyRequestRefreshBus подряд), и каждое запускало свой
    // GetAllRequests. Коалесим: пока запрос в полёте, новые триггеры
    // схлопываются в один повторный прогон после текущего. Заодно уходит
    // гонка «старый ответ перетёр новый» при смене фильтра во время загрузки.
    if (_loadInFlight) {
      _loadQueuedWhileInFlight = true;
      return;
    }
    _loadInFlight = true;
    try {
      await _loadOnce();
    } finally {
      _loadInFlight = false;
      if (_loadQueuedWhileInFlight && mounted) {
        _loadQueuedWhileInFlight = false;
        unawaited(_load());
      }
    }
  }

  Future<void> _loadOnce() async {
    final hadData = _requests != null;
    setState(() {
      _loading = !hadData;
      _loadError = null;
    });
    try {
      final result = await _getRequestsWithRetry();
      if (!mounted) return;
      setState(() {
        _requests = result;
        _loading = false;
      });
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      const msg = 'Сессия истекла. Войдите заново.';
      if (hadData) {
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
      if (hadData) {
        _showRefreshErrorSnackbar(e, fallback: 'Не удалось обновить список');
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _loadError = sparkJoyReadableErrorText(
            e,
            fallback: 'Не удалось загрузить заявки',
          );
        });
      }
    }
  }

  void _showRefreshErrorSnackbar(Object error, {String? fallback}) {
    showSparkJoyErrorSnackBar(context, error, fallback: fallback);
  }

  Future<void> _openDetail(Map<String, dynamic> request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SparkJoySpecialistRequestDetailScreen(initial: request),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SparkScreenList(
        bottomInset: 24,
        children: const [SizedBox(height: 60), SparkLoadingState()],
      );
    }
    if (_loadError != null) {
      return SparkScreenList(
        bottomInset: 24,
        onRefresh: _load,
        children: [
          const SizedBox(height: 24),
          SparkErrorState(
            title: 'Не удалось загрузить заявки',
            subtitle: _loadError!,
            copyText: _loadError,
            onRetry: _load,
          ),
        ],
      );
    }

    final requests = _requests ?? const [];
    if (requests.isEmpty && _statusFilter == RequestStatusFilter.all) {
      return SparkScreenList(
        bottomInset: 24,
        onRefresh: _load,
        children: const [SizedBox(height: 60), _EmptyInboxState()],
      );
    }
    return SparkScreenList(
      bottomInset: 24,
      onRefresh: _load,
      children: [
        const SparkSectionTitle('Назначенные заявки'),
        const SizedBox(height: SparkSpace.md),
        SparkJoyRequestFilterBar(
          value: _statusFilter,
          onChanged: (filter) {
            if (filter == _statusFilter) return;
            setState(() => _statusFilter = filter);
            _load();
          },
        ),
        const SizedBox(height: SparkSpace.lg),
        if (requests.isEmpty)
          const SparkHintCard(text: 'Заявок с таким статусом нет')
        else
          for (final r in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.md),
              child: _SpecialistRequestCard(
                data: r,
                onTap: () => _openDetail(r),
              ),
            ),
      ],
    );
  }
}

class _EmptyInboxState extends StatelessWidget {
  const _EmptyInboxState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kSecondaryColor.withValues(alpha: 0.1),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.assignment_ind_outlined,
              size: 40,
              color: kSecondaryColor,
            ),
          ),
        ),
        const SizedBox(height: SparkSpace.xxl),
        const MyText(
          text: 'Назначенных заявок пока нет',
          size: SparkTextSize.titleLg,
          weight: FontWeight.w800,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SparkSpace.sm),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: SparkSpace.xxxl),
          child: MyText(
            text:
                'Когда компания назначит вам заявку, она появится здесь. '
                'Откройте её, чтобы принять или отклонить работу.',
            size: SparkTextSize.body,
            color: kGreyColor,
            textAlign: TextAlign.center,
            lineHeight: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SpecialistRequestCard extends StatelessWidget {
  const _SpecialistRequestCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  String _str(String key) => (data[key] ?? '').toString();

  String get _title {
    final number = _str('requestNumber');
    return number.isNotEmpty ? 'Заявка №$number' : 'Заявка';
  }

  String get _subtitle {
    final cars = data['requestCars'] ?? data['cars'];
    if (cars is List && cars.isNotEmpty) {
      final first = cars.first;
      if (first is Map) {
        final brand = (first['brand'] is Map)
            ? (first['brand']['name'] ?? '').toString()
            : (first['brand'] ?? '').toString();
        final model = (first['model'] is Map)
            ? (first['model']['model'] ?? first['model']['name'] ?? '')
                  .toString()
            : (first['model'] ?? '').toString();
        final combined = [
          brand.trim(),
          model.trim(),
        ].where((s) => s.isNotEmpty).join(' ');
        if (combined.isNotEmpty) return combined;
      } else {
        final value = first.toString().trim();
        if (value.isNotEmpty) return value;
      }
    }
    return 'Автомобиль не указан';
  }

  String get _meta {
    final due = _str('dueAt');
    final city = _str('city').trim();
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (due.isNotEmpty) 'Срок: ${_formatRuDate(due)}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final badge = requestStatusBadge(_str('status'));
    return SparkCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_ind_outlined,
            size: SparkSize.iconLg,
            color: kSecondaryColor,
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
                        text: _title,
                        size: SparkTextSize.bodyLg,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.sm),
                    SparkChip(
                      text: badge.label,
                      background: badge.bg,
                      color: badge.fg,
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.xxs),
                MyText(
                  text: _subtitle,
                  size: SparkTextSize.body,
                  color: kGreyColor,
                ),
                if (_meta.isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xxs),
                  MyText(
                    text: _meta,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: kGreyColor,
            size: SparkSize.iconMd,
          ),
        ],
      ),
    );
  }
}

class SparkJoySpecialistRequestDetailScreen extends StatefulWidget {
  const SparkJoySpecialistRequestDetailScreen({
    super.key,
    required this.initial,
  });

  final Map<String, dynamic> initial;

  @override
  State<SparkJoySpecialistRequestDetailScreen> createState() =>
      _SparkJoySpecialistRequestDetailScreenState();
}

class _SparkJoySpecialistRequestDetailScreenState
    extends State<SparkJoySpecialistRequestDetailScreen> {
  late Map<String, dynamic> _request;
  List<Map<String, dynamic>>? _cars;
  List<Map<String, dynamic>> _requestStatusHistoriesFromCars = const [];
  String? _carsError;
  bool _actionBusy = false;
  bool _openingReport = false;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.initial);
    _loadCars();
  }

  int? get _requestId {
    final v = _request['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _str(String key) => (_request[key] ?? '').toString();

  Future<void> _loadCars() async {
    final id = _requestId;
    if (id == null) {
      setState(() {
        _cars = const [];
        _carsError = 'Не удалось определить ID заявки';
      });
      return;
    }
    try {
      final details = await storage_api.StorageApi.getRequestCarDetails(
        requestId: id,
      );
      if (!mounted) return;
      setState(() {
        _cars = details.cars;
        _requestStatusHistoriesFromCars = details.requestStatusHistories;
        _carsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cars = const [];
        _carsError = 'Не удалось загрузить детали авто: $e';
      });
    }
  }

  Future<void> _refreshRequestSnapshot() async {
    final id = _requestId;
    if (id == null) return;
    final requests = await storage_api.StorageApi.getAllRequests();
    final next = requests.where((r) {
      final raw = r['id'];
      final itemId = raw is int
          ? raw
          : raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '');
      return itemId == id;
    }).toList();
    if (!mounted || next.isEmpty) return;
    setState(() => _request = next.first);
  }

  Future<void> _accept() async {
    final note = await _showNoteSheet(
      context,
      title: 'Принять заявку',
      hint: 'Комментарий для компании (необязательно)',
      actionLabel: 'Принять',
      actionIcon: Icons.check_rounded,
    );
    if (note == null || _actionBusy) return;
    final id = _requestId;
    if (id == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _actionBusy = true);
    try {
      final result = await storage_api.StorageApi.acceptRequest(
        requestId: id,
        note: note,
      );
      if (!mounted) return;
      if (result.status.isNotEmpty) {
        setState(() => _request['status'] = result.status);
      }
      try {
        await _refreshRequestSnapshot();
      } catch (_) {
        // Acceptance already succeeded. A stale detail snapshot is better
        // than showing a false negative because the follow-up refresh failed.
      }
      try {
        await _ensureRequestDraft(id);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка принята, но черновик не был создан'),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заявка принята. Черновик доступен в отчётах'),
        ),
      );
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      _showActionError('Сессия истекла. Войдите заново.');
    } catch (e) {
      if (!mounted) return;
      _showActionError(e, fallback: 'Не удалось принять заявку');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _rejectNewRequest() {
    return _rejectRequest(
      title: 'Отклонить заявку',
      hint: 'Причина отказа (необязательно)',
      actionLabel: 'Отклонить',
      successMessage: 'Заявка отклонена',
      errorMessage: 'Не удалось отклонить заявку',
    );
  }

  Future<void> _rejectRequest({
    required String title,
    required String hint,
    required String actionLabel,
    required String successMessage,
    required String errorMessage,
    IconData actionIcon = Icons.close_rounded,
  }) async {
    final note = await _showNoteSheet(
      context,
      title: title,
      hint: hint,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      destructive: true,
    );
    if (note == null || _actionBusy) return;
    final id = _requestId;
    if (id == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _actionBusy = true);
    try {
      final result = await storage_api.StorageApi.rejectRequest(
        requestId: id,
        note: note,
      );
      if (!mounted) return;
      if (result.status.isNotEmpty) {
        setState(() => _request['status'] = result.status);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      Navigator.of(context).pop(true);
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      _showActionError('Сессия истекла. Войдите заново.');
    } catch (e) {
      if (!mounted) return;
      _showActionError(e, fallback: errorMessage);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _abandonRequest() async {
    final note = await _showNoteSheet(
      context,
      title: 'Заявка не выполнена',
      hint: 'Причина, почему не удалось выполнить заявку',
      actionLabel: 'Отметить неудачной',
      actionIcon: Icons.error_outline_rounded,
      destructive: true,
    );
    if (note == null || _actionBusy) return;
    if (note.trim().isEmpty) {
      _showActionError('Укажите причину, почему заявку не удалось выполнить');
      return;
    }
    final id = _requestId;
    if (id == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _actionBusy = true);
    try {
      final result = await storage_api.StorageApi.abandonRequest(
        requestId: id,
        note: note,
      );
      if (!mounted) return;
      setState(
        () => _request['status'] = result.status.isNotEmpty
            ? result.status
            : 'failed',
      );
      await _deleteLocalDraftsForRequest(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка отмечена как не выполненная')),
      );
      Navigator.of(context).pop(true);
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      _showActionError('Сессия истекла. Войдите заново.');
    } catch (e) {
      if (!mounted) return;
      _showActionError(
        e,
        fallback: 'Не удалось отметить заявку как не выполненную',
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _deleteLocalDraftsForRequest(int requestId) async {
    final drafts = await SparkJoyStorage.loadDrafts();
    final ids = drafts
        .where((draft) => _draftRequestId(draft) == requestId)
        .map((draft) => (draft['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    for (final id in ids) {
      await SparkJoyStorage.deleteDraft(id);
    }
  }

  void _showActionError(Object error, {String? fallback}) {
    showSparkJoyErrorSnackBar(context, error, fallback: fallback);
  }

  Future<void> _openReportForRequest() async {
    final id = _requestId;
    if (id == null || _openingReport) return;
    HapticFeedback.selectionClick();
    setState(() => _openingReport = true);
    try {
      final draft = await _ensureRequestDraft(id);
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SparkJoyCreateReportScreen(draft: draft),
        ),
      );
      if (!mounted) return;
      if (changed == true) {
        await _refreshRequestSnapshot();
      }
    } catch (e) {
      if (!mounted) return;
      _showActionError(e, fallback: 'Не удалось открыть отчёт по заявке');
    } finally {
      if (mounted) setState(() => _openingReport = false);
    }
  }

  Future<Map<String, dynamic>> _ensureRequestDraft(int requestId) async {
    if (_cars == null) {
      await _loadCars();
      if (!mounted) {
        throw StateError('screen disposed');
      }
    }
    final drafts = await SparkJoyStorage.loadDrafts();
    final existing = drafts.where((draft) {
      return _draftRequestId(draft) == requestId;
    }).toList();
    if (existing.isNotEmpty) return existing.first;
    return _createRequestDraft(requestId);
  }

  int? _draftRequestId(Map<String, dynamic> draft) {
    final raw = draft['requestId'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<Map<String, dynamic>> _createRequestDraft(int requestId) async {
    final now = DateTime.now();
    final car = (_cars != null && _cars!.isNotEmpty) ? _cars!.first : null;
    // Prefer the detailed car object; fall back to the bare car string from
    // the request payload so the draft still prefills brand/model even when
    // GetRequestCar returns nothing (B13).
    final carFields = car != null
        ? _draftCarFields(car)
        : _draftCarFieldsFromTitle(_carTitleFromDetail(null));
    final draft = <String, dynamic>{
      'id': 'spark_draft_${now.microsecondsSinceEpoch}',
      'requestId': requestId,
      'requestNumber': _str('requestNumber'),
      'reportName': _requestReportName(car),
      'reportNumber': '',
      'currentStep': 1,
      'createdAt': _formatRuDate(now.toIso8601String()),
      'lastSavedAtIso': now.toIso8601String(),
      'status': 'in_progress',
      'inspectionCity': _str('city').trim(),
      ...carFields,
    };
    await SparkJoyStorage.upsertDraft(draft);
    return draft;
  }

  /// Builds car fields from a plain «Бренд Модель» string (used when only the
  /// request's bare car string is available, not the detailed object).
  Map<String, dynamic> _draftCarFieldsFromTitle(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return const <String, dynamic>{};
    final parts = clean.split(RegExp(r'\s+'));
    return <String, dynamic>{
      'car': clean,
      if (parts.isNotEmpty) 'brand': parts.first,
      if (parts.length > 1) 'model': parts.sublist(1).join(' '),
    };
  }

  String _requestReportName(Map<String, dynamic>? car) {
    final number = _str('requestNumber').trim();
    final carName = _carTitleFromDetail(car).trim();
    if (number.isNotEmpty && carName.isNotEmpty) {
      return 'Заявка №$number · $carName';
    }
    if (number.isNotEmpty) return 'Заявка №$number';
    if (carName.isNotEmpty) return carName;
    return 'Отчёт по заявке';
  }

  // Brand/model arrive in TWO shapes depending on endpoint: a nested object
  // ({name}/{model|name}) from the detailed GetRequestCar, or a bare string
  // from the list payload. The request card already handles both — these
  // mirror that so the draft prefill never ends up empty (B13: «автомобиль
  // из заявки не подгружается»).
  String _carBrandName(dynamic brand) {
    if (brand is Map) return (brand['name'] ?? '').toString().trim();
    return (brand ?? '').toString().trim();
  }

  String _carModelName(dynamic model) {
    if (model is Map) {
      return (model['model'] ?? model['name'] ?? '').toString().trim();
    }
    return (model ?? '').toString().trim();
  }

  Map<String, dynamic> _draftCarFields(Map<String, dynamic> car) {
    final brandName = _carBrandName(car['brand']);
    final modelName = _carModelName(car['model']);
    final generation = (car['generation'] ?? '').toString().trim();
    final restylings = car['restyling'] ?? car['restylings'];
    var restylingLabel = '';
    if (restylings is List && restylings.isNotEmpty) {
      final first = restylings.first;
      if (first is Map) {
        restylingLabel = (first['restyling'] ?? '').toString().trim();
      } else {
        restylingLabel = first.toString().trim();
      }
    } else if (restylings is String) {
      restylingLabel = restylings.trim();
    }
    final carTitle = [
      brandName,
      modelName,
    ].where((s) => s.isNotEmpty).join(' ');
    final adLink = (car['url'] ?? car['listingUrl'] ?? car['adLink'] ?? '')
        .toString()
        .trim();
    final vin = (car['vin'] ?? '').toString().trim();
    return <String, dynamic>{
      if (brandName.isNotEmpty) 'brand': brandName,
      if (modelName.isNotEmpty) 'model': modelName,
      if (generation.isNotEmpty) 'generation': generation,
      if (restylingLabel.isNotEmpty) 'restyling': restylingLabel,
      if (adLink.isNotEmpty) 'adLink': adLink,
      if (vin.isNotEmpty) 'vin': vin,
      if (carTitle.isNotEmpty) 'car': carTitle,
    };
  }

  String _carTitleFromDetail(Map<String, dynamic>? car) {
    if (car == null) {
      final cars = _request['cars'];
      if (cars is List && cars.isNotEmpty) return cars.first.toString();
      return '';
    }
    return [
      _carBrandName(car['brand']),
      _carModelName(car['model']),
    ].where((s) => s.isNotEmpty).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final status = normalizeRequestStatus(_str('status'));
    final badge = requestStatusBadge(status);
    final number = _str('requestNumber');
    final createdAt = _str('createdAt');
    final dueAt = _str('dueAt');
    final note = _str('note').trim();
    final city = _str('city').trim();
    final budgetFrom = _request['budgetFrom'];
    final budgetTo = _request['budgetTo'];
    final maxMileage = _request['maxMileage'];
    final ownersCount = _request['ownersCount'];
    final history = _historyNewestFirst(
      _request['requestStatusHistories'],
      _requestStatusHistoriesFromCars,
    );
    final canRespond = status == 'created';
    final canAbandon = status == 'paid_escrow' || status == 'in_work';

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: MyText(
          text: number.isEmpty ? 'Заявка' : 'Заявка №$number',
          size: SparkTextSize.titleLg,
          weight: FontWeight.w800,
        ),
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
        ),
      ),
      body: SparkScreenList(
        bottomInset: 24,
        onRefresh: () async {
          await _refreshRequestSnapshot();
          await _loadCars();
        },
        children: [
          SparkCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: SparkSize.icon5xl,
                  height: SparkSize.icon5xl,
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.assignment_ind_outlined,
                    color: kSecondaryColor,
                    size: SparkSize.iconLg,
                  ),
                ),
                const SizedBox(width: SparkSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SparkChip(
                        text: badge.label,
                        background: badge.bg,
                        color: badge.fg,
                      ),
                      const SizedBox(height: SparkSpace.sm),
                      MyText(
                        text: 'Создана: ${_formatRuDateTime(createdAt)}',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                      if (dueAt.isNotEmpty) ...[
                        const SizedBox(height: SparkSpace.xxs),
                        MyText(
                          text: 'Срок: ${_formatRuDate(dueAt)}',
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SparkSectionTitle('Автомобиль', top: SparkSpace.xxl),
          SparkCard(child: _buildCarSection()),
          if (city.isNotEmpty ||
              budgetFrom != null ||
              budgetTo != null ||
              maxMileage != null ||
              ownersCount != null) ...[
            const SparkSectionTitle('Параметры подбора', top: SparkSpace.xxl),
            SparkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (city.isNotEmpty)
                    SparkInfoRow(label: 'Город', value: city),
                  if (budgetFrom != null || budgetTo != null)
                    SparkInfoRow(
                      label: 'Бюджет',
                      value: _formatBudget(budgetFrom, budgetTo),
                    ),
                  if (maxMileage != null)
                    SparkInfoRow(
                      label: 'Макс. пробег',
                      value: '${_formatNumber(maxMileage)} км',
                    ),
                  if (ownersCount != null)
                    SparkInfoRow(
                      label: 'Макс. владельцев',
                      value: ownersCount.toString(),
                    ),
                ],
              ),
            ),
          ],
          // Комментарий заказчика — ключевой контекст для специалиста (что
          // именно проверить). Показываем всегда, с плейсхолдером когда
          // пусто, чтобы исполнитель не гадал, есть ли пожелания (B12).
          const SparkSectionTitle('Комментарий заказчика', top: SparkSpace.xxl),
          SparkCard(
            child: note.isNotEmpty
                ? MyText(text: note, size: SparkTextSize.body, lineHeight: 1.5)
                : const MyText(
                    text:
                        'Заказчик не оставил дополнительных пожеланий по '
                        'осмотру.',
                    size: SparkTextSize.body,
                    color: kGreyColor,
                    lineHeight: 1.5,
                  ),
          ),
          const SparkSectionTitle('История', top: SparkSpace.xxl),
          if (history.isEmpty)
            const SparkCard(
              child: MyText(
                text: 'История пуста',
                size: SparkTextSize.body,
                color: kGreyColor,
              ),
            )
          else
            SparkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < history.length; i++) ...[
                    _HistoryEntry(entry: history[i]),
                    if (i < history.length - 1)
                      const Divider(height: 1, color: kBorderColor),
                  ],
                ],
              ),
            ),
          const SizedBox(height: SparkSpace.xxl),
          if (canRespond) ...[
            SparkPrimaryActionButton(
              label: _actionBusy ? 'Сохраняем...' : 'Принять заявку',
              icon: Icons.check_rounded,
              busy: _actionBusy,
              onTap: _accept,
            ),
            const SizedBox(height: SparkSpace.md),
            OutlinedButton.icon(
              onPressed: _actionBusy ? null : _rejectNewRequest,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Отклонить'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kRedColor,
                minimumSize: const Size(
                  double.infinity,
                  SparkSize.actionHeight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.lg),
                ),
              ),
            ),
          ] else if (canAbandon) ...[
            if (status == 'in_work') ...[
              SparkPrimaryActionButton(
                label: _openingReport ? 'Открываем...' : 'Начать отчёт',
                icon: Icons.edit_note_rounded,
                busy: _openingReport,
                onTap: _openReportForRequest,
              ),
              const SizedBox(height: SparkSpace.md),
            ],
            OutlinedButton.icon(
              onPressed: _actionBusy ? null : _abandonRequest,
              icon: const Icon(Icons.error_outline_rounded),
              label: Text(_actionBusy ? 'Сохраняем...' : 'Отметить неудачной'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kRedColor,
                minimumSize: const Size(
                  double.infinity,
                  SparkSize.actionHeight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.lg),
                ),
              ),
            ),
          ],
          const SizedBox(height: SparkSpace.lg),
        ],
      ),
    );
  }

  Widget _buildCarSection() {
    final rawCarStrings = _request['cars'];
    final carStrings = rawCarStrings is List
        ? rawCarStrings
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[];
    final detailedCars = _cars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detailedCars == null) ...[
          for (final name in carStrings)
            Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    color: kSecondaryColor,
                    size: SparkSize.iconLg,
                  ),
                  const SizedBox(width: SparkSpace.md),
                  Expanded(
                    child: MyText(
                      text: name,
                      size: SparkTextSize.body,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: SparkSpace.md),
          const SizedBox(
            height: SparkSize.spinner,
            width: SparkSize.spinner,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ] else if (_carsError != null) ...[
          SparkHintCard(
            text: _carsError!,
            icon: Icons.error_outline_rounded,
            textColor: kRedColor,
            copyText: _carsError,
          ),
        ] else if (detailedCars.isEmpty) ...[
          const MyText(
            text: 'Детали автомобиля не загружены',
            size: SparkTextSize.body,
            color: kGreyColor,
          ),
        ] else
          for (int i = 0; i < detailedCars.length; i++) ...[
            if (i > 0) const Divider(height: 24, color: kBorderColor),
            _CarDetailBlock(car: detailedCars[i]),
          ],
      ],
    );
  }
}

class _CarDetailBlock extends StatelessWidget {
  const _CarDetailBlock({required this.car});

  final Map<String, dynamic> car;

  String _str(String key) => (car[key] ?? '').toString();

  String get _title {
    final brand = car['brand'];
    final model = car['model'];
    final brandName = (brand is Map) ? (brand['name'] ?? '').toString() : '';
    final modelName = (model is Map)
        ? (model['model'] ?? model['name'] ?? '').toString()
        : '';
    final combined = [
      brandName,
      modelName,
    ].where((s) => s.isNotEmpty).join(' ');
    return combined.isEmpty ? 'Автомобиль' : combined;
  }

  String? get _generationLabel {
    final g = car['generation'];
    if (g is num) return 'Поколение $g';
    if (g is String && g.isNotEmpty) return 'Поколение $g';
    return null;
  }

  List<Map<String, dynamic>> get _restylings {
    final r = car['restylings'] ?? car['restyling'];
    if (r is List) {
      return r
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final sellerPhone = _str('phone').trim();
    final sellerUrl = _str('url').trim();
    final tags = car['tags'];
    final tagList = tags is List
        ? tags.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final gen = _generationLabel;
    final restylings = _restylings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.directions_car_outlined,
              color: kSecondaryColor,
              size: SparkSize.iconLg,
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: MyText(
                text: _title,
                size: SparkTextSize.bodyLg,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (gen != null) ...[
          const SizedBox(height: SparkSpace.xs),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: MyText(
              text: gen,
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ),
        ],
        if (restylings.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.xs),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: MyText(
              text: restylings
                  .map((r) {
                    final name = (r['restyling'] ?? '').toString().trim();
                    final ys = r['yearStart'];
                    final ye = r['yearEnd'];
                    final years = [ys, ye]
                        .where((y) => y != null)
                        .map((y) => y.toString())
                        .join('-');
                    if (name.isEmpty && years.isEmpty) return 'Без рестайлинга';
                    if (years.isEmpty) return name;
                    if (name.isEmpty) return years;
                    return '$name ($years)';
                  })
                  .join(', '),
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ),
        ],
        if (tagList.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.sm),
          Wrap(
            spacing: SparkSpace.xs,
            runSpacing: SparkSpace.xs,
            children: tagList
                .map(
                  (t) => SparkChip(
                    text: t,
                    background: kSecondaryColor.withValues(alpha: 0.1),
                    color: kSecondaryColor,
                  ),
                )
                .toList(),
          ),
        ],
        if (sellerPhone.isNotEmpty || sellerUrl.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          const Divider(height: 1, color: kBorderColor),
          const SizedBox(height: SparkSpace.md),
          if (sellerPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    color: kGreyColor,
                    size: SparkSize.iconSm,
                  ),
                  const SizedBox(width: SparkSpace.sm),
                  MyText(
                    text: sellerPhone,
                    size: SparkTextSize.body,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          if (sellerUrl.isNotEmpty) SparkExternalLinkRow(url: sellerUrl),
        ],
      ],
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final oldStatus = (entry['oldStatus'] ?? '').toString();
    final newStatus = (entry['newStatus'] ?? '').toString();
    final role = (entry['changedByRole'] ?? '').toString();
    final reason = requestHistoryReason((entry['reason'] ?? '').toString());
    final createdAt = (entry['createdAt'] ?? '').toString();
    final badge = requestStatusBadge(newStatus);
    final transition = oldStatus.isEmpty
        ? badge.label
        : '${requestStatusBadge(oldStatus).label} -> ${badge.label}';
    final roleLabel = requestRoleLabel(role);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SparkSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SparkSize.iconLg,
            height: SparkSize.iconLg,
            decoration: BoxDecoration(color: badge.bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(
              requestStatusIcon(newStatus),
              color: badge.fg,
              size: SparkSize.iconSm,
            ),
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MyText(
                  text: transition,
                  size: SparkTextSize.body,
                  weight: FontWeight.w600,
                ),
                if (roleLabel.isNotEmpty || createdAt.isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xxs),
                  MyText(
                    text: [
                      if (roleLabel.isNotEmpty) roleLabel,
                      if (createdAt.isNotEmpty) _formatRuDateTime(createdAt),
                    ].join(' · '),
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                ],
                if (reason.label.isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xs),
                  MyText(
                    text: reason.label,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    lineHeight: 1.4,
                  ),
                ],
                if (reason.comment != null) ...[
                  const SizedBox(height: SparkSpace.xxs),
                  MyText(
                    text: 'Комментарий: ${reason.comment}',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    lineHeight: 1.4,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showNoteSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String actionLabel,
  required IconData actionIcon,
  bool destructive = false,
}) async {
  final controller = TextEditingController();
  try {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.lg),
        ),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: SparkSpace.xxxl,
              right: SparkSpace.xxxl,
              top: SparkSpace.xxxl,
              bottom: media.viewInsets.bottom + SparkSpace.xxxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: title,
                        size: SparkTextSize.titleLg,
                        weight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.md),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: sparkInputDecoration(hint),
                ),
                const SizedBox(height: SparkSpace.xl),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(ctx).pop(controller.text.trim()),
                  icon: Icon(actionIcon),
                  label: Text(actionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: destructive ? kRedColor : kSecondaryColor,
                    foregroundColor: kWhiteColor,
                    minimumSize: const Size(
                      double.infinity,
                      SparkSize.actionHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SparkRadius.lg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

List<Map<String, dynamic>> _historyNewestFirst(dynamic primary, dynamic extra) {
  final byKey = <String, Map<String, dynamic>>{};
  var fallbackIndex = 0;
  for (final source in [primary, extra]) {
    if (source is! List) continue;
    for (final item in source) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      final id = (entry['id'] ?? '').toString().trim();
      final key = id.isNotEmpty
          ? 'id:$id'
          : [
              entry['oldStatus'],
              entry['newStatus'],
              entry['changedByRole'],
              entry['reason'],
              entry['createdAt'],
            ].map((value) => (value ?? '').toString()).join('|');
      byKey[key.isEmpty ? 'fallback:${fallbackIndex++}' : key] = entry;
    }
  }
  final history = byKey.values.toList(growable: false);
  history.sort((a, b) {
    final aT = (a['createdAt'] ?? '').toString();
    final bT = (b['createdAt'] ?? '').toString();
    return bT.compareTo(aT);
  });
  return history;
}

String _formatRuDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
}

String _formatRuDateTime(String iso) {
  final dm = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})',
  ).firstMatch(iso);
  if (dm == null) return _formatRuDate(iso);
  return '${dm.group(3)}.${dm.group(2)}.${dm.group(1)} '
      '${dm.group(4)}:${dm.group(5)}';
}

String _formatBudget(dynamic from, dynamic to) {
  final f = from is num ? from.toInt() : null;
  final t = to is num ? to.toInt() : null;
  if (f != null && t != null) {
    return '${_formatNumber(f)} - ${_formatNumber(t)} ₽';
  }
  if (f != null) return 'от ${_formatNumber(f)} ₽';
  if (t != null) return 'до ${_formatNumber(t)} ₽';
  return '-';
}

String _formatNumber(dynamic v) {
  if (v == null) return '';
  final n = v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
  final s = n.toString();
  final out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

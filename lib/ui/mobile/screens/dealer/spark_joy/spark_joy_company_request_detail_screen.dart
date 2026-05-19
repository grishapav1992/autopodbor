import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_company_specialist_picker.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Детальный экран заявки для роли company.
///
/// Конструктор принимает уже загруженный `initial` snapshot из списка
/// (`Storage.GetRequest`) — мгновенный paint без spinner'а. В фоне
/// дёргается `Storage.GetRequestCar` за детальными авто-полями
/// (телефон продавца, ссылка на объявление, поколение, рестайлинг).
///
class SparkJoyCompanyRequestDetailScreen extends StatefulWidget {
  const SparkJoyCompanyRequestDetailScreen({super.key, required this.initial});

  final Map<String, dynamic> initial;

  @override
  State<SparkJoyCompanyRequestDetailScreen> createState() =>
      _SparkJoyCompanyRequestDetailScreenState();
}

class _SparkJoyCompanyRequestDetailScreenState
    extends State<SparkJoyCompanyRequestDetailScreen> {
  late Map<String, dynamic> _request;
  List<Map<String, dynamic>>? _cars; // null = ещё не загружено
  String? _carsError;
  bool _shareBusy = false;
  bool _actionBusy = false;

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
      final cars = await storage_api.StorageApi.getRequestCars(requestId: id);
      if (!mounted) return;
      setState(() {
        _cars = cars;
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
    final requests = await storage_api.StorageApi.getRequests();
    final next = requests.where((r) => _readInt(r['id']) == id).toList();
    if (!mounted || next.isEmpty) return;
    setState(() => _request = next.first);
  }

  Future<void> _refreshAll() async {
    await _refreshRequestSnapshot();
    await _loadCars();
  }

  int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  int? get _reportId {
    for (final key in const ['reportId', 'report_id', 'specialistReportId']) {
      final parsed = _readInt(_request[key]);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  Future<void> _shareReport() async {
    if (_shareBusy) return;
    HapticFeedback.selectionClick();
    setState(() => _shareBusy = true);
    try {
      var reportId = _reportId;
      var reportNumber = _str('reportNumber').trim();
      if (reportId == null) {
        await _refreshRequestSnapshot();
        if (!mounted) return;
        reportId = _reportId;
        reportNumber = _str('reportNumber').trim();
      }
      if (reportId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reportNumber.isEmpty
                  ? 'Бэкенд пока не вернул ID отчёта для этой заявки'
                  : 'Бэкенд пока не вернул ID отчёта №$reportNumber',
            ),
          ),
        );
        return;
      }
      final generated = await storage_api
          .StorageApi.createSpecialistReportShareUrl(reportId: reportId);
      final url = generated.url.trim();
      if (!mounted) return;
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ссылка не была сгенерирована')),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      await _showShareLinkSheet(url);
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла. Войдите заново.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сгенерировать ссылку')),
      );
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _openShareUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Некорректная ссылка')));
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку')));
  }

  Future<void> _showShareLinkSheet(String url) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(SparkSpace.xl),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(SparkRadius.xl),
              border: Border.all(color: kBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(SparkSpace.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MyText(
                    text: 'Ссылка на отчёт',
                    size: SparkTextSize.title,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: SparkSpace.md),
                  SparkHintCard(text: url, icon: Icons.link_rounded),
                  const SizedBox(height: SparkSpace.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ссылка скопирована'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Копировать'),
                        ),
                      ),
                      const SizedBox(width: SparkSpace.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _openShareUrl(url);
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Открыть'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _canManageAssignment {
    final status = _str('status');
    return status == 'created' || status == 'await_payment';
  }

  bool get _hasAssignedSpecialist {
    final raw = _request['assignedSpecialist'];
    if (raw is Map && raw.isNotEmpty) return true;
    return _readInt(_request['assignedSpecialistId']) != null ||
        _readInt(_request['assignedSpecialistUserId']) != null;
  }

  Future<void> _assignSpecialist() async {
    if (_actionBusy) return;
    final requestId = _requestId;
    if (requestId == null) return;
    final assignee = await showSpecialistPicker(context);
    if (assignee == null || _actionBusy) return;
    HapticFeedback.selectionClick();
    setState(() => _actionBusy = true);
    try {
      final result = await storage_api.StorageApi.assignSpecialist(
        requestId: requestId,
        specialistId: assignee.userId,
      );
      if (!mounted) return;
      setState(() {
        _request['assignedSpecialistId'] = assignee.userId;
        if (result.status.isNotEmpty) _request['status'] = result.status;
      });
      try {
        await _refreshRequestSnapshot();
      } catch (_) {
        // Assignment already succeeded. Keep the optimistic specialist id
        // instead of reporting a false failure because refresh failed.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Назначен специалист: ${assignee.displayName}')),
      );
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла. Войдите заново.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось назначить специалиста: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_actionBusy) return;
    final requestId = _requestId;
    if (requestId == null) return;
    final reason = await _showCancelReasonSheet();
    if (reason == null || _actionBusy) return;
    HapticFeedback.mediumImpact();
    setState(() => _actionBusy = true);
    try {
      final result = await storage_api.StorageApi.cancelRequest(
        requestId: requestId,
        cancelReason: reason,
      );
      if (!mounted) return;
      if (result.status.isNotEmpty) {
        setState(() => _request['status'] = result.status);
      }
      try {
        await _refreshRequestSnapshot();
      } catch (_) {
        // Cancellation already succeeded. A stale history section is less
        // harmful than showing a false negative after the mutation.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заявка отменена')));
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла. Войдите заново.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось отменить заявку: $e')));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<String?> _showCancelReasonSheet() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.lg),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(SparkSpace.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: MyText(
                        text: 'Отменить заявку',
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
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop('canceled_not_signed'),
                  icon: const Icon(Icons.assignment_late_outlined),
                  label: const Text('Договор не подписан'),
                ),
                const SizedBox(height: SparkSpace.md),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(ctx).pop('canceled_signed_unpaid'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Подписан, но не оплачен'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _str('status');
    final badge = requestStatusBadge(status);
    final number = _str('requestNumber');
    final createdAt = _str('createdAt');
    final dueAt = _str('dueAt');
    final note = _str('note').trim();

    final budgetFrom = _request['budgetFrom'];
    final budgetTo = _request['budgetTo'];
    final city = _str('city').trim();
    final maxMileage = _request['maxMileage'];
    final ownersCount = _request['ownersCount'];

    final histories = _request['requestStatusHistories'];
    final history = histories is List
        ? histories
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
        : <Map<String, dynamic>>[];
    // History приходит хронологически от бэка; рендерим newest-first.
    history.sort((a, b) {
      final aT = (a['createdAt'] ?? '').toString();
      final bT = (b['createdAt'] ?? '').toString();
      return bT.compareTo(aT);
    });

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
        onRefresh: _refreshAll,
        children: [
          // ── Header card ─────────────────────────────────────────────
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
                    Icons.assignment_outlined,
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

          // ── Автомобиль ──────────────────────────────────────────────
          const SparkSectionTitle('Автомобиль', top: SparkSpace.xxl),
          SparkCard(child: _buildCarSection()),

          // ── Параметры подбора ───────────────────────────────────────
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

          // ── Заметка ─────────────────────────────────────────────────
          if (note.isNotEmpty) ...[
            const SparkSectionTitle('Заметка', top: SparkSpace.xxl),
            SparkCard(
              child: MyText(
                text: note,
                size: SparkTextSize.body,
                lineHeight: 1.5,
              ),
            ),
          ],

          // ── Специалист ──────────────────────────────────────────────
          const SparkSectionTitle('Специалист', top: SparkSpace.xxl),
          SparkCard(child: _buildSpecialistSection()),

          // ── История ─────────────────────────────────────────────────
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

          // ── Actions ─────────────────────────────────────────────────
          const SizedBox(height: SparkSpace.xxl),
          if (_canManageAssignment) ...[
            OutlinedButton.icon(
              onPressed: _actionBusy ? null : _assignSpecialist,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                _hasAssignedSpecialist
                    ? 'Переназначить специалиста'
                    : 'Назначить специалиста',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  SparkSize.actionHeight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.lg),
                ),
              ),
            ),
            const SizedBox(height: SparkSpace.md),
          ],
          if (status == 'done') ...[
            SparkPrimaryActionButton(
              label: _shareBusy ? 'Генерируем...' : 'Поделиться отчётом',
              icon: Icons.ios_share_rounded,
              busy: _shareBusy,
              onTap: _shareReport,
            ),
            const SizedBox(height: SparkSpace.md),
          ],
          OutlinedButton.icon(
            onPressed: _canManageAssignment && !_actionBusy
                ? _cancelRequest
                : null,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(_actionBusy ? 'Сохраняем...' : 'Отменить заявку'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kRedColor,
              minimumSize: const Size(double.infinity, SparkSize.actionHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
            ),
          ),
          if (!_canManageAssignment)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.sm,
              ),
              child: MyText(
                text: 'Отмена доступна только до оплаты или начала работы.',
                size: SparkTextSize.caption,
                color: kGreyColor,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: SparkSpace.lg),
        ],
      ),
    );
  }

  Widget _buildCarSection() {
    // Из списка приходит `cars: string[]` ("Бренд Модель"); из
    // GetRequestCar — детальные объекты с поколением + рестайлингом +
    // телефоном продавца + URL. Показываем оба слоя: пока детали
    // грузятся — fallback на string-список.
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
          // Грузятся — показываем pre-loaded имена
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
          MyText(
            text: _carsError!,
            size: SparkTextSize.caption,
            color: kRedColor,
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

  Widget _buildSpecialistSection() {
    final raw = _request['assignedSpecialist'];
    final specialist = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final assignedId =
        _readInt(_request['assignedSpecialistId']) ??
        _readInt(_request['assignedSpecialistUserId']) ??
        _readInt(specialist?['id']);
    if (specialist == null && assignedId == null) {
      return const MyText(
        text: 'Специалист не назначен',
        size: SparkTextSize.body,
        color: kGreyColor,
      );
    }

    final firstName = (specialist?['firstName'] ?? '').toString().trim();
    final lastName = (specialist?['lastName'] ?? '').toString().trim();
    final middleName = (specialist?['middleName'] ?? '').toString().trim();
    final fullName = [
      lastName,
      firstName,
      middleName,
    ].where((part) => part.isNotEmpty).join(' ');
    final phone = (specialist?['phone'] ?? '').toString().trim();
    final email = (specialist?['email'] ?? '').toString().trim();
    final city = (specialist?['city'] ?? '').toString().trim();
    final rating = specialist?['rating'];
    final ratingText = rating is num && rating > 0
        ? rating.toStringAsFixed(rating.truncateToDouble() == rating ? 0 : 1)
        : '';
    final avatar = (specialist?['urlAvatar'] ?? '').toString().trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: kSecondaryColor.withValues(alpha: 0.1),
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? const Icon(Icons.person_rounded, color: kSecondaryColor)
              : null,
        ),
        const SizedBox(width: SparkSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: fullName.isEmpty
                    ? 'Специалист #${assignedId ?? ''}'.trim()
                    : fullName,
                size: SparkTextSize.bodyLg,
                weight: FontWeight.w700,
              ),
              if (phone.isNotEmpty || email.isNotEmpty || city.isNotEmpty) ...[
                const SizedBox(height: SparkSpace.xxs),
                MyText(
                  text: [
                    if (city.isNotEmpty) city,
                    if (phone.isNotEmpty) phone,
                    if (email.isNotEmpty) email,
                  ].join(' · '),
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
              ],
              if (ratingText.isNotEmpty) ...[
                const SizedBox(height: SparkSpace.xs),
                SparkChip(
                  text: 'Рейтинг $ratingText',
                  background: kSecondaryColor.withValues(alpha: 0.08),
                  color: kSecondaryColor,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Car detail block ──────────────────────────────────────────────────

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
    final r = car['restylings'];
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
                        .join('–');
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
          if (sellerUrl.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.link_rounded,
                    color: kGreyColor,
                    size: SparkSize.iconSm,
                  ),
                ),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: MyText(
                    text: sellerUrl,
                    size: SparkTextSize.caption,
                    color: kSecondaryColor,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

// ── History entry ────────────────────────────────────────────────────

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final oldStatus = (entry['oldStatus'] ?? '').toString();
    final newStatus = (entry['newStatus'] ?? '').toString();
    final role = (entry['changedByRole'] ?? '').toString();
    final reason = (entry['reason'] ?? '').toString().trim();
    final createdAt = (entry['createdAt'] ?? '').toString();

    final badge = requestStatusBadge(newStatus);
    final transition = oldStatus.isEmpty
        ? badge.label
        : '${requestStatusBadge(oldStatus).label} → ${badge.label}';
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
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xs),
                  MyText(
                    text: reason,
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

// ── Local helpers (date/number formatting) ──────────────────────────

String _formatRuDate(String iso) {
  // ISO 8601 — берём YYYY-MM-DD префикс, переворачиваем.
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
    return '${_formatNumber(f)} – ${_formatNumber(t)} ₽';
  }
  if (f != null) return 'от ${_formatNumber(f)} ₽';
  if (t != null) return 'до ${_formatNumber(t)} ₽';
  return '—';
}

String _formatNumber(dynamic v) {
  if (v == null) return '';
  final n = v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
  // 1000 separators (thin-space) — RU стандарт.
  final s = n.toString();
  final out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

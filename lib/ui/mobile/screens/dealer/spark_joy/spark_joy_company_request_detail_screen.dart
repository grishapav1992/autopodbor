import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_company_specialist_picker.dart';
import 'spark_joy_error_snackbar.dart';
import 'spark_joy_external_link.dart';
import 'spark_joy_request_detail_ui.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_specialist_public_profile_screen.dart';
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
  List<Map<String, dynamic>> _requestStatusHistoriesFromCars = const [];
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
        _carsError = sparkJoyReadableErrorText(
          e,
          fallback: 'Не удалось загрузить детали авто',
        );
      });
    }
  }

  Future<void> _refreshRequestSnapshot() async {
    final id = _requestId;
    if (id == null) return;
    final requests = await storage_api.StorageApi.getAllRequests();
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
    } on storage_api.SessionExpiredException catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось сгенерировать ссылку',
      );
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _openShareUrl(String rawUrl) async {
    // The URL comes from server data (createSpecialistReportShareUrl) —
    // reject anything that isn't http/https with a real host, so a
    // compromised/hijacked backend can't trigger intent:/tel:/javascript:
    // via launchUrl.
    final normalized = sparkNormalizeExternalUrl(rawUrl);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Некорректная ссылка')));
      return;
    }
    final uri = Uri.parse(normalized);
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
    await showAppAdaptiveBottomSheet<void>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xxxl,
              0,
              SparkSpace.xxxl,
              SparkSpace.xxxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppBottomSheetHeader(title: 'Ссылка на отчёт'),
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
                            const SnackBar(content: Text('Ссылка скопирована')),
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
        );
      },
    );
  }

  bool get _canManageAssignment {
    final status = normalizeRequestStatus(_str('status'));
    return status == 'created' || status == 'await_payment';
  }

  int? get _assignedSpecialistId {
    final raw = _request['assignedSpecialist'];
    final specialist = raw is Map ? raw : null;
    return _readInt(_request['assignedSpecialistId']) ??
        _readInt(_request['assignedSpecialistUserId']) ??
        _readInt(specialist?['id']);
  }

  bool get _hasAssignedSpecialist {
    final raw = _request['assignedSpecialist'];
    if (raw is Map && raw.isNotEmpty) return true;
    return _assignedSpecialistId != null;
  }

  /// Публичный профиль назначенного специалиста: payload заявки идёт как
  /// initialProfile (там контакты/город/рейтинг, которых RPC не отдаёт),
  /// `Storage.GetSpecialistProfile` доложит описание услуг.
  Future<void> _openAssignedSpecialistProfile() async {
    final raw = _request['assignedSpecialist'];
    final specialist = raw is Map ? Map<String, dynamic>.from(raw) : null;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoySpecialistPublicProfileScreen(
          specialistId: _assignedSpecialistId,
          initialProfile: specialist,
        ),
      ),
    );
  }

  Future<void> _assignSpecialist() async {
    if (_actionBusy) return;
    final requestId = _requestId;
    if (requestId == null) return;
    final currentAssigneeId = _assignedSpecialistId;
    final assignee = await showSpecialistPicker(
      context,
      currentSpecialistId: currentAssigneeId,
    );
    if (assignee == null || _actionBusy) return;
    if (currentAssigneeId != null && assignee.userId == currentAssigneeId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Этот специалист уже назначен')),
      );
      return;
    }
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
    } on storage_api.SessionExpiredException catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось назначить специалиста',
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_actionBusy) return;
    final requestId = _requestId;
    if (requestId == null) return;
    final reason = cancelReasonForRequestStatus(_str('status'));
    if (reason == null) return;
    final confirmed = await _showCancelConfirmation();
    if (!confirmed || _actionBusy) return;
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
    } on storage_api.SessionExpiredException catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(context, e);
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось отменить заявку',
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<bool> _showCancelConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Отменить заявку?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Не отменять'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Отменить заявку'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final status = normalizeRequestStatus(_str('status'));
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
    final history = _historyNewestFirst(
      _request['requestStatusHistories'],
      _requestStatusHistoriesFromCars,
    );

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: SparkRequestDetailAppBar(
        title: number.isEmpty ? 'Заявка' : 'Заявка №$number',
        subtitle: sparkRequestDetailSubtitle(
          createdAt: createdAt,
          dueAt: dueAt,
        ),
        badge: badge,
      ),
      body: SparkScreenList(
        bottomInset: 24,
        onRefresh: _refreshAll,
        children: [
          // ── Автомобиль ──────────────────────────────────────────────
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
            SparkCard(child: SparkRequestHistoryTimeline(entries: history)),

          // ── Отмена недоступна — поясняем почему ─────────────────────
          if (!_canManageAssignment)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.section,
              ),
              child: MyText(
                text: sparkCancelUnavailableLabel(status),
                size: SparkTextSize.body,
                color: kGreyColor,
                weight: FontWeight.w600,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: SparkSpace.lg),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(status),
    );
  }

  /// Закреплённые внизу действия: для завершённой заявки — «Поделиться
  /// отчётом», для новой/неоплаченной — назначение специалиста + отмена.
  /// Когда действий нет (в работе, отменена, …) — панель не рендерится.
  Widget? _buildBottomBar(String status) {
    final children = <Widget>[];
    if (status == 'done') {
      children.add(
        SparkPrimaryActionButton(
          label: _shareBusy ? 'Генерируем...' : 'Поделиться отчётом',
          icon: Icons.ios_share_rounded,
          busy: _shareBusy,
          onTap: _shareReport,
        ),
      );
    }
    if (_canManageAssignment) {
      children.add(
        SparkPrimaryActionButton(
          label: _actionBusy
              ? 'Сохраняем...'
              : _hasAssignedSpecialist
              ? 'Переназначить специалиста'
              : 'Назначить специалиста',
          icon: Icons.person_add_alt_1_rounded,
          busy: _actionBusy,
          onTap: _assignSpecialist,
        ),
      );
      children.add(const SizedBox(height: SparkSpace.md));
      children.add(
        OutlinedButton.icon(
          onPressed: _actionBusy ? null : _cancelRequest,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Отменить заявку'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kRedColor,
            side: BorderSide(color: kRedColor.withValues(alpha: 0.45)),
            minimumSize: const Size(double.infinity, SparkSize.actionHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SparkRadius.lg),
            ),
          ),
        ),
      );
    }
    if (children.isEmpty) return null;
    return Container(
      color: kPrimaryColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.xxxl,
            SparkSpace.xl,
            SparkSpace.xxxl,
            SparkSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
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
          if (carStrings.isEmpty)
            const Row(
              children: [
                SizedBox(
                  width: SparkSize.iconSm,
                  height: SparkSize.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                SizedBox(width: SparkSpace.md),
                MyText(
                  text: 'Загружаем данные автомобиля…',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
              ],
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
            SparkRequestCarBlock(
              car: detailedCars[i],
              city: _str('city').trim(),
            ),
          ],
      ],
    );
  }

  Widget _buildSpecialistSection() {
    final raw = _request['assignedSpecialist'];
    final specialist = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final assignedId = _assignedSpecialistId;
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

    // Как в макете: тёмный аватар с инициалом, имя + город, справа —
    // квадратные кнопки «позвонить»/«написать» (появляются только когда
    // соответствующий контакт есть в данных). Тап по аватару/имени
    // открывает публичный профиль специалиста; кнопки контактов —
    // отдельные тап-зоны.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openAssignedSpecialistProfile(),
              borderRadius: BorderRadius.circular(SparkRadius.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SparkInitialsAvatar(
                    name: fullName,
                    size: SparkSize.avatarSm,
                    backgroundColor: kSecondaryColor,
                    textColor: kWhiteColor,
                    imageUrl: avatar.isEmpty ? null : avatar,
                  ),
                  const SizedBox(width: SparkSpace.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MyText(
                          text: fullName.isEmpty
                              ? 'Специалист #${assignedId ?? ''}'.trim()
                              : fullName,
                          size: SparkTextSize.title,
                          weight: FontWeight.w700,
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: SparkSpace.xxs),
                          MyText(
                            text: city,
                            size: SparkTextSize.bodyLg,
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
              ),
            ),
          ),
        ),
        if (phone.isNotEmpty) ...[
          const SizedBox(width: SparkSpace.md),
          SparkContactIconButton(
            icon: Icons.call_rounded,
            tooltip: 'Позвонить специалисту',
            onTap: () => sparkLaunchPhone(context, phone),
          ),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(width: SparkSpace.md),
          SparkContactIconButton(
            icon: Icons.mail_rounded,
            tooltip: 'Написать специалисту',
            onTap: () => sparkLaunchEmail(context, email),
          ),
        ],
      ],
    );
  }
}

// ── Local helpers (date/number formatting) ──────────────────────────

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

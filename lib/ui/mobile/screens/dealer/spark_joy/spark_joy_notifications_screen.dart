import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/state/notification_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_public_profile_screen.dart';
import 'spark_joy_legal_labels.dart';
import 'spark_joy_notification_actions.dart';
import 'spark_joy_notification_detail_rows.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Notifications feed — dealer/specialist side.
///
/// Backed by [NotificationController] (HTTP + realtime push). On-screen
/// reactions:
///   • `task` / `invitation` show inline accept / reject buttons that
///     call `Notification.ActionNotification`.
///   • `reminder` / `system` mark themselves read once they are shown.
///   • Pull-to-refresh re-fetches page 1 from the backend.
///
/// Notifications cannot be deleted by the user (per spec); status
/// transitions (`pending` → `accepted` / `rejected` / `read`) are how
/// they "leave" the feed visually.
class SparkJoyNotificationsScreen extends StatefulWidget {
  const SparkJoyNotificationsScreen({super.key, this.onOpenRequest});

  final Future<void> Function(int requestId)? onOpenRequest;

  @override
  State<SparkJoyNotificationsScreen> createState() =>
      _SparkJoyNotificationsScreenState();
}

class _SparkJoyNotificationsScreenState
    extends State<SparkJoyNotificationsScreen> {
  late final NotificationController _controller =
      Get.find<NotificationController>();
  late final ScrollController _scrollController;
  final Set<String> _expandedIds = <String>{};
  final Set<String> _autoReadQueuedIds = <String>{};
  String? _seenMarkerQueuedForId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    // Fire-and-forget — the controller already has page 1 from
    // bootstrap; this just refreshes to pick up anything that arrived
    // while the screen was off-screen.
    _controller.reload();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 480) return;
    _controller.loadMore();
  }

  void _scheduleAutoMarkRead(List<BackendNotification> items) {
    final ids = items
        .where(
          (n) =>
              !n.type.isInteractive &&
              n.status == NotificationStatus.pending &&
              !_autoReadQueuedIds.contains(n.id),
        )
        .map((n) => n.id)
        .toList(growable: false);
    if (ids.isEmpty) return;
    _autoReadQueuedIds.addAll(ids);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final id in ids) {
        _controller.markRead(id).catchError((_) {
          _autoReadQueuedIds.remove(id);
        });
      }
    });
  }

  void _scheduleMarkLatestSeen(List<BackendNotification> visibleItems) {
    if (visibleItems.isEmpty) return;
    final latest = visibleItems.first;
    if (_seenMarkerQueuedForId == latest.id) return;
    final latestId = latest.id;
    _seenMarkerQueuedForId = latestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.markLatestNotificationSeen().catchError((_) {
        if (_seenMarkerQueuedForId == latestId) {
          _seenMarkerQueuedForId = null;
        }
      });
    });
  }

  void _toggleDetails(BackendNotification n) {
    setState(() {
      if (!_expandedIds.add(n.id)) {
        _expandedIds.remove(n.id);
      }
    });
  }

  Future<void> _openRequest(BackendNotification n) async {
    final requestId = n.requestId;
    if (requestId == null || widget.onOpenRequest == null) return;
    await widget.onOpenRequest!(requestId);
  }

  /// Company a notification points at: an explicit `companyId` in the
  /// payload, else the sender of an invitation (the inviting company is the
  /// sender). Used to offer «Открыть компанию» (B6).
  int? _companyIdForNotification(BackendNotification n) {
    final raw = n.payload['companyId'] ?? n.payload['company_id'];
    final fromPayload = raw is int ? raw : int.tryParse('${raw ?? ''}');
    if (fromPayload != null && fromPayload > 0) return fromPayload;
    if (n.type == NotificationType.invitation && (n.senderId ?? 0) > 0) {
      return n.senderId;
    }
    return null;
  }

  void _openCompany(BackendNotification n) {
    final companyId = _companyIdForNotification(n);
    if (companyId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SparkJoyCompanyPublicProfileScreen(companyId: companyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = _controller.loading.value;
      final items = _controller.items;
      // Конвертер (api_cloud_converter_search) — внутренний инструмент
      // идентификации, не материал проверки: его уведомления в ленте прячем
      // (как он скрыт и из сводки отчёта). Прочитанными помечаем по ПОЛНОМУ
      // списку (ниже), чтобы счётчик непрочитанных оставался консистентным.
      final visible = items.where((n) => !n.isLegalConverter).toList();
      if (loading && items.isEmpty) {
        return const SparkLoadingState(message: 'Загрузка уведомлений...');
      }
      if (visible.isEmpty) {
        return RefreshIndicator(
          onRefresh: _controller.reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SparkEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Нет уведомлений',
                subtitle:
                    'Здесь появятся сообщения о назначениях, приёмке и статусах отчётов.',
                topPadding: SparkSpace.xxxl,
              ),
            ],
          ),
        );
      }
      final groups = _groupByDate(visible);
      _scheduleAutoMarkRead(items.toList());
      _scheduleMarkLatestSeen(visible);
      return SparkScreenList(
        controller: _scrollController,
        onRefresh: _controller.reload,
        bottomInset: 56,
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: SparkSpace.md,
                bottom: SparkSpace.sm,
              ),
              child: MyText(
                text: group.label.toUpperCase(),
                size: SparkTextSize.chip,
                weight: FontWeight.w700,
                color: kGreyColor,
              ),
            ),
            for (final n in group.items)
              _NotificationCard(
                notification: n,
                expanded: _expandedIds.contains(n.id),
                onTap: () => _toggleDetails(n),
                onOpenRequest:
                    n.requestId != null && widget.onOpenRequest != null
                    ? () => _openRequest(n)
                    : null,
                onOpenCompany: _companyIdForNotification(n) != null
                    ? () => _openCompany(n)
                    : null,
              ),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: SparkSpace.lg),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kSecondaryColor,
                  ),
                ),
              ),
            ),
          const SizedBox(height: SparkSpace.xl),
        ],
      );
    });
  }

  /// Groups notifications into ordered buckets: Сегодня, Вчера, Ранее.
  List<_NotificationGroup> _groupByDate(List<BackendNotification> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final todayItems = <BackendNotification>[];
    final yesterdayItems = <BackendNotification>[];
    final earlierItems = <BackendNotification>[];
    final sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final n in sorted) {
      final localDate = n.createdAt.toLocal();
      final d = DateTime(localDate.year, localDate.month, localDate.day);
      if (d == today) {
        todayItems.add(n);
      } else if (d == yesterday) {
        yesterdayItems.add(n);
      } else {
        earlierItems.add(n);
      }
    }
    return <_NotificationGroup>[
      if (todayItems.isNotEmpty)
        _NotificationGroup(label: 'Сегодня', items: todayItems),
      if (yesterdayItems.isNotEmpty)
        _NotificationGroup(label: 'Вчера', items: yesterdayItems),
      if (earlierItems.isNotEmpty)
        _NotificationGroup(label: 'Ранее', items: earlierItems),
    ];
  }
}

class _NotificationGroup {
  const _NotificationGroup({required this.label, required this.items});

  final String label;
  final List<BackendNotification> items;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.expanded,
    required this.onTap,
    this.onOpenRequest,
    this.onOpenCompany,
  });

  final BackendNotification notification;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onOpenRequest;
  final VoidCallback? onOpenCompany;

  _TypeStyle _styleForType(NotificationType type) {
    switch (type) {
      case NotificationType.task:
        return _TypeStyle(
          icon: Icons.assignment_outlined,
          color: kSecondaryColor,
        );
      case NotificationType.invitation:
        return _TypeStyle(icon: Icons.group_add_outlined, color: kBlueColor);
      case NotificationType.reminder:
        return _TypeStyle(icon: Icons.schedule_rounded, color: kYellowColor);
      case NotificationType.system:
        return _TypeStyle(icon: Icons.info_outline_rounded, color: kGreyColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleForType(notification.type);
    final unread = notification.status == NotificationStatus.pending;
    final title = _notificationDisplayTitle(notification);
    final body = _notificationDisplayBody(notification);
    return SparkListCard(
      // Legal-уведомления самодостаточны и не разворачиваются → тап-ноль,
      // чтобы не было ripple/лишних rebuild без видимого эффекта.
      onTap: notification.isLegalReview ? null : onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.lg,
      ),
      backgroundColor: unread
          ? style.color.withValues(alpha: 0.04)
          : kWhiteColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(style.icon, size: 20, color: style.color),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: MyText(
                            text: title,
                            size: SparkTextSize.body,
                            weight: unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: SparkSpace.sm),
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: kSecondaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (body.isNotEmpty)
                      MyText(
                        text: body,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                        lineHeight: 1.35,
                        maxLines: 3,
                        textOverflow: TextOverflow.ellipsis,
                      ),
                    MyText(
                      text: _formatRelative(notification.createdAt),
                      size: SparkTextSize.chip,
                      color: kGreyColor,
                      paddingTop: SparkSpace.sm,
                    ),
                    // Legal-уведомления самодостаточны (коротко всё сказано) —
                    // у них «Подробнее»/разворота нет.
                    if (!notification.isLegalReview)
                      MyText(
                        text: expanded ? 'Свернуть' : 'Подробнее',
                        size: SparkTextSize.chip,
                        weight: FontWeight.w700,
                        color: kSecondaryColor,
                        paddingTop: SparkSpace.sm,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!notification.isLegalReview)
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _NotificationDetails(
                notification: notification,
                onOpenRequest: onOpenRequest,
                onOpenCompany: onOpenCompany,
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeOutCubic,
            ),
          if (notification.isInteractivePending)
            SparkJoyNotificationActions(notification: notification),
        ],
      ),
    );
  }
}

// ── ApiCloud legal-review (system) уведомления: короткий читаемый текст ──────
// Бэк шлёт техничный title («…завершена со статусом: not_found») и сырой
// payload. Здесь переписываем в человеческий вид. Ссылок на черновик/отчёт нет
// (в payload нет идентификатора отчёта). Ярлыки проверок — общий
// `sparkJoyLegalCheckTypeLabel` (spark_joy_legal_labels.dart), он же в шаге.
String _notificationDisplayTitle(BackendNotification n) =>
    n.isLegalReview ? _legalNotificationTitle(n) : n.title;

String _notificationDisplayBody(BackendNotification n) =>
    n.isLegalReview ? _legalNotificationSubtitle(n) : (n.body ?? '');

// Статусы ApiCloud-результата. Бэк шлёт success/not_found/error; синонимы — на
// случай расширения протокола, чтобы негативный исход не подавался как
// благополучное «завершена» (#5).
const Set<String> _legalSuccessStatuses = {'success', 'ok', 'found', 'done'};
const Set<String> _legalErrorStatuses = {
  'error',
  'failed',
  'failure',
  'timeout',
  'timed_out',
};

String _legalNotificationTitle(BackendNotification n) {
  final label = sparkJoyLegalCheckTypeLabel(n.legalCheckType);
  final status = n.legalStatus;
  if (status == 'not_found') return 'Проверка «$label»: данных не найдено';
  if (_legalErrorStatuses.contains(status)) {
    return 'Проверка «$label» не выполнилась';
  }
  if (_legalSuccessStatuses.contains(status)) {
    return 'Проверка «$label» выполнена';
  }
  return 'Проверка «$label» завершена';
}

String _legalNotificationSubtitle(BackendNotification n) {
  // Контекст авто (если есть) сохраняем при любом статусе (#6); для ошибки
  // добавляем причину — иначе она нигде не видна, разворот скрыт (#1).
  final parts = <String>[];
  final vin = (n.payload['vehicleVin'] ?? '').toString().trim();
  final gos = (n.payload['vehicleGosNumber'] ?? '').toString().trim();
  if (vin.isNotEmpty) {
    parts.add('VIN $vin');
  } else if (gos.isNotEmpty) {
    parts.add('Госномер $gos');
  }
  if (_legalErrorStatuses.contains(n.legalStatus)) {
    final err = (n.payload['errorMessage'] ?? '').toString().trim();
    if (err.isNotEmpty) parts.add(err);
  }
  return parts.join(' · ');
}

class _NotificationDetails extends StatelessWidget {
  const _NotificationDetails({
    required this.notification,
    required this.onOpenRequest,
    this.onOpenCompany,
  });

  final BackendNotification notification;
  final VoidCallback? onOpenRequest;
  final VoidCallback? onOpenCompany;

  @override
  Widget build(BuildContext context) {
    final rows = notificationDetailRows(notification);
    return Padding(
      padding: const EdgeInsets.only(top: SparkSpace.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SparkSpace.lg),
        decoration: BoxDecoration(
          color: kLightGreyColor,
          borderRadius: BorderRadius.circular(SparkRadius.md),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MyText(
              text: 'Детали уведомления',
              size: SparkTextSize.caption,
              weight: FontWeight.w700,
              color: kGreyColor,
            ),
            const SizedBox(height: SparkSpace.sm),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: SparkSpace.xs),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: SparkTextSize.caption,
                      height: 1.35,
                      color: kBlackColor,
                    ),
                    children: [
                      TextSpan(
                        text: '${row.label}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kGreyColor,
                        ),
                      ),
                      TextSpan(text: row.value),
                    ],
                  ),
                ),
              ),
            if (onOpenRequest != null) ...[
              const SizedBox(height: SparkSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(SparkRadius.pill),
                  onTap: onOpenRequest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.md,
                      vertical: SparkSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: kSecondaryColor,
                      borderRadius: BorderRadius.circular(SparkRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: kWhiteColor,
                        ),
                        SizedBox(width: SparkSpace.xs),
                        MyText(
                          text: 'Открыть заявку',
                          size: SparkTextSize.chip,
                          weight: FontWeight.w700,
                          color: kWhiteColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (onOpenCompany != null) ...[
              const SizedBox(height: SparkSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: BorderRadius.circular(SparkRadius.pill),
                  onTap: onOpenCompany,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.md,
                      vertical: SparkSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: kSecondaryColor,
                      borderRadius: BorderRadius.circular(SparkRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 16,
                          color: kWhiteColor,
                        ),
                        SizedBox(width: SparkSpace.xs),
                        MyText(
                          text: 'Открыть компанию',
                          size: SparkTextSize.chip,
                          weight: FontWeight.w700,
                          color: kWhiteColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeStyle {
  const _TypeStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Human-readable elapsed time for a notification.
String _formatRelative(DateTime ts) {
  final local = ts.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inSeconds < 45) return 'только что';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${_pluralMin(m)} назад';
  }
  if (diff.inHours < 24 && now.day == local.day) {
    final h = diff.inHours;
    return '$h ${_pluralHour(h)} назад';
  }
  final yesterday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 1));
  final tsDate = DateTime(local.year, local.month, local.day);
  if (tsDate == yesterday) {
    return 'вчера, ${_hhmm(local)}';
  }
  return '${_dd(local.day)}.${_dd(local.month)}.${local.year}, ${_hhmm(local)}';
}

String _pluralMin(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'минуту';
  if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
    return 'минуты';
  }
  return 'минут';
}

String _pluralHour(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'час';
  if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) {
    return 'часа';
  }
  return 'часов';
}

String _dd(int n) => n < 10 ? '0$n' : '$n';
String _hhmm(DateTime ts) => '${_dd(ts.hour)}:${_dd(ts.minute)}';

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

/// Notifications feed — dealer/specialist side (design «2a»).
///
/// Backed by [NotificationController] (HTTP + realtime push). On-screen
/// reactions:
///   • `task` / `invitation` show inline accept / reject buttons that
///     call `Notification.ActionNotification`.
///   • `reminder` / `system` mark themselves read once they are shown.
///   • Pull-to-refresh re-fetches page 1 from the backend.
///
/// Layout (variant 2a): compact cards with a type-tinted icon, unread items on
/// a light-blue fill with a navy dot, single cards expand inline details, and
/// repeated read notifications collapse into a single group «stack» with a
/// count badge (see [buildNotificationFeedEntries]).
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
  final Set<String> _expandedGroups = <String>{};
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

  void _toggleGroup(String key) {
    setState(() {
      if (!_expandedGroups.add(key)) {
        _expandedGroups.remove(key);
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
            for (final entry in buildNotificationFeedEntries(group.items))
              _feedEntryWidget(entry),
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

  Widget _feedEntryWidget(NotificationFeedEntry entry) {
    if (entry is NotificationGroupEntry) {
      // Идентичность разворота — по id новейшего члена, а НЕ по groupKey:
      // ключ не содержит даты, поэтому одинаковые группы в разных бакетах
      // («Сегодня»/«Вчера») делили бы одно состояние и разворачивались вместе.
      final groupUiId = entry.newest.id;
      return _NotificationGroupCard(
        entry: entry,
        expanded: _expandedGroups.contains(groupUiId),
        onToggle: () => _toggleGroup(groupUiId),
        style: _styleForType(entry.newest.type),
        onOpenRequest: widget.onOpenRequest == null
            ? null
            : (n) => _openRequest(n),
      );
    }
    final n = (entry as NotificationSingleEntry).notification;
    return _NotificationCard(
      notification: n,
      expanded: _expandedIds.contains(n.id),
      onTap: () => _toggleDetails(n),
      onOpenRequest: n.requestId != null && widget.onOpenRequest != null
          ? () => _openRequest(n)
          : null,
      onOpenCompany: _companyIdForNotification(n) != null
          ? () => _openCompany(n)
          : null,
    );
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

// ── Feed entries: single card vs collapsed group «stack» (design 2a) ─────────

/// Minimum number of same-kind read notifications in a date bucket before they
/// collapse into a single group «stack». Below this the items render as
/// individual cards.
const int _kGroupThreshold = 3;

/// Light-blue fill for unread cards (design 2a). Distinct from the per-type
/// tint used for the icon so unread state reads at a glance regardless of type.
const Color _kUnreadCardBg = Color(0xFFEFF3F8);

/// One rendered row of the feed: either a standalone notification card
/// ([NotificationSingleEntry]) or a collapsed group of repeated notifications
/// ([NotificationGroupEntry]).
sealed class NotificationFeedEntry {
  const NotificationFeedEntry();
}

class NotificationSingleEntry extends NotificationFeedEntry {
  const NotificationSingleEntry(this.notification);

  final BackendNotification notification;
}

class NotificationGroupEntry extends NotificationFeedEntry {
  const NotificationGroupEntry({required this.key, required this.items});

  /// Grouping key (see [notificationGroupKey]).
  final String key;

  /// Members, newest-first (same order as the source bucket).
  final List<BackendNotification> items;

  int get count => items.length;
  BackendNotification get newest => items.first;
}

/// Whether [n] may be folded into a group. Only READ, non-interactive items
/// WITHOUT free-text detail are groupable:
///   • unread items and pending invitations/tasks (accept/reject) always
///     deserve an individual card and must never be hidden inside a stack;
///   • an item carrying a comment / reason must stay expandable — that text
///     lives only in the «Подробнее» panel, so folding it would make the
///     specialist's rejection reason unreachable in-app (the mockup keeps such
///     items as standalone cards for the same reason).
@visibleForTesting
bool notificationIsGroupable(BackendNotification n) =>
    !n.isInteractivePending &&
    n.status != NotificationStatus.pending &&
    !_notificationHasReadableComment(n);

/// True when [n]'s payload carries user-facing free text (comment / reason)
/// that is only surfaced in the expanded details panel.
bool _notificationHasReadableComment(BackendNotification n) {
  for (final key in const ['note', 'comment', 'message', 'reason']) {
    final v = n.payload[key];
    if (v != null && v.toString().trim().isNotEmpty) return true;
  }
  return false;
}

/// Grouping key for [n]: notification type plus its title with the variable
/// parts (request codes `REQ-…`, `№…` tokens and bare numbers) stripped, so
/// «Специалист отклонил заявку REQ-A225453» and «…REQ-A894735» share a key.
@visibleForTesting
String notificationGroupKey(BackendNotification n) {
  final base = _notificationDisplayTitle(n)
      .replaceAll(RegExp(r'REQ-[A-Za-z0-9]+'), '')
      .replaceAll(RegExp(r'№\s*\S+'), '')
      .replaceAll(RegExp(r'\d+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  return '${n.type.name}|$base';
}

/// Folds a single date bucket (newest-first) into feed entries. Any group key
/// with at least [threshold] groupable members becomes a [NotificationGroupEntry]
/// positioned where its newest member sits; everything else stays a
/// [NotificationSingleEntry] in place. Chronological order is preserved.
@visibleForTesting
List<NotificationFeedEntry> buildNotificationFeedEntries(
  List<BackendNotification> bucket, {
  int threshold = _kGroupThreshold,
}) {
  final counts = <String, int>{};
  for (final n in bucket) {
    if (notificationIsGroupable(n)) {
      final k = notificationGroupKey(n);
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  final emitted = <String>{};
  final entries = <NotificationFeedEntry>[];
  for (final n in bucket) {
    if (notificationIsGroupable(n)) {
      final k = notificationGroupKey(n);
      if ((counts[k] ?? 0) >= threshold) {
        if (emitted.add(k)) {
          entries.add(
            NotificationGroupEntry(
              key: k,
              items: bucket
                  .where(
                    (m) =>
                        notificationIsGroupable(m) &&
                        notificationGroupKey(m) == k,
                  )
                  .toList(growable: false),
            ),
          );
        }
        continue;
      }
    }
    entries.add(NotificationSingleEntry(n));
  }
  return entries;
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
      backgroundColor: unread ? _kUnreadCardBg : kWhiteColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeAvatar(style: style),
              const SizedBox(width: SparkSpace.lg),
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

/// Collapsed «stack» of repeated notifications (design 2a). Tapping the card
/// toggles an inline list of the members; while collapsed, two thin offset bars
/// beneath the card render the paper-stack effect.
class _NotificationGroupCard extends StatelessWidget {
  const _NotificationGroupCard({
    required this.entry,
    required this.expanded,
    required this.onToggle,
    required this.style,
    required this.onOpenRequest,
  });

  final NotificationGroupEntry entry;
  final bool expanded;
  final VoidCallback onToggle;
  final _TypeStyle style;
  final void Function(BackendNotification n)? onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final newest = entry.newest;
    final title = _groupDisplayTitle(newest);
    final subtitle =
        '${_groupRowLabel(newest)} и ещё ${entry.count - 1} · '
        '${_groupTimeRange(entry.items)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SparkListCard(
          bottom: expanded ? SparkSpace.lg : 0,
          onTap: onToggle,
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xl,
            vertical: SparkSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeAvatar(style: style),
                  const SizedBox(width: SparkSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MyText(
                                text: title,
                                size: SparkTextSize.body,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: SparkSpace.sm),
                            _CountBadge(count: entry.count),
                          ],
                        ),
                        MyText(
                          text: subtitle,
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                          paddingTop: SparkSpace.xxs,
                          lineHeight: 1.35,
                          maxLines: 2,
                          textOverflow: TextOverflow.ellipsis,
                        ),
                        MyText(
                          text: expanded
                              ? 'Свернуть'
                              : 'Показать все ${entry.count}',
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
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(top: SparkSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final n in entry.items)
                        _GroupRow(
                          notification: n,
                          onOpen: (n.requestId != null && onOpenRequest != null)
                              ? () => onOpenRequest!(n)
                              : null,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!expanded) ...[
          const _StackShadowBar(inset: SparkSpace.lg, radius: 12),
          const _StackShadowBar(inset: 22, radius: 10),
          const SizedBox(height: SparkSpace.lg),
        ],
      ],
    );
  }
}

/// One member line inside an expanded group: short request/notification label,
/// time and (when the notification points at a request) an open affordance.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.notification, this.onOpen});

  final BackendNotification notification;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: SparkSpace.md),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kGreyColor2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: MyText(
                text: _groupRowLabel(notification),
                size: SparkTextSize.caption,
                weight: FontWeight.w600,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: SparkSpace.sm),
            MyText(
              text: _hhmm(notification.createdAt.toLocal()),
              size: SparkTextSize.chip,
              color: kGreyColor,
            ),
            if (onOpen != null) ...[
              const SizedBox(width: SparkSpace.sm),
              const Icon(
                Icons.open_in_new_rounded,
                size: SparkSize.iconXs,
                color: kSecondaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin offset bar drawn beneath a collapsed group to suggest a stack of cards.
class _StackShadowBar extends StatelessWidget {
  const _StackShadowBar({required this.inset, required this.radius});

  final double inset;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      margin: EdgeInsets.symmetric(horizontal: inset),
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: const Border(
          left: BorderSide(color: kBorderColor),
          right: BorderSide(color: kBorderColor),
          bottom: BorderSide(color: kBorderColor),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
      ),
    );
  }
}

/// Pill count badge shown on a group card.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: kChipNewBg,
        borderRadius: BorderRadius.circular(SparkRadius.pill),
      ),
      child: MyText(
        text: '$count',
        size: SparkTextSize.chip,
        weight: FontWeight.w700,
        color: kChipNewFg,
      ),
    );
  }
}

/// Round type-tinted icon shared by single and group cards (design 2a: 34px).
class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.style});

  final _TypeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SparkSize.iconState,
      height: SparkSize.iconState,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(style.icon, size: SparkSize.iconMd, color: style.color),
    );
  }
}

_TypeStyle _styleForType(NotificationType type) {
  switch (type) {
    case NotificationType.task:
      return _TypeStyle(icon: Icons.assignment_outlined, color: kSecondaryColor);
    case NotificationType.invitation:
      return _TypeStyle(icon: Icons.group_add_outlined, color: kBlueColor);
    case NotificationType.reminder:
      return _TypeStyle(icon: Icons.schedule_rounded, color: kYellowColor);
    case NotificationType.system:
      return _TypeStyle(icon: Icons.info_outline_rounded, color: kGreyColor);
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

// ── Group labels ────────────────────────────────────────────────────────────

/// Header title for a group: the newest member's display title with its
/// request code / `№…` token stripped (case preserved), e.g. «Специалист
/// отклонил заявку REQ-A225453» → «Специалист отклонил заявку».
String _groupDisplayTitle(BackendNotification n) {
  final title = _notificationDisplayTitle(n);
  final stripped = title
      .replaceAll(RegExp(r'\s*REQ-[A-Za-z0-9]+'), '')
      .replaceAll(RegExp(r'\s*№\s*\S+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return stripped.isEmpty ? title : stripped;
}

/// Short identifier for a group member row / the subtitle lead: the request
/// code from the title, else `№<requestNumber>`, else the display title.
String _groupRowLabel(BackendNotification n) {
  final title = _notificationDisplayTitle(n);
  final match = RegExp(r'REQ-[A-Za-z0-9]+').firstMatch(title);
  if (match != null) return match.group(0)!;
  final number = n.requestNumber;
  if (number.isNotEmpty) return '№$number';
  return title;
}

/// Compact time span of a group's members: `HH:MM–HH:MM` within one day,
/// otherwise `dd.MM–dd.MM`.
String _groupTimeRange(List<BackendNotification> items) {
  final times = items.map((n) => n.createdAt.toLocal()).toList()..sort();
  final a = times.first;
  final b = times.last;
  final sameDay = a.year == b.year && a.month == b.month && a.day == b.day;
  if (sameDay) {
    return a == b ? _hhmm(a) : '${_hhmm(a)}–${_hhmm(b)}';
  }
  return '${_dd(a.day)}.${_dd(a.month)}–${_dd(b.day)}.${_dd(b.month)}';
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
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: SparkSpace.xs),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: SparkTextSize.caption,
                      height: 1.5,
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

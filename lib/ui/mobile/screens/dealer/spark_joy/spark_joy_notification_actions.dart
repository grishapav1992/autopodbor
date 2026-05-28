import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/state/notification_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_request_refresh_bus.dart';
import 'spark_joy_tokens.dart';

/// Accept / Reject row attached to interactive notification cards
/// (`task` and `invitation`). Hidden once the notification is no
/// longer in `pending` status (server moved it to accepted/rejected).
///
/// On accept of a `task`, the backend creates a request and returns
/// `requestId`+`requestNumber` — the post-action snack hints at this so
/// the user knows where to look. We don't auto-navigate (the dealer is
/// browsing notifications, not picking up a request right now).
///
/// On accept of an `invitation`, the backend joins the user to a
/// company and returns `companyId`. UI shows a confirmation snack.
class SparkJoyNotificationActions extends StatefulWidget {
  const SparkJoyNotificationActions({super.key, required this.notification});

  final BackendNotification notification;

  @override
  State<SparkJoyNotificationActions> createState() =>
      _SparkJoyNotificationActionsState();
}

class _SparkJoyNotificationActionsState
    extends State<SparkJoyNotificationActions> {
  bool _busy = false;

  Future<void> _runAction(NotificationAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await Get.find<NotificationController>().action(
        notificationId: widget.notification.id,
        action: action,
      );
      if (result.isOk && widget.notification.type == NotificationType.task) {
        SparkJoyRequestRefreshBus.notifyChanged();
      }
      if (!mounted) return;
      _showResultFeedback(action, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kRedColor,
          content: Text('Не удалось выполнить действие: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResultFeedback(
    NotificationAction action,
    NotificationActionResult result,
  ) {
    if (!result.isOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kRedColor,
          content: Text(result.error ?? 'Действие не выполнено'),
        ),
      );
      return;
    }
    String message;
    if (action == NotificationAction.reject) {
      message = 'Отклонено';
    } else if (widget.notification.type == NotificationType.task &&
        result.requestNumber != null) {
      message = 'Принято — заявка №${result.requestNumber}';
    } else if (widget.notification.type == NotificationType.invitation) {
      message = 'Вы присоединились к компании';
    } else {
      message = 'Принято';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: kGreenColor, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notification.status != NotificationStatus.pending) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: SparkSpace.md),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Принять',
              icon: Icons.check_rounded,
              busy: _busy,
              variant: _ActionVariant.primary,
              onTap: () => _runAction(NotificationAction.accept),
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          Expanded(
            child: _ActionButton(
              label: 'Отклонить',
              icon: Icons.close_rounded,
              busy: _busy,
              variant: _ActionVariant.secondary,
              onTap: () => _runAction(NotificationAction.reject),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionVariant { primary, secondary }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.variant,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final _ActionVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _ActionVariant.primary;
    final fg = isPrimary ? kWhiteColor : kRedColor;
    final bg = isPrimary ? kSecondaryColor : kRedColor.withValues(alpha: 0.08);
    final border = isPrimary
        ? null
        : Border.all(color: kRedColor.withValues(alpha: 0.35));
    return Opacity(
      opacity: busy ? 0.6 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(SparkRadius.lg),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(SparkRadius.lg),
          child: Container(
            height: SparkSize.actionHeightSm,
            padding: const EdgeInsets.symmetric(horizontal: SparkSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SparkRadius.lg),
              border: border,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: SparkSize.iconMd),
                const SizedBox(width: SparkSpace.xs),
                MyText(
                  text: label,
                  size: SparkTextSize.body,
                  color: fg,
                  weight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

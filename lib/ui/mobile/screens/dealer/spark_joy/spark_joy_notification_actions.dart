import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/state/notification_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_error_snackbar.dart';
import 'spark_joy_profile_refresh_bus.dart';
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
      // «Уже обработано» — тоже применённое действие (первый запрос дошёл,
      // ответ потерялся): для task заявка создана, для invitation компания
      // привязана — refresh-басам это так же важно, как свежий успех.
      final processed = result.isOk || result.isAlreadyProcessed;
      if (processed && widget.notification.type == NotificationType.task) {
        SparkJoyRequestRefreshBus.notifyChanged();
      }
      // Accepting a staff invite changes the user's company/role — refresh
      // the profile (linked company) and the shell nav immediately (B7).
      final acceptedIntoCompany =
          widget.notification.type == NotificationType.invitation &&
          ((result.isOk && action == NotificationAction.accept) ||
              (result.isAlreadyProcessed &&
                  result.status == NotificationStatus.accepted));
      if (acceptedIntoCompany) {
        SparkJoyProfileRefreshBus.notifyChanged();
      }
      if (!mounted) return;
      _showResultFeedback(action, result);
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: action == NotificationAction.accept
            ? 'Не удалось принять'
            : 'Не удалось отклонить',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResultFeedback(
    NotificationAction action,
    NotificationActionResult result,
  ) {
    if (result.isAlreadyProcessed || result.isGoneOnServer) {
      // Не провал текущего тапа, а запоздалая правда о прошлом действии —
      // контроллер уже обновил карточку до фактического статуса. Нейтральный
      // снекбар вместо красной ошибки.
      final isInvite =
          widget.notification.type == NotificationType.invitation;
      final message = switch (result.status) {
        NotificationStatus.accepted => isInvite
            ? 'Приглашение уже принято — вы в компании'
            : 'Уже принято',
        NotificationStatus.rejected => isInvite
            ? 'Приглашение уже отклонено'
            : 'Уже отклонено',
        NotificationStatus.expired => 'Срок действия оповещения истёк',
        _ => result.isGoneOnServer
            ? 'Оповещение больше недоступно'
            : 'Оповещение уже было обработано ранее',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!result.isOk) {
      // Серверный отказ: через общий классификатор — читаемый текст, код для
      // поддержки в копируемом блоке, кнопка «Скопировать». Упаковка в
      // Exception с именем метода повторяет формат app-level ошибок _postRpc,
      // чтобы метод попал в support-текст.
      showSparkJoyErrorSnackBar(
        context,
        Exception('Notification.ActionNotification: ${result.error}'),
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
      child: _busy
          ? const _ActionProgress()
          : Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Принять',
                    icon: Icons.check_rounded,
                    variant: _ActionVariant.primary,
                    onTap: () => _runAction(NotificationAction.accept),
                  ),
                ),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: _ActionButton(
                    label: 'Отклонить',
                    icon: Icons.close_rounded,
                    variant: _ActionVariant.secondary,
                    onTap: () => _runAction(NotificationAction.reject),
                  ),
                ),
              ],
            ),
    );
  }
}

/// In-flight placeholder shown while accept/reject is processing — makes it
/// obvious the tap registered and the buttons aren't "stuck" (#5).
class _ActionProgress extends StatelessWidget {
  const _ActionProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SparkSize.actionHeightSm,
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kSecondaryColor,
            ),
          ),
          SizedBox(width: SparkSpace.sm),
          MyText(
            text: 'Обрабатываем…',
            size: SparkTextSize.body,
            color: kGreyColor,
            weight: FontWeight.w600,
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
    required this.variant,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(SparkRadius.lg),
      child: InkWell(
        onTap: onTap,
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
    );
  }
}

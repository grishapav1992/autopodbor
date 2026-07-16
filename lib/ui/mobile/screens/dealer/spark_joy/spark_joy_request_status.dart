import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';

/// Status enum заявки (`Storage.GetRequest.status`):
/// `created`, `in_work`, `done`, `canceled`, `await_payment`,
/// `paid_escrow`, `failed`, `refund`. Helpers ниже маппят их в UI-метку, цвет
/// фон/forge для chip'а, иконку для timeline. Старые/ошибочные значения
/// нормализуем до canonical status, чтобы на UI не просачивались enum-string.
///
/// Файл-helper нужен чтобы list-screen и detail-screen рендерили
/// статус идентично — иначе при появлении новых статусов один экран
/// показывает enum-string, другой friendly-name (был именно такой
/// drift в slice 2 и 3 до этого refactor'а).

typedef RequestStatusBadge = ({String label, Color bg, Color fg});
typedef RequestHistoryReason = ({String label, String? comment});

enum RequestStatusFilter {
  all('Все', <String>{}),
  active('Активные', <String>{
    'created',
    'await_payment',
    'paid_escrow',
    'in_work',
  }),
  done('Завершены', <String>{'done'}),
  canceled('Отменены', <String>{'canceled', 'refund', 'failed'});

  const RequestStatusFilter(this.label, this.statuses);

  final String label;
  final Set<String> statuses;
}

String normalizeRequestStatus(String status) {
  final value = status.trim().toLowerCase();
  return switch (value) {
    'failied' => 'failed',
    'cancelled' => 'canceled',
    'completed' => 'done',
    'in_progress' => 'in_work',
    _ => value,
  };
}

/// Возвращает обязательную для `Storage.CancelRequest` причину отмены.
///
/// Пользователь не выбирает техническую причину вручную: она однозначно
/// следует из текущего этапа заявки. Для статусов, в которых отмена запрещена,
/// возвращается `null`.
String? cancelReasonForRequestStatus(String status) {
  return switch (normalizeRequestStatus(status)) {
    'created' => 'canceled_not_signed',
    'await_payment' => 'canceled_signed_unpaid',
    _ => null,
  };
}

RequestStatusBadge requestStatusBadge(String status) {
  final normalized = normalizeRequestStatus(status);
  switch (normalized) {
    case 'draft':
      return (
        label: 'Черновик',
        bg: kYellowColor.withValues(alpha: 0.12),
        fg: kYellowColor,
      );
    case 'created':
      return (
        label: 'Создана',
        bg: kGreyColor.withValues(alpha: 0.12),
        fg: kGreyColor,
      );
    case 'in_work':
      return (
        label: 'В работе',
        bg: kSecondaryColor.withValues(alpha: 0.12),
        fg: kSecondaryColor,
      );
    case 'done':
      return (
        label: 'Завершена',
        bg: kGreenColor.withValues(alpha: 0.12),
        fg: kGreenColor,
      );
    case 'canceled':
      return (
        label: 'Отменена',
        bg: kRedColor.withValues(alpha: 0.12),
        fg: kRedColor,
      );
    case 'failed':
      return (
        label: 'Не выполнена',
        bg: kRedColor.withValues(alpha: 0.12),
        fg: kRedColor,
      );
    case 'await_payment':
      return (
        label: 'Ожидание оплаты',
        bg: kYellowColor.withValues(alpha: 0.12),
        fg: kYellowColor,
      );
    case 'paid_escrow':
      return (
        label: 'Оплачено (escrow)',
        bg: kSecondaryColor.withValues(alpha: 0.10),
        fg: kSecondaryColor,
      );
    case 'refund':
      return (
        label: 'Возврат',
        bg: kRedColor.withValues(alpha: 0.10),
        fg: kRedColor,
      );
    case 'assigned':
      return (
        label: 'Специалист назначен',
        bg: kSecondaryColor.withValues(alpha: 0.10),
        fg: kSecondaryColor,
      );
    default:
      return (
        // A backend enum must never be exposed as user-facing copy. New
        // statuses stay understandable until an exact product label is added.
        label: normalized.isEmpty ? '—' : 'Статус обновлён',
        bg: kGreyColor.withValues(alpha: 0.10),
        fg: kGreyColor,
      );
  }
}

/// Event labels used only by request history. Keeping these out of
/// [requestStatusBadge] prevents backend event enums from becoming business
/// states in filters and action gating.
RequestStatusBadge requestHistoryStatusBadge(String status) {
  switch (normalizeRequestStatus(status)) {
    case 'request_assigned':
    case 'specialist_assigned':
      return (
        label: 'Специалист назначен',
        bg: kSecondaryColor.withValues(alpha: 0.10),
        fg: kSecondaryColor,
      );
    case 'request_reassigned':
    case 'specialist_reassigned':
      return (
        label: 'Специалист переназначен',
        bg: kSecondaryColor.withValues(alpha: 0.10),
        fg: kSecondaryColor,
      );
    case 'specialist_accepted':
      return (
        label: 'Принята специалистом',
        bg: kSecondaryColor.withValues(alpha: 0.12),
        fg: kSecondaryColor,
      );
    case 'specialist_rejected':
      return (
        label: 'Отклонена специалистом',
        bg: kRedColor.withValues(alpha: 0.10),
        fg: kRedColor,
      );
    case 'specialist_failed':
    case 'request_failed':
      return (
        label: 'Не выполнена',
        bg: kRedColor.withValues(alpha: 0.12),
        fg: kRedColor,
      );
    case 'request_created':
      return requestStatusBadge('created');
    case 'request_completed':
      return requestStatusBadge('done');
    case 'request_canceled':
      return requestStatusBadge('canceled');
    default:
      return requestStatusBadge(status);
  }
}

IconData requestStatusIcon(String status) {
  switch (normalizeRequestStatus(status)) {
    case 'draft':
      return Icons.edit_note_rounded;
    case 'created':
      return Icons.fiber_new_rounded;
    case 'in_work':
      return Icons.work_outline_rounded;
    case 'done':
      return Icons.check_rounded;
    case 'canceled':
      return Icons.close_rounded;
    case 'failed':
      return Icons.error_outline_rounded;
    case 'await_payment':
    case 'paid_escrow':
      return Icons.payments_outlined;
    case 'refund':
      return Icons.undo_rounded;
    case 'assigned':
      return Icons.person_add_alt_1_rounded;
    default:
      return Icons.circle_outlined;
  }
}

IconData requestHistoryStatusIcon(String status) {
  switch (normalizeRequestStatus(status)) {
    case 'request_assigned':
    case 'specialist_assigned':
    case 'request_reassigned':
    case 'specialist_reassigned':
      return Icons.person_add_alt_1_rounded;
    case 'specialist_accepted':
      return Icons.person_rounded;
    case 'specialist_rejected':
      return Icons.person_off_rounded;
    case 'specialist_failed':
    case 'request_failed':
      return Icons.error_outline_rounded;
    case 'request_created':
      return Icons.fiber_new_rounded;
    case 'request_completed':
      return Icons.check_rounded;
    case 'request_canceled':
      return Icons.close_rounded;
    default:
      return requestStatusIcon(status);
  }
}

/// Маппит `changedByRole` из history-entry в human-readable label.
String requestRoleLabel(String role) {
  switch (role.toLowerCase()) {
    case 'company':
      return 'Компания';
    case 'specialist':
      return 'Специалист';
    case 'client':
      return 'Клиент';
    case 'admin':
      return 'Администратор';
    case 'system':
    case '':
      return 'Система';
    default:
      return 'Участник';
  }
}

RequestHistoryReason requestHistoryReason(String rawReason) {
  final raw = rawReason.trim();
  if (raw.isEmpty) return (label: '', comment: null);

  final separator = raw.indexOf(':');
  final code = (separator >= 0 ? raw.substring(0, separator) : raw)
      .trim()
      .toLowerCase();
  final comment = separator >= 0 ? raw.substring(separator + 1).trim() : '';
  final label = switch (code) {
    'specialist_accepted' => 'Специалист принял заявку',
    'specialist_rejected' => 'Специалист отклонил заявку',
    'specialist_failed' => 'Специалист отметил заявку как невыполненную',
    'request_assigned' => 'Назначен специалист',
    'request_reassigned' => 'Специалист переназначен',
    'request_canceled' => 'Заявка отменена',
    'company_canceled' => 'Компания отменила заявку',
    'canceled_not_signed' => 'Договор не подписан',
    'canceled_signed_unpaid' => 'Договор подписан, оплаты нет',
    'request_completed' => 'Заявка завершена',
    'specialist_assigned' => 'Назначен специалист',
    'specialist_reassigned' => 'Специалист переназначен',
    'request_created' => 'Заявка создана',
    'payment_requested' => 'Ожидается оплата',
    'payment_completed' => 'Оплата получена',
    'refund_completed' => 'Возврат выполнен',
    'company_specialist_unlinked' => 'Специалист больше не привязан к компании',
    _ =>
      RegExp(r'^[a-z0-9_]+$').hasMatch(code) ? 'Статус заявки изменён' : code,
  };

  return (label: label, comment: comment.isEmpty ? null : comment);
}

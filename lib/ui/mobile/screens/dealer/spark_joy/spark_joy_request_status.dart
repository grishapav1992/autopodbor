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
  draft('Черновики', <String>{}, localOnly: true),
  newRequests('Новые', <String>{'created', 'await_payment'}),
  inProgress('В работе', <String>{'paid_escrow', 'in_work'}),
  done('Завершены', <String>{'done'}),
  canceled('Отменены', <String>{'canceled', 'refund'}),
  failed('Не выполнены', <String>{'failed'});

  const RequestStatusFilter(
    this.label,
    this.statuses, {
    this.localOnly = false,
  });

  final String label;
  final Set<String> statuses;
  final bool localOnly;
}

String normalizeRequestStatus(String status) {
  final value = status.trim().toLowerCase();
  return switch (value) {
    'failied' => 'failed',
    'cancelled' => 'canceled',
    _ => value,
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
    default:
      return (
        label: normalized.isEmpty ? '—' : normalized,
        bg: kGreyColor.withValues(alpha: 0.10),
        fg: kGreyColor,
      );
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
    default:
      return Icons.circle_outlined;
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
      return role;
  }
}

RequestHistoryReason requestHistoryReason(String rawReason) {
  final raw = rawReason.trim();
  if (raw.isEmpty) return (label: '', comment: null);

  final separator = raw.indexOf(':');
  final code = (separator >= 0 ? raw.substring(0, separator) : raw).trim();
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
    _ => code,
  };

  return (label: label, comment: comment.isEmpty ? null : comment);
}

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';

/// Status enum заявки (`Storage.GetRequest.status`):
/// `created`, `in_work`, `done`, `canceled`, `await_payment`,
/// `paid_escrow`, `refund`. Helpers ниже маппят их в UI-метку, цвет
/// фон/forge для chip'а, иконку для timeline.
///
/// Файл-helper нужен чтобы list-screen и detail-screen рендерили
/// статус идентично — иначе при появлении новых статусов один экран
/// показывает enum-string, другой friendly-name (был именно такой
/// drift в slice 2 и 3 до этого refactor'а).

typedef RequestStatusBadge = ({String label, Color bg, Color fg});

RequestStatusBadge requestStatusBadge(String status) {
  switch (status) {
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
        label: status.isEmpty ? '—' : status,
        bg: kGreyColor.withValues(alpha: 0.10),
        fg: kGreyColor,
      );
  }
}

IconData requestStatusIcon(String status) {
  switch (status) {
    case 'created':
      return Icons.fiber_new_rounded;
    case 'in_work':
      return Icons.work_outline_rounded;
    case 'done':
      return Icons.check_rounded;
    case 'canceled':
      return Icons.close_rounded;
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

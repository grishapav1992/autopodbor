import 'package:flutter_application_1/data/api/notification_api.dart';

/// One label/value line in the «Детали уведомления» panel.
class NotificationDetailRow {
  const NotificationDetailRow(this.label, this.value);

  final String label;
  final String value;
}

/// Builds the human-readable detail rows for a notification's «Подробнее»
/// panel.
///
/// Only a curated set of human-readable payload fields is surfaced. Technical
/// keys (`event`, any `*Id`, raw `requestType`, the `from`/`to`/`clientUser`
/// container keys, `entityType`, `source`, `provider`, `status`, `checkType`,
/// `requestCars`, …) and bare numeric IDs are intentionally hidden so DB
/// fields never leak to the user (#1, #3). Anything not listed in
/// [_detailPayloadFields] is dropped.
List<NotificationDetailRow> notificationDetailRows(BackendNotification n) {
  final rows = <NotificationDetailRow>[
    NotificationDetailRow('Тип', _typeLabel(n.type)),
    NotificationDetailRow('Статус', _statusLabel(n.status)),
    NotificationDetailRow('Создано', _formatAbsolute(n.createdAt)),
  ];
  if (n.actedAt != null) {
    rows.add(NotificationDetailRow('Обработано', _formatAbsolute(n.actedAt!)));
  }
  if (n.expiresAt != null) {
    rows.add(NotificationDetailRow('Истекает', _formatAbsolute(n.expiresAt!)));
  }
  for (final field in _detailPayloadFields) {
    final value = field.read(n.payload);
    if (value != null && value.isNotEmpty) {
      rows.add(NotificationDetailRow(field.label, value));
    }
  }
  return rows;
}

/// Curated payload field for the «Подробнее» panel: a fixed label plus a reader
/// that extracts and formats a value (or returns null to skip the field).
class _PayloadField {
  const _PayloadField(this.label, this.read);

  final String label;
  final String? Function(Map<String, dynamic> payload) read;
}

final List<_PayloadField> _detailPayloadFields = <_PayloadField>[
  _PayloadField(
    'Компания',
    (p) => _payloadName(p['from']) ?? _payloadString(p['companyName']),
  ),
  _PayloadField(
    'Клиент',
    (p) => _payloadName(p['clientUser']) ?? _payloadName(p['client']),
  ),
  _PayloadField(
    'Специалист',
    (p) => _payloadName(p['specialist']) ?? _payloadString(p['specialistName']),
  ),
  _PayloadField('Заявка', (p) {
    final number =
        _payloadString(p['requestNumber']) ??
        _payloadString(p['request_number']);
    return number == null ? null : '№$number';
  }),
  _PayloadField('Тип заявки', (p) => _requestTypeLabel(p['requestType'])),
  _PayloadField('Срок', (p) => _formatDueDate(p['dueAt'])),
  _PayloadField('Напомнить', (p) {
    final s = _payloadString(p['reminderAt']);
    if (s == null) return null;
    final dt = DateTime.tryParse(s);
    return dt == null ? s : _formatAbsolute(dt);
  }),
  _PayloadField(
    'Комментарий',
    (p) =>
        _payloadString(p['note']) ??
        _payloadString(p['comment']) ??
        _payloadString(p['message']),
  ),
  _PayloadField('Причина', (p) => _payloadString(p['reason'])),
];

/// Trimmed non-empty string from a payload value, or null.
String? _payloadString(Object? value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

/// Readable name from a nested payload object (company/specialist/client),
/// or null when none of the known name fields are present.
String? _payloadName(Object? value) {
  if (value is Map) {
    final label = _readableMapLabel(value);
    return label.isEmpty ? null : label;
  }
  return null;
}

String _readableMapLabel(Map value) {
  for (final k in const [
    'name',
    'companyName',
    'title',
    'displayName',
    'fullName',
    'label',
  ]) {
    final v = value[k];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }
  }
  return '';
}

String? _requestTypeLabel(Object? raw) {
  final value = _payloadString(raw);
  if (value == null) return null;
  switch (value) {
    case 'by_car':
      return 'По автомобилю';
    case 'turnkey':
      return 'Под ключ';
    default:
      return value;
  }
}

/// Formats a due date (date-only — the backend sends `dueAt` as a date).
String? _formatDueDate(Object? raw) {
  final s = _payloadString(raw);
  if (s == null) return null;
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  final local = dt.toLocal();
  return '${_dd(local.day)}.${_dd(local.month)}.${local.year}';
}

String _typeLabel(NotificationType type) {
  switch (type) {
    case NotificationType.task:
      return 'Заявка';
    case NotificationType.invitation:
      return 'Приглашение';
    case NotificationType.reminder:
      return 'Напоминание';
    case NotificationType.system:
      return 'Системное';
  }
}

String _statusLabel(NotificationStatus status) {
  switch (status) {
    case NotificationStatus.pending:
      return 'Новое';
    case NotificationStatus.accepted:
      return 'Принято';
    case NotificationStatus.rejected:
      return 'Отклонено';
    case NotificationStatus.read:
      return 'Просмотрено';
    case NotificationStatus.expired:
      return 'Истекло';
  }
}

String _formatAbsolute(DateTime ts) {
  final local = ts.toLocal();
  return '${_dd(local.day)}.${_dd(local.month)}.${local.year}, ${_hhmm(local)}';
}

String _dd(int n) => n < 10 ? '0$n' : '$n';
String _hhmm(DateTime ts) => '${_dd(ts.hour)}:${_dd(ts.minute)}';

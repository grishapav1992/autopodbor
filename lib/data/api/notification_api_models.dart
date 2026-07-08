/// Domain models for the `Notification.*` RPC family on the storage
/// backend (`https://app.carreports.ru`).
///
/// Mirrors the OpenRPC schema returned by `Doc({getMethodByName: ...})`:
///   • [NotificationType] — wire enum: task, invitation, reminder, system.
///   • [NotificationStatus] — wire enum: pending, accepted, rejected,
///     read, expired.
///   • [NotificationAction] — request enum: accept, reject (only for
///     interactive types: task and invitation).
///   • [BackendNotification] — single feed item with full payload.
///   • [NotificationsPage] — paginated result of GetNotifications.
///   • [NotificationActionResult] — server response after accept/reject.
///   • [NotificationPushEvent] — server-to-client realtime push frame.
///
/// Datetime fields are decoded from ISO 8601 ATOM strings
/// (`2026-04-27T00:00:00+00:00`) via `DateTime.tryParse`. The 2026-04-27
/// changelog unified all backend datetime fields to this format.
library;

enum NotificationType {
  task,
  invitation,
  reminder,
  system;

  String get wireValue => name;

  static NotificationType? tryParse(Object? raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return null;
    for (final t in NotificationType.values) {
      if (t.name == value) return t;
    }
    return null;
  }

  /// True for types that require an explicit accept/reject reaction.
  bool get isInteractive =>
      this == NotificationType.task || this == NotificationType.invitation;
}

enum NotificationStatus {
  pending,
  accepted,
  rejected,
  read,
  expired;

  String get wireValue => name;

  static NotificationStatus? tryParse(Object? raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return null;
    for (final s in NotificationStatus.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

enum NotificationAction {
  accept,
  reject;

  String get wireValue => name;
}

/// Realtime push event types from the WebSocket channel.
enum NotificationPushEventType {
  created,
  feedback,
  expired,
  unknown;

  static NotificationPushEventType tryParse(Object? raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) {
      return NotificationPushEventType.unknown;
    }
    for (final e in NotificationPushEventType.values) {
      if (e.name == value) return e;
    }
    return NotificationPushEventType.unknown;
  }
}

/// Immutable notification record returned by `Notification.GetNotifications`.
///
/// The [payload] map is shape-typed by the backend via [NotificationType] —
/// e.g. `task` carries `requestId`, `requestNumber`, `clientUser`;
/// `reminder` carries `reminderAt`, `entityType`, `entityId`. Keep raw
/// access through [payload]; add typed getters when a specific UI screen
/// starts depending on a field.
class BackendNotification {
  const BackendNotification({
    required this.id,
    required this.type,
    required this.status,
    required this.recipientId,
    required this.title,
    required this.createdAt,
    this.senderId,
    this.body,
    this.payload = const <String, dynamic>{},
    this.expiresAt,
    this.actedAt,
  });

  /// UUID assigned by the backend.
  final String id;
  final NotificationType type;
  final NotificationStatus status;
  final int recipientId;
  final int? senderId;
  final String title;
  final String? body;
  final Map<String, dynamic> payload;
  final DateTime? expiresAt;
  final DateTime? actedAt;
  final DateTime createdAt;

  bool get isInteractivePending =>
      type.isInteractive && status == NotificationStatus.pending;

  int? get requestId {
    final entityType = (payload['entityType'] ?? '').toString();
    final raw =
        payload['requestId'] ??
        payload['request_id'] ??
        (entityType == 'request' ? payload['entityId'] : null);
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  String get requestNumber {
    return (payload['requestNumber'] ?? payload['request_number'] ?? '')
        .toString()
        .trim();
  }

  // ── ApiCloud legal-review (system) notifications ──────────────────────
  // Бэк шлёт ОДНО уведомление на КАЖДУЮ проверку с payload вида
  // {event: 'legal_review_persisted', provider: 'api_cloud', status, checkType,
  //  vehicleVin, vehicleGosNumber, …}. batchNumber/reportNumber/имени отчёта в
  // payload НЕТ — поэтому навигации в отчёт нет, только читаемый текст.

  /// True для уведомления о завершении ApiCloud-проверки. Матчим по точному
  /// маркеру `event` (не по одному `provider == 'api_cloud'`), чтобы будущие
  /// api_cloud-события с другим `event` не рендерились как завершённая проверка.
  bool get isLegalReview =>
      (payload['event'] ?? '').toString() == 'legal_review_persisted';

  /// True для уведомления о внутреннем VIN↔госномер конвертере — инструмент
  /// идентификации, а не материал проверки (в ленте его прячем).
  bool get isLegalConverter =>
      isLegalReview && legalCheckType == 'api_cloud_converter_search';

  /// Тип ApiCloud-проверки (`api_cloud_zalog_fedresurs` и т.п.).
  String get legalCheckType => (payload['checkType'] ?? '').toString().trim();

  /// Статус результата: `success` / `not_found` / `error`.
  String get legalStatus => (payload['status'] ?? '').toString().trim();

  factory BackendNotification.fromJson(Map<String, dynamic> json) {
    final payloadRaw = json['payload'];
    final payload = payloadRaw is Map
        ? payloadRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    for (final key in const ['requestId', 'requestNumber']) {
      if (json[key] != null && payload[key] == null) {
        payload[key] = json[key];
      }
    }
    return BackendNotification(
      id: (json['id'] ?? '').toString(),
      type: NotificationType.tryParse(json['type']) ?? NotificationType.system,
      status:
          NotificationStatus.tryParse(json['status']) ??
          NotificationStatus.pending,
      recipientId: (json['recipientId'] is num)
          ? (json['recipientId'] as num).toInt()
          : int.tryParse('${json['recipientId']}') ?? 0,
      senderId: json['senderId'] is num
          ? (json['senderId'] as num).toInt()
          : (json['senderId'] != null
                ? int.tryParse('${json['senderId']}')
                : null),
      title: (json['title'] ?? '').toString(),
      body: json['body']?.toString(),
      payload: payload,
      expiresAt: _parseDt(json['expiresAt']),
      actedAt: _parseDt(json['actedAt']),
      createdAt: _parseDt(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  BackendNotification copyWith({
    NotificationStatus? status,
    DateTime? actedAt,
  }) {
    return BackendNotification(
      id: id,
      type: type,
      status: status ?? this.status,
      recipientId: recipientId,
      senderId: senderId,
      title: title,
      body: body,
      payload: payload,
      expiresAt: expiresAt,
      actedAt: actedAt ?? this.actedAt,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDt(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class NotificationsPage {
  const NotificationsPage({required this.items, this.nextCursor});

  final List<BackendNotification> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// Result of `Notification.ActionNotification`.
///
/// For `accept` on `task` — backend creates a request and returns
/// `requestId` + `requestNumber`. For `accept` on `invitation` — backend
/// joins the user to a company and returns `companyId`.
class NotificationActionResult {
  const NotificationActionResult({
    required this.notificationId,
    required this.status,
    required this.action,
    this.requestId,
    this.requestNumber,
    this.companyId,
    this.error,
  });

  final String notificationId;
  final NotificationStatus status;
  final NotificationAction action;
  final int? requestId;
  final String? requestNumber;
  final int? companyId;
  final String? error;

  bool get isOk => error == null || error!.isEmpty;

  /// Бэк отвечает «Оповещение уже обработано.», когда статус на сервере уже
  /// финальный: типично первый accept/reject ДОШЁЛ (сервер коммитит смену
  /// статуса + привязку к компании до рассылки push/email), а его ответ
  /// потерялся — например, из-за клиентского таймаута. Контракт не даёт
  /// числового кода — только этот текст в `result.error`
  /// (ActionNotificationUseCase::resolveActionError), поэтому матчим по
  /// подстроке.
  bool get isAlreadyProcessed =>
      (error ?? '').toLowerCase().contains('уже обработано');

  /// «Оповещение не найдено.» — запись удалена на сервере; локальная карточка
  /// заведомо мертва, действия по ней невозможны.
  bool get isGoneOnServer {
    final text = (error ?? '').toLowerCase();
    return text.contains('оповещение не найдено') ||
        text.contains('уведомление не найдено');
  }

  factory NotificationActionResult.fromJson(Map<String, dynamic> json) {
    return NotificationActionResult(
      notificationId: (json['notificationId'] ?? '').toString(),
      status:
          NotificationStatus.tryParse(json['status']) ??
          NotificationStatus.pending,
      action: json['action']?.toString() == 'reject'
          ? NotificationAction.reject
          : NotificationAction.accept,
      requestId: json['requestId'] is num
          ? (json['requestId'] as num).toInt()
          : null,
      requestNumber: json['requestNumber']?.toString(),
      companyId: json['companyId'] is num
          ? (json['companyId'] as num).toInt()
          : null,
      error: (json['error']?.toString().isEmpty ?? true)
          ? null
          : json['error'].toString(),
    );
  }
}

/// Single push frame from the WebSocket channel.
///
/// Backend wire format:
/// ```json
/// {
///   "id": 0,
///   "response": "Notification.Push",
///   "fromMethod": "Notification.Push",
///   "result": {
///     "notificationId": "uuid",
///     "event": "created",
///     "preview": {"type": "task", "title": "...", "createdAt": "..."},
///     "requiresFetch": true
///   }
/// }
/// ```
class NotificationPushEvent {
  const NotificationPushEvent({
    required this.notificationId,
    required this.event,
    required this.requiresFetch,
    this.previewType,
    this.previewTitle,
    this.previewCreatedAt,
  });

  final String notificationId;
  final NotificationPushEventType event;
  final bool requiresFetch;
  final NotificationType? previewType;
  final String? previewTitle;
  final DateTime? previewCreatedAt;

  /// Tries to parse a single WS frame. Returns `null` if it's not a
  /// `Notification.Push` envelope (heartbeats, errors, unknown frames).
  static NotificationPushEvent? tryParse(Map<String, dynamic> frame) {
    final response = frame['response']?.toString() ?? '';
    if (response != 'Notification.Push') return null;
    final result = frame['result'];
    if (result is! Map) return null;
    final map = result.map((k, v) => MapEntry(k.toString(), v));
    final notificationId = (map['notificationId'] ?? '').toString();
    if (notificationId.isEmpty) return null;
    final preview = map['preview'] is Map
        ? (map['preview'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};
    return NotificationPushEvent(
      notificationId: notificationId,
      event: NotificationPushEventType.tryParse(map['event']),
      requiresFetch: map['requiresFetch'] == true,
      previewType: NotificationType.tryParse(preview['type']),
      previewTitle: preview['title']?.toString(),
      previewCreatedAt: BackendNotification._parseDt(preview['createdAt']),
    );
  }
}

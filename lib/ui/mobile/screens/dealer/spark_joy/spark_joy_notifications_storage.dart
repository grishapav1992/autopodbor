import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

/// Data layer (Service + Repository rolled into one) for the spark_joy
/// notifications feed.
///
/// Persisted to the shared `SharedPreferences` instance under a versioned
/// key so a schema change later can cleanly migrate. No backend today —
/// [ensureSeedData] populates an initial demo set on first run so the
/// "Уведомления" tab is never empty in product previews.
///
/// Contract with the rest of the app:
///   • [load]          — fetch the full list, newest first.
///   • [markAsRead]    — flip a single entry's `read` flag.
///   • [markAllAsRead] — batch flip (unused right now, kept for future
///                       "очистить" affordance on the screen).
///   • [unreadCount]   — used by the nav-bar badge.
///   • [notifier]      — a single [ValueNotifier] that bumps whenever
///                       the stored list changes; screens can listen
///                       instead of re-reading on every visit.
///
/// Notifications are append-only from the user's perspective — the spec
/// says they cannot be deleted, so no `delete` / `remove` API here.
class SparkJoyNotificationsStorage {
  SparkJoyNotificationsStorage._();

  static const String _key = 'spark_joy_notifications_v1';
  static const String _seededKey = 'spark_joy_notifications_seeded_v1';

  /// Increments every time the persisted list changes. The nav-bar badge
  /// and the feed screen can `ValueListenableBuilder` on this to rebuild
  /// without polling.
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static Future<List<SparkJoyNotification>> load() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return <SparkJoyNotification>[];
    final raw = pref.getStringList(_key) ?? const <String>[];
    final result = <SparkJoyNotification>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          result.add(SparkJoyNotification.fromJson(decoded));
        }
      } catch (_) {}
    }
    // Newest first, regardless of insertion order.
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  static Future<void> _save(List<SparkJoyNotification> list) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setStringList(
      _key,
      list.map((n) => jsonEncode(n.toJson())).toList(growable: false),
    );
    notifier.value = notifier.value + 1;
  }

  /// Marks a single notification as read. No-op if the id is missing or
  /// already read.
  static Future<void> markAsRead(String id) async {
    final list = await load();
    var changed = false;
    final updated = list.map((n) {
      if (n.id == id && !n.read) {
        changed = true;
        return n.copyWith(read: true);
      }
      return n;
    }).toList(growable: false);
    if (!changed) return;
    await _save(updated);
  }

  /// Batch-flips every notification to read. Exposed for a potential
  /// "прочитать все" button in a future revision.
  static Future<void> markAllAsRead() async {
    final list = await load();
    if (list.every((n) => n.read)) return;
    final updated = list
        .map((n) => n.read ? n : n.copyWith(read: true))
        .toList(growable: false);
    await _save(updated);
  }

  /// Convenience read-only count for the nav-bar badge.
  static Future<int> unreadCount() async {
    final list = await load();
    return list.where((n) => !n.read).length;
  }

  /// Seeds a demo dataset on first launch so the feed isn't empty.
  /// Idempotent: checks the seed flag, does nothing on subsequent runs.
  static Future<void> ensureSeedData() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    if (pref.getBool(_seededKey) == true) return;
    await pref.setBool(_seededKey, true);
    final existing = pref.getStringList(_key);
    if (existing != null && existing.isNotEmpty) return;
    final now = DateTime.now();
    final seed = <SparkJoyNotification>[
      SparkJoyNotification(
        id: 'n_seed_1',
        title: 'Новое задание',
        message: 'Компания назначила вам осмотр Toyota Camry.',
        type: SparkJoyNotificationType.assignment,
        createdAt: now.subtract(const Duration(minutes: 12)),
        read: false,
      ),
      SparkJoyNotification(
        id: 'n_seed_2',
        title: 'Отчёт принят',
        message: 'Клиент подтвердил получение отчёта №1000021.',
        type: SparkJoyNotificationType.reportAccepted,
        createdAt: now.subtract(const Duration(hours: 3)),
        read: false,
      ),
      SparkJoyNotification(
        id: 'n_seed_3',
        title: 'Напоминание',
        message: 'Черновик отчёта ждёт завершения уже 2 дня.',
        type: SparkJoyNotificationType.reminder,
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        read: true,
      ),
      SparkJoyNotification(
        id: 'n_seed_4',
        title: 'Обновление приложения',
        message: 'Доступна новая версия с улучшенным VIN-сканером.',
        type: SparkJoyNotificationType.system,
        createdAt: now.subtract(const Duration(days: 3)),
        read: true,
      ),
    ];
    await _save(seed);
  }
}

/// Semantic category of a notification. Drives the leading icon + tint
/// so the list stays visually scannable without reading each title.
enum SparkJoyNotificationType {
  assignment,
  reportAccepted,
  reminder,
  system,
  message,
}

/// Domain model — immutable. Serializes to/from JSON for persistence.
class SparkJoyNotification {
  const SparkJoyNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String title;
  final String message;
  final SparkJoyNotificationType type;
  final DateTime createdAt;
  final bool read;

  SparkJoyNotification copyWith({bool? read}) {
    return SparkJoyNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      createdAt: createdAt,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'message': message,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory SparkJoyNotification.fromJson(Map<String, dynamic> json) {
    return SparkJoyNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      type: _parseType(json['type']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      read: json['read'] == true,
    );
  }

  static SparkJoyNotificationType _parseType(Object? raw) {
    final text = (raw ?? '').toString();
    for (final t in SparkJoyNotificationType.values) {
      if (t.name == text) return t;
    }
    return SparkJoyNotificationType.system;
  }
}

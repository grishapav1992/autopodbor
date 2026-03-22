import 'dart:convert';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'spark_joy_data.dart';

class SparkJoyStorage {
  SparkJoyStorage._();

  static const String _loggedInKey = 'spark_joy_logged_in_v1';
  static const String _roleKey = 'spark_joy_role_v1';
  static const String _draftsKey = 'spark_joy_drafts_v1';
  static const String _completedKey = 'spark_joy_completed_v1';

  static Future<bool> isLoggedIn() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return false;
    return pref.getBool(_loggedInKey) ?? false;
  }

  static Future<SparkJoyRole> currentRole() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return SparkJoyRole.specialist;
    return sparkJoyRoleFromKey(pref.getString(_roleKey));
  }

  static Future<void> login(SparkJoyRole role) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setBool(_loggedInKey, true);
    await pref.setString(_roleKey, sparkJoyRoleKey(role));
  }

  static Future<void> logout() async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setBool(_loggedInKey, false);
  }

  static Future<void> ensureSeedData() async {
    final completed = await loadCompleted();
    if (completed.isNotEmpty) return;
    await _writeList(_completedKey, [_seedCompletedReport()]);
  }

  static Future<List<Map<String, dynamic>>> loadDrafts() async {
    return _readList(_draftsKey);
  }

  static Future<List<Map<String, dynamic>>> loadCompleted() async {
    return _readList(_completedKey);
  }

  static Future<void> upsertDraft(Map<String, dynamic> draft) async {
    final drafts = await loadDrafts();
    final id = (draft['id'] ?? '').toString();
    if (id.isEmpty) return;
    final filtered = drafts.where((d) => d['id']?.toString() != id).toList();
    filtered.insert(0, draft);
    await _writeList(_draftsKey, filtered);
  }

  static Future<void> deleteDraft(String id) async {
    final drafts = await loadDrafts();
    await _writeList(
      _draftsKey,
      drafts.where((d) => d['id']?.toString() != id).toList(),
    );
  }

  static Future<void> upsertCompleted(Map<String, dynamic> report) async {
    final completed = await loadCompleted();
    final id = (report['id'] ?? '').toString();
    if (id.isEmpty) return;
    final filtered = completed.where((d) => d['id']?.toString() != id).toList();
    filtered.insert(0, report);
    await _writeList(_completedKey, filtered);
  }

  static Future<void> deleteCompleted(String id) async {
    final completed = await loadCompleted();
    await _writeList(
      _completedKey,
      completed.where((d) => d['id']?.toString() != id).toList(),
    );
  }

  static Future<void> moveDraftToCompleted({
    required String draftId,
    required Map<String, dynamic> completedReport,
  }) async {
    await upsertCompleted(completedReport);
    await deleteDraft(draftId);
  }

  static Future<List<Map<String, dynamic>>> _readList(String key) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return [];
    final raw = pref.getStringList(key) ?? <String>[];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          result.add(decoded);
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<void> _writeList(
    String key,
    List<Map<String, dynamic>> values,
  ) async {
    final pref = UserSimplePreferences.pref;
    if (pref == null) return;
    await pref.setStringList(key, values.map(jsonEncode).toList());
  }

  static Map<String, dynamic> _seedCompletedReport() {
    return {
      'id': 'spark_report_seed_1',
      'createdAt': '19.03.2026',
      'updatedAt': '19.03.2026',
      'reportName': 'Toyota Camry для клиента',
      'car': 'Toyota Camry 2019',
      'make': 'Toyota',
      'model': 'Camry',
      'generation': 'XV70',
      'inspector': 'Максим Егоров',
      'date': '19.03.2026',
      'verdict': 'recommended',
      'verdictLabel': 'Рекомендован',
      'score': '88/100',
      'issues': 'Мелкие сколы, косметический окрас переднего крыла',
      'summary':
          'Автомобиль в хорошем состоянии, критических замечаний по технике нет.',
      'vin': 'JTNB11HK1K3000001',
      'plate': 'A123BC77',
      'mileage': '78000',
      'owners': '2 владельца',
      'engine': '2.5 бензин',
      'transmission': 'AT',
      'drive': 'Передний',
      'reportsCount': 2,
      'images': [
        'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop',
      ],
      'sections': [
        {
          'title': 'Автомобиль',
          'status': 'ok',
          'required': true,
          'details': [
            {
              'label': 'Марка / модель',
              'value': 'Toyota Camry 2019',
              'severity': 'ok',
            },
            {'label': 'VIN', 'value': 'JTNB11HK1K3000001', 'severity': 'ok'},
            {'label': 'Госномер', 'value': 'A123BC77', 'severity': 'ok'},
          ],
        },
        {
          'title': 'Кузов',
          'status': 'warn',
          'required': true,
          'details': [
            {
              'label': 'Переднее левое крыло',
              'value': 'Косметический окрас',
              'severity': 'minor',
            },
          ],
        },
      ],
      'checklist': [
        {'text': 'Проверить торг по кузовным замечаниям'},
        {'text': 'Перепроверить историю обслуживания у дилера'},
      ],
      'mediaGroups': {
        'overview': [
          {
            'id': 'camry-overview-1',
            'url':
                'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80&auto=format&fit=crop',
            'type': 'image',
            'inspection': {'noDamage': true, 'isDraft': false, 'tags': []},
          },
        ],
        'body': [
          {
            'id': 'camry-body-1',
            'url':
                'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop',
            'type': 'image',
            'inspection': {
              'noDamage': false,
              'isDraft': false,
              'tags': ['cosmetic_paint'],
            },
          },
        ],
      },
      'summaryNote':
          'Автомобиль технически исправен, критичных дефектов не выявлено.',
      'expertConclusion':
          'Рекомендую к покупке после небольшого торга на косметику.',
      'fullInspection': true,
    };
  }
}

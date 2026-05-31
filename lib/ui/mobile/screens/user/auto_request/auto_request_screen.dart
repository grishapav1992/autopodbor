import 'dart:async';

import 'package:flutter_application_1/core/constants/app_colors.dart';

import 'package:flutter_application_1/core/constants/app_sizes.dart';

import 'package:flutter_application_1/core/constants/popular_cars_ru.dart';

import 'package:flutter_application_1/core/constants/app_images.dart';

import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/core/utils/profanity_moderator.dart';
import 'package:flutter_application_1/data/services/city_repository.dart';

import 'package:flutter_application_1/ui/common/widgets/city_picker_bottom_sheet.dart';

import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';

import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';

import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';

import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

String _formatDateIso(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? _tryParseRuDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(raw);
  if (match == null) return null;
  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > lastDay) return null;
  return DateTime(year, month, day);
}

class _RuDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final length = digits.length.clamp(0, 8);
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _RuPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('8') || digits.startsWith('7')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    String take(int start, int length) {
      if (digits.length <= start) return '';
      final end = start + length;
      return digits.substring(start, end > digits.length ? digits.length : end);
    }

    final g1 = take(0, 3);
    final g2 = take(3, 3);
    final g3 = take(6, 2);
    final g4 = take(8, 2);

    var out = '+7';
    if (g1.isNotEmpty) out += g1;
    if (g2.isNotEmpty) out += '-$g2';
    if (g3.isNotEmpty) out += '-$g3';
    if (g4.isNotEmpty) out += '-$g4';

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

bool _looksNumericCode(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) return false;

  return RegExp(r'^\d+$').hasMatch(trimmed);
}

bool _matchesRestylingQuery(_RestylingCardData data, String query) {
  final q = query.trim().toLowerCase();

  if (q.isEmpty) return true;

  return data.title.toLowerCase().contains(q) ||
      data.subtitle.toLowerCase().contains(q);
}

String _fallbackRestylingTitle(String rawValue) {
  final trimmed = rawValue.trim();

  if (trimmed.isEmpty) return 'Поколение';

  if (trimmed == 'Без рестайлинга') return trimmed;

  if (RegExp(r'^rest:\d+$').hasMatch(trimmed)) return 'Поколение';

  if (RegExp(r'^gen:\d+\|').hasMatch(trimmed)) return 'Поколение';

  return trimmed;
}

Widget _twoColumn(
  BuildContext context, {
  required Widget left,
  required Widget right,
  double gap = 12,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final bool stacked = constraints.maxWidth < 360;
      if (stacked) {
        return Column(
          children: [
            left,
            SizedBox(height: gap),
            right,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: gap),
          Expanded(child: right),
        ],
      );
    },
  );
}

class _RemoteCarCatalog {
  static final ValueNotifier<int> stamp = ValueNotifier<int>(0);

  static bool brandsLoading = false;

  static bool brandsFailed = false;

  static List<String> brandNames = [];

  static Map<String, String> brandRusByName = {};

  static Map<String, int> brandIdByName = {};

  static final Map<String, List<String>> modelsByMake = {};

  static final Map<String, int> modelIdByKey = {};

  static final Map<String, List<String>> restylingsByKey = {};

  static final Map<String, String> restylingPhotoByKey = {};
  static final Map<String, List<String>> restylingPhotoUrlsByKey = {};

  static final Map<String, _RestylingMeta> restylingMetaByKey = {};

  static final Map<String, bool> modelsLoading = {};

  static final Map<String, bool> restylingsLoading = {};

  static String _modelKey(int brandId, String model) {
    return '$brandId|$model';
  }

  static String _restylingKey(int brandId, String model, String restyling) {
    return '$brandId|$model|$restyling';
  }

  static String _restylingValueFor(GenerationItem gen, RestylingItem rest) {
    if (rest.id > 0) {
      return 'rest:${rest.id}';
    }
    final start = rest.yearStart?.toString() ?? 'na';
    final end = rest.yearEnd?.toString() ?? 'na';
    final raw = rest.restyling.trim().isEmpty ? 'none' : rest.restyling.trim();
    return 'gen:${gen.generation}|rest:$raw|$start-$end';
  }

  static String _restylingLabelFor(RestylingItem rest) {
    final raw = rest.restyling.trim();
    if (raw.isEmpty) {
      return '\u0411\u0435\u0437 \u0440\u0435\u0441\u0442\u0430\u0439\u043b\u0438\u043d\u0433\u0430';
    }
    return raw;
  }

  static int _photoSizeRank(String size) {
    final value = size.toLowerCase();
    if (value == 'xl' ||
        value.contains('xlarge') ||
        value.contains('original')) {
      return 6;
    }
    if (value == 'l' || value.contains('large')) return 5;
    if (value == 'm' || value.contains('medium')) return 4;
    if (value == 's' || value.contains('small')) return 3;
    if (value.contains('thumb') || value.contains('preview')) return 1;
    return 2;
  }

  static int _photoUrlQualityScore(String raw) {
    final value = raw.toLowerCase();
    var score = 0;
    if (value.contains('orig') ||
        value.contains('original') ||
        value.contains('full') ||
        value.contains('hd')) {
      score += 5;
    }
    if (value.contains('large') ||
        value.contains('_l') ||
        value.contains('-l')) {
      score += 3;
    }
    final match = RegExp(r'(\d{2,4})x(\d{2,4})').firstMatch(value);
    if (match != null) {
      final w = int.tryParse(match.group(1) ?? '') ?? 0;
      final h = int.tryParse(match.group(2) ?? '') ?? 0;
      score += ((w * h) / 100000).round();
    }
    if (value.contains('thumb') ||
        value.contains('thumbnail') ||
        value.contains('preview') ||
        value.contains('small') ||
        value.contains('_s') ||
        value.contains('-s')) {
      score -= 3;
    }
    return score;
  }

  static String _normalizePhotoUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return '';
    if (value.startsWith('www.')) return 'https://$value';
    if (RegExp(r'^[A-Za-z0-9.-]+\.[A-Za-z]{2,}').hasMatch(value)) {
      return 'https://$value';
    }
    return value;
  }

  static List<String> _bestPhotoUrlsForRestyling(RestylingItem rest) {
    final scored = <String, int>{};
    for (final photo in rest.photos) {
      final sizeScore = _photoSizeRank(photo.size) * 100;
      for (final raw in [photo.urlX2, photo.urlX1]) {
        final url = _normalizePhotoUrl(raw);
        if (url.isEmpty) continue;
        final total = sizeScore + _photoUrlQualityScore(url);
        final prev = scored[url];
        if (prev == null || total > prev) {
          scored[url] = total;
        }
      }
    }
    final entries = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  static Future<void> ensureBrands() async {
    if (brandsLoading || brandNames.isNotEmpty) return;

    brandsLoading = true;

    brandsFailed = false;

    stamp.value++;

    for (int i = 0; i < 2; i++) {
      try {
        final catalog = await StorageApi.fetchBrandCatalog();

        if (catalog.names.isNotEmpty) {
          brandNames = catalog.names;

          brandRusByName = catalog.rusByName;

          brandIdByName = catalog.idByName;

          break;
        }
      } catch (_) {
        if (i == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }

    if (brandNames.isEmpty) {
      brandsFailed = true;
    }

    brandsLoading = false;

    stamp.value++;
  }

  static Future<void> ensureModels(String make) async {
    if (make.isEmpty) return;

    if (modelsByMake.containsKey(make)) return;

    if (modelsLoading[make] == true) return;

    final brandId = brandIdByName[make];

    if (brandId == null) return;

    modelsLoading[make] = true;

    stamp.value++;

    try {
      final items = await StorageApi.fetchModels(brandId: brandId);

      final models = items.map((e) => e.model).toList();

      modelsByMake[make] = models;

      for (final item in items) {
        modelIdByKey[_modelKey(brandId, item.model)] = item.id;
      }
    } catch (_) {}

    modelsLoading[make] = false;

    stamp.value++;
  }

  static Future<void> ensureRestylings(String make, String model) async {
    if (make.isEmpty || model.isEmpty) return;

    final brandId = brandIdByName[make];

    if (brandId == null) return;

    final modelKey = _modelKey(brandId, model);

    final modelId = modelIdByKey[modelKey];

    if (modelId == null) return;

    if (restylingsByKey.containsKey(modelKey)) return;

    if (restylingsLoading[modelKey] == true) return;

    restylingsLoading[modelKey] = true;

    stamp.value++;

    try {
      final generations = await StorageApi.fetchGenerations(
        modelCarId: modelId,
      );

      final restylings = <String>{};

      for (final gen in generations) {
        for (final rest in gen.restylings) {
          final value = _restylingValueFor(gen, rest);
          final label = _restylingLabelFor(rest);

          restylings.add(value);

          restylingMetaByKey.putIfAbsent(
            _restylingKey(brandId, model, value),

            () => _RestylingMeta(
              generation: gen.generation,
              restylingId: rest.id,

              yearStart: rest.yearStart,

              yearEnd: rest.yearEnd,

              frames: rest.frames
                  .map((e) => e.frame.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList(),
              restylingLabel: label,
            ),
          );

          if (rest.photos.isNotEmpty) {
            final key = _restylingKey(brandId, model, value);
            final urls = _bestPhotoUrlsForRestyling(rest);
            if (urls.isNotEmpty) {
              restylingPhotoByKey[key] = urls.first;
              restylingPhotoUrlsByKey[key] = urls;
            }
          }
        }
      }

      final ordered = restylings.toList()
        ..sort((a, b) => compareRestylingsByYearDesc(make, model, a, b));
      restylingsByKey[modelKey] = ordered;
    } catch (_) {}

    restylingsLoading[modelKey] = false;

    stamp.value++;
  }

  static List<String> makes() {
    // Backend brand list is already popularity-sorted — keep its order, no
    // frontend re-sort (T3).
    if (brandNames.isNotEmpty) {
      return List<String>.from(brandNames);
    }

    if (brandsLoading && !brandsFailed) {
      return [];
    }

    return _carCatalog.keys.toList();
  }

  static List<String> modelsFor(String make) {
    final remote = modelsByMake[make];

    if (remote != null && remote.isNotEmpty) {
      return sortModelsByPopularity(make, remote);
    }

    final local = _carCatalog[make];

    if (local != null) {
      return sortModelsByPopularity(make, local.keys.toList());
    }

    return [];
  }

  static List<String> restylingsFor(String make, String model) {
    final brandId = brandIdByName[make];

    if (brandId != null) {
      final key = _modelKey(brandId, model);

      final remote = restylingsByKey[key];

      if (remote != null && remote.isNotEmpty) {
        return remote;
      }
    }

    return _carCatalog[make]?[model] ?? <String>[];
  }

  static String restylingPhotoFor(String make, String model, String restyling) {
    final brandId = brandIdByName[make];

    if (brandId == null) return '';

    return restylingPhotoByKey[_restylingKey(brandId, model, restyling)] ?? '';
  }

  static List<String> restylingPhotoUrlsFor(
    String make,
    String model,
    String restyling,
  ) {
    final brandId = brandIdByName[make];
    if (brandId == null) return const [];
    final key = _restylingKey(brandId, model, restyling);
    final list = restylingPhotoUrlsByKey[key];
    if (list != null && list.isNotEmpty) {
      return List<String>.from(list);
    }
    final single = restylingPhotoByKey[key] ?? '';
    if (single.isEmpty) return const [];
    return [single];
  }

  static _RestylingMeta? restylingMetaFor(
    String make,

    String model,

    String restyling,
  ) {
    final brandId = brandIdByName[make];

    if (brandId == null) return null;

    return restylingMetaByKey[_restylingKey(brandId, model, restyling)];
  }

  static int? restylingIdFor(String make, String model, String restyling) {
    final meta = restylingMetaFor(make, model, restyling);
    final id = meta?.restylingId;
    if (id != null && id > 0) return id;
    return _parseRestylingId(restyling);
  }

  static int? _parseRestylingId(String value) {
    final match = RegExp(r'^rest:(\d+)$').firstMatch(value.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  static int _restylingEndYearForSort(_RestylingMeta? meta) {
    return meta?.yearEnd ?? meta?.yearStart ?? -1;
  }

  static int _restylingStartYearForSort(_RestylingMeta? meta) {
    return meta?.yearStart ?? meta?.yearEnd ?? -1;
  }

  static int compareRestylingsByYearDesc(
    String make,
    String model,
    String a,
    String b,
  ) {
    final aMeta = restylingMetaFor(make, model, a);
    final bMeta = restylingMetaFor(make, model, b);
    final byEnd = _restylingEndYearForSort(
      bMeta,
    ).compareTo(_restylingEndYearForSort(aMeta));
    if (byEnd != 0) return byEnd;
    final byStart = _restylingStartYearForSort(
      bMeta,
    ).compareTo(_restylingStartYearForSort(aMeta));
    if (byStart != 0) return byStart;
    final byGeneration = (bMeta?.generation ?? -1).compareTo(
      aMeta?.generation ?? -1,
    );
    if (byGeneration != 0) return byGeneration;
    return a.compareTo(b);
  }

  static bool isModelsLoading(String make) {
    return modelsLoading[make] == true;
  }

  static bool isRestylingsLoading(String make, String model) {
    final brandId = brandIdByName[make];

    if (brandId == null) return false;

    return restylingsLoading[_modelKey(brandId, model)] == true;
  }
}

class AutoRequestScreen extends StatefulWidget {
  const AutoRequestScreen({super.key});

  @override
  State<AutoRequestScreen> createState() => _AutoRequestScreenState();
}

class _AutoRequestScreenState extends State<AutoRequestScreen>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,

      child: Scaffold(
        appBar: AppBar(
          title: const Text('Создание заявки'),

          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),

            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),

              child: Material(
                color: kWhiteColor,

                borderRadius: BorderRadius.circular(12),

                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(color: kBorderColor),
                  ),

                  child: TabBar(
                    indicator: BoxDecoration(
                      color: kSecondaryColor,

                      borderRadius: BorderRadius.circular(10),
                    ),

                    labelColor: kWhiteColor,

                    unselectedLabelColor: kSecondaryColor,

                    labelStyle: const TextStyle(
                      fontSize: 12,

                      fontWeight: FontWeight.w700,
                    ),

                    tabs: const [
                      Tab(text: 'По авто'),

                      Tab(text: 'Под ключ'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        body: GestureDetector(
          behavior: HitTestBehavior.translucent,

          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),

          child: TabBarView(children: [_ByCarForm(), _TurnkeyForm()]),
        ),
      ),
    );
  }
}

class _ByCarForm extends StatelessWidget {
  const _ByCarForm();

  @override
  Widget build(BuildContext context) {
    return _ByCarFormBody();
  }
}

class _SourceAdPreview {
  const _SourceAdPreview({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
}

class _ByCarFormBody extends StatefulWidget {
  @override
  State<_ByCarFormBody> createState() => _ByCarFormBodyState();
}

class _ByCarFormBodyState extends State<_ByCarFormBody> {
  static const int _maxCars = 5;

  final List<_CarItem> _cars = [_CarItem(id: _genId())];

  final Map<String, bool> _collapsed = {};

  final Map<String, bool> _manualOpen = {};
  final Map<String, List<_CollapsedRestylingOption>>
  _collapsedRestylingOptionsCache = {};
  final Map<String, Map<String, _CollapsedRestylingOption>>
  _collapsedRestylingLookupCache = {};
  final Map<String, Timer> _sourceParseDebounce = {};
  final Map<String, int> _sourceParseSeq = {};
  final Map<String, bool> _sourceParsing = {};
  final Map<String, bool> _sourceParseFailed = {};
  final Map<String, String> _sourceParseHint = {};
  final Map<String, _SourceAdPreview> _sourcePreview = {};
  final Map<String, TextEditingController> _sourceUrlControllers = {};
  bool _remoteRefreshScheduled = false;

  String _formError = '';
  bool _isSubmittingByCar = false;

  final Map<String, Map<String, String>> _carErrors = {};

  DateTime? _dueDate;
  final TextEditingController _dueDateController = TextEditingController();
  String _dueDateError = '';

  @override
  void initState() {
    super.initState();

    _collapsed[_cars.first.id] = false;
    _sourceUrlControllers[_cars.first.id] = TextEditingController(
      text: _cars.first.sourceUrl,
    );

    _RemoteCarCatalog.stamp.addListener(_handleRemoteUpdate);

    _RemoteCarCatalog.ensureBrands();
  }

  @override
  void dispose() {
    _RemoteCarCatalog.stamp.removeListener(_handleRemoteUpdate);
    for (final timer in _sourceParseDebounce.values) {
      timer.cancel();
    }
    _sourceParseDebounce.clear();
    _sourceParsing.clear();
    _sourceParseFailed.clear();
    _sourceParseHint.clear();
    _sourcePreview.clear();
    for (final c in _sourceUrlControllers.values) {
      c.dispose();
    }
    _sourceUrlControllers.clear();
    _dueDateController.dispose();

    super.dispose();
  }

  String _restylingCacheKey(String make, String model) {
    return '${make.trim()}|${model.trim()}';
  }

  void _clearCollapsedRestylingCache() {
    _collapsedRestylingOptionsCache.clear();
    _collapsedRestylingLookupCache.clear();
  }

  void _scheduleRemoteRefresh() {
    if (_remoteRefreshScheduled || !mounted) return;
    _remoteRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remoteRefreshScheduled = false;
      if (!mounted) return;
      setState(() {});
    });
  }

  void _handleRemoteUpdate() {
    if (!mounted) return;
    _clearCollapsedRestylingCache();
    _scheduleRemoteRefresh();
  }

  static String _genId() {
    final n = DateTime.now().millisecondsSinceEpoch;

    return 'CAR-${n % 1000000}-${n % 97}';
  }

  static String _stripSpaces(String s) {
    return s.replaceAll(' ', '').trim();
  }

  static String _digitsOnly(String s) {
    final t = _stripSpaces(s);

    final buffer = StringBuffer();

    for (final ch in t.split('')) {
      if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        buffer.write(ch);
      }
    }

    return buffer.toString();
  }

  void _onDueDateChanged(String value) {
    if (_dueDateError.isNotEmpty) {
      setState(() {
        _dueDateError = '';
      });
    }
    _dueDate = _tryParseRuDate(value);
  }

  bool _validateDueDate() {
    _dueDateError = '';
    final raw = _dueDateController.text.trim();
    if (raw.isEmpty) {
      _dueDate = null;
      return true;
    }
    final parsed = _tryParseRuDate(raw);
    if (parsed == null) {
      _dueDate = null;
      _dueDateError = 'Укажите дату в формате ДД.ММ.ГГГГ';
      return false;
    }
    _dueDate = parsed;
    return true;
  }

  static String _safeUrlHost(String url) {
    try {
      return Uri.parse(url).host.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static bool _isAllowedListingUrl(String url) {
    final t = url.trim();

    if (t.isEmpty) return false;

    final host = _safeUrlHost(t);

    if (host.isEmpty) return false;
    for (final domain in _allowedListingDomains) {
      final d = domain.toLowerCase();
      if (host == d || host.endsWith('.$d')) return true;
    }
    return false;
  }

  String _normalizeSourceUrlForParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    var normalized = trimmed;
    final hasScheme = RegExp(
      r'^[a-zA-Z][a-zA-Z0-9+.-]*://',
    ).hasMatch(normalized);
    if (!hasScheme) {
      if (!normalized.contains('.')) return '';
      normalized = 'https://$normalized';
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.trim().isEmpty) return '';
    return normalized;
  }

  _CarItem? _findCarById(String id) {
    for (final car in _cars) {
      if (car.id == id) return car;
    }
    return null;
  }

  TextEditingController _sourceUrlControllerFor(_CarItem item) {
    final controller = _sourceUrlControllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.sourceUrl),
    );
    if (controller.text != item.sourceUrl) {
      controller.text = item.sourceUrl;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
    return controller;
  }

  dynamic _mapValueByKey(Map<String, dynamic> map, String key) {
    if (map.containsKey(key)) return map[key];
    final lower = key.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  List<Map<String, dynamic>> _flattenMaps(dynamic raw) {
    final out = <Map<String, dynamic>>[];
    void walk(dynamic node) {
      if (node is Map) {
        final map = node.map((k, v) => MapEntry(k.toString(), v));
        out.add(map);
        for (final value in map.values) {
          walk(value);
        }
        return;
      }
      if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(raw);
    return out;
  }

  String _valueAsString(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is num || raw is bool) return raw.toString();
    if (raw is List) {
      for (final item in raw) {
        final text = _valueAsString(item);
        if (text.isNotEmpty) return text;
      }
      return '';
    }
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      for (final key in const [
        'nameRus',
        'name',
        'modelRus',
        'model',
        'make',
        'brand',
        'mark',
        'value',
        'title',
        'phone',
      ]) {
        final text = _valueAsString(_mapValueByKey(map, key));
        if (text.isNotEmpty) return text;
      }
      for (final value in map.values) {
        final text = _valueAsString(value);
        if (text.isNotEmpty) return text;
      }
      return '';
    }
    return raw.toString().trim();
  }

  String _normalizeLookup(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-я]'), '');
  }

  String _matchFromOptions(List<String> candidates, List<String> options) {
    if (options.isEmpty || candidates.isEmpty) return '';
    for (final candidate in candidates) {
      final c = candidate.trim();
      if (c.isEmpty) continue;
      final normalized = _normalizeLookup(c);
      for (final option in options) {
        final o = option.trim();
        if (o.isEmpty) continue;
        if (o.toLowerCase() == c.toLowerCase()) return option;
        final optionNormalized = _normalizeLookup(o);
        if (optionNormalized == normalized) return option;
        if (normalized.length >= 3 &&
            optionNormalized.length >= 3 &&
            (optionNormalized.contains(normalized) ||
                normalized.contains(optionNormalized))) {
          return option;
        }
        final hasAlphaNum = RegExp(
          r'(?=.*[a-zа-я])(?=.*\d)',
          caseSensitive: false,
        ).hasMatch(normalized);
        if (normalized.length >= 2 &&
            hasAlphaNum &&
            optionNormalized.contains(normalized)) {
          return option;
        }
      }
    }
    return '';
  }

  String _extractSourceSlug(String sourceUrl) {
    try {
      final uri = Uri.parse(sourceUrl.trim());
      final segments = uri.pathSegments
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (segments.isEmpty) return '';
      return segments.last;
    } catch (_) {
      return '';
    }
  }

  String _resolveMakeFromSourceUrl(String sourceUrl, List<String> options) {
    if (options.isEmpty) return '';
    final slug = _extractSourceSlug(sourceUrl);
    if (slug.isEmpty) return '';
    final slugNormalized = _normalizeLookup(slug);
    if (slugNormalized.isEmpty) return '';

    var best = '';
    var bestLen = 0;
    for (final option in options) {
      final optionNormalized = _normalizeLookup(option);
      if (optionNormalized.isEmpty) continue;
      final rusNormalized = _normalizeLookup(
        _RemoteCarCatalog.brandRusByName[option] ?? '',
      );
      final matches =
          slugNormalized.startsWith(optionNormalized) ||
          (rusNormalized.isNotEmpty &&
              slugNormalized.startsWith(rusNormalized));
      if (!matches) continue;
      final len = optionNormalized.length;
      if (len > bestLen) {
        bestLen = len;
        best = option;
      }
    }
    return best;
  }

  String _resolveModelFromSourceUrl(
    String sourceUrl,
    String make,
    List<String> options,
  ) {
    if (make.trim().isEmpty || options.isEmpty) return '';
    final slug = _extractSourceSlug(sourceUrl);
    if (slug.isEmpty) return '';
    final slugNormalized = _normalizeLookup(slug);
    if (slugNormalized.isEmpty) return '';

    var remainder = slugNormalized;
    final aliases = <String>[
      _normalizeLookup(make),
      _normalizeLookup(_RemoteCarCatalog.brandRusByName[make] ?? ''),
    ].where((e) => e.isNotEmpty).toList();
    for (final alias in aliases) {
      if (remainder.startsWith(alias)) {
        remainder = remainder.substring(alias.length);
        break;
      }
    }

    var best = '';
    var bestLen = 0;
    for (final option in options) {
      final optionNormalized = _normalizeLookup(option);
      if (optionNormalized.isEmpty) continue;
      final matches =
          remainder.startsWith(optionNormalized) ||
          slugNormalized.contains(optionNormalized);
      if (!matches) continue;
      final len = optionNormalized.length;
      if (len > bestLen) {
        bestLen = len;
        best = option;
      }
    }
    return best;
  }

  String _resolveParsedMake(
    Map<String, dynamic> parsed, {
    String sourceUrl = '',
  }) {
    final maps = _flattenMaps(parsed);
    final candidates = <String>[];
    for (final map in maps) {
      for (final key in const [
        'make',
        'makeName',
        'brand',
        'brandName',
        'mark',
        'markName',
        'carMake',
        'carBrand',
        'name',
        'nameRus',
        'title',
        'carTitle',
        'offerTitle',
      ]) {
        final value = _valueAsString(_mapValueByKey(map, key));
        if (value.isNotEmpty && !candidates.contains(value)) {
          candidates.add(value);
        }
      }
    }
    final options = _RemoteCarCatalog.makes();
    final matched = _matchFromOptions(candidates, options);
    if (matched.isNotEmpty) return matched;

    for (final candidate in candidates) {
      final normalized = _normalizeLookup(candidate);
      for (final option in options) {
        final rus = _RemoteCarCatalog.brandRusByName[option] ?? '';
        if (rus.isEmpty) continue;
        if (_normalizeLookup(rus) == normalized) return option;
      }
    }

    final byUrl = _resolveMakeFromSourceUrl(sourceUrl, options);
    if (byUrl.isNotEmpty) return byUrl;

    return '';
  }

  List<String> _expandModelCandidates(
    List<String> rawCandidates,
    List<String> makeAliases,
  ) {
    final out = <String>[];
    final seen = <String>{};

    void addCandidate(String value) {
      final text = value.trim();
      if (text.isEmpty) return;
      if (seen.add(text)) out.add(text);
    }

    final aliasRegexes = makeAliases
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(
          (alias) =>
              RegExp('\\b${RegExp.escape(alias)}\\b', caseSensitive: false),
        )
        .toList();

    for (final raw in rawCandidates) {
      addCandidate(raw);
      var cleaned = raw.trim();
      if (cleaned.isEmpty) continue;

      for (final rx in aliasRegexes) {
        cleaned = cleaned.replaceAll(rx, ' ');
      }
      cleaned = cleaned.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ');
      cleaned = cleaned.replaceAll(
        RegExp(
          r'\b(поколение|рестайлинг|generation|gen|кузов|body)\b',
          caseSensitive: false,
        ),
        ' ',
      );
      cleaned = cleaned.replaceAll(RegExp(r'[_|/,:;()\[\]\-]+'), ' ');
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
      addCandidate(cleaned);

      final parts = cleaned
          .split(' ')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (var i = 0; i < parts.length; i++) {
        for (var len = 1; len <= 3 && i + len <= parts.length; len++) {
          addCandidate(parts.sublist(i, i + len).join(' '));
        }
      }
    }

    return out;
  }

  String _resolveParsedModel(
    Map<String, dynamic> parsed,
    String make, {
    String sourceUrl = '',
  }) {
    final maps = _flattenMaps(parsed);
    final candidates = <String>[];
    for (final map in maps) {
      for (final key in const [
        'model',
        'modelName',
        'modelRus',
        'model_name',
        'modelCar',
        'model_car',
        'autoModel',
        'vehicleModel',
        'carModel',
        'carModelName',
        'series',
        'nameFull',
        'title',
        'carTitle',
        'offerTitle',
        'name',
        'nameRus',
      ]) {
        final value = _valueAsString(_mapValueByKey(map, key));
        if (value.isNotEmpty && !candidates.contains(value)) {
          candidates.add(value);
        }
      }
    }
    final options = _RemoteCarCatalog.modelsFor(make);
    if (options.isEmpty) return '';

    final direct = _matchFromOptions(candidates, options);
    if (direct.isNotEmpty) return direct;

    final expanded = _expandModelCandidates(candidates, [
      make,
      _RemoteCarCatalog.brandRusByName[make] ?? '',
    ]);
    final fromExpanded = _matchFromOptions(expanded, options);
    if (fromExpanded.isNotEmpty) return fromExpanded;

    final byUrl = _resolveModelFromSourceUrl(sourceUrl, make, options);
    if (byUrl.isNotEmpty) return byUrl;

    return '';
  }

  String _extractFromMaps(Map<String, dynamic> parsed, List<String> keys) {
    final maps = _flattenMaps(parsed);
    for (final map in maps) {
      for (final key in keys) {
        final value = _valueAsString(_mapValueByKey(map, key));
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  bool _looksLikeImageUrl(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return false;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return false;
    }
    final clean = value.split('?').first;
    if (clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.bmp')) {
      return true;
    }
    return clean.contains('/image') ||
        clean.contains('/images/') ||
        clean.contains('/photo') ||
        clean.contains('/photos/');
  }

  String _extractImageFromAny(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) {
      return _looksLikeImageUrl(raw) ? raw.trim() : '';
    }
    if (raw is List) {
      for (final item in raw) {
        final url = _extractImageFromAny(item);
        if (url.isNotEmpty) return url;
      }
      return '';
    }
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      for (final key in const [
        'urlX2',
        'urlX1',
        'imageUrl',
        'photoUrl',
        'src',
        'preview',
        'image',
        'photo',
        'images',
        'photos',
      ]) {
        final url = _extractImageFromAny(_mapValueByKey(map, key));
        if (url.isNotEmpty) return url;
      }
      return '';
    }
    return '';
  }

  String _formatPriceLabel(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final value = int.tryParse(digits);
    if (value == null) return '';
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$text ₽';
  }

  _SourceAdPreview _buildSourcePreview(
    Map<String, dynamic> parsed,
    String sourceUrl, {
    required String resolvedMake,
    required String resolvedModel,
  }) {
    final host = _shortListingLabel(sourceUrl);
    final titleFromParsed = _extractFromMaps(parsed, const [
      'title',
      'name',
      'carTitle',
      'caption',
      'description',
    ]);
    final title = [
      resolvedMake,
      resolvedModel,
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();
    final year = _extractFromMaps(parsed, const [
      'year',
      'carYear',
      'productionYear',
      'modelYear',
    ]);
    final priceRaw = _extractFromMaps(parsed, const [
      'price',
      'cost',
      'amount',
      'finalPrice',
    ]);
    final price = _formatPriceLabel(priceRaw);
    final subtitleParts = <String>[
      if (year.trim().isNotEmpty) year.trim(),
      if (price.isNotEmpty) price,
      host,
    ];
    final imageUrl = _extractImageFromAny(parsed);
    return _SourceAdPreview(
      title: title.isNotEmpty
          ? title
          : (titleFromParsed.isNotEmpty ? titleFromParsed : host),
      subtitle: subtitleParts.where((e) => e.isNotEmpty).join(' • '),
      imageUrl: imageUrl,
    );
  }

  String _extractParsedPhone(Map<String, dynamic> parsed) {
    final maps = _flattenMaps(parsed);
    for (final map in maps) {
      for (final key in const [
        'phone',
        'sellerPhone',
        'phoneNumber',
        'contactPhone',
      ]) {
        final raw = _valueAsString(_mapValueByKey(map, key));
        if (raw.isEmpty) continue;
        final digits = _digitsOnly(raw);
        if (digits.length == 10) return '+7$digits';
        if (digits.length == 11) {
          if (digits.startsWith('8')) return '+7${digits.substring(1)}';
          if (digits.startsWith('7')) return '+$digits';
        }
      }
    }
    return '';
  }

  Future<void> _parseSourceUrlAndAutofill(
    String carId,
    String url,
    int seq,
  ) async {
    Map<String, dynamic> parsed;
    try {
      parsed = await StorageApi.parseCarSourceUrl(url: url);
    } catch (_) {
      if (!mounted || _sourceParseSeq[carId] != seq) return;
      setState(() {
        _sourceParsing[carId] = false;
        _sourceParseFailed[carId] = true;
        _sourceParseHint[carId] = 'Не удалось получить данные по ссылке';
      });
      return;
    }

    if (!mounted || _sourceParseSeq[carId] != seq) return;
    final current = _findCarById(carId);
    if (current == null) return;
    final currentUrl = _normalizeSourceUrlForParse(current.sourceUrl);
    if (currentUrl != url) return;

    await _RemoteCarCatalog.ensureBrands();
    if (!mounted || _sourceParseSeq[carId] != seq) return;
    final afterBrands = _findCarById(carId);
    if (afterBrands == null) return;
    if (_normalizeSourceUrlForParse(afterBrands.sourceUrl) != url) return;

    final parsedMake = _resolveParsedMake(parsed, sourceUrl: url);
    var make = current.make;
    var updated = false;
    if (parsedMake.isNotEmpty && parsedMake != make) {
      _setCarPatch(carId, _CarItemPatch(make: parsedMake));
      make = parsedMake;
      updated = true;
    }

    if (make.isNotEmpty) {
      await _RemoteCarCatalog.ensureModels(make);
    }

    if (!mounted || _sourceParseSeq[carId] != seq) return;
    final afterMake = _findCarById(carId);
    if (afterMake == null) return;
    if (_normalizeSourceUrlForParse(afterMake.sourceUrl) != url) return;
    make = afterMake.make;

    final parsedModel = make.isNotEmpty
        ? _resolveParsedModel(parsed, make, sourceUrl: url)
        : '';
    var model = afterMake.model;
    if (parsedModel.isNotEmpty && parsedModel != model) {
      _setCarPatch(carId, _CarItemPatch(model: parsedModel));
      model = parsedModel;
      updated = true;
    }

    if (make.isNotEmpty && model.isNotEmpty) {
      await _RemoteCarCatalog.ensureRestylings(make, model);
    }

    if (!mounted || _sourceParseSeq[carId] != seq) return;
    final afterModel = _findCarById(carId);
    if (afterModel == null) return;
    if (_normalizeSourceUrlForParse(afterModel.sourceUrl) != url) return;

    final parsedPhone = _extractParsedPhone(parsed);
    if (parsedPhone.isNotEmpty) {
      final latest = _findCarById(carId);
      if (latest != null && latest.sellerPhone.trim().isEmpty) {
        _setCarPatch(carId, _CarItemPatch(sellerPhone: parsedPhone));
      }
    }

    final latest = _findCarById(carId);
    final hasResolvedMake = (latest?.make.trim().isNotEmpty ?? false);
    final hasResolvedModel = (latest?.model.trim().isNotEmpty ?? false);
    final hasBoth = hasResolvedMake && hasResolvedModel;
    final preview = _buildSourcePreview(
      parsed,
      url,
      resolvedMake: latest?.make ?? '',
      resolvedModel: latest?.model ?? '',
    );

    setState(() {
      _sourceParsing[carId] = false;
      _sourceParseFailed[carId] = !hasBoth && !updated;
      _sourcePreview[carId] = preview;
      if (hasBoth) {
        _sourceParseHint[carId] = 'Марка и модель заполнены по ссылке';
      } else if (updated || parsedPhone.isNotEmpty) {
        _sourceParseHint[carId] =
            'Данные частично получены, проверьте марку и модель';
      } else {
        _sourceParseHint[carId] = 'Не удалось распознать марку и модель';
      }
    });
  }

  void _scheduleParseSourceUrl(String carId, String rawUrl) {
    _sourceParseDebounce.remove(carId)?.cancel();
    final seq = (_sourceParseSeq[carId] ?? 0) + 1;
    _sourceParseSeq[carId] = seq;
    final url = _normalizeSourceUrlForParse(rawUrl);
    if (url.isEmpty) {
      setState(() {
        _sourceParsing.remove(carId);
        _sourceParseFailed.remove(carId);
        _sourceParseHint.remove(carId);
        _sourcePreview.remove(carId);
      });
      return;
    }
    setState(() {
      _sourceParsing[carId] = true;
      _sourceParseFailed[carId] = false;
      _sourceParseHint[carId] = 'Получаем данные по ссылке...';
      _sourcePreview.remove(carId);
    });
    _sourceParseDebounce[carId] = Timer(const Duration(milliseconds: 120), () {
      _sourceParseDebounce.remove(carId);
      _parseSourceUrlAndAutofill(carId, url, seq);
    });
  }

  String _restylingDisplayFor(String make, String model, String restyling) {
    if (restyling.trim().isEmpty) return '';

    final collapsed = _collapsedRestylingOptionFor(make, model, restyling);
    if (collapsed != null) {
      return collapsed.card.title;
    }

    final data = _buildRestylingCardDataFor(make, model, restyling);

    return data.title;
  }

  List<int> _restylingIdsForCar(_CarItem car) {
    final grouped = _collapsedRestylingOptionFor(
      car.make,
      car.model,
      car.restyling,
    );
    if (grouped != null && grouped.restylingIds.isNotEmpty) {
      return grouped.restylingIds;
    }
    final id = _RemoteCarCatalog.restylingIdFor(
      car.make,
      car.model,
      car.restyling,
    );
    if (id == null || id <= 0) return const [];
    return [id];
  }

  _CollapsedRestylingOption? _collapsedRestylingOptionFor(
    String make,
    String model,
    String restyling,
  ) {
    final target = restyling.trim();
    if (target.isEmpty || make.trim().isEmpty || model.trim().isEmpty) {
      return null;
    }
    final cacheKey = _restylingCacheKey(make, model);
    var lookup = _collapsedRestylingLookupCache[cacheKey];
    if (lookup == null) {
      final options = _collapsedRestylingOptionsFor(make, model);
      final next = <String, _CollapsedRestylingOption>{};
      for (final option in options) {
        for (final value in option.values) {
          final normalized = value.trim();
          if (normalized.isEmpty) continue;
          next[normalized] = option;
        }
      }
      _collapsedRestylingLookupCache[cacheKey] = next;
      lookup = next;
    }
    return lookup[target];
  }

  List<_CollapsedRestylingOption> _collapsedRestylingOptionsFor(
    String make,
    String model,
  ) {
    final cacheKey = _restylingCacheKey(make, model);
    final cached = _collapsedRestylingOptionsCache[cacheKey];
    if (cached != null) return cached;

    final rawOptions = _RemoteCarCatalog.restylingsFor(make, model);
    if (rawOptions.isEmpty) {
      const empty = <_CollapsedRestylingOption>[];
      _collapsedRestylingOptionsCache[cacheKey] = empty;
      _collapsedRestylingLookupCache.remove(cacheKey);
      return empty;
    }

    final groups = <_CollapsedRestylingGroup>[];

    for (final rawValue in rawOptions) {
      final value = rawValue.trim();
      if (value.isEmpty) continue;
      final meta = _RemoteCarCatalog.restylingMetaFor(make, model, value);
      final generation = meta?.generation ?? 0;
      final range = _PickerYearRange(
        start: meta?.yearStart,
        end: meta?.yearEnd,
        label: _formatYears(meta?.yearStart, meta?.yearEnd),
      );
      final restLabel = _normalizeRestylingLabel(meta?.restylingLabel ?? value);
      final modifications = (meta?.frames ?? const <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final imageUrl = _RemoteCarCatalog.restylingPhotoFor(make, model, value);
      final restylingId = _RemoteCarCatalog.restylingIdFor(make, model, value);

      _CollapsedRestylingGroup? target;
      for (final group in groups) {
        if (group.generation != generation) continue;
        if (group.ranges.isEmpty || range.isUnknown) {
          target = group;
          break;
        }
        if (group.ranges.any((r) => _pickerRangesOverlap(r, range))) {
          target = group;
          break;
        }
      }

      target ??= _CollapsedRestylingGroup(generation: generation);
      if (!groups.contains(target)) groups.add(target);
      target.addValue(value);
      target.addRange(range);
      target.addRestyling(restLabel);
      target.addModifications(modifications);
      target.addImageUrl(imageUrl);
      if (restylingId != null && restylingId > 0) {
        target.addRestylingId(restylingId);
      }
    }

    final options = <_CollapsedRestylingOption>[];
    for (final group in groups) {
      final values = group.values;
      if (values.isEmpty) continue;
      final years = group.sortedYearLabels();
      final restylings = group.sortedRestylings();
      final modifications = group.sortedModifications();
      final title = years.isNotEmpty
          ? years.join(', ')
          : _fallbackRestylingTitle(
              restylings.isNotEmpty ? restylings.first : values.first,
            );
      final lines = <String>[];
      if (group.generation > 0) {
        lines.add('Поколение: ${group.generation}');
      }
      if (restylings.isNotEmpty) {
        lines.add('Рестайлинг: ${restylings.join(', ')}');
      }
      if (modifications.isNotEmpty) {
        lines.add('Модификация: ${modifications.join(', ')}');
      }
      options.add(
        _CollapsedRestylingOption(
          value: values.first,
          values: values,
          restylingIds: group.restylingIds,
          card: _RestylingCardData(
            value: values.first,
            title: title,
            subtitle: lines.join('\n'),
            imageUrl: group.imageUrl,
          ),
        ),
      );
    }

    options.sort((a, b) {
      final aKey = _collapsedSortKeyFor(a);
      final bKey = _collapsedSortKeyFor(b);
      final byStart = bKey.start.compareTo(aKey.start);
      if (byStart != 0) return byStart;
      final byGeneration = bKey.generation.compareTo(aKey.generation);
      if (byGeneration != 0) return byGeneration;
      return a.card.title.compareTo(b.card.title);
    });

    _collapsedRestylingOptionsCache[cacheKey] = options;
    _collapsedRestylingLookupCache.remove(cacheKey);
    return options;
  }

  _CollapsedSortKey _collapsedSortKeyFor(_CollapsedRestylingOption option) {
    final generationMatch = RegExp(
      r'Поколение:\s*(\d+)',
    ).firstMatch(option.card.subtitle);
    final generation = int.tryParse(generationMatch?.group(1) ?? '') ?? 0;
    final yearMatch = RegExp(r'(\d{4})').firstMatch(option.card.title);
    final start = int.tryParse(yearMatch?.group(1) ?? '') ?? -1;
    return _CollapsedSortKey(generation: generation, start: start);
  }

  bool _pickerRangesOverlap(_PickerYearRange a, _PickerYearRange b) {
    if (a.isUnknown || b.isUnknown) return true;
    final aStart = a.start ?? a.end!;
    final aEnd = a.end ?? a.start!;
    final bStart = b.start ?? b.end!;
    final bEnd = b.end ?? b.start!;
    return aStart <= bEnd && bStart <= aEnd;
  }

  String _normalizeRestylingLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value == '0' || value == 'Без рестайлинга') return 'стартовый';
    return value;
  }

  List<Map<String, dynamic>> _restylingDisplayEntriesFor(
    String make,
    String model,
    String restyling,
  ) {
    final out = <Map<String, dynamic>>[];
    final option = _collapsedRestylingOptionFor(make, model, restyling);
    final values = option?.values ?? [restyling.trim()];
    final seen = <String>{};

    for (final rawValue in values) {
      final value = rawValue.trim();
      if (value.isEmpty || !seen.add(value)) continue;
      final meta = _RemoteCarCatalog.restylingMetaFor(make, model, value);
      final photoUrls = _RemoteCarCatalog.restylingPhotoUrlsFor(
        make,
        model,
        value,
      );
      final entry = <String, dynamic>{};
      if (meta != null) {
        if (meta.generation > 0) entry['generation'] = meta.generation;
        if (meta.yearStart != null) entry['yearStart'] = meta.yearStart;
        if (meta.yearEnd != null) entry['yearEnd'] = meta.yearEnd;
        final frames = meta.frames
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (frames.isNotEmpty) entry['frames'] = frames;
        final normalizedRest = _normalizeRestylingLabel(meta.restylingLabel);
        if (normalizedRest.isNotEmpty) entry['restyling'] = normalizedRest;
      } else {
        final normalizedRest = _normalizeRestylingLabel(value);
        if (normalizedRest.isNotEmpty) entry['restyling'] = normalizedRest;
      }
      if (photoUrls.isNotEmpty) {
        final cover = photoUrls.first;
        entry['photoUrl'] = cover;
        entry['photos'] = [
          for (int i = 0; i < photoUrls.length; i++)
            {
              'size': i == 0 ? 'l' : 'm',
              'url': photoUrls[i],
              'urlX1': photoUrls[i],
              'urlX2': photoUrls[i],
            },
        ];
      }
      if (entry.isNotEmpty) out.add(entry);
    }

    return out;
  }

  static bool _isCarEmpty(_CarItem c) {
    final fields = [
      c.sourceUrl.trim(),

      c.sellerPhone.trim(),

      c.note?.trim() ?? '',

      c.make.trim(),

      c.model.trim(),

      c.restyling.trim(),
    ];

    return fields.every((v) => v.isEmpty);
  }

  void _toggleCollapsed(String id) {
    setState(() {
      _collapsed[id] = !(_collapsed[id] ?? false);
    });
  }

  void _toggleManual(String id) {
    setState(() {
      _manualOpen[id] = !(_manualOpen[id] ?? false);
    });
  }

  void _addCar() {
    if (_cars.length >= _maxCars) return;

    setState(() {
      final id = _genId();

      _cars.add(_CarItem(id: id));
      _sourceUrlControllers[id] = TextEditingController();

      _collapsed[id] = false;
    });
  }

  void _removeCar(String id) {
    _sourceParseDebounce.remove(id)?.cancel();
    _sourceParseSeq.remove(id);
    _sourceParsing.remove(id);
    _sourceParseFailed.remove(id);
    _sourceParseHint.remove(id);
    _sourcePreview.remove(id);
    _sourceUrlControllers.remove(id)?.dispose();
    setState(() {
      _cars.removeWhere((c) => c.id == id);

      _collapsed.remove(id);

      _manualOpen.remove(id);

      _carErrors.remove(id);
    });
  }

  void _setCarPatch(String id, _CarItemPatch patch) {
    if (patch.make != null || patch.model != null) {
      _clearCollapsedRestylingCache();
    }
    if (patch.sourceUrl != null) {
      _scheduleParseSourceUrl(id, patch.sourceUrl ?? '');
    }
    setState(() {
      for (int i = 0; i < _cars.length; i++) {
        if (_cars[i].id != id) continue;

        final next = _cars[i].copyWith(patch);

        if (patch.make != null) {
          _cars[i] = next.copyWith(_CarItemPatch(model: '', restyling: ''));

          final make = patch.make ?? '';

          if (make.isNotEmpty) {
            _RemoteCarCatalog.ensureModels(make);
          }

          return;
        }

        if (patch.model != null) {
          _cars[i] = next.copyWith(_CarItemPatch(restyling: ''));

          final make = next.make;

          final model = patch.model ?? '';

          if (make.isNotEmpty && model.isNotEmpty) {
            _RemoteCarCatalog.ensureRestylings(make, model);
          }

          return;
        }

        _cars[i] = next;
        if (patch.sourceUrl != null) {
          final controller = _sourceUrlControllers[id];
          if (controller != null && controller.text != next.sourceUrl) {
            controller.text = next.sourceUrl;
            controller.selection = TextSelection.collapsed(
              offset: controller.text.length,
            );
          }
        }

        return;
      }
    });
  }

  bool _validateCars() {
    _formError = '';

    _carErrors.clear();
    final dueDateValid = _validateDueDate();

    final activeCars = _cars.where((c) => !_isCarEmpty(c)).toList();

    if (activeCars.isEmpty) {
      _formError =
          '\u0414\u043E\u0431\u0430\u0432\u044C\u0442\u0435 \u0445\u043E\u0442\u044F \u0431\u044B \u043E\u0434\u0438\u043D \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C';
    }

    if (activeCars.length > _maxCars) {
      _formError =
          '\u041C\u043E\u0436\u043D\u043E \u0434\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u043D\u0435 \u0431\u043E\u043B\u0435\u0435 $_maxCars \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0435\u0439';
    }

    final List<String> toOpen = [];

    for (final c in _cars) {
      if (_isCarEmpty(c)) continue;

      final Map<String, String> ce = {};

      final url = c.sourceUrl.trim();

      final phoneDigits = _digitsOnly(c.sellerPhone);

      final hasPhone = phoneDigits.isNotEmpty;

      final hasUrl = url.isNotEmpty;

      if (hasUrl && !_isAllowedListingUrl(url)) {
        ce['sourceUrl'] =
            '\u0421\u0441\u044B\u043B\u043A\u0430 \u0434\u043E\u043B\u0436\u043D\u0430 \u0431\u044B\u0442\u044C \u0441 avito.ru, drom.ru \u0438\u043B\u0438 auto.ru';
      }

      if (!hasUrl) {
        toOpen.add(c.id);

        if (!hasPhone) {
          ce['sellerPhone'] =
              '\u0423\u043A\u0430\u0436\u0438\u0442\u0435 \u043D\u043E\u043C\u0435\u0440 \u0442\u0435\u043B\u0435\u0444\u043E\u043D\u0430 \u0438\u043B\u0438 \u0434\u043E\u0431\u0430\u0432\u044C\u0442\u0435 \u0441\u0441\u044B\u043B\u043A\u0443';
          ce['sourceUrl'] =
              '\u0415\u0441\u043B\u0438 \u043D\u0435\u0442 \u0442\u0435\u043B\u0435\u0444\u043E\u043D\u0430, \u0434\u043E\u0431\u0430\u0432\u044C\u0442\u0435 \u0441\u0441\u044B\u043B\u043A\u0443 \u043D\u0430 \u0440\u0435\u0441\u0443\u0440\u0441';
        } else if (phoneDigits.length < 11) {
          ce['sellerPhone'] =
              '\u0422\u0435\u043B\u0435\u0444\u043E\u043D \u0441\u043B\u0438\u0448\u043A\u043E\u043C \u043A\u043E\u0440\u043E\u0442\u043A\u0438\u0439';
        }

        if (c.make.trim().isEmpty) {
          ce['make'] =
              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443 (\u0435\u0441\u043B\u0438 \u043D\u0435\u0442 \u0441\u0441\u044B\u043B\u043A\u0438)';
        }

        if (c.model.trim().isEmpty) {
          ce['model'] =
              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C (\u0435\u0441\u043B\u0438 \u043D\u0435\u0442 \u0441\u0441\u044B\u043B\u043A\u0438)';
        }
      }

      if (ce.isNotEmpty) _carErrors[c.id] = ce;
    }

    for (final id in toOpen) {
      _manualOpen[id] = true;
    }

    if (_formError.isEmpty && _carErrors.isNotEmpty) {
      _formError = 'Исправьте ошибки в данных автомобиля.';
    }
    if (_formError.isEmpty && !dueDateValid) {
      _formError = 'Проверьте дату: ДД.ММ.ГГГГ';
    }

    setState(() {});

    return _formError.isEmpty && _carErrors.isEmpty && dueDateValid;
  }

  Future<void> _submitByCar() async {
    if (_isSubmittingByCar) return;
    if (!_validateCars()) return;

    final activeCars = _cars.where((c) => !_isCarEmpty(c)).toList();
    if (activeCars.isEmpty) return;

    setState(() {
      _isSubmittingByCar = true;
      _formError = '';
    });

    final dueAt = _dueDate == null ? null : _formatDateIso(_dueDate!);
    final requestCars = activeCars.map((c) {
      final phone = c.sellerPhone.trim();
      final url = c.sourceUrl.trim();
      final note = c.note?.trim() ?? '';
      return {
        'restylings': _restylingIdsForCar(c),
        'phone': phone.isEmpty ? null : phone,
        'url': url.isEmpty ? null : url,
        if (note.isNotEmpty) 'note': note,
        if (dueAt != null) 'dueAt': dueAt,
      };
    }).toList();
    final displayCars = activeCars.map((c) {
      final restDisplay = _restylingDisplayFor(c.make, c.model, c.restyling);
      final phone = c.sellerPhone.trim();
      final url = c.sourceUrl.trim();
      final note = c.note?.trim() ?? '';
      final restylingEntries = _restylingDisplayEntriesFor(
        c.make,
        c.model,
        c.restyling,
      );
      final photoUrls = _RemoteCarCatalog.restylingPhotoUrlsFor(
        c.make,
        c.model,
        c.restyling,
      );
      final photoUrl = photoUrls.isNotEmpty ? photoUrls.first : '';
      return {
        'make': c.make,
        'makeName': c.make,
        'brandName': c.make,
        'model': c.model,
        'modelName': c.model,
        'modelRus': c.model,
        if (restylingEntries.isNotEmpty) 'restylings': restylingEntries,
        if (restylingEntries.isEmpty && c.restyling.trim().isNotEmpty)
          'restyling': c.restyling,
        if (restDisplay.trim().isNotEmpty) 'restylingName': restDisplay.trim(),
        if (photoUrl.isNotEmpty) 'photoUrl': photoUrl,
        if (photoUrls.isNotEmpty)
          'photos': [
            for (int i = 0; i < photoUrls.length; i++)
              {
                'size': i == 0 ? 'l' : 'm',
                'url': photoUrls[i],
                'urlX1': photoUrls[i],
                'urlX2': photoUrls[i],
              },
          ],
        if (phone.isNotEmpty) 'phone': phone,
        if (url.isNotEmpty) 'url': url,
        if (note.isNotEmpty) 'note': note,
        if (dueAt != null) 'dueAt': dueAt,
      };
    }).toList();

    try {
      final result = await StorageApi.createRequest(
        requestType: 'by_car',
        requestCars: requestCars,
        dueAt: dueAt,
      );
      final override = <String, dynamic>{'requestCars': displayCars};
      if (result.id > 0) {
        await UserSimplePreferences.setRequestDisplayOverride(
          result.id.toString(),
          override,
        );
      }
      if (result.requestNumber.trim().isNotEmpty) {
        await UserSimplePreferences.setRequestDisplayOverride(
          result.requestNumber.trim(),
          override,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(<String, dynamic>{
        'created': true,
        'requestId': result.id,
        'requestNumber': result.requestNumber,
      });
    } catch (e) {
      final raw = e.toString().trim();
      final cleaned = raw
          .replaceFirst('Exception:', '')
          .replaceFirst('Bad response', '')
          .trim();
      if (mounted) {
        setState(() {
          _formError = cleaned.isNotEmpty
              ? cleaned
              : 'Не удалось отправить заявку. Проверьте данные и попробуйте еще раз.';
        });
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingByCar = false;
        });
      }
    }
  }

  List<String> _withHint(
    String hint,
    List<String> options,
    String selected, {
    bool loading = false,
  }) {
    final list = <String>[];
    final seen = <String>{};

    void addUnique(String value) {
      if (value.isEmpty) return;
      if (seen.add(value)) list.add(value);
    }

    addUnique(hint);

    if (options.isNotEmpty) {
      for (final opt in options) {
        if (opt != hint) addUnique(opt);
      }
    } else if (loading) {
      addUnique('Загрузка...');
    }

    if (selected.isNotEmpty) addUnique(selected);
    return list;
  }

  Future<void> _openRestylingPickerForCar(_CarItem car) async {
    if (car.make.trim().isEmpty || car.model.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите марку и модель.')),
      );

      return;
    }

    _RemoteCarCatalog.ensureRestylings(car.make, car.model);

    String query = '';

    await showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: kWhiteColor,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final media = MediaQuery.of(ctx);

            final sheetHeight = (media.size.height - media.padding.top) * 0.88;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 120),

              curve: Curves.easeOut,

              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),

              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

                  child: SizedBox(
                    height: sheetHeight,

                    child: Column(
                      mainAxisSize: MainAxisSize.max,

                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MyText(
                                text: 'Поколение',

                                size: 16,

                                weight: FontWeight.w700,
                              ),
                            ),

                            IconButton(
                              onPressed: () => Navigator.pop(ctx),

                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          onChanged: (v) => setSheet(() => query = v),

                          decoration: InputDecoration(
                            hintText: 'Найти...',

                            prefixIcon: const Icon(Icons.search, size: 18),

                            filled: true,

                            fillColor: kWhiteColor,

                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,

                              vertical: 10,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),

                              borderSide: BorderSide(color: kBorderColor),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),

                              borderSide: BorderSide(color: kSecondaryColor),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Expanded(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _RemoteCarCatalog.stamp,

                            builder: (ctx, _, _) {
                              final options = _RemoteCarCatalog.restylingsFor(
                                car.make,

                                car.model,
                              );

                              final items = options.isEmpty
                                  ? const <_CollapsedRestylingOption>[]
                                  : _collapsedRestylingOptionsFor(
                                          car.make,
                                          car.model,
                                        )
                                        .where(
                                          (item) => _matchesRestylingQuery(
                                            item.card,
                                            query,
                                          ),
                                        )
                                        .toList();

                              final loading =
                                  _RemoteCarCatalog.isRestylingsLoading(
                                    car.make,

                                    car.model,
                                  );

                              if (items.isEmpty && loading) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }

                              if (items.isEmpty) {
                                return const Center(
                                  child: MyText(
                                    text: 'Ничего не найдено',

                                    size: 12,

                                    color: kGreyColor,
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.only(bottom: 6),

                                itemCount: items.length,

                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),

                                itemBuilder: (context, index) {
                                  final data = items[index];

                                  final selected = data.values.contains(
                                    car.restyling,
                                  );

                                  return SizedBox(
                                    width: double.infinity,

                                    child: _RestylingCard(
                                      title: data.card.title,

                                      subtitle: data.card.subtitle,

                                      imageUrl: data.card.imageUrl,

                                      selected: selected,

                                      onTap: () {
                                        Navigator.pop(ctx);

                                        _setCarPatch(
                                          car.id,

                                          _CarItemPatch(restyling: data.value),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);

                                  _setCarPatch(
                                    car.id,

                                    _CarItemPatch(restyling: ''),
                                  );
                                },

                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: kSecondaryColor),

                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),

                                child: const Text(
                                  'Сбросить',

                                  style: TextStyle(color: kSecondaryColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _looksNumericCode(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return false;

    return RegExp(r'^\d+$').hasMatch(trimmed);
  }

  _RestylingCardData _buildRestylingCardDataFor(
    String make,

    String model,

    String rest,
  ) {
    final meta = _RemoteCarCatalog.restylingMetaFor(make, model, rest);

    final imageUrl = _RemoteCarCatalog.restylingPhotoFor(make, model, rest);

    final years = _formatYears(meta?.yearStart, meta?.yearEnd);

    final baseRestLabel = meta?.restylingLabel ?? rest;
    final restLabel =
        baseRestLabel ==
            '\u0411\u0435\u0437 \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433\u0430'
        ? ''
        : baseRestLabel;

    final frames = meta?.frames ?? const <String>[];

    final codes = <String>{};

    for (final code in frames) {
      final trimmed = code.trim();

      if (trimmed.isNotEmpty) {
        codes.add(trimmed);
      }
    }

    if (restLabel.isNotEmpty &&
        !_looksNumericCode(restLabel) &&
        !codes.contains(restLabel)) {
      codes.add(restLabel);
    }

    final codesText = codes.isEmpty ? '' : codes.join(', ');

    final titleParts = <String>[];

    if (years.isNotEmpty) titleParts.add(years);

    if (codesText.isNotEmpty) titleParts.add(codesText);

    final title = titleParts.join(', ');

    String subtitle = '';

    if (meta != null && meta.generation > 0) {
      subtitle = 'Поколение ${meta.generation}';

      if (restLabel.isNotEmpty) {
        subtitle +=
            ', \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';
      }
    } else if (restLabel.isNotEmpty) {
      subtitle = '\u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';
    }

    return _RestylingCardData(
      value: rest,

      title: title.isEmpty
          ? _fallbackRestylingTitle(
              restLabel.isEmpty ? baseRestLabel : restLabel,
            )
          : title,

      subtitle: subtitle,

      imageUrl: imageUrl,
    );
  }

  String _formatYears(int? start, int? end) {
    if (start == null && end == null) return '';

    if (start != null && end != null) {
      return '$start - $end';
    }

    if (start != null) {
      return '$start - н.в.';
    }

    return 'до $end';
  }

  @override
  Widget build(BuildContext context) {
    final makeOptions = _RemoteCarCatalog.makes();
    final makeAltNames = _RemoteCarCatalog.brandRusByName;
    final makeLoading = _RemoteCarCatalog.brandsLoading;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

      padding: AppSizes.listPaddingWithBottomBar(),

      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 6,
          spacing: 8,

          children: [
            MyText(
              text:
                  '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0438 (${_cars.length})',

              size: 16,

              weight: FontWeight.w700,
            ),

            SizedBox(
              height: 40,

              child: MyButton(
                buttonText:
                    '+ \u0414\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C',

                onTap: _addCar,

                textSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        MyText(
          text:
              '\u041C\u0430\u043A\u0441\u0438\u043C\u0443\u043C $_maxCars \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0435\u0439 \u0432 \u043E\u0434\u043D\u043E\u0439 \u0437\u0430\u044F\u0432\u043A\u0435.',

          size: 12,

          color: _cars.length >= _maxCars ? kRedColor : kHintColor,
        ),

        if (_formError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),

            child: MyText(text: _formError, size: 12, color: kRedColor),
          ),

        const SizedBox(height: 12),
        MyTextField(
          labelText:
              '\u0421\u0440\u043e\u043a \u0432\u044b\u043f\u043e\u043b\u043d\u0435\u043d\u0438\u044f \u0434\u043e',
          hintText: '\u0414\u0414.\u041c\u041c.\u0413\u0413\u0413\u0413',
          controller: _dueDateController,
          keyboardType: TextInputType.number,
          inputFormatters: [_RuDateFormatter()],
          onChanged: _onDueDateChanged,
        ),
        _ErrorText(text: _dueDateError),
        const SizedBox(height: 12),

        for (int i = 0; i < _cars.length; i++)
          _CarCard(
            // Stable key so reordering / removing a car doesn't trigger a
            // rebuild of every sibling _CarCard.
            key: ValueKey('by_car_card_${_cars[i].id}'),
            item: _cars[i],

            index: i,

            errors: _carErrors[_cars[i].id] ?? {},

            collapsed: _collapsed[_cars[i].id] ?? false,

            manualOpen: _manualOpen[_cars[i].id] ?? false,

            makeOptions: makeOptions,

            modelOptions: _RemoteCarCatalog.modelsFor(_cars[i].make),

            restylingOptions: _RemoteCarCatalog.restylingsFor(
              _cars[i].make,

              _cars[i].model,
            ),

            restylingDisplay: _restylingDisplayFor(
              _cars[i].make,

              _cars[i].model,

              _cars[i].restyling,
            ),

            makeAltNames: makeAltNames,

            makeLoading: makeLoading,

            modelLoading: _RemoteCarCatalog.isModelsLoading(_cars[i].make),

            restylingLoading: _RemoteCarCatalog.isRestylingsLoading(
              _cars[i].make,

              _cars[i].model,
            ),
            sourceParsing: _sourceParsing[_cars[i].id] ?? false,
            sourceParseFailed: _sourceParseFailed[_cars[i].id] ?? false,
            sourceParseHint: _sourceParseHint[_cars[i].id] ?? '',
            sourcePreview: _sourcePreview[_cars[i].id],
            sourceUrlController: _sourceUrlControllerFor(_cars[i]),
            sourceUrlLocked:
                _cars[i].sourceUrl.trim().isNotEmpty &&
                ((_sourceParsing[_cars[i].id] ?? false) ||
                    (_sourceParseHint[_cars[i].id]?.trim().isNotEmpty ??
                        false)),
            onResetSourceUrl: () =>
                _setCarPatch(_cars[i].id, _CarItemPatch(sourceUrl: '')),

            withHint: _withHint,

            onPickRestyling: () => _openRestylingPickerForCar(_cars[i]),

            onToggle: () => _toggleCollapsed(_cars[i].id),

            onToggleManual: () => _toggleManual(_cars[i].id),

            onRemove: _cars.length > 1 ? () => _removeCar(_cars[i].id) : null,

            onChanged: (patch) => _setCarPatch(_cars[i].id, patch),
          ),

        const SizedBox(height: 8),

        MyButton(
          buttonText: _isSubmittingByCar
              ? '\u041E\u0442\u043F\u0440\u0430\u0432\u043A\u0430...'
              : '\u041E\u0442\u043F\u0440\u0430\u0432\u0438\u0442\u044C \u0437\u0430\u044F\u0432\u043A\u0443',
          onTap: () {
            if (_isSubmittingByCar) return;
            _submitByCar();
          },
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    super.key,
    required this.item,

    required this.index,

    required this.errors,

    required this.collapsed,

    required this.manualOpen,

    required this.makeOptions,

    required this.modelOptions,

    required this.restylingOptions,

    required this.restylingDisplay,

    required this.makeAltNames,

    required this.makeLoading,

    required this.modelLoading,

    required this.restylingLoading,
    required this.sourceParsing,
    required this.sourceParseFailed,
    required this.sourceParseHint,
    this.sourcePreview,
    required this.sourceUrlController,
    required this.sourceUrlLocked,
    required this.onResetSourceUrl,

    required this.withHint,

    required this.onPickRestyling,

    required this.onToggle,

    required this.onToggleManual,

    required this.onChanged,

    required this.onRemove,
  });

  final _CarItem item;

  final int index;

  final Map<String, String> errors;

  final bool collapsed;

  final bool manualOpen;

  final List<String> makeOptions;

  final List<String> modelOptions;

  final List<String> restylingOptions;

  final String restylingDisplay;

  final Map<String, String> makeAltNames;

  final bool makeLoading;

  final bool modelLoading;

  final bool restylingLoading;
  final bool sourceParsing;
  final bool sourceParseFailed;
  final String sourceParseHint;
  final _SourceAdPreview? sourcePreview;
  final TextEditingController sourceUrlController;
  final bool sourceUrlLocked;
  final VoidCallback onResetSourceUrl;

  final List<String> Function(
    String hint,

    List<String> options,

    String selected, {

    bool loading,
  })
  withHint;

  final VoidCallback onPickRestyling;

  final VoidCallback onToggle;

  final VoidCallback onToggleManual;

  final ValueChanged<_CarItemPatch> onChanged;

  final VoidCallback? onRemove;

  String _headerTitle() {
    final link = item.sourceUrl.trim();

    if (item.make.isNotEmpty && item.model.isNotEmpty) {
      return '${item.make} ${item.model}'
          '${restylingDisplay.isNotEmpty ? ' $restylingDisplay' : ''}';
    }

    if (sourcePreview != null && sourcePreview!.title.trim().isNotEmpty) {
      return sourcePreview!.title.trim();
    }

    if (link.isNotEmpty) {
      return '\u041E\u0431\u044A\u044F\u0432\u043B\u0435\u043D\u0438\u0435: ${_shortListingLabel(link)}';
    }

    return '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C \u2116${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final makes = makeOptions;

    final models = modelOptions;

    final makeItems = withHint(
      '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443',

      makes,

      item.make,

      loading: makeLoading,
    );

    final modelItems = withHint(
      '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C',

      models,

      item.model,

      loading: modelLoading,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),

      decoration: BoxDecoration(
        color: kWhiteColor,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorderColor),
      ),

      child: Column(
        children: [
          InkWell(
            onTap: onToggle,

            child: Padding(
              padding: const EdgeInsets.all(12),

              child: Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: _headerTitle(),

                      size: 14,

                      weight: FontWeight.w600,
                    ),
                  ),

                  if (onRemove != null)
                    GestureDetector(
                      onTap: onRemove,

                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,

                          vertical: 4,
                        ),

                        decoration: BoxDecoration(
                          color: kRedColor.withValues(alpha: 0.1),

                          borderRadius: BorderRadius.circular(8),
                        ),

                        child: MyText(
                          text: '\u0423\u0434\u0430\u043B\u0438\u0442\u044C',

                          size: 11,

                          color: kRedColor,

                          weight: FontWeight.w700,
                        ),
                      ),
                    ),

                  const SizedBox(width: 8),

                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,

                    color: kSecondaryColor,
                  ),
                ],
              ),
            ),
          ),

          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  MyTextField(
                    labelText:
                        '\u0421\u0441\u044B\u043B\u043A\u0430 \u043D\u0430 \u043E\u0431\u044A\u044F\u0432\u043B\u0435\u043D\u0438\u0435 *',

                    hintText: 'https://',
                    controller: sourceUrlController,
                    isReadOnly: sourceUrlLocked,
                    suffix: sourceUrlLocked
                        ? IconButton(
                            tooltip:
                                '\u0418\u0437\u043C\u0435\u043D\u0438\u0442\u044C \u0441\u0441\u044B\u043B\u043A\u0443',
                            onPressed: onResetSourceUrl,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: kGreyColor,
                            ),
                          )
                        : null,

                    onChanged: (v) => onChanged(_CarItemPatch(sourceUrl: v)),
                  ),

                  _ErrorText(text: errors['sourceUrl']),
                  if (sourceParsing || sourceParseHint.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          if (sourceParsing)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              sourceParseFailed
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              size: 14,
                              color: sourceParseFailed
                                  ? kRedColor
                                  : kGreenColor,
                            ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: MyText(
                              text: sourceParsing
                                  ? 'Получаем данные по ссылке...'
                                  : sourceParseHint,
                              size: 11,
                              color: sourceParseFailed
                                  ? kRedColor
                                  : kSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (sourcePreview != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kInputBgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kBorderColor),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: sourcePreview!.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: sourcePreview!.imageUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Container(
                                        width: 56,
                                        height: 56,
                                        color: kWhiteColor,
                                        alignment: Alignment.center,
                                        child: const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, _, _) => Container(
                                        width: 56,
                                        height: 56,
                                        color: kWhiteColor,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.directions_car_outlined,
                                          size: 20,
                                          color: kGreyColor,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      color: kWhiteColor,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.link,
                                        size: 20,
                                        color: kGreyColor,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyText(
                                    text: sourcePreview!.title,
                                    size: 12,
                                    weight: FontWeight.w700,
                                    maxLines: 2,
                                    textOverflow: TextOverflow.ellipsis,
                                  ),
                                  if (sourcePreview!.subtitle.trim().isNotEmpty)
                                    MyText(
                                      text: sourcePreview!.subtitle.trim(),
                                      size: 11,
                                      color: kSecondaryColor,
                                      maxLines: 2,
                                      textOverflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  Align(
                    alignment: Alignment.centerRight,

                    child: TextButton(
                      onPressed: onToggleManual,

                      child: Text(
                        manualOpen
                            ? '\u0421\u043A\u0440\u044B\u0442\u044C \u0434\u043E\u043F\u043E\u043B\u043D\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0435 \u043F\u043E\u043B\u044F'
                            : '\u041D\u0435\u0442 \u0441\u0441\u044B\u043B\u043A\u0438 \u2014 \u0432\u0432\u0435\u0441\u0442\u0438 \u0434\u0430\u043D\u043D\u044B\u0435',

                        style: const TextStyle(color: kSecondaryColor),
                      ),
                    ),
                  ),

                  if (manualOpen) ...[
                    MyTextField(
                      labelText: '\u0417\u0430\u043C\u0435\u0442\u043A\u0430',

                      hintText:
                          '\u041D\u0430\u043F\u0440\u0438\u043C\u0435\u0440: \u0436\u0435\u043B\u0430\u0442\u0435\u043B\u044C\u043D\u043E \u0431\u0435\u0437 \u0414\u0422\u041F',

                      onChanged: (v) => onChanged(_CarItemPatch(note: v)),
                    ),

                    const SizedBox(height: 12),

                    MyTextField(
                      labelText:
                          '\u0422\u0435\u043B\u0435\u0444\u043E\u043D \u043F\u0440\u043E\u0434\u0430\u0432\u0446\u0430 *',

                      hintText: '+7',

                      keyboardType: TextInputType.number,
                      inputFormatters: [_RuPhoneFormatter()],

                      onChanged: (v) =>
                          onChanged(_CarItemPatch(sellerPhone: v)),
                    ),

                    _ErrorText(text: errors['sellerPhone']),

                    const SizedBox(height: 6),

                    MyText(
                      text:
                          '\u0414\u0430\u043D\u043D\u044B\u0435 \u043F\u043E \u0430\u0432\u0442\u043E',

                      size: 14,

                      weight: FontWeight.w700,

                      paddingBottom: 12,
                    ),

                    _twoColumn(
                      context,
                      left: CustomDropDown(
                        hint:
                            '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443',
                        labelText: '\u041C\u0430\u0440\u043A\u0430 *',
                        items: makeItems,
                        selectedValue: item.make.isEmpty
                            ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443'
                            : item.make,
                        enableSearch: true,
                        searchAltNames: makeAltNames,
                        onChanged: makeLoading
                            ? null
                            : (value) {
                                final v =
                                    value ==
                                        '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443'
                                    ? ''
                                    : value;
                                onChanged(_CarItemPatch(make: v));
                              },
                      ),
                      right: CustomDropDown(
                        hint:
                            '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C',
                        labelText: '\u041C\u043E\u0434\u0435\u043B\u044C *',
                        items: modelItems,
                        selectedValue: item.model.isEmpty
                            ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C'
                            : item.model,
                        enableSearch: true,
                        onChanged: modelLoading
                            ? null
                            : (value) {
                                final v =
                                    value ==
                                        '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C'
                                    ? ''
                                    : value;
                                onChanged(_CarItemPatch(model: v));
                              },
                      ),
                    ),

                    _ErrorText(text: errors['make']),

                    _ErrorText(text: errors['model']),

                    _SelectField(
                      label:
                          '\u041F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435 / \u043A\u0443\u0437\u043E\u0432',
                      placeholder:
                          '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435',
                      value: restylingDisplay.isEmpty
                          ? item.restyling
                          : restylingDisplay,
                      enabled:
                          item.make.isNotEmpty &&
                          item.model.isNotEmpty &&
                          !restylingLoading,
                      loading: restylingLoading,
                      onTap: onPickRestyling,
                    ),

                    _ErrorText(text: errors['restyling']),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),

      child: MyText(text: text!, size: 11, color: kRedColor),
    );
  }
}

class _CarItem {
  _CarItem({
    required this.id,

    this.make = '',

    this.model = '',

    this.restyling = '',

    this.sourceUrl = '',

    this.sellerPhone = '',

    this.note = '',
  });

  final String id;

  final String make;

  final String model;

  final String restyling;

  final String sourceUrl;

  final String sellerPhone;

  final String? note;

  int get index => id.hashCode;

  _CarItem copyWith(_CarItemPatch patch) {
    return _CarItem(
      id: id,

      make: patch.make ?? make,

      model: patch.model ?? model,

      restyling: patch.restyling ?? restyling,

      sourceUrl: patch.sourceUrl ?? sourceUrl,

      sellerPhone: patch.sellerPhone ?? sellerPhone,

      note: patch.note ?? note,
    );
  }
}

class _CarItemPatch {
  _CarItemPatch({
    this.make,

    this.model,

    this.restyling,

    this.sourceUrl,

    this.sellerPhone,

    this.note,
  });

  final String? make;

  final String? model;

  final String? restyling;

  final String? sourceUrl;

  final String? sellerPhone;

  final String? note;
}

String _shortListingLabel(String url) {
  try {
    final u = Uri.parse(url);
    var host = u.host.trim().toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    if (host.isEmpty) return 'ссылка';

    final parts = (u.path).split('/').where((e) => e.isNotEmpty).toList();

    final tail = parts.isNotEmpty ? parts.last : '';
    if (tail.isEmpty) return host;

    final compactTail = tail.length > 24
        ? '${tail.substring(0, 24)}\u2026'
        : tail;
    return '$host/$compactTail';
  } catch (_) {
    return url.length > 32 ? '${url.substring(0, 32)}\u2026' : url;
  }
}

const List<String> _allowedListingDomains = ['avito.ru', 'drom.ru', 'auto.ru'];

const Map<String, Map<String, List<String>>> _carCatalog = {
  'Toyota': {
    'Camry': ['XV40', 'XV50', 'XV70'],

    'Corolla': ['E150', 'E170', 'E210'],

    'RAV4': ['XA30', 'XA40', 'XA50'],
  },

  'Ford': {
    'Focus': ['Mk1', 'Mk2', 'Mk3', 'Mk4'],

    'Mondeo': ['Mk3', 'Mk4', 'Mk5'],

    'Kuga': ['I', 'II', 'III'],
  },

  'Volkswagen': {
    'Golf': ['Mk5', 'Mk6', 'Mk7', 'Mk8'],

    'Passat': ['B6', 'B7', 'B8'],

    'Tiguan': ['I', 'II'],
  },
};

class _TurnkeyForm extends StatefulWidget {
  @override
  State<_TurnkeyForm> createState() => _TurnkeyFormState();
}

class _TurnkeyFormState extends State<_TurnkeyForm> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _cityFieldKey = GlobalKey();
  final GlobalKey _dueDateFieldKey = GlobalKey();
  final GlobalKey _makesFieldKey = GlobalKey();
  List<String> _tkMakes = [];

  List<String> _tkModels = [];

  List<String> _tkRestylings = [];

  DateTime? _dueDate;
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _budgetFromController = TextEditingController();
  final TextEditingController _budgetToController = TextEditingController();
  final TextEditingController _mileageToController = TextEditingController();
  final TextEditingController _ownersCountController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _dueDateError = '';
  final Map<String, String> _fieldErrors = {};
  String _formError = '';
  bool _isSubmittingTurnkey = false;
  bool _remoteRefreshScheduled = false;

  // Source-of-truth flag for "city is in the canonical RU+CIS list".
  // The form's text controller always holds the displayable name;
  // this flag answers "did the user actually pick from the dropdown
  // or is the value some legacy free-text we cannot trust". Submit
  // is gated on this in `_validateRequiredFields`. Picker callback
  // sets it true; preload below resets it from the bundled list.
  bool _isCityValid = false;

  @override
  void initState() {
    super.initState();

    _RemoteCarCatalog.stamp.addListener(_handleRemoteUpdate);

    _RemoteCarCatalog.ensureBrands();

    // Eagerly preload the city dataset so the first picker open is
    // instant. Pre-fills `_isCityValid` if the form was reopened with
    // a value already in the controller (e.g. saved request draft).
    unawaited(_initCityRepoAndValidate());
  }

  Future<void> _initCityRepoAndValidate() async {
    if (!CityRepository.instance.isReady) {
      await CityRepository.instance.init();
    }
    if (!mounted) return;
    final v = _cityController.text.trim();
    final valid = v.isNotEmpty &&
        CityRepository.instance.findByExactRu(v) != null;
    if (valid != _isCityValid) {
      setState(() => _isCityValid = valid);
    }
  }

  /// Tap handler for the city field. Awaits dataset readiness, opens
  /// the bottom-sheet picker, writes the selected name into the
  /// controller, and clears any city-related form error so the user
  /// sees immediate feedback that the field is now valid.
  Future<void> _pickCity() async {
    if (!CityRepository.instance.isReady) {
      await CityRepository.instance.init();
    }
    if (!mounted) return;
    final picked = await showCityPickerBottomSheet(
      context,
      currentValue: _cityController.text.trim(),
    );
    if (!mounted || picked == null) return;
    setState(() {
      // Full "Country, Region, City" label — same source string the
      // picker tile shows. `findByExactRu` matches both this form and
      // bare `nameRu` so legacy form drafts remain valid.
      _cityController.text = picked.displayLabel;
      _isCityValid = true;
      _fieldErrors.remove('city');
      if (_fieldErrors.isEmpty) _formError = '';
    });
  }

  @override
  void dispose() {
    _RemoteCarCatalog.stamp.removeListener(_handleRemoteUpdate);
    _scrollController.dispose();
    _cityController.dispose();
    _budgetFromController.dispose();
    _budgetToController.dispose();
    _mileageToController.dispose();
    _ownersCountController.dispose();
    _dueDateController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  Future<void> _scrollToField(GlobalKey key, {double alignment = 0.12}) async {
    final ctx = key.currentContext;
    if (ctx == null) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: alignment,
    );
  }

  Future<void> _revealFirstValidationError() async {
    if (_fieldErrors.containsKey('city')) {
      await _scrollToField(_cityFieldKey, alignment: 0.08);
      return;
    }
    if (_dueDateError.isNotEmpty) {
      await _scrollToField(_dueDateFieldKey, alignment: 0.12);
      return;
    }
    if (_fieldErrors.containsKey('makes')) {
      await _scrollToField(_makesFieldKey, alignment: 0.12);
    }
  }

  void _handleRemoteUpdate() {
    if (_remoteRefreshScheduled || !mounted) return;
    _remoteRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remoteRefreshScheduled = false;
      if (!mounted) return;
      setState(() {});
    });
  }

  void _onDueDateChanged(String value) {
    if (_dueDateError.isNotEmpty) {
      setState(() {
        _dueDateError = '';
      });
    }
    _dueDate = _tryParseRuDate(value);
  }

  bool _validateDueDate() {
    _dueDateError = '';
    final raw = _dueDateController.text.trim();
    if (raw.isEmpty) {
      _dueDate = null;
      return true;
    }
    final parsed = _tryParseRuDate(raw);
    if (parsed == null) {
      _dueDate = null;
      _dueDateError = 'Укажите дату в формате ДД.ММ.ГГГГ';
      return false;
    }
    _dueDate = parsed;
    return true;
  }

  List<String> _allMakes() => _RemoteCarCatalog.makes();

  List<String> _allModelsForMakes(List<String> makes) {
    final set = <String>{};

    if (makes.isEmpty) {
      for (final mk in _carCatalog.keys) {
        set.addAll(_carCatalog[mk]!.keys);
      }

      return sortModelsByPopularityForMakes(makes, set.toList());
    }

    for (final mk in makes) {
      final remote = _RemoteCarCatalog.modelsFor(mk);

      if (remote.isNotEmpty) {
        set.addAll(remote);
      } else {
        set.addAll(_carCatalog[mk]?.keys ?? const Iterable.empty());
      }
    }

    return sortModelsByPopularityForMakes(makes, set.toList());
  }

  List<String> _sortRestylingsByYearDesc(Iterable<String> values) {
    final out = values.toList();
    out.sort((a, b) {
      final aParts = a.split('|');
      final bParts = b.split('|');
      if (aParts.length >= 3 && bParts.length >= 3) {
        final aMake = aParts[0].trim();
        final aModel = aParts[1].trim();
        final aRest = aParts.sublist(2).join('|').trim();
        final bMake = bParts[0].trim();
        final bModel = bParts[1].trim();
        final bRest = bParts.sublist(2).join('|').trim();
        if (aMake == bMake && aModel == bModel) {
          final byYear = _RemoteCarCatalog.compareRestylingsByYearDesc(
            aMake,
            aModel,
            aRest,
            bRest,
          );
          if (byYear != 0) return byYear;
        }
        final byMake = aMake.compareTo(bMake);
        if (byMake != 0) return byMake;
        final byModel = aModel.compareTo(bModel);
        if (byModel != 0) return byModel;
      }
      return a.compareTo(b);
    });
    return out;
  }

  List<String> _allRestylingsForSelection(
    List<String> makes,

    List<String> models,
  ) {
    final set = <String>{};

    final targetMakes = makes.isEmpty ? _carCatalog.keys : makes;

    for (final mk in targetMakes) {
      final byModel = _carCatalog[mk] ?? {};

      final knownModels = _RemoteCarCatalog.modelsFor(mk);

      final availableModels = knownModels.isNotEmpty
          ? knownModels
          : byModel.keys.toList();

      final targetModels = models.isEmpty
          ? availableModels
          : models.where((m) => availableModels.contains(m));

      for (final md in targetModels) {
        final remote = _RemoteCarCatalog.restylingsFor(mk, md);

        final restList = remote.isNotEmpty
            ? remote
            : (byModel[md] ?? const <String>[]);

        for (final rest in restList) {
          set.add('$mk|$md|$rest');
        }
      }
    }

    return _sortRestylingsByYearDesc(set);
  }

  void _setMakes(List<String> v) {
    final allowedModels = _allModelsForMakes(v);

    final nextModels = _tkModels
        .where((m) => allowedModels.contains(m))
        .toList();

    final allowedRest = _allRestylingsForSelection(v, nextModels);

    final nextRest = _tkRestylings
        .where((g) => allowedRest.contains(g))
        .toList();

    setState(() {
      _tkMakes = v;

      _tkModels = nextModels;

      _tkRestylings = nextRest;
      _fieldErrors.remove('makes');
      if (_tkMakes.isNotEmpty) {
        _formError = '';
      }
    });

    for (final mk in v) {
      _RemoteCarCatalog.ensureModels(mk);
    }
  }

  void _setModels(List<String> v) {
    final allowedRest = _allRestylingsForSelection(_tkMakes, v);

    final nextRest = _tkRestylings
        .where((g) => allowedRest.contains(g))
        .toList();

    setState(() {
      _tkModels = v;

      _tkRestylings = nextRest;
      _fieldErrors.remove('models');
      if (_tkModels.isNotEmpty) {
        _formError = '';
      }
    });

    for (final mk in _tkMakes) {
      for (final md in v) {
        _RemoteCarCatalog.ensureRestylings(mk, md);
      }
    }
  }

  void _setRestylings(List<String> v) {
    setState(() {
      _tkRestylings = v;
      _fieldErrors.remove('restylings');
      if (_tkRestylings.isNotEmpty) {
        _formError = '';
      }
    });
  }

  bool _validateRequiredFields() {
    _fieldErrors.clear();
    if (_cityController.text.trim().isEmpty) {
      _fieldErrors['city'] = 'Укажите город';
    } else if (!_isCityValid) {
      // Free-form city values from older app versions / pasted strings
      // are no longer accepted by the new picker contract — surface
      // the explicit "reselect" prompt instead of the generic
      // "укажите город".
      _fieldErrors['city'] = 'Город отсутствует в списке. Выберите заново.';
    }
    if (_tkMakes.isEmpty) {
      _fieldErrors['makes'] = 'Выберите минимум одну марку';
    }
    // Profanity gate on the free-form note. The note is the only
    // field on this form where a user can type arbitrary Russian
    // prose; everything else is a structured selection.
    final noteCheck = ProfanityModerator.moderateText(
      _noteController.text,
      fieldLabel: 'Комментарий',
    );
    if (noteCheck.isBlock) {
      _fieldErrors['note'] = noteCheck.userMessage!;
    }
    _formError = _fieldErrors.isEmpty
        ? ''
        : 'Заполните обязательные поля формы';
    return _fieldErrors.isEmpty;
  }

  Future<void> _openMultiSelect({
    required String title,

    required List<String> options,

    required List<String> initial,

    required ValueChanged<List<String>> onApply,
  }) async {
    final temp = List<String>.from(initial);

    String query = '';

    await showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: kWhiteColor,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final filtered = options.where((opt) {
              if (query.trim().isEmpty) return true;

              return opt.toLowerCase().contains(query.trim().toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: title,

                            size: 16,

                            weight: FontWeight.w700,
                          ),
                        ),

                        IconButton(
                          onPressed: () => Navigator.pop(ctx),

                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      onChanged: (v) => setSheet(() => query = v),

                      decoration: InputDecoration(
                        hintText: '\u041d\u0430\u0439\u0442\u0438...',

                        prefixIcon: const Icon(Icons.search, size: 18),

                        filled: true,

                        fillColor: kWhiteColor,

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,

                          vertical: 10,
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),

                          borderSide: BorderSide(color: kBorderColor),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),

                          borderSide: BorderSide(color: kSecondaryColor),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),

                      decoration: BoxDecoration(
                        border: Border.all(color: kBorderColor),

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: ListView.builder(
                        shrinkWrap: true,

                        itemCount: filtered.length,

                        itemBuilder: (context, index) {
                          final item = filtered[index];

                          final checked = temp.contains(item);

                          return CheckboxListTile(
                            value: checked,

                            onChanged: (v) {
                              setSheet(() {
                                if (v == true) {
                                  if (!temp.contains(item)) temp.add(item);
                                } else {
                                  temp.remove(item);
                                }
                              });
                            },

                            controlAffinity: ListTileControlAffinity.leading,

                            title: Text(
                              item,

                              style: const TextStyle(fontSize: 12),
                            ),

                            dense: true,

                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,

                              vertical: 0,
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheet(() => temp.clear()),

                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: kSecondaryColor),

                              padding: const EdgeInsets.symmetric(vertical: 12),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),

                            child: const Text(
                              '\u0421\u0431\u0440\u043e\u0441\u0438\u0442\u044c',

                              style: TextStyle(color: kSecondaryColor),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              onApply(List<String>.from(temp));

                              Navigator.pop(ctx);
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSecondaryColor,

                              padding: const EdgeInsets.symmetric(vertical: 12),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),

                            child: const Text(
                              '\u041f\u0440\u0438\u043c\u0435\u043d\u0438\u0442\u044c',

                              style: TextStyle(color: kWhiteColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openRestylingPicker() async {
    final temp = List<String>.from(_tkRestylings);

    String query = '';

    await showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: kWhiteColor,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final media = MediaQuery.of(ctx);

            final sheetHeight = (media.size.height - media.padding.top) * 0.88;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 120),

              curve: Curves.easeOut,

              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),

              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

                  child: SizedBox(
                    height: sheetHeight,

                    child: Column(
                      mainAxisSize: MainAxisSize.max,

                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MyText(
                                text: 'Поколение',

                                size: 16,

                                weight: FontWeight.w700,
                              ),
                            ),

                            IconButton(
                              onPressed: () => Navigator.pop(ctx),

                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          onChanged: (v) => setSheet(() => query = v),

                          decoration: InputDecoration(
                            hintText: 'Найти...',

                            prefixIcon: const Icon(Icons.search, size: 18),

                            filled: true,

                            fillColor: kWhiteColor,

                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,

                              vertical: 10,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),

                              borderSide: BorderSide(color: kBorderColor),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),

                              borderSide: BorderSide(color: kSecondaryColor),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Expanded(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _RemoteCarCatalog.stamp,

                            builder: (ctx, _, _) {
                              final options = _allRestylingsForSelection(
                                _tkMakes,

                                _tkModels,
                              );

                              final items = options
                                  .map((rest) => _buildRestylingCardData(rest))
                                  .where(
                                    (item) =>
                                        _matchesRestylingQuery(item, query),
                                  )
                                  .toList();

                              if (items.isEmpty) {
                                return const Center(
                                  child: MyText(
                                    text: 'Ничего не найдено',

                                    size: 12,

                                    color: kGreyColor,
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.only(bottom: 6),

                                itemCount: items.length,

                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),

                                itemBuilder: (context, index) {
                                  final data = items[index];

                                  final selected = temp.contains(data.value);

                                  return SizedBox(
                                    width: double.infinity,

                                    child: _RestylingCard(
                                      title: data.title,

                                      subtitle: data.subtitle,

                                      imageUrl: data.imageUrl,

                                      selected: selected,

                                      onTap: () => setSheet(() {
                                        if (selected) {
                                          temp.remove(data.value);
                                        } else {
                                          temp.add(data.value);
                                        }
                                      }),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setSheet(() => temp.clear()),

                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: kSecondaryColor),

                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),

                                child: const Text(
                                  'Сбросить',

                                  style: TextStyle(color: kSecondaryColor),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _setRestylings(List<String>.from(temp));

                                  Navigator.pop(ctx);
                                },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kSecondaryColor,

                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),

                                child: const Text(
                                  'Применить',

                                  style: TextStyle(color: kWhiteColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  _RestylingCardData _buildRestylingCardData(String rest) {
    String make = '';

    String model = '';

    String restName = rest;

    if (rest.contains('|')) {
      final parts = rest.split('|');

      if (parts.length >= 3) {
        make = parts[0];

        model = parts[1];

        restName = parts.sublist(2).join('|');
      }
    }

    _RestylingMeta? meta;

    String imageUrl = '';

    if (make.isNotEmpty && model.isNotEmpty) {
      meta = _RemoteCarCatalog.restylingMetaFor(make, model, restName);

      imageUrl = _RemoteCarCatalog.restylingPhotoFor(make, model, restName);
    } else {
      final makes = _tkMakes.isNotEmpty ? _tkMakes : _carCatalog.keys.toList();

      final models = _tkModels;

      for (final mk in makes) {
        final modelList = models.isNotEmpty
            ? models
            : (_carCatalog[mk]?.keys.toList() ?? const <String>[]);

        for (final md in modelList) {
          meta ??= _RemoteCarCatalog.restylingMetaFor(mk, md, restName);

          if (imageUrl.isEmpty) {
            imageUrl = _RemoteCarCatalog.restylingPhotoFor(mk, md, restName);
          }

          if (meta != null && imageUrl.isNotEmpty) break;
        }

        if (meta != null && imageUrl.isNotEmpty) break;
      }
    }

    final years = _formatYears(meta?.yearStart, meta?.yearEnd);

    final baseRestLabel = meta?.restylingLabel ?? restName;
    final restLabel =
        baseRestLabel ==
            '\u0411\u0435\u0437 \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433\u0430'
        ? ''
        : baseRestLabel;

    final frames = meta?.frames ?? const <String>[];

    final codes = <String>{};

    for (final code in frames) {
      final trimmed = code.trim();

      if (trimmed.isNotEmpty) {
        codes.add(trimmed);
      }
    }

    if (restLabel.isNotEmpty &&
        !_looksNumericCode(restLabel) &&
        !codes.contains(restLabel)) {
      codes.add(restLabel);
    }

    final codesText = codes.isEmpty ? '' : codes.join(', ');

    final titleParts = <String>[];

    if (years.isNotEmpty) titleParts.add(years);

    if (codesText.isNotEmpty) titleParts.add(codesText);

    final title = titleParts.join(', ');

    String subtitle = '';

    if (meta != null && meta.generation > 0) {
      subtitle = 'Поколение ${meta.generation}';

      if (restLabel.isNotEmpty) {
        subtitle +=
            ', \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';
      }
    } else if (restLabel.isNotEmpty) {
      subtitle = '\u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';
    }

    return _RestylingCardData(
      value: rest,

      title: title.isEmpty
          ? _fallbackRestylingTitle(
              restLabel.isEmpty ? baseRestLabel : restLabel,
            )
          : title,

      subtitle: subtitle,

      imageUrl: imageUrl,
    );
  }

  String _formatYears(int? start, int? end) {
    if (start == null && end == null) return '';

    if (start != null && end != null) {
      return '$start - $end';
    }

    if (start != null) {
      return '$start - н.в.';
    }

    return 'до $end';
  }

  List<String> _restylingDisplayList(List<String> restylings) {
    return _sortRestylingsByYearDesc(restylings)
        .map((rest) => _buildRestylingCardData(rest).title)
        .where((v) => v.trim().isNotEmpty)
        .toList();
  }

  int? _turnkeyRestylingIdFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('|');
    if (parts.length >= 3) {
      final make = parts[0].trim();
      final model = parts[1].trim();
      final restName = parts.sublist(2).join('|').trim();
      final id = _RemoteCarCatalog.restylingIdFor(make, model, restName);
      if (id != null && id > 0) return id;
    }

    final directId = _RemoteCarCatalog.restylingIdFor('', '', trimmed);
    if (directId != null && directId > 0) return directId;

    final makes = _tkMakes.isNotEmpty ? _tkMakes : _carCatalog.keys.toList();
    final selectedModels = _tkModels;
    for (final make in makes) {
      final models = selectedModels.isNotEmpty
          ? selectedModels
          : _RemoteCarCatalog.modelsFor(make);
      for (final model in models) {
        final id = _RemoteCarCatalog.restylingIdFor(make, model, trimmed);
        if (id != null && id > 0) return id;
      }
    }

    return null;
  }

  int? _parseIntOrNull(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  Future<void> _submitTurnkey() async {
    if (_isSubmittingTurnkey) return;

    final requiredValid = _validateRequiredFields();
    final dueDateValid = _validateDueDate();
    if (!requiredValid || !dueDateValid) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _revealFirstValidationError();
      });
      return;
    }

    setState(() {
      _isSubmittingTurnkey = true;
      _formError = '';
    });

    try {
      final restylingIds = _tkRestylings
          .map(_turnkeyRestylingIdFor)
          .whereType<int>()
          .toSet()
          .toList();
      final dueAt = _dueDate == null ? null : _formatDateIso(_dueDate!);
      final city = _cityController.text.trim();
      final note = _noteController.text.trim();
      final budgetFrom = _parseIntOrNull(_budgetFromController.text);
      final budgetTo = _parseIntOrNull(_budgetToController.text);
      final maxMileage = _parseIntOrNull(_mileageToController.text);
      final ownersCount = _parseIntOrNull(_ownersCountController.text);
      final displayCars = _tkRestylings
          .map((raw) {
            var make = '';
            var model = '';
            var restName = raw.trim();
            if (raw.contains('|')) {
              final parts = raw.split('|');
              if (parts.length >= 3) {
                make = parts[0].trim();
                model = parts[1].trim();
                restName = parts.sublist(2).join('|').trim();
              }
            }
            final meta = make.isNotEmpty && model.isNotEmpty
                ? _RemoteCarCatalog.restylingMetaFor(make, model, restName)
                : null;
            final photoUrls = make.isNotEmpty && model.isNotEmpty
                ? _RemoteCarCatalog.restylingPhotoUrlsFor(make, model, restName)
                : const <String>[];
            final photoUrl = photoUrls.isNotEmpty ? photoUrls.first : '';
            final restEntry = <String, dynamic>{};
            if (meta != null) {
              if (meta.generation > 0) {
                restEntry['generation'] = meta.generation;
              }
              if (meta.yearStart != null) {
                restEntry['yearStart'] = meta.yearStart;
              }
              if (meta.yearEnd != null) restEntry['yearEnd'] = meta.yearEnd;
              final frames = meta.frames
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();
              if (frames.isNotEmpty) restEntry['frames'] = frames;
              if (meta.restylingLabel.trim().isNotEmpty) {
                restEntry['restyling'] = meta.restylingLabel.trim();
              }
            } else if (restName.isNotEmpty) {
              restEntry['restyling'] = restName;
            }
            return {
              if (make.isNotEmpty) 'make': make,
              if (make.isNotEmpty) 'makeName': make,
              if (make.isNotEmpty) 'brandName': make,
              if (model.isNotEmpty) 'model': model,
              if (model.isNotEmpty) 'modelName': model,
              if (model.isNotEmpty) 'modelRus': model,
              if (restEntry.isNotEmpty) 'restylings': [restEntry],
              if (photoUrl.isNotEmpty) 'photoUrl': photoUrl,
              if (photoUrls.isNotEmpty)
                'photos': [
                  for (int i = 0; i < photoUrls.length; i++)
                    {
                      'size': i == 0 ? 'l' : 'm',
                      'url': photoUrls[i],
                      'urlX1': photoUrls[i],
                      'urlX2': photoUrls[i],
                    },
                ],
              if (note.isNotEmpty) 'note': note,
              if (dueAt != null) 'dueAt': dueAt,
            };
          })
          .where((e) => e.isNotEmpty)
          .toList();
      final requestCars = restylingIds.isEmpty
          ? [
              {
                'restylings': <int>[],
                'phone': null,
                'url': null,
                if (note.isNotEmpty) 'note': note,
                if (dueAt != null) 'dueAt': dueAt,
              },
            ]
          : restylingIds
                .map(
                  (id) => {
                    'restylings': [id],
                    'phone': null,
                    'url': null,
                    if (note.isNotEmpty) 'note': note,
                    if (dueAt != null) 'dueAt': dueAt,
                  },
                )
                .toList();

      final result = await StorageApi.createRequest(
        requestType: 'turnkey',
        requestCars: requestCars,
        dueAt: dueAt,
        note: note.isEmpty ? null : note,
        city: city.isEmpty ? null : city,
        budgetFrom: budgetFrom,
        budgetTo: budgetTo,
        maxMileage: maxMileage,
        ownersCount: ownersCount,
      );
      final override = <String, dynamic>{
        if (_tkMakes.isNotEmpty) 'makes': List<String>.from(_tkMakes),
        if (_tkModels.isNotEmpty) 'models': List<String>.from(_tkModels),
        if (_tkRestylings.isNotEmpty)
          'restylings': List<String>.from(_tkRestylings),
        if (_tkMakes.isNotEmpty) 'make': _tkMakes.first,
        if (_tkModels.isNotEmpty) 'model': _tkModels.first,
        if (city.isNotEmpty) 'city': city,
        if (note.isNotEmpty) 'note': note,
        if (budgetFrom != null) 'budgetFrom': budgetFrom,
        if (budgetTo != null) 'budgetTo': budgetTo,
        if (maxMileage != null) 'mileageTo': maxMileage,
        if (ownersCount != null) 'ownersCount': ownersCount,
        if (displayCars.isNotEmpty) 'requestCars': displayCars,
      };
      if (override.isNotEmpty && result.id > 0) {
        await UserSimplePreferences.setRequestDisplayOverride(
          result.id.toString(),
          override,
        );
      }
      if (override.isNotEmpty && result.requestNumber.trim().isNotEmpty) {
        await UserSimplePreferences.setRequestDisplayOverride(
          result.requestNumber.trim(),
          override,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(<String, dynamic>{
        'created': true,
        'requestId': result.id,
        'requestNumber': result.requestNumber,
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formError = 'Не удалось отправить заявку. Попробуйте еще раз.';
      });
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingTurnkey = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

      padding: AppSizes.listPaddingWithBottomBar(),

      children: [
        MyText(
          text:
              '\u041f\u0430\u0440\u0430\u043c\u0435\u0442\u0440\u044b \u043f\u043e\u0434\u0431\u043e\u0440\u0430',

          size: 16,

          weight: FontWeight.w700,

          paddingBottom: 12,
        ),
        if (_formError.isNotEmpty)
          MyText(
            text: _formError,
            size: 12,
            color: kRedColor,
            paddingBottom: 12,
          ),

        Container(
          key: _cityFieldKey,
          child: Column(
            children: [
              // Tap-to-open city picker (\u0431\u044b\u0432\u0448\u0435\u0435 free-text \u043f\u043e\u043b\u0435). The
              // `_cityController` is still source of truth, so submit
              // payload (`city: text`) and any persisted form draft
              // round-trip unchanged. Read-only blocks manual typing
              // per product decision (\u0441\u043c. \u043f\u043b\u0430\u043d 2026-05-05).
              MyTextField(
                labelText: '\u0413\u043e\u0440\u043e\u0434 *',
                hintText:
                    '\u041d\u0430\u043f\u0440\u0438\u043c\u0435\u0440, \u0410\u043b\u043c\u0430\u0442\u044b',
                controller: _cityController,
                isReadOnly: true,
                onTap: _pickCity,
              ),
              _ErrorText(text: _fieldErrors['city']),
            ],
          ),
        ),

        _twoColumn(
          context,
          left: MyTextField(
            labelText: '\u0411\u044E\u0434\u0436\u0435\u0442 \u043E\u0442',
            hintText: '2500000',
            controller: _budgetFromController,
            marginBottom: 0,
          ),
          right: MyTextField(
            labelText: '\u0411\u044E\u0434\u0436\u0435\u0442 \u0434\u043E',
            hintText: '3500000',
            controller: _budgetToController,
            marginBottom: 0,
          ),
        ),

        const SizedBox(height: 16),
        Container(
          key: _dueDateFieldKey,
          child: Column(
            children: [
              MyTextField(
                labelText:
                    '\u0421\u0440\u043e\u043a \u0432\u044b\u043f\u043e\u043b\u043d\u0435\u043d\u0438\u044f \u0434\u043e',
                hintText: '\u0414\u0414.\u041c\u041c.\u0413\u0413\u0413\u0413',
                controller: _dueDateController,
                keyboardType: TextInputType.number,
                inputFormatters: [_RuDateFormatter()],
                onChanged: _onDueDateChanged,
              ),
              _ErrorText(text: _dueDateError),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _twoColumn(
          context,
          left: Container(
            key: _makesFieldKey,
            child: _MultiSelectField(
              label: '\u041C\u0430\u0440\u043A\u0430 *',
              placeholder: '\u041B\u044E\u0431\u0430\u044F',
              value: _tkMakes,
              errorText: _fieldErrors['makes'],
              onTap: () => _openMultiSelect(
                title: '\u041C\u0430\u0440\u043A\u0430',
                options: _allMakes(),
                initial: _tkMakes,
                onApply: _setMakes,
              ),
            ),
          ),
          right: _MultiSelectField(
            label: '\u041C\u043E\u0434\u0435\u043B\u044C',
            placeholder: '\u041B\u044E\u0431\u0430\u044F',
            value: _tkModels,
            onTap: () => _openMultiSelect(
              title: '\u041C\u043E\u0434\u0435\u043B\u044C',
              options: _allModelsForMakes(_tkMakes),
              initial: _tkModels,
              onApply: _setModels,
            ),
          ),
        ),

        const SizedBox(height: 16),

        _MultiSelectField(
          label:
              '\u041f\u043e\u043a\u043e\u043b\u0435\u043d\u0438\u0435 / \u043a\u0443\u0437\u043e\u0432',

          placeholder: '\u041b\u044e\u0431\u043e\u0435',

          value: _tkRestylings,

          displayValue: _restylingDisplayList(_tkRestylings),
          showItemsAsList: true,

          onTap: _openRestylingPicker,
        ),

        const SizedBox(height: 16),

        _twoColumn(
          context,
          left: MyTextField(
            labelText: '\u041F\u0440\u043E\u0431\u0435\u0433 \u0434\u043E',
            hintText: '120000',
            controller: _mileageToController,
            marginBottom: 0,
          ),
          right: MyTextField(
            labelText:
                '\u041A\u043E\u043B\u0438\u0447\u0435\u0441\u0442\u0432\u043E \u0432\u043B\u0430\u0434\u0435\u043B\u044C\u0446\u0435\u0432',
            hintText: '2',
            controller: _ownersCountController,
            marginBottom: 0,
          ),
        ),

        const SizedBox(height: 16),

        MyTextField(
          labelText: '\u0417\u0430\u043c\u0435\u0442\u043a\u0430',
          hintText:
              '\u041f\u043e\u0436\u0435\u043b\u0430\u043d\u0438\u044f, \u043e\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u044f, \u043e\u043f\u0446\u0438\u0438',
          controller: _noteController,
          maxLines: 3,
        ),

        const SizedBox(height: 8),

        MyButton(
          buttonText: _isSubmittingTurnkey
              ? '\u041E\u0442\u043F\u0440\u0430\u0432\u043A\u0430...'
              : '\u041E\u0442\u043F\u0440\u0430\u0432\u0438\u0442\u044C \u0437\u0430\u044F\u0432\u043A\u0443',

          onTap: () {
            if (_isSubmittingTurnkey) return;
            _submitTurnkey();
          },
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

class _MultiSelectField extends StatelessWidget {
  const _MultiSelectField({
    required this.label,

    required this.placeholder,

    required this.value,

    this.displayValue,
    this.errorText,
    this.showItemsAsList = false,

    required this.onTap,
  });

  final String label;

  final String placeholder;

  final List<String> value;

  final List<String>? displayValue;
  final String? errorText;
  final bool showItemsAsList;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effective = displayValue ?? value;

    final text = effective.isEmpty
        ? placeholder
        : effective.length <= 2
        ? effective.join(', ')
        : '${effective.take(2).join(', ')} +${effective.length - 2}';
    final hasError = (errorText?.trim().isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        SizedBox(
          height: 16,

          child: Align(
            alignment: Alignment.centerLeft,

            child: MyText(
              text: label,

              size: 14,

              weight: FontWeight.bold,

              maxLines: 1,

              textOverflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        const SizedBox(height: 6),

        InkWell(
          onTap: onTap,

          borderRadius: BorderRadius.circular(8),

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

            decoration: BoxDecoration(
              color: kWhiteColor,

              borderRadius: BorderRadius.circular(8),

              border: Border.all(
                color: hasError ? kRedColor : kBorderColor,
                width: 1,
              ),
            ),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: showItemsAsList && effective.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final item in effective.take(4))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '\u2022 $item',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kTertiaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (effective.length > 4)
                              Text(
                                '+${effective.length - 4} \u0435\u0449\u0451',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kSecondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        )
                      : Text(
                          text,
                          style: TextStyle(
                            fontSize: 12,
                            color: value.isEmpty ? kHintColor : kTertiaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const Icon(Icons.expand_more, size: 18, color: kGreyColor),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MyText(text: errorText ?? '', size: 11, color: kRedColor),
          ),
      ],
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,

    required this.placeholder,

    required this.value,

    required this.enabled,

    required this.loading,

    required this.onTap,
  });

  final String label;

  final String placeholder;

  final String value;

  final bool enabled;

  final bool loading;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value.isNotEmpty
        ? value
        : loading
        ? '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430...'
        : enabled
        ? placeholder
        : '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0432\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043c\u0430\u0440\u043a\u0443 \u0438 \u043c\u043e\u0434\u0435\u043b\u044c';

    final color = value.isNotEmpty
        ? kTertiaryColor
        : (enabled ? kHintColor : kGreyColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        SizedBox(
          height: 16,

          child: Align(
            alignment: Alignment.centerLeft,

            child: MyText(
              text: label,

              size: 12,

              weight: FontWeight.bold,

              maxLines: 1,

              textOverflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        const SizedBox(height: 6),

        InkWell(
          onTap: enabled ? onTap : null,

          borderRadius: BorderRadius.circular(8),

          child: Container(
            height: 48,

            padding: const EdgeInsets.symmetric(horizontal: 14),

            decoration: BoxDecoration(
              color: kWhiteColor,

              borderRadius: BorderRadius.circular(8),

              border: Border.all(color: kBorderColor, width: 1),
            ),

            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,

                    style: TextStyle(
                      fontSize: 12,

                      color: color,

                      fontWeight: FontWeight.w500,
                    ),

                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (loading)
                  const SizedBox(
                    width: 16,

                    height: 16,

                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.expand_more, size: 18, color: kGreyColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RestylingMeta {
  const _RestylingMeta({
    required this.generation,
    required this.restylingId,

    required this.yearStart,

    required this.yearEnd,

    required this.frames,
    required this.restylingLabel,
  });

  final int generation;
  final int? restylingId;

  final int? yearStart;

  final int? yearEnd;

  final List<String> frames;
  final String restylingLabel;
}

class _RestylingCardData {
  const _RestylingCardData({
    required this.value,

    required this.title,

    required this.subtitle,

    required this.imageUrl,
  });

  final String value;

  final String title;

  final String subtitle;

  final String imageUrl;
}

class _CollapsedRestylingOption {
  const _CollapsedRestylingOption({
    required this.value,
    required this.values,
    required this.restylingIds,
    required this.card,
  });

  final String value;
  final List<String> values;
  final List<int> restylingIds;
  final _RestylingCardData card;
}

class _CollapsedSortKey {
  const _CollapsedSortKey({required this.generation, required this.start});

  final int generation;
  final int start;
}

class _PickerYearRange {
  const _PickerYearRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final int? start;
  final int? end;
  final String label;

  bool get isUnknown => start == null && end == null;
}

class _CollapsedRestylingGroup {
  _CollapsedRestylingGroup({required this.generation});

  final int generation;
  final List<String> values = [];
  final List<int> restylingIds = [];
  final List<_PickerYearRange> ranges = [];
  final List<String> restylings = [];
  final List<String> modifications = [];
  String imageUrl = '';

  void addValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (!values.contains(trimmed)) values.add(trimmed);
  }

  void addRestylingId(int id) {
    if (id <= 0) return;
    if (!restylingIds.contains(id)) restylingIds.add(id);
  }

  void addRange(_PickerYearRange range) {
    final label = range.label.trim();
    if (label.isEmpty) return;
    if (!ranges.any((r) => r.label == label)) {
      ranges.add(range);
    }
  }

  void addRestyling(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (!restylings.contains(trimmed)) restylings.add(trimmed);
  }

  void addModifications(List<String> items) {
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      if (!modifications.contains(trimmed)) modifications.add(trimmed);
    }
  }

  void addImageUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (imageUrl.isEmpty) imageUrl = trimmed;
  }

  List<String> sortedYearLabels() {
    final rows = List<_PickerYearRange>.from(ranges);
    rows.sort((a, b) {
      final aEnd = a.end ?? a.start ?? -1;
      final bEnd = b.end ?? b.start ?? -1;
      final byEnd = bEnd.compareTo(aEnd);
      if (byEnd != 0) return byEnd;
      final aStart = a.start ?? a.end ?? -1;
      final bStart = b.start ?? b.end ?? -1;
      return bStart.compareTo(aStart);
    });
    return rows.map((e) => e.label).toList();
  }

  List<String> sortedRestylings() {
    final out = List<String>.from(restylings);
    out.sort((a, b) {
      if (a == b) return 0;
      if (a == 'стартовый') return -1;
      if (b == 'стартовый') return 1;
      final aNum = int.tryParse(a);
      final bNum = int.tryParse(b);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return a.compareTo(b);
    });
    return out;
  }

  List<String> sortedModifications() {
    final out = List<String>.from(modifications);
    out.sort();
    return out;
  }
}

class _RestylingCard extends StatelessWidget {
  const _RestylingCard({
    required this.title,

    required this.subtitle,

    required this.imageUrl,

    required this.selected,

    required this.onTap,
  });

  final String title;

  final String subtitle;

  final String imageUrl;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(12),

      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(
            color: selected ? kSecondaryColor : kBorderColor,

            width: selected ? 1.5 : 1,
          ),
        ),

        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),

                  child: AspectRatio(
                    aspectRatio: 16 / 9,

                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              Assets.imagesNoImageFound,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            Assets.imagesNoImageFound,

                            fit: BoxFit.cover,
                          ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      MyText(text: title, size: 12, weight: FontWeight.w700),

                      if (subtitle.isNotEmpty)
                        MyText(text: subtitle, size: 10, color: kGreyColor),
                    ],
                  ),
                ),
              ],
            ),

            if (selected)
              Positioned(
                right: 8,

                top: 8,

                child: Container(
                  padding: const EdgeInsets.all(4),

                  decoration: BoxDecoration(
                    color: kSecondaryColor,

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(Icons.check, size: 12, color: kWhiteColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

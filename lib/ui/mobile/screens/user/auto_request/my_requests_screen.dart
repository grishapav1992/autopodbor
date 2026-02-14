import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/auto_request_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/my_request_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key, this.refresh});

  final ValueNotifier<int>? refresh;

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _requestCardKeys = {};
  Timer? _newRequestTimer;
  int? _newRequestId;
  String _newRequestNumber = '';

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_handleRefresh);
    _load();
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_handleRefresh);
    _newRequestTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    List<Map<String, dynamic>> list = [];
    Map<String, dynamic> overrides = {};
    try {
      list = await StorageApi.getRequests();
    } catch (_) {}
    try {
      overrides = await UserSimplePreferences.getRequestDisplayOverrides();
    } catch (_) {}
    final normalized = list
        .map((raw) => _normalizeRequest(raw, overrides))
        .toList();
    if (!mounted) return;
    setState(() {
      _requests = normalized;
      _loading = false;
    });
    _scrollToNewRequest();
  }

  int? _requestIdFromData(Map<String, dynamic> data) {
    final raw = data['id'] ?? data['requestId'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  String _requestNumberFromData(Map<String, dynamic> data) {
    return (data['requestNumber'] ??
            data['request_number'] ??
            data['number'] ??
            '')
        .toString()
        .trim();
  }

  String _requestTokenFromData(Map<String, dynamic> data) {
    final id = _requestIdFromData(data);
    if (id != null && id > 0) return 'id:$id';
    final number = _requestNumberFromData(data);
    if (number.isNotEmpty) return 'number:$number';
    return 'hash:${data.hashCode}';
  }

  GlobalKey _requestCardKey(Map<String, dynamic> data) {
    final token = _requestTokenFromData(data);
    return _requestCardKeys.putIfAbsent(token, () => GlobalKey());
  }

  bool _matchesNewRequest(Map<String, dynamic> data) {
    final id = _requestIdFromData(data);
    if (_newRequestId != null && id == _newRequestId) return true;
    if (_newRequestNumber.isNotEmpty &&
        _requestNumberFromData(data) == _newRequestNumber) {
      return true;
    }
    return false;
  }

  void _markNewRequest({int? requestId, String requestNumber = ''}) {
    _newRequestTimer?.cancel();
    setState(() {
      _newRequestId = requestId;
      _newRequestNumber = requestNumber.trim();
    });
    _newRequestTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() {
        _newRequestId = null;
        _newRequestNumber = '';
      });
    });
  }

  void _scrollToNewRequest() {
    if (_newRequestId == null && _newRequestNumber.isEmpty) return;
    Map<String, dynamic>? target;
    for (final request in _requests) {
      if (_matchesNewRequest(request)) {
        target = request;
        break;
      }
    }
    if (target == null) return;
    _scrollToRequestToken(_requestTokenFromData(target));
  }

  void _scrollToRequestToken(String token, {int attempt = 0}) {
    if (!mounted) return;
    final key = _requestCardKeys[token];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.12,
      );
      return;
    }
    if (attempt >= 6) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _scrollToRequestToken(token, attempt: attempt + 1);
      });
    });
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  String _formatServerDate(dynamic raw) {
    if (raw == null) return '';
    if (raw is DateTime) return _formatDate(raw);
    if (raw is Map) {
      final mapDate = raw['date'] ?? raw['datetime'] ?? raw['value'];
      if (mapDate != null) {
        return _formatServerDate(mapDate);
      }
    }
    if (raw is num) {
      final ms = raw > 1000000000000 ? raw.toInt() : (raw * 1000).toInt();
      return _formatDate(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    final dateMatch = RegExp(r'(\\d{4}-\\d{2}-\\d{2})').firstMatch(text);
    if (dateMatch != null) {
      final isoDate = dateMatch.group(1) ?? '';
      if (isoDate.isNotEmpty) {
        try {
          return _formatDate(DateTime.parse(isoDate));
        } catch (_) {}
      }
    }
    try {
      return _formatDate(DateTime.parse(text));
    } catch (_) {}
    return text;
  }

  String _normalizeStatus(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return 'Создана';
    final lower = text.toLowerCase();
    if (lower.contains('создан') || lower.contains('create')) return 'Создана';
    if (lower.contains('ожид') || lower.contains('wait')) {
      return 'Ожидает оплаты';
    }
    if (lower.contains('опла') || lower.contains('paid')) {
      return 'Оплачено (эскроу)';
    }
    if (lower.contains('работ') || lower.contains('progress')) {
      return 'В работе';
    }
    if (lower.contains('заверш') ||
        lower.contains('done') ||
        lower.contains('complete')) {
      return 'Завершена';
    }
    if (lower.contains('отмен') || lower.contains('cancel')) return 'Отменена';
    if (lower.contains('возврат') || lower.contains('refund')) return 'Возврат';
    return text;
  }

  Map<String, dynamic> _normalizeRequest(
    Map<String, dynamic> raw,
    Map<String, dynamic> overrides,
  ) {
    final typeRaw = raw['requestType'] ?? raw['type'] ?? raw['request_type'];
    final type = typeRaw?.toString() == 'turnkey' ? 'turnkey' : 'by_car';
    final createdAt = _formatServerDate(
      raw['createdAt'] ?? raw['created_at'] ?? raw['created'],
    );
    final dueDate = _formatServerDate(
      raw['dueAt'] ?? raw['due_at'] ?? raw['due'],
    );
    final requestNumber =
        raw['requestNumber'] ?? raw['request_number'] ?? raw['number'] ?? '';
    final title =
        raw['title']?.toString() ??
        (type == 'turnkey' ? 'Под ключ' : 'По авто');
    final subtitle = raw['subtitle']?.toString() ?? '';
    final data = <String, dynamic>{
      'id': raw['id'] ?? raw['requestId'],
      'requestNumber': requestNumber,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'status': _normalizeStatus(raw['status'] ?? raw['state']),
      'createdAt': createdAt,
      'dueDate': dueDate,
      'server': true,
    };
    const passthroughKeys = [
      'city',
      'cityName',
      'location',
      'make',
      'brand',
      'mark',
      'makeName',
      'brandName',
      'markName',
      'model',
      'modelName',
      'modelRus',
      'budgetFrom',
      'budgetTo',
      'budget',
      'mileageTo',
      'ownersCount',
      'note',
      'comment',
      'description',
      'makes',
      'models',
      'restylings',
    ];
    for (final key in passthroughKeys) {
      if (raw[key] != null) data[key] = raw[key];
    }
    if (raw['requestCars'] != null) data['requestCars'] = raw['requestCars'];
    if (raw['cars'] != null && data['requestCars'] == null) {
      data['requestCars'] = raw['cars'];
    }
    final override = _findOverride(raw, overrides);
    if (override != null) {
      for (final key in passthroughKeys) {
        if (override[key] != null) data[key] = override[key];
      }
      if (override['requestCars'] is List) {
        data['requestCars'] = override['requestCars'];
      }
      if (override['cars'] is List && data['requestCars'] == null) {
        data['requestCars'] = override['cars'];
      }
    }
    return data;
  }

  Map<String, dynamic>? _findOverride(
    Map<String, dynamic> raw,
    Map<String, dynamic> overrides,
  ) {
    if (overrides.isEmpty) return null;
    final id = raw['id'] ?? raw['requestId'];
    if (id != null) {
      final byId = overrides[id.toString()];
      if (byId is Map) {
        return byId.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    final number =
        raw['requestNumber'] ?? raw['request_number'] ?? raw['number'];
    if (number != null) {
      final byNumber = overrides[number.toString()];
      if (byNumber is Map) {
        return byNumber.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return null;
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => const AutoRequestScreen()),
    );
    var created = result == true;
    int? createdId;
    var createdNumber = '';
    if (result is Map) {
      created = result['created'] == true || created;
      final rawId = result['requestId'] ?? result['id'];
      if (rawId is int) {
        createdId = rawId;
      } else if (rawId is num) {
        createdId = rawId.toInt();
      } else if (rawId is String) {
        createdId = int.tryParse(rawId);
      }
      createdNumber = (result['requestNumber'] ?? result['number'] ?? '')
          .toString();
    }
    if (created) {
      _markNewRequest(requestId: createdId, requestNumber: createdNumber);
      _load();
    }
  }

  Future<void> _openDetail(Map<String, dynamic> request) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MyRequestDetailScreen(request: request),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_loading) {
      content = const Center(child: CircularProgressIndicator(strokeWidth: 2));
      return SafeArea(top: true, bottom: false, child: content);
    }

    if (_requests.isEmpty) {
      content = Center(
        child: Padding(
          padding: AppSizes.DEFAULT,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MyText(
                text: 'Пока нет созданных заявок',
                size: 14,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 12),
              MyButton(
                buttonText: 'Создать заявку',
                onTap: _openCreate,
                textSize: 12,
              ),
            ],
          ),
        ),
      );
      return SafeArea(top: true, bottom: false, child: content);
    }

    content = ListView(
      controller: _scrollController,
      padding: AppSizes.listPaddingWithBottomBar(),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            MyText(text: 'Мои заявки', size: 18, weight: FontWeight.w700),
            TextButton.icon(
              onPressed: _openCreate,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add, size: 18, color: kSecondaryColor),
              label: const Text(
                'Новая заявка',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kSecondaryColor, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._requests.map((r) {
          return _RequestCard(
            key: _requestCardKey(r),
            data: r,
            isFresh: _matchesNewRequest(r),
            onTap: () => _openDetail(r),
          );
        }),
      ],
    );

    return SafeArea(top: true, bottom: false, child: content);
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.data,
    required this.onTap,
    this.isFresh = false,
  });

  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final bool isFresh;

  String _cleanInternalRestTag(String text) {
    final cleaned = text.replaceAll(RegExp(r'\brest:\d+\b'), '').trim();
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
  }

  String _normalizeRequestNumber(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (RegExp(r'[A-Za-z]').hasMatch(value)) return value;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return value;
    final six = digits.length > 6
        ? digits.substring(digits.length - 6)
        : digits.padLeft(6, '0');
    return 'F$six';
  }

  String _requestMeta(String requestNumber, String createdAt) {
    final num = _normalizeRequestNumber(requestNumber);
    final date = createdAt.trim();
    if (num.isEmpty && date.isEmpty) return '';
    if (num.isEmpty) return date;
    if (date.isEmpty) return '№ $num';
    return '№ $num | $date';
  }

  String _stringFromAny(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is num || raw is bool) return raw.toString();
    if (raw is List) {
      for (final item in raw) {
        final value = _stringFromAny(item);
        if (value.isNotEmpty) return value;
      }
      return '';
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in const [
        'nameRus',
        'name',
        'modelRus',
        'model',
        'brandName',
        'makeName',
        'markName',
        'displayName',
        'value',
        'title',
      ]) {
        final value = _stringFromAny(map[key]);
        if (value.isNotEmpty) return value;
      }
      for (final value in map.values) {
        final nested = _stringFromAny(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return raw.toString().trim();
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String _firstStringByKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = _stringFromAny(source[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _carLabel(Map<String, dynamic> car) {
    final candidates = <Map<String, dynamic>>[
      car,
      _asMap(car['car']) ?? const <String, dynamic>{},
      _asMap(car['requestCar']) ?? const <String, dynamic>{},
      _asMap(car['modelCar']) ?? const <String, dynamic>{},
      _asMap(car['brand']) ?? const <String, dynamic>{},
      _asMap(car['make']) ?? const <String, dynamic>{},
      _asMap(car['mark']) ?? const <String, dynamic>{},
      _asMap(car['model']) ?? const <String, dynamic>{},
    ].where((e) => e.isNotEmpty).toList();

    for (final map in candidates) {
      final brand = _firstStringByKeys(map, const [
        'brand',
        'brandName',
        'make',
        'makeName',
        'mark',
        'markName',
      ]);
      final model = _firstStringByKeys(map, const [
        'model',
        'modelName',
        'modelRus',
        'nameRus',
        'name',
      ]);
      if (brand.isNotEmpty && model.isNotEmpty) return '$brand $model';
      if (brand.isNotEmpty) return brand;
      if (model.isNotEmpty) return model;
    }

    final fallback = _firstStringByKeys(car, const ['title', 'displayName']);
    if (fallback.isNotEmpty) return fallback;
    return '';
  }

  String _extractCarSummary(Map<String, dynamic> data, {required String type}) {
    List<String> collectTopValues(List<String> keys) {
      final out = <String>[];
      for (final key in keys) {
        final raw = data[key];
        if (raw is List) {
          for (final item in raw) {
            final text = _stringFromAny(item);
            if (text.isEmpty || out.contains(text)) continue;
            out.add(text);
          }
        } else {
          final text = _stringFromAny(raw);
          if (text.isEmpty || out.contains(text)) continue;
          out.add(text);
        }
      }
      return out;
    }

    final topMakes = collectTopValues(const [
      'makes',
      'make',
      'brand',
      'mark',
      'makeName',
      'brandName',
      'markName',
    ]);
    final topModels = collectTopValues(const [
      'models',
      'model',
      'modelName',
      'modelRus',
    ]);

    final normalizedType = type.toString().toLowerCase();
    final isTurnkey =
        normalizedType == 'turnkey' ||
        normalizedType.contains('turn') ||
        normalizedType.contains('key') ||
        data.containsKey('makes') ||
        data.containsKey('models') ||
        data.containsKey('restylings');

    if (isTurnkey) {
      final makes = List<String>.from(topMakes);
      final models = List<String>.from(topModels);
      final labels = <String>[];

      if (makes.isEmpty && models.isEmpty) {
        final rawCars = data['requestCars'] ?? data['cars'];
        if (rawCars is List) {
          for (final item in rawCars) {
            if (item is! Map) continue;
            final car = Map<String, dynamic>.from(item);
            final candidates = <Map<String, dynamic>>[
              car,
              _asMap(car['car']) ?? const <String, dynamic>{},
              _asMap(car['requestCar']) ?? const <String, dynamic>{},
              _asMap(car['modelCar']) ?? const <String, dynamic>{},
              _asMap(car['brand']) ?? const <String, dynamic>{},
              _asMap(car['make']) ?? const <String, dynamic>{},
              _asMap(car['mark']) ?? const <String, dynamic>{},
              _asMap(car['model']) ?? const <String, dynamic>{},
            ].where((e) => e.isNotEmpty).toList();
            for (final map in candidates) {
              final make = _firstStringByKeys(map, const [
                'make',
                'brand',
                'mark',
                'makeName',
                'brandName',
                'markName',
              ]);
              final model = _firstStringByKeys(map, const [
                'model',
                'modelName',
                'modelRus',
              ]);
              if (make.isNotEmpty && !makes.contains(make)) makes.add(make);
              if (model.isNotEmpty && !models.contains(model)) {
                models.add(model);
              }
            }
            final label = _carLabel(car);
            if (label.isNotEmpty && !labels.contains(label)) labels.add(label);
          }
        }
      }

      if (makes.isEmpty && models.isEmpty) {
        if (labels.isEmpty) return '';
        if (labels.length <= 2) return labels.join(', ');
        return '${labels[0]}, ${labels[1]} и еще ${labels.length - 2}';
      }
      final primaryMake = makes.isNotEmpty ? makes.first : '';
      final primaryModel = models.isNotEmpty ? models.first : '';
      final primary = [
        primaryMake,
        primaryModel,
      ].where((e) => e.isNotEmpty).join(' ');
      if (primary.isNotEmpty) return primary;
      if (makes.isNotEmpty) return makes.join(', ');
      return models.join(', ');
    }
    if (topMakes.isNotEmpty || topModels.isNotEmpty) {
      final primaryMake = topMakes.isNotEmpty ? topMakes.first : '';
      final primaryModel = topModels.isNotEmpty ? topModels.first : '';
      final primary = [
        primaryMake,
        primaryModel,
      ].where((e) => e.isNotEmpty).join(' ');
      if (primary.isNotEmpty) return primary;
      if (topMakes.isNotEmpty) return topMakes.join(', ');
      return topModels.join(', ');
    }
    final rawCars = data['requestCars'] ?? data['cars'];
    if (rawCars is! List) return '';
    final labels = <String>[];
    for (final item in rawCars) {
      if (item is! Map) continue;
      final car = Map<String, dynamic>.from(item);
      final label = _carLabel(car);
      if (label.isEmpty || labels.contains(label)) continue;
      labels.add(label);
    }
    if (labels.isEmpty) return '';
    if (labels.length <= 2) return labels.join(', ');
    return '${labels[0]}, ${labels[1]} и еще ${labels.length - 2}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Создана':
        return kSecondaryColor;
      case 'Ожидает оплаты':
        return kYellowColor;
      case 'Оплачено (эскроу)':
        return kBlueColor;
      case 'В работе':
        return kYellowColor;
      case 'Завершена':
        return kGreenColor;
      case 'Отменена':
        return kRedColor;
      case 'Возврат':
        return kRedColor;
      default:
        return kGreyColor;
    }
  }

  Widget _buildDueBadge(String value, {double textSize = 11}) {
    final tone = kYellowColor.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kYellowColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kYellowColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: tone),
          const SizedBox(width: 4),
          MyText(
            text: 'Срок до $value',
            size: textSize,
            weight: FontWeight.w700,
            color: tone,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'by_car';
    final title = _cleanInternalRestTag((data['title'] ?? 'Заявка').toString());
    final requestNumber = data['requestNumber'] ?? data['id'] ?? '';
    final createdAt = data['createdAt'] ?? '';
    final dueDate = data['dueDate']?.toString() ?? '';
    final requestMeta = _requestMeta(
      requestNumber.toString(),
      createdAt.toString(),
    );
    final status = data['status'] ?? 'Создана';
    final statusColor = _statusColor(status);
    final carSummary = _extractCarSummary(data, type: type.toString());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFresh
              ? kSecondaryColor.withValues(alpha: 0.06)
              : kWhiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFresh
                ? kSecondaryColor.withValues(alpha: 0.5)
                : kBorderColor,
            width: isFresh ? 1.3 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (requestMeta.isNotEmpty) ...[
              MyText(
                text: requestMeta,
                size: 11,
                weight: FontWeight.w600,
                color: kGreyColor,
              ),
              const SizedBox(height: 4),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final chip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: MyText(
                    text: type == 'turnkey' ? 'Под ключ' : 'По авто',
                    size: 10,
                    weight: FontWeight.w700,
                    color: kSecondaryColor,
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(text: title, size: 14, weight: FontWeight.w700),
                      if (carSummary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        MyText(text: carSummary, size: 11, color: kGreyColor),
                      ],
                      const SizedBox(height: 6),
                      chip,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: title,
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                          if (carSummary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            MyText(
                              text: carSummary,
                              size: 11,
                              color: kGreyColor,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    chip,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (isFresh)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kSecondaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const MyText(
                      text: 'Новая',
                      size: 10,
                      weight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                  ),
                MyText(
                  text: status,
                  size: 12,
                  weight: FontWeight.w600,
                  color: statusColor,
                ),
                if (dueDate.isNotEmpty) _buildDueBadge(dueDate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

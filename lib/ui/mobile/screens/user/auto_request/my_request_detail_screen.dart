import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';

import 'package:flutter_application_1/core/constants/app_sizes.dart';

import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';

import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/inspector_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

const String kStatusCreated = 'Создана';

const String kStatusAwaitPayment = 'Ожидает оплаты';

const String kStatusPaid = 'Оплачено (эскроу)';

const String kStatusInWork = 'В работе';

const String kStatusDone = 'Завершена';

const String kStatusCanceled = 'Отменена';

const String kStatusRefund = 'Возврат';

class MyRequestDetailScreen extends StatefulWidget {
  const MyRequestDetailScreen({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  State<MyRequestDetailScreen> createState() => _MyRequestDetailScreenState();
}

class _MyRequestDetailScreenState extends State<MyRequestDetailScreen> {
  late Map<String, dynamic> _data;
  bool _loadingCars = false;

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _offersKey = GlobalKey();

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
    final six = digits.length > 6 ? digits.substring(digits.length - 6) : digits.padLeft(6, '0');
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

  @override
  void initState() {
    super.initState();

    _data = Map<String, dynamic>.from(widget.request);
    _applyDisplayOverride();
    if (_isServerRequest()) {
      _loadServerCars();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  bool _isServerRequest() {
    return _data['server'] == true;
  }

  int? _requestId() {
    final raw = _data['id'] ?? _data['requestId'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
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

  Future<void> _loadServerCars() async {
    final id = _requestId();
    if (id == null) return;
    setState(() {
      _loadingCars = true;
    });
    List<Map<String, dynamic>> cars = [];
    try {
      cars = await StorageApi.getRequestCars(requestId: id);
    } catch (_) {}
    if (!mounted) return;
    final previousCars = (_data['requestCars'] as List<dynamic>?) ?? const [];
    final overrideCars = _data['requestCarsOverride'];
    var mergedCars = cars.isNotEmpty ? cars : previousCars;
    if (overrideCars is List && overrideCars.isNotEmpty) {
      mergedCars = _mergeOverrideCars(overrideCars, mergedCars);
    }
    final dueDate =
        _data['dueDate']?.toString().isNotEmpty == true ? _data['dueDate'] : _extractDueDate(cars);
    setState(() {
      _data['requestCars'] = mergedCars;
      if (dueDate != null && dueDate.toString().isNotEmpty) {
        _data['dueDate'] = dueDate;
      }
      _loadingCars = false;
    });
  }

  Future<void> _applyDisplayOverride() async {
    final override = await _loadDisplayOverride();
    if (override == null) return;
    if (!mounted) return;
    final cars = override['requestCars'];
    if (cars is List && cars.isNotEmpty) {
      setState(() {
        _data['requestCarsOverride'] = cars;
        final existing = _data['requestCars'] as List<dynamic>?;
        if (existing == null || existing.isEmpty) {
          _data['requestCars'] = cars;
        }
      });
    }
  }

  Future<Map<String, dynamic>?> _loadDisplayOverride() async {
    final id = _requestId();
    if (id != null) {
      final byId = await UserSimplePreferences.getRequestDisplayOverride(
        id.toString(),
      );
      if (byId != null) return byId;
    }
    final number = _data['requestNumber'] ?? _data['request_number'] ?? _data['number'];
    if (number != null) {
      return UserSimplePreferences.getRequestDisplayOverride(number.toString());
    }
    return null;
  }

  List<Map<String, dynamic>> _mergeOverrideCars(
    List<dynamic> overrideCars,
    List<dynamic> serverCars,
  ) {
    final merged = <Map<String, dynamic>>[];
    final maxLen = overrideCars.length > serverCars.length
        ? overrideCars.length
        : serverCars.length;
    for (var i = 0; i < maxLen; i++) {
      Map<String, dynamic>? overrideCar;
      if (i < overrideCars.length && overrideCars[i] is Map) {
        overrideCar = Map<String, dynamic>.from(overrideCars[i] as Map);
      }
      Map<String, dynamic>? serverCar;
      if (i < serverCars.length && serverCars[i] is Map) {
        serverCar = Map<String, dynamic>.from(serverCars[i] as Map);
      }
      if (serverCar != null && overrideCar != null) {
        merged.add({...serverCar, ...overrideCar});
      } else if (overrideCar != null) {
        merged.add(overrideCar);
      } else if (serverCar != null) {
        merged.add(serverCar);
      }
    }
    return merged;
  }

  String _extractDueDate(List<Map<String, dynamic>> cars) {
    for (final car in cars) {
      final raw = car['dueAt'] ?? car['due_at'] ?? car['due'];
      final formatted = _formatServerDate(raw);
      if (formatted.isNotEmpty) return formatted;
    }
    return '';
  }

  Future<void> _updateRequest(Map<String, dynamic> patch) async {
    if (_isServerRequest()) return;
    setState(() {
      _data.addAll(patch);
    });
  }

  List<Map<String, dynamic>> _offers() {
    final raw = _data['offers'] as List<dynamic>?;

    if (raw == null) return [];

    return raw.map((o) => Map<String, dynamic>.from(o as Map)).toList();
  }

  Set<String> _canceledOffers() {
    final raw = _data['canceledOffers'] as List<dynamic>?;

    if (raw == null) return {};

    return raw.map((e) => e.toString()).toSet();
  }

  Map<String, dynamic>? _selectedOffer() {
    final id = _data['selectedOfferId']?.toString();

    if (id == null || id.isEmpty) return null;

    for (final offer in _offers()) {
      if (offer['id']?.toString() == id) return offer;
    }

    return null;
  }

  List<int> _extractRestylingIds(dynamic raw) {
    final ids = <int>[];
    if (raw is List) {
      for (final item in raw) {
        final id = _extractRestylingIds(item);
        ids.addAll(id);
      }
      return ids;
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      ids.addAll(_extractRestylingIds(map['id']));
      ids.addAll(_extractRestylingIds(map['restylingId']));
      ids.addAll(_extractRestylingIds(map['generationId']));
      ids.addAll(_extractRestylingIds(map['restyling']));
      ids.addAll(_extractRestylingIds(map['restylings']));
      ids.addAll(_extractRestylingIds(map['generation']));
      ids.addAll(_extractRestylingIds(map['generations']));
      return ids;
    }
    if (raw is int) return [raw];
    if (raw is num) return [raw.toInt()];
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return ids;
    final match = RegExp(r'rest:(\d+)').firstMatch(text);
    if (match != null) {
      final parsed = int.tryParse(match.group(1) ?? '');
      if (parsed != null) ids.add(parsed);
      return ids;
    }
    final parsed = int.tryParse(text);
    if (parsed != null) ids.add(parsed);
    return ids;
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) {
      final out = <String>[];
      for (final item in raw) {
        out.addAll(_stringList(item));
      }
      return out;
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in const [
        'nameRus',
        'modelRus',
        'markName',
        'brandName',
        'makeName',
        'generationName',
        'restylingName',
        'name',
        'model',
        'generation',
        'restyling',
      ]) {
        final values = _stringList(map[key]);
        if (values.isNotEmpty) return values;
      }
      final fallbackId = map['id'] ?? map['restylingId'] ?? map['generationId'];
      final idText = fallbackId?.toString().trim() ?? '';
      if (idText.isNotEmpty) return [idText];
      return const [];
    }
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return const [];
    return [value];
  }

  List<String> _collectRequestCarValues(
    List<dynamic> requestCars,
    List<String> keys,
  ) {
    final out = <String>{};
    for (final raw in requestCars) {
      if (raw is! Map) continue;
      final car = Map<String, dynamic>.from(raw);
      for (final key in keys) {
        out.addAll(_stringList(car[key]));
      }
    }
    return out.toList();
  }

  String _firstStringByKeys(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final values = _stringList(source[key]);
      if (values.isEmpty) continue;
      for (final value in values) {
        final cleaned = _cleanInternalRestTag(value).trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
    }
    return '';
  }

  String _carTitleFromMap(Map<String, dynamic> car) {
    final make = _firstStringByKeys(
      car,
      const ['makeName', 'brandName', 'markName', 'make', 'brand', 'mark'],
    );
    final model = _firstStringByKeys(
      car,
      const ['modelRus', 'modelName', 'model'],
    );
    return [make, model].where((e) => e.isNotEmpty).join(' ');
  }

  String _generationLabelFromCar(Map<String, dynamic> car) {
    final raw = car['generationName'] ?? car['generationLabel'] ?? car['generation'];
    final text = _cleanInternalRestTag(raw?.toString() ?? '').trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower.contains('покол')) return text;
    if (RegExp(r'^\d+$').hasMatch(text)) return 'Поколение $text';
    return 'Поколение $text';
  }

  List<String> _byCarRestylingLabels(Map<String, dynamic> car) {
    final out = <String>[];
    final explicit = [
      ..._stringList(car['restylingName']),
      ..._stringList(car['restylingDisplay']),
    ]
        .map((e) => _cleanInternalRestTag(e).trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final genRaw = car['generation'];
    final genNum = genRaw is num
        ? genRaw.toInt()
        : int.tryParse(genRaw?.toString() ?? '');
    if (genNum != null && genNum > 0) {
      out.add('Поколение $genNum');
    }

    final restylingRaw = car['restyling'] ?? car['restylings'];
    if (restylingRaw is Map) {
      final map = Map<String, dynamic>.from(restylingRaw);
      final restLabel = _restylingLabelFromMap(map);
      if (restLabel.isNotEmpty) out.add(restLabel);
    } else if (restylingRaw is List) {
      for (final item in restylingRaw) {
        if (item is! Map) continue;
        final restLabel = _restylingLabelFromMap(Map<String, dynamic>.from(item));
        if (restLabel.isNotEmpty) out.add(restLabel);
      }
    }

    if (out.isNotEmpty) {
      return out.toSet().toList();
    }

    final fallbackLabels = <String>[
      ..._stringList(car['generationName']),
      ..._stringList(car['restylingName']),
      ..._stringList(restylingRaw),
    ]
        .map((e) => _cleanInternalRestTag(e).trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (fallbackLabels.isNotEmpty) return fallbackLabels;

    final restylingIds = <int>[
      ..._extractRestylingIds(car['restylings']),
      ..._extractRestylingIds(car['restyling']),
      ..._extractRestylingIds(car['restylingId']),
      ..._extractRestylingIds(car['restylingIds']),
    ]
        .where((e) => e > 0)
        .toSet()
        .toList();
    return restylingIds.map((e) => 'Рестайлинг #$e').toList();
  }

  List<_TurnkeyRestylingCard> _turnkeyRestylingCards(
    List<dynamic> requestCars,
    List<dynamic> savedRestylings,
  ) {
    final cards = <_TurnkeyRestylingCard>[];
    for (final raw in requestCars) {
      if (raw is! Map) continue;
      final car = Map<String, dynamic>.from(raw);
      final restylingRaw = car['restyling'] ?? car['restylings'];
      final baseTitle = _carTitleFromMap(car);
      final generationLabel = _generationLabelFromCar(car);
      final fallbackPhoto = _extractCarPhotoUrl(car);
      cards.addAll(
        _cardsFromRestylingRaw(
          restylingRaw,
          baseTitle: baseTitle,
          generationLabel: generationLabel,
          fallbackPhotoUrl: fallbackPhoto,
        ),
      );
    }
    if (cards.isEmpty) {
      for (final raw in requestCars) {
        if (raw is! Map) continue;
        final car = Map<String, dynamic>.from(raw);
        final genRaw = car['generation'];
        final genNum = genRaw is num
            ? genRaw.toInt()
            : int.tryParse(genRaw?.toString() ?? '');
        if (genNum != null && genNum > 0) {
          final title = _carTitleFromMap(car);
          cards.add(
            _TurnkeyRestylingCard(
              title: title.isNotEmpty ? title : 'Поколение $genNum',
              subtitle: title.isNotEmpty ? 'Поколение $genNum' : '',
              photoUrl: _extractCarPhotoUrl(car),
            ),
          );
        }
      }
    }
    if (cards.isEmpty && savedRestylings.isNotEmpty) {
      for (final raw in savedRestylings) {
        final value = _cleanInternalRestTag(raw?.toString() ?? '').trim();
        if (value.isEmpty) continue;
        final label = RegExp(r'^\\d+$').hasMatch(value)
            ? 'Поколение #$value'
            : value;
        cards.add(
          _TurnkeyRestylingCard(title: label, subtitle: '', photoUrl: ''),
        );
      }
    }
    final seen = <String>{};
    final unique = <_TurnkeyRestylingCard>[];
    for (final card in cards) {
      final key = '${card.title}|${card.subtitle}|${card.photoUrl}';
      if (seen.add(key)) unique.add(card);
    }
    return unique;
  }

  List<_TurnkeyRestylingCard> _cardsFromRestylingRaw(
    dynamic restylingRaw, {
    required String baseTitle,
    required String generationLabel,
    required String fallbackPhotoUrl,
  }) {
    final cards = <_TurnkeyRestylingCard>[];
    final items = <Map<String, dynamic>>[];
    if (restylingRaw is Map) {
      items.add(Map<String, dynamic>.from(restylingRaw));
    } else if (restylingRaw is List) {
      for (final item in restylingRaw) {
        if (item is! Map) continue;
        items.add(Map<String, dynamic>.from(item));
      }
    }
    for (final map in items) {
      final years = _formatYearRange(map['yearStart'], map['yearEnd']);
      final frames = _stringList(map['frames'])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      final parts = <String>[];
      if (years.isNotEmpty) parts.add(years);
      if (frames.isNotEmpty) parts.add(frames.join(', '));
      final raw = map['restyling'] ??
          map['restylingName'] ??
          map['name'] ??
          map['title'];
      final restText = _cleanInternalRestTag(raw?.toString() ?? '').trim();
      if (restText.isNotEmpty) {
        final restLabel = RegExp(r'^\\d+$').hasMatch(restText)
            ? 'рестайлинг $restText'
            : restText;
        parts.add(restLabel);
      }
      final label = parts.join(', ').trim();
      final combinedParts = <String>[];
      if (generationLabel.isNotEmpty) combinedParts.add(generationLabel);
      if (label.isNotEmpty) combinedParts.add(label);
      final combined = combinedParts.join(' · ').trim();
      if (combined.isEmpty) continue;
      final photoRaw = _pickPhotoUrl(map['photos']);
      final photoUrl = photoRaw.isNotEmpty ? photoRaw : fallbackPhotoUrl;
      final title = baseTitle.isNotEmpty
          ? baseTitle
          : (generationLabel.isNotEmpty ? generationLabel : label);
      final subtitle = baseTitle.isNotEmpty
          ? combined
          : (generationLabel.isNotEmpty ? label : '');
      cards.add(
        _TurnkeyRestylingCard(
          title: title,
          subtitle: subtitle,
          photoUrl: photoUrl,
        ),
      );
    }
    return cards;
  }

  String _restylingLabelFromMap(Map<String, dynamic> map) {
    final raw = map['restyling'] ??
        map['name'] ??
        map['title'] ??
        map['restylingName'];
    final restValue = raw?.toString().trim() ?? '';
    final idText = map['id']?.toString().trim() ?? '';
    String label = '';
    if (restValue.isNotEmpty) {
      label = RegExp(r'^\d+$').hasMatch(restValue)
          ? 'Рестайлинг $restValue'
          : restValue;
    } else if (idText.isNotEmpty) {
      label = 'Рестайлинг #$idText';
    }
    final years = _formatYearRange(map['yearStart'], map['yearEnd']);
    if (label.isNotEmpty && years.isNotEmpty) {
      label = '$label ($years)';
    }
    return label;
  }

  int? _yearFromRaw(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return _yearFromRaw(
        map['date'] ?? map['value'] ?? map['datetime'] ?? map['year'],
      );
    }
    if (raw is String && raw.length >= 4) {
      return int.tryParse(raw.substring(0, 4));
    }
    return int.tryParse(raw.toString());
  }

  String _formatYearRange(dynamic startRaw, dynamic endRaw) {
    final start = _yearFromRaw(startRaw);
    final end = _yearFromRaw(endRaw);
    if (start == null && end == null) return '';
    if (start != null && end != null) return '$start–$end';
    if (start != null) return '$start–н.в.';
    return 'до $end';
  }

  String _photoUrlFromPhotoMap(Map<String, dynamic> photo) {
    final url = photo['url_x2'] ??
        photo['urlX2'] ??
        photo['url_x1'] ??
        photo['urlX1'] ??
        photo['url'] ??
        '';
    return url.toString();
  }

  String _pickPhotoUrl(dynamic photos) {
    if (photos is Map) {
      return _photoUrlFromPhotoMap(Map<String, dynamic>.from(photos));
    }
    if (photos is! List) return '';
    final list = photos.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (list.isEmpty) return '';
    final chosen = list.firstWhere(
      (p) => (p['size']?.toString().toLowerCase() ?? '') == 'm',
      orElse: () => list.firstWhere(
        (p) => (p['size']?.toString().toLowerCase() ?? '') == 's',
        orElse: () => list.first,
      ),
    );
    return _photoUrlFromPhotoMap(chosen);
  }

  String _extractCarPhotoUrl(Map<String, dynamic> car) {
    final direct = _pickPhotoUrl(car['photos']);
    if (direct.isNotEmpty) return direct;
    final restylings = car['restyling'] ?? car['restylings'];
    if (restylings is List) {
      for (final item in restylings) {
        if (item is! Map) continue;
        final url = _pickPhotoUrl(item['photos']);
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }

  void _addPhotoUrl(List<String> urls, String raw, int limit) {
    if (urls.length >= limit) return;
    final url = raw.trim();
    if (url.isEmpty) return;
    if (!urls.contains(url)) {
      urls.add(url);
    }
  }

  void _addPhotosFrom(dynamic photos, List<String> urls, int limit) {
    if (urls.length >= limit) return;
    if (photos is Map) {
      _addPhotoUrl(urls, _photoUrlFromPhotoMap(Map<String, dynamic>.from(photos)), limit);
      return;
    }
    if (photos is List) {
      final list = photos.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (list.isEmpty) return;
      final hasSize = list.any((p) => (p['size']?.toString().isNotEmpty ?? false));
      if (hasSize) {
        _addPhotoUrl(urls, _pickPhotoUrl(list), limit);
        return;
      }
      for (final item in list) {
        if (urls.length >= limit) break;
        _addPhotoUrl(urls, _photoUrlFromPhotoMap(item), limit);
      }
    }
  }

  List<String> _collectPhotoUrlsFromCar(Map<String, dynamic> car, {int limit = 8}) {
    final urls = <String>[];
    _addPhotosFrom(car['photos'], urls, limit);
    if (urls.length >= limit) return urls;
    final restylings = car['restyling'] ?? car['restylings'];
    if (restylings is Map) {
      _addPhotosFrom(restylings['photos'], urls, limit);
    } else if (restylings is List) {
      for (final item in restylings) {
        if (urls.length >= limit) break;
        if (item is! Map) continue;
        _addPhotosFrom(item['photos'], urls, limit);
      }
    }
    return urls;
  }

  List<String> _collectPhotoUrlsFromRequestCars(List<dynamic> requestCars, int limit) {
    final urls = <String>[];
    for (final raw in requestCars) {
      if (urls.length >= limit) break;
      if (raw is! Map) continue;
      final car = Map<String, dynamic>.from(raw);
      final carUrls = _collectPhotoUrlsFromCar(car, limit: limit - urls.length);
      for (final url in carUrls) {
        if (urls.length >= limit) break;
        if (!urls.contains(url)) {
          urls.add(url);
        }
      }
    }
    return urls;
  }

  Future<void> _openPhotoGallery(List<String> urls, {int initialIndex = 0}) async {
    final unique = <String>[];
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      if (!unique.contains(url)) unique.add(url);
    }
    if (unique.isEmpty) return;
    final safeIndex = initialIndex < 0
        ? 0
        : (initialIndex > unique.length - 1 ? unique.length - 1 : initialIndex);
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _PhotoGalleryScreen(
          urls: unique,
          initialIndex: safeIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildPhotoThumb(
    String url, {
    double size = 60,
    VoidCallback? onTap,
  }) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorderColor),
      ),
      child: const Icon(Icons.directions_car, size: 18, color: kGreyColor),
    );
    if (url.isEmpty) return placeholder;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
    if (onTap == null) return image;
    return GestureDetector(
      onTap: onTap,
      child: image,
    );
  }

  String _formatPhoneReadable(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
      final normalized = digits.startsWith('8') ? '7${digits.substring(1)}' : digits;
      return '+7 (${normalized.substring(1, 4)}) ${normalized.substring(4, 7)}-${normalized.substring(7, 9)}-${normalized.substring(9, 11)}';
    }
    return value;
  }

  String _urlHost(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.tryParse('https://$raw');
    }
    return (uri?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');
  }

  Future<void> _openListingUrl(String value) async {
    final raw = value.trim();
    if (raw.isEmpty) return;
    Uri? uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.tryParse('https://$raw');
    }
    if (uri == null) {
      _showError('Не удалось открыть ссылку.');
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _showError('Не удалось открыть ссылку.');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kSecondaryColor),
    );
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

  Future<void> _selectOffer(Map<String, dynamic> offer) async {
    final canceled = _canceledOffers();

    canceled.remove(offer['id']?.toString());

    await _updateRequest({
      'status': kStatusAwaitPayment,

      'selectedOfferId': offer['id'],

      'canceledOffers': canceled.toList(),
    });
  }

  Future<void> _cancelSelection() async {
    final selectedId = _data['selectedOfferId']?.toString();

    final canceled = _canceledOffers();

    if (selectedId != null && selectedId.isNotEmpty) {
      canceled.add(selectedId);
    }

    await _updateRequest({
      'status': kStatusCreated,

      'selectedOfferId': null,

      'paidAt': null,

      'canceledOffers': canceled.toList(),
    });
  }

  Future<void> _pay() async {
    await _updateRequest({
      'status': kStatusPaid,

      'paidAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _markDone() async {
    final id = _data['id'] as String?;
    if (id == null || id.isEmpty) return;
    await _updateRequest({'status': kStatusDone});
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Color _statusColor(String status) {
    switch (status) {
      case kStatusCreated:
        return kSecondaryColor;

      case kStatusAwaitPayment:
        return kYellowColor;

      case kStatusPaid:
        return kBlueColor;

      case kStatusInWork:
        return kYellowColor;

      case kStatusDone:
        return kGreenColor;

      case kStatusCanceled:
        return kRedColor;

      case kStatusRefund:
        return kRedColor;

      default:
        return kGreyColor;
    }
  }

  int _stepIndex(String status) {
    switch (status) {
      case kStatusCreated:
        return 0;

      case kStatusAwaitPayment:
        return 1;

      case kStatusPaid:
        return 2;

      case kStatusInWork:
        return 3;

      case kStatusDone:
        return 4;

      default:
        return 0;
    }
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');

    final m = value.month.toString().padLeft(2, '0');

    return '$d.$m.${value.year}';
  }

  String _dueDateLabel(Map<String, dynamic>? offer) {
    if (offer == null) return '';

    final daysRaw = offer['days'];

    int days = 0;

    if (daysRaw is num) {
      days = daysRaw.toInt();
    } else if (daysRaw is String) {
      days = int.tryParse(daysRaw) ?? 0;
    }

    if (days <= 0) return '';

    DateTime base = DateTime.now();

    final paidAt = _data['paidAt']?.toString();

    if (paidAt != null && paidAt.isNotEmpty) {
      try {
        base = DateTime.parse(paidAt);
      } catch (_) {}
    }

    final due = base.add(Duration(days: days));

    return _formatDate(due);
  }

  Future<void> _scrollToOffers() async {
    final ctx = _offersKey.currentContext;

    if (ctx == null) return;

    await Scrollable.ensureVisible(
      ctx,

      duration: const Duration(milliseconds: 300),

      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _data['type'] ?? 'by_car';

    final status = _data['status'] ?? kStatusCreated;
    final isServer = _isServerRequest();

    var title = _cleanInternalRestTag((_data['title'] ?? '').toString());
    if (title.isEmpty) {
      title = type == 'turnkey' ? 'Под ключ' : 'По авто';
    }

    final subtitle = _cleanInternalRestTag(
      (_data['subtitle'] ?? '').toString(),
    );

    final selectedOffer = isServer ? null : _selectedOffer();
    final dueDate = _data['dueDate']?.toString() ?? '';
    final requestMeta = _requestMeta(
      (_data['requestNumber'] ?? _data['id'] ?? '').toString(),
      (_data['createdAt'] ?? '').toString(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявка'),

        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(true),

          icon: const Icon(Icons.arrow_back),
        ),
      ),

      body: ListView(
        controller: _scrollController,

        padding: AppSizes.listPaddingWithBottomBar(),

        children: [
          _StepBar(status: status, current: _stepIndex(status)),

          const SizedBox(height: 10),

          if (!isServer) ...[
            _MainAction(
              status: status,

              dueDate: _dueDateLabel(selectedOffer),

              onPrimary:
                  (status == kStatusCreated || status == kStatusAwaitPayment)
                  ? _scrollToOffers
                  : null,
            ),

            const SizedBox(height: 12),
          ],

          Wrap(
            alignment: WrapAlignment.spaceBetween,

            crossAxisAlignment: WrapCrossAlignment.center,

            spacing: 8,

            runSpacing: 6,

            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,

                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(999),
                ),

                child: MyText(
                  text: status,

                  size: 12,

                  weight: FontWeight.w700,

                  color: _statusColor(status),
                ),
              ),

              if (requestMeta.isNotEmpty)
                MyText(text: requestMeta, size: 11, color: kGreyColor),
              if (dueDate.isNotEmpty) _buildDueBadge(dueDate),
            ],
          ),

          if (status == kStatusPaid || status == kStatusInWork) ...[
            const SizedBox(height: 8),

            _PaidInfo(offer: selectedOffer),
          ],

          const SizedBox(height: 16),

          MyText(
            text: type == 'turnkey' ? '  ' : 'Автомобили в заявке',

            size: 14,

            weight: FontWeight.w700,

            paddingBottom: 6,
          ),

          if (type == 'by_car') ..._buildByCar(),

          if (type == 'turnkey') ..._buildTurnkey(),

          const SizedBox(height: 20),

          if (!isServer) ...[
            _buildOffersSection(status, selectedOffer),

            const SizedBox(height: 20),

            _buildActions(status),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildByCar() {
    final requestCars = (_data['requestCars'] as List<dynamic>?) ?? [];
    if (_loadingCars && requestCars.isEmpty) {
      return [
        MyText(text: 'Загрузка...', size: 12, color: kGreyColor),
      ];
    }
    if (requestCars.isNotEmpty) {
      return requestCars.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final raw = entry.value;
        final car = Map<String, dynamic>.from(raw as Map);
        final restylingLabels = _byCarRestylingLabels(car);
        final phoneRaw = (car['phone'] ?? car['sellerPhone'] ?? '').toString().trim();
        final urlRaw = (car['url'] ?? car['sourceUrl'] ?? '').toString().trim();
        final dueAt = _formatServerDate(car['dueAt'] ?? car['due_at'] ?? car['due']);
        final make = _firstStringByKeys(
          car,
          const ['makeName', 'brandName', 'markName', 'make', 'brand', 'mark'],
        );
        final model = _firstStringByKeys(
          car,
          const ['modelRus', 'modelName', 'model'],
        );
        final carName = [make, model].where((e) => e.isNotEmpty).join(' ');
        final title = carName.isNotEmpty ? carName : 'Автомобиль №$index';
        final phone = phoneRaw.isEmpty ? '' : _formatPhoneReadable(phoneRaw);
        final host = _urlHost(urlRaw);
        final photoUrls = _collectPhotoUrlsFromCar(car, limit: 10);
        final photoUrl = photoUrls.isNotEmpty ? photoUrls.first : _extractCarPhotoUrl(car);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoThumb(
                photoUrl,
                size: 64,
                onTap: photoUrls.isEmpty ? null : () => _openPhotoGallery(photoUrls),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MyText(text: title, size: 13, weight: FontWeight.w600),
                    if (restylingLabels.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const MyText(
                        text: 'Поколение',
                        size: 11,
                        color: kGreyColor,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: restylingLabels
                            .map(
                              (label) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: kBorderColor),
                                ),
                                child: MyText(
                                  text: label,
                                  size: 11,
                                  color: kTertiaryColor,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (dueAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildDueBadge(dueAt, textSize: 10),
                    ],
                    if (urlRaw.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: MyText(
                              text: 'Объявление: ${host.isEmpty ? urlRaw : host}',
                              size: 12,
                              color: kGreyColor,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openListingUrl(urlRaw),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 0),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Открыть',
                              style: TextStyle(color: kSecondaryColor, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      MyText(text: 'Телефон: $phone', size: 12, color: kGreyColor),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    final cars = (_data['cars'] as List<dynamic>?) ?? [];
    if (cars.isEmpty) {
      return [
        MyText(text: 'Автомобили не добавлены', size: 12, color: kGreyColor),
      ];
    }

    return cars.map((raw) {
      final car = Map<String, dynamic>.from(raw as Map);
      final make = car['make'] ?? '-';
      final model = car['model'] ?? '-';
      final generation = _cleanInternalRestTag(
        (car['generation'] ?? '').toString(),
      );
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MyText(
              text: '$make $model $generation'.trim(),
              size: 13,
              weight: FontWeight.w600,
            ),
            if ((car['sourceUrl'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              MyText(
                text: 'Ссылка: ${car['sourceUrl']}',
                size: 12,
                color: kGreyColor,
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildTurnkey() {
    final requestCars = (_data['requestCars'] as List<dynamic>?) ?? [];
    final savedMakes = (_data['makes'] as List<dynamic>?) ?? const [];
    final savedModels = (_data['models'] as List<dynamic>?) ?? const [];
    final savedRestylings = (_data['restylings'] as List<dynamic>?) ?? const [];
    final makes = <String>[
      ...savedMakes.expand(_stringList),
      ..._collectRequestCarValues(
        requestCars,
        const ['make', 'brand', 'makeName', 'brandName', 'mark', 'markName'],
      ),
    ].where((e) => e.trim().isNotEmpty).toSet().toList();

    final models = <String>[
      ...savedModels.expand(_stringList),
      ..._collectRequestCarValues(
        requestCars,
        const ['model', 'modelName'],
      ),
    ].where((e) => e.trim().isNotEmpty).toSet().toList();

    final restylingCards = _turnkeyRestylingCards(
      requestCars,
      savedRestylings,
    );
    final galleryUrls = restylingCards
        .map((e) => e.photoUrl)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    final showFallbackChips = restylingCards.isEmpty;
    final fallbackRestylings = showFallbackChips
        ? savedRestylings
            .expand(_stringList)
            .map(_cleanInternalRestTag)
            .where((e) => e.trim().isNotEmpty)
            .toSet()
            .toList()
        : <String>[];


    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MyText(
              text: 'Критерии подбора',
              size: 13,
              weight: FontWeight.w700,
            ),
            if (restylingCards.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                children: restylingCards.asMap().entries.map((entry) {
                  final index = entry.key;
                  final card = entry.value;
                  final url = card.photoUrl;
                  final galleryIndex = galleryUrls.indexOf(url);
                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index == restylingCards.length - 1 ? 0 : 8,
                    ),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kSecondaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: Row(
                      children: [
                        _buildPhotoThumb(
                          url,
                          size: 56,
                          onTap: url.isEmpty
                              ? null
                              : () => _openPhotoGallery(
                                    galleryUrls,
                                    initialIndex: galleryIndex >= 0 ? galleryIndex : 0,
                                  ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MyText(
                                text: card.title,
                                size: 12,
                                weight: FontWeight.w600,
                                color: kTertiaryColor,
                              ),
                              if (card.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                MyText(
                                  text: card.subtitle,
                                  size: 11,
                                  color: kGreyColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            if (showFallbackChips) ...[
              _ChipRow(label: 'Марка', values: makes),
              const SizedBox(height: 8),
              _ChipRow(label: 'Модель', values: models),
              const SizedBox(height: 8),
              _ChipRow(label: 'Поколение', values: fallbackRestylings),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildOffersSection(
    String status,

    Map<String, dynamic>? selectedOffer,
  ) {
    final offers = _offers();

    final canceled = _canceledOffers();

    final showOthers = status == kStatusCreated || status == kStatusCanceled;

    return Column(
      key: _offersKey,

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        MyText(
          text: 'Предложения автоподборщиков',

          size: 14,

          weight: FontWeight.w700,

          paddingBottom: 10,
        ),

        if (offers.isEmpty)
          MyText(text: 'Пока нет предложений', size: 12, color: kGreyColor)
        else ...[
          if (selectedOffer != null) ...[
            _OfferCard(
              offer: selectedOffer,

              isSelected: true,

              isCanceled: canceled.contains(selectedOffer['id']?.toString()),

              onProfile: () => _openProfile(selectedOffer),

              onPay: status == kStatusAwaitPayment ? _pay : null,
            ),

            const SizedBox(height: 10),
          ],

          if (showOthers)
            ...offers.map(
              (offer) => _OfferCard(
                offer: offer,

                isSelected: false,

                isCanceled: canceled.contains(offer['id']?.toString()),

                onProfile: () => _openProfile(
                  offer,

                  onChoose: status == kStatusCanceled
                      ? null
                      : () => _selectOffer(offer),
                ),

                onChoose: status == kStatusCanceled
                    ? null
                    : () => _selectOffer(offer),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActions(String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        if (status == kStatusAwaitPayment)
          Padding(
            padding: const EdgeInsets.only(top: 10),

            child: OutlinedButton(
              onPressed: _cancelSelection,

              style: OutlinedButton.styleFrom(
                side: BorderSide(color: kSecondaryColor),

                padding: const EdgeInsets.symmetric(vertical: 12),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: const Text(
                'Отменить выбор',

                style: TextStyle(color: kSecondaryColor, fontSize: 12),
              ),
            ),
          ),

        if (status == kStatusPaid || status == kStatusInWork) ...[
          MyButton(buttonText: 'Отчет получен', onTap: _markDone),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(12),

              border: Border.all(color: kBorderColor),
            ),

            child: MyText(
              text:
                  'Отмена недоступна. Сервис может вернуть деньги, если сроки не соблюдены.',

              size: 11,

              color: kGreyColor,
            ),
          ),
        ],

        if (status == kStatusCreated)
          Padding(
            padding: const EdgeInsets.only(top: 10),

            child: OutlinedButton(
              onPressed: () => _updateRequest({'status': kStatusCanceled}),

              style: OutlinedButton.styleFrom(
                side: BorderSide(color: kRedColor),

                padding: const EdgeInsets.symmetric(vertical: 12),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: const Text(
                'Отменить заявку',

                style: TextStyle(color: kRedColor, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  void _openProfile(Map<String, dynamic> offer, {VoidCallback? onChoose}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            InspectorProfileScreen(offer: offer, onChoose: onChoose),
      ),
    );
  }
}

class _PaidInfo extends StatelessWidget {
  const _PaidInfo({required this.offer});

  final Map<String, dynamic>? offer;

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);

    final buf = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;

      buf.write(s[i]);

      if (idx > 1 && idx % 3 == 1) buf.write(' ');
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (offer == null) return const SizedBox.shrink();

    final price = offer?['price'] as num?;

    final days = offer?['days']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorderColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          MyText(
            text: 'Оплачено. Деньги на гарантийном счете.',

            size: 12,

            weight: FontWeight.w600,
          ),

          const SizedBox(height: 6),

          if (price != null)
            MyText(
              text: 'Сумма: ${_formatMoney(price)} руб.',

              size: 12,

              color: kGreyColor,
            ),

          if (days.isNotEmpty)
            MyText(
              text: 'Срок выполнения: $days дн.',

              size: 12,

              color: kGreyColor,
            ),

          const SizedBox(height: 4),

          MyText(
            text: 'Если отчет не будет готов в срок, сервис оформит возврат.',

            size: 11,

            color: kGreyColor,
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,

    required this.isSelected,

    required this.isCanceled,

    required this.onProfile,

    this.onChoose,

    this.onPay,
  });

  final Map<String, dynamic> offer;

  final bool isSelected;

  final bool isCanceled;

  final VoidCallback onProfile;

  final VoidCallback? onChoose;

  final VoidCallback? onPay;

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);

    final buf = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;

      buf.write(s[i]);

      if (idx > 1 && idx % 3 == 1) buf.write(' ');
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final name = offer['name']?.toString() ?? '';

    final company = offer['company']?.toString() ?? '';

    final rating = offer['rating']?.toString() ?? '-';

    final reviews = offer['reviews']?.toString() ?? '0';

    final reports = offer['reports']?.toString() ?? '0';

    final price = offer['price'] as num?;

    final days = offer['days']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: kWhiteColor,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorderColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    MyText(text: name, size: 14, weight: FontWeight.w700),

                    if (company.isNotEmpty)
                      MyText(text: company, size: 11, color: kGreyColor),
                  ],
                ),
              ),

              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,

                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(999),
                  ),

                  child: const Text(
                    'Выбрано',

                    style: TextStyle(
                      fontSize: 10,

                      fontWeight: FontWeight.w700,

                      color: kSecondaryColor,
                    ),
                  ),
                ),

              if (!isSelected && isCanceled) ...[
                const SizedBox(width: 6),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,

                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: kRedColor.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(999),
                  ),

                  child: const Text(
                    'Отменено клиентом',

                    style: TextStyle(
                      fontSize: 10,

                      fontWeight: FontWeight.w700,

                      color: kRedColor,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              MyText(text: 'Рейтинг $rating', size: 11, color: kGreyColor),

              const SizedBox(width: 8),

              MyText(text: '$reviews отзывов', size: 11, color: kGreyColor),

              const Spacer(),

              MyText(text: '$reports отчетов', size: 11, color: kGreyColor),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              if (price != null)
                MyText(
                  text: 'Цена: ${_formatMoney(price)} руб.',

                  size: 12,

                  weight: FontWeight.w600,
                ),

              const Spacer(),

              if (days.isNotEmpty)
                MyText(
                  text: 'Срок: $days дн.',

                  size: 12,

                  weight: FontWeight.w600,
                ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              TextButton(
                onPressed: onProfile,

                child: const Text(
                  'Профиль',

                  style: TextStyle(fontSize: 12, color: kSecondaryColor),
                ),
              ),

              const Spacer(),

              if (onPay != null)
                ElevatedButton(
                  onPressed: onPay,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,

                      vertical: 8,
                    ),
                  ),

                  child: const Text(
                    'Оплатить',

                    style: TextStyle(fontSize: 12, color: kWhiteColor),
                  ),
                ),

              if (onChoose != null)
                ElevatedButton(
                  onPressed: onChoose,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,

                      vertical: 8,
                    ),
                  ),

                  child: const Text(
                    'Выбрать',

                    style: TextStyle(fontSize: 12, color: kWhiteColor),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.status, required this.current});

  final String status;

  final int current;

  @override
  Widget build(BuildContext context) {
    final steps = ['Создана', 'Выбран', 'Оплачено', 'В работе', 'Завершена'];

    final isBlocked = status == kStatusCanceled || status == kStatusRefund;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.scaleDown,

              alignment: Alignment.centerLeft,

              child: Row(
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    _StepDot(
                      label: steps[i],

                      state: isBlocked
                          ? _StepState.inactive
                          : (i < current
                                ? _StepState.done
                                : (i == current
                                      ? _StepState.active
                                      : _StepState.inactive)),
                    ),

                    if (i < steps.length - 1)
                      Container(
                        width: 28,

                        height: 2,

                        margin: const EdgeInsets.symmetric(horizontal: 6),

                        color: isBlocked
                            ? kBorderColor
                            : (i < current ? kSecondaryColor : kBorderColor),
                      ),
                  ],
                ],
              ),
            );
          },
        ),

        if (status == kStatusCanceled || status == kStatusRefund) ...[
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: kRedColor.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(10),

              border: Border.all(color: kRedColor.withValues(alpha: 0.3)),
            ),

            child: MyText(
              text: status == kStatusCanceled
                  ? 'Заявка отменена. Предложения доступны ниже.'
                  : 'Оформляется возврат средств.',

              size: 11,

              color: kRedColor,
            ),
          ),
        ],
      ],
    );
  }
}

enum _StepState { inactive, active, done }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.state});

  final String label;

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Color fill;

    final Color text;

    if (state == _StepState.done) {
      fill = kSecondaryColor;

      text = kSecondaryColor;
    } else if (state == _StepState.active) {
      fill = kSecondaryColor;

      text = kSecondaryColor;
    } else {
      fill = kBorderColor;

      text = kGreyColor;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 12,

          height: 12,

          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        ),

        const SizedBox(height: 4),

        MyText(text: label, size: 10, color: text),
      ],
    );
  }
}

class _MainAction extends StatelessWidget {
  const _MainAction({
    required this.status,

    required this.dueDate,

    this.onPrimary,
  });

  final String status;

  final String dueDate;

  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    String title = '';

    String subtitle = '';

    Color tone = kSecondaryColor;

    if (status == kStatusCreated) {
      title = 'Выберите автоподборщика';

      subtitle = 'Ниже список предложений с ценой и сроком.';

      tone = kSecondaryColor;
    } else if (status == kStatusAwaitPayment) {
      title = 'Выбран исполнитель';

      subtitle = 'Оплатите предложение в карточке выбранного.';

      tone = kSecondaryColor;
    } else if (status == kStatusPaid || status == kStatusInWork) {
      title = 'Заявка оплачена';

      subtitle = dueDate.isNotEmpty
          ? '   $dueDate.'
          : 'Ожидаем отчет от автоподборщика.';

      tone = kBlueColor;
    } else if (status == kStatusDone) {
      title = 'Заявка завершена';

      subtitle = 'Отчет получен. Спасибо за доверие!';

      tone = kGreenColor;
    } else if (status == kStatusCanceled) {
      title = 'Заявка отменена';

      subtitle = 'Можно создать новую заявку.';

      tone = kRedColor;
    } else if (status == kStatusRefund) {
      title = 'Оформляется возврат';

      subtitle = 'Средства будут возвращены после проверки.';

      tone = kRedColor;
    }

    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorderColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          MyText(text: title, size: 13, weight: FontWeight.w700, color: tone),

          const SizedBox(height: 4),

          MyText(text: subtitle, size: 11, color: kGreyColor),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.values});

  final String label;

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        MyText(text: label, size: 12, color: kGreyColor),

        const SizedBox(height: 6),

        if (values.isEmpty)
          MyText(text: 'Не выбрано', size: 12, color: kGreyColor)
        else
          Wrap(
            spacing: 6,

            runSpacing: 6,

            children: values
                .map(
                  (v) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,

                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: kSecondaryColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(999),
                    ),

                    child: MyText(
                      text: v,

                      size: 11,

                      weight: FontWeight.w600,

                      color: kSecondaryColor,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _PhotoGalleryScreen extends StatefulWidget {
  const _PhotoGalleryScreen({
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<_PhotoGalleryScreen> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex < 0
        ? 0
        : (widget.initialIndex > widget.urls.length - 1
            ? widget.urls.length - 1
            : widget.initialIndex);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (value) {
                setState(() {
                  _index = value;
                });
              },
              itemBuilder: (context, index) {
                final url = widget.urls[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 3,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.white70,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.urls.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnkeyRestylingCard {
  final String title;
  final String subtitle;
  final String photoUrl;

  const _TurnkeyRestylingCard({
    required this.title,
    required this.subtitle,
    required this.photoUrl,
  });
}


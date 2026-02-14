import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';

import 'package:flutter_application_1/core/constants/app_sizes.dart';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';

import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/inspector_profile_screen.dart';

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

  Map<String, dynamic>? _asStringMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  @override
  void initState() {
    super.initState();

    _data = Map<String, dynamic>.from(widget.request);
    _applyDisplayOverride();
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

  Future<void> _applyDisplayOverride() async {
    final override = await _loadDisplayOverride();
    if (override == null) return;
    if (!mounted) return;
    setState(() {
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
        if (override[key] != null) {
          _data[key] = override[key];
        }
      }
      final cars = override['requestCars'];
      if (cars is List && cars.isNotEmpty) {
        _data['requestCarsOverride'] = cars;
        final existing = _data['requestCars'] as List<dynamic>?;
        if (existing == null || existing.isEmpty) {
          _data['requestCars'] = cars;
        }
      }
    });
  }

  Future<Map<String, dynamic>?> _loadDisplayOverride() async {
    final id = _requestId();
    if (id != null) {
      final byId = await UserSimplePreferences.getRequestDisplayOverride(
        id.toString(),
      );
      if (byId != null) return byId;
    }
    final number =
        _data['requestNumber'] ?? _data['request_number'] ?? _data['number'];
    if (number != null) {
      return UserSimplePreferences.getRequestDisplayOverride(number.toString());
    }
    return null;
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

    return raw.map(_asStringMap).whereType<Map<String, dynamic>>().toList();
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

  String _generationLabelFromCar(Map<String, dynamic> car) {
    final raw =
        car['generationName'] ?? car['generationLabel'] ?? car['generation'];
    final text = _cleanInternalRestTag(raw?.toString() ?? '').trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    if (lower.contains('покол')) return text;
    if (RegExp(r'^\d+$').hasMatch(text)) return 'Поколение $text';
    return 'Поколение $text';
  }

  String _requestCarTitle(Map<String, dynamic> car) {
    final make = _firstStringByKeys(car, const [
      'makeName',
      'brandName',
      'markName',
      'make',
      'brand',
      'mark',
    ]);
    final model = _firstStringByKeys(car, const [
      'modelRus',
      'modelName',
      'model',
      'nameRus',
      'name',
    ]);
    final title = [make, model].where((e) => e.isNotEmpty).join(' ').trim();
    return title.isEmpty ? 'Автомобиль' : title;
  }

  List<_TurnkeyRestylingCard> _turnkeyRestylingCards(
    List<dynamic> requestCars,
    List<dynamic> savedRestylings, {
    String baseRequestTitle = '',
  }) {
    final groups = <_TurnkeyRestylingGroup>[];
    for (final raw in requestCars) {
      if (raw is! Map) continue;
      final car = Map<String, dynamic>.from(raw);
      final carTitle = _requestCarTitle(car);
      final hasCarTitle =
          carTitle.trim().isNotEmpty && carTitle.trim() != 'Автомобиль';
      final groupBaseTitle = hasCarTitle ? carTitle : baseRequestTitle.trim();
      final restylingRaw = car['restyling'] ?? car['restylings'];
      final generationLabel = _generationLabelFromCar(car);
      final generationValue = _generationValueFromLabel(generationLabel);
      final fallbackPhoto = _extractCarPhotoUrl(car);
      final fallbackPhotos = _collectPhotoUrlsFromCar(car, limit: 16);
      final items = <Map<String, dynamic>>[];
      if (restylingRaw is Map) {
        items.add(Map<String, dynamic>.from(restylingRaw));
      } else if (restylingRaw is List) {
        for (final item in restylingRaw) {
          if (item is! Map) continue;
          items.add(Map<String, dynamic>.from(item));
        }
      }
      if (items.isEmpty) {
        final group = _TurnkeyRestylingGroup(
          baseTitle: groupBaseTitle,
          generationValue: generationValue,
          photoUrl: fallbackPhoto,
        );
        for (final url in fallbackPhotos) {
          group.addPhotoUrl(url);
        }
        groups.add(group);
        continue;
      }
      for (final map in items) {
        final start = _yearFromRaw(map['yearStart']);
        final end = _yearFromRaw(map['yearEnd']);
        final yearLabel = _formatYearRangeForHeader(start, end);
        final restyling = _restylingValueFromMap(map);
        final modifications = _modificationValuesFromMap(map);
        final photoRaw = _pickPhotoUrl(map['photos']);
        final photoUrl = photoRaw.isNotEmpty ? photoRaw : fallbackPhoto;
        final range = _TurnkeyYearRange(
          start: start,
          end: end,
          label: yearLabel,
        );

        _TurnkeyRestylingGroup? target;
        for (final group in groups) {
          if (group.baseTitle != groupBaseTitle) continue;
          if (group.generationValue != generationValue) continue;
          if (group.ranges.isEmpty || range.isUnknown) {
            target = group;
            break;
          }
          final hasOverlap = group.ranges.any((r) => _rangesOverlap(r, range));
          if (hasOverlap) {
            target = group;
            break;
          }
        }
        target ??= _TurnkeyRestylingGroup(
          baseTitle: groupBaseTitle,
          generationValue: generationValue,
          photoUrl: photoUrl,
        );
        if (!groups.contains(target)) {
          groups.add(target);
        }
        target.ranges.add(range);
        if (restyling.isNotEmpty) target.restylings.add(restyling);
        target.modifications.addAll(modifications);
        for (final url in fallbackPhotos) {
          target.addPhotoUrl(url);
        }
        if (photoUrl.isNotEmpty) {
          target.addPhotoUrl(photoUrl);
        }
      }
    }

    final cards = <_TurnkeyRestylingCard>[];
    for (final group in groups) {
      final years = group.sortedYearLabels();
      final restylings = <String>[];
      for (final value in group.restylings) {
        if (!restylings.contains(value)) restylings.add(value);
      }
      restylings.sort((a, b) {
        if (a == b) return 0;
        if (a == 'стартовый') return -1;
        if (b == 'стартовый') return 1;
        final aNum = int.tryParse(a);
        final bNum = int.tryParse(b);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        return a.compareTo(b);
      });
      final modifications = <String>[];
      for (final value in group.modifications) {
        if (!modifications.contains(value)) modifications.add(value);
      }
      final defaultTitle = group.generationValue.isEmpty
          ? 'Поколение'
          : 'Поколение ${group.generationValue}';
      final base = group.baseTitle.isNotEmpty ? group.baseTitle : defaultTitle;
      final title = years.isNotEmpty ? '$base ${years.join(', ')}' : base;
      final lines = <String>[];
      if (group.generationValue.isNotEmpty) {
        lines.add('Поколение: ${group.generationValue}');
      }
      if (restylings.isNotEmpty) {
        lines.add('Рестайлинг: ${restylings.join(', ')}');
      }
      if (modifications.isNotEmpty) {
        lines.add('Модификация: ${modifications.join(', ')}');
      }
      final photoUrls = group.photoUrls.isNotEmpty
          ? List<String>.from(group.photoUrls)
          : (group.photoUrl.isNotEmpty ? <String>[group.photoUrl] : <String>[]);
      cards.add(
        _TurnkeyRestylingCard(
          title: title,
          subtitle: lines.join('\n'),
          photoUrl: group.photoUrl,
          photoUrls: photoUrls,
        ),
      );
    }

    if (cards.isEmpty && savedRestylings.isNotEmpty) {
      for (final raw in savedRestylings) {
        final value = _cleanInternalRestTag(raw?.toString() ?? '').trim();
        if (value.isEmpty) continue;
        final label = RegExp(r'^\\d+$').hasMatch(value)
            ? 'Поколение #$value'
            : value;
        cards.add(
          _TurnkeyRestylingCard(
            title: label,
            subtitle: '',
            photoUrl: '',
            photoUrls: const [],
          ),
        );
      }
    }
    final seen = <String>{};
    final unique = <_TurnkeyRestylingCard>[];
    for (final card in cards) {
      final key =
          '${card.title}|${card.subtitle}|${card.photoUrl}|${card.photoUrls.join(',')}';
      if (seen.add(key)) unique.add(card);
    }
    return unique;
  }

  String _generationValueFromLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '';
    final match = RegExp(r'(\d+)').firstMatch(trimmed);
    if (match != null) return match.group(1) ?? trimmed;
    return trimmed
        .replaceFirst(RegExp(r'^Поколение\s*', caseSensitive: false), '')
        .trim();
  }

  String _formatYearRangeForHeader(int? start, int? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) return '$start-$end';
    if (start != null) return '$start-н.в.';
    return 'до $end';
  }

  String _restylingValueFromMap(Map<String, dynamic> map) {
    final raw = _firstStringByKeys(map, const [
      'restyling',
      'restylingName',
      'name',
      'title',
    ]);
    final text = _cleanInternalRestTag(raw).trim();
    if (text.isEmpty) return '';
    if (text == '0') return 'стартовый';
    return text;
  }

  List<String> _modificationValuesFromMap(Map<String, dynamic> map) {
    final values = <String>{
      ..._stringList(map['frames']),
      ..._stringList(map['frame']),
      ..._stringList(map['modification']),
      ..._stringList(map['modifications']),
    };
    return values
        .map((v) => _cleanInternalRestTag(v).trim())
        .where((v) => v.isNotEmpty && !RegExp(r'^\d+$').hasMatch(v))
        .toList();
  }

  bool _rangesOverlap(_TurnkeyYearRange a, _TurnkeyYearRange b) {
    if (a.isUnknown || b.isUnknown) return true;
    final aStart = a.start ?? a.end!;
    final aEnd = a.end ?? a.start!;
    final bStart = b.start ?? b.end!;
    final bEnd = b.end ?? b.start!;
    return aStart <= bEnd && bStart <= aEnd;
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

  String _photoUrlFromPhotoMap(Map<String, dynamic> photo) {
    final candidates = <String>[];
    for (final key in const [
      'url_x1',
      'urlX1',
      'url_x2',
      'urlX2',
      'imageUrl',
      'photoUrl',
      'image',
      'photo',
      'url',
    ]) {
      final value = _normalizeImageUrl(photo[key]?.toString() ?? '');
      if (value.isEmpty) continue;
      if (!candidates.contains(value)) candidates.add(value);
    }
    if (candidates.isEmpty) return '';
    var best = candidates.first;
    var bestScore = _photoQualityScore(best);
    for (final url in candidates.skip(1)) {
      final score = _photoQualityScore(url);
      if (score > bestScore) {
        bestScore = score;
        best = url;
      }
    }
    return best;
  }

  String _normalizeImageUrl(String raw) {
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

  String _pickPhotoUrl(dynamic photos) {
    if (photos is Map) {
      return _photoUrlFromPhotoMap(Map<String, dynamic>.from(photos));
    }
    if (photos is! List) return '';
    final list = photos
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (list.isEmpty) return '';
    int sizeRank(String size) {
      final s = size.toLowerCase();
      if (s == 'xl' || s.contains('xlarge') || s.contains('original')) return 6;
      if (s == 'l' || s.contains('large')) return 5;
      if (s == 'm' || s.contains('medium')) return 4;
      if (s == 's' || s.contains('small')) return 3;
      if (s.contains('thumb') || s.contains('preview')) return 1;
      return 2;
    }

    Map<String, dynamic>? chosen;
    var chosenSizeRank = -1;
    var chosenQuality = -1000;
    for (final item in list) {
      final rank = sizeRank(item['size']?.toString() ?? '');
      final url = _photoUrlFromPhotoMap(item);
      final quality = _photoQualityScore(url);
      if (chosen == null ||
          rank > chosenSizeRank ||
          (rank == chosenSizeRank && quality > chosenQuality)) {
        chosen = item;
        chosenSizeRank = rank;
        chosenQuality = quality;
      }
    }
    if (chosen == null) return '';
    return _photoUrlFromPhotoMap(chosen);
  }

  String _extractCarPhotoUrl(Map<String, dynamic> car) {
    for (final key in const [
      'photoUrl',
      'photo',
      'imageUrl',
      'image',
      'thumbnail',
      'preview',
    ]) {
      final directValue = _normalizeImageUrl(car[key]?.toString() ?? '');
      if (directValue.isNotEmpty) return directValue;
    }
    final direct = _pickPhotoUrl(car['photos']);
    if (direct.isNotEmpty) return direct;
    final restylings = car['restyling'] ?? car['restylings'];
    if (restylings is Map) {
      final restMap = Map<String, dynamic>.from(restylings);
      for (final key in const [
        'photoUrl',
        'photo',
        'imageUrl',
        'image',
        'thumbnail',
      ]) {
        final directValue = _normalizeImageUrl(restMap[key]?.toString() ?? '');
        if (directValue.isNotEmpty) return directValue;
      }
      final url = _pickPhotoUrl(restMap['photos']);
      if (url.isNotEmpty) return url;
    }
    if (restylings is List) {
      for (final item in restylings) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        for (final key in const [
          'photoUrl',
          'photo',
          'imageUrl',
          'image',
          'thumbnail',
        ]) {
          final directValue = _normalizeImageUrl(map[key]?.toString() ?? '');
          if (directValue.isNotEmpty) return directValue;
        }
        final url = _pickPhotoUrl(map['photos']);
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }

  void _addPhotoUrl(List<String> urls, String raw, int limit) {
    if (urls.length >= limit) return;
    final url = _normalizeImageUrl(raw);
    if (url.isEmpty) return;
    if (!urls.contains(url)) {
      urls.add(url);
    }
  }

  void _addPhotosFrom(dynamic photos, List<String> urls, int limit) {
    if (urls.length >= limit) return;
    if (photos is Map) {
      _addPhotoUrl(
        urls,
        _photoUrlFromPhotoMap(Map<String, dynamic>.from(photos)),
        limit,
      );
      return;
    }
    if (photos is List) {
      final list = photos
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (list.isEmpty) return;
      final hasSize = list.any(
        (p) => (p['size']?.toString().isNotEmpty ?? false),
      );
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

  List<String> _collectPhotoUrlsFromCar(
    Map<String, dynamic> car, {
    int limit = 8,
  }) {
    final urls = <String>[];
    for (final key in const [
      'photoUrl',
      'photo',
      'imageUrl',
      'image',
      'thumbnail',
      'preview',
    ]) {
      if (urls.length >= limit) break;
      _addPhotoUrl(urls, car[key]?.toString() ?? '', limit);
    }
    _addPhotosFrom(car['photos'], urls, limit);
    if (urls.length >= limit) return urls;
    final restylings = car['restyling'] ?? car['restylings'];
    if (restylings is Map) {
      for (final key in const [
        'photoUrl',
        'photo',
        'imageUrl',
        'image',
        'thumbnail',
      ]) {
        if (urls.length >= limit) break;
        _addPhotoUrl(urls, restylings[key]?.toString() ?? '', limit);
      }
      _addPhotosFrom(restylings['photos'], urls, limit);
    } else if (restylings is List) {
      for (final item in restylings) {
        if (urls.length >= limit) break;
        if (item is! Map) continue;
        for (final key in const [
          'photoUrl',
          'photo',
          'imageUrl',
          'image',
          'thumbnail',
        ]) {
          if (urls.length >= limit) break;
          _addPhotoUrl(urls, item[key]?.toString() ?? '', limit);
        }
        _addPhotosFrom(item['photos'], urls, limit);
      }
    }
    return urls;
  }

  String _photoDedupKey(String raw) {
    final normalized = _normalizeImageUrl(raw).trim();
    if (normalized.isEmpty) return '';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) return normalized.toLowerCase();
    final parent = segments.length > 1 ? segments[segments.length - 2] : '';
    var file = segments.last.toLowerCase();
    file = file.replaceFirst(
      RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp|heic|heif)$', caseSensitive: false),
      '',
    );
    file = file.replaceAll(
      RegExp(
        r'([_-])?(x1|x2|thumb|thumbnail|preview|small|medium|large|mini|s|m|l|xl)$',
        caseSensitive: false,
      ),
      '',
    );
    file = file.replaceAll(
      RegExp(r'([_-])?\d{2,4}x\d{2,4}$', caseSensitive: false),
      '',
    );
    final idMatch = RegExp(r'(\d{4,})').firstMatch(file);
    final core = idMatch?.group(1) ?? file;
    return '$host/${parent.toLowerCase()}/$core';
  }

  int _photoQualityScore(String raw) {
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

  Future<void> _openPhotoGallery(
    List<String> urls, {
    int initialIndex = 0,
  }) async {
    final byKey = <String, String>{};
    for (final raw in urls) {
      final url = _normalizeImageUrl(raw).trim();
      if (url.isEmpty) continue;
      final key = _photoDedupKey(url);
      if (key.isEmpty) continue;
      final existing = byKey[key];
      if (existing == null ||
          _photoQualityScore(url) > _photoQualityScore(existing)) {
        byKey[key] = url;
      }
    }
    final unique = byKey.values.toList();
    if (unique.isEmpty) return;
    final safeIndex = initialIndex < 0
        ? 0
        : (initialIndex > unique.length - 1 ? unique.length - 1 : initialIndex);
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _PhotoGalleryScreen(urls: unique, initialIndex: safeIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildPhotoThumb(String url, {double size = 60, VoidCallback? onTap}) {
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
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, imageUrl) {
          return Stack(
            alignment: Alignment.center,
            children: [
              placeholder,
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kSecondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          );
        },
        errorWidget: (context, imageUrl, error) => placeholder,
      ),
    );
    if (onTap == null) return image;
    return GestureDetector(onTap: onTap, child: image);
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
    final requestCarsRaw = (_data['requestCars'] as List<dynamic>?) ?? [];
    final requestCars = requestCarsRaw
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (requestCars.isNotEmpty) {
      final cards = _turnkeyRestylingCards(
        requestCarsRaw,
        const [],
        baseRequestTitle: '',
      );
      if (cards.isNotEmpty) {
        return cards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          final url = card.photoUrl;
          final cardGalleryUrls = card.photoUrls.isNotEmpty
              ? card.photoUrls
              : (url.isNotEmpty ? <String>[url] : <String>[]);
          final onOpenGallery = cardGalleryUrls.isEmpty
              ? null
              : () => _openPhotoGallery(cardGalleryUrls);
          return GestureDetector(
            onTap: onOpenGallery,
            child: Container(
              margin: EdgeInsets.only(
                bottom: index == cards.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSecondaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  _buildPhotoThumb(url, size: 56, onTap: onOpenGallery),
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
            ),
          );
        }).toList();
      }
    }

    final carsRaw = (_data['cars'] as List<dynamic>?) ?? [];
    final cars = carsRaw
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (cars.isEmpty) {
      return [
        MyText(text: 'Автомобили не добавлены', size: 12, color: kGreyColor),
      ];
    }

    return cars.map((car) {
      final make = car['make'] ?? '-';
      final model = car['model'] ?? '-';
      final generation = _cleanInternalRestTag(
        (car['generation'] ?? '').toString(),
      );
      final note = (car['note'] ?? car['comment'] ?? '').toString().trim();
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
            if (note.isNotEmpty) ...[
              const SizedBox(height: 4),
              MyText(text: 'Заметка: $note', size: 12, color: kGreyColor),
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
      ..._stringList(_data['make']),
      ..._stringList(_data['brand']),
      ..._stringList(_data['mark']),
      ..._stringList(_data['makeName']),
      ..._stringList(_data['brandName']),
      ..._stringList(_data['markName']),
    ].where((e) => e.trim().isNotEmpty).toSet().toList();

    final models = <String>[
      ...savedModels.expand(_stringList),
      ..._stringList(_data['model']),
      ..._stringList(_data['modelName']),
      ..._stringList(_data['modelRus']),
    ].where((e) => e.trim().isNotEmpty).toSet().toList();

    String firstFromDataOrCars(List<String> keys) {
      final topLevel = _firstStringByKeys(_data, keys);
      if (topLevel.isNotEmpty) return topLevel;
      final fromCars = _collectRequestCarValues(requestCars, keys);
      return fromCars.isNotEmpty ? fromCars.first : '';
    }

    String composeRequestTitle() {
      final make = makes.isNotEmpty ? makes.first : '';
      final model = models.isNotEmpty ? models.first : '';
      return [make, model].where((e) => e.isNotEmpty).join(' ');
    }

    final requestTitle = composeRequestTitle();

    final restylingCards = _turnkeyRestylingCards(
      requestCars,
      savedRestylings,
      baseRequestTitle: requestTitle,
    );
    final showFallbackChips = restylingCards.isEmpty;
    final fallbackRestylings = showFallbackChips
        ? savedRestylings
              .expand(_stringList)
              .map(_cleanInternalRestTag)
              .where((e) => e.trim().isNotEmpty)
              .toSet()
              .toList()
        : <String>[];
    final city = firstFromDataOrCars(const [
      'city',
      'cityName',
      'location',
      'town',
      'locality',
    ]);
    final budgetFrom = firstFromDataOrCars(const [
      'budgetFrom',
      'budget_from',
      'budgetMin',
      'budget_min',
      'priceFrom',
      'price_from',
      'minPrice',
      'min_price',
    ]);
    final budgetTo = firstFromDataOrCars(const [
      'budgetTo',
      'budget_to',
      'budgetMax',
      'budget_max',
      'priceTo',
      'price_to',
      'maxPrice',
      'max_price',
    ]);
    final budgetSingle = firstFromDataOrCars(const [
      'budget',
      'price',
      'amount',
    ]);
    final mileageTo = firstFromDataOrCars(const [
      'mileageTo',
      'mileage_to',
      'mileage',
      'maxMileage',
      'max_mileage',
      'runTo',
      'run_to',
    ]);
    final ownersCount = firstFromDataOrCars(const [
      'ownersCount',
      'owners_count',
      'owners',
      'maxOwners',
      'max_owners',
    ]);
    final note = () {
      final topLevel = _firstStringByKeys(_data, const [
        'note',
        'comment',
        'description',
        'notes',
        'remark',
      ]);
      if (topLevel.isNotEmpty) return topLevel;
      final noteFromCars = _collectRequestCarValues(requestCars, const [
        'note',
        'comment',
        'description',
        'notes',
        'remark',
      ]);
      return noteFromCars.isNotEmpty ? noteFromCars.first : '';
    }();
    String budget = '';
    if (budgetFrom.isNotEmpty && budgetTo.isNotEmpty) {
      budget = '$budgetFrom - $budgetTo';
    } else if (budgetFrom.isNotEmpty) {
      budget = 'от $budgetFrom';
    } else if (budgetTo.isNotEmpty) {
      budget = 'до $budgetTo';
    } else {
      budget = budgetSingle;
    }
    final infoRows = <MapEntry<String, String>>[
      MapEntry('Город', city),
      MapEntry('Бюджет', budget),
      MapEntry('Пробег до', mileageTo),
      MapEntry('Владельцев', ownersCount),
      MapEntry('Заметка', note),
    ];

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
              text: 'Параметры заявки',
              size: 13,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: 8),
            ...infoRows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: kGreyColor,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: '${row.key}: ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: row.value),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
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
                  final cardGalleryUrls = card.photoUrls.isNotEmpty
                      ? card.photoUrls
                      : (url.isNotEmpty ? <String>[url] : <String>[]);
                  final onOpenGallery = cardGalleryUrls.isEmpty
                      ? null
                      : () => _openPhotoGallery(cardGalleryUrls);
                  return GestureDetector(
                    onTap: onOpenGallery,
                    child: Container(
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
                          _buildPhotoThumb(url, size: 56, onTap: onOpenGallery),
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
  const _PhotoGalleryScreen({required this.urls, this.initialIndex = 0});

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
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (context, imageUrl) => const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, imageUrl, error) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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

class _TurnkeyYearRange {
  const _TurnkeyYearRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final int? start;
  final int? end;
  final String label;

  bool get isUnknown => start == null && end == null;
}

class _TurnkeyRestylingGroup {
  _TurnkeyRestylingGroup({
    required this.baseTitle,
    required this.generationValue,
    required this.photoUrl,
  });

  final String baseTitle;
  final String generationValue;
  String photoUrl;
  final List<String> photoUrls = [];
  final List<_TurnkeyYearRange> ranges = [];
  final List<String> restylings = [];
  final List<String> modifications = [];

  void addPhotoUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    if (!photoUrls.contains(value)) {
      photoUrls.add(value);
    }
    if (photoUrl.isEmpty) {
      photoUrl = value;
    }
  }

  List<String> sortedYearLabels() {
    final rows = <_TurnkeyYearRange>[];
    final seen = <String>{};
    for (final range in ranges) {
      final label = range.label.trim();
      if (label.isEmpty) continue;
      if (seen.add(label)) rows.add(range);
    }
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
}

class _TurnkeyRestylingCard {
  final String title;
  final String subtitle;
  final String photoUrl;
  final List<String> photoUrls;

  const _TurnkeyRestylingCard({
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    required this.photoUrls,
  });
}

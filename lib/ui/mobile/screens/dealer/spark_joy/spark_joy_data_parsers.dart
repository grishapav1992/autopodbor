part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyDataParsers on _SparkJoyCreateReportScreenState {
  String _read(Map<String, dynamic> map, String key, {String fallback = ''}) {
    final value = map[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _normalizeInitialExpertConclusion(Map<String, dynamic> draft) {
    final touched =
        _readBool(draft, 'expertConclusionTouched') ||
        _readBool(draft, 'expertConclusionUser');
    if (!touched) return '';
    return _read(draft, 'expertConclusion');
  }

  int _readInt(Map<String, dynamic> map, String key, {int fallback = 0}) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _readDouble(
    Map<String, dynamic> map,
    String key, {
    double fallback = 0,
  }) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? _readNullableDouble(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key)) return null;
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _readBool(
    Map<String, dynamic> map,
    String key, {
    bool fallback = false,
  }) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  bool? _readTriState(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Map<String, List<String>> _readStringListMap(dynamic value) {
    if (value is! Map) return <String, List<String>>{};

    final result = <String, List<String>>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final tags = _readStringList(entry.value);
      if (tags.isEmpty) continue;

      final dedup = <String>{};
      final clean = <String>[];
      for (final tag in tags) {
        final value = tag.trim();
        if (value.isEmpty) continue;
        final marker = value.toLowerCase();
        if (dedup.add(marker)) clean.add(value);
      }
      if (clean.isNotEmpty) {
        result[key] = clean;
      }
    }
    return result;
  }

  List<UploadedItem> _readUploadedList(dynamic value) {
    if (value is! List) return const [];
    final items = <UploadedItem>[];
    for (var index = 0; index < value.length; index++) {
      final entry = value[index];
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final name = _read(map, 'name');
      final dataUrl = _read(map, 'dataUrl');
      if (name.isEmpty || dataUrl.isEmpty) continue;
      final id = _read(map, 'id').trim().isNotEmpty
          ? _read(map, 'id').trim()
          : 'legacy_${index}_${name.hashCode}_${dataUrl.hashCode}';
      items.add(
        UploadedItem(
          id: id,
          name: name,
          mimeType: _read(
            map,
            'mimeType',
            fallback: 'application/octet-stream',
          ),
          dataUrl: dataUrl,
          inspection: _readMediaInspection(map['inspection']),
        ),
      );
    }
    return items;
  }

  MediaInspection _readMediaInspection(dynamic value) {
    if (value is! Map) return const MediaInspection();
    final map = Map<String, dynamic>.from(value);
    double? paintFrom = _readNullableDouble(map, 'paintFrom');
    double? paintTo = _readNullableDouble(map, 'paintTo');
    final paint = map['paintThickness'];
    if (paint is Map) {
      final paintMap = Map<String, dynamic>.from(paint);
      paintFrom ??= _readNullableDouble(paintMap, 'from');
      paintTo ??= _readNullableDouble(paintMap, 'to');
    }
    return MediaInspection(
      noDamage: _readBool(map, 'noDamage'),
      tags: _readStringList(map['tags']),
      note: _read(map, 'note'),
      elementType: _read(map, 'elementType'),
      audioRecordings: _readStringList(map['audioRecordings']),
      paintFrom: paintFrom,
      paintTo: paintTo,
      isDraft: _readBool(map, 'isDraft', fallback: true),
    );
  }

  MediaPartInspection _readMediaPartInspection(dynamic value) {
    if (value is! Map) return const MediaPartInspection();
    final map = Map<String, dynamic>.from(value);
    double? paintFrom = _readNullableDouble(map, 'paintFrom');
    double? paintTo = _readNullableDouble(map, 'paintTo');
    final paint = map['paintThickness'];
    if (paint is Map) {
      final paintMap = Map<String, dynamic>.from(paint);
      paintFrom ??= _readNullableDouble(paintMap, 'from');
      paintTo ??= _readNullableDouble(paintMap, 'to');
    }
    final rawTagPhotos = map['tagPhotos'];
    final tagPhotos = <String, List<String>>{};
    if (rawTagPhotos is Map) {
      for (final entry in rawTagPhotos.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        final values = _readStringList(entry.value);
        if (values.isEmpty) continue;
        tagPhotos[key] = values;
      }
    }
    return MediaPartInspection(
      noDamage: _readBool(map, 'noDamage'),
      tags: _readStringList(map['tags']),
      note: _read(map, 'note'),
      elementType: _read(map, 'elementType'),
      audioRecordings: _readStringList(map['audioRecordings']),
      paintFrom: paintFrom,
      paintTo: paintTo,
      tagPhotos: tagPhotos,
      isDraft: _readBool(map, 'isDraft', fallback: true),
    );
  }

  bool _mediaPartInspectionIsEmpty(MediaPartInspection inspection) {
    return !inspection.noDamage &&
        inspection.tags.isEmpty &&
        inspection.note.trim().isEmpty &&
        inspection.audioRecordings.isEmpty &&
        (inspection.elementType ?? '').trim().isEmpty &&
        inspection.tagPhotos.isEmpty &&
        !(inspection.paintFrom != null && inspection.paintTo != null);
  }

  List<String> _parseUrls(String value) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

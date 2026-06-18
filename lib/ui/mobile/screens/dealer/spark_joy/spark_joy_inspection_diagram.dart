part of 'spark_joy_create_report_screen.dart';

enum _InspectionDiagramStatus { none, ok, issue, severe }

class _InspectionDiagramZone {
  const _InspectionDiagramZone({
    required this.id,
    required this.label,
    required this.rect,
  });

  final String id;
  final String label;
  final Rect rect;
}

class _InspectionDiagramZoneState {
  const _InspectionDiagramZoneState({
    required this.status,
    required this.count,
    required this.firstFileIndex,
  });

  final _InspectionDiagramStatus status;
  final int count;
  final int? firstFileIndex;
}

class _SparkJoyInspectionDiagram extends StatelessWidget {
  const _SparkJoyInspectionDiagram({
    required this.groupKey,
    required this.files,
    required this.onOpenFile,
  });

  final String groupKey;
  final List<UploadedItem> files;
  final ValueChanged<int> onOpenFile;

  @override
  Widget build(BuildContext context) {
    final zones = _zonesForGroup(groupKey);
    if (zones.isEmpty) return const SizedBox.shrink();

    final zoneStates = _zoneStates(files, zones);
    final unboundCount = files.where((item) {
      final element = (item.inspection.elementType ?? '').trim();
      return element.isEmpty || !zones.any((zone) => zone.id == element);
    }).length;
    final touchedCount = zoneStates.values.where((state) {
      return state.status != _InspectionDiagramStatus.none;
    }).length;

    return SparkCard(
      radius: SparkRadius.xxl,
      padding: const EdgeInsets.all(SparkSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_car_filled_outlined,
                color: kSecondaryColor,
                size: SparkSize.iconMd,
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: MyText(
                  text: _diagramTitle(groupKey),
                  size: SparkTextSize.sectionTitle,
                  weight: FontWeight.w700,
                ),
              ),
              SparkChip(
                text: '$touchedCount/${zones.length}',
                background: kSecondaryColor.withValues(alpha: 0.1),
                color: kSecondaryColor,
                textSize: SparkTextSize.caption,
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.md,
                  vertical: SparkSpace.xxxs,
                ),
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final diagram = _DiagramCanvas(
                zones: zones,
                states: zoneStates,
                onZoneTap: (zone) {
                  final index = zoneStates[zone.id]?.firstFileIndex;
                  if (index != null) onOpenFile(index);
                },
              );
              final legend = _DiagramLegend(unboundCount: unboundCount);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: diagram),
                    const SizedBox(width: SparkSpace.lg),
                    Expanded(flex: 2, child: legend),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  diagram,
                  const SizedBox(height: SparkSpace.md),
                  legend,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _diagramTitle(String groupKey) {
    switch (groupKey) {
      case _SparkJoyMediaGroupRegistry.keyBody:
        return 'Карта кузова';
      case _SparkJoyMediaGroupRegistry.keyStructural:
        return 'Карта силовых элементов';
      case _SparkJoyMediaGroupRegistry.keyGlass:
        return 'Карта остекления';
      case _SparkJoyMediaGroupRegistry.keyLighting:
        return 'Карта светотехники';
      case _SparkJoyMediaGroupRegistry.keyUnderhood:
        return 'Карта подкапотного пространства';
      case _SparkJoyMediaGroupRegistry.keyInterior:
        return 'Карта салона';
      case _SparkJoyMediaGroupRegistry.keyWheels:
        return 'Карта колёс и тормозов';
      case _SparkJoyMediaGroupRegistry.keyDiagnostics:
        return 'Карта диагностических блоков';
      default:
        return 'Карта элементов';
    }
  }

  static Map<String, _InspectionDiagramZoneState> _zoneStates(
    List<UploadedItem> files,
    List<_InspectionDiagramZone> zones,
  ) {
    final zoneIds = zones.map((zone) => zone.id).toSet();
    final buckets = <String, List<MapEntry<int, UploadedItem>>>{};
    for (var i = 0; i < files.length; i++) {
      final element = (files[i].inspection.elementType ?? '').trim();
      if (!zoneIds.contains(element)) continue;
      buckets.putIfAbsent(element, () => []).add(MapEntry(i, files[i]));
    }

    return {
      for (final zone in zones)
        zone.id: _InspectionDiagramZoneState(
          status: _statusForBucket(buckets[zone.id] ?? const []),
          count: buckets[zone.id]?.length ?? 0,
          firstFileIndex: buckets[zone.id]?.first.key,
        ),
    };
  }

  static _InspectionDiagramStatus _statusForBucket(
    List<MapEntry<int, UploadedItem>> bucket,
  ) {
    if (bucket.isEmpty) return _InspectionDiagramStatus.none;
    var hasOk = false;
    var hasIssue = false;
    var hasSevere = false;
    for (final entry in bucket) {
      final inspection = entry.value.inspection;
      if (inspection.noDamage) hasOk = true;
      if (!inspection.isDraft &&
          !inspection.noDamage &&
          inspection.tags.isNotEmpty) {
        hasIssue = true;
      }
      if (inspection.tags.any(_isSevereTagName)) hasSevere = true;
    }
    if (hasSevere) return _InspectionDiagramStatus.severe;
    if (hasIssue) return _InspectionDiagramStatus.issue;
    if (hasOk) return _InspectionDiagramStatus.ok;
    return _InspectionDiagramStatus.none;
  }

  static bool _isSevereTagName(String tag) {
    final lower = tag.toLowerCase();
    const severeMarkers = [
      'деформация',
      'замена',
      'свар',
      'лонжерон',
      'подуш',
      'не работает',
      'ошибка',
      'течь',
      'трещина',
      'шпатл',
      'полный окрас',
    ];
    return severeMarkers.any(lower.contains);
  }
}

class _DiagramLegend extends StatelessWidget {
  const _DiagramLegend({required this.unboundCount});

  final int unboundCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _legendRow(kGreenColor, 'Без замечаний'),
        _legendRow(kSecondaryColor, 'Есть замечания'),
        _legendRow(kRedColor, 'Серьёзные замечания'),
        _legendRow(kBorderColor, 'Нет данных'),
        if (unboundCount > 0) ...[
          const SizedBox(height: SparkSpace.md),
          SparkHintCard(
            text:
                '$unboundCount файл(ов) без привязки к элементу. Откройте «Заметка» и выберите тип элемента.',
            icon: Icons.link_off_rounded,
            textColor: kTertiaryColor,
          ),
        ],
      ],
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.sm),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: SparkSpace.sm),
          MyText(text: label, size: SparkTextSize.body, color: kGreyColor),
        ],
      ),
    );
  }
}

class _DiagramCanvas extends StatelessWidget {
  const _DiagramCanvas({
    required this.zones,
    required this.states,
    required this.onZoneTap,
  });

  final List<_InspectionDiagramZone> zones;
  final Map<String, _InspectionDiagramZoneState> states;
  final ValueChanged<_InspectionDiagramZone> onZoneTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.25,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          final size = box.size;
          final normalized = Offset(
            local.dx / size.width,
            local.dy / size.height,
          );
          for (final zone in zones.reversed) {
            if (zone.rect.contains(normalized) &&
                (states[zone.id]?.firstFileIndex != null)) {
              onZoneTap(zone);
              return;
            }
          }
        },
        child: CustomPaint(
          painter: _InspectionDiagramPainter(zones: zones, states: states),
        ),
      ),
    );
  }
}

class _InspectionDiagramPainter extends CustomPainter {
  const _InspectionDiagramPainter({required this.zones, required this.states});

  final List<_InspectionDiagramZone> zones;
  final Map<String, _InspectionDiagramZoneState> states;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = kLightGreyColor
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = kBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final radius = Radius.circular(math.min(size.width, size.height) * 0.018);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(16)),
      bg,
    );

    for (final zone in zones) {
      final rect = _scale(zone.rect, size);
      final status = states[zone.id]?.status ?? _InspectionDiagramStatus.none;
      final count = states[zone.id]?.count ?? 0;
      final fill = Paint()
        ..color = _fillColor(status)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = _strokeColor(status)
        ..style = PaintingStyle.stroke
        ..strokeWidth = count > 0 ? 1.8 : 1.0;
      final rrect = RRect.fromRectAndRadius(rect, radius);
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
      if (count > 1) _drawCountBadge(canvas, rect, count);
      if (rect.width >= 58 && rect.height >= 22) {
        _drawLabel(canvas, rect, zone.label, status);
      }
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(16)),
      outline,
    );
  }

  @override
  bool shouldRepaint(covariant _InspectionDiagramPainter oldDelegate) {
    return oldDelegate.zones != zones || oldDelegate.states != states;
  }

  static Rect _scale(Rect rect, Size size) {
    return Rect.fromLTWH(
      rect.left * size.width,
      rect.top * size.height,
      rect.width * size.width,
      rect.height * size.height,
    );
  }

  static Color _fillColor(_InspectionDiagramStatus status) {
    switch (status) {
      case _InspectionDiagramStatus.ok:
        return kGreenColor.withValues(alpha: 0.18);
      case _InspectionDiagramStatus.issue:
        return kSecondaryColor.withValues(alpha: 0.24);
      case _InspectionDiagramStatus.severe:
        return kRedColor.withValues(alpha: 0.22);
      case _InspectionDiagramStatus.none:
        return kWhiteColor;
    }
  }

  static Color _strokeColor(_InspectionDiagramStatus status) {
    switch (status) {
      case _InspectionDiagramStatus.ok:
        return kGreenColor;
      case _InspectionDiagramStatus.issue:
        return kSecondaryColor;
      case _InspectionDiagramStatus.severe:
        return kRedColor;
      case _InspectionDiagramStatus.none:
        return kBorderColor;
    }
  }

  static void _drawLabel(
    Canvas canvas,
    Rect rect,
    String label,
    _InspectionDiagramStatus status,
  ) {
    final text = label.length > 16 ? '${label.substring(0, 15)}…' : label;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: status == _InspectionDiagramStatus.none
              ? kGreyColor
              : kTertiaryColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 6);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  static void _drawCountBadge(Canvas canvas, Rect rect, int count) {
    final badgeRect = Rect.fromCircle(
      center: Offset(rect.right - 8, rect.top + 8),
      radius: 8,
    );
    canvas.drawOval(badgeRect, Paint()..color = kTertiaryColor);
    final painter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          color: kWhiteColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        badgeRect.center.dx - painter.width / 2,
        badgeRect.center.dy - painter.height / 2,
      ),
    );
  }
}

List<_InspectionDiagramZone> _zonesForGroup(String groupKey) {
  final options =
      _SparkJoyMediaTagRegistry.mediaElementOptionsByGroup[groupKey] ??
      const <_MediaOption>[];
  final labels = {for (final option in options) option.id: option.label};
  final rects = _zoneRectsByGroup[groupKey];
  if (rects == null) return _gridZones(options);
  final zones = <_InspectionDiagramZone>[];
  for (final entry in rects.entries) {
    final label = labels[entry.key];
    if (label == null) continue;
    zones.add(
      _InspectionDiagramZone(id: entry.key, label: label, rect: entry.value),
    );
  }
  final missing = options.where((option) => !rects.containsKey(option.id));
  zones.addAll(_gridZones(missing.toList(), top: 0.82, height: 0.14));
  return zones;
}

List<_InspectionDiagramZone> _gridZones(
  List<_MediaOption> options, {
  double top = 0.08,
  double height = 0.84,
}) {
  if (options.isEmpty) return const [];
  final columns = options.length <= 6 ? 2 : 3;
  final rows = (options.length / columns).ceil();
  const gap = 0.018;
  final cellW = (0.92 - gap * (columns - 1)) / columns;
  final cellH = (height - gap * (rows - 1)) / rows;
  final zones = <_InspectionDiagramZone>[];
  for (var i = 0; i < options.length; i++) {
    final col = i % columns;
    final row = i ~/ columns;
    zones.add(
      _InspectionDiagramZone(
        id: options[i].id,
        label: options[i].label,
        rect: Rect.fromLTWH(
          0.04 + col * (cellW + gap),
          top + row * (cellH + gap),
          cellW,
          cellH,
        ),
      ),
    );
  }
  return zones;
}

const Map<String, Map<String, Rect>> _zoneRectsByGroup = {
  _SparkJoyMediaGroupRegistry.keyBody: {
    'front_bumper': Rect.fromLTWH(0.30, 0.04, 0.40, 0.08),
    'hood': Rect.fromLTWH(0.33, 0.14, 0.34, 0.14),
    'uh_body_elements': Rect.fromLTWH(0.39, 0.30, 0.22, 0.08),
    'roof': Rect.fromLTWH(0.34, 0.40, 0.32, 0.18),
    'trunk': Rect.fromLTWH(0.34, 0.65, 0.32, 0.12),
    'inner_trunk_lid': Rect.fromLTWH(0.38, 0.78, 0.24, 0.06),
    'rear_bumper': Rect.fromLTWH(0.30, 0.87, 0.40, 0.08),
    'left_front_fender': Rect.fromLTWH(0.18, 0.15, 0.13, 0.16),
    'right_front_fender': Rect.fromLTWH(0.69, 0.15, 0.13, 0.16),
    'left_front_door': Rect.fromLTWH(0.16, 0.36, 0.16, 0.15),
    'right_front_door': Rect.fromLTWH(0.68, 0.36, 0.16, 0.15),
    'left_rear_door': Rect.fromLTWH(0.16, 0.53, 0.16, 0.13),
    'right_rear_door': Rect.fromLTWH(0.68, 0.53, 0.16, 0.13),
    'left_rear_fender': Rect.fromLTWH(0.18, 0.68, 0.13, 0.14),
    'right_rear_fender': Rect.fromLTWH(0.69, 0.68, 0.13, 0.14),
    'body_general': Rect.fromLTWH(0.34, 0.30, 0.32, 0.06),
  },
  _SparkJoyMediaGroupRegistry.keyStructural: {
    'rail_left': Rect.fromLTWH(0.26, 0.12, 0.10, 0.70),
    'rail_right': Rect.fromLTWH(0.64, 0.12, 0.10, 0.70),
    'sill_left': Rect.fromLTWH(0.11, 0.28, 0.10, 0.44),
    'sill_right': Rect.fromLTWH(0.79, 0.28, 0.10, 0.44),
    'a_pillar_left': Rect.fromLTWH(0.38, 0.24, 0.09, 0.12),
    'a_pillar_right': Rect.fromLTWH(0.53, 0.24, 0.09, 0.12),
    'b_pillar_left': Rect.fromLTWH(0.38, 0.43, 0.09, 0.12),
    'b_pillar_right': Rect.fromLTWH(0.53, 0.43, 0.09, 0.12),
    'c_pillar_left': Rect.fromLTWH(0.38, 0.62, 0.09, 0.12),
    'c_pillar_right': Rect.fromLTWH(0.53, 0.62, 0.09, 0.12),
    'fender_liner_left_front': Rect.fromLTWH(0.10, 0.08, 0.13, 0.12),
    'fender_liner_right_front': Rect.fromLTWH(0.77, 0.08, 0.13, 0.12),
    'fender_liner_left_rear': Rect.fromLTWH(0.10, 0.78, 0.13, 0.12),
    'fender_liner_right_rear': Rect.fromLTWH(0.77, 0.78, 0.13, 0.12),
    'structural_general': Rect.fromLTWH(0.39, 0.84, 0.22, 0.10),
  },
  _SparkJoyMediaGroupRegistry.keyGlass: {
    'windshield': Rect.fromLTWH(0.34, 0.26, 0.32, 0.11),
    'rear_glass': Rect.fromLTWH(0.34, 0.66, 0.32, 0.11),
    'glass_front_left': Rect.fromLTWH(0.17, 0.37, 0.14, 0.13),
    'glass_front_right': Rect.fromLTWH(0.69, 0.37, 0.14, 0.13),
    'glass_rear_left': Rect.fromLTWH(0.17, 0.52, 0.14, 0.13),
    'glass_rear_right': Rect.fromLTWH(0.69, 0.52, 0.14, 0.13),
    'mirror_left': Rect.fromLTWH(0.08, 0.33, 0.08, 0.08),
    'mirror_right': Rect.fromLTWH(0.84, 0.33, 0.08, 0.08),
    'glass_general': Rect.fromLTWH(0.36, 0.44, 0.28, 0.12),
  },
  _SparkJoyMediaGroupRegistry.keyLighting: {
    'headlights_front': Rect.fromLTWH(0.31, 0.08, 0.38, 0.10),
    'drl': Rect.fromLTWH(0.22, 0.20, 0.22, 0.08),
    'fog_lights': Rect.fromLTWH(0.56, 0.20, 0.22, 0.08),
    'turn_signals': Rect.fromLTWH(0.18, 0.36, 0.64, 0.08),
    'brake_lights': Rect.fromLTWH(0.22, 0.60, 0.22, 0.09),
    'plate_light': Rect.fromLTWH(0.46, 0.60, 0.08, 0.09),
    'taillights_rear': Rect.fromLTWH(0.56, 0.60, 0.22, 0.09),
    'lighting_general': Rect.fromLTWH(0.32, 0.78, 0.36, 0.12),
  },
  _SparkJoyMediaGroupRegistry.keyUnderhood: {
    'uh_engine': Rect.fromLTWH(0.30, 0.20, 0.40, 0.22),
    'uh_accessories': Rect.fromLTWH(0.12, 0.20, 0.15, 0.22),
    'uh_cooling': Rect.fromLTWH(0.30, 0.08, 0.40, 0.09),
    'uh_fuel': Rect.fromLTWH(0.73, 0.20, 0.15, 0.22),
    'uh_intake_turbo': Rect.fromLTWH(0.12, 0.47, 0.24, 0.15),
    'uh_exhaust_ecology': Rect.fromLTWH(0.64, 0.47, 0.24, 0.15),
    'uh_electrical': Rect.fromLTWH(0.39, 0.47, 0.22, 0.15),
    'uh_brakes': Rect.fromLTWH(0.12, 0.67, 0.24, 0.13),
    'uh_steering': Rect.fromLTWH(0.64, 0.67, 0.24, 0.13),
    'uh_fluids': Rect.fromLTWH(0.39, 0.67, 0.22, 0.13),
    'uh_general': Rect.fromLTWH(0.32, 0.84, 0.36, 0.10),
  },
  _SparkJoyMediaGroupRegistry.keyWheels: {
    'front_left_wheel': Rect.fromLTWH(0.12, 0.12, 0.18, 0.16),
    'front_right_wheel': Rect.fromLTWH(0.70, 0.12, 0.18, 0.16),
    'rear_left_wheel': Rect.fromLTWH(0.12, 0.62, 0.18, 0.16),
    'rear_right_wheel': Rect.fromLTWH(0.70, 0.62, 0.18, 0.16),
    'front_left_brake': Rect.fromLTWH(0.31, 0.14, 0.15, 0.12),
    'front_right_brake': Rect.fromLTWH(0.54, 0.14, 0.15, 0.12),
    'rear_left_brake': Rect.fromLTWH(0.31, 0.64, 0.15, 0.12),
    'rear_right_brake': Rect.fromLTWH(0.54, 0.64, 0.15, 0.12),
    'spare_wheel': Rect.fromLTWH(0.38, 0.40, 0.24, 0.14),
    'wheels_general': Rect.fromLTWH(0.32, 0.84, 0.36, 0.10),
  },
  _SparkJoyMediaGroupRegistry.keyInterior: {
    'dashboard_top': Rect.fromLTWH(0.25, 0.08, 0.50, 0.10),
    'instrument_cluster': Rect.fromLTWH(0.24, 0.21, 0.18, 0.10),
    'center_display': Rect.fromLTWH(0.44, 0.21, 0.16, 0.10),
    'climate_panel': Rect.fromLTWH(0.62, 0.21, 0.14, 0.10),
    'steering_wheel': Rect.fromLTWH(0.20, 0.34, 0.16, 0.12),
    'center_console': Rect.fromLTWH(0.42, 0.34, 0.16, 0.20),
    'gear_selector_area': Rect.fromLTWH(0.60, 0.34, 0.16, 0.12),
    'front_seats': Rect.fromLTWH(0.18, 0.50, 0.24, 0.18),
    'rear_seats': Rect.fromLTWH(0.58, 0.50, 0.24, 0.18),
    'door_cards': Rect.fromLTWH(0.06, 0.40, 0.10, 0.34),
    'headliner': Rect.fromLTWH(0.35, 0.70, 0.30, 0.10),
    'trunk_interior': Rect.fromLTWH(0.35, 0.82, 0.30, 0.10),
    'dashboard_buttons_left': Rect.fromLTWH(0.08, 0.24, 0.12, 0.10),
    'interior_general': Rect.fromLTWH(0.78, 0.34, 0.14, 0.18),
  },
};

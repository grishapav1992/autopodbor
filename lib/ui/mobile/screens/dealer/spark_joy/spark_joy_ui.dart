import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

String sjRead(Map<String, dynamic>? map, String key, {String fallback = ''}) {
  if (map == null) return fallback;
  final value = map[key];
  if (value == null) return fallback;
  return value.toString();
}

bool sjReadBool(
  Map<String, dynamic>? map,
  String key, {
  bool fallback = false,
}) {
  final value = map?[key];
  if (value is bool) return value;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return fallback;
}

List<Map<String, dynamic>> sjReadMapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map((e) {
    return Map<String, dynamic>.from(e);
  }).toList();
}

String sjInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

Color sparkAssignmentChipBackground(String status) {
  switch (status) {
    case 'new':
      return const Color(0xFFE8F1FF);
    case 'assigned':
      return const Color(0xFFEFEAFF);
    case 'in_progress':
      return const Color(0xFFFFF4D8);
    case 'completed':
      return const Color(0xFFE8F6EC);
    default:
      return kLightGreyColor;
  }
}

Color sparkAssignmentChipColor(String status) {
  switch (status) {
    case 'new':
      return const Color(0xFF245CBA);
    case 'assigned':
      return const Color(0xFF5A35C8);
    case 'in_progress':
      return const Color(0xFFA87300);
    case 'completed':
      return const Color(0xFF1C7C3D);
    default:
      return kGreyColor;
  }
}

Color sparkVerdictColor(String verdict) {
  switch (verdict) {
    case 'recommended':
      return kGreenColor;
    case 'with_reservations':
      return kYellowColor;
    case 'not_recommended':
      return kRedColor;
    default:
      return kGreyColor;
  }
}

String sparkVerdictLabel(String verdict) {
  switch (verdict) {
    case 'recommended':
      return 'Рекомендован';
    case 'with_reservations':
      return 'С оговорками';
    case 'not_recommended':
      return 'Не рекомендован';
    default:
      return 'Готов';
  }
}

class SparkCard extends StatelessWidget {
  const SparkCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class SparkSectionTitle extends StatelessWidget {
  const SparkSectionTitle(this.text, {super.key, this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: MyText(text: text, size: 14, weight: FontWeight.w700),
    );
  }
}

class SparkInfoRow extends StatelessWidget {
  const SparkInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MyText(text: label, size: 12, color: kGreyColor),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: MyText(
              text: value,
              size: 12,
              textAlign: TextAlign.right,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SparkChip extends StatelessWidget {
  const SparkChip({
    super.key,
    required this.text,
    required this.background,
    required this.color,
  });

  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background,
      ),
      child: MyText(
        text: text,
        size: 10,
        weight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

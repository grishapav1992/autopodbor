import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/reports/report_detail.dart';

class PurchasedReportsScreen extends StatelessWidget {
  const PurchasedReportsScreen({
    super.key,
    required this.onOpenReports,
    this.reports = const [],
  });

  final VoidCallback onOpenReports;
  final List<Map<String, dynamic>> reports;

  String _stringFromAny(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is num) return raw.toString();
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in const ['name', 'title', 'value']) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return raw.toString().trim();
  }

  String _carTitle(Map<String, dynamic> report) {
    final car = _stringFromAny(report['car']);
    if (car.isNotEmpty) return car;
    final make = _stringFromAny(report['make']);
    final model = _stringFromAny(report['model']);
    return [make, model].where((e) => e.isNotEmpty).join(' ');
  }

  String _firstImage(Map<String, dynamic> report) {
    final raw = report['images'];
    if (raw is List) {
      for (final item in raw) {
        final url = item?.toString().trim() ?? '';
        if (url.isNotEmpty) return url;
      }
    }
    final single = report['image']?.toString().trim() ?? '';
    return single;
  }

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: AppSizes.DEFAULT,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MyText(
                  text: 'Пока нет купленных отчетов',
                  size: 14,
                  weight: FontWeight.w700,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                MyText(
                  text: 'Посмотрите доступные отчеты и выберите подходящий.',
                  size: 12,
                  color: kGreyColor,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                MyButton(
                  buttonText: 'Посмотреть отчеты',
                  onTap: onOpenReports,
                  textSize: 12,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: AppSizes.listPaddingWithBottomBar(),
        children: [
          MyText(
            text: 'Купленные отчеты',
            size: 18,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          ...reports.map(
            (report) => _PurchasedReportCard(
              title: _carTitle(report),
              date: _stringFromAny(report['date']),
              verdict: _stringFromAny(report['verdict']),
              imageUrl: _firstImage(report),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportDetailScreen(report: report),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasedReportCard extends StatelessWidget {
  const _PurchasedReportCard({
    required this.title,
    required this.date,
    required this.verdict,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String date;
  final String verdict;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReportThumb(imageUrl: imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MyText(
                    text: title.isNotEmpty ? title : 'Отчет',
                    size: 13,
                    weight: FontWeight.w700,
                  ),
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    MyText(text: date, size: 11, color: kGreyColor),
                  ],
                  if (verdict.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: MyText(
                        text: verdict,
                        size: 11,
                        weight: FontWeight.w600,
                        color: kSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportThumb extends StatelessWidget {
  const _ReportThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: kGreyColor2,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                size: 24,
                color: kGreyColor,
              ),
            )
          : const Icon(Icons.insert_photo, color: kGreyColor),
    );
  }
}

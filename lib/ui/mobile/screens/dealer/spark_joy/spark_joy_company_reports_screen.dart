import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyReportsScreen extends StatefulWidget {
  const SparkJoyCompanyReportsScreen({super.key, required this.onOpenReport});

  final ValueChanged<Map<String, dynamic>> onOpenReport;

  @override
  State<SparkJoyCompanyReportsScreen> createState() =>
      _SparkJoyCompanyReportsScreenState();
}

class _SparkJoyCompanyReportsScreenState
    extends State<SparkJoyCompanyReportsScreen> {
  String _search = '';
  bool _loading = true;
  List<Map<String, dynamic>> _reports = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final completed = await SparkJoyStorage.loadCompleted();

    final platform = sparkPlatformReports
        .where((r) {
          return sjRead(r, 'companyId') == kSparkCompanyId &&
              sjRead(r, 'status') == 'completed';
        })
        .map((r) {
          final vehicle = sjRead(r, 'vehicle');
          return {
            'id': sjRead(r, 'id'),
            'reportName': vehicle,
            'car': vehicle,
            'vin': sjRead(r, 'vin'),
            'createdAt': sjRead(r, 'createdAt'),
            'score':
                '${((double.tryParse(sjRead(r, 'score')) ?? 0) * 10).round()}/100',
            'verdict': 'with_reservations',
            'verdictLabel': 'С оговорками',
            'summaryNote': 'Краткая карточка отчёта из платформы.',
            'sections': [
              {
                'title': 'Автомобиль',
                'status': 'ok',
                'details': [
                  {'label': 'Модель', 'value': vehicle, 'severity': 'ok'},
                  {'label': 'VIN', 'value': sjRead(r, 'vin'), 'severity': 'ok'},
                ],
              },
            ],
          };
        })
        .toList();

    final all = <Map<String, dynamic>>[];
    final ids = <String>{};

    for (final report in completed) {
      final id = sjRead(report, 'id');
      if (id.isEmpty || ids.contains(id)) continue;
      ids.add(id);
      all.add(report);
    }

    for (final report in platform) {
      final id = sjRead(report, 'id');
      if (id.isEmpty || ids.contains(id)) continue;
      ids.add(id);
      all.add(report);
    }

    all.sort(
      (a, b) => sjRead(b, 'createdAt').compareTo(sjRead(a, 'createdAt')),
    );

    if (!mounted) return;
    setState(() {
      _reports = all;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _reports;
    final query = _search.toLowerCase();
    return _reports.where((r) {
      final text = [
        sjRead(r, 'reportName'),
        sjRead(r, 'car'),
        sjRead(r, 'make'),
        sjRead(r, 'model'),
        sjRead(r, 'vin'),
        sjRead(r, 'plate'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  Widget _reportCard(Map<String, dynamic> report) {
    final car = [
      sjRead(report, 'reportName'),
      sjRead(report, 'car'),
      [
        sjRead(report, 'make'),
        sjRead(report, 'model'),
      ].where((e) => e.isNotEmpty).join(' '),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Отчёт');

    final verdict = sjRead(report, 'verdict');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => widget.onOpenReport(report),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.description_outlined,
                size: 16,
                color: kGreyColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MyText(
                          text: car,
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                      SparkChip(
                        text: sjRead(report, 'score', fallback: '—'),
                        background: kSecondaryColor.withValues(alpha: 0.08),
                        color: kSecondaryColor,
                      ),
                    ],
                  ),
                  MyText(
                    text:
                        '${sjRead(report, 'vin')} • ${sjRead(report, 'createdAt')}',
                    size: 11,
                    color: kGreyColor,
                    paddingTop: 2,
                  ),
                  const SizedBox(height: 6),
                  SparkChip(
                    text: sparkVerdictLabel(verdict),
                    background: sparkVerdictColor(
                      verdict,
                    ).withValues(alpha: 0.12),
                    color: sparkVerdictColor(verdict),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        const MyText(text: 'Отчёты', size: 22, weight: FontWeight.w700),
        const SizedBox(height: 10),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            hintText: 'Поиск по отчётам',
            prefixIcon: const Icon(Icons.search, size: 18, color: kGreyColor),
            filled: true,
            fillColor: kWhiteColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kSecondaryColor),
            ),
          ),
        ),
        const SizedBox(height: 10),
        MyText(
          text: 'Найдено: ${filtered.length}',
          size: 11,
          color: kGreyColor,
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 26),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Column(
              children: [
                Icon(Icons.description_outlined, size: 34, color: kGreyColor),
                SizedBox(height: 8),
                MyText(text: 'Нет отчётов', size: 14, weight: FontWeight.w700),
              ],
            ),
          )
        else
          ...filtered.map(_reportCard),
      ],
    );
  }
}

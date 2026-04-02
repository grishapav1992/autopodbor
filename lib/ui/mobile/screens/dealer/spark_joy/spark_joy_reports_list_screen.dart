import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_new_report_name_screen.dart';
import 'spark_joy_report_detail_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_ui.dart';

class SparkJoyReportsListScreen extends StatefulWidget {
  const SparkJoyReportsListScreen({super.key});

  @override
  State<SparkJoyReportsListScreen> createState() =>
      _SparkJoyReportsListScreenState();
}

class _SparkJoyReportsListScreenState extends State<SparkJoyReportsListScreen> {
  String _search = '';
  String _tab = 'completed';
  bool _loading = true;

  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _completed = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final drafts = await SparkJoyStorage.loadDrafts();
    final completed = await SparkJoyStorage.loadCompleted();
    if (!mounted) return;
    setState(() {
      _drafts = drafts;
      _completed = completed;
      _loading = false;
    });
  }

  Future<void> _openNewReport() async {
    final reportName = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SparkJoyNewReportNameScreen()),
    );

    if (!mounted || reportName == null || reportName.trim().isEmpty) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SparkJoyCreateReportScreen(initialReportName: reportName),
      ),
    );

    if (created == true) {
      await _load();
      return;
    }

    await _load();
  }

  Future<void> _openDraft(Map<String, dynamic> draft) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(draft: draft),
      ),
    );

    if (created == true) {
      await _load();
      return;
    }

    await _load();
  }

  Future<void> _openCompleted(Map<String, dynamic> report) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyReportDetailScreen(report: report),
      ),
    );
  }

  Future<void> _deleteDraft(String id) async {
    await SparkJoyStorage.deleteDraft(id);
    await _load();
  }

  List<Map<String, dynamic>> get _filteredDrafts {
    if (_search.trim().isEmpty) return _drafts;
    final query = _search.toLowerCase();
    return _drafts.where((d) {
      final text = [
        sjRead(d, 'reportName'),
        sjRead(d, 'car'),
        sjRead(d, 'brand'),
        sjRead(d, 'model'),
        sjRead(d, 'vin'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCompleted {
    if (_search.trim().isEmpty) return _completed;
    final query = _search.toLowerCase();
    return _completed.where((r) {
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

  Widget _tabButton({
    required String value,
    required String title,
    required int count,
  }) {
    final active = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? kSecondaryColor.withValues(alpha: 0.1)
                : kWhiteColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? kSecondaryColor.withValues(alpha: 0.45)
                  : kBorderColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MyText(
                text: title,
                size: 12,
                weight: FontWeight.w700,
                color: active ? kSecondaryColor : kGreyColor,
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active ? kSecondaryColor : kLightGreyColor,
                  ),
                  child: MyText(
                    text: '$count',
                    size: 10,
                    color: active ? kWhiteColor : kGreyColor,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> draft) {
    final title = [
      sjRead(draft, 'reportName'),
      sjRead(draft, 'car'),
      sjRead(draft, 'vin'),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Новый отчёт');

    final step = int.tryParse(sjRead(draft, 'currentStep')) ?? 1;
    final total = int.tryParse(sjRead(draft, 'totalSteps')) ?? 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => _openDraft(draft),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(text: title, size: 13, weight: FontWeight.w700),
                  if (sjRead(draft, 'car').isNotEmpty &&
                      sjRead(draft, 'car') != title)
                    MyText(
                      text: sjRead(draft, 'car'),
                      size: 11,
                      color: kGreyColor,
                      paddingTop: 2,
                    ),
                  if (sjRead(draft, 'vin').isNotEmpty)
                    MyText(
                      text: sjRead(draft, 'vin'),
                      size: 11,
                      color: kGreyColor,
                      paddingTop: 2,
                    ),
                  MyText(
                    text: 'Шаг $step из $total',
                    size: 11,
                    color: kGreyColor,
                    paddingTop: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MyText(
                  text: sjRead(draft, 'updatedAt'),
                  size: 10,
                  color: kGreyColor,
                ),
                const SizedBox(height: 4),
                SparkChip(
                  text: 'Продолжить',
                  background: kSecondaryColor.withValues(alpha: 0.1),
                  color: kSecondaryColor,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteDraft(sjRead(draft, 'id')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: kBorderColor),
                    foregroundColor: kGreyColor,
                    backgroundColor: kInputBgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Удалить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> report) {
    final car = [
      sjRead(report, 'car'),
      [
        sjRead(report, 'make'),
        sjRead(report, 'model'),
      ].where((e) => e.isNotEmpty).join(' '),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Отчёт');

    final title = sjRead(report, 'reportName', fallback: car);
    final verdict = sjRead(report, 'verdict');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => _openCompleted(report),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(text: title, size: 13, weight: FontWeight.w700),
                      if (car != title)
                        MyText(
                          text: car,
                          size: 11,
                          color: kGreyColor,
                          paddingTop: 2,
                        ),
                      if (sjRead(report, 'vin').isNotEmpty)
                        MyText(
                          text: sjRead(report, 'vin'),
                          size: 11,
                          color: kGreyColor,
                          paddingTop: 2,
                        ),
                      if (sjRead(report, 'mileage').isNotEmpty)
                        MyText(
                          text: '${sjRead(report, 'mileage')} км',
                          size: 11,
                          color: kGreyColor,
                          paddingTop: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MyText(
                      text: sjRead(report, 'createdAt'),
                      size: 10,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SparkChip(
                  text: sjRead(report, 'score', fallback: '—'),
                  background: kSecondaryColor.withValues(alpha: 0.08),
                  color: kSecondaryColor,
                ),
                SparkChip(
                  text: sparkVerdictLabel(verdict),
                  background: sparkVerdictColor(
                    verdict,
                  ).withValues(alpha: 0.12),
                  color: sparkVerdictColor(verdict),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _filteredDrafts;
    final completed = _filteredCompleted;

    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        const MyText(text: 'Мои отчёты', size: 22, weight: FontWeight.w700),
        const MyText(
          text: 'Автоподбор',
          size: 12,
          color: kGreyColor,
          paddingTop: 2,
          paddingBottom: 12,
        ),
        MyButton(
          buttonText: 'Создать новый отчёт',
          onTap: _openNewReport,
          customChild: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: kWhiteColor, size: 20),
              SizedBox(width: 6),
              MyText(
                text: 'Создать новый отчёт',
                size: 14,
                weight: FontWeight.w700,
                color: kWhiteColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            hintText: 'Поиск по марке, модели, VIN... ',
            prefixIcon: const Icon(Icons.search, color: kGreyColor, size: 18),
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
        const SizedBox(height: 12),
        Row(
          children: [
            _tabButton(
              value: 'drafts',
              title: 'Черновики',
              count: drafts.length,
            ),
            const SizedBox(width: 8),
            _tabButton(
              value: 'completed',
              title: 'Завершённые',
              count: completed.length,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 30),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_tab == 'drafts')
          if (drafts.isEmpty)
            const _SparkEmptyState(
              icon: Icons.edit_note,
              title: 'Нет черновиков',
              subtitle: 'Начните новый отчёт, чтобы увидеть его здесь',
            )
          else
            ...drafts.map(_buildDraftCard)
        else if (completed.isEmpty)
          const _SparkEmptyState(
            icon: Icons.check_circle_outline,
            title: 'Нет завершённых отчётов',
            subtitle: 'Завершите осмотр, чтобы увидеть результат',
          )
        else
          ...completed.map(_buildCompletedCard),
      ],
    );
  }
}

class _SparkEmptyState extends StatelessWidget {
  const _SparkEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(icon, size: 34, color: kGreyColor.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          MyText(text: title, size: 14, weight: FontWeight.w700),
          const SizedBox(height: 3),
          MyText(text: subtitle, size: 11, color: kGreyColor),
        ],
      ),
    );
  }
}

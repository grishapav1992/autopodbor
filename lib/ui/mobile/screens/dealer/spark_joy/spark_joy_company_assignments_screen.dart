import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyAssignmentsScreen extends StatefulWidget {
  const SparkJoyCompanyAssignmentsScreen({
    super.key,
    required this.onCreate,
    required this.onOpen,
  });

  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  State<SparkJoyCompanyAssignmentsScreen> createState() =>
      _SparkJoyCompanyAssignmentsScreenState();
}

class _SparkJoyCompanyAssignmentsScreenState
    extends State<SparkJoyCompanyAssignmentsScreen> {
  String _search = '';
  String _status = 'all';
  String _specialist = 'all';

  List<Map<String, dynamic>> get _assignments {
    return sparkAssignments
        .where((a) => sjRead(a, 'companyId') == kSparkCompanyId)
        .map(cloneMap)
        .toList();
  }

  List<Map<String, dynamic>> get _companySpecialists {
    final ids = _assignments.map((a) => sjRead(a, 'specialistId')).toSet();
    return sparkSpecialists
        .where((s) => ids.contains(sjRead(s, 'id')))
        .map(cloneMap)
        .toList();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _assignments;
    if (_status != 'all') {
      list = list.where((a) => sjRead(a, 'status') == _status).toList();
    }
    if (_specialist != 'all') {
      list = list
          .where((a) => sjRead(a, 'specialistId') == _specialist)
          .toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((a) {
        final text = [
          sjRead(a, 'title'),
          sjRead(a, 'vehicle'),
          sjRead(a, 'vin'),
          sjRead(a, 'specialistName'),
        ].join(' ').toLowerCase();
        return text.contains(q);
      }).toList();
    }
    return list;
  }

  Widget _filterMenu({
    required String current,
    required Map<String, String> labels,
    required ValueChanged<String> onSelect,
  }) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      itemBuilder: (_) => labels.entries
          .map(
            (entry) =>
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MyText(
              text: labels[current] ?? 'Фильтр',
              size: 12,
              color: kGreyColor,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: kGreyColor),
          ],
        ),
      ),
    );
  }

  Widget _assignmentCard(Map<String, dynamic> assignment) {
    final status = sjRead(assignment, 'status');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => widget.onOpen(assignment),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.assignment_outlined,
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
                          text: sjRead(assignment, 'title'),
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                      SparkChip(
                        text: sparkAssignmentStatusLabels[status] ?? status,
                        background: sparkAssignmentChipBackground(status),
                        color: sparkAssignmentChipColor(status),
                      ),
                    ],
                  ),
                  MyText(
                    text: sjRead(
                      assignment,
                      'specialistName',
                      fallback: 'Не назначен',
                    ),
                    size: 11,
                    color: kGreyColor,
                    paddingTop: 2,
                  ),
                  if (status == 'completed' &&
                      sjRead(assignment, 'reportId').isNotEmpty)
                    const MyText(
                      text: 'Отчёт готов',
                      size: 10,
                      color: kGreenColor,
                      paddingTop: 3,
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

    final statusOptions = {
      'all': 'Все статусы',
      'new': 'Новые',
      'assigned': 'Переданы',
      'in_progress': 'В работе',
      'completed': 'Завершены',
    };

    final specialistOptions = <String, String>{'all': 'Все спецы'};
    for (final specialist in _companySpecialists) {
      specialistOptions[sjRead(specialist, 'id')] = sjRead(specialist, 'name');
    }

    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        Row(
          children: [
            const Expanded(
              child: MyText(text: 'Заявки', size: 22, weight: FontWeight.w700),
            ),
            SizedBox(
              height: 34,
              child: MyButton(
                buttonText: 'Новая заявка',
                onTap: widget.onCreate,
                textSize: 12,
                customChild: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: kWhiteColor),
                    SizedBox(width: 4),
                    MyText(
                      text: 'Новая заявка',
                      size: 12,
                      color: kWhiteColor,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            hintText: 'Поиск по заявкам',
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
        Row(
          children: [
            _filterMenu(
              current: _status,
              labels: statusOptions,
              onSelect: (value) => setState(() => _status = value),
            ),
            const SizedBox(width: 8),
            _filterMenu(
              current: _specialist,
              labels: specialistOptions,
              onSelect: (value) => setState(() => _specialist = value),
            ),
            const Spacer(),
            MyText(
              text: 'Найдено: ${filtered.length}',
              size: 11,
              color: kGreyColor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_late_outlined,
                  size: 34,
                  color: kGreyColor,
                ),
                SizedBox(height: 8),
                MyText(text: 'Нет заявок', size: 14, weight: FontWeight.w700),
              ],
            ),
          )
        else
          ...filtered.map(_assignmentCard),
      ],
    );
  }
}

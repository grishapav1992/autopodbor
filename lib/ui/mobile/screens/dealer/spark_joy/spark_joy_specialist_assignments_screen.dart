import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoySpecialistAssignmentsScreen extends StatefulWidget {
  const SparkJoySpecialistAssignmentsScreen({super.key});

  @override
  State<SparkJoySpecialistAssignmentsScreen> createState() =>
      _SparkJoySpecialistAssignmentsScreenState();
}

class _SparkJoySpecialistAssignmentsScreenState
    extends State<SparkJoySpecialistAssignmentsScreen> {
  String _search = '';
  String _statusFilter = 'all';

  List<Map<String, dynamic>> get _myAssignments {
    return sparkAssignments
        .where((a) {
          final status = sjRead(a, 'status');
          return sjRead(a, 'specialistId') == kSparkSpecialistId &&
              (status == 'assigned' ||
                  status == 'in_progress' ||
                  status == 'completed');
        })
        .map(cloneMap)
        .toList();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _myAssignments;
    if (_statusFilter != 'all') {
      list = list.where((a) => sjRead(a, 'status') == _statusFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final query = _search.toLowerCase();
      list = list.where((a) {
        final text = [
          sjRead(a, 'title'),
          sjRead(a, 'companyName'),
          sjRead(a, 'vehicle'),
          sjRead(a, 'comment'),
        ].join(' ').toLowerCase();
        return text.contains(query);
      }).toList();
    }
    return list;
  }

  Future<void> _acceptAssignment(Map<String, dynamic> assignment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(
          assignment: assignment,
          initialReportName: sjRead(assignment, 'vehicle'),
        ),
      ),
    );
  }

  Future<void> _openListing(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  }

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Widget _statusPicker() {
    const labels = {
      'all': 'Все статусы',
      'assigned': 'Новые',
      'in_progress': 'В работе',
      'completed': 'Завершены',
    };

    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _statusFilter = value),
      itemBuilder: (_) => labels.entries
          .map(
            (entry) =>
                PopupMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorderColor),
          color: kWhiteColor,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 16, color: kGreyColor),
            const SizedBox(width: 6),
            MyText(
              text: labels[_statusFilter]!,
              size: 12,
              weight: FontWeight.w600,
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: kGreyColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> assignment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: kSecondaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MyText(
                          text: sjRead(assignment, 'title'),
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                        MyText(
                          text: sjRead(assignment, 'companyName'),
                          size: 11,
                          color: kGreyColor,
                          paddingTop: 2,
                        ),
                      ],
                    ),
                  ),
                  SparkChip(
                    text: 'Новая',
                    background: sparkAssignmentChipBackground('new'),
                    color: sparkAssignmentChipColor('new'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (sjRead(assignment, 'listingUrl').isNotEmpty)
                InkWell(
                  onTap: () => _openListing(sjRead(assignment, 'listingUrl')),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: kSecondaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: MyText(
                          text: sjRead(assignment, 'listingUrl'),
                          size: 11,
                          color: kSecondaryColor,
                          textOverflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              if (sjRead(assignment, 'contactPhone').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    onTap: () => _dial(sjRead(assignment, 'contactPhone')),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: kGreyColor,
                        ),
                        const SizedBox(width: 6),
                        MyText(
                          text: sjRead(assignment, 'contactPhone'),
                          size: 11,
                          color: kGreyColor,
                        ),
                      ],
                    ),
                  ),
                ),
              if (sjRead(assignment, 'comment').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: kGreyColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: MyText(
                          text: sjRead(assignment, 'comment'),
                          size: 11,
                          color: kGreyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: MyButton(
                  buttonText: 'Принять',
                  onTap: () => _acceptAssignment(assignment),
                  textSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommonCard(Map<String, dynamic> assignment) {
    final status = sjRead(assignment, 'status');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
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
                        text: sparkAssignmentStatusLabels[status] ?? 'Статус',
                        background: sparkAssignmentChipBackground(status),
                        color: sparkAssignmentChipColor(status),
                      ),
                    ],
                  ),
                  MyText(
                    text: sjRead(assignment, 'companyName'),
                    size: 11,
                    color: kGreyColor,
                    paddingTop: 2,
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
    final pending = _myAssignments
        .where((a) => sjRead(a, 'status') == 'assigned')
        .length;

    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        Row(
          children: [
            const Expanded(
              child: MyText(text: 'Заявки', size: 22, weight: FontWeight.w700),
            ),
            if (pending > 0)
              SparkChip(
                text: '$pending новых',
                background: sparkAssignmentChipBackground('new'),
                color: sparkAssignmentChipColor('new'),
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
            _statusPicker(),
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
                MyText(text: 'Заявок нет', size: 14, weight: FontWeight.w700),
              ],
            ),
          )
        else
          ...filtered.map((assignment) {
            final status = sjRead(assignment, 'status');
            if (status == 'assigned') {
              return _buildPendingCard(assignment);
            }
            return _buildCommonCard(assignment);
          }),
      ],
    );
  }
}

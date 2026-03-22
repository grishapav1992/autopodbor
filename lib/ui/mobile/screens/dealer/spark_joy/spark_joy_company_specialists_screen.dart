import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanySpecialistsScreen extends StatefulWidget {
  const SparkJoyCompanySpecialistsScreen({
    super.key,
    required this.onInvite,
    required this.onOpenDetail,
    required this.onCreateAssignment,
  });

  final VoidCallback onInvite;
  final ValueChanged<Map<String, dynamic>> onOpenDetail;
  final VoidCallback onCreateAssignment;

  @override
  State<SparkJoyCompanySpecialistsScreen> createState() =>
      _SparkJoyCompanySpecialistsScreenState();
}

class _SparkJoyCompanySpecialistsScreenState
    extends State<SparkJoyCompanySpecialistsScreen> {
  String _search = '';
  String _format = 'all';
  String _city = 'all';

  List<Map<String, dynamic>> get _specialists {
    return sparkSpecialists
        .where((s) => sjRead(s, 'companyId') == kSparkCompanyId)
        .map(cloneMap)
        .toList();
  }

  List<String> get _cities {
    final set = <String>{};
    for (final s in _specialists) {
      final city = sjRead(s, 'city');
      if (city.isNotEmpty) {
        set.add(city);
      }
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _specialists;
    if (_format != 'all') {
      list = list.where((s) => sjRead(s, 'format') == _format).toList();
    }
    if (_city != 'all') {
      list = list.where((s) => sjRead(s, 'city') == _city).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) {
        final text = [
          sjRead(s, 'name'),
          sjRead(s, 'city'),
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
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(10),
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

  Widget _specialistCard(Map<String, dynamic> spec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SparkCard(
        onTap: () => widget.onOpenDetail(spec),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kSecondaryColor.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: MyText(
                text: sjInitials(sjRead(spec, 'name')),
                size: 12,
                weight: FontWeight.w700,
                color: kSecondaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MyText(
                          text: sjRead(spec, 'name', fallback: 'Специалист'),
                          size: 13,
                          weight: FontWeight.w700,
                        ),
                      ),
                      SparkChip(
                        text:
                            sparkFormatLabels[sjRead(spec, 'format')] ?? 'Спец',
                        background: kSecondaryColor.withValues(alpha: 0.08),
                        color: kSecondaryColor,
                      ),
                    ],
                  ),
                  MyText(
                    text:
                        '${sjRead(spec, 'city')} · ${sjRead(spec, 'specialization')}',
                    size: 11,
                    color: kGreyColor,
                    paddingTop: 2,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      MyText(
                        text:
                            '${sjRead(spec, 'reportCount', fallback: '0')} отч.',
                        size: 10,
                        color: kGreyColor,
                      ),
                      MyText(
                        text:
                            '${sjRead(spec, 'activeInspections', fallback: '0')} акт.',
                        size: 10,
                        color: kGreyColor,
                      ),
                      MyText(
                        text: 'Был: ${sjRead(spec, 'lastActive')}',
                        size: 10,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'detail') {
                  widget.onOpenDetail(spec);
                } else if (value == 'assign') {
                  widget.onCreateAssignment();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Деактивация в разработке')),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'detail', child: Text('Открыть карточку')),
                PopupMenuItem(
                  value: 'assign',
                  child: Text('Назначить на осмотр'),
                ),
                PopupMenuItem(
                  value: 'deactivate',
                  child: Text('Деактивировать'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.more_vert, size: 18, color: kGreyColor),
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

    final formatOptions = {
      'all': 'Все типы',
      'staff': 'Штатные',
      'guest': 'Внештат',
      'private': 'Частные',
    };

    final cityOptions = <String, String>{'all': 'Все города'};
    for (final city in _cities) {
      cityOptions[city] = city;
    }

    return ListView(
      padding: AppSizes.DEFAULT.copyWith(bottom: 110),
      children: [
        Row(
          children: [
            const Expanded(
              child: MyText(
                text: 'Специалисты',
                size: 22,
                weight: FontWeight.w700,
              ),
            ),
            SizedBox(
              height: 34,
              child: MyButton(
                buttonText: 'Пригласить',
                onTap: widget.onInvite,
                textSize: 12,
                customChild: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      color: kWhiteColor,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    MyText(
                      text: 'Пригласить',
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
            hintText: 'Поиск по имени или городу',
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
              current: _format,
              labels: formatOptions,
              onSelect: (value) => setState(() => _format = value),
            ),
            const SizedBox(width: 8),
            _filterMenu(
              current: _city,
              labels: cityOptions,
              onSelect: (value) => setState(() => _city = value),
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
                Icon(Icons.group_off_outlined, size: 34, color: kGreyColor),
                SizedBox(height: 8),
                MyText(
                  text: 'Специалисты не найдены',
                  size: 14,
                  weight: FontWeight.w700,
                ),
              ],
            ),
          )
        else
          ...filtered.map(_specialistCard),
      ],
    );
  }
}

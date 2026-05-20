import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_request_detail_screen.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyStaffDetailScreen extends StatelessWidget {
  const SparkJoyCompanyStaffDetailScreen({
    super.key,
    required this.specialist,
    required this.requests,
  });

  final Map<String, dynamic> specialist;
  final List<Map<String, dynamic>> requests;

  Future<void> _openRequest(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCompanyRequestDetailScreen(initial: request),
      ),
    );
  }

  String _str(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString();
  }

  String _requestTitle(Map<String, dynamic> request) {
    final number = _str(request, 'requestNumber');
    return number.isEmpty ? 'Заявка' : 'Заявка №$number';
  }

  String _requestCarTitle(Map<String, dynamic> request) {
    final cars = request['requestCars'] ?? request['cars'];
    if (cars is List && cars.isNotEmpty) {
      final first = cars.first;
      if (first is Map) {
        final brand = first['brand'] is Map
            ? (first['brand']['name'] ?? '').toString()
            : (first['brand'] ?? '').toString();
        final model = first['model'] is Map
            ? (first['model']['model'] ?? first['model']['name'] ?? '')
                  .toString()
            : (first['model'] ?? '').toString();
        final title = [
          brand.trim(),
          model.trim(),
        ].where((part) => part.isNotEmpty).join(' ');
        if (title.isNotEmpty) return title;
      }
    }
    final title = [
      _str(request, 'brand').trim(),
      _str(request, 'model').trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    return title.isEmpty ? 'Автомобиль не указан' : title;
  }

  String _formatRuDate(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> request) {
    final badge = requestStatusBadge(_str(request, 'status'));
    final dueAt = _str(request, 'dueAt');

    return SparkListCard(
      onTap: () => _openRequest(context, request),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: SparkSize.iconSm,
            color: kSecondaryColor,
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: _requestTitle(request),
                        size: SparkTextSize.bodyLg,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.sm),
                    SparkChip(
                      text: badge.label,
                      background: badge.bg,
                      color: badge.fg,
                    ),
                  ],
                ),
                MyText(
                  text: _requestCarTitle(request),
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  paddingTop: SparkSpace.xxs,
                ),
                if (dueAt.isNotEmpty)
                  MyText(
                    text: 'Срок: ${_formatRuDate(dueAt)}',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                  ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          const Icon(
            Icons.chevron_right_rounded,
            size: SparkSize.iconMd,
            color: kGreyColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffName = sjRead(specialist, 'name', fallback: 'Сотрудник');
    final specialization = sjRead(specialist, 'specialization');
    final phone = sjRead(specialist, 'phone');
    final city = sjRead(specialist, 'city');

    return SparkPageScaffold(
      appBar: AppBar(centerTitle: false, title: Text(staffName)),
      bottomInset: SparkSpace.xl,
      children: [
        SparkPageHeader(
          title: 'Профиль сотрудника',
          subtitle: specialization.isEmpty
              ? 'Данные сотрудника и назначенные заявки'
              : specialization,
        ),
        SparkCard(
          child: Row(
            children: [
              SparkInitialsAvatar(
                name: staffName,
                size: SparkSize.inputHeight,
                textSize: SparkTextSize.title,
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: staffName,
                      size: SparkTextSize.label,
                      weight: FontWeight.w700,
                    ),
                    if (specialization.isNotEmpty)
                      MyText(
                        text: specialization,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                  ],
                ),
              ),
              SparkChip(
                text: sjT('spark.status.confirmed', fallback: 'Подтверждён'),
                background: kChipCompletedBg,
                color: kChipCompletedFg,
              ),
            ],
          ),
        ),
        if (phone.isNotEmpty || city.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.lg),
          SparkCard(
            child: Column(
              children: [
                if (phone.isNotEmpty)
                  SparkInfoRow(label: 'Телефон', value: phone),
                if (city.isNotEmpty) SparkInfoRow(label: 'Город', value: city),
              ],
            ),
          ),
        ],
        const SizedBox(height: SparkSpace.xl),
        const SparkSectionTitle('Назначенные заявки'),
        if (requests.isEmpty)
          const SparkHintCard(text: 'Назначенных заявок пока нет')
        else
          ...requests.map((request) => _requestCard(context, request)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/auto_request_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/my_request_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key, this.refresh});

  final ValueNotifier<int>? refresh;

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_handleRefresh);
    _load();
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_handleRefresh);
    super.dispose();
  }

  void _handleRefresh() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    List<Map<String, dynamic>> list = [];
    try {
      list = await StorageApi.getRequests();
    } catch (_) {}
    final normalized = list.map(_normalizeRequest).toList();
    if (!mounted) return;
    setState(() {
      _requests = normalized;
      _loading = false;
    });
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  String _formatServerDate(dynamic raw) {
    if (raw == null) return '';
    if (raw is DateTime) return _formatDate(raw);
    if (raw is Map) {
      final mapDate = raw['date'] ?? raw['datetime'] ?? raw['value'];
      if (mapDate != null) {
        return _formatServerDate(mapDate);
      }
    }
    if (raw is num) {
      final ms = raw > 1000000000000 ? raw.toInt() : (raw * 1000).toInt();
      return _formatDate(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    final dateMatch = RegExp(r'(\\d{4}-\\d{2}-\\d{2})').firstMatch(text);
    if (dateMatch != null) {
      final isoDate = dateMatch.group(1) ?? '';
      if (isoDate.isNotEmpty) {
        try {
          return _formatDate(DateTime.parse(isoDate));
        } catch (_) {}
      }
    }
    try {
      return _formatDate(DateTime.parse(text));
    } catch (_) {}
    return text;
  }

  String _normalizeStatus(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return 'Создана';
    final lower = text.toLowerCase();
    if (lower.contains('создан') || lower.contains('create')) return 'Создана';
    if (lower.contains('ожид') || lower.contains('wait')) return 'Ожидает оплаты';
    if (lower.contains('опла') || lower.contains('paid')) return 'Оплачено (эскроу)';
    if (lower.contains('работ') || lower.contains('progress')) return 'В работе';
    if (lower.contains('заверш') || lower.contains('done') || lower.contains('complete')) {
      return 'Завершена';
    }
    if (lower.contains('отмен') || lower.contains('cancel')) return 'Отменена';
    if (lower.contains('возврат') || lower.contains('refund')) return 'Возврат';
    return text;
  }

  Map<String, dynamic> _normalizeRequest(Map<String, dynamic> raw) {
    final typeRaw = raw['requestType'] ?? raw['type'] ?? raw['request_type'];
    final type = typeRaw?.toString() == 'turnkey' ? 'turnkey' : 'by_car';
    final createdAt =
        _formatServerDate(raw['createdAt'] ?? raw['created_at'] ?? raw['created']);
    final dueDate = _formatServerDate(raw['dueAt'] ?? raw['due_at'] ?? raw['due']);
    final requestNumber = raw['requestNumber'] ??
        raw['request_number'] ??
        raw['number'] ??
        '';
    final title = raw['title']?.toString() ??
        (type == 'turnkey' ? 'Под ключ' : 'По авто');
    final subtitle = raw['subtitle']?.toString() ?? '';
    final data = <String, dynamic>{
      'id': raw['id'] ?? raw['requestId'],
      'requestNumber': requestNumber,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'status': _normalizeStatus(raw['status'] ?? raw['state']),
      'createdAt': createdAt,
      'dueDate': dueDate,
      'server': true,
    };
    if (raw['requestCars'] != null) data['requestCars'] = raw['requestCars'];
    if (raw['cars'] != null && data['requestCars'] == null) {
      data['requestCars'] = raw['cars'];
    }
    return data;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AutoRequestScreen()));
    if (created == true) {
      _load();
    }
  }

  Future<void> _openDetail(Map<String, dynamic> request) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MyRequestDetailScreen(request: request),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_loading) {
      content = const Center(child: CircularProgressIndicator(strokeWidth: 2));
      return SafeArea(top: true, bottom: false, child: content);
    }

    if (_requests.isEmpty) {
      content = Center(
        child: Padding(
          padding: AppSizes.DEFAULT,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MyText(
                text: 'Пока нет созданных заявок',
                size: 14,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 12),
              MyButton(
                buttonText: 'Создать заявку',
                onTap: _openCreate,
                textSize: 12,
              ),
            ],
          ),
        ),
      );
      return SafeArea(top: true, bottom: false, child: content);
    }

    content = ListView(
      padding: AppSizes.listPaddingWithBottomBar(),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            MyText(text: 'Мои заявки', size: 18, weight: FontWeight.w700),
            TextButton.icon(
              onPressed: _openCreate,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add, size: 18, color: kSecondaryColor),
              label: const Text(
                'Новая заявка',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kSecondaryColor, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._requests.map(
          (r) => _RequestCard(data: r, onTap: () => _openDetail(r)),
        ),
      ],
    );

    return SafeArea(top: true, bottom: false, child: content);
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  String _cleanInternalRestTag(String text) {
    final cleaned = text.replaceAll(RegExp(r'\brest:\d+\b'), '').trim();
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
  }

  String _normalizeRequestNumber(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (RegExp(r'[A-Za-z]').hasMatch(value)) return value;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return value;
    final six = digits.length > 6 ? digits.substring(digits.length - 6) : digits.padLeft(6, '0');
    return 'F$six';
  }

  String _requestMeta(String requestNumber, String createdAt) {
    final num = _normalizeRequestNumber(requestNumber);
    final date = createdAt.trim();
    if (num.isEmpty && date.isEmpty) return '';
    if (num.isEmpty) return date;
    if (date.isEmpty) return '№ $num';
    return '№ $num | $date';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Создана':
        return kSecondaryColor;
      case 'Ожидает оплаты':
        return kYellowColor;
      case 'Оплачено (эскроу)':
        return kBlueColor;
      case 'В работе':
        return kYellowColor;
      case 'Завершена':
        return kGreenColor;
      case 'Отменена':
        return kRedColor;
      case 'Возврат':
        return kRedColor;
      default:
        return kGreyColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? 'by_car';
    final title = _cleanInternalRestTag((data['title'] ?? 'Заявка').toString());
    final requestNumber = data['requestNumber'] ?? data['id'] ?? '';
    final createdAt = data['createdAt'] ?? '';
    final dueDate = data['dueDate']?.toString() ?? '';
    final requestMeta = _requestMeta(requestNumber.toString(), createdAt.toString());
    final status = data['status'] ?? 'Создана';
    final statusColor = _statusColor(status);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (requestMeta.isNotEmpty) ...[
              MyText(
                text: requestMeta,
                size: 11,
                weight: FontWeight.w600,
                color: kGreyColor,
              ),
              const SizedBox(height: 4),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final chip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: MyText(
                    text: type == 'turnkey' ? 'Под ключ' : 'По авто',
                    size: 10,
                    weight: FontWeight.w700,
                    color: kSecondaryColor,
                  ),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(text: title, size: 14, weight: FontWeight.w700),
                      const SizedBox(height: 6),
                      chip,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: title,
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    chip,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                MyText(
                  text: status,
                  size: 12,
                  weight: FontWeight.w600,
                  color: statusColor,
                ),
                if (dueDate.isNotEmpty)
                  MyText(text: 'Срок: $dueDate', size: 11, color: kGreyColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

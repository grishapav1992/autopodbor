import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
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
    final list = await UserSimplePreferences.getAutoRequests();
    final allowedStatuses = <String>{
      'Создана',
      'Ожидает оплаты',
      'Оплачено (эскроу)',
      'В работе',
      'Завершена',
      'Отменена',
      'Возврат',
    };
    final normalized = list.map((raw) {
      final data = Map<String, dynamic>.from(raw);
      final status = data['status']?.toString() ?? '';
      if (!allowedStatuses.contains(status)) {
        data['status'] = 'Создана';
      }
      return data;
    }).toList();
    if (!mounted) return;
    setState(() {
      _requests = normalized;
      _loading = false;
    });
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_requests.isEmpty) {
      return Center(
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
    }

    return ListView(
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
            if (requestNumber.toString().isNotEmpty) ...[
              MyText(
                text: '№ $requestNumber',
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
                MyText(text: createdAt, size: 11, color: kGreyColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/app_colors.dart';

import 'package:flutter_application_1/core/constants/app_sizes.dart';

import 'package:flutter_application_1/data/preferences/user_preferences.dart';

import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';

import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/inspector_profile_screen.dart';

const String kStatusCreated = 'Создана';

const String kStatusAwaitPayment = 'Ожидает оплаты';

const String kStatusPaid = 'Оплачено (эскроу)';

const String kStatusInWork = 'В работе';

const String kStatusDone = 'Завершена';

const String kStatusCanceled = 'Отменена';

const String kStatusRefund = 'Возврат';

class MyRequestDetailScreen extends StatefulWidget {
  const MyRequestDetailScreen({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  State<MyRequestDetailScreen> createState() => _MyRequestDetailScreenState();
}

class _MyRequestDetailScreenState extends State<MyRequestDetailScreen> {
  late Map<String, dynamic> _data;

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _offersKey = GlobalKey();

  String _cleanInternalRestTag(String text) {
    final cleaned = text.replaceAll(RegExp(r'\brest:\d+\b'), '').trim();
    return cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
  }

  @override
  void initState() {
    super.initState();

    _data = Map<String, dynamic>.from(widget.request);
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _updateRequest(Map<String, dynamic> patch) async {
    final id = _data['id'] as String?;

    if (id == null) return;

    await UserSimplePreferences.updateAutoRequest(id, patch);

    setState(() {
      _data.addAll(patch);
    });
  }

  List<Map<String, dynamic>> _offers() {
    final raw = _data['offers'] as List<dynamic>?;

    if (raw == null) return [];

    return raw.map((o) => Map<String, dynamic>.from(o as Map)).toList();
  }

  Set<String> _canceledOffers() {
    final raw = _data['canceledOffers'] as List<dynamic>?;

    if (raw == null) return {};

    return raw.map((e) => e.toString()).toSet();
  }

  Map<String, dynamic>? _selectedOffer() {
    final id = _data['selectedOfferId']?.toString();

    if (id == null || id.isEmpty) return null;

    for (final offer in _offers()) {
      if (offer['id']?.toString() == id) return offer;
    }

    return null;
  }

  Future<void> _selectOffer(Map<String, dynamic> offer) async {
    final canceled = _canceledOffers();

    canceled.remove(offer['id']?.toString());

    await _updateRequest({
      'status': kStatusAwaitPayment,

      'selectedOfferId': offer['id'],

      'canceledOffers': canceled.toList(),
    });
  }

  Future<void> _cancelSelection() async {
    final selectedId = _data['selectedOfferId']?.toString();

    final canceled = _canceledOffers();

    if (selectedId != null && selectedId.isNotEmpty) {
      canceled.add(selectedId);
    }

    await _updateRequest({
      'status': kStatusCreated,

      'selectedOfferId': null,

      'paidAt': null,

      'canceledOffers': canceled.toList(),
    });
  }

  Future<void> _pay() async {
    await _updateRequest({
      'status': kStatusPaid,

      'paidAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _markDone() async {
    await _updateRequest({'status': kStatusDone});
  }

  Color _statusColor(String status) {
    switch (status) {
      case kStatusCreated:
        return kSecondaryColor;

      case kStatusAwaitPayment:
        return kYellowColor;

      case kStatusPaid:
        return kBlueColor;

      case kStatusInWork:
        return kYellowColor;

      case kStatusDone:
        return kGreenColor;

      case kStatusCanceled:
        return kRedColor;

      case kStatusRefund:
        return kRedColor;

      default:
        return kGreyColor;
    }
  }

  int _stepIndex(String status) {
    switch (status) {
      case kStatusCreated:
        return 0;

      case kStatusAwaitPayment:
        return 1;

      case kStatusPaid:
        return 2;

      case kStatusInWork:
        return 3;

      case kStatusDone:
        return 4;

      default:
        return 0;
    }
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');

    final m = value.month.toString().padLeft(2, '0');

    return '$d.$m.${value.year}';
  }

  String _dueDateLabel(Map<String, dynamic>? offer) {
    if (offer == null) return '';

    final daysRaw = offer['days'];

    int days = 0;

    if (daysRaw is num) {
      days = daysRaw.toInt();
    } else if (daysRaw is String) {
      days = int.tryParse(daysRaw) ?? 0;
    }

    if (days <= 0) return '';

    DateTime base = DateTime.now();

    final paidAt = _data['paidAt']?.toString();

    if (paidAt != null && paidAt.isNotEmpty) {
      try {
        base = DateTime.parse(paidAt);
      } catch (_) {}
    }

    final due = base.add(Duration(days: days));

    return _formatDate(due);
  }

  Future<void> _scrollToOffers() async {
    final ctx = _offersKey.currentContext;

    if (ctx == null) return;

    await Scrollable.ensureVisible(
      ctx,

      duration: const Duration(milliseconds: 300),

      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _data['type'] ?? 'by_car';

    final status = _data['status'] ?? kStatusCreated;

    final title = _cleanInternalRestTag((_data['title'] ?? '').toString());

    final subtitle = _cleanInternalRestTag(
      (_data['subtitle'] ?? '').toString(),
    );

    final selectedOffer = _selectedOffer();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявка'),

        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(true),

          icon: const Icon(Icons.arrow_back),
        ),
      ),

      body: ListView(
        controller: _scrollController,

        padding: AppSizes.listPaddingWithBottomBar(),

        children: [
          _StepBar(status: status, current: _stepIndex(status)),

          const SizedBox(height: 10),

          _MainAction(
            status: status,

            dueDate: _dueDateLabel(selectedOffer),

            onPrimary:
                (status == kStatusCreated || status == kStatusAwaitPayment)
                ? _scrollToOffers
                : null,
          ),

          const SizedBox(height: 12),

          Wrap(
            alignment: WrapAlignment.spaceBetween,

            crossAxisAlignment: WrapCrossAlignment.center,

            spacing: 8,

            runSpacing: 6,

            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,

                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(999),
                ),

                child: MyText(
                  text: status,

                  size: 12,

                  weight: FontWeight.w700,

                  color: _statusColor(status),
                ),
              ),

              MyText(
                text: _data['createdAt'] ?? '',

                size: 11,

                color: kGreyColor,
              ),
            ],
          ),

          if (status == kStatusPaid || status == kStatusInWork) ...[
            const SizedBox(height: 8),

            _PaidInfo(offer: selectedOffer),
          ],

          const SizedBox(height: 16),

          MyText(
            text: type == 'turnkey' ? '  ' : 'Автомобили в заявке',

            size: 14,

            weight: FontWeight.w700,

            paddingBottom: 6,
          ),

          if (type == 'by_car') ..._buildByCar(),

          if (type == 'turnkey') ..._buildTurnkey(),

          const SizedBox(height: 20),

          _buildOffersSection(status, selectedOffer),

          const SizedBox(height: 20),

          _buildActions(status),
        ],
      ),
    );
  }

  List<Widget> _buildByCar() {
    final cars = (_data['cars'] as List<dynamic>?) ?? [];

    if (cars.isEmpty) {
      return [
        MyText(text: 'Автомобили не добавлены', size: 12, color: kGreyColor),
      ];
    }

    return cars.map((raw) {
      final car = Map<String, dynamic>.from(raw as Map);

      final make = car['make'] ?? '-';

      final model = car['model'] ?? '-';

      final generation = _cleanInternalRestTag(
        (car['generation'] ?? '').toString(),
      );

      return Container(
        margin: const EdgeInsets.only(bottom: 10),

        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: kWhiteColor,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: kBorderColor),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            MyText(
              text: '$make $model $generation'.trim(),

              size: 13,

              weight: FontWeight.w600,
            ),

            if ((car['plate'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),

              MyText(
                text: 'Госномер: ${car['plate']}',

                size: 12,

                color: kGreyColor,
              ),
            ],

            if ((car['sourceUrl'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),

              MyText(
                text: 'Ссылка: ${car['sourceUrl']}',

                size: 12,

                color: kGreyColor,
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildTurnkey() {
    final makes = (_data['makes'] as List<dynamic>?)?.cast<String>() ?? [];

    final models = (_data['models'] as List<dynamic>?)?.cast<String>() ?? [];

    final restylings =
        ((_data['restylings'] as List<dynamic>?)?.cast<String>() ?? [])
            .map(_cleanInternalRestTag)
            .toList();

    return [
      _ChipRow(label: 'Марка', values: makes),

      const SizedBox(height: 8),

      _ChipRow(label: 'Модель', values: models),

      const SizedBox(height: 8),

      _ChipRow(label: 'Поколение', values: restylings),
    ];
  }

  Widget _buildOffersSection(
    String status,

    Map<String, dynamic>? selectedOffer,
  ) {
    final offers = _offers();

    final canceled = _canceledOffers();

    final showOthers = status == kStatusCreated || status == kStatusCanceled;

    return Column(
      key: _offersKey,

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        MyText(
          text: 'Предложения автоподборщиков',

          size: 14,

          weight: FontWeight.w700,

          paddingBottom: 10,
        ),

        if (offers.isEmpty)
          MyText(text: 'Пока нет предложений', size: 12, color: kGreyColor)
        else ...[
          if (selectedOffer != null) ...[
            _OfferCard(
              offer: selectedOffer,

              isSelected: true,

              isCanceled: canceled.contains(selectedOffer['id']?.toString()),

              onProfile: () => _openProfile(selectedOffer),

              onPay: status == kStatusAwaitPayment ? _pay : null,
            ),

            const SizedBox(height: 10),
          ],

          if (showOthers)
            ...offers.map(
              (offer) => _OfferCard(
                offer: offer,

                isSelected: false,

                isCanceled: canceled.contains(offer['id']?.toString()),

                onProfile: () => _openProfile(
                  offer,

                  onChoose: status == kStatusCanceled
                      ? null
                      : () => _selectOffer(offer),
                ),

                onChoose: status == kStatusCanceled
                    ? null
                    : () => _selectOffer(offer),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActions(String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        if (status == kStatusAwaitPayment)
          Padding(
            padding: const EdgeInsets.only(top: 10),

            child: OutlinedButton(
              onPressed: _cancelSelection,

              style: OutlinedButton.styleFrom(
                side: BorderSide(color: kSecondaryColor),

                padding: const EdgeInsets.symmetric(vertical: 12),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: const Text(
                'Отменить выбор',

                style: TextStyle(color: kSecondaryColor, fontSize: 12),
              ),
            ),
          ),

        if (status == kStatusPaid || status == kStatusInWork) ...[
          MyButton(buttonText: 'Отчет получен', onTap: _markDone),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(12),

              border: Border.all(color: kBorderColor),
            ),

            child: MyText(
              text:
                  'Отмена недоступна. Сервис может вернуть деньги, если сроки не соблюдены.',

              size: 11,

              color: kGreyColor,
            ),
          ),
        ],

        if (status == kStatusCreated)
          Padding(
            padding: const EdgeInsets.only(top: 10),

            child: OutlinedButton(
              onPressed: () => _updateRequest({'status': kStatusCanceled}),

              style: OutlinedButton.styleFrom(
                side: BorderSide(color: kRedColor),

                padding: const EdgeInsets.symmetric(vertical: 12),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: const Text(
                'Отменить заявку',

                style: TextStyle(color: kRedColor, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  void _openProfile(Map<String, dynamic> offer, {VoidCallback? onChoose}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            InspectorProfileScreen(offer: offer, onChoose: onChoose),
      ),
    );
  }
}

class _PaidInfo extends StatelessWidget {
  const _PaidInfo({required this.offer});

  final Map<String, dynamic>? offer;

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);

    final buf = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;

      buf.write(s[i]);

      if (idx > 1 && idx % 3 == 1) buf.write(' ');
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (offer == null) return const SizedBox.shrink();

    final price = offer?['price'] as num?;

    final days = offer?['days']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: kSecondaryColor.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorderColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          MyText(
            text: 'Оплачено. Деньги на гарантийном счете.',

            size: 12,

            weight: FontWeight.w600,
          ),

          const SizedBox(height: 6),

          if (price != null)
            MyText(
              text: 'Сумма: ${_formatMoney(price)} руб.',

              size: 12,

              color: kGreyColor,
            ),

          if (days.isNotEmpty)
            MyText(
              text: 'Срок выполнения: $days дн.',

              size: 12,

              color: kGreyColor,
            ),

          const SizedBox(height: 4),

          MyText(
            text: 'Если отчет не будет готов в срок, сервис оформит возврат.',

            size: 11,

            color: kGreyColor,
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,

    required this.isSelected,

    required this.isCanceled,

    required this.onProfile,

    this.onChoose,

    this.onPay,
  });

  final Map<String, dynamic> offer;

  final bool isSelected;

  final bool isCanceled;

  final VoidCallback onProfile;

  final VoidCallback? onChoose;

  final VoidCallback? onPay;

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);

    final buf = StringBuffer();

    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;

      buf.write(s[i]);

      if (idx > 1 && idx % 3 == 1) buf.write(' ');
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final name = offer['name']?.toString() ?? '';

    final company = offer['company']?.toString() ?? '';

    final rating = offer['rating']?.toString() ?? '-';

    final reviews = offer['reviews']?.toString() ?? '0';

    final reports = offer['reports']?.toString() ?? '0';

    final price = offer['price'] as num?;

    final days = offer['days']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: kWhiteColor,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorderColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    MyText(text: name, size: 14, weight: FontWeight.w700),

                    if (company.isNotEmpty)
                      MyText(text: company, size: 11, color: kGreyColor),
                  ],
                ),
              ),

              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,

                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(999),
                  ),

                  child: const Text(
                    'Выбрано',

                    style: TextStyle(
                      fontSize: 10,

                      fontWeight: FontWeight.w700,

                      color: kSecondaryColor,
                    ),
                  ),
                ),

              if (!isSelected && isCanceled) ...[
                const SizedBox(width: 6),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,

                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: kRedColor.withValues(alpha: 0.12),

                    borderRadius: BorderRadius.circular(999),
                  ),

                  child: const Text(
                    'Отменено клиентом',

                    style: TextStyle(
                      fontSize: 10,

                      fontWeight: FontWeight.w700,

                      color: kRedColor,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              MyText(text: 'Рейтинг $rating', size: 11, color: kGreyColor),

              const SizedBox(width: 8),

              MyText(text: '$reviews отзывов', size: 11, color: kGreyColor),

              const Spacer(),

              MyText(text: '$reports отчетов', size: 11, color: kGreyColor),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              if (price != null)
                MyText(
                  text: 'Цена: ${_formatMoney(price)} руб.',

                  size: 12,

                  weight: FontWeight.w600,
                ),

              const Spacer(),

              if (days.isNotEmpty)
                MyText(
                  text: 'Срок: $days дн.',

                  size: 12,

                  weight: FontWeight.w600,
                ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              TextButton(
                onPressed: onProfile,

                child: const Text(
                  'Профиль',

                  style: TextStyle(fontSize: 12, color: kSecondaryColor),
                ),
              ),

              const Spacer(),

              if (onPay != null)
                ElevatedButton(
                  onPressed: onPay,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,

                      vertical: 8,
                    ),
                  ),

                  child: const Text(
                    'Оплатить',

                    style: TextStyle(fontSize: 12, color: kWhiteColor),
                  ),
                ),

              if (onChoose != null)
                ElevatedButton(
                  onPressed: onChoose,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,

                      vertical: 8,
                    ),
                  ),

                  child: const Text(
                    'Выбрать',

                    style: TextStyle(fontSize: 12, color: kWhiteColor),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.status, required this.current});

  final String status;

  final int current;

  @override
  Widget build(BuildContext context) {
    final steps = ['Создана', 'Выбран', 'Оплачено', 'В работе', 'Завершена'];

    final isBlocked = status == kStatusCanceled || status == kStatusRefund;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.scaleDown,

              alignment: Alignment.centerLeft,

              child: Row(
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    _StepDot(
                      label: steps[i],

                      state: isBlocked
                          ? _StepState.inactive
                          : (i < current
                                ? _StepState.done
                                : (i == current
                                      ? _StepState.active
                                      : _StepState.inactive)),
                    ),

                    if (i < steps.length - 1)
                      Container(
                        width: 28,

                        height: 2,

                        margin: const EdgeInsets.symmetric(horizontal: 6),

                        color: isBlocked
                            ? kBorderColor
                            : (i < current ? kSecondaryColor : kBorderColor),
                      ),
                  ],
                ],
              ),
            );
          },
        ),

        if (status == kStatusCanceled || status == kStatusRefund) ...[
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: kRedColor.withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(10),

              border: Border.all(color: kRedColor.withValues(alpha: 0.3)),
            ),

            child: MyText(
              text: status == kStatusCanceled
                  ? 'Заявка отменена. Предложения доступны ниже.'
                  : 'Оформляется возврат средств.',

              size: 11,

              color: kRedColor,
            ),
          ),
        ],
      ],
    );
  }
}

enum _StepState { inactive, active, done }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.state});

  final String label;

  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final Color fill;

    final Color text;

    if (state == _StepState.done) {
      fill = kSecondaryColor;

      text = kSecondaryColor;
    } else if (state == _StepState.active) {
      fill = kSecondaryColor;

      text = kSecondaryColor;
    } else {
      fill = kBorderColor;

      text = kGreyColor;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 12,

          height: 12,

          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        ),

        const SizedBox(height: 4),

        MyText(text: label, size: 10, color: text),
      ],
    );
  }
}

class _MainAction extends StatelessWidget {
  const _MainAction({
    required this.status,

    required this.dueDate,

    this.onPrimary,
  });

  final String status;

  final String dueDate;

  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    String title = '';

    String subtitle = '';

    Color tone = kSecondaryColor;

    if (status == kStatusCreated) {
      title = 'Выберите автоподборщика';

      subtitle = 'Ниже список предложений с ценой и сроком.';

      tone = kSecondaryColor;
    } else if (status == kStatusAwaitPayment) {
      title = 'Выбран исполнитель';

      subtitle = 'Оплатите предложение в карточке выбранного.';

      tone = kSecondaryColor;
    } else if (status == kStatusPaid || status == kStatusInWork) {
      title = 'Заявка оплачена';

      subtitle = dueDate.isNotEmpty
          ? '   $dueDate.'
          : 'Ожидаем отчет от автоподборщика.';

      tone = kBlueColor;
    } else if (status == kStatusDone) {
      title = 'Заявка завершена';

      subtitle = 'Отчет получен. Спасибо за доверие!';

      tone = kGreenColor;
    } else if (status == kStatusCanceled) {
      title = 'Заявка отменена';

      subtitle = 'Можно создать новую заявку.';

      tone = kRedColor;
    } else if (status == kStatusRefund) {
      title = 'Оформляется возврат';

      subtitle = 'Средства будут возвращены после проверки.';

      tone = kRedColor;
    }

    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: kBorderColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          MyText(text: title, size: 13, weight: FontWeight.w700, color: tone),

          const SizedBox(height: 4),

          MyText(text: subtitle, size: 11, color: kGreyColor),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.values});

  final String label;

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        MyText(text: label, size: 12, color: kGreyColor),

        const SizedBox(height: 6),

        if (values.isEmpty)
          MyText(text: 'Не выбрано', size: 12, color: kGreyColor)
        else
          Wrap(
            spacing: 6,

            runSpacing: 6,

            children: values
                .map(
                  (v) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,

                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: kSecondaryColor.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(999),
                    ),

                    child: MyText(
                      text: v,

                      size: 11,

                      weight: FontWeight.w600,

                      color: kSecondaryColor,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

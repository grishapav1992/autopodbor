import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Детальный экран заявки для роли company.
///
/// Конструктор принимает уже загруженный `initial` snapshot из списка
/// (`Storage.GetRequest`) — мгновенный paint без spinner'а. В фоне
/// дёргается `Storage.GetRequestCar` за детальными авто-полями
/// (телефон продавца, ссылка на объявление, поколение, рестайлинг).
///
/// Известные backend-gap'ы (placeholder'ы в UI):
///  * `assignedSpecialistId` НЕ возвращается из `GetRequest` —
///    нельзя показать кому назначена заявка
///  * Cancel-flow нет — кнопка отмены disabled с tooltip
///  * Share-link (`CreateSpecialistReportShareUrl`) появится в slice 6
class SparkJoyCompanyRequestDetailScreen extends StatefulWidget {
  const SparkJoyCompanyRequestDetailScreen({
    super.key,
    required this.initial,
  });

  final Map<String, dynamic> initial;

  @override
  State<SparkJoyCompanyRequestDetailScreen> createState() =>
      _SparkJoyCompanyRequestDetailScreenState();
}

class _SparkJoyCompanyRequestDetailScreenState
    extends State<SparkJoyCompanyRequestDetailScreen> {
  List<Map<String, dynamic>>? _cars; // null = ещё не загружено
  String? _carsError;

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  int? get _requestId {
    final v = widget.initial['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _str(String key) => (widget.initial[key] ?? '').toString();

  Future<void> _loadCars() async {
    final id = _requestId;
    if (id == null) {
      setState(() {
        _cars = const [];
        _carsError = 'Не удалось определить ID заявки';
      });
      return;
    }
    try {
      final cars = await storage_api.StorageApi.getRequestCars(
        requestId: id,
      );
      if (!mounted) return;
      setState(() {
        _cars = cars;
        _carsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cars = const [];
        _carsError = 'Не удалось загрузить детали авто: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _str('status');
    final badge = requestStatusBadge(status);
    final number = _str('requestNumber');
    final createdAt = _str('createdAt');
    final dueAt = _str('dueAt');
    final note = _str('note').trim();

    final budgetFrom = widget.initial['budgetFrom'];
    final budgetTo = widget.initial['budgetTo'];
    final city = _str('city').trim();
    final maxMileage = widget.initial['maxMileage'];
    final ownersCount = widget.initial['ownersCount'];

    final histories = widget.initial['requestStatusHistories'];
    final history = histories is List
        ? histories.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
    // History приходит хронологически от бэка; рендерим newest-first.
    history.sort((a, b) {
      final aT = (a['createdAt'] ?? '').toString();
      final bT = (b['createdAt'] ?? '').toString();
      return bT.compareTo(aT);
    });

    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: MyText(
          text: number.isEmpty ? 'Заявка' : 'Заявка №$number',
          size: SparkTextSize.titleLg,
          weight: FontWeight.w800,
        ),
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
        ),
      ),
      body: SparkScreenList(
        bottomInset: 24,
        children: [
          // ── Header card ─────────────────────────────────────────────
          SparkCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: SparkSize.icon5xl,
                  height: SparkSize.icon5xl,
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: kSecondaryColor,
                    size: SparkSize.iconLg,
                  ),
                ),
                const SizedBox(width: SparkSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SparkChip(
                        text: badge.label,
                        background: badge.bg,
                        color: badge.fg,
                      ),
                      const SizedBox(height: SparkSpace.sm),
                      MyText(
                        text: 'Создана: ${_formatRuDateTime(createdAt)}',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                      if (dueAt.isNotEmpty) ...[
                        const SizedBox(height: SparkSpace.xxs),
                        MyText(
                          text: 'Срок: ${_formatRuDate(dueAt)}',
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Автомобиль ──────────────────────────────────────────────
          const SparkSectionTitle('Автомобиль', top: SparkSpace.xxl),
          SparkCard(child: _buildCarSection()),

          // ── Параметры подбора ───────────────────────────────────────
          if (city.isNotEmpty ||
              budgetFrom != null ||
              budgetTo != null ||
              maxMileage != null ||
              ownersCount != null) ...[
            const SparkSectionTitle('Параметры подбора', top: SparkSpace.xxl),
            SparkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (city.isNotEmpty)
                    SparkInfoRow(label: 'Город', value: city),
                  if (budgetFrom != null || budgetTo != null)
                    SparkInfoRow(
                      label: 'Бюджет',
                      value: _formatBudget(budgetFrom, budgetTo),
                    ),
                  if (maxMileage != null)
                    SparkInfoRow(
                      label: 'Макс. пробег',
                      value: '${_formatNumber(maxMileage)} км',
                    ),
                  if (ownersCount != null)
                    SparkInfoRow(
                      label: 'Макс. владельцев',
                      value: ownersCount.toString(),
                    ),
                ],
              ),
            ),
          ],

          // ── Заметка ─────────────────────────────────────────────────
          if (note.isNotEmpty) ...[
            const SparkSectionTitle('Заметка', top: SparkSpace.xxl),
            SparkCard(
              child: MyText(
                text: note,
                size: SparkTextSize.body,
                lineHeight: 1.5,
              ),
            ),
          ],

          // ── Специалист (placeholder из-за backend gap) ──────────────
          const SparkSectionTitle('Специалист', top: SparkSpace.xxl),
          SparkCard(
            backgroundColor: kGreyColor.withValues(alpha: 0.06),
            borderColor: kBorderColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: kGreyColor,
                  size: SparkSize.iconMd,
                ),
                const SizedBox(width: SparkSpace.md),
                const Expanded(
                  child: MyText(
                    text:
                        'Информация о назначенном специалисте появится '
                        'после расширения API. Сейчас бэкенд не возвращает '
                        'эти данные в ответе GetRequest.',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    lineHeight: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // ── История ─────────────────────────────────────────────────
          const SparkSectionTitle('История', top: SparkSpace.xxl),
          if (history.isEmpty)
            const SparkCard(
              child: MyText(
                text: 'История пуста',
                size: SparkTextSize.body,
                color: kGreyColor,
              ),
            )
          else
            SparkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < history.length; i++) ...[
                    _HistoryEntry(entry: history[i]),
                    if (i < history.length - 1)
                      const Divider(height: 1, color: kBorderColor),
                  ],
                ],
              ),
            ),

          // ── Actions ─────────────────────────────────────────────────
          const SizedBox(height: SparkSpace.xxl),
          if (status == 'done') ...[
            SparkPrimaryActionButton(
              label: 'Поделиться отчётом',
              icon: Icons.ios_share_rounded,
              onTap: () {
                // Slice 6 — CreateSpecialistReportShareUrl
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Share-ссылка появится после интеграции '
                      'CreateSpecialistReportShareUrl',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: SparkSpace.md),
          ],
          // Cancel — пока backend не поддерживает.
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Отменить заявку (недоступно)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, SparkSize.actionHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.sm,
            ),
            child: MyText(
              text:
                  'Отмена заявки появится когда backend добавит метод '
                  'CancelRequest.',
              size: SparkTextSize.caption,
              color: kGreyColor,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: SparkSpace.lg),
        ],
      ),
    );
  }

  Widget _buildCarSection() {
    // Из списка приходит `cars: string[]` ("Бренд Модель"); из
    // GetRequestCar — детальные объекты с поколением + рестайлингом +
    // телефоном продавца + URL. Показываем оба слоя: пока детали
    // грузятся — fallback на string-список.
    final rawCarStrings = widget.initial['cars'];
    final carStrings = rawCarStrings is List
        ? rawCarStrings.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    final detailedCars = _cars;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detailedCars == null) ...[
          // Грузятся — показываем pre-loaded имена
          for (final name in carStrings)
            Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    color: kSecondaryColor,
                    size: SparkSize.iconLg,
                  ),
                  const SizedBox(width: SparkSpace.md),
                  Expanded(
                    child: MyText(
                      text: name,
                      size: SparkTextSize.body,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: SparkSpace.md),
          const SizedBox(
            height: SparkSize.spinner,
            width: SparkSize.spinner,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ] else if (_carsError != null) ...[
          MyText(
            text: _carsError!,
            size: SparkTextSize.caption,
            color: kRedColor,
          ),
        ] else if (detailedCars.isEmpty) ...[
          const MyText(
            text: 'Детали автомобиля не загружены',
            size: SparkTextSize.body,
            color: kGreyColor,
          ),
        ] else
          for (int i = 0; i < detailedCars.length; i++) ...[
            if (i > 0) const Divider(height: 24, color: kBorderColor),
            _CarDetailBlock(car: detailedCars[i]),
          ],
      ],
    );
  }
}

// ── Car detail block ──────────────────────────────────────────────────

class _CarDetailBlock extends StatelessWidget {
  const _CarDetailBlock({required this.car});

  final Map<String, dynamic> car;

  String _str(String key) => (car[key] ?? '').toString();

  String get _title {
    final brand = car['brand'];
    final model = car['model'];
    final brandName = (brand is Map) ? (brand['name'] ?? '').toString() : '';
    final modelName = (model is Map)
        ? (model['model'] ?? model['name'] ?? '').toString()
        : '';
    final combined = [brandName, modelName].where((s) => s.isNotEmpty).join(' ');
    return combined.isEmpty ? 'Автомобиль' : combined;
  }

  String? get _generationLabel {
    final g = car['generation'];
    if (g is num) return 'Поколение $g';
    if (g is String && g.isNotEmpty) return 'Поколение $g';
    return null;
  }

  List<Map<String, dynamic>> get _restylings {
    final r = car['restylings'];
    if (r is List) {
      return r.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final sellerPhone = _str('phone').trim();
    final sellerUrl = _str('url').trim();
    final tags = car['tags'];
    final tagList = tags is List
        ? tags.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final gen = _generationLabel;
    final restylings = _restylings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.directions_car_outlined,
              color: kSecondaryColor,
              size: SparkSize.iconLg,
            ),
            const SizedBox(width: SparkSpace.md),
            Expanded(
              child: MyText(
                text: _title,
                size: SparkTextSize.bodyLg,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (gen != null) ...[
          const SizedBox(height: SparkSpace.xs),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: MyText(
              text: gen,
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ),
        ],
        if (restylings.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.xs),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: MyText(
              text: restylings.map((r) {
                final name = (r['restyling'] ?? '').toString().trim();
                final ys = r['yearStart'];
                final ye = r['yearEnd'];
                final years = [ys, ye]
                    .where((y) => y != null)
                    .map((y) => y.toString())
                    .join('–');
                if (name.isEmpty && years.isEmpty) return 'Без рестайлинга';
                if (years.isEmpty) return name;
                if (name.isEmpty) return years;
                return '$name ($years)';
              }).join(', '),
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ),
        ],
        if (tagList.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.sm),
          Wrap(
            spacing: SparkSpace.xs,
            runSpacing: SparkSpace.xs,
            children: tagList
                .map((t) => SparkChip(
                      text: t,
                      background: kSecondaryColor.withValues(alpha: 0.1),
                      color: kSecondaryColor,
                    ))
                .toList(),
          ),
        ],
        if (sellerPhone.isNotEmpty || sellerUrl.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          const Divider(height: 1, color: kBorderColor),
          const SizedBox(height: SparkSpace.md),
          if (sellerPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    color: kGreyColor,
                    size: SparkSize.iconSm,
                  ),
                  const SizedBox(width: SparkSpace.sm),
                  MyText(
                    text: sellerPhone,
                    size: SparkTextSize.body,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          if (sellerUrl.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.link_rounded,
                    color: kGreyColor,
                    size: SparkSize.iconSm,
                  ),
                ),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: MyText(
                    text: sellerUrl,
                    size: SparkTextSize.caption,
                    color: kSecondaryColor,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

// ── History entry ────────────────────────────────────────────────────

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final oldStatus = (entry['oldStatus'] ?? '').toString();
    final newStatus = (entry['newStatus'] ?? '').toString();
    final role = (entry['changedByRole'] ?? '').toString();
    final reason = (entry['reason'] ?? '').toString().trim();
    final createdAt = (entry['createdAt'] ?? '').toString();

    final badge = requestStatusBadge(newStatus);
    final transition = oldStatus.isEmpty
        ? badge.label
        : '${requestStatusBadge(oldStatus).label} → ${badge.label}';
    final roleLabel = requestRoleLabel(role);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SparkSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SparkSize.iconLg,
            height: SparkSize.iconLg,
            decoration: BoxDecoration(
              color: badge.bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              requestStatusIcon(newStatus),
              color: badge.fg,
              size: SparkSize.iconSm,
            ),
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MyText(
                  text: transition,
                  size: SparkTextSize.body,
                  weight: FontWeight.w600,
                ),
                if (roleLabel.isNotEmpty || createdAt.isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xxs),
                  MyText(
                    text: [
                      if (roleLabel.isNotEmpty) roleLabel,
                      if (createdAt.isNotEmpty) _formatRuDateTime(createdAt),
                    ].join(' · '),
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                ],
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xs),
                  MyText(
                    text: reason,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    lineHeight: 1.4,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Local helpers (date/number formatting) ──────────────────────────

String _formatRuDate(String iso) {
  // ISO 8601 — берём YYYY-MM-DD префикс, переворачиваем.
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
}

String _formatRuDateTime(String iso) {
  final dm = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})')
      .firstMatch(iso);
  if (dm == null) return _formatRuDate(iso);
  return '${dm.group(3)}.${dm.group(2)}.${dm.group(1)} '
      '${dm.group(4)}:${dm.group(5)}';
}

String _formatBudget(dynamic from, dynamic to) {
  final f = from is num ? from.toInt() : null;
  final t = to is num ? to.toInt() : null;
  if (f != null && t != null) {
    return '${_formatNumber(f)} – ${_formatNumber(t)} ₽';
  }
  if (f != null) return 'от ${_formatNumber(f)} ₽';
  if (t != null) return 'до ${_formatNumber(t)} ₽';
  return '—';
}

String _formatNumber(dynamic v) {
  if (v == null) return '';
  final n = v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
  // 1000 separators (thin-space) — RU стандарт.
  final s = n.toString();
  final out = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

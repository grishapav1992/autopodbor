import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_external_link.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Общие детали редизайна экрана заявки (компания + специалист):
/// шапка «номер + даты + статус-чип», карточка авто с телефоном и кнопкой
/// звонка, таймлайн истории, квадратные кнопки контактов. Вынесено сюда,
/// чтобы оба детальных экрана рендерили заявку идентично (раньше каждый
/// держал свою копию _CarDetailBlock/_HistoryEntry и они уже разъехались).

// ── Даты ──────────────────────────────────────────────────────────────

String sparkFormatRuDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso;
  return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
}

String sparkFormatRuDateTime(String iso) {
  final dm = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})',
  ).firstMatch(iso);
  if (dm == null) return sparkFormatRuDate(iso);
  return '${dm.group(3)}.${dm.group(2)}.${dm.group(1)}, '
      '${dm.group(4)}:${dm.group(5)}';
}

/// Подзаголовок шапки: «27.05.2026 · срок до 03.06». Год у срока
/// опускается, когда совпадает с годом создания — как в макете.
String sparkRequestDetailSubtitle({
  required String createdAt,
  required String dueAt,
}) {
  final created = sparkFormatRuDate(createdAt).trim();
  final due = _shortDueDate(createdAt, dueAt);
  return [
    if (created.isNotEmpty) created,
    if (due.isNotEmpty) 'срок до $due',
  ].join(' · ');
}

String _shortDueDate(String createdIso, String dueIso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(dueIso);
  if (m == null) return dueIso.trim();
  final createdYear = RegExp(r'^(\d{4})').firstMatch(createdIso)?.group(1);
  if (createdYear != null && createdYear == m.group(1)) {
    return '${m.group(3)}.${m.group(2)}';
  }
  return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
}

// ── Шапка ─────────────────────────────────────────────────────────────

/// AppBar детального экрана заявки: номер крупно, под ним «дата · срок»,
/// справа — статус-чип с точкой. Заменяет прежнюю пару «плоский AppBar +
/// header-карточка со статусом в скролле».
class SparkRequestDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  // Две строки заголовка (18 + 11) с зазором укладываются в 64.
  static const double _toolbarHeight = 64;

  const SparkRequestDetailAppBar({
    super.key,
    required this.title,
    this.subtitle = '',
    this.badge,
  });

  final String title;
  final String subtitle;
  final RequestStatusBadge? badge;

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final chip = badge;
    return AppBar(
      centerTitle: false,
      toolbarHeight: _toolbarHeight,
      backgroundColor: kPrimaryColor,
      foregroundColor: kSecondaryColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MyText(
            text: title,
            size: SparkTextSize.titleLg,
            weight: FontWeight.w800,
            color: kSecondaryColor,
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: SparkSpace.xxs),
            MyText(
              text: subtitle,
              size: SparkTextSize.caption,
              color: kGreyColor,
              maxLines: 1,
              textOverflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: [
        if (chip != null)
          Padding(
            padding: const EdgeInsets.only(right: SparkSpace.xxxl),
            child: SparkChip(
              text: chip.label,
              background: chip.bg,
              color: chip.fg,
              icon: Icons.circle,
              iconSize: 8,
            ),
          ),
      ],
    );
  }
}

// ── Контакты ──────────────────────────────────────────────────────────

/// Квадратная кнопка контакта (звонок/почта) из макета: светлая плитка
/// со скруглением и тёмной иконкой.
class SparkContactIconButton extends StatelessWidget {
  const SparkContactIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: kGreyColor2,
      borderRadius: BorderRadius.circular(SparkRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(SparkRadius.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: SparkSize.actionHeight,
          height: SparkSize.actionHeight,
          child: Icon(icon, color: kSecondaryColor, size: SparkSize.iconLg),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Открывает номеронабиратель. Там, где tel: недоступен (web/desktop без
/// обработчика), молча копирует номер и говорит об этом снекбаром — чтобы
/// кнопка звонка никогда не была «мёртвой».
Future<void> sparkLaunchPhone(BuildContext context, String phone) async {
  final display = phone.trim();
  if (display.isEmpty) return;
  final dialable = display.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri(scheme: 'tel', path: dialable);
  try {
    if (await launchUrl(uri)) return;
  } catch (_) {
    // Проваливаемся в copy-fallback ниже.
  }
  if (!context.mounted) return;
  await Clipboard.setData(ClipboardData(text: display));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Звонки недоступны на этом устройстве — номер скопирован'),
    ),
  );
}

/// Открывает почтовый клиент; при неудаче копирует адрес (см.
/// [sparkLaunchPhone] — та же логика «кнопка не может быть мёртвой»).
Future<void> sparkLaunchEmail(BuildContext context, String email) async {
  final address = email.trim();
  if (address.isEmpty) return;
  final uri = Uri(scheme: 'mailto', path: address);
  try {
    if (await launchUrl(uri)) return;
  } catch (_) {
    // Проваливаемся в copy-fallback ниже.
  }
  if (!context.mounted) return;
  await Clipboard.setData(ClipboardData(text: address));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Почта недоступна на этом устройстве — адрес скопирован'),
    ),
  );
}

// ── Карточка авто ─────────────────────────────────────────────────────

/// Блок одного автомобиля внутри карточки заявки: плитка-иконка, «Бренд
/// Модель», строка «Поколение · Город», рестайлинги/теги, а под
/// разделителем — телефон с кнопкой звонка и ссылка на объявление.
class SparkRequestCarBlock extends StatelessWidget {
  const SparkRequestCarBlock({
    super.key,
    required this.car,
    this.city = '',
    this.phoneLabel = 'Телефон клиента',
  });

  final Map<String, dynamic> car;

  /// Город заявки — в макете живёт в подзаголовке карточки авто.
  final String city;
  final String phoneLabel;

  // Бренд/модель приходят в ДВУХ формах в зависимости от эндпоинта:
  // вложенный объект ({name}/{model|name}) из GetRequestCar или голая
  // строка из list-payload'а.
  String _brandName(dynamic brand) {
    if (brand is Map) return (brand['name'] ?? '').toString().trim();
    return (brand ?? '').toString().trim();
  }

  String _modelName(dynamic model) {
    if (model is Map) {
      return (model['model'] ?? model['name'] ?? '').toString().trim();
    }
    return (model ?? '').toString().trim();
  }

  String get _title {
    final combined = [
      _brandName(car['brand']),
      _modelName(car['model']),
    ].where((s) => s.isNotEmpty).join(' ');
    return combined.isEmpty ? 'Автомобиль' : combined;
  }

  String? get _generationLabel {
    // Диапазон годов, если рестайлинги под рукой (тот же контракт toJson);
    // иначе — номер поколения. Ключ 'restyling' — legacy-форма из
    // specialist-payload'а.
    final range = storage_api.GenerationItem.yearRangeFromRestylingsJson(
      car['restylings'] ?? car['restyling'],
    );
    if (range != null) return 'Поколение $range';
    final g = car['generation'];
    if (g is num) return 'Поколение $g';
    if (g is String && g.isNotEmpty) return 'Поколение $g';
    return null;
  }

  List<Map<String, dynamic>> get _restylings {
    final r = car['restylings'] ?? car['restyling'];
    if (r is List) {
      return r
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String get _restylingsLabel {
    return _restylings
        .map((r) {
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
        })
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final phone = (car['phone'] ?? '').toString().trim();
    final url = (car['url'] ?? '').toString().trim();
    final tags = car['tags'];
    final tagList = tags is List
        ? tags.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final subtitle = [
      if (_generationLabel != null) _generationLabel!,
      if (city.trim().isNotEmpty) city.trim(),
    ].join(' · ');
    final restylingsLabel = _restylingsLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: SparkSize.icon6xl,
              height: SparkSize.icon6xl,
              decoration: BoxDecoration(
                color: kGreyColor2,
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.directions_car_rounded,
                color: kSecondaryColor,
                size: SparkSize.iconXl,
              ),
            ),
            const SizedBox(width: SparkSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyText(
                    text: _title,
                    size: SparkTextSize.titleLg,
                    weight: FontWeight.w800,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: subtitle,
                      size: SparkTextSize.bodyLg,
                      color: kGreyColor,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (restylingsLabel.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.sm),
          MyText(
            text: restylingsLabel,
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
        ],
        if (tagList.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.sm),
          Wrap(
            spacing: SparkSpace.xs,
            runSpacing: SparkSpace.xs,
            children: tagList
                .map(
                  (t) => SparkChip(
                    text: t,
                    background: kSecondaryColor.withValues(alpha: 0.1),
                    color: kSecondaryColor,
                  ),
                )
                .toList(),
          ),
        ],
        if (phone.isNotEmpty || url.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.xxl),
          const Divider(height: 1, color: kBorderColor),
          const SizedBox(height: SparkSpace.xxl),
          if (phone.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  color: kGreyColor,
                  size: SparkSize.iconMd,
                ),
                const SizedBox(width: SparkSpace.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MyText(
                        text: phoneLabel,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                      const SizedBox(height: SparkSpace.xxs),
                      MyText(
                        text: phone,
                        size: SparkTextSize.title,
                        weight: FontWeight.w700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                SparkContactIconButton(
                  icon: Icons.call_rounded,
                  tooltip: 'Позвонить',
                  onTap: () => sparkLaunchPhone(context, phone),
                ),
              ],
            ),
          if (phone.isNotEmpty && url.isNotEmpty)
            const SizedBox(height: SparkSpace.md),
          if (url.isNotEmpty) SparkExternalLinkRow(url: url),
        ],
      ],
    );
  }
}

// ── История ───────────────────────────────────────────────────────────

/// Таймлайн истории заявки из макета: круглая иконка статуса, вертикальная
/// линия между событиями, заголовок-статус, «Роль · дата, время»,
/// пояснение и комментарий в серой плашке.
class SparkRequestHistoryTimeline extends StatelessWidget {
  const SparkRequestHistoryTimeline({super.key, required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < entries.length; i++)
          _SparkTimelineEntry(
            entry: entries[i],
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _SparkTimelineEntry extends StatelessWidget {
  const _SparkTimelineEntry({required this.entry, required this.isLast});

  final Map<String, dynamic> entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final newStatus = (entry['newStatus'] ?? '').toString();
    final role = (entry['changedByRole'] ?? '').toString();
    final reason = requestHistoryReason((entry['reason'] ?? '').toString());
    final createdAt = (entry['createdAt'] ?? '').toString();
    final badge = requestStatusBadge(newStatus);
    final roleLabel = requestRoleLabel(role);
    final meta = [
      if (roleLabel.isNotEmpty) roleLabel,
      if (createdAt.isNotEmpty) sparkFormatRuDateTime(createdAt),
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: SparkSize.icon3xl,
            child: Column(
              children: [
                Container(
                  width: SparkSize.icon3xl,
                  height: SparkSize.icon3xl,
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
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(
                        vertical: SparkSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: kBorderColor,
                        borderRadius: BorderRadius.circular(SparkRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.xl),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : SparkSpace.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyText(
                    text: badge.label,
                    size: SparkTextSize.label,
                    weight: FontWeight.w700,
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: meta,
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                  if (reason.label.isNotEmpty) ...[
                    const SizedBox(height: SparkSpace.xs),
                    MyText(
                      text: reason.label,
                      size: SparkTextSize.body,
                      color: kTertiaryColor,
                      lineHeight: 1.4,
                    ),
                  ],
                  if (reason.comment != null) ...[
                    const SizedBox(height: SparkSpace.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(SparkSpace.xl),
                      decoration: BoxDecoration(
                        color: kGreyColor2,
                        borderRadius: BorderRadius.circular(SparkRadius.md),
                      ),
                      child: MyText(
                        text: '«${reason.comment}»',
                        size: SparkTextSize.body,
                        lineHeight: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Отмена ────────────────────────────────────────────────────────────

/// Пояснение, почему отмена заявки недоступна в текущем статусе —
/// заменяет прежнюю вечно-задизейбленную кнопку «Отменить заявку».
String sparkCancelUnavailableLabel(String status) {
  switch (normalizeRequestStatus(status)) {
    case 'done':
      return 'Отменить заявку недоступно — заявка завершена';
    case 'canceled':
      return 'Отменить заявку недоступно — заявка отменена';
    case 'refund':
      return 'Отменить заявку недоступно — по заявке оформлен возврат';
    case 'failed':
      return 'Отменить заявку недоступно — заявка не выполнена';
    case 'in_work':
      return 'Отменить заявку недоступно — заявка уже в работе';
    case 'paid_escrow':
      return 'Отменить заявку недоступно — заявка уже оплачена';
    default:
      return 'Отмена доступна только до оплаты или начала работы';
  }
}

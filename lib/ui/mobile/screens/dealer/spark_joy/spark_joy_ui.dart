import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_fonts.dart';
import 'package:flutter_application_1/core/constants/app_responsive.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_i18n.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';

String sjRead(Map<String, dynamic>? map, String key, {String fallback = ''}) {
  if (map == null) return fallback;
  final value = map[key];
  if (value == null) return fallback;
  return value.toString();
}

bool sjReadBool(
  Map<String, dynamic>? map,
  String key, {
  bool fallback = false,
}) {
  final value = map?[key];
  if (value is bool) return value;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return fallback;
}

List<Map<String, dynamic>> sjReadMapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map((e) {
    return Map<String, dynamic>.from(e);
  }).toList();
}

String sjInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

Color sparkAssignmentChipBackground(String status) {
  switch (status) {
    case 'new':
      return kChipNewBg;
    case 'assigned':
      return kChipAssignedBg;
    case 'in_progress':
      return kChipInProgressBg;
    case 'completed':
      return kChipCompletedBg;
    default:
      return kLightGreyColor;
  }
}

Color sparkAssignmentChipColor(String status) {
  switch (status) {
    case 'new':
      return kChipNewFg;
    case 'assigned':
      return kChipAssignedFg;
    case 'in_progress':
      return kChipInProgressFg;
    case 'completed':
      return kChipCompletedFg;
    default:
      return kGreyColor;
  }
}

Color sparkVerdictColor(String verdict) {
  switch (verdict) {
    case 'recommended':
      return kGreenColor;
    case 'with_reservations':
      return kYellowColor;
    case 'not_recommended':
      return kRedColor;
    default:
      return kGreyColor;
  }
}

String sparkVerdictLabel(String verdict) {
  switch (verdict) {
    case 'recommended':
      return 'Рекомендован';
    case 'with_reservations':
      return 'С оговорками';
    case 'not_recommended':
      return 'Не рекомендован';
    default:
      return 'Готов';
  }
}

enum SparkJoySectionFillState { empty, partial, done, loading }

class SparkCard extends StatelessWidget {
  const SparkCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(SparkSpace.xl),
    this.backgroundColor = kWhiteColor,
    this.borderColor = kBorderColor,
    this.radius = SparkRadius.lg,
    this.elevated = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final bool elevated;

  static const List<BoxShadow> _elevatedShadow = [
    BoxShadow(
      color: kShadowColor,
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: elevated ? _elevatedShadow : null,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class SparkListCard extends StatelessWidget {
  const SparkListCard({
    super.key,
    required this.child,
    this.onTap,
    this.bottom = SparkSpace.lg,
    this.padding,
    this.backgroundColor = kWhiteColor,
    this.borderColor = kBorderColor,
    this.radius = SparkRadius.lg,
    this.elevated = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double bottom;
  final EdgeInsets? padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SparkCard(
        onTap: onTap,
        padding: padding ?? const EdgeInsets.all(SparkSpace.xl),
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        radius: radius,
        elevated: elevated,
        child: child,
      ),
    );
  }
}

/// Legacy preset model. Kept for old preference values, but profile UI no
/// longer offers avatar presets: users either upload a photo or see one
/// neutral default avatar.
class SparkAvatarPreset {
  const SparkAvatarPreset({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}

/// 10 авто-тематических preset-аватаров. Порядок фиксирован — индекс
/// сохраняется в prefs (не имя), переставлять = ломать существующие
/// профили. Добавлять только в конец.
const List<SparkAvatarPreset> kSparkAvatarPresets = <SparkAvatarPreset>[
  SparkAvatarPreset(
    icon: Icons.directions_car_rounded,
    background: Color(0xFFFFE4E4),
    foreground: Color(0xFFD93131),
  ),
  SparkAvatarPreset(
    icon: Icons.directions_car_filled_rounded,
    background: Color(0xFFE0F2FF),
    foreground: Color(0xFF1E78E0),
  ),
  SparkAvatarPreset(
    icon: Icons.local_taxi_rounded,
    background: Color(0xFFFFF6D6),
    foreground: Color(0xFFB78B00),
  ),
  SparkAvatarPreset(
    icon: Icons.local_shipping_rounded,
    background: Color(0xFFF2E7DA),
    foreground: Color(0xFF8B5A2B),
  ),
  SparkAvatarPreset(
    icon: Icons.two_wheeler_rounded,
    background: Color(0xFFFFE6CC),
    foreground: Color(0xFFD2691E),
  ),
  SparkAvatarPreset(
    icon: Icons.electric_car_rounded,
    background: Color(0xFFD6F2DE),
    foreground: Color(0xFF1F8A3F),
  ),
  SparkAvatarPreset(
    icon: Icons.build_rounded,
    background: Color(0xFFE0E0F5),
    foreground: Color(0xFF4949B0),
  ),
  SparkAvatarPreset(
    icon: Icons.local_gas_station_rounded,
    background: Color(0xFFFFDED1),
    foreground: Color(0xFFCB4B16),
  ),
  SparkAvatarPreset(
    icon: Icons.car_repair_rounded,
    background: Color(0xFFD2EEEC),
    foreground: Color(0xFF1B7F76),
  ),
  SparkAvatarPreset(
    icon: Icons.speed_rounded,
    background: Color(0xFFEDDDF7),
    foreground: Color(0xFF8E44AD),
  ),
];

class SparkInitialsAvatar extends StatelessWidget {
  const SparkInitialsAvatar({
    super.key,
    required this.name,
    this.size = SparkSize.avatarSm,
    this.textSize = SparkTextSize.label,
    this.backgroundColor,
    this.textColor = kSecondaryColor,
    this.imageUrl,
    this.imageBase64,
    this.presetIndex,
  });

  final String name;
  final double size;
  final double textSize;
  final Color? backgroundColor;
  final Color textColor;

  /// Публичный URL аватарки из S3. Приоритетнее imageBase64 и preset.
  final String? imageUrl;

  /// Optional base64-кодированное JPEG/PNG. Применяется только если
  /// imageUrl null/пустой. Fallback при отсутствии сетевого аватара.
  final String? imageBase64;

  /// Legacy preset index. Ignored for rendering; kept to avoid touching every
  /// call site while old preference values are phased out.
  final int? presetIndex;

  Uint8List? _decode() {
    final raw = imageBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      // Verified 2026-05-31 against the live backend: avatars come from
      // S3 (regru) with `Content-Type: binary/octet-stream`, not image/*.
      // cached_network_image silently drops such responses into its
      // errorWidget — this is why staff/company avatars weren't showing
      // (B9). Image.network sniffs the magic bytes itself and renders
      // regardless of the content-type, on every platform, so we use it
      // unconditionally. Avatars are tiny (~140 KB), so losing the disk
      // cache is a non-issue; ImageCache still dedupes in-memory.
      // On ANY load failure (offline, web CORS, 404, a content-type the
      // sniffer still can't read) we fall back to the default person icon
      // (_buildDefaultAvatar) — same as having no avatar at all.
      final Widget networkImage = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildDefaultAvatar(),
      );
      return ClipOval(child: networkImage);
    }
    final bytes = _decode();
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildDefaultAvatar(),
          gaplessPlayback: true,
        ),
      );
    }
    return _buildDefaultAvatar();
  }

  /// Инициалы из первых букв до двух слов имени («Григорий Павленко» →
  /// «ГП»). Пусто — когда имя не задано; тогда fallback на иконку.
  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    return parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
  }

  Widget _buildDefaultAvatar() {
    final initials = _initials;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? kSecondaryColor.withValues(alpha: 0.10),
      ),
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: size * 0.52,
              color: textColor.withValues(alpha: 0.82),
            )
          : MyText(
              text: initials,
              size: textSize,
              weight: FontWeight.w800,
              color: textColor,
            ),
    );
  }
}

class SparkHintCard extends StatelessWidget {
  const SparkHintCard({
    super.key,
    required this.text,
    this.icon,
    this.textColor = kGreyColor,
    this.copyText,
    this.trailing,
  });

  final String text;
  final IconData? icon;
  final Color textColor;
  final String? copyText;

  /// Optional action rendered on the right side of the hint (e.g. a
  /// compact TextButton for "Обновить" when we're surfacing a stale-cache
  /// refresh failure). Use sparingly — the hint card is meant to be
  /// passive context, not a second nav target.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final effectiveCopyText = (copyText ?? '').trim();
    return SparkCard(
      backgroundColor: kInputBgColor,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: SparkSize.iconSm, color: textColor),
            const SizedBox(width: SparkSpace.sm),
          ],
          Expanded(
            child: MyText(
              text: text,
              size: SparkTextSize.body,
              color: textColor,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SparkSpace.sm),
            trailing!,
          ],
          if (effectiveCopyText.isNotEmpty) ...[
            const SizedBox(width: SparkSpace.xs),
            IconButton(
              tooltip: 'Скопировать',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: effectiveCopyText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ошибка скопирована')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              color: kSecondaryColor,
              iconSize: SparkSize.iconSm,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class SparkSectionTitle extends StatelessWidget {
  const SparkSectionTitle(this.text, {super.key, this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    // iOS-style group header: маленький, серый, с трекингом, UPPERCASE.
    // Заголовок секции должен направлять глаз, а не соревноваться с
    // value-текстом в карточке — раньше label-size + чёрный жирный
    // визуально ставил каждую секцию в один ряд с её содержимым.
    return Padding(
      padding: EdgeInsets.only(
        top: top,
        bottom: SparkSpace.sm,
        left: SparkSpace.xs,
      ),
      child: MyText(
        text: text.toUpperCase(),
        size: SparkTextSize.caption,
        color: kGreyColor,
        weight: FontWeight.w700,
        // Положительный letterSpacing для UPPERCASE caption — стандарт
        // iOS group-header. `tracking: true` в MyText даёт -0.4 (для
        // больших шрифтов), а здесь нужно loose, не tight.
        letterSpacing: 0.6,
      ),
    );
  }
}

class SparkStepHeader extends StatelessWidget {
  const SparkStepHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    this.subtitle = '',
    this.showProgress = true,
    this.progress = 0,
  });

  final int currentStep;
  final int totalSteps;
  final String title;
  final String subtitle;
  final bool showProgress;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: SparkSize.stepBadge,
                height: SparkSize.stepBadge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kLightGreyColor,
                  borderRadius: BorderRadius.circular(SparkRadius.sm),
                ),
                child: MyText(
                  text: '$currentStep',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: title,
                      size: SparkTextSize.title,
                      weight: FontWeight.w700,
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: SparkSpace.xxs),
                      MyText(
                        text: subtitle,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                    ],
                  ],
                ),
              ),
              MyText(
                text: '$currentStep/$totalSteps',
                size: SparkTextSize.caption,
                color: kGreyColor,
                weight: FontWeight.w700,
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: SparkSpace.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.pill),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: SparkSize.progressThin,
                backgroundColor: kLightGreyColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  kSecondaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SparkInfoRow extends StatelessWidget {
  const SparkInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;

  /// Делает value тапабельным (акцентный цвет — видно, что это действие,
  /// например переход в профиль исполнителя).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueText = MyText(
      text: value,
      size: SparkTextSize.body,
      textAlign: TextAlign.right,
      weight: FontWeight.w600,
      color: onTap == null ? null : kSecondaryColor,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MyText(
              text: label,
              size: SparkTextSize.body,
              color: kGreyColor,
            ),
          ),
          const SizedBox(width: SparkSpace.lg),
          Flexible(
            child: onTap == null
                ? valueText
                : Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(SparkRadius.sm),
                      child: valueText,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tappable iOS-style list row для профиля: leading-иконка, label-сверху
/// + value-снизу, опциональный trailing-виджет (бейдж/чип), chevron
/// справа. Tap открывает редактор поля (bottom-sheet/dialog). Если
/// `onTap == null` — row становится не-интерактивным (без chevron, без
/// InkWell). Используется как замена двухколоночной view-mode карточки
/// «Информация», где целая карточка переключалась в edit-mode по одному
/// pencil-кнопке и пользователь не понимал, какое поле он редактирует.
class SparkProfileRow extends StatelessWidget {
  const SparkProfileRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
    this.valueIsPlaceholder = false,
    this.muted = false,
    this.maxLinesValue,
    this.required = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Прячет шеврон «→» у тапабельной строки. Для действий-не-переходов
  /// (позвонить/написать) шеврон врёт про навигацию — вместо него caller
  /// передаёт свою иконку через [trailing].
  final bool showChevron;

  /// Когда value — это placeholder для пустого поля («Не указано»),
  /// рендерим его серым/regular-весом, чтобы не путать с реальными
  /// данными.
  final bool valueIsPlaceholder;

  /// Demote row visually: серая icon, dim-text. Для read-only-полей
  /// (телефон), которые по идее формально такие же, как остальные, но
  /// без affordance редактирования — чтобы юзер не пытался тапнуть.
  final bool muted;

  /// Ограничение количества строк в value. По умолчанию (null) — без
  /// ограничения. Полезно для «Описание услуг»: 2-3 строки превью с
  /// «…» — тап открывает полный текст в редакторе.
  final int? maxLinesValue;

  /// Когда true — рендерим красную `*` после label'а. Для required-
  /// полей формы (например, «Марка *» в форме создания заявки).
  final bool required;

  @override
  Widget build(BuildContext context) {
    final iconColor = muted
        ? kGreyColor
        : (valueIsPlaceholder ? kGreyColor : kSecondaryColor);
    final Color? valueColor = (muted || valueIsPlaceholder) ? kGreyColor : null;
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xs,
        vertical: SparkSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: SparkSize.iconLg, color: iconColor),
          const SizedBox(width: SparkSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                required
                    ? RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: label,
                              style: const TextStyle(
                                fontSize: SparkTextSize.caption,
                                color: kGreyColor,
                              ),
                            ),
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(
                                fontSize: SparkTextSize.caption,
                                color: kRedColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : MyText(
                        text: label,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                const SizedBox(height: SparkSpace.xxs),
                MyText(
                  text: value,
                  size: SparkTextSize.bodyLg,
                  weight: (valueIsPlaceholder || muted)
                      ? FontWeight.w400
                      : FontWeight.w600,
                  color: valueColor,
                  lineHeight: 1.30,
                  maxLines: maxLinesValue,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SparkSpace.sm),
            trailing!,
          ],
          if (onTap != null && showChevron) ...[
            const SizedBox(width: SparkSpace.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: SparkSize.iconLg,
              color: kGreyColor,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
        child: body,
      ),
    );
  }
}

class SparkChip extends StatelessWidget {
  const SparkChip({
    super.key,
    required this.text,
    required this.background,
    required this.color,
    this.icon,
    this.iconSize = SparkTextSize.body,
    this.textSize = SparkTextSize.chip,
    this.padding = const EdgeInsets.symmetric(
      horizontal: SparkSpace.md,
      vertical: SparkSpace.xs,
    ),
  });

  final String text;
  final Color background;
  final Color color;
  final IconData? icon;
  final double iconSize;
  final double textSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        color: background,
        boxShadow: const [
          BoxShadow(
            color: Color(0x80FFFFFF),
            blurRadius: 1,
            offset: Offset(0, 1),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: SparkSpace.xs),
          ],
          MyText(
            text: text,
            size: textSize,
            weight: FontWeight.w700,
            color: color,
          ),
        ],
      ),
    );
  }
}

class SparkSelectableChip extends StatelessWidget {
  const SparkSelectableChip({
    super.key,
    required this.text,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        child: AnimatedContainer(
          duration: SparkMotion.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.chipX,
            vertical: SparkSpace.xl,
          ),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withValues(alpha: 0.12)
                : kLightGreyColor,
            borderRadius: BorderRadius.circular(SparkRadius.pill),
            border: Border.all(
              color: selected
                  ? selectedColor.withValues(alpha: 0.45)
                  : kBorderColor,
            ),
          ),
          child: MyText(
            text: text,
            size: SparkTextSize.label,
            weight: FontWeight.w700,
            color: selected ? selectedColor : kGreyColor,
          ),
        ),
      ),
    );
  }
}

class SparkSegmentedTabItem {
  const SparkSegmentedTabItem({
    required this.value,
    required this.label,
    this.count = 0,
  });

  final String value;
  final String label;
  final int count;
}

class SparkSegmentedTabs extends StatelessWidget {
  const SparkSegmentedTabs({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<SparkSegmentedTabItem> items;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Underline-style tabs (Material 3 inspired):
    //   • Активная вкладка — тёмный жирный текст, под ней
    //     анимированный индикатор-полоса.
    //   • Неактивная — серый regular, без подложки.
    //   • Счётчики — отдельным pill-badge'ем справа от лейбла.
    //   • Под всей tabs-полосой — горизонтальный divider.
    final selectedIndex = items.indexWhere((i) => i.value == value);
    final clampedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = items.isEmpty
                  ? constraints.maxWidth
                  : constraints.maxWidth / items.length;
              return Stack(
                children: [
                  Row(
                    children: [
                      for (int index = 0; index < items.length; index++)
                        Expanded(
                          child: _SparkUnderlineTabButton(
                            item: items[index],
                            active: value == items[index].value,
                            onTap: () => onChanged(items[index].value),
                          ),
                        ),
                    ],
                  ),
                  if (items.isNotEmpty)
                    AnimatedPositioned(
                      duration: SparkMotion.regular,
                      curve: Curves.easeOutCubic,
                      left: clampedIndex * tabWidth + SparkSpace.lg,
                      width: (tabWidth - SparkSpace.lg * 2).clamp(
                        24.0,
                        double.infinity,
                      ),
                      bottom: 0,
                      height: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kSecondaryColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(SparkRadius.xs),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Container(height: 1, color: kBorderColor),
      ],
    );
  }
}

class _SparkUnderlineTabButton extends StatelessWidget {
  const _SparkUnderlineTabButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final SparkSegmentedTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: SparkSpace.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MyText(
                text: item.label,
                size: SparkTextSize.sectionTitle,
                weight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? kSecondaryColor : kGreyColor,
              ),
              if (item.count > 0) ...[
                const SizedBox(width: SparkSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.sm,
                    vertical: SparkSpace.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: active ? kSecondaryColor : kLightGreyColor,
                    borderRadius: BorderRadius.circular(SparkRadius.pill),
                  ),
                  child: MyText(
                    text: '${item.count}',
                    size: SparkTextSize.caption,
                    weight: FontWeight.w700,
                    color: active ? kWhiteColor : kGreyColor,
                    tabularFigures: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration sparkInputDecoration(
  String hint, {
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? labelText,
  String? errorText,
  bool dense = false,
}) {
  return InputDecoration(
    hintText: hint,
    labelText: labelText,
    errorText: errorText,
    filled: true,
    fillColor: kWhiteColor,
    isDense: dense,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: EdgeInsets.symmetric(
      horizontal: SparkSpace.xl,
      vertical: dense ? SparkSpace.lg : SparkSpace.xl,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SparkRadius.lg),
      borderSide: const BorderSide(color: kBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SparkRadius.lg),
      borderSide: const BorderSide(color: kBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SparkRadius.lg),
      borderSide: const BorderSide(color: kSecondaryColor),
    ),
  );
}

class SparkPageHeader extends StatelessWidget {
  const SparkPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyText(
          text: title,
          size: SparkTextSize.pageTitle,
          weight: FontWeight.w800,
          lineHeight: 1.30,
          tracking: true,
        ),
        MyText(
          text: subtitle,
          size: SparkTextSize.body,
          color: kGreyColor,
          paddingTop: SparkSpace.xxs,
          paddingBottom: SparkSpace.xl,
        ),
      ],
    );
  }
}

/// Единый хедер для всех обычных экранов Spark Joy.
///
/// Главный shell и вложенные маршруты используют одну поверхность,
/// типографику и нижний разделитель. Вложенные экраны отличаются только
/// системной кнопкой «Назад» и своими actions.
AppBar sparkAppBar({
  required String title,
  String subtitle = '',
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double? toolbarHeight,
}) {
  final hasLeading = leading != null || automaticallyImplyLeading;
  final hasSubtitle = subtitle.trim().isNotEmpty;
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    centerTitle: false,
    leading: leading,
    titleSpacing: hasLeading ? 0 : SparkSpace.section,
    toolbarHeight: toolbarHeight,
    backgroundColor: kPrimaryColor,
    foregroundColor: kSecondaryColor,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: const Border(
      bottom: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
    ),
    title: hasSubtitle
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MyText(
                text: title,
                size: SparkTextSize.title,
                weight: FontWeight.w800,
                color: kSecondaryColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
              MyText(
                text: subtitle,
                size: SparkTextSize.body,
                color: kGreyColor,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ],
          )
        : MyText(
            text: title,
            size: SparkTextSize.titleLg,
            weight: FontWeight.w800,
            color: kSecondaryColor,
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
          ),
    actions: actions,
  );
}

class SparkReportEditorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  // Одна строка заголовка (+ мета + пилюля автосейва) укладывается в ~60px;
  // 78 даёт компактный бар без вертикальной пустоты, которую давал прежний
  // фикс 96 под 2-строчный заголовок (короткое имя висело в центре бара).
  static const double _toolbarHeight = 78;

  const SparkReportEditorAppBar({
    super.key,
    required this.title,
    required this.meta,
    required this.draftStatus,
    required this.draftStatusColor,
    required this.draftStatusIcon,
    required this.draftSaving,
    required this.onBack,
    this.titleController,
    this.titleFocusNode,
    this.onShare,
    this.sharing = false,
  });

  final String title;
  final String meta;
  final String draftStatus;
  final Color draftStatusColor;
  final IconData draftStatusIcon;
  final bool draftSaving;
  final VoidCallback onBack;
  final TextEditingController? titleController;
  final FocusNode? titleFocusNode;

  /// When non-null the AppBar renders a share icon in the actions row. Used
  /// by the read-only completed-report view to surface the "Поделиться"
  /// affordance next to the back button without adding a bottom action bar.
  final VoidCallback? onShare;

  /// Swap the share icon for a compact spinner while the share URL is
  /// being generated so mashing the button doesn't queue duplicate RPCs.
  final bool sharing;

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);

  @override
  Widget build(BuildContext context) {
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
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      titleSpacing: 0,
      // Пилюля автосейва живёт в строке меты (замечание 2026-07-14): в строке
      // заголовка она отъедала ширину и длинные названия обрезались раньше
      // времени. Заголовок получает всю ширину бара, пилюля прижата к правому
      // краю строки даты.
      title: Padding(
        padding: EdgeInsets.only(right: onShare == null ? SparkSpace.xl : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titleController != null && titleFocusNode != null)
              _SparkEditableReportTitle(
                controller: titleController!,
                focusNode: titleFocusNode!,
              )
            else
              _SparkReportTitle(title: title),
            const SizedBox(height: SparkSpace.xs),
            Row(
              children: [
                Expanded(
                  child: MyText(
                    text: meta,
                    size: SparkTextSize.body,
                    color: kGreyColor,
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                _SparkDraftSaveBadge(
                  text: draftStatus,
                  color: draftStatusColor,
                  icon: draftStatusIcon,
                  saving: draftSaving,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (onShare != null)
          IconButton(
            onPressed: sharing ? null : onShare,
            tooltip: 'Поделиться ссылкой',
            icon: sharing
                ? const SizedBox(
                    width: SparkSize.iconSm,
                    height: SparkSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
          ),
      ],
    );
  }
}

/// Название черновика в шапке выглядит как обычный однострочный заголовок,
/// но редактируется сразу по нажатию. Отдельные карандаш, рамка и кнопка
/// подтверждения не нужны: потеря фокуса или action «Готово» на клавиатуре
/// фиксируют введённое значение через общий listener экрана.
///
/// Вне редактирования рендерится текст с многоточием ([TextField] в одну
/// строку не умеет «…» — длинное имя просто обрезалось по краю); тап по
/// строке подменяет текст на настоящее поле ввода и передаёт ему фокус.
/// Флаг редактирования — локальный стейт, а не `focusNode.hasFocus`:
/// пока поле не построено, нода не привязана к дереву фокуса и
/// `requestFocus` на ней не уведомляет слушателей.
class _SparkEditableReportTitle extends StatefulWidget {
  const _SparkEditableReportTitle({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  State<_SparkEditableReportTitle> createState() =>
      _SparkEditableReportTitleState();
}

class _SparkEditableReportTitleState extends State<_SparkEditableReportTitle> {
  late bool _editing = widget.focusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SparkEditableReportTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
      _editing = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted || widget.focusNode.hasFocus == _editing) return;
    setState(() => _editing = widget.focusNode.hasFocus);
  }

  void _startEditing() {
    setState(() => _editing = true);
    // Нода привяжется к дереву при билде TextField и подхватит отложенный
    // запрос фокуса (_requestFocusWhenReparented).
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final text = widget.controller.text;
          final isEmpty = text.trim().isEmpty;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startEditing,
            child: SizedBox(
              width: double.infinity,
              child: MyText(
                text: isEmpty ? 'Новый отчёт' : text,
                size: SparkTextSize.title,
                weight: FontWeight.w700,
                lineHeight: 1.15,
                color: isEmpty ? kGreyColor : null,
                maxLines: 1,
                textOverflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      );
    }
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      textInputAction: TextInputAction.done,
      maxLines: 1,
      onSubmitted: (_) => widget.focusNode.unfocus(),
      onTapOutside: (_) => widget.focusNode.unfocus(),
      style: TextStyle(
        fontSize: AppResponsive.sp(context, SparkTextSize.title),
        fontWeight: FontWeight.w700,
        height: 1.15,
        fontFamily: AppFonts.URBANIST,
        fontFamilyFallback: const [
          'SF Pro Text',
          'Helvetica',
          'Roboto',
          'Arial',
          'Noto Sans',
          'sans-serif',
        ],
      ),
      decoration: InputDecoration(
        hintText: 'Новый отчёт',
        hintStyle: TextStyle(
          color: kGreyColor,
          fontSize: AppResponsive.sp(context, SparkTextSize.title),
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }
}

/// Заголовок отчёта в шапке редактора — всегда одна строка с «…».
///
/// Прежний вариант держал 2 строки и фиксированную высоту 96px под худший
/// случай; при обычном коротком имени заголовок висел по центру высокого
/// бара и снизу/сверху зияла пустота. Теперь имя всегда в одну строку
/// (бар компактный), а если оно не влезло по ширине — тап открывает диалог
/// с полным названием. Факт обрезки меряем [TextPainter]'ом по реальной
/// ширине слота, повторяя эффективный стиль [MyText], чтобы тап включался
/// ТОЛЬКО когда текст действительно усечён (короткое имя не ловит зря
/// нажатия и не открывает бессмысленный диалог).
class _SparkReportTitle extends StatelessWidget {
  const _SparkReportTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final measureStyle = TextStyle(
      fontSize: AppResponsive.sp(context, SparkTextSize.title),
      fontWeight: FontWeight.w700,
      height: 1.15,
      fontFamily: AppFonts.URBANIST,
      fontFamilyFallback: const [
        'SF Pro Text',
        'Helvetica',
        'Roboto',
        'Arial',
        'Noto Sans',
        'sans-serif',
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: title, style: measureStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final truncated = painter.didExceedMaxLines;
        return MyText(
          text: title,
          size: SparkTextSize.title,
          weight: FontWeight.w700,
          lineHeight: 1.15,
          maxLines: 1,
          textOverflow: TextOverflow.ellipsis,
          onTap: truncated ? () => _showFullReportTitle(context, title) : null,
        );
      },
    );
  }
}

/// Диалог с полным названием отчёта — открывается тапом по усечённому
/// заголовку в шапке (см. [_SparkReportTitle]).
void _showFullReportTitle(BuildContext context, String title) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kWhiteColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SparkRadius.lg),
      ),
      title: const MyText(
        text: 'Название отчёта',
        size: SparkTextSize.sectionTitle,
        weight: FontWeight.w700,
      ),
      content: MyText(
        text: title,
        size: SparkTextSize.bodyLg,
        maxLines: 8,
        lineHeight: 1.3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const MyText(
            text: 'Закрыть',
            size: SparkTextSize.label,
            weight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Compact pill rendered in the meta row of the editor AppBar, right of the
/// «Отчёт от …» date.
///
/// Reads autosave state at a glance: a small spinner replaces the leading
/// icon while a save is in flight, the pill tint matches the semantic
/// state colour (green / yellow / red / secondary), and the text matches
/// the meta font size so the row reads as one line.
class _SparkDraftSaveBadge extends StatelessWidget {
  const _SparkDraftSaveBadge({
    required this.text,
    required this.color,
    required this.icon,
    required this.saving,
  });

  final String text;
  final Color color;
  final IconData icon;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final Widget leading = saving
        ? SizedBox(
            width: SparkTextSize.body,
            height: SparkTextSize.body,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          )
        : Icon(icon, size: SparkSize.iconSm, color: color);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: SparkSpace.xs),
          MyText(
            text: text,
            size: SparkTextSize.body,
            weight: FontWeight.w700,
            color: color,
            tabularFigures: true,
          ),
        ],
      ),
    );
  }
}

class SparkPrimaryActionButton extends StatelessWidget {
  const SparkPrimaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add,
    this.showIcon = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool showIcon;

  /// When true the button becomes non-interactive, swaps the leading icon
  /// for a spinner, and fades the gradient. Use this while the callback
  /// kicks off async work (e.g. an RPC that opens a modal on return) so
  /// successive taps don't queue up duplicate operations.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SparkRadius.lg);
    return SizedBox(
      height: SparkSize.inputHeightLg,
      child: Opacity(
        opacity: busy ? 0.7 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: [kSecondaryColor, kBlueColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: const [
              BoxShadow(
                color: kShadowColor,
                blurRadius: 16,
                offset: Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: busy
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      onTap();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy) ...[
                      const SizedBox(
                        width: SparkSize.spinner,
                        height: SparkSize.spinner,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            kWhiteColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: SparkSpace.sm),
                    ] else if (showIcon) ...[
                      Icon(icon, color: kWhiteColor, size: SparkSize.iconLg),
                      const SizedBox(width: SparkSpace.sm),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: SparkTextSize.label,
                        fontWeight: FontWeight.w700,
                        color: kWhiteColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SparkStepActionBar extends StatelessWidget {
  const SparkStepActionBar({
    super.key,
    required this.secondaryLabel,
    required this.onSecondaryTap,
    required this.primaryLabel,
    required this.onPrimaryTap,
    this.primaryDisabled = false,
    this.primaryBusy = false,
    this.secondaryDisabled = false,
  });

  final String secondaryLabel;
  final VoidCallback onSecondaryTap;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final bool primaryDisabled;
  final bool primaryBusy;
  final bool secondaryDisabled;

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      radius: SparkRadius.md,
      padding: const EdgeInsets.all(SparkSpace.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: SparkSize.actionHeight,
                  child: FilledButton.icon(
                    onPressed: (primaryDisabled || primaryBusy)
                        ? null
                        : onPrimaryTap,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: kSecondaryColor,
                      foregroundColor: kWhiteColor,
                      disabledBackgroundColor: kGreyColor.withValues(
                        alpha: 0.35,
                      ),
                      disabledForegroundColor: kWhiteColor.withValues(
                        alpha: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                        side: const BorderSide(color: kSecondaryColor),
                      ),
                    ),
                    icon: primaryBusy
                        ? const SizedBox(
                            width: SparkSize.iconSm,
                            height: SparkSize.iconSm,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                kWhiteColor,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            size: SparkSize.iconSm,
                          ),
                    label: Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: SparkTextSize.label,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: SparkSpace.md),
                SizedBox(
                  height: SparkSize.actionHeight,
                  child: OutlinedButton.icon(
                    onPressed: secondaryDisabled ? null : onSecondaryTap,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                      ),
                      foregroundColor: kSecondaryColor,
                      backgroundColor: kInputBgColor,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: SparkSize.iconSm,
                    ),
                    label: Text(
                      secondaryLabel,
                      style: const TextStyle(
                        color: kSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: secondaryDisabled ? null : onSecondaryTap,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kBorderColor),
                    minimumSize: const Size.fromHeight(SparkSize.actionHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SparkRadius.lg),
                    ),
                    foregroundColor: kSecondaryColor,
                    backgroundColor: kInputBgColor,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    size: SparkSize.iconSm,
                  ),
                  label: Text(
                    secondaryLabel,
                    style: const TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: SizedBox(
                  height: SparkSize.actionHeight,
                  child: FilledButton.icon(
                    onPressed: (primaryDisabled || primaryBusy)
                        ? null
                        : onPrimaryTap,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: kSecondaryColor,
                      foregroundColor: kWhiteColor,
                      disabledBackgroundColor: kGreyColor.withValues(
                        alpha: 0.35,
                      ),
                      disabledForegroundColor: kWhiteColor.withValues(
                        alpha: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                        side: const BorderSide(color: kSecondaryColor),
                      ),
                    ),
                    icon: primaryBusy
                        ? const SizedBox(
                            width: SparkSize.iconSm,
                            height: SparkSize.iconSm,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                kWhiteColor,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            size: SparkSize.iconSm,
                          ),
                    label: Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: SparkTextSize.label,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SparkStatTile extends StatelessWidget {
  const SparkStatTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      radius: SparkRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.xl,
      ),
      child: Row(
        children: [
          Container(
            width: SparkSize.navStepBadge,
            height: SparkSize.navStepBadge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SparkRadius.sm),
              color: kSecondaryColor.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: SparkSize.iconSm, color: kSecondaryColor),
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: value,
                  size: SparkTextSize.title,
                  weight: FontWeight.w700,
                ),
                MyText(
                  text: title,
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SparkReportOverviewHeaderCard extends StatelessWidget {
  const SparkReportOverviewHeaderCard({
    super.key,
    required this.title,
    required this.meta,
    required this.draftStatusText,
    required this.draftStatusColor,
    required this.currentStepPrefix,
    required this.currentStepTitle,
  });

  final String title;
  final String meta;
  final String draftStatusText;
  final Color draftStatusColor;
  final String currentStepPrefix;
  final String currentStepTitle;

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      padding: const EdgeInsets.all(SparkSpace.section),
      radius: SparkRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: SparkSize.icon5xl,
                height: SparkSize.icon5xl,
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SparkRadius.sm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.description_outlined,
                  size: SparkSize.iconLg,
                  color: kSecondaryColor,
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: title,
                      size: SparkTextSize.title,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: SparkSpace.xxxs),
                    MyText(
                      text: meta,
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.lg),
          Wrap(
            spacing: SparkSpace.md,
            runSpacing: SparkSpace.sm,
            children: [
              SparkChip(
                text: draftStatusText,
                background: draftStatusColor.withValues(alpha: 0.12),
                color: draftStatusColor,
              ),
              SparkChip(
                text: '$currentStepPrefix: $currentStepTitle',
                background: kSecondaryColor.withValues(alpha: 0.08),
                color: kSecondaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SparkStepHeroCard extends StatelessWidget {
  const SparkStepHeroCard({
    super.key,
    required this.icon,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    required this.statusText,
    required this.statusColor,
    required this.stepProgress,
    this.description = '',
    this.currentValue = '',
    this.hideProgressBar = false,
  });

  final IconData icon;
  final int currentStep;
  final int totalSteps;
  final String title;
  final String description;
  final String statusText;
  final Color statusColor;
  final String currentValue;
  final bool hideProgressBar;
  final double stepProgress;

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.lg,
      ),
      radius: SparkRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: SparkSize.icon4xl,
                height: SparkSize.icon4xl,
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SparkRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: SparkSize.iconMd,
                  color: kSecondaryColor,
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: 'Шаг $currentStep/$totalSteps',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: title,
                      size: SparkTextSize.title,
                      weight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.sm),
              SparkChip(
                text: statusText,
                background: statusColor.withValues(alpha: 0.12),
                color: statusColor,
                textSize: SparkTextSize.caption,
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.sm,
                  vertical: SparkSpace.xxxs,
                ),
              ),
            ],
          ),
          if (!hideProgressBar) ...[
            const SizedBox(height: SparkSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.pill),
              child: LinearProgressIndicator(
                value: stepProgress.clamp(0.0, 1.0),
                minHeight: SparkSpace.sm,
                backgroundColor: kLightGreyColor,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  kSecondaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Строка раздела в группированной карточке обзора черновика.
///
/// Статус читается по ведущему кругу: зелёная галочка — раздел заполнен
/// полностью (все обязательные поля), многоточие — раздел начат, но не
/// завершён (галочку тут показывать нельзя: она прятала пустые обязательные
/// поля вроде пробега и города в «Автомобиле»), оранжевый «!» — обязательный
/// и пока пустой, пунктирный контур — необязательный и пустой. Правый край
/// дублирует статус словами («заполнить» / «продолжить» / «не обяз.»),
/// чтобы список читался без легенды.
class SparkSectionStatusRow extends StatelessWidget {
  const SparkSectionStatusRow({
    super.key,
    required this.title,
    required this.onTap,
    required this.fillState,
    this.description = '',
    this.required = false,
  });

  final String title;
  final VoidCallback onTap;
  final SparkJoySectionFillState fillState;
  final String description;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final isLoading = fillState == SparkJoySectionFillState.loading;
    final isDone = fillState == SparkJoySectionFillState.done;
    final isPartial = fillState == SparkJoySectionFillState.partial;
    final needsAction = required && !isDone && !isPartial && !isLoading;
    final dashed = !required && !isDone && !isPartial && !isLoading;

    final Color partialColor = required ? kOrangeColor : kGreyColor;
    final Widget? badgeChild = isLoading
        ? const SizedBox(
            width: SparkSize.iconSm,
            height: SparkSize.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(kGreyColor),
            ),
          )
        : isDone
        ? const Icon(
            Icons.check_rounded,
            size: SparkSize.iconSm,
            color: kGreenColor,
          )
        : isPartial
        ? Icon(
            Icons.more_horiz_rounded,
            size: SparkSize.iconSm,
            color: partialColor,
          )
        : needsAction
        ? const Icon(
            Icons.priority_high_rounded,
            size: SparkSize.iconSm,
            color: kOrangeColor,
          )
        : null;

    final Color? badgeBackground = isDone
        ? kGreenColor.withValues(alpha: 0.12)
        : isPartial
        ? partialColor.withValues(alpha: 0.12)
        : needsAction
        ? kOrangeColor.withValues(alpha: 0.12)
        : null;

    Widget statusBadge = Container(
      width: SparkSize.navStepBadge,
      height: SparkSize.navStepBadge,
      alignment: Alignment.center,
      decoration: badgeBackground == null
          ? null
          : BoxDecoration(shape: BoxShape.circle, color: badgeBackground),
      child: badgeChild,
    );
    if (dashed) {
      statusBadge = CustomPaint(
        painter: SparkDashedCirclePainter(
          color: kGreyColor.withValues(alpha: 0.5),
        ),
        child: statusBadge,
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SparkSpace.xl,
          vertical: SparkSpace.xl,
        ),
        child: Row(
          children: [
            statusBadge,
            const SizedBox(width: SparkSpace.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: title,
                    size: SparkTextSize.title,
                    weight: FontWeight.w700,
                    color: kTertiaryColor,
                  ),
                  if (description.trim().isNotEmpty) ...[
                    const SizedBox(height: SparkSpace.xxs),
                    MyText(
                      text: description.trim(),
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                      maxLines: 2,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (needsAction || (required && isPartial)) ...[
              const SizedBox(width: SparkSpace.md),
              MyText(
                text: needsAction ? 'заполнить' : 'продолжить',
                size: SparkTextSize.body,
                weight: FontWeight.w700,
                color: kOrangeColor,
              ),
            ] else if (!required) ...[
              const SizedBox(width: SparkSpace.md),
              const MyText(
                text: 'не обяз.',
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            ],
            const SizedBox(width: SparkSpace.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: kGreyColor,
              size: SparkSize.iconSm,
            ),
          ],
        ),
      ),
    );
  }
}

/// Волосяной разделитель между строками группированной карточки разделов —
/// левый отступ выравнивает его под текст (мимо статус-круга), как в
/// профильных экранах.
class SparkSectionRowDivider extends StatelessWidget {
  const SparkSectionRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: SparkSpace.xl + SparkSize.navStepBadge + SparkSpace.xl,
      ),
      height: SparkSpace.hairline,
      color: kBorderColor.withValues(alpha: 0.6),
    );
  }
}

/// Пунктирная окружность пустого необязательного раздела — «слот, который
/// можно и не занимать». Flutter не рисует пунктирный border из коробки,
/// поэтому штрихуем дугами по метрике пути.
/// Пунктирная окружность — «шаг ещё не начат». Живёт и в обзоре разделов
/// (`SparkSectionStatusRow`), и в списке «Материалов проверки» (проверка в
/// очереди), поэтому публичный.
class SparkDashedCirclePainter extends CustomPainter {
  const SparkDashedCirclePainter({required this.color});

  final Color color;

  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final circle = Path()
      ..addOval((Offset.zero & size).deflate(paint.strokeWidth));
    for (final metric in circle.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(SparkDashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class SparkSearchField extends StatelessWidget {
  const SparkSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: sparkInputDecoration(
        hint,
        dense: true,
        prefixIcon: const Icon(
          Icons.search,
          color: kGreyColor,
          size: SparkSize.iconMd,
        ),
      ),
    );
  }
}

class SparkLoadingState extends StatelessWidget {
  const SparkLoadingState({
    super.key,
    this.message,
    this.topPadding = SparkSize.stateTopLoading,
  });

  final String? message;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final text = (message ?? '').trim().isEmpty
        ? sjT('spark.state.loading', fallback: 'Загрузка...')
        : message!;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: SparkSize.spinnerLg,
              height: SparkSize.spinnerLg,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: SparkSpace.md),
            MyText(text: text, size: SparkTextSize.caption, color: kGreyColor),
          ],
        ),
      ),
    );
  }
}

class SparkEmptyState extends StatelessWidget {
  const SparkEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.topPadding = SparkSize.stateTopEmpty,
  });

  final IconData icon;
  final String title;

  /// Optional supporting line under the title. Omit on tight surfaces
  /// (e.g. picker dialogs) where a single-line empty state reads better.
  final String? subtitle;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final trimmedSubtitle = subtitle?.trim() ?? '';
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        children: [
          Icon(
            icon,
            size: SparkSize.iconState,
            color: kGreyColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: SparkSpace.md),
          MyText(
            text: title,
            size: SparkTextSize.label,
            weight: FontWeight.w700,
          ),
          if (trimmedSubtitle.isNotEmpty) ...[
            const SizedBox(height: SparkSpace.xxxs),
            MyText(
              text: trimmedSubtitle,
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ],
        ],
      ),
    );
  }
}

class SparkErrorState extends StatelessWidget {
  const SparkErrorState({
    super.key,
    required this.title,
    required this.subtitle,
    this.copyText,
    this.retryLabel,
    this.onRetry,
    this.topPadding = SparkSize.stateTopError,
  });

  final String title;
  final String subtitle;
  final String? copyText;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final actionLabel = (retryLabel ?? '').trim().isEmpty
        ? sjT('spark.action.retry', fallback: 'Повторить')
        : retryLabel!;
    final effectiveCopyText = (copyText ?? subtitle).trim();
    void copyErrorText() {
      if (effectiveCopyText.isEmpty) return;
      Clipboard.setData(ClipboardData(text: effectiveCopyText));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка скопирована')));
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: SparkCard(
        borderColor: kRedColor.withValues(alpha: 0.5),
        backgroundColor: kRedColor.withValues(alpha: 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: kRedColor,
                  size: SparkSize.iconMd,
                ),
                const SizedBox(width: SparkSpace.sm),
                Expanded(
                  child: MyText(
                    text: title,
                    size: SparkTextSize.label,
                    weight: FontWeight.w700,
                    color: kRedColor,
                  ),
                ),
                if (effectiveCopyText.isNotEmpty)
                  IconButton(
                    tooltip: 'Скопировать ошибку',
                    onPressed: copyErrorText,
                    icon: const Icon(Icons.copy_rounded),
                    color: kRedColor,
                    iconSize: SparkSize.iconSm,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: SparkSpace.xs),
            MyText(text: subtitle, size: SparkTextSize.body, color: kGreyColor),
            if (onRetry != null) ...[
              const SizedBox(height: SparkSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: SparkSize.actionHeight,
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: SparkSize.iconSm,
                        ),
                        label: Text(actionLabel),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kSecondaryColor,
                          side: const BorderSide(color: kBorderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SparkRadius.lg),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inherited inset propagation for the SparkJoy shell.
///
/// When the Scaffold uses `extendBodyBehindAppBar` / `extendBody`, tab content
/// needs extra padding so the first and last items sit under the AppBar and
/// BottomNav frosted surfaces without being clipped. The shell publishes these
/// insets here so any [SparkScreenList] or [SparkPageScaffold] descendant can
/// apply them without the tab knowing about the shell.
class SparkShellInsets extends InheritedWidget {
  const SparkShellInsets({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required super.child,
  });

  final double topInset;
  final double bottomInset;

  static SparkShellInsets? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SparkShellInsets>();

  @override
  bool updateShouldNotify(SparkShellInsets old) =>
      topInset != old.topInset || bottomInset != old.bottomInset;
}

class SparkScreenList extends StatelessWidget {
  const SparkScreenList({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.bottomInset = SparkSize.listBottomInset,
    this.onRefresh,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final double bottomInset;

  /// Optional pull-to-refresh handler. When non-null the ListView is wrapped
  /// in a [RefreshIndicator] so callers can trigger a reload from the top of
  /// the list without adding their own button.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final base = padding ?? AppSizes.DEFAULT;
    final shellInsets = SparkShellInsets.maybeOf(context);
    final shellTop = shellInsets?.topInset ?? 0;
    final shellBottom = shellInsets?.bottomInset ?? 0;
    final effectivePadding = base.copyWith(
      top: base.top + shellTop,
      bottom: base.bottom + media.padding.bottom + bottomInset + shellBottom,
    );

    Widget list = ListView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: effectivePadding,
      physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
      children: children,
    );
    if (onRefresh != null) {
      list = RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: shellTop,
        color: kSecondaryColor,
        child: list,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: list,
    );
  }
}

class SparkPageScaffold extends StatelessWidget {
  const SparkPageScaffold({
    super.key,
    this.appBar,
    required this.children,
    this.scrollController,
    this.padding,
    this.bottomInset = SparkSize.pageBottomInset,
    this.bottomBar,
  });

  final PreferredSizeWidget? appBar;
  final List<Widget> children;
  final ScrollController? scrollController;
  final EdgeInsets? padding;
  final double bottomInset;

  /// Закреплённая панель под списком (sticky CTA). Оборачивается в SafeArea —
  /// содержимому не нужно думать про home-индикатор iOS.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SparkScreenList(
        controller: scrollController,
        padding: padding,
        bottomInset: bottomInset,
        children: children,
      ),
      bottomNavigationBar:
          bottomBar == null ? null : SafeArea(top: false, child: bottomBar!),
    );
  }
}

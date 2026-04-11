import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
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
      return const Color(0xFFE8F1FF);
    case 'assigned':
      return const Color(0xFFEFEAFF);
    case 'in_progress':
      return const Color(0xFFFFF4D8);
    case 'completed':
      return const Color(0xFFE8F6EC);
    default:
      return kLightGreyColor;
  }
}

Color sparkAssignmentChipColor(String status) {
  switch (status) {
    case 'new':
      return const Color(0xFF245CBA);
    case 'assigned':
      return const Color(0xFF5A35C8);
    case 'in_progress':
      return const Color(0xFFA87300);
    case 'completed':
      return const Color(0xFF1C7C3D);
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

class SparkCard extends StatelessWidget {
  const SparkCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(SparkSpace.xl),
    this.backgroundColor = kWhiteColor,
    this.borderColor = kBorderColor,
    this.radius = SparkRadius.lg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
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
  });

  final Widget child;
  final VoidCallback? onTap;
  final double bottom;
  final EdgeInsets? padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;

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
        child: child,
      ),
    );
  }
}

class SparkInitialsAvatar extends StatelessWidget {
  const SparkInitialsAvatar({
    super.key,
    required this.name,
    this.size = SparkSize.avatarSm,
    this.textSize = SparkTextSize.label,
    this.backgroundColor,
    this.textColor = kSecondaryColor,
  });

  final String name;
  final double size;
  final double textSize;
  final Color? backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? kSecondaryColor.withValues(alpha: 0.1),
      ),
      alignment: Alignment.center,
      child: MyText(
        text: sjInitials(name),
        size: textSize,
        weight: FontWeight.w700,
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
  });

  final String text;
  final IconData? icon;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
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
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: SparkSpace.md),
      child: MyText(
        text: text,
        size: SparkTextSize.label,
        weight: FontWeight.w700,
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
  const SparkInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
            child: MyText(
              text: value,
              size: SparkTextSize.body,
              textAlign: TextAlign.right,
              weight: FontWeight.w600,
            ),
          ),
        ],
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
        onTap: onTap,
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
    return SparkCard(
      padding: const EdgeInsets.all(SparkSpace.sm),
      radius: SparkRadius.md,
      backgroundColor: kInputBgColor,
      child: Row(
        children: [
          for (int index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: SparkSpace.md),
            Expanded(
              child: _SparkSegmentedTabButton(
                item: items[index],
                active: value == items[index].value,
                onTap: () => onChanged(items[index].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparkSegmentedTabButton extends StatelessWidget {
  const _SparkSegmentedTabButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final SparkSegmentedTabItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.sm,
      ),
      radius: SparkRadius.md,
      borderColor: active
          ? kSecondaryColor.withValues(alpha: 0.45)
          : kBorderColor,
      backgroundColor: active
          ? kSecondaryColor.withValues(alpha: 0.08)
          : kWhiteColor,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SparkSelectableChip(
            text: item.label,
            selected: active,
            selectedColor: kSecondaryColor,
            onTap: onTap,
          ),
          if (item.count > 0) ...[
            const SizedBox(width: SparkSpace.sm),
            SparkChip(
              text: '${item.count}',
              background: active ? kSecondaryColor : kLightGreyColor,
              color: active ? kWhiteColor : kGreyColor,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.sm,
                vertical: SparkSpace.xxs,
              ),
            ),
          ],
        ],
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
          weight: FontWeight.w700,
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

class SparkReportEditorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SparkReportEditorAppBar({
    super.key,
    required this.title,
    required this.meta,
    required this.draftStatus,
    required this.draftStatusColor,
    required this.onBack,
    required this.showEditAction,
    this.onEdit,
  });

  final String title;
  final String meta;
  final String draftStatus;
  final Color draftStatusColor;
  final VoidCallback onBack;
  final bool showEditAction;
  final VoidCallback? onEdit;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(
            text: title,
            size: SparkTextSize.title,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.xxs),
          MyText(text: meta, size: SparkTextSize.body, color: kGreyColor),
          const SizedBox(height: SparkSpace.xxs),
          MyText(
            text: draftStatus,
            size: SparkTextSize.caption,
            color: draftStatusColor,
          ),
        ],
      ),
      actions: [
        if (showEditAction)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Переименовать',
          ),
      ],
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
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SparkSize.actionHeight,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kSecondaryColor,
          foregroundColor: kWhiteColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.lg),
            side: const BorderSide(color: kSecondaryColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xl),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(icon, color: kWhiteColor, size: SparkSize.iconLg),
              const SizedBox(width: SparkSpace.sm),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: SparkTextSize.label,
                fontWeight: FontWeight.w700,
                color: kWhiteColor,
              ),
            ),
          ],
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
  });

  final String secondaryLabel;
  final VoidCallback onSecondaryTap;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;
  final bool primaryDisabled;

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
                    onPressed: primaryDisabled ? null : onPrimaryTap,
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
                    icon: const Icon(
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
                    onPressed: onSecondaryTap,
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
                  onPressed: onSecondaryTap,
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
                    onPressed: primaryDisabled ? null : onPrimaryTap,
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
                    icon: const Icon(
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
      padding: const EdgeInsets.all(SparkSpace.section),
      radius: SparkRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: SparkSize.icon5xl,
                height: SparkSize.icon5xl,
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SparkRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
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
                      text: 'Шаг $currentStep из $totalSteps',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: SparkSpace.xxxs),
                    MyText(
                      text: title,
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w700,
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: SparkSpace.xxxs),
                      MyText(
                        text: description.trim(),
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.sm),
              SparkChip(
                text: statusText,
                background: statusColor.withValues(alpha: 0.12),
                color: statusColor,
              ),
            ],
          ),
          if (currentValue.isNotEmpty) ...[
            const SizedBox(height: SparkSpace.md),
            MyText(
              text: currentValue,
              size: SparkTextSize.caption,
              color: kSecondaryColor,
            ),
          ],
          if (!hideProgressBar) ...[
            const SizedBox(height: SparkSpace.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.pill),
              child: LinearProgressIndicator(
                value: stepProgress.clamp(0.0, 1.0),
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

class SparkProgressSummaryCard extends StatelessWidget {
  const SparkProgressSummaryCard({
    super.key,
    required this.completed,
    required this.total,
    required this.progress,
    this.label = 'Заполнено разделов',
  });

  final int completed;
  final int total;
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                size: SparkSize.iconSm,
                color: kSecondaryColor,
              ),
              const SizedBox(width: SparkSpace.sm),
              MyText(
                text: '$label: $completed из $total',
                size: SparkTextSize.body,
                color: kTertiaryColor,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(SparkRadius.pill),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: SparkSize.progress,
              backgroundColor: kLightGreyColor,
              valueColor: const AlwaysStoppedAnimation<Color>(kSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class SparkSectionNavCard extends StatelessWidget {
  const SparkSectionNavCard({
    super.key,
    required this.index,
    required this.title,
    required this.onTap,
    this.icon,
    this.description = '',
    this.value = '',
    this.done = false,
    this.isSummary = false,
  });

  final int index;
  final String title;
  final VoidCallback onTap;
  final IconData? icon;
  final String description;
  final String value;
  final bool done;
  final bool isSummary;

  @override
  Widget build(BuildContext context) {
    final statusText = done ? 'Заполнено' : 'Заполнить';
    final statusColor = done ? kGreenColor : kGreyColor;

    return SparkCard(
      onTap: onTap,
      radius: SparkRadius.lg,
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.xl,
      ),
      borderColor: done
          ? kSecondaryColor.withValues(alpha: 0.25)
          : kBorderColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: SparkSize.navStepBadge,
            height: SparkSize.navStepBadge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done
                  ? kSecondaryColor.withValues(alpha: 0.14)
                  : kLightGreyColor,
              border: Border.all(
                color: done
                    ? kSecondaryColor.withValues(alpha: 0.4)
                    : kBorderColor,
              ),
              borderRadius: BorderRadius.circular(SparkRadius.md),
            ),
            child: icon != null
                ? Icon(
                    icon,
                    size: SparkSize.iconSm,
                    color: done ? kSecondaryColor : kGreyColor,
                  )
                : MyText(
                    text: done ? '✓' : '${index + 1}',
                    size: SparkTextSize.body,
                    weight: FontWeight.w700,
                    color: done ? kSecondaryColor : kGreyColor,
                  ),
          ),
          if (icon != null) ...[
            const SizedBox(width: SparkSpace.sm),
            MyText(
              text: '${index + 1}',
              size: SparkTextSize.caption,
              color: kGreyColor,
              weight: FontWeight.w700,
            ),
          ],
          const SizedBox(width: SparkSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: title,
                        size: SparkTextSize.title,
                        weight: FontWeight.w700,
                        color: kTertiaryColor,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.sm),
                    SparkChip(
                      text: statusText,
                      background: statusColor.withValues(alpha: 0.11),
                      color: statusColor,
                      textSize: SparkTextSize.chip,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.sm,
                        vertical: SparkSpace.xxs,
                      ),
                    ),
                  ],
                ),
                MyText(
                  text: '#${index + 1}',
                  size: SparkTextSize.chip,
                  color: kGreyColor,
                ),
                if (value.trim().isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xxs),
                  MyText(
                    text: value.trim(),
                    size: SparkTextSize.caption,
                    color: kSecondaryColor,
                    maxLines: 2,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                ],
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
          const SizedBox(width: SparkSpace.sm),
          Container(
            width: SparkSize.iconXl,
            height: SparkSize.iconXl,
            decoration: BoxDecoration(
              color: kInputBgColor,
              borderRadius: BorderRadius.circular(SparkRadius.pill),
            ),
            child: Icon(
              isSummary ? Icons.done_rounded : Icons.chevron_right_rounded,
              color: isSummary ? kSecondaryColor : kGreyColor,
              size: SparkSize.iconSm,
            ),
          ),
        ],
      ),
    );
  }
}

class SparkSectionsOverview extends StatelessWidget {
  const SparkSectionsOverview({
    super.key,
    required this.completed,
    required this.total,
    required this.progress,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int completed;
  final int total;
  final double progress;
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: kBorderColor),
        const SizedBox(height: SparkSpace.xxxl),
        SparkCard(
          padding: const EdgeInsets.all(SparkSpace.section),
          child: SparkProgressSummaryCard(
            completed: completed,
            total: total,
            progress: progress,
          ),
        ),
        const SizedBox(height: SparkSpace.lg),
        ...List.generate(itemCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: SparkSpace.lg),
            child: itemBuilder(index),
          );
        }),
      ],
    );
  }
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
    required this.subtitle,
    this.topPadding = SparkSize.stateTopEmpty,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: SparkSpace.xxxs),
          MyText(
            text: subtitle,
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
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
    this.retryLabel,
    this.onRetry,
    this.topPadding = SparkSize.stateTopError,
  });

  final String title;
  final String subtitle;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final actionLabel = (retryLabel ?? '').trim().isEmpty
        ? sjT('spark.action.retry', fallback: 'Повторить')
        : retryLabel!;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: SparkCard(
        borderColor: kRedColor2.withValues(alpha: 0.5),
        backgroundColor: kRedColor2.withValues(alpha: 0.06),
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
              ],
            ),
            const SizedBox(height: SparkSpace.xs),
            MyText(text: subtitle, size: SparkTextSize.body, color: kGreyColor),
            if (onRetry != null) ...[
              const SizedBox(height: SparkSpace.xl),
              SizedBox(
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
            ],
          ],
        ),
      ),
    );
  }
}

class SparkScreenList extends StatelessWidget {
  const SparkScreenList({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.bottomInset = SparkSize.listBottomInset,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final base = padding ?? AppSizes.DEFAULT;
    final effectivePadding = base.copyWith(
      bottom: base.bottom + media.padding.bottom + bottomInset,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: effectivePadding,
        children: children,
      ),
    );
  }
}

class SparkPageScaffold extends StatelessWidget {
  const SparkPageScaffold({
    super.key,
    this.appBar,
    required this.children,
    this.padding,
    this.bottomInset = SparkSize.pageBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final List<Widget> children;
  final EdgeInsets? padding;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SparkScreenList(
        padding: padding,
        bottomInset: bottomInset,
        children: children,
      ),
    );
  }
}

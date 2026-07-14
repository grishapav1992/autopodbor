import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

enum AppBottomSheetExtent { content, expanded }

const appAdaptiveBottomSheetSurfaceKey = ValueKey<String>(
  'app-adaptive-bottom-sheet-surface',
);

/// Единый контейнер для модальных экранов, которые появляются снизу.
///
/// [AppBottomSheetExtent.expanded] заполняет почти всю доступную высоту и
/// предназначен для поиска и прокручиваемых списков. [content] занимает
/// высоту содержимого, но остаётся прижатым к нижнему краю.
Future<T?> showAppAdaptiveBottomSheet<T>({
  required BuildContext context,
  required AppBottomSheetExtent extent,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) {
      final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
      final sheet = _AppAdaptiveBottomSheetSurface(
        extent: extent,
        child: builder(sheetContext),
      );
      return AnimatedPadding(
        duration: SparkMotion.fast,
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: extent == AppBottomSheetExtent.expanded
            ? FractionallySizedBox(heightFactor: 0.96, child: sheet)
            : sheet,
      );
    },
  );
}

class _AppAdaptiveBottomSheetSurface extends StatelessWidget {
  const _AppAdaptiveBottomSheetSurface({
    required this.extent,
    required this.child,
  });

  final AppBottomSheetExtent extent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final expanded = extent == AppBottomSheetExtent.expanded;
    return Container(
      key: appAdaptiveBottomSheetSurfaceKey,
      width: double.infinity,
      constraints: expanded
          ? null
          : BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.90),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const _AppBottomSheetDragHandle(),
            if (expanded)
              Expanded(child: child)
            else
              Flexible(fit: FlexFit.loose, child: child),
          ],
        ),
      ),
    );
  }
}

/// Каноничная шапка bottom-sheet: `[← назад?] заголовок … [trailing?] [X]`.
///
/// Единый минимальный формат для всех шитов: заголовок слева, крестик с
/// рамкой справа. Размер/начертание заголовка зашиты — вызыватели не
/// переопределяют. Иконки-квадраты и подзаголовки в шапке не живут:
/// пояснения — это контент под шапкой.
class AppBottomSheetHeader extends StatelessWidget {
  const AppBottomSheetHeader({
    super.key,
    required this.title,
    this.onClose,
    this.onBack,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  final String title;

  /// Закрытие; по умолчанию `Navigator.pop()` без результата — семантика
  /// «отмена», как у свайпа вниз.
  final VoidCallback? onClose;

  /// Не-null включает ведущую стрелку «назад» (пикеры с drill-in).
  final VoidCallback? onBack;

  /// Необязательный слот между заголовком и крестиком.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              tooltip: 'Назад',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: SparkSpace.xs),
          ],
          Expanded(
            child: MyText(
              text: title,
              size: SparkTextSize.modalTitle,
              weight: FontWeight.w700,
              maxLines: 1,
              textOverflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: SparkSpace.xs),
          ],
          IconButton(
            tooltip: 'Закрыть',
            onPressed: onClose ?? () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              foregroundColor: kGreyColor,
              backgroundColor: kWhiteColor,
              side: const BorderSide(color: kBorderColor),
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _AppBottomSheetDragHandle extends StatelessWidget {
  const _AppBottomSheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SparkSpace.lg, bottom: SparkSpace.lg),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: kBorderColor,
          borderRadius: BorderRadius.circular(SparkRadius.pill),
        ),
      ),
    );
  }
}

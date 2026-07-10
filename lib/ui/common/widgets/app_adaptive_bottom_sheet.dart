import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';

enum AppBottomSheetExtent { content, expanded }

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
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: expanded
            ? null
            : BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.90,
              ),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SparkRadius.sheet),
          ),
        ),
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

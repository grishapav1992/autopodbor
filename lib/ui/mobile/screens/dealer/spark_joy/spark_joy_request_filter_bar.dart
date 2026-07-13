import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';

import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';

class SparkJoyRequestFilterBar extends StatefulWidget {
  const SparkJoyRequestFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.filters,
    this.onQueryChanged,
    this.searchHint = 'Номер, авто или специалист',
  });

  final RequestStatusFilter value;
  final ValueChanged<RequestStatusFilter> onChanged;
  final List<RequestStatusFilter>? filters;
  final ValueChanged<String>? onQueryChanged;
  final String searchHint;

  @override
  State<SparkJoyRequestFilterBar> createState() =>
      _SparkJoyRequestFilterBarState();
}

class _SparkJoyRequestFilterBarState extends State<SparkJoyRequestFilterBar> {
  final _searchController = TextEditingController();

  IconData _filterIcon(RequestStatusFilter filter) => switch (filter) {
    RequestStatusFilter.all => Icons.view_list_rounded,
    RequestStatusFilter.draft => Icons.edit_note_rounded,
    RequestStatusFilter.newRequests => Icons.fiber_new_rounded,
    RequestStatusFilter.inProgress => Icons.pending_actions_rounded,
    RequestStatusFilter.done => Icons.task_alt_rounded,
    RequestStatusFilter.canceled => Icons.block_rounded,
    RequestStatusFilter.failed => Icons.error_outline_rounded,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters(List<RequestStatusFilter> available) async {
    var pending = widget.value;
    final selected = await showAppAdaptiveBottomSheet<RequestStatusFilter>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xl,
              SparkSpace.xxs,
              SparkSpace.xl,
              SparkSpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kSecondaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(SparkRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.tune_rounded,
                        color: kSecondaryColor,
                        size: SparkSize.iconXl,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Фильтр заявок',
                            style: TextStyle(
                              fontSize: SparkTextSize.title,
                              fontWeight: FontWeight.w800,
                              color: kTertiaryColor,
                            ),
                          ),
                          SizedBox(height: SparkSpace.xxxs),
                          Text(
                            'Выберите статус для списка',
                            style: TextStyle(
                              fontSize: SparkTextSize.caption,
                              fontWeight: FontWeight.w500,
                              color: kGreyColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: IconButton.styleFrom(
                        foregroundColor: kGreyColor,
                        backgroundColor: kWhiteColor,
                        side: const BorderSide(color: kBorderColor),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.xl),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(SparkRadius.lg),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < available.length;
                        index++
                      ) ...[
                        if (index > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 58,
                            color: kBorderColor,
                          ),
                        _RequestStatusFilterRow(
                          key: ValueKey(
                            'request-filter-${available[index].name}',
                          ),
                          label: available[index].label,
                          icon: _filterIcon(available[index]),
                          selected: pending == available[index],
                          onTap: () =>
                              setSheetState(() => pending = available[index]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: SparkSpace.xl),
                Row(
                  children: [
                    TextButton(
                      onPressed: pending == RequestStatusFilter.all
                          ? null
                          : () => setSheetState(
                              () => pending = RequestStatusFilter.all,
                            ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(92, SparkSize.actionHeight),
                      ),
                      child: const Text('Сбросить'),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(pending),
                        style: FilledButton.styleFrom(
                          backgroundColor: kSecondaryColor,
                          foregroundColor: kWhiteColor,
                          minimumSize: const Size(
                            double.infinity,
                            SparkSize.actionHeight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SparkRadius.lg),
                          ),
                        ),
                        child: const Text(
                          'Применить',
                          style: TextStyle(
                            fontSize: SparkTextSize.body,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    if (selected != null && selected != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        widget.filters ??
        RequestStatusFilter.values
            .where((filter) => filter != RequestStatusFilter.draft)
            .toList(growable: false);
    final filterActive = widget.value != RequestStatusFilter.all;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: SparkSize.inputHeight,
            child: TextField(
              controller: _searchController,
              onChanged: widget.onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить поиск',
                        onPressed: () {
                          _searchController.clear();
                          widget.onQueryChanged?.call('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: kWhiteColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.lg,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.lg),
                  borderSide: const BorderSide(color: kBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.lg),
                  borderSide: const BorderSide(color: kBorderColor),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: SparkSpace.md),
        SizedBox(
          width: SparkSize.inputHeight,
          height: SparkSize.inputHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IconButton.filled(
                  tooltip: 'Фильтры заявок',
                  onPressed: () => _openFilters(available),
                  style: IconButton.styleFrom(
                    backgroundColor: filterActive
                        ? kSecondaryColor
                        : kWhiteColor,
                    foregroundColor: filterActive
                        ? kWhiteColor
                        : kSecondaryColor,
                    side: BorderSide(
                      color: filterActive ? kSecondaryColor : kBorderColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SparkRadius.lg),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
              if (filterActive)
                Positioned(
                  right: -SparkSpace.xxxs,
                  top: -SparkSpace.xxxs,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: kRedColor,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestStatusFilterRow extends StatelessWidget {
  const _RequestStatusFilterRow({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? kSecondaryColor.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.lg,
            vertical: SparkSpace.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  icon,
                  size: SparkSize.iconLg,
                  color: selected ? kSecondaryColor : kGreyColor,
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: SparkTextSize.body,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? kSecondaryColor : kTertiaryColor,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: SparkMotion.fast,
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kSecondaryColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? kSecondaryColor : kBorderColor,
                    width: selected ? 0 : 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: kWhiteColor,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

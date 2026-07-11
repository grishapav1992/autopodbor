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
  });

  final RequestStatusFilter value;
  final ValueChanged<RequestStatusFilter> onChanged;
  final List<RequestStatusFilter>? filters;
  final ValueChanged<String>? onQueryChanged;

  @override
  State<SparkJoyRequestFilterBar> createState() =>
      _SparkJoyRequestFilterBarState();
}

class _SparkJoyRequestFilterBarState extends State<SparkJoyRequestFilterBar> {
  final _searchController = TextEditingController();

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
              SparkSpace.md,
              SparkSpace.xl,
              SparkSpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Фильтры',
                        style: TextStyle(
                          fontSize: SparkTextSize.title,
                          fontWeight: FontWeight.w800,
                          color: kTertiaryColor,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(
                        () => pending = RequestStatusFilter.all,
                      ),
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.lg),
                const Text(
                  'СТАТУС',
                  style: TextStyle(
                    fontSize: SparkTextSize.caption,
                    fontWeight: FontWeight.w700,
                    color: kGreyColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: SparkSpace.md),
                Wrap(
                  spacing: SparkSpace.sm,
                  runSpacing: SparkSpace.sm,
                  children: [
                    for (final filter in available)
                      ChoiceChip(
                        selected: pending == filter,
                        onSelected: (_) =>
                            setSheetState(() => pending = filter),
                        avatar: pending == filter
                            ? const Icon(Icons.check_rounded, size: 18)
                            : null,
                        label: Text(filter.label),
                        showCheckmark: false,
                        selectedColor: kSecondaryColor,
                        backgroundColor: kWhiteColor,
                        side: BorderSide(
                          color: pending == filter
                              ? kSecondaryColor
                              : kBorderColor,
                        ),
                        labelStyle: TextStyle(
                          color: pending == filter
                              ? kWhiteColor
                              : kTertiaryColor,
                          fontSize: SparkTextSize.body,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            SparkRadius.pill,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SparkSpace.xxl),
                FilledButton(
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
                    'Показать заявки',
                    style: TextStyle(
                      fontSize: SparkTextSize.body,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                hintText: 'Номер, авто или специалист',
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

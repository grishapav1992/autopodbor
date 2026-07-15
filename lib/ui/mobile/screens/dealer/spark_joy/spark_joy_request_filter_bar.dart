import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available =
        widget.filters ??
        RequestStatusFilter.values
            .where((filter) => filter != RequestStatusFilter.draft)
            .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: SparkSize.inputHeight,
          child: TextField(
            controller: _searchController,
            onChanged: (query) {
              widget.onQueryChanged?.call(query);
              setState(() {});
            },
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
        const SizedBox(height: SparkSpace.lg),
        SizedBox(
          height: SparkSize.actionHeightMd,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Row(
              children: [
                for (var index = 0; index < available.length; index++) ...[
                  _RequestStatusFilterChip(
                    key: ValueKey('request-filter-${available[index].name}'),
                    label: available[index].label,
                    selected: widget.value == available[index],
                    onTap: () {
                      if (available[index] != widget.value) {
                        widget.onChanged(available[index]);
                      }
                    },
                  ),
                  if (index < available.length - 1)
                    const SizedBox(width: SparkSpace.md),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestStatusFilterChip extends StatelessWidget {
  const _RequestStatusFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? kSecondaryColor : kWhiteColor,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? kSecondaryColor : kBorderColor),
        ),
        animationDuration: SparkMotion.fast,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SparkSize.actionHeightMd,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xxl),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? kWhiteColor : kTertiaryColor,
                    fontSize: SparkTextSize.body,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

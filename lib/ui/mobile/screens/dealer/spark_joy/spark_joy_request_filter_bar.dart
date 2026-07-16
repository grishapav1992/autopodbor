import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';

import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';

class SparkJoyRequestFilterBar extends StatefulWidget {
  const SparkJoyRequestFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.onQueryChanged,
    this.searchHint = 'Номер, авто или специалист',
  });

  final RequestStatusFilter value;
  final ValueChanged<RequestStatusFilter> onChanged;
  final ValueChanged<String>? onQueryChanged;
  final String searchHint;

  @override
  State<SparkJoyRequestFilterBar> createState() =>
      _SparkJoyRequestFilterBarState();
}

class _SparkJoyRequestFilterBarState extends State<SparkJoyRequestFilterBar> {
  final _searchController = TextEditingController();
  final _pillKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openStatusMenu() async {
    // Меню поверх открытой клавиатуры прыгает по layout'у — прячем её заранее.
    FocusManager.instance.primaryFocus?.unfocus();
    final pillContext = _pillKey.currentContext;
    if (pillContext == null) return;
    final pillBox = pillContext.findRenderObject()! as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = pillBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final selected = await showMenu<RequestStatusFilter>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          origin.dx,
          origin.dy + pillBox.size.height + SparkSpace.xs,
          pillBox.size.width,
          pillBox.size.height,
        ),
        Offset.zero & overlayBox.size,
      ),
      color: kWhiteColor,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SparkRadius.lg),
        side: const BorderSide(color: kBorderColor),
      ),
      constraints: const BoxConstraints(minWidth: 200),
      items: [
        for (final filter in RequestStatusFilter.values)
          PopupMenuItem<RequestStatusFilter>(
            key: ValueKey('request-filter-${filter.name}'),
            value: filter,
            height: SparkSize.actionHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    filter.label,
                    style: TextStyle(
                      color: filter == widget.value
                          ? kSecondaryColor
                          : kTertiaryColor,
                      fontSize: SparkTextSize.bodyLg,
                      fontWeight: filter == widget.value
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (filter == widget.value)
                  const Icon(
                    Icons.check_rounded,
                    size: SparkSize.iconMd,
                    color: kSecondaryColor,
                  ),
              ],
            ),
          ),
      ],
    );
    if (selected != null && selected != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFiltered = widget.value != RequestStatusFilter.all;
    return SizedBox(
      height: SparkSize.inputHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
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
          const SizedBox(width: SparkSpace.md),
          Semantics(
            button: true,
            label: 'Фильтр по статусу: ${widget.value.label}',
            child: Material(
              key: _pillKey,
              color: isFiltered ? kSecondaryColor : kWhiteColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
                side: BorderSide(
                  color: isFiltered ? kSecondaryColor : kBorderColor,
                ),
              ),
              animationDuration: SparkMotion.fast,
              child: InkWell(
                key: const ValueKey('request-filter-pill'),
                onTap: _openStatusMenu,
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.lg),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.xl,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.value.label,
                        style: TextStyle(
                          color: isFiltered ? kWhiteColor : kTertiaryColor,
                          fontSize: SparkTextSize.body,
                          fontWeight: isFiltered
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: SparkSpace.xs),
                      Icon(
                        Icons.expand_more_rounded,
                        size: SparkSize.iconMd,
                        color: isFiltered ? kWhiteColor : kGreyColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

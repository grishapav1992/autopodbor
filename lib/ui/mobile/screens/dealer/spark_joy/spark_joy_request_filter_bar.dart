import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';

import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';

class SparkJoyRequestFilterBar extends StatelessWidget {
  const SparkJoyRequestFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.filters,
  });

  final RequestStatusFilter value;
  final ValueChanged<RequestStatusFilter> onChanged;
  final List<RequestStatusFilter>? filters;

  @override
  Widget build(BuildContext context) {
    final available =
        filters ??
        RequestStatusFilter.values
            .where((filter) => filter != RequestStatusFilter.draft)
            .toList(growable: false);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () async {
          final selected = await showModalBottomSheet<RequestStatusFilter>(
            context: context,
            backgroundColor: kWhiteColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(SparkRadius.lg),
              ),
            ),
            builder: (ctx) {
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: SparkSpace.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          SparkSpace.xl,
                          SparkSpace.md,
                          SparkSpace.xl,
                          SparkSpace.sm,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Фильтр заявок',
                            style: TextStyle(
                              fontSize: SparkTextSize.title,
                              fontWeight: FontWeight.w800,
                              color: kTertiaryColor,
                            ),
                          ),
                        ),
                      ),
                      for (final filter in available)
                        ListTile(
                          onTap: () => Navigator.of(ctx).pop(filter),
                          title: Text(filter.label),
                          trailing: value == filter
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: kSecondaryColor,
                                )
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              );
            },
          );
          if (selected != null && selected != value) {
            onChanged(selected);
          }
        },
        icon: const Icon(Icons.filter_list_rounded),
        label: Text(
          value == RequestStatusFilter.all ? 'Все заявки' : value.label,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: kTertiaryColor,
          backgroundColor: kWhiteColor,
          side: const BorderSide(color: kBorderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.lg),
          ),
          textStyle: const TextStyle(
            fontSize: SparkTextSize.body,
            fontWeight: FontWeight.w700,
          ),
          minimumSize: const Size(0, SparkSize.inputHeight),
          padding: const EdgeInsets.symmetric(horizontal: SparkSpace.lg),
        ),
      ),
    );
  }
}

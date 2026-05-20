import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';

import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';

class SparkJoyRequestFilterBar extends StatelessWidget {
  const SparkJoyRequestFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RequestStatusFilter value;
  final ValueChanged<RequestStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: RequestStatusFilter.values.map((filter) {
          final selected = value == filter;
          return Padding(
            padding: const EdgeInsets.only(right: SparkSpace.sm),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              onSelected: (_) => onChanged(filter),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                fontSize: SparkTextSize.caption,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? kWhiteColor : kGreyColor,
              ),
              selectedColor: kSecondaryColor,
              backgroundColor: kWhiteColor,
              side: BorderSide(
                color: selected ? kSecondaryColor : kBorderColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.pill),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

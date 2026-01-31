import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

import 'package:flutter/material.dart';

// ignore: must_be_immutable
class CustomDropDown extends StatefulWidget {
  CustomDropDown({
    super.key,
    required this.hint,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.bgColor,
    this.marginBottom,
    this.width,
    this.labelText,
    this.enableSearch = false,
    this.searchAltNames = const {},
    this.searchHint = '\u041d\u0430\u0439\u0442\u0438...',
    this.itemImages = const {},
  });

  final List<dynamic>? items;
  String selectedValue;
  final ValueChanged<dynamic>? onChanged;
  String hint;
  String? labelText;
  Color? bgColor;
  double? marginBottom, width;
  final bool enableSearch;
  final Map<String, String> searchAltNames;
  final String searchHint;
  final Map<String, String> itemImages;

  @override
  State<CustomDropDown> createState() => _CustomDropDownState();
}

class _CustomDropDownState extends State<CustomDropDown> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.marginBottom ?? 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.labelText != null)
            SizedBox(
              height: 16,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MyText(
                  text: widget.labelText ?? '',
                  size: 12,
                  weight: FontWeight.bold,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (widget.labelText != null) const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton2(
              items: widget.items!
                  .map(
                    (item) => DropdownMenuItem<dynamic>(
                      value: item,
                      child: _DropDownItem(
                        label: item.toString(),
                        imageUrl: widget.itemImages[item.toString()],
                      ),
                    ),
                  )
                  .toList(),
              value: widget.selectedValue,
              onChanged: widget.onChanged,
              iconStyleData: IconStyleData(icon: SizedBox()),
              isDense: true,
              isExpanded: false,
              dropdownSearchData: widget.enableSearch
                  ? DropdownSearchData(
                      searchController: _searchController,
                      searchInnerWidgetHeight: 52,
                      searchInnerWidget: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: widget.searchHint,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            filled: true,
                            fillColor: kWhiteColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: kBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: kSecondaryColor),
                            ),
                          ),
                        ),
                      ),
                      searchMatchFn: (item, searchValue) {
                        final raw = item.value?.toString() ?? '';
                        final q = searchValue.trim().toLowerCase();
                        if (q.isEmpty) return true;
                        if (raw.toLowerCase().contains(q)) {
                          return true;
                        }
                        final alt =
                            widget.searchAltNames[raw]?.toLowerCase() ?? '';
                        return alt.contains(q);
                      },
                    )
                  : null,
              onMenuStateChange: widget.enableSearch
                  ? (isOpen) {
                      if (!isOpen) _searchController.clear();
                    }
                  : null,
              customButton: Container(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: kWhiteColor,
                  border: Border.all(width: 1.0, color: kBorderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: MyText(
                        text: widget.selectedValue == widget.hint
                            ? widget.hint
                            : widget.selectedValue,
                        size: 12,
                        weight: FontWeight.w500,
                        color: widget.selectedValue == widget.hint
                            ? kHintColor
                            : kTertiaryColor,
                      ),
                    ),
                    RotatedBox(
                      quarterTurns: 1,
                      child: Image.asset(Assets.imagesArrowNext, height: 16),
                    ),
                  ],
                ),
              ),
              menuItemStyleData: MenuItemStyleData(height: 35),
              dropdownStyleData: DropdownStyleData(
                elevation: 6,
                maxHeight: 300,
                offset: Offset(0, -5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: kWhiteColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropDownItem extends StatelessWidget {
  const _DropDownItem({required this.label, this.imageUrl});

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Row(
      children: [
        if (url != null && url.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              url,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 28, height: 28, color: kBorderColor),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: MyText(text: label, size: 12)),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/services/city_repository.dart';

/// Modal bottom sheet for picking a city from the bundled RU+CIS list.
///
/// Returns the selected [City], or `null` if dismissed without choice.
/// The current value (e.g. what's already in the inspector's report
/// draft) is passed via [currentValue] purely so the sheet can show a
/// "out of list" warning banner — the picker itself never returns
/// the original string back; the caller decides what to do with the
/// pre-existing value if the user dismisses without selecting.
Future<City?> showCityPickerBottomSheet(
  BuildContext context, {
  String? currentValue,
}) {
  return showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: kPrimaryColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => _CityPickerSheet(currentValue: currentValue),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({this.currentValue});
  final String? currentValue;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  // Country chips. `null` for "Все" (no filter). Order: most-likely
  // home countries of inspectors first. Keep in sync with the
  // `_targetCountries` set in scripts/build_cities_dataset.dart.
  static const List<_CountryChip> _countries = [
    _CountryChip(code: null, label: 'Все'),
    _CountryChip(code: 'RU', label: 'Россия'),
    _CountryChip(code: 'BY', label: 'Беларусь'),
    _CountryChip(code: 'KZ', label: 'Казахстан'),
    _CountryChip(code: 'AM', label: 'Армения'),
    _CountryChip(code: 'AZ', label: 'Азербайджан'),
    _CountryChip(code: 'KG', label: 'Кыргызстан'),
    _CountryChip(code: 'MD', label: 'Молдова'),
    _CountryChip(code: 'TJ', label: 'Таджикистан'),
    _CountryChip(code: 'TM', label: 'Туркменистан'),
    _CountryChip(code: 'UZ', label: 'Узбекистан'),
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  String? _selectedCountry;
  String _query = '';
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    // Lazy load — first picker open pays the parse cost (~150ms on
    // mid-range Android), subsequent opens are instant.
    _initFuture = CityRepository.instance.init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Debounce search input to keep filter work off the keystroke
  /// thread. 80ms feels instant while still coalescing fast typing.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _selectCountry(String? code) {
    setState(() => _selectedCountry = code);
  }

  void _pickCity(City city) {
    Navigator.of(context).pop(city);
  }

  /// True iff the inspector already has a value typed but it doesn't
  /// match any city in the master list. Surfaces the orange warning
  /// banner so the user knows why the field is "broken" — without it,
  /// the picker would silently overwrite a value that downstream code
  /// might expect to remain the same.
  bool get _shouldShowOutOfListBanner {
    final v = widget.currentValue?.trim();
    if (v == null || v.isEmpty) return false;
    if (!CityRepository.instance.isReady) return false;
    return CityRepository.instance.findByExactRu(v) == null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewInsets = media.viewInsets.bottom;
    final maxHeight = media.size.height * 0.85;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDragHandle(),
            _buildHeader(),
            if (_shouldShowOutOfListBanner) _buildOutOfListBanner(),
            _buildSearchField(),
            _buildCountryChips(),
            const Divider(height: 1, color: kBorderColor),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: kBorderColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Выберите город',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kTertiaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildOutOfListBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Soft orange — non-error informational. Distinguishes from
        // hard validation errors (which use red elsewhere in spark_joy).
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0A800), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFB37700), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Текущее значение «${widget.currentValue}» отсутствует в '
              'списке. Выберите город заново.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7A4F00),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Поиск города',
          prefixIcon: const Icon(Icons.search, color: kTertiaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: kTertiaryColor),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kSecondaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _countries.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final c = _countries[i];
          final selected = _selectedCountry == c.code;
          return ChoiceChip(
            label: Text(c.label),
            selected: selected,
            onSelected: (_) => _selectCountry(c.code),
            labelStyle: TextStyle(
              color: selected ? Colors.white : kTertiaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: kSecondaryColor,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: selected ? kSecondaryColor : kBorderColor,
              ),
            ),
            // Compact paddings — fit ~3 chips on a 375px-wide screen.
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Не удалось загрузить список городов:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTertiaryColor),
              ),
            ),
          );
        }
        final results = CityRepository.instance.search(
          _query,
          countryCode: _selectedCountry,
          limit: 200,
        );
        if (results.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Город не найден.\nПопробуйте изменить запрос.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kTertiaryColor,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: results.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: kBorderColor),
          itemBuilder: (context, i) {
            final city = results[i];
            return ListTile(
              dense: false,
              // Single full-label line — "Россия, Краснодарский край,
              // Краснодар". Same string is what we write into the
              // controller on selection so the report and the picker
              // stay in sync.
              title: Text(
                city.displayLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTertiaryColor,
                  height: 1.3,
                ),
              ),
              onTap: () => _pickCity(city),
            );
          },
        );
      },
    );
  }
}

class _CountryChip {
  const _CountryChip({required this.code, required this.label});
  final String? code;
  final String label;
}

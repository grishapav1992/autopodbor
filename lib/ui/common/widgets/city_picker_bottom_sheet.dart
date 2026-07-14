import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/services/city_repository.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';

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
  return showAppAdaptiveBottomSheet<City>(
    context: context,
    extent: AppBottomSheetExtent.expanded,
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
  // Country-фильтр временно жёстко зафиксирован на Россию.
  // Раньше тут был chip-bar с 11 странами СНГ; продукт сузил скоуп
  // до РФ. Когда понадобится снова — вернуть chip-UI + dataset уже
  // содержит все страны (см. `scripts/build_cities_dataset.dart`).
  static const String _selectedCountry = 'RU';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
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
    return Column(
      children: [
        _buildHeader(),
        if (_shouldShowOutOfListBanner) _buildOutOfListBanner(),
        _buildSearchField(),
        const Divider(height: 1, color: kBorderColor),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildHeader() {
    return const AppBottomSheetHeader(
      title: 'Выберите город',
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB37700),
            size: 20,
          ),
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
        // No autofocus: opening the picker used to pop the keyboard at the
        // same time as the sheet, so the user saw «два окна» (sheet +
        // keyboard) and half the city list was hidden. The list is shown
        // immediately; the keyboard appears only when the user taps the
        // search field (B5).
        autofocus: false,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
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
            final region = city.distinctRegionRu;
            // Город — крупно, регион — серой подписью. Страну не
            // показываем: фильтр жёстко RU, «Россия, …» в каждой
            // строке было шумом. В контроллер вызывающие экраны пишут
            // `city.shortLabel` (регион остаётся только у одноимённых
            // городов вроде Мирного).
            return ListTile(
              dense: false,
              title: Text(
                city.displayNameRu,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kTertiaryColor,
                  height: 1.3,
                ),
              ),
              subtitle: region == null
                  ? null
                  : Text(
                      region,
                      style: const TextStyle(
                        fontSize: 12,
                        color: kGreyColor,
                        height: 1.2,
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

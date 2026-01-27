import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AutoRequestScreen extends StatefulWidget {
  const AutoRequestScreen({super.key});

  @override
  State<AutoRequestScreen> createState() => _AutoRequestScreenState();
}

class _AutoRequestScreenState extends State<AutoRequestScreen>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSizes.DEFAULT,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MyText(
                    text:
                        '\u0421\u043e\u0437\u0434\u0430\u043d\u0438\u0435 \u0437\u0430\u044f\u0432\u043a\u0438',
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: kWhiteColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: kSecondaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: kWhiteColor,
                      unselectedLabelColor: kSecondaryColor,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(
                          text: '\u041f\u043e \u0430\u0432\u0442\u043e',
                        ),
                        Tab(
                          text: '\u041f\u043e\u0434 \u043a\u043b\u044e\u0447',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                children: [
                  _ByCarForm(),
                  _TurnkeyForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ByCarForm extends StatelessWidget {
  const _ByCarForm();

  @override
  Widget build(BuildContext context) {
    return _ByCarFormBody();
  }
}

class _ByCarFormBody extends StatefulWidget {
  @override
  State<_ByCarFormBody> createState() => _ByCarFormBodyState();
}

class _ByCarFormBodyState extends State<_ByCarFormBody> {
  static const int _maxCars = 5;

  final List<_CarItem> _cars = [
    _CarItem(id: _genId()),
  ];

  final Map<String, bool> _collapsed = {};
  final Map<String, bool> _manualOpen = {};

  String _formError = '';
  final Map<String, Map<String, String>> _carErrors = {};

  @override
  void initState() {
    super.initState();
    _collapsed[_cars.first.id] = false;
  }

  static String _genId() {
    final n = DateTime.now().millisecondsSinceEpoch;
    return 'CAR-${n % 1000000}-${n % 97}';
  }

  static String _stripSpaces(String s) {
    return s.replaceAll(' ', '').trim();
  }

  static String _digitsOnly(String s) {
    final t = _stripSpaces(s);
    final buffer = StringBuffer();
    for (final ch in t.split('')) {
      if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  static String _safeUrlHost(String url) {
    try {
      return Uri.parse(url).host.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static bool _isAllowedListingUrl(String url) {
    final t = url.trim();
    if (t.isEmpty) return false;
    final host = _safeUrlHost(t);
    return host.isNotEmpty && _allowedListingDomains.contains(host);
  }

  static List<String> _getYearOptions(
    String make,
    String model,
    String restyling,
  ) {
    final years =
        _yearCatalog[make]?[model]?[restyling] ?? const <int>[];
    return years.map((y) => y.toString()).toList();
  }

  static bool _isCarEmpty(_CarItem c) {
    final fields = [
      c.sourceUrl.trim(),
      c.sellerPhone.trim(),
      c.plate?.trim() ?? '',
      c.vin?.trim() ?? '',
      c.note?.trim() ?? '',
      c.make.trim(),
      c.model.trim(),
      c.restyling.trim(),
      c.year.trim(),
    ];
    return fields.every((v) => v.isEmpty);
  }

  void _toggleCollapsed(String id) {
    setState(() {
      _collapsed[id] = !(_collapsed[id] ?? false);
    });
  }

  void _toggleManual(String id) {
    setState(() {
      _manualOpen[id] = !(_manualOpen[id] ?? false);
    });
  }

  void _addCar() {
    if (_cars.length >= _maxCars) return;
    setState(() {
      final id = _genId();
      _cars.add(_CarItem(id: id));
      _collapsed[id] = false;
    });
  }

  void _removeCar(String id) {
    setState(() {
      _cars.removeWhere((c) => c.id == id);
      _collapsed.remove(id);
      _manualOpen.remove(id);
      _carErrors.remove(id);
    });
  }

  void _setCarPatch(String id, _CarItemPatch patch) {
    setState(() {
      for (int i = 0; i < _cars.length; i++) {
        if (_cars[i].id != id) continue;
        final next = _cars[i].copyWith(patch);

        if (patch.plate != null) {
          final key = patch.plate!.trim();
          final hit = _plateLookup[key];
          if (hit != null) {
            _cars[i] = next.copyWith(
              _CarItemPatch(
                make: hit.make,
                model: hit.model,
                restyling: hit.restyling,
                year: hit.year,
                vin: hit.vin ?? next.vin,
              ),
            );
            return;
          }
        }

        if (patch.make != null) {
          _cars[i] = next.copyWith(
            _CarItemPatch(model: '', restyling: '', year: ''),
          );
          return;
        }
        if (patch.model != null) {
          _cars[i] = next.copyWith(_CarItemPatch(restyling: '', year: ''));
          return;
        }
        if (patch.restyling != null && patch.year == null) {
          final opts = _getYearOptions(
            next.make,
            next.model,
            next.restyling,
          );
          final latest = opts.isNotEmpty ? opts.last : '';
          _cars[i] = next.copyWith(_CarItemPatch(year: latest));
          return;
        }

        _cars[i] = next;
        return;
      }
    });
  }

  bool _validateCars() {
    _formError = '';
    _carErrors.clear();

    final activeCars = _cars.where((c) => !_isCarEmpty(c)).toList();
    if (activeCars.isEmpty) {
      _formError = '\u0414\u043E\u0431\u0430\u0432\u044C\u0442\u0435 \u0445\u043E\u0442\u044F \u0431\u044B \u043E\u0434\u0438\u043D \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C';
    }
    if (activeCars.length > _maxCars) {
      _formError = '\u041C\u043E\u0436\u043D\u043E \u0434\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u043D\u0435 \u0431\u043E\u043B\u0435\u0435 $_maxCars \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0435\u0439';
    }

    final List<String> toOpen = [];

    for (final c in _cars) {
      if (_isCarEmpty(c)) continue;
      final Map<String, String> ce = {};

      final url = c.sourceUrl.trim();
      final phoneDigits = _digitsOnly(c.sellerPhone);
      final hasPhone = phoneDigits.isNotEmpty;
      final hasUrl = url.isNotEmpty;

      if (!hasUrl && !hasPhone) {
        final manualComplete = c.make.trim().isNotEmpty &&
            c.model.trim().isNotEmpty &&
            c.restyling.trim().isNotEmpty &&
            c.year.trim().isNotEmpty;
        if (!manualComplete) {
          const msg =
              '\u041D\u0443\u0436\u043D\u0430 \u0441\u0441\u044B\u043B\u043A\u0430, \u0442\u0435\u043B\u0435\u0444\u043E\u043D \u043F\u0440\u043E\u0434\u0430\u0432\u0446\u0430 \u0438\u043B\u0438 \u0437\u0430\u043F\u043E\u043B\u043D\u0435\u043D\u043D\u044B\u0435 \u043F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0430\u0432\u0442\u043E';
          ce['sourceUrl'] = msg;
          ce['sellerPhone'] = msg;
          toOpen.add(c.id);
        }
      }

      if (hasUrl && !_isAllowedListingUrl(url)) {
        ce['sourceUrl'] = '\u0421\u0441\u044B\u043B\u043A\u0430 \u0434\u043E\u043B\u0436\u043D\u0430 \u0431\u044B\u0442\u044C \u0441 avito.ru, drom.ru \u0438\u043B\u0438 auto.ru';
      }

      if (hasPhone && phoneDigits.length < 11) {
        ce['sellerPhone'] = '\u0422\u0435\u043B\u0435\u0444\u043E\u043D \u0441\u043B\u0438\u0448\u043A\u043E\u043C \u043A\u043E\u0440\u043E\u0442\u043A\u0438\u0439';
      }

      final manualTouched = c.make.trim().isNotEmpty ||
          c.model.trim().isNotEmpty ||
          c.restyling.trim().isNotEmpty ||
          c.year.trim().isNotEmpty;

      if (manualTouched) {
        if (c.make.trim().isEmpty) ce['make'] = '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443';
        if (c.model.trim().isEmpty) ce['model'] = '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C';
        if (c.restyling.trim().isEmpty) {
          ce['restyling'] = '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435/\u043A\u0443\u0437\u043E\u0432';
        }
        if (c.year.trim().isEmpty) ce['year'] = '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434';
      }

      if (ce.isNotEmpty) _carErrors[c.id] = ce;
    }

    for (final id in toOpen) {
      _manualOpen[id] = true;
    }

    setState(() {});
    return _formError.isEmpty && _carErrors.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSizes.DEFAULT,
      children: [
        Row(
          children: [
            MyText(
              text: '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0438 (${_cars.length})',
              size: 16,
              weight: FontWeight.w700,
            ),
            const Spacer(),
            SizedBox(
              height: 40,
              child: MyButton(
                buttonText: '+ \u0414\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C',
                onTap: _addCar,
                textSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MyText(
          text: '\u041C\u0430\u043A\u0441\u0438\u043C\u0443\u043C $_maxCars \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0435\u0439 \u0432 \u043E\u0434\u043D\u043E\u0439 \u0437\u0430\u044F\u0432\u043A\u0435.',
          size: 12,
          color: _cars.length >= _maxCars ? kRedColor : kHintColor,
        ),
        if (_formError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: MyText(
              text: _formError,
              size: 12,
              color: kRedColor,
            ),
          ),
        const SizedBox(height: 12),
        for (int i = 0; i < _cars.length; i++)
          _CarCard(
            item: _cars[i],
            index: i,
            errors: _carErrors[_cars[i].id] ?? {},
            collapsed: _collapsed[_cars[i].id] ?? false,
            manualOpen: _manualOpen[_cars[i].id] ?? false,
            onToggle: () => _toggleCollapsed(_cars[i].id),
            onToggleManual: () => _toggleManual(_cars[i].id),
            onRemove: _cars.length > 1 ? () => _removeCar(_cars[i].id) : null,
            onChanged: (patch) => _setCarPatch(_cars[i].id, patch),
          ),
        const SizedBox(height: 8),
        MyButton(
          buttonText: '\u041E\u0442\u043F\u0440\u0430\u0432\u0438\u0442\u044C \u0437\u0430\u044F\u0432\u043A\u0443',
          onTap: _validateCars,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.item,
    required this.index,
    required this.errors,
    required this.collapsed,
    required this.manualOpen,
    required this.onToggle,
    required this.onToggleManual,
    required this.onChanged,
    required this.onRemove,
  });

  final _CarItem item;
  final int index;
  final Map<String, String> errors;
  final bool collapsed;
  final bool manualOpen;
  final VoidCallback onToggle;
  final VoidCallback onToggleManual;
  final ValueChanged<_CarItemPatch> onChanged;
  final VoidCallback? onRemove;

  String _headerTitle() {
    final link = item.sourceUrl.trim();
    if (link.isNotEmpty) return '\u0421\u0441\u044B\u043B\u043A\u0430: ${_shortListingLabel(link)}';
    final plate = item.plate?.trim() ?? '';
    if (plate.isNotEmpty) return '\u0413\u043E\u0441\u043D\u043E\u043C\u0435\u0440: $plate';
    if (item.make.isNotEmpty && item.model.isNotEmpty) {
      return '${item.make} ${item.model}'
          '${item.restyling.isNotEmpty ? ' ${item.restyling}' : ''}'
          '${item.year.isNotEmpty ? ' ${item.year}' : ''}';
    }
    return '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C \u2116${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final makes = (() {
      final list = _carCatalog.keys.toList();
      list.sort();
      return list;
    })();
    final models = item.make.isNotEmpty
        ? (() {
            final list = (_carCatalog[item.make] ?? {}).keys.toList();
            list.sort();
            return list;
          })()
        : <String>[];
    final restylings = item.make.isNotEmpty && item.model.isNotEmpty
        ? (_carCatalog[item.make]?[item.model] ?? <String>[])
        : <String>[];
    final years = _ByCarFormBodyState._getYearOptions(
      item.make,
      item.model,
      item.restyling,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: _headerTitle(),
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (onRemove != null)
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kRedColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: MyText(
                          text: '\u0423\u0434\u0430\u043B\u0438\u0442\u044C',
                          size: 11,
                          color: kRedColor,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: kSecondaryColor,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MyTextField(
                    labelText: '\u0421\u0441\u044B\u043B\u043A\u0430 \u043D\u0430 \u043E\u0431\u044A\u044F\u0432\u043B\u0435\u043D\u0438\u0435',
                    hintText: 'https://',
                    onChanged: (v) => onChanged(
                      _CarItemPatch(sourceUrl: v),
                    ),
                  ),
                  _ErrorText(text: errors['sourceUrl']),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onToggleManual,
                      child: Text(
                        manualOpen
                            ? '\u0421\u043A\u0440\u044B\u0442\u044C \u0434\u043E\u043F\u043E\u043B\u043D\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0435 \u043F\u043E\u043B\u044F'
                            : '\u041D\u0435\u0442 \u0441\u0441\u044B\u043B\u043A\u0438 \u2014 \u0432\u0432\u0435\u0441\u0442\u0438 \u0434\u0430\u043D\u043D\u044B\u0435',
                        style: const TextStyle(color: kSecondaryColor),
                      ),
                    ),
                  ),
                  if (manualOpen) ...[
                    MyTextField(
                      labelText: '\u0417\u0430\u043C\u0435\u0442\u043A\u0430',
                      hintText: '\u041D\u0430\u043F\u0440\u0438\u043C\u0435\u0440: \u0436\u0435\u043B\u0430\u0442\u0435\u043B\u044C\u043D\u043E \u0431\u0435\u0437 \u0414\u0422\u041F',
                      onChanged: (v) =>
                          onChanged(_CarItemPatch(note: v)),
                    ),
                    Row(
                        children: [
                        Expanded(
                          child: MyTextField(
                            labelText: '\u0413\u043E\u0441\u043D\u043E\u043C\u0435\u0440',
                            hintText: 'A123BC77',
                            marginBottom: 0,
                            onChanged: (v) =>
                                onChanged(_CarItemPatch(plate: v)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MyTextField(
                            labelText: 'VIN',
                            hintText: 'VIN',
                            marginBottom: 0,
                            onChanged: (v) =>
                                onChanged(_CarItemPatch(vin: v)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MyTextField(
                      labelText: '\u0422\u0435\u043B\u0435\u0444\u043E\u043D \u043F\u0440\u043E\u0434\u0430\u0432\u0446\u0430',
                      hintText: '+7',
                      inputFormatters: [_RuPhoneFormatter()],
                      onChanged: (v) =>
                          onChanged(_CarItemPatch(sellerPhone: v)),
                    ),
                    _ErrorText(text: errors['sellerPhone']),
                    const SizedBox(height: 6),
                    MyText(
                      text: '\u0414\u0430\u043D\u043D\u044B\u0435 \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044F (\u043E\u043F\u0446\u0438\u043E\u043D\u0430\u043B\u044C\u043D\u043E)',
                      size: 14,
                      weight: FontWeight.w700,
                      paddingBottom: 12,
                    ),
                    Row(
                        children: [
                        Expanded(
                          child: CustomDropDown(
                            hint: '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443',
                            labelText: '\u041C\u0430\u0440\u043A\u0430',
                            items: ['\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443', ...makes],
                            selectedValue: item.make.isEmpty
                                ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443'
                                : item.make,
                            onChanged: (value) {
                              final v =
                                  value == '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443' ? '' : value;
                              onChanged(_CarItemPatch(make: v));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomDropDown(
                            hint: '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C',
                            labelText: '\u041C\u043E\u0434\u0435\u043B\u044C',
                            items: [
                              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C',
                              ...models,
                            ],
                            selectedValue: item.model.isEmpty
                                ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C'
                                : item.model,
                            onChanged: (value) {
                              final v =
                                  value == '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C' ? '' : value;
                              onChanged(_CarItemPatch(model: v));
                            },
                          ),
                        ),
                      ],
                    ),
                    _ErrorText(text: errors['make']),
                    _ErrorText(text: errors['model']),
                    Row(
                        children: [
                        Expanded(
                          child: CustomDropDown(
                            hint: '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435',
                            labelText: '\u041F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435 / \u043A\u0443\u0437\u043E\u0432',
                            items: [
                              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435',
                              ...restylings,
                            ],
                            selectedValue: item.restyling.isEmpty
                                ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435'
                                : item.restyling,
                            onChanged: (value) {
                              final v = value == '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435'
                                  ? ''
                                  : value;
                              onChanged(_CarItemPatch(restyling: v));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomDropDown(
                            hint: '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434',
                            labelText: '\u0413\u043E\u0434',
                            items: ['\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434', ...years],
                            selectedValue: item.year.isEmpty
                                ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434'
                                : item.year,
                            onChanged: (value) {
                              final v =
                                  value == '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434' ? '' : value;
                              onChanged(_CarItemPatch(year: v));
                            },
                          ),
                        ),
                      ],
                    ),
                    _ErrorText(text: errors['restyling']),
                    _ErrorText(text: errors['year']),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: MyText(
        text: text!,
        size: 11,
        color: kRedColor,
      ),
    );
  }
}

class _CarItem {
  _CarItem({
    required this.id,
    this.make = '',
    this.model = '',
    this.restyling = '',
    this.year = '',
    this.vin = '',
    this.plate = '',
    this.sourceUrl = '',
    this.sellerPhone = '',
    this.note = '',
  });

  final String id;
  final String make;
  final String model;
  final String restyling;
  final String year;
  final String? vin;
  final String? plate;
  final String sourceUrl;
  final String sellerPhone;
  final String? note;

  int get index => id.hashCode;

  _CarItem copyWith(_CarItemPatch patch) {
    return _CarItem(
      id: id,
      make: patch.make ?? make,
      model: patch.model ?? model,
      restyling: patch.restyling ?? restyling,
      year: patch.year ?? year,
      vin: patch.vin ?? vin,
      plate: patch.plate ?? plate,
      sourceUrl: patch.sourceUrl ?? sourceUrl,
      sellerPhone: patch.sellerPhone ?? sellerPhone,
      note: patch.note ?? note,
    );
  }
}

class _CarItemPatch {
  _CarItemPatch({
    this.make,
    this.model,
    this.restyling,
    this.year,
    this.vin,
    this.plate,
    this.sourceUrl,
    this.sellerPhone,
    this.note,
  });

  final String? make;
  final String? model;
  final String? restyling;
  final String? year;
  final String? vin;
  final String? plate;
  final String? sourceUrl;
  final String? sellerPhone;
  final String? note;
}

class _PlateHit {
  const _PlateHit({
    required this.make,
    required this.model,
    required this.restyling,
    required this.year,
    this.vin,
  });

  final String make;
  final String model;
  final String restyling;
  final String year;
  final String? vin;
}

String _shortListingLabel(String url) {
  try {
    final u = Uri.parse(url);
    final parts = (u.path).split('/').where((e) => e.isNotEmpty).toList();
    final tail = parts.length >= 2
        ? '${parts[parts.length - 2]}/${parts.last}'
        : (parts.isNotEmpty ? parts.last : '');
    return '${u.host}${tail.isNotEmpty ? '/$tail' : ''}';
  } catch (_) {
    return url.length > 32 ? '${url.substring(0, 32)}\u2026' : url;
  }
}

const List<String> _allowedListingDomains = [
  'avito.ru',
  'www.avito.ru',
  'drom.ru',
  'www.drom.ru',
  'auto.ru',
  'www.auto.ru',
];

const Map<String, Map<String, List<String>>> _carCatalog = {
  'Toyota': {
    'Camry': ['XV40', 'XV50', 'XV70'],
    'Corolla': ['E150', 'E170', 'E210'],
    'RAV4': ['XA30', 'XA40', 'XA50'],
  },
  'Ford': {
    'Focus': ['Mk1', 'Mk2', 'Mk3', 'Mk4'],
    'Mondeo': ['Mk3', 'Mk4', 'Mk5'],
    'Kuga': ['I', 'II', 'III'],
  },
  'Volkswagen': {
    'Golf': ['Mk5', 'Mk6', 'Mk7', 'Mk8'],
    'Passat': ['B6', 'B7', 'B8'],
    'Tiguan': ['I', 'II'],
  },
};

const Map<String, Map<String, Map<String, List<int>>>> _yearCatalog = {
  'Toyota': {
    'Camry': {
      'XV40': [2006, 2007, 2008, 2009, 2010, 2011],
      'XV50': [2012, 2013, 2014, 2015, 2016, 2017],
      'XV70': [2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
    'Corolla': {
      'E150': [2007, 2008, 2009, 2010, 2011, 2012, 2013],
      'E170': [2014, 2015, 2016, 2017, 2018],
      'E210': [2019, 2020, 2021, 2022, 2023, 2024],
    },
    'RAV4': {
      'XA30': [2006, 2007, 2008, 2009, 2010, 2011, 2012],
      'XA40': [2013, 2014, 2015, 2016, 2017, 2018],
      'XA50': [2019, 2020, 2021, 2022, 2023, 2024],
    },
  },
  'Ford': {
    'Focus': {
      'Mk1': [1998, 1999, 2000, 2001, 2002, 2003, 2004],
      'Mk2': [2005, 2006, 2007, 2008, 2009, 2010, 2011],
      'Mk3': [2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018],
      'Mk4': [2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
    'Mondeo': {
      'Mk3': [2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007],
      'Mk4': [2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014],
      'Mk5': [2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021],
    },
    'Kuga': {
      'I': [2008, 2009, 2010, 2011, 2012],
      'II': [2013, 2014, 2015, 2016, 2017, 2018, 2019],
      'III': [2020, 2021, 2022, 2023, 2024],
    },
  },
  'Volkswagen': {
    'Golf': {
      'Mk5': [2003, 2004, 2005, 2006, 2007, 2008, 2009],
      'Mk6': [2008, 2009, 2010, 2011, 2012, 2013],
      'Mk7': [2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019],
      'Mk8': [2020, 2021, 2022, 2023, 2024],
    },
    'Passat': {
      'B6': [2005, 2006, 2007, 2008, 2009, 2010],
      'B7': [2010, 2011, 2012, 2013, 2014, 2015],
      'B8': [2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
    'Tiguan': {
      'I': [2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016],
      'II': [2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
  },
};

const Map<String, _PlateHit> _plateLookup = {
  'A123BC77': _PlateHit(
    make: 'Toyota',
    model: 'Camry',
    restyling: 'XV70',
    year: '2019',
    vin: 'JTNB11HK1K3000001',
  ),
  'K777KK77': _PlateHit(
    make: 'Volkswagen',
    model: 'Golf',
    restyling: 'Mk7',
    year: '2016',
    vin: 'WVWZZZ1KZGW000002',
  ),
  'M555MM77': _PlateHit(
    make: 'Ford',
    model: 'Focus',
    restyling: 'Mk3',
    year: '2015',
    vin: 'WF0AXXWPMAP000003',
  ),
};

class _TurnkeyForm extends StatefulWidget {
  @override
  State<_TurnkeyForm> createState() => _TurnkeyFormState();
}

class _TurnkeyFormState extends State<_TurnkeyForm> {
  List<String> _tkMakes = [];
  List<String> _tkModels = [];
  List<String> _tkRestylings = [];

  List<String> _allMakes() => _carCatalog.keys.toList()..sort();

  List<String> _allModelsForMakes(List<String> makes) {
    final set = <String>{};
    if (makes.isEmpty) {
      for (final mk in _carCatalog.keys) {
        set.addAll(_carCatalog[mk]!.keys);
      }
      return set.toList()..sort();
    }
    for (final mk in makes) {
      set.addAll(_carCatalog[mk]?.keys ?? const Iterable.empty());
    }
    return set.toList()..sort();
  }

  List<String> _allRestylingsForSelection(
    List<String> makes,
    List<String> models,
  ) {
    final set = <String>{};
    final targetMakes = makes.isEmpty ? _carCatalog.keys : makes;
    for (final mk in targetMakes) {
      final byModel = _carCatalog[mk] ?? {};
      final targetModels = models.isEmpty ? byModel.keys : models;
      for (final md in targetModels) {
        final gens = byModel[md] ?? const <String>[];
        set.addAll(gens);
      }
    }
    return set.toList()..sort();
  }

  void _setMakes(List<String> v) {
    final allowedModels = _allModelsForMakes(v);
    final nextModels =
        _tkModels.where((m) => allowedModels.contains(m)).toList();
    final allowedRest = _allRestylingsForSelection(v, nextModels);
    final nextRest =
        _tkRestylings.where((g) => allowedRest.contains(g)).toList();
    setState(() {
      _tkMakes = v;
      _tkModels = nextModels;
      _tkRestylings = nextRest;
    });
  }

  void _setModels(List<String> v) {
    final allowedRest = _allRestylingsForSelection(_tkMakes, v);
    final nextRest =
        _tkRestylings.where((g) => allowedRest.contains(g)).toList();
    setState(() {
      _tkModels = v;
      _tkRestylings = nextRest;
    });
  }

  void _setRestylings(List<String> v) {
    setState(() {
      _tkRestylings = v;
    });
  }

  Future<void> _openMultiSelect({
    required String title,
    required List<String> options,
    required List<String> initial,
    required ValueChanged<List<String>> onApply,
  }) async {
    final temp = List<String>.from(initial);
    String query = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final filtered = options.where((opt) {
              if (query.trim().isEmpty) return true;
              return opt.toLowerCase().contains(query.trim().toLowerCase());
            }).toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: title,
                            size: 16,
                            weight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (v) => setSheet(() => query = v),
                      decoration: InputDecoration(
                        hintText: '\u041d\u0430\u0439\u0442\u0438...',
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
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorderColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final checked = temp.contains(item);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setSheet(() {
                                if (v == true) {
                                  if (!temp.contains(item)) temp.add(item);
                                } else {
                                  temp.remove(item);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(item, style: const TextStyle(fontSize: 12)),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheet(() => temp.clear()),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: kSecondaryColor),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '\u0421\u0431\u0440\u043e\u0441\u0438\u0442\u044c',
                              style: TextStyle(color: kSecondaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              onApply(List<String>.from(temp));
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSecondaryColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '\u041f\u0440\u0438\u043c\u0435\u043d\u0438\u0442\u044c',
                              style: TextStyle(color: kWhiteColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSizes.DEFAULT,
      children: [
        MyText(
          text: '\u041f\u0430\u0440\u0430\u043c\u0435\u0442\u0440\u044b \u043f\u043e\u0434\u0431\u043e\u0440\u0430',
          size: 16,
          weight: FontWeight.w700,
          paddingBottom: 12,
        ),
        MyTextField(
          labelText: '\u0413\u043e\u0440\u043e\u0434',
          hintText:
              '\u041d\u0430\u043f\u0440\u0438\u043c\u0435\u0440, \u0410\u043b\u043c\u0430\u0442\u044b',
        ),
        Row(
          children: [
            Expanded(
              child: MyTextField(
                labelText:
                    '\u0411\u044e\u0434\u0436\u0435\u0442 \u043e\u0442',
                hintText: '2500000',
                marginBottom: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MyTextField(
                labelText:
                    '\u0411\u044e\u0434\u0436\u0435\u0442 \u0434\u043e',
                hintText: '3500000',
                marginBottom: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MultiSelectField(
                label: '\u041c\u0430\u0440\u043a\u0430',
                placeholder: '\u041b\u044e\u0431\u0430\u044f',
                value: _tkMakes,
                onTap: () => _openMultiSelect(
                  title: '\u041c\u0430\u0440\u043a\u0430',
                  options: _allMakes(),
                  initial: _tkMakes,
                  onApply: _setMakes,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MultiSelectField(
                label: '\u041c\u043e\u0434\u0435\u043b\u044c',
                placeholder: '\u041b\u044e\u0431\u0430\u044f',
                value: _tkModels,
                onTap: () => _openMultiSelect(
                  title: '\u041c\u043e\u0434\u0435\u043b\u044c',
                  options: _allModelsForMakes(_tkMakes),
                  initial: _tkModels,
                  onApply: _setModels,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MultiSelectField(
          label: '\u041f\u043e\u043a\u043e\u043b\u0435\u043d\u0438\u0435 / \u043a\u0443\u0437\u043e\u0432',
          placeholder: '\u041b\u044e\u0431\u043e\u0435',
          value: _tkRestylings,
          onTap: () => _openMultiSelect(
            title: '\u041f\u043e\u043a\u043e\u043b\u0435\u043d\u0438\u0435 / \u043a\u0443\u0437\u043e\u0432',
            options: _allRestylingsForSelection(_tkMakes, _tkModels),
            initial: _tkRestylings,
            onApply: _setRestylings,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MyTextField(
                labelText: '\u0413\u043e\u0434 \u043e\u0442',
                hintText: '2018',
                marginBottom: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MyTextField(
                labelText: '\u0413\u043e\u0434 \u0434\u043e',
                hintText: '2022',
                marginBottom: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MyTextField(
                labelText:
                    '\u041f\u0440\u043e\u0431\u0435\u0433 \u0434\u043e',
                hintText: '120000',
                marginBottom: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MyTextField(
                labelText:
                    '\u041a\u043e\u043b\u0438\u0447\u0435\u0441\u0442\u0432\u043e \u0432\u043b\u0430\u0434\u0435\u043b\u044c\u0446\u0435\u0432',
                hintText: '2',
                marginBottom: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MyTextField(
          labelText:
              '\u041e\u0431\u044f\u0437\u0430\u0442\u0435\u043b\u044c\u043d\u043e \u0434\u043e\u043b\u0436\u043d\u043e \u0431\u044b\u0442\u044c',
          hintText:
              '\u041e\u043f\u0446\u0438\u0438, \u0447\u0435\u0440\u0435\u0437 \u0437\u0430\u043f\u044f\u0442\u0443\u044e',
          maxLines: 3,
        ),
        MyTextField(
          labelText:
              '\u0427\u0435\u0433\u043e \u0438\u0437\u0431\u0435\u0433\u0430\u0442\u044c',
          hintText:
              '\u041e\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u044f, \u0442\u0430\u043a\u0441\u0438, \u0414\u0422\u041f',
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        MyButton(
          buttonText:
              '\u041e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c \u0437\u0430\u044f\u0432\u043a\u0443',
          onTap: () {},
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MultiSelectField extends StatelessWidget {
  const _MultiSelectField({
    required this.label,
    required this.placeholder,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String placeholder;
  final List<String> value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value.isEmpty
        ? placeholder
        : value.length <= 2
            ? value.join(', ')
            : '${value.take(2).join(', ')} +${value.length - 2}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          text: label,
          size: 14,
          weight: FontWeight.bold,
          paddingBottom: 6,
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      color: value.isEmpty ? kHintColor : kTertiaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.expand_more, size: 18, color: kGreyColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RuPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('8') || digits.startsWith('7')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    String take(int start, int length) {
      if (digits.length <= start) return '';
      final end = start + length;
      return digits.substring(start, end > digits.length ? digits.length : end);
    }

    final g1 = take(0, 3);
    final g2 = take(3, 3);
    final g3 = take(6, 2);
    final g4 = take(8, 2);

    var out = '+7';
    if (g1.isNotEmpty) out += g1;
    if (g2.isNotEmpty) out += '-$g2';
    if (g3.isNotEmpty) out += '-$g3';
    if (g4.isNotEmpty) out += '-$g4';

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

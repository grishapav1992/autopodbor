import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/constants/popular_cars_ru.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_field_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

bool _looksNumericCode(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^\d+$').hasMatch(trimmed);
}

List<Map<String, dynamic>> _sampleOffers(String requestId) {
  return [
    {
      'id': '$requestId-o1',
      'name': 'SelectCar',
      'company': 'SelectCar Pro',
      'rating': 4.9,
      'reviews': 204,
      'reports': 520,
      'successDeals': 458,
      'experienceYears': 8,
      'memberSince': '2019',
      'city': 'Москва',
      'responseHours': 2,
      'price': 42000,
      'days': 5,
      'photos': [
        'assets/car_hub/images/dm_image.png',
        'assets/car_hub/images/dummy_map.png',
        'assets/car_hub/images/no_image_found.png',
      ],
      'about':
          'Подбираю автомобили под ключ, специализация — немецкие и японские марки.',
      'extra': 'Работаю по договору, выезжаю на осмотры в день обращения.',
    },
    {
      'id': '$requestId-o2',
      'name': 'AutoExpert',
      'company': 'AutoExpert Team',
      'rating': 4.8,
      'reviews': 126,
      'reports': 312,
      'successDeals': 265,
      'experienceYears': 6,
      'memberSince': '2020',
      'city': 'Санкт-Петербург',
      'responseHours': 4,
      'price': 35000,
      'days': 7,
      'photos': [
        'assets/car_hub/images/dm_image.png',
        'assets/car_hub/images/events.png',
        'assets/car_hub/images/no_image_found.png',
      ],
      'about': 'Полный цикл подбора: поиск, торг, юридическая проверка.',
      'extra': 'Сопровождаю сделку и помогаю с оформлением.',
    },
    {
      'id': '$requestId-o3',
      'name': 'CheckAuto',
      'company': 'CheckAuto Lab',
      'rating': 4.7,
      'reviews': 88,
      'reports': 190,
      'successDeals': 143,
      'experienceYears': 5,
      'memberSince': '2021',
      'city': 'Казань',
      'responseHours': 6,
      'price': 28000,
      'days': 10,
      'photos': [
        'assets/car_hub/images/dm_image.png',
        'assets/car_hub/images/dummy_map.png',
        'assets/car_hub/images/no_image_found.png',
      ],
      'about': 'Проверяю техническое состояние и историю, даю подробный отчет.',
      'extra': 'Можно заказать отдельные проверки, если нужно ускориться.',
    },
  ];
}

void _showCreatedSnack(BuildContext context) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      backgroundColor: kSecondaryColor,
      duration: const Duration(seconds: 4),
      content: Row(
        children: const [
          Icon(Icons.check_circle, color: kWhiteColor, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Заявка создана. Предложения появятся в списке.',
              style: TextStyle(
                color: kWhiteColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RemoteCarCatalog {
  static final ValueNotifier<int> stamp = ValueNotifier<int>(0);
  static bool brandsLoading = false;
  static bool brandsFailed = false;
  static List<String> brandNames = [];
  static Map<String, String> brandRusByName = {};
  static Map<String, int> brandIdByName = {};
  static final Map<String, List<String>> modelsByMake = {};
  static final Map<String, int> modelIdByKey = {};
  static final Map<String, List<String>> restylingsByKey = {};
  static final Map<String, String> restylingPhotoByKey = {};
  static final Map<String, _RestylingMeta> restylingMetaByKey = {};
  static final Map<String, List<String>> yearsByKey = {};
  static final Map<String, bool> modelsLoading = {};
  static final Map<String, bool> restylingsLoading = {};

  static String _modelKey(int brandId, String model) {
    return '$brandId|$model';
  }

  static String _restylingKey(int brandId, String model, String restyling) {
    return '$brandId|$model|$restyling';
  }

  static Future<void> ensureBrands() async {
    if (brandsLoading || brandNames.isNotEmpty) return;
    brandsLoading = true;
    brandsFailed = false;
    stamp.value++;
    for (int i = 0; i < 2; i++) {
      try {
        final catalog = await StorageApi.fetchBrandCatalog();
        if (catalog.names.isNotEmpty) {
          brandNames = catalog.names;
          brandRusByName = catalog.rusByName;
          brandIdByName = catalog.idByName;
          break;
        }
      } catch (_) {
        if (i == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }
    if (brandNames.isEmpty) {
      brandsFailed = true;
    }
    brandsLoading = false;
    stamp.value++;
  }

  static Future<void> ensureModels(String make) async {
    if (make.isEmpty) return;
    if (modelsByMake.containsKey(make)) return;
    if (modelsLoading[make] == true) return;
    final brandId = brandIdByName[make];
    if (brandId == null) return;
    modelsLoading[make] = true;
    stamp.value++;
    try {
      final items = await StorageApi.fetchModels(brandId: brandId);
      final models = items.map((e) => e.model).toList();
      modelsByMake[make] = models;
      for (final item in items) {
        modelIdByKey[_modelKey(brandId, item.model)] = item.id;
      }
    } catch (_) {}
    modelsLoading[make] = false;
    stamp.value++;
  }

  static Future<void> ensureRestylings(String make, String model) async {
    if (make.isEmpty || model.isEmpty) return;
    final brandId = brandIdByName[make];
    if (brandId == null) return;
    final modelKey = _modelKey(brandId, model);
    final modelId = modelIdByKey[modelKey];
    if (modelId == null) return;
    if (restylingsByKey.containsKey(modelKey)) return;
    if (restylingsLoading[modelKey] == true) return;
    restylingsLoading[modelKey] = true;
    stamp.value++;
    try {
      final generations = await StorageApi.fetchGenerations(
        modelCarId: modelId,
      );
      final restylings = <String>{};
      final yearsByRestyling = <String, Set<int>>{};
      for (final gen in generations) {
        for (final rest in gen.restylings) {
          final label = rest.restyling.trim().isEmpty
              ? 'Без рестайлинга'
              : rest.restyling;
          restylings.add(label);
          restylingMetaByKey.putIfAbsent(
            _restylingKey(brandId, model, label),
            () => _RestylingMeta(
              generation: gen.generation,
              yearStart: rest.yearStart,
              yearEnd: rest.yearEnd,
              frames: rest.frames
                  .map((e) => e.frame.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList(),
            ),
          );
          if (rest.photos.isNotEmpty &&
              !restylingPhotoByKey.containsKey(
                _restylingKey(brandId, model, label),
              )) {
            final photo = rest.photos.firstWhere(
              (p) => p.size.toLowerCase() == 'm',
              orElse: () => rest.photos.first,
            );
            final url = photo.urlX1.isNotEmpty ? photo.urlX1 : photo.urlX2;
            if (url.isNotEmpty) {
              restylingPhotoByKey[_restylingKey(brandId, model, label)] = url;
            }
          }
          final start = rest.yearStart;
          final end = rest.yearEnd;
          if (start != null || end != null) {
            final y1 = start ?? end!;
            final y2 = end ?? start!;
            final from = y1 <= y2 ? y1 : y2;
            final to = y1 <= y2 ? y2 : y1;
            final set = yearsByRestyling.putIfAbsent(label, () => <int>{});
            for (int y = from; y <= to; y++) {
              set.add(y);
            }
          }
        }
      }
      restylingsByKey[modelKey] = restylings.toList()..sort();
      for (final entry in yearsByRestyling.entries) {
        final years = entry.value.toList()..sort();
        yearsByKey[_restylingKey(brandId, model, entry.key)] = years
            .map((e) => e.toString())
            .toList();
      }
    } catch (_) {}
    restylingsLoading[modelKey] = false;
    stamp.value++;
  }

  static List<String> makes() {
    if (brandNames.isNotEmpty) {
      return sortMakesByPopularity(brandNames);
    }
    if (brandsLoading && !brandsFailed) {
      return [];
    }
    return sortMakesByPopularity(_carCatalog.keys.toList());
  }

  static List<String> modelsFor(String make) {
    final remote = modelsByMake[make];
    if (remote != null && remote.isNotEmpty) {
      return sortModelsByPopularity(make, remote);
    }
    final local = _carCatalog[make];
    if (local != null) {
      return sortModelsByPopularity(make, local.keys.toList());
    }
    return [];
  }

  static List<String> restylingsFor(String make, String model) {
    final brandId = brandIdByName[make];
    if (brandId != null) {
      final key = _modelKey(brandId, model);
      final remote = restylingsByKey[key];
      if (remote != null && remote.isNotEmpty) {
        return remote;
      }
    }
    return _carCatalog[make]?[model] ?? <String>[];
  }

  static String restylingPhotoFor(String make, String model, String restyling) {
    final brandId = brandIdByName[make];
    if (brandId == null) return '';
    return restylingPhotoByKey[_restylingKey(brandId, model, restyling)] ?? '';
  }

  static _RestylingMeta? restylingMetaFor(
    String make,
    String model,
    String restyling,
  ) {
    final brandId = brandIdByName[make];
    if (brandId == null) return null;
    return restylingMetaByKey[_restylingKey(brandId, model, restyling)];
  }

  static List<String> yearsFor(String make, String model, String restyling) {
    final brandId = brandIdByName[make];
    if (brandId != null) {
      final key = _restylingKey(brandId, model, restyling);
      final remote = yearsByKey[key];
      if (remote != null && remote.isNotEmpty) {
        return remote;
      }
    }
    final years = _yearCatalog[make]?[model]?[restyling] ?? const <int>[];
    return years.map((e) => e.toString()).toList();
  }

  static bool isModelsLoading(String make) {
    return modelsLoading[make] == true;
  }

  static bool isRestylingsLoading(String make, String model) {
    final brandId = brandIdByName[make];
    if (brandId == null) return false;
    return restylingsLoading[_modelKey(brandId, model)] == true;
  }
}

class AutoRequestScreen extends StatefulWidget {
  const AutoRequestScreen({super.key});

  @override
  State<AutoRequestScreen> createState() => _AutoRequestScreenState();
}

class _AutoRequestScreenState extends State<AutoRequestScreen>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
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
                          Tab(text: '\u041f\u043e \u0430\u0432\u0442\u043e'),
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
                child: TabBarView(children: [_ByCarForm(), _TurnkeyForm()]),
              ),
            ],
          ),
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

  final List<_CarItem> _cars = [_CarItem(id: _genId())];

  final Map<String, bool> _collapsed = {};
  final Map<String, bool> _manualOpen = {};

  String _formError = '';
  final Map<String, Map<String, String>> _carErrors = {};

  @override
  void initState() {
    super.initState();
    _collapsed[_cars.first.id] = false;
    _RemoteCarCatalog.stamp.addListener(_handleRemoteUpdate);
    _RemoteCarCatalog.ensureBrands();
  }

  @override
  void dispose() {
    _RemoteCarCatalog.stamp.removeListener(_handleRemoteUpdate);
    super.dispose();
  }

  void _handleRemoteUpdate() {
    if (!mounted) return;
    setState(() {});
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

  List<String> _getYearOptions(String make, String model, String restyling) {
    return _RemoteCarCatalog.yearsFor(make, model, restyling);
  }

  String _restylingDisplayFor(String make, String model, String restyling) {
    if (restyling.trim().isEmpty) return '';
    final data = _buildRestylingCardDataFor(make, model, restyling);
    return data.title;
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
          final make = patch.make ?? '';
          if (make.isNotEmpty) {
            _RemoteCarCatalog.ensureModels(make);
          }
          return;
        }
        if (patch.model != null) {
          _cars[i] = next.copyWith(_CarItemPatch(restyling: '', year: ''));
          final make = next.make;
          final model = patch.model ?? '';
          if (make.isNotEmpty && model.isNotEmpty) {
            _RemoteCarCatalog.ensureRestylings(make, model);
          }
          return;
        }
        if (patch.restyling != null && patch.year == null) {
          final opts = _getYearOptions(next.make, next.model, next.restyling);
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
      _formError =
          '\u0414\u043E\u0431\u0430\u0432\u044C\u0442\u0435 \u0445\u043E\u0442\u044F \u0431\u044B \u043E\u0434\u0438\u043D \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C';
    }
    if (activeCars.length > _maxCars) {
      _formError =
          '\u041C\u043E\u0436\u043D\u043E \u0434\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u043D\u0435 \u0431\u043E\u043B\u0435\u0435 $_maxCars \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0435\u0439';
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
        const msg =
            '\u041d\u0443\u0436\u043d\u0430 \u0441\u0441\u044b\u043b\u043a\u0430 \u043d\u0430 \u043e\u0431\u044a\u044f\u0432\u043b\u0435\u043d\u0438\u0435 \u0438\u043b\u0438 \u0442\u0435\u043b\u0435\u0444\u043e\u043d \u043f\u0440\u043e\u0434\u0430\u0432\u0446\u0430';
        ce['sourceUrl'] = msg;
        ce['sellerPhone'] = msg;
        toOpen.add(c.id);
      }

      if (hasUrl && !_isAllowedListingUrl(url)) {
        ce['sourceUrl'] =
            '\u0421\u0441\u044B\u043B\u043A\u0430 \u0434\u043E\u043B\u0436\u043D\u0430 \u0431\u044B\u0442\u044C \u0441 avito.ru, drom.ru \u0438\u043B\u0438 auto.ru';
      }

      if (hasPhone && phoneDigits.length < 11) {
        ce['sellerPhone'] =
            '\u0422\u0435\u043B\u0435\u0444\u043E\u043D \u0441\u043B\u0438\u0448\u043A\u043E\u043C \u043A\u043E\u0440\u043E\u0442\u043A\u0438\u0439';
      }

      final manualTouched =
          c.make.trim().isNotEmpty ||
          c.model.trim().isNotEmpty ||
          c.restyling.trim().isNotEmpty ||
          c.year.trim().isNotEmpty;

      if (manualTouched) {
        if (c.make.trim().isEmpty)
          ce['make'] =
              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443';
        if (c.model.trim().isEmpty)
          ce['model'] =
              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C';
        if (c.restyling.trim().isEmpty) {
          ce['restyling'] =
              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435/\u043A\u0443\u0437\u043E\u0432';
        }
        if (c.year.trim().isEmpty)
          ce['year'] =
              '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434';
      }

      if (ce.isNotEmpty) _carErrors[c.id] = ce;
    }

    for (final id in toOpen) {
      _manualOpen[id] = true;
    }

    setState(() {});
    return _formError.isEmpty && _carErrors.isEmpty;
  }

  Future<void> _submitByCar() async {
    if (!_validateCars()) return;

    final activeCars = _cars.where((c) => !_isCarEmpty(c)).toList();
    if (activeCars.isEmpty) return;

    final now = DateTime.now();
    final id = 'REQ-${now.millisecondsSinceEpoch}';

    String carLabel(_CarItem car, int index) {
      final parts = [
        car.make.trim(),
        car.model.trim(),
        car.restyling.trim(),
        car.year.trim(),
      ].where((v) => v.isNotEmpty).toList();
      return parts.isEmpty ? 'Авто ${index + 1}' : parts.join(' ');
    }

    final carNames = <String>[];
    for (int i = 0; i < activeCars.length; i++) {
      carNames.add(carLabel(activeCars[i], i));
    }

    final title = activeCars.length == 1
        ? 'По авто: ${carNames.first}'
        : 'По авто: ${carNames.first} +${activeCars.length - 1}';
    final subtitle = 'Автомобилей: ${activeCars.length}';
    final carLine = carNames.join(', ');

    final carsPayload = activeCars.map((c) {
      return {
        'make': c.make.trim(),
        'model': c.model.trim(),
        'generation': c.restyling.trim(),
        'year': c.year.trim(),
        'sourceUrl': c.sourceUrl.trim(),
        'sellerPhone': c.sellerPhone.trim(),
        'plate': c.plate?.trim() ?? '',
        'vin': c.vin?.trim() ?? '',
        'note': c.note?.trim() ?? '',
      };
    }).toList();

    await UserSimplePreferences.addAutoRequest({
      'id': id,
      'requestNumber': (now.millisecondsSinceEpoch % 100000).toString(),
      'type': 'by_car',
      'title': title,
      'subtitle': subtitle,
      'carLine': carLine,
      'status': 'Создана',
      'createdAt': _formatDate(now),
      'cars': carsPayload,
      'offers': _sampleOffers(id),
      'selectedOfferId': null,
      'paidAt': null,
    });

    if (!mounted) return;
    _showCreatedSnack(context);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  List<String> _withHint(
    String hint,
    List<String> options,
    String selected, {
    bool loading = false,
  }) {
    final list = <String>[hint];
    if (options.isNotEmpty) {
      list.addAll(options);
    } else if (loading) {
      list.add('Загрузка...');
    }
    if (selected.isNotEmpty && !list.contains(selected)) {
      list.add(selected);
    }
    return list;
  }

  Future<void> _openRestylingPickerForCar(_CarItem car) async {
    if (car.make.trim().isEmpty || car.model.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите марку и модель')),
      );
      return;
    }

    _RemoteCarCatalog.ensureRestylings(car.make, car.model);
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
            final options = _RemoteCarCatalog.restylingsFor(
              car.make,
              car.model,
            );
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
                            text: 'Поколение',
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
                        hintText: 'Найти...',
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
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _RemoteCarCatalog.stamp,
                        builder: (ctx, _, __) {
                          if (filtered.isEmpty &&
                              _RemoteCarCatalog.isRestylingsLoading(
                                car.make,
                                car.model,
                              )) {
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          final items = filtered
                              .map(
                                (rest) => _buildRestylingCardDataFor(
                                  car.make,
                                  car.model,
                                  rest,
                                ),
                              )
                              .toList();
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.9,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final data = items[index];
                              final selected = car.restyling == data.value;
                              return _RestylingCard(
                                title: data.title,
                                subtitle: data.subtitle,
                                imageUrl: data.imageUrl,
                                selected: selected,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _setCarPatch(
                                    car.id,
                                    _CarItemPatch(restyling: data.value),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _setCarPatch(
                                car.id,
                                _CarItemPatch(restyling: ''),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: kSecondaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Сбросить',
                              style: TextStyle(color: kSecondaryColor),
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

  bool _looksNumericCode(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^\d+$').hasMatch(trimmed);
  }

  _RestylingCardData _buildRestylingCardDataFor(
    String make,
    String model,
    String rest,
  ) {
    final meta = _RemoteCarCatalog.restylingMetaFor(make, model, rest);
    final imageUrl = _RemoteCarCatalog.restylingPhotoFor(make, model, rest);
    final years = _formatYears(meta?.yearStart, meta?.yearEnd);
    final restLabel = rest == 'Без рестайлинга' ? '' : rest;
    final frames = meta?.frames ?? const <String>[];
    final codes = <String>{};
    for (final code in frames) {
      final trimmed = code.trim();
      if (trimmed.isNotEmpty) {
        codes.add(trimmed);
      }
    }
    if (restLabel.isNotEmpty &&
        !_looksNumericCode(restLabel) &&
        !codes.contains(restLabel)) {
      codes.add(restLabel);
    }
    final codesText = codes.isEmpty ? '' : codes.join(', ');
    final titleParts = <String>[];
    if (years.isNotEmpty) titleParts.add(years);
    if (codesText.isNotEmpty) titleParts.add(codesText);
    final title = titleParts.join(', ');

    String subtitle = '';
    if (meta != null && meta.generation > 0) {
      subtitle = 'Поколение ${meta.generation}';
      if (restLabel.isNotEmpty) {
        subtitle += ', рестайлинг';
      }
    } else if (restLabel.isNotEmpty) {
      subtitle = 'Рестайлинг';
    }

    return _RestylingCardData(
      value: rest,
      title: title.isEmpty ? rest : title,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  String _formatYears(int? start, int? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '$start - $end';
    }
    if (start != null) {
      return '$start - н.в.';
    }
    return 'до $end';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSizes.listPaddingWithBottomBar(),
      children: [
        Row(
          children: [
            MyText(
              text:
                  '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0438 (${_cars.length})',
              size: 16,
              weight: FontWeight.w700,
            ),
            const Spacer(),
            SizedBox(
              height: 40,
              child: MyButton(
                buttonText:
                    '+ \u0414\u043E\u0431\u0430\u0432\u0438\u0442\u044C \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C',
                onTap: _addCar,
                textSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MyText(
          text:
              '\u041C\u0430\u043A\u0441\u0438\u043C\u0443\u043C $_maxCars \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0435\u0439 \u0432 \u043E\u0434\u043D\u043E\u0439 \u0437\u0430\u044F\u0432\u043A\u0435.',
          size: 12,
          color: _cars.length >= _maxCars ? kRedColor : kHintColor,
        ),
        if (_formError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: MyText(text: _formError, size: 12, color: kRedColor),
          ),
        const SizedBox(height: 12),
        for (int i = 0; i < _cars.length; i++)
          _CarCard(
            item: _cars[i],
            index: i,
            errors: _carErrors[_cars[i].id] ?? {},
            collapsed: _collapsed[_cars[i].id] ?? false,
            manualOpen: _manualOpen[_cars[i].id] ?? false,
            makeOptions: _RemoteCarCatalog.makes(),
            modelOptions: _RemoteCarCatalog.modelsFor(_cars[i].make),
            restylingOptions: _RemoteCarCatalog.restylingsFor(
              _cars[i].make,
              _cars[i].model,
            ),
            restylingDisplay: _restylingDisplayFor(
              _cars[i].make,
              _cars[i].model,
              _cars[i].restyling,
            ),
            yearOptions: _getYearOptions(
              _cars[i].make,
              _cars[i].model,
              _cars[i].restyling,
            ),
            makeAltNames: _RemoteCarCatalog.brandRusByName,
            makeLoading: _RemoteCarCatalog.brandsLoading,
            modelLoading: _RemoteCarCatalog.isModelsLoading(_cars[i].make),
            restylingLoading: _RemoteCarCatalog.isRestylingsLoading(
              _cars[i].make,
              _cars[i].model,
            ),
            withHint: _withHint,
            onPickRestyling: () => _openRestylingPickerForCar(_cars[i]),
            onToggle: () => _toggleCollapsed(_cars[i].id),
            onToggleManual: () => _toggleManual(_cars[i].id),
            onRemove: _cars.length > 1 ? () => _removeCar(_cars[i].id) : null,
            onChanged: (patch) => _setCarPatch(_cars[i].id, patch),
          ),
        const SizedBox(height: 8),
        MyButton(
          buttonText:
              '\u041E\u0442\u043F\u0440\u0430\u0432\u0438\u0442\u044C \u0437\u0430\u044F\u0432\u043A\u0443',
          onTap: _submitByCar,
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
    required this.makeOptions,
    required this.modelOptions,
    required this.restylingOptions,
    required this.restylingDisplay,
    required this.yearOptions,
    required this.makeAltNames,
    required this.makeLoading,
    required this.modelLoading,
    required this.restylingLoading,
    required this.withHint,
    required this.onPickRestyling,
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
  final List<String> makeOptions;
  final List<String> modelOptions;
  final List<String> restylingOptions;
  final String restylingDisplay;
  final List<String> yearOptions;
  final Map<String, String> makeAltNames;
  final bool makeLoading;
  final bool modelLoading;
  final bool restylingLoading;
  final List<String> Function(
    String hint,
    List<String> options,
    String selected, {
    bool loading,
  })
  withHint;
  final VoidCallback onPickRestyling;
  final VoidCallback onToggle;
  final VoidCallback onToggleManual;
  final ValueChanged<_CarItemPatch> onChanged;
  final VoidCallback? onRemove;

  String _headerTitle() {
    final link = item.sourceUrl.trim();
    if (link.isNotEmpty)
      return '\u0421\u0441\u044B\u043B\u043A\u0430: ${_shortListingLabel(link)}';
    final plate = item.plate?.trim() ?? '';
    if (plate.isNotEmpty)
      return '\u0413\u043E\u0441\u043D\u043E\u043C\u0435\u0440: $plate';
    if (item.make.isNotEmpty && item.model.isNotEmpty) {
      return '${item.make} ${item.model}'
          '${restylingDisplay.isNotEmpty ? ' $restylingDisplay' : ''}'
          '${item.year.isNotEmpty ? ' ${item.year}' : ''}';
    }
    return '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C \u2116${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final makes = makeOptions;
    final models = modelOptions;
    final restylings = restylingOptions;
    final years = yearOptions;
    final makeItems = withHint(
      'Выберите марку',
      makes,
      item.make,
      loading: makeLoading,
    );
    final modelItems = withHint(
      'Выберите модель',
      models,
      item.model,
      loading: modelLoading,
    );
    final restylingItems = withHint(
      'Выберите поколение',
      restylings,
      item.restyling,
      loading: restylingLoading,
    );
    final yearItems = withHint('Выберите год', years, item.year);

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
                    labelText:
                        '\u0421\u0441\u044B\u043B\u043A\u0430 \u043D\u0430 \u043E\u0431\u044A\u044F\u0432\u043B\u0435\u043D\u0438\u0435',
                    hintText: 'https://',
                    onChanged: (v) => onChanged(_CarItemPatch(sourceUrl: v)),
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
                      hintText:
                          '\u041D\u0430\u043F\u0440\u0438\u043C\u0435\u0440: \u0436\u0435\u043B\u0430\u0442\u0435\u043B\u044C\u043D\u043E \u0431\u0435\u0437 \u0414\u0422\u041F',
                      onChanged: (v) => onChanged(_CarItemPatch(note: v)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: MyTextField(
                            labelText:
                                '\u0413\u043E\u0441\u043D\u043E\u043C\u0435\u0440',
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
                            onChanged: (v) => onChanged(_CarItemPatch(vin: v)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    MyTextField(
                      labelText:
                          '\u0422\u0435\u043B\u0435\u0444\u043E\u043D \u043F\u0440\u043E\u0434\u0430\u0432\u0446\u0430',
                      hintText: '+7',
                      inputFormatters: [_RuPhoneFormatter()],
                      onChanged: (v) =>
                          onChanged(_CarItemPatch(sellerPhone: v)),
                    ),
                    _ErrorText(text: errors['sellerPhone']),
                    const SizedBox(height: 6),
                    MyText(
                      text:
                          '\u0414\u0430\u043D\u043D\u044B\u0435 \u0430\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044F (\u043E\u043F\u0446\u0438\u043E\u043D\u0430\u043B\u044C\u043D\u043E)',
                      size: 14,
                      weight: FontWeight.w700,
                      paddingBottom: 12,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CustomDropDown(
                            hint:
                                '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443',
                            labelText: '\u041C\u0430\u0440\u043A\u0430',
                            items: makeItems,
                            selectedValue: item.make.isEmpty
                                ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443'
                                : item.make,
                            enableSearch: true,
                            searchAltNames: makeAltNames,
                            onChanged: makeLoading
                                ? null
                                : (value) {
                                    final v =
                                        value ==
                                            '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443'
                                        ? ''
                                        : value;
                                    onChanged(_CarItemPatch(make: v));
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomDropDown(
                            hint:
                                '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C',
                            labelText: '\u041C\u043E\u0434\u0435\u043B\u044C',
                            items: modelItems,
                            selectedValue: item.model.isEmpty
                                ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C'
                                : item.model,
                            enableSearch: true,
                            onChanged: modelLoading
                                ? null
                                : (value) {
                                    final v =
                                        value ==
                                            '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C'
                                        ? ''
                                        : value;
                                    onChanged(_CarItemPatch(model: v));
                                  },
                          ),
                        ),
                      ],
                    ),
                    _ErrorText(text: errors['make']),
                    _ErrorText(text: errors['model']),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SelectField(
                            label:
                                '\u041F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435 / \u043A\u0443\u0437\u043E\u0432',
                            placeholder: 'Выберите поколение',
                            value: restylingDisplay.isEmpty
                                ? item.restyling
                                : restylingDisplay,
                            enabled:
                                item.make.isNotEmpty &&
                                item.model.isNotEmpty &&
                                !restylingLoading,
                            loading: restylingLoading,
                            onTap: onPickRestyling,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomDropDown(
                            hint:
                                '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434',
                            labelText: '\u0413\u043E\u0434',
                            items: yearItems,
                            selectedValue: item.year.isEmpty
                                ? '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434'
                                : item.year,
                            onChanged: (value) {
                              final v =
                                  value ==
                                      '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043E\u0434'
                                  ? ''
                                  : value;
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
      child: MyText(text: text!, size: 11, color: kRedColor),
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

  @override
  void initState() {
    super.initState();
    _RemoteCarCatalog.stamp.addListener(_handleRemoteUpdate);
    _RemoteCarCatalog.ensureBrands();
  }

  @override
  void dispose() {
    _RemoteCarCatalog.stamp.removeListener(_handleRemoteUpdate);
    super.dispose();
  }

  void _handleRemoteUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  List<String> _allMakes() => _RemoteCarCatalog.makes();

  List<String> _allModelsForMakes(List<String> makes) {
    final set = <String>{};
    if (makes.isEmpty) {
      for (final mk in _carCatalog.keys) {
        set.addAll(_carCatalog[mk]!.keys);
      }
      return sortModelsByPopularityForMakes(makes, set.toList());
    }
    for (final mk in makes) {
      final remote = _RemoteCarCatalog.modelsFor(mk);
      if (remote.isNotEmpty) {
        set.addAll(remote);
      } else {
        set.addAll(_carCatalog[mk]?.keys ?? const Iterable.empty());
      }
    }
    return sortModelsByPopularityForMakes(makes, set.toList());
  }

  List<String> _allRestylingsForSelection(
    List<String> makes,
    List<String> models,
  ) {
    final set = <String>{};
    final targetMakes = makes.isEmpty ? _carCatalog.keys : makes;
    for (final mk in targetMakes) {
      final byModel = _carCatalog[mk] ?? {};
      final knownModels = _RemoteCarCatalog.modelsFor(mk);
      final availableModels = knownModels.isNotEmpty
          ? knownModels
          : byModel.keys.toList();
      final targetModels = models.isEmpty
          ? availableModels
          : models.where((m) => availableModels.contains(m));
      for (final md in targetModels) {
        final remote = _RemoteCarCatalog.restylingsFor(mk, md);
        final restList = remote.isNotEmpty
            ? remote
            : (byModel[md] ?? const <String>[]);
        for (final rest in restList) {
          set.add('$mk|$md|$rest');
        }
        _RemoteCarCatalog.ensureRestylings(mk, md);
      }
    }
    return set.toList()..sort();
  }

  void _setMakes(List<String> v) {
    final allowedModels = _allModelsForMakes(v);
    final nextModels = _tkModels
        .where((m) => allowedModels.contains(m))
        .toList();
    final allowedRest = _allRestylingsForSelection(v, nextModels);
    final nextRest = _tkRestylings
        .where((g) => allowedRest.contains(g))
        .toList();
    setState(() {
      _tkMakes = v;
      _tkModels = nextModels;
      _tkRestylings = nextRest;
    });
    for (final mk in v) {
      _RemoteCarCatalog.ensureModels(mk);
    }
  }

  void _setModels(List<String> v) {
    final allowedRest = _allRestylingsForSelection(_tkMakes, v);
    final nextRest = _tkRestylings
        .where((g) => allowedRest.contains(g))
        .toList();
    setState(() {
      _tkModels = v;
      _tkRestylings = nextRest;
    });
    for (final mk in _tkMakes) {
      for (final md in v) {
        _RemoteCarCatalog.ensureRestylings(mk, md);
      }
    }
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
                            title: Text(
                              item,
                              style: const TextStyle(fontSize: 12),
                            ),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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

  Future<void> _openRestylingPicker() async {
    final temp = List<String>.from(_tkRestylings);
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
                            text: 'Поколение',
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
                        hintText: 'Найти...',
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
                    Expanded(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _RemoteCarCatalog.stamp,
                        builder: (ctx, _, __) {
                          final options = _allRestylingsForSelection(
                            _tkMakes,
                            _tkModels,
                          );
                          final filtered = options.where((opt) {
                            if (query.trim().isEmpty) return true;
                            return opt.toLowerCase().contains(
                              query.trim().toLowerCase(),
                            );
                          }).toList();

                          final items = filtered
                              .map((rest) => _buildRestylingCardData(rest))
                              .toList();

                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.9,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final data = items[index];
                              final selected = temp.contains(data.value);
                              return _RestylingCard(
                                title: data.title,
                                subtitle: data.subtitle,
                                imageUrl: data.imageUrl,
                                selected: selected,
                                onTap: () {
                                  setSheet(() {
                                    if (selected) {
                                      temp.remove(data.value);
                                    } else {
                                      temp.add(data.value);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheet(() => temp.clear()),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: kSecondaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Сбросить',
                              style: TextStyle(color: kSecondaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _setRestylings(List<String>.from(temp));
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSecondaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Применить',
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

  _RestylingCardData _buildRestylingCardData(String rest) {
    String make = '';
    String model = '';
    String restName = rest;
    if (rest.contains('|')) {
      final parts = rest.split('|');
      if (parts.length >= 3) {
        make = parts[0];
        model = parts[1];
        restName = parts.sublist(2).join('|');
      }
    }

    _RestylingMeta? meta;
    String imageUrl = '';

    if (make.isNotEmpty && model.isNotEmpty) {
      meta = _RemoteCarCatalog.restylingMetaFor(make, model, restName);
      imageUrl = _RemoteCarCatalog.restylingPhotoFor(make, model, restName);
    } else {
      final makes = _tkMakes.isNotEmpty ? _tkMakes : _carCatalog.keys.toList();
      final models = _tkModels;
      for (final mk in makes) {
        final modelList = models.isNotEmpty
            ? models
            : (_carCatalog[mk]?.keys.toList() ?? const <String>[]);
        for (final md in modelList) {
          meta ??= _RemoteCarCatalog.restylingMetaFor(mk, md, restName);
          if (imageUrl.isEmpty) {
            imageUrl = _RemoteCarCatalog.restylingPhotoFor(mk, md, restName);
          }
          if (meta != null && imageUrl.isNotEmpty) break;
        }
        if (meta != null && imageUrl.isNotEmpty) break;
      }
    }

    final years = _formatYears(meta?.yearStart, meta?.yearEnd);
    final restLabel = restName == 'Без рестайлинга' ? '' : restName;
    final frames = meta?.frames ?? const <String>[];
    final codes = <String>{};
    for (final code in frames) {
      final trimmed = code.trim();
      if (trimmed.isNotEmpty) {
        codes.add(trimmed);
      }
    }
    if (restLabel.isNotEmpty &&
        !_looksNumericCode(restLabel) &&
        !codes.contains(restLabel)) {
      codes.add(restLabel);
    }
    final codesText = codes.isEmpty ? '' : codes.join(', ');
    final titleParts = <String>[];
    if (years.isNotEmpty) titleParts.add(years);
    if (codesText.isNotEmpty) titleParts.add(codesText);
    final title = titleParts.join(', ');

    String subtitle = '';
    if (meta != null && meta.generation > 0) {
      subtitle = 'Поколение ${meta.generation}';
      if (restLabel.isNotEmpty) {
        subtitle += ', рестайлинг';
      }
    } else if (restLabel.isNotEmpty) {
      subtitle = 'Рестайлинг';
    }

    return _RestylingCardData(
      value: rest,
      title: title.isEmpty ? restName : title,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  String _formatYears(int? start, int? end) {
    if (start == null && end == null) return '';
    if (start != null && end != null) {
      return '$start - $end';
    }
    if (start != null) {
      return '$start - н.в.';
    }
    return 'до $end';
  }

  List<String> _restylingDisplayList(List<String> restylings) {
    return restylings
        .map((rest) => _buildRestylingCardData(rest).title)
        .where((v) => v.trim().isNotEmpty)
        .toList();
  }

  Future<void> _submitTurnkey() async {
    final now = DateTime.now();
    final id = 'REQ-${now.millisecondsSinceEpoch}';
    final makes = List<String>.from(_tkMakes);
    final models = List<String>.from(_tkModels);
    final restylings = List<String>.from(_tkRestylings);
    final restylingDisplay = _restylingDisplayList(restylings);

    final titleParts = <String>[];
    if (makes.isNotEmpty) titleParts.add(makes.join(', '));
    if (models.isNotEmpty) titleParts.add(models.join(', '));
    final title = titleParts.isEmpty
        ? 'Под ключ: подбор автомобиля'
        : 'Под ключ: ${titleParts.join(' ')}';

    final subtitleParts = <String>[];
    if (makes.isNotEmpty) subtitleParts.add('Марки: ${makes.join(', ')}');
    if (models.isNotEmpty) subtitleParts.add('Модели: ${models.join(', ')}');
    final subtitle = subtitleParts.join(' · ');
    final carLine = restylings.isNotEmpty
        ? 'Поколения: ${restylings.join(', ')}'
        : '';

    await UserSimplePreferences.addAutoRequest({
      'id': id,
      'requestNumber': (now.millisecondsSinceEpoch % 100000).toString(),
      'type': 'turnkey',
      'title': title,
      'subtitle': subtitle,
      'carLine': carLine,
      'status': 'Создана',
      'createdAt': _formatDate(now),
      'makes': makes,
      'models': models,
      'restylings': restylingDisplay,
      'offers': _sampleOffers(id),
      'selectedOfferId': null,
      'paidAt': null,
    });

    if (!mounted) return;
    _showCreatedSnack(context);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSizes.listPaddingWithBottomBar(),
      children: [
        MyText(
          text:
              '\u041f\u0430\u0440\u0430\u043c\u0435\u0442\u0440\u044b \u043f\u043e\u0434\u0431\u043e\u0440\u0430',
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
                labelText: '\u0411\u044e\u0434\u0436\u0435\u0442 \u043e\u0442',
                hintText: '2500000',
                marginBottom: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MyTextField(
                labelText: '\u0411\u044e\u0434\u0436\u0435\u0442 \u0434\u043e',
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
          label:
              '\u041f\u043e\u043a\u043e\u043b\u0435\u043d\u0438\u0435 / \u043a\u0443\u0437\u043e\u0432',
          placeholder: '\u041b\u044e\u0431\u043e\u0435',
          value: _tkRestylings,
          displayValue: _restylingDisplayList(_tkRestylings),
          onTap: _openRestylingPicker,
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
                labelText: '\u041f\u0440\u043e\u0431\u0435\u0433 \u0434\u043e',
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
          onTap: _submitTurnkey,
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
    this.displayValue,
    required this.onTap,
  });

  final String label;
  final String placeholder;
  final List<String> value;
  final List<String>? displayValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effective = displayValue ?? value;
    final text = effective.isEmpty
        ? placeholder
        : effective.length <= 2
        ? effective.join(', ')
        : '${effective.take(2).join(', ')} +${effective.length - 2}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 16,
          child: Align(
            alignment: Alignment.centerLeft,
            child: MyText(
              text: label,
              size: 14,
              weight: FontWeight.bold,
              maxLines: 1,
              textOverflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 6),
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

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.placeholder,
    required this.value,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final String placeholder;
  final String value;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value.isNotEmpty
        ? value
        : loading
        ? 'Загрузка...'
        : enabled
        ? placeholder
        : 'Выберите марку и модель';
    final color = value.isNotEmpty
        ? kTertiaryColor
        : (enabled ? kHintColor : kGreyColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 16,
          child: Align(
            alignment: Alignment.centerLeft,
            child: MyText(
              text: label,
              size: 12,
              weight: FontWeight.bold,
              maxLines: 1,
              textOverflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.expand_more, size: 18, color: kGreyColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RestylingMeta {
  const _RestylingMeta({
    required this.generation,
    required this.yearStart,
    required this.yearEnd,
    required this.frames,
  });

  final int generation;
  final int? yearStart;
  final int? yearEnd;
  final List<String> frames;
}

class _RestylingCardData {
  const _RestylingCardData({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String value;
  final String title;
  final String subtitle;
  final String imageUrl;
}

class _RestylingCard extends StatelessWidget {
  const _RestylingCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kSecondaryColor : kBorderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Image.asset(
                              Assets.imagesNoImageFound,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            Assets.imagesNoImageFound,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(text: title, size: 12, weight: FontWeight.w700),
                      if (subtitle.isNotEmpty)
                        MyText(text: subtitle, size: 10, color: kGreyColor),
                    ],
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kSecondaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: kWhiteColor),
                ),
              ),
          ],
        ),
      ),
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

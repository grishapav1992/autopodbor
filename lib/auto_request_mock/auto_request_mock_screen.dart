import 'dart:math';

import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import 'api.dart';
import 'data.dart';
import 'models.dart';
import 'utils.dart';
import 'widgets.dart';

class AutoRequestMockScreen extends StatefulWidget {
  const AutoRequestMockScreen({super.key, this.requireAuthOnSubmit = false});

  final bool requireAuthOnSubmit;

  @override
  State<AutoRequestMockScreen> createState() => _AutoRequestMockScreenState();
}

class _AutoRequestMockScreenState extends State<AutoRequestMockScreen> {
  bool isSmall = false;
  bool _authorized = false;
  bool _authGateOpen = false;

  String routeName = 'create';
  String? routeRequestId;

  late List<ProProfile> pros;
  late List<AutoRequest> requests;
  late List<ProOffer> offers;

  final int totalSteps = 3;
  int step = 1;
  RequestType type = RequestType.byCar;

  String? editingRequestId;
  String? cancelModalId;

  String city = 'Алматы';
  bool areaOpen = false;
  String budgetFrom = '';
  String budgetTo = '';
  String comment = '';

  List<CarItem> cars = [];
  Map<String, bool> carCollapsed = {};
  Map<String, bool> manualCarOpen = {};

  String tkSegmentScheme = 'EU';
  List<String> tkSegments = ['D'];
  List<String> tkBrandCountries = [];
  List<String> tkMakes = [];
  List<String> tkModelsSel = [];
  List<String> tkVersionsSel = [];
  String tkYearFrom = '2018';
  String tkYearTo = '2022';
  String tkMileageFrom = '';
  String tkMileageTo = '120000';
  List<String> tkBodyTypes = [];
  List<String> tkFuelTypes = [];
  List<String> tkTransmissions = [];
  List<String> tkDrives = [];
  String tkOwnersMax = '';
  bool tkNoAccidents = false;
  bool tkServiceBook = false;
  List<String> tkColors = ['Любой'];
  String tkMustHave = '';
  String tkMustAvoid = '';

  Map<String, String> errors = {};
  Map<String, Map<String, String>> carErrors = {};

  String? drawerProId;

  final BrandApi _brandApi = BrandApi();
  List<String> brandOptions = [];
  final Map<String, String> brandAliases = {};
  bool brandsLoading = false;
  String? brandsError;
  final Map<String, List<String>> _modelCache = {};
  final Set<String> _modelLoading = {};
  final Map<String, String> _modelError = {};

  @override
  void initState() {
    super.initState();
    _authorized = !widget.requireAuthOnSubmit;
    pros = [
      ProProfile(
        id: 'PRO-01',
        name: 'Илья Власов',
        city: 'Алматы',
        rating: 5,
        completedDeals: 124,
        yearsExp: 7,
        about:
            'Подбор под ключ и разовые осмотры. Специализация: японские и немецкие авто. Работаю с толщиномером, эндоскопией и диагностикой.',
      ),
      ProProfile(
        id: 'PRO-02',
        name: 'Александр Ким',
        city: 'Алматы',
        rating: 4,
        completedDeals: 78,
        yearsExp: 5,
        about:
            'Осмотры по городу и области. Умею быстро договариваться о встречах, проверяю юридическую чистоту и историю.',
      ),
      ProProfile(
        id: 'PRO-03',
        name: 'Руслан Асанов',
        city: 'Алматы',
        rating: 5,
        completedDeals: 201,
        yearsExp: 9,
        about:
            'Премиальные авто и внедорожники. Дополнительно: сопровождение сделки, торг, проверка на СТО.',
      ),
    ];

    requests = [
      AutoRequest(
        id: 'REQ-100001',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        type: RequestType.turnkey,
        status: RequestStatus.hasOffers,
        city: 'Алматы',
        budgetFromRub: 3500000,
        budgetToRub: 4500000,
        comment: 'Пример заявки под ключ.',
        turnkey: TurnkeyFilters(
          makes: ['Ford'],
          models: ['Focus'],
          versions: ['Mk3'],
          segmentScheme: 'TAXI',
          segments: ['Комфорт', 'Бизнес'],
          yearFrom: 2016,
          yearTo: 2020,
          mileageFrom: 60000,
          mileageTo: 140000,
          bodyTypes: ['Хэтчбек', 'Седан'],
          fuelTypes: ['Бензин'],
          transmissions: ['AT'],
          drives: ['Передний'],
          ownersMax: 2,
          noAccidents: true,
          serviceBookRequired: false,
          colorPreferences: ['Любой'],
          mustHave: 'Климат-контроль, круиз-контроль',
          mustAvoid: 'Такси, юридические ограничения',
        ),
        reportCount: 0,
      ),
    ];

    offers = [
      ProOffer(
        id: 'OFF-01',
        requestId: 'REQ-100001',
        proId: 'PRO-01',
        priceRub: 65000,
        etaDays: 5,
        message:
            'Готов начать сразу. Включаю проверку истории, диагностику и торг до 50 000 ₽.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ProOffer(
        id: 'OFF-02',
        requestId: 'REQ-100001',
        proId: 'PRO-02',
        priceRub: 52000,
        etaDays: 7,
        message:
            'Сделаю подбор в пределах недели. Работаю по чек-листу, предоставляю отчеты с фото/видео.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ProOffer(
        id: 'OFF-03',
        requestId: 'REQ-100001',
        proId: 'PRO-03',
        priceRub: 78000,
        etaDays: 4,
        message:
            'Под ключ + сопровождение сделки и проверка на выбранной СТО.',
        createdAt: DateTime.now().subtract(const Duration(hours: 26)),
      ),
    ];

    resetWizard();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() {
      brandsLoading = true;
      brandsError = null;
    });
    try {
      final items = await _brandApi.fetchBrands();
      setState(() {
        brandOptions = items.map((e) => e.name).toList();
        brandAliases
          ..clear()
          ..addEntries(
            items
                .where((e) => e.nameRus != null && e.nameRus!.isNotEmpty)
                .map((e) => MapEntry(e.name, e.nameRus!)),
          );
        brandsLoading = false;
      });
    } catch (e) {
      setState(() {
        brandsError = e.toString();
        brandsLoading = false;
      });
    }
  }

  void _searchBrands(String query) {
    if (brandOptions.isEmpty && !brandsLoading) {
      _loadBrands();
    }
  }

  Future<void> _loadModelsForBrand(String brand) async {
    final trimmed = brand.trim();
    if (trimmed.isEmpty) return;
    if (_modelLoading.contains(trimmed)) return;

    setState(() {
      _modelLoading.add(trimmed);
      _modelError.remove(trimmed);
    });

    try {
      final models = await _brandApi.fetchModels(brandName: trimmed);
      setState(() {
        _modelCache[trimmed] = models;
        _modelLoading.remove(trimmed);
      });
    } catch (e) {
      setState(() {
        _modelError[trimmed] = e.toString();
        _modelLoading.remove(trimmed);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void resetWizard() {
    step = 1;
    type = RequestType.byCar;
    city = 'Алматы';
    budgetFrom = '';
    budgetTo = '';
    comment = '';

    final firstCarId = genId('CAR');
    cars = [CarItem(id: firstCarId)];
    carCollapsed = {firstCarId: false};
    manualCarOpen = {};

    tkSegmentScheme = 'EU';
    tkSegments = ['D'];
    tkBrandCountries = [];
    tkMakes = [];
    tkModelsSel = [];
    tkVersionsSel = [];
    tkYearFrom = '2018';
    tkYearTo = '2022';
    tkMileageFrom = '';
    tkMileageTo = '120000';
    tkBodyTypes = [];
    tkFuelTypes = [];
    tkTransmissions = [];
    tkDrives = [];
    tkOwnersMax = '';
    tkNoAccidents = false;
    tkServiceBook = false;
    tkColors = ['Любой'];
    tkMustHave = '';
    tkMustAvoid = '';

    errors = {};
    carErrors = {};
    editingRequestId = null;
    setState(() {});
  }

  bool validateStep1() {
    final e = <String, String>{};
    if (city.trim().isEmpty) e['city'] = 'Укажите область поиска';

    final bf = parseMoney(budgetFrom);
    final bt = parseMoney(budgetTo);
    if (budgetFrom.trim().isNotEmpty && bf == null) {
      e['budgetFrom'] = 'Некорректное число';
    }
    if (budgetTo.trim().isNotEmpty && bt == null) {
      e['budgetTo'] = 'Некорректное число';
    }
    if (bf != null && bt != null && bf > bt) {
      const msg = 'Бюджет «от» должен быть меньше или равен «до»';
      e['budgetFrom'] = msg;
      e['budgetTo'] = msg;
    }

    errors = e;
    setState(() {});
    return e.isEmpty;
  }

  bool validateCars() {
    final per = <String, Map<String, String>>{};
    final toOpen = <String>[];

    for (final c in cars) {
      if (isCarEmpty(c)) continue;
      final ce = <String, String>{};

      final url = c.sourceUrl.trim();
      final phoneDigits = digitsOnly(c.sellerPhone);
      final hasPhone = phoneDigits.isNotEmpty;
      final hasUrl = url.isNotEmpty;

      if (!hasUrl && !hasPhone) {
        final manualComplete = c.make.trim().isNotEmpty &&
            c.model.trim().isNotEmpty &&
            c.restyling.trim().isNotEmpty &&
            c.year.trim().isNotEmpty;
        if (!manualComplete) {
          const msg =
              'Нужно указать ссылку на объявление (avito/drom/auto.ru), телефон продавца или заполнить марку/модель/поколение/год';
          ce['sourceUrl'] = msg;
          ce['sellerPhone'] = msg;
          toOpen.add(c.id);
        }
      }

      if (hasUrl && !isAllowedListingUrl(url)) {
        ce['sourceUrl'] = 'Ссылка должна быть с avito.ru, drom.ru или auto.ru';
      }

      if (hasPhone && phoneDigits.length < 10) {
        ce['sellerPhone'] = 'Телефон слишком короткий';
      }

      final manualTouched = c.make.trim().isNotEmpty ||
          c.model.trim().isNotEmpty ||
          c.restyling.trim().isNotEmpty ||
          c.year.trim().isNotEmpty;

      if (manualTouched) {
        if (c.make.trim().isEmpty) ce['make'] = 'Выберите марку';
        if (c.model.trim().isEmpty) ce['model'] = 'Выберите модель';
        if (c.restyling.trim().isEmpty) {
          ce['restyling'] = 'Выберите поколение/кузов';
        }
        if (c.year.trim().isEmpty) ce['year'] = 'Выберите год';
      }

      if (ce.isNotEmpty) per[c.id] = ce;
    }

    carErrors = per;
    if (toOpen.isNotEmpty) {
      for (final id in toOpen) {
        manualCarOpen[id] = true;
      }
    }
    setState(() {});
    return per.isEmpty;
  }

  bool validateTurnkey() {
    final e = <String, String>{};
    if (tkSegments.isEmpty) {
      e['tkSegments'] = 'Выберите хотя бы один класс/сегмент';
    }
    if (tkModelsSel.isNotEmpty && tkMakes.isEmpty) {
      e['tkModelsSel'] = 'Чтобы выбрать модели, выберите марку';
    }
    if (tkVersionsSel.isNotEmpty &&
        (tkMakes.isEmpty || tkModelsSel.isEmpty)) {
      e['tkVersionsSel'] = 'Чтобы выбрать поколения, выберите марку и модель';
    }

    final yf = int.tryParse(tkYearFrom);
    final yt = int.tryParse(tkYearTo);
    if (tkYearFrom.trim().isNotEmpty && yf == null) {
      e['tkYearFrom'] = 'Некорректный год';
    }
    if (tkYearTo.trim().isNotEmpty && yt == null) {
      e['tkYearTo'] = 'Некорректный год';
    }
    if (yf != null && yt != null && yf > yt) {
      e['tkYearFrom'] = 'Год «от» должен быть меньше или равен «до»';
      e['tkYearTo'] = 'Год «до» должен быть больше или равен «от»';
    }

    final milFrom =
        tkMileageFrom.trim().isEmpty ? null : int.tryParse(tkMileageFrom);
    final milTo =
        tkMileageTo.trim().isEmpty ? null : int.tryParse(tkMileageTo);
    if (tkMileageFrom.trim().isNotEmpty && (milFrom == null || milFrom < 0)) {
      e['tkMileageFrom'] = 'Некорректный пробег';
    }
    if (tkMileageTo.trim().isNotEmpty && (milTo == null || milTo < 0)) {
      e['tkMileageTo'] = 'Некорректный пробег';
    }
    if (milFrom != null && milTo != null && milFrom > milTo) {
      e['tkMileageFrom'] = 'Пробег «от» должен быть меньше или равен «до»';
      e['tkMileageTo'] = 'Пробег «до» должен быть больше или равен «от»';
    }

    final owners =
        tkOwnersMax.trim().isEmpty ? null : int.tryParse(tkOwnersMax);
    if (tkOwnersMax.trim().isNotEmpty && (owners == null || owners < 1)) {
      e['tkOwnersMax'] = 'Некорректное число';
    }

    errors = {...errors, ...e};
    setState(() {});
    return e.isEmpty;
  }

  bool validateStep2() {
    final e = <String, String>{};
    if (type == RequestType.byCar) {
      final activeCars = cars.where((c) => !isCarEmpty(c)).toList();
      if (activeCars.isEmpty) e['cars'] = 'Добавьте хотя бы один автомобиль';
      if (activeCars.length > 5) {
        e['cars'] = 'Можно добавить не более 5 автомобилей';
      }
      errors = {...errors, ...e};
      setState(() {});
      return e.isEmpty && validateCars();
    }
    errors = {...errors, ...e};
    setState(() {});
    return validateTurnkey();
  }

  AutoRequest currentPreview() {
    TurnkeyFilters? turnkey;
    if (type == RequestType.turnkey) {
      turnkey = TurnkeyFilters(
        makes: tkMakes,
        models: tkModelsSel,
        versions: tkVersionsSel,
        segmentScheme: tkSegmentScheme,
        segments: tkSegments,
        yearFrom: int.tryParse(tkYearFrom),
        yearTo: int.tryParse(tkYearTo),
        mileageFrom: int.tryParse(tkMileageFrom),
        mileageTo: int.tryParse(tkMileageTo),
        bodyTypes: tkBodyTypes,
        fuelTypes: tkFuelTypes,
        transmissions: tkTransmissions,
        drives: tkDrives,
        ownersMax:
            tkOwnersMax.trim().isEmpty ? null : int.tryParse(tkOwnersMax),
        noAccidents: tkNoAccidents ? true : null,
        serviceBookRequired: tkServiceBook ? true : null,
        colorPreferences: tkColors,
        mustHave: tkMustHave.trim().isEmpty ? null : tkMustHave.trim(),
        mustAvoid: tkMustAvoid.trim().isEmpty ? null : tkMustAvoid.trim(),
      );
    }

    return AutoRequest(
      id: editingRequestId ?? '—',
      createdAt: DateTime.now(),
      type: type,
      status: RequestStatus.draft,
      city: city.trim(),
      budgetFromRub: parseMoney(budgetFrom),
      budgetToRub: parseMoney(budgetTo),
      comment: comment.trim().isEmpty ? null : comment.trim(),
      cars: type == RequestType.byCar
          ? cars
              .where((c) => !isCarEmpty(c))
              .map((c) {
                final cc = c.copy();
                cc.make = cc.make.trim();
                cc.model = cc.model.trim();
                cc.restyling = cc.restyling.trim();
                cc.year = cc.year.trim();
                cc.vin = cc.vin.trim();
                cc.plate = cc.plate.trim();
                cc.sourceUrl = cc.sourceUrl.trim();
                cc.sellerPhone = stripSpaces(cc.sellerPhone);
                cc.note = cc.note.trim();
                return cc;
              })
              .toList()
          : null,
      turnkey: turnkey,
      reportCount: 0,
    );
  }

  void upsertRequest() {
    if (!validateStep1()) {
      step = 1;
      setState(() {});
      return;
    }
    if (!validateStep2()) {
      step = 2;
      setState(() {});
      return;
    }

    if (widget.requireAuthOnSubmit &&
        !_authorized &&
        editingRequestId == null) {
      _authGateOpen = true;
      setState(() {});
      return;
    }

    final preview = currentPreview();

    if (editingRequestId != null) {
      requests = requests.map((r) {
        if (r.id != editingRequestId) return r;
        return AutoRequest(
          id: r.id,
          createdAt: r.createdAt,
          type: r.type,
          status: r.status,
          city: preview.city,
          budgetFromRub: preview.budgetFromRub,
          budgetToRub: preview.budgetToRub,
          comment: preview.comment,
          cars: preview.cars,
          turnkey: preview.turnkey,
          reportCount: r.reportCount,
        );
      }).toList();
      routeName = 'my';
      resetWizard();
      return;
    }

    final newReq = AutoRequest(
      id: genId('REQ'),
      createdAt: DateTime.now(),
      type: preview.type,
      status: RequestStatus.published,
      city: preview.city,
      budgetFromRub: preview.budgetFromRub,
      budgetToRub: preview.budgetToRub,
      comment: preview.comment,
      cars: preview.cars,
      turnkey: preview.turnkey,
      reportCount: 0,
    );
    requests = [newReq, ...requests];
    routeName = 'my';
    resetWizard();
  }

  Future<void> _handleAuth(bool isLogin) async {
    setState(() => _authGateOpen = false);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => isLogin
            ? const LoginScreen(returnResult: true)
            : const RegisterScreen(returnResult: true),
      ),
    );
    if (result == true) {
      _authorized = true;
      setState(() {});
    }
  }

  void nextStep() {
    if (step == 1) {
      if (!validateStep1()) return;
      step = 2;
      setState(() {});
      return;
    }
    if (step == 2) {
      if (!validateStep2()) return;
      step = 3;
      setState(() {});
      return;
    }
    upsertRequest();
  }

  void backStep() {
    step = max(1, step - 1);
    setState(() {});
  }

  void updateStatus(String id, RequestStatus status) {
    requests = requests.map((r) {
      if (r.id != id) return r;
      r.status = status;
      return r;
    }).toList();
    setState(() {});
  }

  void addCar() {
    errors['cars'] = '';
    if (cars.length >= 5) return;
    final id = genId('CAR');
    carCollapsed[id] = false;
    cars = [...cars, CarItem(id: id)];
    setState(() {});
  }

  void removeCar(String carId) {
    cars = cars.where((c) => c.id != carId).toList();
    carErrors.remove(carId);
    carCollapsed.remove(carId);
    manualCarOpen.remove(carId);
    setState(() {});
  }

  void setCarPatch(String carId, Map<String, String> patch) {
    cars = cars.map((c) {
      if (c.id != carId) return c;
      final next = c.copy();
      if (patch.containsKey('make')) next.make = patch['make'] ?? '';
      if (patch.containsKey('model')) next.model = patch['model'] ?? '';
      if (patch.containsKey('restyling')) {
        next.restyling = patch['restyling'] ?? '';
      }
      if (patch.containsKey('year')) next.year = patch['year'] ?? '';
      if (patch.containsKey('vin')) next.vin = patch['vin'] ?? '';
      if (patch.containsKey('plate')) next.plate = patch['plate'] ?? '';
      if (patch.containsKey('sourceUrl')) {
        next.sourceUrl = patch['sourceUrl'] ?? '';
      }
      if (patch.containsKey('sellerPhone')) {
        next.sellerPhone = patch['sellerPhone'] ?? '';
      }
      if (patch.containsKey('note')) next.note = patch['note'] ?? '';

      if (patch.containsKey('plate')) {
        final key = (patch['plate'] ?? '').trim();
        final hit = plateLookup[key];
        if (hit != null) {
          next.make = hit['make'] ?? next.make;
          next.model = hit['model'] ?? next.model;
          next.restyling = hit['restyling'] ?? next.restyling;
          next.year = hit['year'] ?? next.year;
          next.vin = hit['vin'] ?? next.vin;
        }
      }

      if (patch.containsKey('make')) {
        next.model = '';
        next.restyling = '';
        next.year = '';
      }
      if (patch.containsKey('model')) {
        next.restyling = '';
        next.year = '';
      }
      if (patch.containsKey('restyling')) {
        if (!patch.containsKey('year')) {
          final opts = getYearOptions(next.make, next.model, next.restyling);
          next.year = opts.isNotEmpty ? opts.last : '';
        }
      }

      return next;
    }).toList();
    setState(() {});
  }

  String requestTitle(AutoRequest r) {
    if (r.type == RequestType.byCar) {
      final n = r.cars?.length ?? 0;
      final first = r.cars != null && r.cars!.isNotEmpty
          ? (r.cars!.first.sourceUrl.isNotEmpty
              ? shortListingLabel(r.cars!.first.sourceUrl)
              : '${r.cars!.first.make} ${r.cars!.first.model} ${r.cars!.first.restyling} ${r.cars!.first.year}')
          : '—';
      return n <= 1 ? 'По авто: $first' : 'По авто: $n авто';
    }
    final tk = r.turnkey;
    final mk = tk != null &&
            (tk.makes.isNotEmpty ||
                tk.models.isNotEmpty ||
                tk.versions.isNotEmpty)
        ? '${tk.makes.isNotEmpty ? tk.makes.join(', ') : 'Любая марка'}'
            '${tk.models.isNotEmpty ? ' / ${tk.models.join(', ')}' : ''}'
            '${tk.versions.isNotEmpty ? ' / ${tk.versions.join(', ')}' : ''}'
        : 'Любая марка/модель';
    return 'Под ключ: $mk';
  }

  List<String> filteredAreas() {
    final q = city.trim().toLowerCase();
    if (q.isEmpty) return locationSuggestions.take(6).toList();
    return locationSuggestions
        .where((x) => x.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  String? _err(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }

  ProProfile? getPro(String id) =>
      pros.firstWhere((p) => p.id == id, orElse: () => pros.first);

  void selectOffer(String offerId) {
    final offer = offers.firstWhere((o) => o.id == offerId);
    requests = requests.map((r) {
      if (r.id == offer.requestId) r.status = RequestStatus.proSelected;
      return r;
    }).toList();
    routeName = 'my';
    setState(() {});
  }

  void openEdit(String requestId) {
    final r = requests.firstWhere((x) => x.id == requestId);
    editingRequestId = r.id;
    step = 1;
    type = r.type;
    city = r.city;
    budgetFrom = r.budgetFromRub?.toString() ?? '';
    budgetTo = r.budgetToRub?.toString() ?? '';
    comment = r.comment ?? '';

    if (r.type == RequestType.byCar) {
      final list = (r.cars ?? []).isNotEmpty
          ? (r.cars ?? []).map((c) {
              return CarItem(
                id: c.id.isNotEmpty ? c.id : genId('CAR'),
                make: c.make,
                model: c.model,
                restyling: c.restyling,
                year: c.year,
                vin: c.vin,
                plate: c.plate,
                sourceUrl: c.sourceUrl,
                sellerPhone: c.sellerPhone,
                note: c.note,
              );
            }).toList()
          : [CarItem(id: genId('CAR'))];

      cars = list;
      carCollapsed = {};
      for (int i = 0; i < list.length; i++) {
        carCollapsed[list[i].id] = i != 0;
      }
      manualCarOpen = {};
    }

    if (r.type == RequestType.turnkey && r.turnkey != null) {
      final tk = r.turnkey!;
      tkSegmentScheme = tk.segmentScheme;
      tkSegments = tk.segments;
      tkBrandCountries = tk.makes.map(getMakeCountry).toSet().toList();
      tkMakes = tk.makes;
      tkModelsSel = tk.models;
      tkVersionsSel = tk.versions;
      tkYearFrom = tk.yearFrom?.toString() ?? '';
      tkYearTo = tk.yearTo?.toString() ?? '';
      tkMileageFrom = tk.mileageFrom?.toString() ?? '';
      tkMileageTo = tk.mileageTo?.toString() ?? '';
      tkBodyTypes = tk.bodyTypes;
      tkFuelTypes = tk.fuelTypes;
      tkTransmissions = tk.transmissions;
      tkDrives = tk.drives;
      tkOwnersMax = tk.ownersMax?.toString() ?? '';
      tkNoAccidents = tk.noAccidents ?? false;
      tkServiceBook = tk.serviceBookRequired ?? false;
      tkColors = tk.colorPreferences;
      tkMustHave = tk.mustHave ?? '';
      tkMustAvoid = tk.mustAvoid ?? '';
    }

    errors = {};
    carErrors = {};
    routeName = 'create';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    isSmall = MediaQuery.of(context).size.width <= 720;

    final baseBrands =
        brandOptions.isNotEmpty ? brandOptions : carCatalog.keys.toList();
    final tkMakeOptions = () {
      final all = [...baseBrands]..sort();
      if (tkBrandCountries.isEmpty) return all;
      final set = tkBrandCountries.toSet();
      return all.where((mk) => set.contains(getMakeCountry(mk))).toList();
    }();

    final tkModels = tkMakes.isEmpty
        ? <String>[]
        : () {
            final fromApi = <String>{};
            for (final mk in tkMakes) {
              final list = _modelCache[mk];
              if (list != null) fromApi.addAll(list);
            }
            if (fromApi.isNotEmpty) {
              final list = fromApi.toList()..sort();
              return list;
            }
            final fallback = getAllModelsForMakes(tkMakes)..sort();
            return fallback;
          }();
    final tkVersions = (tkMakes.isEmpty || tkModelsSel.isEmpty)
        ? <String>[]
        : (getAllRestylingsForSelection(tkMakes, tkModelsSel)..sort());

    final currentReq = routeName == 'offers'
        ? requests.firstWhere(
            (r) => r.id == routeRequestId,
            orElse: () => AutoRequest(
              id: '—',
              createdAt: DateTime.now(),
              type: RequestType.byCar,
              status: RequestStatus.published,
              city: '—',
            ),
          )
        : null;

    final currentOffers = routeName == 'offers'
        ? (offers
            .where((o) => o.requestId == routeRequestId)
            .toList()
          ..sort((a, b) => a.priceRub.compareTo(b.priceRub)))
        : <ProOffer>[];

    final page = routeName == 'create'
        ? _buildCreatePage(baseBrands, tkMakeOptions, tkModels, tkVersions)
        : routeName == 'my'
            ? _buildMyPage()
            : _buildOffersPage(currentReq, currentOffers);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [uiTokens.gray50, Colors.white],
                begin: Alignment.topCenter,
                end: const Alignment(0, 0.6),
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: EdgeInsets.all(isSmall ? 12 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(child: page),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_authGateOpen)
            AppModal(
              title: 'Войдите или зарегистрируйтесь',
              onClose: () => setState(() => _authGateOpen = false),
              child: const Text(
                'Чтобы отправить заявку, нужна авторизация.',
              ),
              footer: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Регистрация',
                    variant: ButtonVariant.secondary,
                    onTap: () => _handleAuth(false),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Войти',
                    onTap: () => _handleAuth(true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: uiTokens.gray900,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Автоподбор',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Web мок: заявка + мои заявки + предложения',
                  style: TextStyle(fontSize: 12, color: uiTokens.gray600),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        Wrap(
          spacing: 8,
          children: [
            AppButton(
              label: 'Создать заявку',
              variant: routeName == 'create'
                  ? ButtonVariant.primary
                  : ButtonVariant.secondary,
              onTap: () {
                if (routeName != 'create') resetWizard();
                setState(() => routeName = 'create');
              },
            ),
            AppButton(
              label: 'Мои заявки (${requests.length})',
              variant: routeName == 'my'
                  ? ButtonVariant.primary
                  : ButtonVariant.secondary,
              onTap: () => setState(() => routeName = 'my'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreatePage(
    List<String> baseBrands,
    List<String> tkMakeOptions,
    List<String> tkModels,
    List<String> tkVersions,
  ) {
    final preview = currentPreview();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: StepHeader(
                  step: step,
                  total: totalSteps,
                  title: editingRequestId != null
                      ? 'Редактирование заявки'
                      : 'Создать заявку',
                ),
              ),
              const SizedBox(width: 10),
              const StatusPill(status: RequestStatus.draft),
            ],
          ),
          const SizedBox(height: 12),
          if (step == 1) _buildStep1(),
          if (step == 2)
            _buildStep2(baseBrands, tkMakeOptions, tkModels, tkVersions),
          if (step == 3) _buildStep3(preview),
          const SizedBox(height: 14),
          Row(
            children: [
              AppButton(
                label: step == 1 ? 'Сбросить' : 'Назад',
                variant: ButtonVariant.secondary,
                onTap: () {
                  if (step == 1) {
                    resetWizard();
                    return;
                  }
                  backStep();
                },
              ),
              const Spacer(),
              Wrap(
                spacing: 10,
                children: [
                  AppButton(
                    label: 'Перейти в «Мои заявки»',
                    variant: ButtonVariant.secondary,
                    onTap: () => setState(() => routeName = 'my'),
                  ),
                  AppButton(
                    label: step < 3
                        ? 'Далее'
                        : (editingRequestId != null
                            ? 'Сохранить'
                            : 'Создать заявку'),
                    onTap: step < 3 ? nextStep : upsertRequest,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppField(
          label: 'Тип заявки',
          required: true,
          child: AppSelect<RequestType>(
            value: type,
            items: RequestType.values,
            label: (v) => requestTypeLabel[v] ?? '',
            enabled: editingRequestId == null,
            onChanged: (v) {
              if (v == null) return;
              type = v;
              errors = {};
              carErrors = {};
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 12),
        AppField(
          label: 'Область поиска',
          required: true,
          hint: _err(errors['city']),
          child: Stack(
            children: [
              AppInput(
                value: city,
                placeholder:
                    'Город, район или адрес (например: Алматы, Бостандыкский район)',
                onChanged: (v) {
                  city = v;
                  areaOpen = true;
                  setState(() {});
                },
                onFocus: () => setState(() => areaOpen = true),
                onBlur: () {
                  Future.delayed(
                    const Duration(milliseconds: 120),
                    () => setState(() => areaOpen = false),
                  );
                },
              ),
              if (areaOpen && filteredAreas().isNotEmpty)
                Positioned(
                  top: 52,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: uiTokens.gray300),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 25,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: filteredAreas().map((s) {
                        return InkWell(
                          onTap: () {
                            city = s;
                            areaOpen = false;
                            setState(() {});
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 13,
                                color: uiTokens.gray900,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isSmall ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3.2,
          children: [
            AppField(
              label: 'Бюджет от (₽)',
              hint: _err(errors['budgetFrom']),
              child: AppInput(
                value: budgetFrom,
                placeholder: 'Например: 2500000',
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => budgetFrom = v),
              ),
            ),
            AppField(
              label: 'Бюджет до (₽)',
              hint: _err(errors['budgetTo']),
              child: AppInput(
                value: budgetTo,
                placeholder: 'Например: 3500000',
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => budgetTo = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppField(
          label: 'Комментарий',
          child: AppTextarea(
            value: comment,
            rows: 4,
            placeholder: 'Например: не такси, не более 2 владельцев...',
            onChanged: (v) => setState(() => comment = v),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(
    List<String> baseBrands,
    List<String> tkMakeOptions,
    List<String> tkModels,
    List<String> tkVersions,
  ) {
    final brandHint = _err(brandsError);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Тип: ${requestTypeLabel[type]}',
          style: TextStyle(fontSize: 13, color: uiTokens.gray600),
        ),
        const SizedBox(height: 12),
        if (type == RequestType.byCar) ...[
          Row(
            children: [
              Text(
                'Автомобили (${cars.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: uiTokens.gray900,
                ),
              ),
              const Spacer(),
              AppButton(
                label: '+ Добавить автомобиль',
                onTap: cars.length >= 5 ? null : addCar,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Максимум 5 автомобилей в одной заявке.',
            style: TextStyle(
              fontSize: 12,
              color: cars.length >= 5
                  ? const Color(0xFF991B1B)
                  : uiTokens.gray600,
            ),
          ),
          if ((errors['cars'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                errors['cars']!,
                style: TextStyle(fontSize: 12, color: uiTokens.red600),
              ),
            ),
          const SizedBox(height: 12),
          Column(
            children: cars.asMap().entries.map((entry) {
              final idx = entry.key;
              final c = entry.value;
              final years = getYearOptions(c.make, c.model, c.restyling);
              final showManual = manualCarOpen[c.id] ?? false;
              final collapsed = carCollapsed[c.id] ?? idx != 0;
              final modelHint = _err(_modelError[c.make]);
              final modelOptions = () {
                if (c.make.trim().isEmpty) return <String>[];
                final cached = _modelCache[c.make];
                if (cached != null && cached.isNotEmpty) return cached;
                return carCatalog[c.make]?.keys.toList() ?? <String>[];
              }();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CarRow(
                  item: c,
                  index: idx,
                  onRemove: () => removeCar(c.id),
                  canRemove: cars.length > 1,
                  errors: carErrors[c.id] ?? {},
                  collapsed: collapsed,
                  onToggle: () {
                    carCollapsed[c.id] = !collapsed;
                    setState(() {});
                  },
                  showManualFields: showManual,
                  onToggleManual: () {
                    manualCarOpen[c.id] = !(manualCarOpen[c.id] ?? false);
                    setState(() {});
                  },
                  years: years,
                  onChange: (patch) => setCarPatch(c.id, patch),
                  isSmall: isSmall,
                  brandOptions: baseBrands,
                  brandHint: brandHint,
                  onBrandSearch: _searchBrands,
                  onBrandOpen: _loadBrands,
                  modelOptions: modelOptions,
                  modelHint: modelHint,
                  onModelOpen: () => _loadModelsForBrand(c.make),
                  brandAliases: brandAliases,
                ),
              );
            }).toList(),
          ),
        ],
        if (type == RequestType.turnkey) ...[
          Text(
            'Класс / сегмент',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: uiTokens.gray900,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: isSmall ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isSmall ? 2.4 : 3.5,
            children: [
            AppField(
              label: 'Тип классификации',
              required: true,
              child: AppSelect<String>(
                  value: tkSegmentScheme,
                  items: const ['EU', 'TAXI'],
                  label: (v) => v == 'TAXI' ? 'Как в такси' : 'Европейская',
                  onChanged: (v) {
                    if (v == null) return;
                    tkSegmentScheme = v;
                    final allowed = (v == 'TAXI'
                            ? segmentOptionsTaxi
                            : segmentOptionsEU)
                        .toSet();
                    tkSegments = tkSegments.where(allowed.contains).toList();
                    setState(() {});
                  },
                ),
              ),
              MultiSelectPicker(
                label: 'Сегменты',
                value: tkSegments,
                options: tkSegmentScheme == 'TAXI'
                    ? segmentOptionsTaxi
                    : segmentOptionsEU,
                onChange: (next) => setState(() => tkSegments = next),
                hint: _err(errors['tkSegments']),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Марка / модель / версия (опционально)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: uiTokens.gray900,
            ),
          ),
          const SizedBox(height: 10),
          AvitoDropdownSelect(
            label: 'Страна бренда',
            value: tkBrandCountries,
            options: brandCountries,
            onChange: (next) {
              tkBrandCountries = next;
              final allowedMakes = tkBrandCountries.isEmpty
                  ? baseBrands.toSet()
                  : baseBrands
                      .where((mk) =>
                          tkBrandCountries.contains(getMakeCountry(mk)))
                      .toSet();
              tkMakes = tkMakes.where(allowedMakes.contains).toList();
              final nextModels = getAllModelsForMakes(tkMakes).toSet();
              tkModelsSel =
                  tkModelsSel.where(nextModels.contains).toList();
              final nextRestylings =
                  getAllRestylingsForSelection(tkMakes, tkModelsSel).toSet();
              tkVersionsSel =
                  tkVersionsSel.where(nextRestylings.contains).toList();
              setState(() {});
            },
            mode: AvitoSelectMode.multi,
          ),
          const SizedBox(height: 10),
          FilterMultiSelect(
            label: 'Марка',
            value: tkMakes,
            options: tkMakeOptions,
            searchAliases: brandAliases,
            maxVisibleItems: 10,
            closeOnSelect: false,
            onChange: (next) {
              tkMakes = next;
              final nextModels = getAllModelsForMakes(next).toSet();
              tkModelsSel = tkModelsSel.where(nextModels.contains).toList();
              final nextRestylings =
                  getAllRestylingsForSelection(next, tkModelsSel).toSet();
              tkVersionsSel =
                  tkVersionsSel.where(nextRestylings.contains).toList();
              for (final mk in next) {
                _loadModelsForBrand(mk);
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          AvitoDropdownSelect(
            label: 'Модель',
            value: tkModelsSel,
            options: tkModels,
            onChange: (next) {
              tkModelsSel = next;
              final nextRestylings =
                  getAllRestylingsForSelection(tkMakes, next).toSet();
              tkVersionsSel =
                  tkVersionsSel.where(nextRestylings.contains).toList();
              setState(() {});
            },
            disabled: tkMakes.isEmpty,
            hint: _err(
                _modelError.entries
                    .firstWhere(
                      (e) => tkMakes.contains(e.key),
                      orElse: () => const MapEntry('', ''),
                    )
                    .value),
            mode: AvitoSelectMode.multi,
            onOpen: () {
              for (final mk in tkMakes) {
                _loadModelsForBrand(mk);
              }
            },
          ),
          const SizedBox(height: 10),
          AvitoDropdownSelect(
            label: 'Поколение',
            value: tkVersionsSel,
            options: tkVersions,
            onChange: (next) {
              tkVersionsSel = next;
              final yrs = getAllYearsForSelection(tkMakes, tkModelsSel, next);
              if (yrs.isNotEmpty) {
                tkYearFrom = yrs.reduce(min).toString();
                tkYearTo = yrs.reduce(max).toString();
              }
              setState(() {});
            },
            disabled: tkMakes.isEmpty || tkModelsSel.isEmpty,
            hint: errors['tkVersionsSel'] ??
                (tkMakes.isNotEmpty && tkModelsSel.isNotEmpty
                    ? 'Можно выбрать несколько. Год подставится автоматически (можно поправить).'
                    : 'Чтобы выбрать поколения, выберите марку и модель'),
            mode: AvitoSelectMode.multi,
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: isSmall ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3.5,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppField(
                      label: 'Год от',
                      hint: _err(errors['tkYearFrom']),
                      child: AppInput(
                        value: tkYearFrom,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => tkYearFrom = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppField(
                      label: 'Год до',
                      hint: _err(errors['tkYearTo']),
                      child: AppInput(
                        value: tkYearTo,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => setState(() => tkYearTo = v),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: AppField(
                      label: 'Пробег от (км)',
                      hint: _err(errors['tkMileageFrom']),
                      child: AppInput(
                        value: tkMileageFrom,
                        keyboardType: TextInputType.number,
                        placeholder: 'Например: 0',
                        onChanged: (v) =>
                            setState(() => tkMileageFrom = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppField(
                      label: 'Пробег до (км)',
                      hint: _err(errors['tkMileageTo']),
                      child: AppInput(
                        value: tkMileageTo,
                        keyboardType: TextInputType.number,
                        placeholder: 'Например: 120000',
                        onChanged: (v) => setState(() => tkMileageTo = v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Дополнительные фильтры (как в Avito)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: uiTokens.gray900,
            ),
          ),
          const SizedBox(height: 10),
          MultiSelectPicker(
            label: 'Тип кузова',
            value: tkBodyTypes,
            options: bodyTypeOptions,
            onChange: (v) => setState(() => tkBodyTypes = v),
          ),
          const SizedBox(height: 10),
          MultiSelectPicker(
            label: 'Топливо',
            value: tkFuelTypes,
            options: fuelOptions,
            onChange: (v) => setState(() => tkFuelTypes = v),
          ),
          const SizedBox(height: 10),
          MultiSelectPicker(
            label: 'Коробка',
            value: tkTransmissions,
            options: transmissionOptions,
            onChange: (v) => setState(() => tkTransmissions = v),
          ),
          const SizedBox(height: 10),
          MultiSelectPicker(
            label: 'Привод',
            value: tkDrives,
            options: driveOptions,
            onChange: (v) => setState(() => tkDrives = v),
          ),
          const SizedBox(height: 10),
          MultiSelectPicker(
            label: 'Цвет',
            value: tkColors,
            options: colorOptions,
            onChange: (v) => setState(() => tkColors = v),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: isSmall ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3.3,
            children: [
              AppField(
                label: 'Макс. владельцев',
                hint: _err(errors['tkOwnersMax']),
                child: AppInput(
                  value: tkOwnersMax,
                  keyboardType: TextInputType.number,
                  placeholder: 'Например: 2',
                  onChanged: (v) => setState(() => tkOwnersMax = v),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckboxRow(
                    label: 'Без ДТП (желательно)',
                    value: tkNoAccidents,
                    onChanged: (v) => setState(() => tkNoAccidents = v),
                  ),
                  const SizedBox(height: 10),
                  _CheckboxRow(
                    label: 'Нужна сервисная история',
                    value: tkServiceBook,
                    onChanged: (v) => setState(() => tkServiceBook = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: isSmall ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              AppField(
                label: 'Обязательно должно быть',
                child: AppTextarea(
                  value: tkMustHave,
                  rows: 3,
                  placeholder: 'Например: климат, круиз, камера',
                  onChanged: (v) => setState(() => tkMustHave = v),
                ),
              ),
              AppField(
                label: 'Чего избегать',
                child: AppTextarea(
                  value: tkMustAvoid,
                  rows: 3,
                  placeholder: 'Например: такси, ограничения, крупные ДТП',
                  onChanged: (v) => setState(() => tkMustAvoid = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildStep3(AutoRequest preview) {
    final stackedPreview = isSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Проверьте данные. Можно вернуться и отредактировать, либо нажать «${editingRequestId != null ? 'Сохранить' : 'Создать'}» заявку.',
                style: TextStyle(fontSize: 13, color: uiTokens.gray600),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                AppButton(
                  label: 'Редактировать общие данные',
                  variant: ButtonVariant.secondary,
                  onTap: () => setState(() => step = 1),
                ),
                AppButton(
                  label: 'Редактировать детали',
                  variant: ButtonVariant.secondary,
                  onTap: () => setState(() => step = 2),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: uiTokens.gray300),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PreviewKV(
                k: 'Тип заявки',
                v: requestTypeLabel[type] ?? '',
                stacked: stackedPreview,
              ),
              PreviewKV(
                k: 'Область поиска',
                v: preview.city.isEmpty ? '—' : preview.city,
                stacked: stackedPreview,
              ),
              PreviewKV(
                k: 'Бюджет',
                v: formatBudget(preview.budgetFromRub, preview.budgetToRub),
                stacked: stackedPreview,
              ),
              PreviewKV(
                k: 'Комментарий',
                v: preview.comment ?? '—',
                stacked: stackedPreview,
              ),
              const SizedBox(height: 10),
              Text(
                'Детали',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: uiTokens.gray900,
                ),
              ),
              if (type == RequestType.byCar) ...[
                PreviewKV(
                  k: 'Автомобилей',
                  v: '${preview.cars?.length ?? 0}',
                  stacked: stackedPreview,
                ),
                const SizedBox(height: 8),
                Column(
                  children: (preview.cars ?? []).asMap().entries.map((entry) {
                    final idx = entry.key;
                    final c = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: uiTokens.gray300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Автомобиль №${idx + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: uiTokens.gray900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.sourceUrl.isNotEmpty ? 'Ссылка: ${shortListingLabel(c.sourceUrl)}' : 'Ссылка не указана'}'
                            '${c.plate.isNotEmpty ? ' • Госномер: ${c.plate}' : ''}'
                            '${c.sellerPhone.isNotEmpty ? ' • Тел.: ${c.sellerPhone}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: uiTokens.gray600,
                            ),
                          ),
                          if (c.make.isNotEmpty ||
                              c.model.isNotEmpty ||
                              c.restyling.isNotEmpty ||
                              c.year.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Параметры: ${c.make.isNotEmpty ? c.make : '—'} ${c.model.isNotEmpty ? c.model : '—'} ${c.restyling.isNotEmpty ? c.restyling : '—'} ${c.year.isNotEmpty ? c.year : '—'}',
                                style: TextStyle(
                                    fontSize: 12, color: uiTokens.gray600),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (type == RequestType.turnkey) ...[
                PreviewKV(
                  k: 'Предпочтение',
                  v: (preview.turnkey != null &&
                          (preview.turnkey!.makes.isNotEmpty ||
                              preview.turnkey!.models.isNotEmpty ||
                              preview.turnkey!.versions.isNotEmpty))
                      ? '${preview.turnkey!.makes.isNotEmpty ? preview.turnkey!.makes.join(', ') : 'Любая марка'}'
                          '${preview.turnkey!.models.isNotEmpty ? ' / ${preview.turnkey!.models.join(', ')}' : ''}'
                          '${preview.turnkey!.versions.isNotEmpty ? ' / ${preview.turnkey!.versions.join(', ')}' : ''}'
                      : 'Любая марка/модель',
                  stacked: stackedPreview,
                ),
                PreviewKV(
                  k: 'Сегменты',
                  v: preview.turnkey?.segments.join(', ') ?? '—',
                  stacked: stackedPreview,
                ),
                PreviewKV(
                  k: 'Классификация',
                  v: preview.turnkey?.segmentScheme == 'TAXI'
                      ? 'Как в такси'
                      : 'Европейская',
                  stacked: stackedPreview,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Мои заявки',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: uiTokens.gray900,
              ),
            ),
            const Spacer(),
            AppButton(
              label: 'Создать заявку',
              variant: ButtonVariant.secondary,
              onTap: () {
                resetWizard();
                setState(() => routeName = 'create');
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...requests.map((r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '№ ${r.id}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: uiTokens.gray600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              requestTitle(r),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: uiTokens.gray900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.city} • Бюджет: ${formatBudget(r.budgetFromRub, r.budgetToRub)}${r.reportCount != null ? ' • Отчетов: ${r.reportCount}' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: uiTokens.gray600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatDate(r.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: uiTokens.gray400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(status: r.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      AppButton(
                        label: 'Подробнее / Редактировать',
                        variant: ButtonVariant.secondary,
                        onTap: () => openEdit(r.id),
                      ),
                      if (r.status == RequestStatus.published) ...[
                        AppButton(
                          label: 'Отменить',
                          variant: ButtonVariant.danger,
                          onTap: () => setState(() => cancelModalId = r.id),
                        ),
                        AppButton(
                          label: 'Имитировать «Есть предложения»',
                          onTap: () {
                            updateStatus(r.id, RequestStatus.hasOffers);
                            final now = DateTime.now();
                            offers.insert(
                              0,
                              ProOffer(
                                id: genId('OFF'),
                                requestId: r.id,
                                proId: 'PRO-02',
                                priceRub: 45000,
                                etaDays: 6,
                                message:
                                    'Готов взяться. Уточню детали и приступлю.',
                                createdAt: now,
                              ),
                            );
                          },
                        ),
                      ],
                      if (r.status == RequestStatus.hasOffers) ...[
                        AppButton(
                          label: 'Вернуть в «Создана»',
                          variant: ButtonVariant.secondary,
                          onTap: () => updateStatus(r.id, RequestStatus.published),
                        ),
                        AppButton(
                          label: 'Открыть предложения',
                          onTap: () {
                            routeName = 'offers';
                            routeRequestId = r.id;
                            setState(() {});
                          },
                        ),
                      ],
                      if (r.status == RequestStatus.proSelected) ...[
                        AppButton(
                          label: 'Назад к предложениям',
                          variant: ButtonVariant.secondary,
                          onTap: () => updateStatus(r.id, RequestStatus.hasOffers),
                        ),
                        AppButton(
                          label: 'Имитировать «Оплачено / В работе»',
                          onTap: () => updateStatus(r.id, RequestStatus.inProgress),
                        ),
                      ],
                      if (r.status == RequestStatus.inProgress) ...[
                        AppButton(
                          label: 'Перевести в «Спор»',
                          variant: ButtonVariant.secondary,
                          onTap: () => updateStatus(r.id, RequestStatus.dispute),
                        ),
                        AppButton(
                          label: 'Имитировать «Завершена»',
                          onTap: () => updateStatus(r.id, RequestStatus.completed),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (cancelModalId != null)
          AppModal(
            title: 'Отменить заявку?',
            onClose: () => setState(() => cancelModalId = null),
            footer: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Нет, оставить',
                  variant: ButtonVariant.secondary,
                  onTap: () => setState(() => cancelModalId = null),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Да, отменить',
                  variant: ButtonVariant.danger,
                  onTap: () {
                    if (cancelModalId != null) {
                      updateStatus(cancelModalId!, RequestStatus.cancelled);
                    }
                    setState(() => cancelModalId = null);
                  },
                ),
              ],
            ),
            child: const Text(
              'Вы действительно хотите отменить заявку? После отмены автоподборщики не смогут откликаться.',
            ),
          ),
      ],
    );
  }

  Widget _buildOffersPage(AutoRequest? currentRequest, List<ProOffer> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Предложения по заявке',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: uiTokens.gray900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentRequest != null
                          ? '${requestTitle(currentRequest)} • ${currentRequest.city} • Бюджет: ${formatBudget(currentRequest.budgetFromRub, currentRequest.budgetToRub)}'
                          : 'Заявка не найдена',
                      style: TextStyle(fontSize: 13, color: uiTokens.gray600),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Назад в «Мои заявки»',
                variant: ButtonVariant.secondary,
                onTap: () => setState(() => routeName = 'my'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Пока нет предложений',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: uiTokens.gray900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Автоподборщики ещё не откликнулись. В реальном продукте здесь будет автообновление/пуш-уведомления.',
                  style: TextStyle(fontSize: 13, color: uiTokens.gray600),
                ),
              ],
            ),
          ),
        ...list.map((o) {
          final pro = getPro(o.proId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  pro?.name ?? 'Автоподборщик',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: uiTokens.gray900,
                                  ),
                                ),
                                Text(
                                  pro?.city ?? '—',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: uiTokens.gray600,
                                  ),
                                ),
                                if (pro != null) ...[
                                  Stars(value: pro.rating),
                                  Text(
                                    '${pro.completedDeals} сделок',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: uiTokens.gray600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            GridView.count(
                              crossAxisCount: isSmall ? 1 : 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 3.1,
                              children: [
                                StatBox(
                                  label: 'Цена',
                                  value: formatMoney(o.priceRub),
                                ),
                                StatBox(
                                  label: 'Срок выполнения',
                                  value: formatEtaDays(o.etaDays),
                                ),
                              ],
                            ),
                            if (o.message != null && o.message!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: uiTokens.gray900,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Комментарий: ',
                                        style:
                                            TextStyle(color: uiTokens.gray600),
                                      ),
                                      TextSpan(text: o.message!),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              formatDate(o.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: uiTokens.gray400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 10,
                        children: [
                          AppButton(
                            label: 'Подробная информация по автоподборщику',
                            variant: ButtonVariant.secondary,
                            onTap: () =>
                                setState(() => drawerProId = o.proId),
                          ),
                          AppButton(
                            label: 'Выбрать этого автоподборщика',
                            onTap: () => selectOffer(o.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (drawerProId != null)
          AppDrawerRight(
            title: 'Информация об автоподборщике',
            onClose: () => setState(() => drawerProId = null),
            isSmall: isSmall,
            child: _buildProDrawer(),
          ),
      ],
    );
  }

  Widget _buildProDrawer() {
    final pro = drawerProId == null
        ? null
        : pros.firstWhere((p) => p.id == drawerProId, orElse: () => pros.first);
    if (pro == null) {
      return Text(
        'Профиль не найден.',
        style: TextStyle(fontSize: 13, color: uiTokens.gray600),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          pro.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: uiTokens.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          pro.city,
          style: TextStyle(fontSize: 13, color: uiTokens.gray600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Stars(value: pro.rating),
            Text(
              '${pro.completedDeals} завершенных сделок',
              style: TextStyle(fontSize: 12, color: uiTokens.gray600),
            ),
            Text(
              '${pro.yearsExp} лет опыта',
              style: TextStyle(fontSize: 12, color: uiTokens.gray600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'О себе',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: uiTokens.gray900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pro.about,
                style: TextStyle(
                  fontSize: 13,
                  color: uiTokens.gray900,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Выполненные сделки',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: uiTokens.gray900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'MVP-упрощение: вместо списка сделок показываем агрегат. Далее можно добавить ленту выполненных заявок и отзывы.',
                style: TextStyle(fontSize: 13, color: uiTokens.gray600),
              ),
              const SizedBox(height: 10),
              Text(
                '${pro.completedDeals}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: uiTokens.gray900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  const _CheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: uiTokens.gray900,
            ),
          ),
        ],
      ),
    );
  }
}

class CarRow extends StatelessWidget {
  const CarRow({
    super.key,
    required this.item,
    required this.index,
    required this.onChange,
    required this.onRemove,
    required this.canRemove,
    required this.errors,
    required this.collapsed,
    required this.onToggle,
    required this.showManualFields,
    required this.onToggleManual,
    required this.years,
    required this.isSmall,
    required this.brandOptions,
    required this.brandHint,
    required this.onBrandSearch,
    required this.onBrandOpen,
    required this.modelOptions,
    required this.modelHint,
    required this.onModelOpen,
    required this.brandAliases,
  });

  final CarItem item;
  final int index;
  final void Function(Map<String, String>) onChange;
  final VoidCallback onRemove;
  final bool canRemove;
  final Map<String, String> errors;
  final bool collapsed;
  final VoidCallback onToggle;
  final bool showManualFields;
  final VoidCallback onToggleManual;
  final List<String> years;
  final bool isSmall;
  final List<String> brandOptions;
  final String? brandHint;
  final ValueChanged<String> onBrandSearch;
  final VoidCallback onBrandOpen;
  final List<String> modelOptions;
  final String? modelHint;
  final VoidCallback onModelOpen;
  final Map<String, String> brandAliases;

  @override
  Widget build(BuildContext context) {
    final makes = brandOptions;
    final models = modelOptions;
    final restylings = item.make.isNotEmpty &&
            item.model.isNotEmpty &&
            carCatalog[item.make]?[item.model] != null
        ? carCatalog[item.make]![item.model]!
        : <String>[];

    String headerTitle() {
      final link = item.sourceUrl.trim();
      if (link.isNotEmpty) return 'Ссылка: ${shortListingLabel(link)}';
      final plate = item.plate.trim();
      if (plate.isNotEmpty) return 'Госномер: $plate';
      if (item.make.isNotEmpty && item.model.isNotEmpty) {
        return '${item.make} ${item.model}${item.restyling.isNotEmpty ? ' ${item.restyling}' : ''}${item.year.isNotEmpty ? ' ${item.year}' : ''}';
      }
      return 'Автомобиль №${index + 1}';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: uiTokens.gray300),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: uiTokens.gray900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canRemove)
                    InkWell(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: uiTokens.red100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: uiTokens.red200),
                        ),
                        child: const Text(
                          'Удалить',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      border: Border.all(color: uiTokens.gray300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      collapsed ? Icons.expand_more : Icons.expand_less,
                      size: 16,
                      color: uiTokens.gray900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: uiTokens.gray300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    AppField(
                      label: 'Ссылка на объявление (avito/drom/auto.ru)',
                      hint: errors['sourceUrl'],
                      child: AppInput(
                        value: item.sourceUrl,
                        placeholder: null,
                        onChanged: (v) => onChange({'sourceUrl': v}),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      AppButton(
                        label: showManualFields
                            ? 'Скрыть дополнительные поля'
                            : 'Нет ссылки — ввести данные',
                        variant: ButtonVariant.secondary,
                        onTap: onToggleManual,
                      ),
                    ],
                  ),
                  if (showManualFields) ...[
                    const SizedBox(height: 12),
                    AppField(
                      label: 'Заметка',
                      hint: errors['note'],
                      child: AppInput(
                        value: item.note,
                        placeholder: 'Например: желательно без ДТП',
                        onChanged: (v) => onChange({'note': v}),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: isSmall ? 1 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3.3,
                      children: [
                        AppField(
                          label: 'Госномер',
                          hint: errors['plate'],
                          child: AppInput(
                            value: item.plate,
                            placeholder: 'Например: A123BC77',
                            onChanged: (v) => onChange({'plate': v}),
                          ),
                        ),
                        AppField(
                          label: 'VIN',
                          hint: errors['vin'],
                          child: AppInput(
                            value: item.vin,
                            placeholder: 'VIN',
                            onChanged: (v) => onChange({'vin': v}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      label: 'Телефон продавца',
                      required: errors['sellerPhone'] != null,
                      hint: errors['sellerPhone'],
                      child: AppInput(
                        value: item.sellerPhone,
                        placeholder: '79180010001',
                        keyboardType: TextInputType.phone,
                        onChanged: (v) => onChange({'sellerPhone': v}),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Данные автомобиля (опционально)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: uiTokens.gray900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilterMultiSelect(
                          label: 'Марка',
                          value: item.make.isNotEmpty ? [item.make] : [],
                          options: makes,
                          searchAliases: brandAliases,
                          maxVisibleItems: 10,
                          maxSelection: 1,
                          closeOnSelect: true,
                          requireApply: false,
                          onChange: (next) => onChange({
                            'make': next.isNotEmpty ? next.last : '',
                          }),
                        ),
                        const SizedBox(height: 12),
                        AvitoDropdownSelect(
                          label: 'Модель',
                          value: item.model.isNotEmpty ? [item.model] : [],
                          options: models,
                          onChange: (next) =>
                              onChange({'model': next.isNotEmpty ? next.last : ''}),
                          disabled: item.make.isEmpty,
                          hint: errors['model'] ?? modelHint,
                          mode: AvitoSelectMode.single,
                          onOpen: onModelOpen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: isSmall ? 1 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3.3,
                      children: [
                        AvitoDropdownSelect(
                          label: 'Поколение / кузов',
                          value: item.restyling.isNotEmpty ? [item.restyling] : [],
                          options: restylings,
                          onChange: (next) => onChange(
                              {'restyling': next.isNotEmpty ? next.last : ''}),
                          disabled: item.make.isEmpty || item.model.isEmpty,
                          hint: errors['restyling'],
                          mode: AvitoSelectMode.single,
                        ),
                        AppField(
                          label: 'Год',
                          hint: errors['year'],
                          child: AppSelect<String>(
                            value: item.year.isNotEmpty
                                ? item.year
                                : (years.isNotEmpty ? years.first : ''),
                            items: years,
                            label: (v) => v,
                            enabled: item.restyling.isNotEmpty,
                            onChanged: (v) =>
                                onChange({'year': v ?? ''}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

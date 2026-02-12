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
import 'package:flutter/scheduler.dart';







String _formatDate(DateTime value) {



  final day = value.day.toString().padLeft(2, '0');



  final month = value.month.toString().padLeft(2, '0');



  return '$day.$month.${value.year}';



}

String _formatDateIso(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? _tryParseRuDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(raw);
  if (match == null) return null;
  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  final lastDay = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > lastDay) return null;
  return DateTime(year, month, day);
}





class _RuDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final length = digits.length.clamp(0, 8);
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
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


bool _looksNumericCode(String value) {



  final trimmed = value.trim();



  if (trimmed.isEmpty) return false;



  return RegExp(r'^\d+$').hasMatch(trimmed);



}



bool _matchesRestylingQuery(_RestylingCardData data, String query) {



  final q = query.trim().toLowerCase();



  if (q.isEmpty) return true;



  return data.title.toLowerCase().contains(q) ||



      data.subtitle.toLowerCase().contains(q);



}



String _fallbackRestylingTitle(String rawValue) {



  final trimmed = rawValue.trim();



  if (trimmed.isEmpty) return 'Поколение';



  if (trimmed == 'Без рестайлинга') return trimmed;



  if (RegExp(r'^rest:\d+$').hasMatch(trimmed)) return 'Поколение';



  if (RegExp(r'^gen:\d+\|').hasMatch(trimmed)) return 'Поколение';



  return trimmed;



}

Widget _twoColumn(
  BuildContext context, {
  required Widget left,
  required Widget right,
  double gap = 12,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final bool stacked = constraints.maxWidth < 360;
      if (stacked) {
        return Column(
          children: [
            left,
            SizedBox(height: gap),
            right,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: gap),
          Expanded(child: right),
        ],
      );
    },
  );
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



      'city': 'Алматы',



      'responseHours': 2,



      'price': 42000,



      'days': 5,



      'photos': [



        'assets/car_hub/images/dm_image.png',



        'assets/car_hub/images/dummy_map.png',



        'assets/car_hub/images/no_image_found.png',



      ],



      'about':



          'Подбираю автомобили под ключ. Специализация: немецкие и японские марки.',



      'extra': '\u041E\u0441\u043C\u043E\u0442\u0440 \u0438 \u0442\u043E\u0440\u0433 \u043F\u043E \u0433\u043E\u0440\u043E\u0434\u0443, \u0440\u0430\u0431\u043E\u0442\u0430\u044E \u0441 \u0432\u044B\u0435\u0437\u0434\u043E\u043C.',



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



      'city': '\u041D\u0443\u0440-\u0421\u0443\u043B\u0442\u0430\u043D',



      'responseHours': 4,



      'price': 35000,



      'days': 7,



      'photos': [



        'assets/car_hub/images/dm_image.png',



        'assets/car_hub/images/events.png',



        'assets/car_hub/images/no_image_found.png',



      ],



      'about': '\u041E\u0441\u043C\u043E\u0442\u0440\u044B \u043F\u043E \u0433\u043E\u0440\u043E\u0434\u0443: \u044E\u0440\u0438\u0434\u0438\u0447\u0435\u0441\u043A\u0430\u044F \u043F\u0440\u043E\u0432\u0435\u0440\u043A\u0430, \u0434\u0438\u0430\u0433\u043D\u043E\u0441\u0442\u0438\u043A\u0430, \u0442\u043E\u0440\u0433.',



      'extra': '\u0420\u0430\u0431\u043E\u0442\u0430\u044E \u043F\u043E \u0433\u043E\u0440\u043E\u0434\u0443 \u0438 \u043E\u0431\u043B\u0430\u0441\u0442\u0438, \u043F\u043E\u043C\u043E\u0433\u0430\u044E \u0441 \u043E\u0444\u043E\u0440\u043C\u043B\u0435\u043D\u0438\u0435\u043C.',



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



      'about': '\u041F\u0440\u0435\u043C\u0438\u0430\u043B\u044C\u043D\u044B\u0435 \u0430\u0432\u0442\u043E \u0438 \u0432\u043D\u0435\u0434\u043E\u0440\u043E\u0436\u043D\u0438\u043A\u0438, \u0441\u043E\u043F\u0440\u043E\u0432\u043E\u0436\u0434\u0435\u043D\u0438\u0435 \u0441\u0434\u0435\u043B\u043A\u0438.',



      'extra': '\u041F\u0440\u043E\u0432\u0435\u0440\u043A\u0430 \u0438\u0441\u0442\u043E\u0440\u0438\u0438, \u0434\u0438\u0430\u0433\u043D\u043E\u0441\u0442\u0438\u043A\u0430, \u0444\u043E\u0442\u043E/\u0432\u0438\u0434\u0435\u043E \u043E\u0442\u0447\u0451\u0442.',



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



              '\u0417\u0430\u044F\u0432\u043A\u0430 \u0441\u043E\u0437\u0434\u0430\u043D\u0430. \u041F\u0435\u0440\u0435\u0439\u0434\u0438\u0442\u0435 \u0432 \u00AB\u041C\u043E\u0438 \u0437\u0430\u044F\u0432\u043A\u0438\u00BB.',



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



  static final Map<String, bool> modelsLoading = {};



  static final Map<String, bool> restylingsLoading = {};







  static String _modelKey(int brandId, String model) {



    return '$brandId|$model';



  }







  static String _restylingKey(int brandId, String model, String restyling) {



    return '$brandId|$model|$restyling';



  }

  static String _restylingValueFor(GenerationItem gen, RestylingItem rest) {
    if (rest.id > 0) {
      return 'rest:${rest.id}';
    }
    final start = rest.yearStart?.toString() ?? 'na';
    final end = rest.yearEnd?.toString() ?? 'na';
    final raw = rest.restyling.trim().isEmpty ? 'none' : rest.restyling.trim();
    return 'gen:${gen.generation}|rest:$raw|$start-$end';
  }

  static String _restylingLabelFor(RestylingItem rest) {
    final raw = rest.restyling.trim();
    if (raw.isEmpty) {
      return '\u0411\u0435\u0437 \u0440\u0435\u0441\u0442\u0430\u0439\u043b\u0438\u043d\u0433\u0430';
    }
    return raw;
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



      for (final gen in generations) {



        for (final rest in gen.restylings) {



          final value = _restylingValueFor(gen, rest);
          final label = _restylingLabelFor(rest);

          restylings.add(value);



          restylingMetaByKey.putIfAbsent(



            _restylingKey(brandId, model, value),



            () => _RestylingMeta(



              generation: gen.generation,
              restylingId: rest.id,



              yearStart: rest.yearStart,



              yearEnd: rest.yearEnd,



              frames: rest.frames



                  .map((e) => e.frame.trim())



                  .where((e) => e.isNotEmpty)



                  .toSet()



                  .toList(),
              restylingLabel: label,



            ),



          );



          if (rest.photos.isNotEmpty &&



              !restylingPhotoByKey.containsKey(



                _restylingKey(brandId, model, value),



              )) {



            final photo = rest.photos.firstWhere(



              (p) => p.size.toLowerCase() == 'm',



              orElse: () => rest.photos.first,



            );



            final url = photo.urlX1.isNotEmpty ? photo.urlX1 : photo.urlX2;



            if (url.isNotEmpty) {



              restylingPhotoByKey[_restylingKey(brandId, model, value)] = url;



            }



          }



        }



      }



      restylingsByKey[modelKey] = restylings.toList()..sort();
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

  static int? restylingIdFor(
    String make,
    String model,
    String restyling,
  ) {
    final meta = restylingMetaFor(make, model, restyling);
    final id = meta?.restylingId;
    if (id != null && id > 0) return id;
    return _parseRestylingId(restyling);
  }

  static int? _parseRestylingId(String value) {
    final match = RegExp(r'^rest:(\d+)$').firstMatch(value.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
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

    return DefaultTabController(

      length: 2,

      child: Scaffold(

        appBar: AppBar(

          title: const Text('Создание заявки'),

          bottom: PreferredSize(

            preferredSize: const Size.fromHeight(56),

            child: Padding(

              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),

              child: Material(

                color: kWhiteColor,

                borderRadius: BorderRadius.circular(12),

                child: Container(

                  decoration: BoxDecoration(

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

                      Tab(text: 'По авто'),

                      Tab(text: 'Под ключ'),

                    ],

                  ),

                ),

              ),

            ),

          ),

        ),

        body: GestureDetector(

          behavior: HitTestBehavior.translucent,

          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),

          child: TabBarView(

            children: [_ByCarForm(), _TurnkeyForm()],

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




  DateTime? _dueDate;
  final TextEditingController _dueDateController = TextEditingController();
  String _dueDateError = '';






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
    _dueDateController.dispose();



    super.dispose();



  }







  void _handleRemoteUpdate() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
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

  void _onDueDateChanged(String value) {
    if (_dueDateError.isNotEmpty) {
      setState(() {
        _dueDateError = '';
      });
    }
    _dueDate = _tryParseRuDate(value);
  }

  bool _validateDueDate() {
    _dueDateError = '';
    final raw = _dueDateController.text.trim();
    if (raw.isEmpty) {
      _dueDate = null;
      return true;
    }
    final parsed = _tryParseRuDate(raw);
    if (parsed == null) {
      _dueDate = null;
      _dueDateError = 'Укажите дату в формате ДД.ММ.ГГГГ';
      return false;
    }
    _dueDate = parsed;
    return true;
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











  String _restylingDisplayFor(String make, String model, String restyling) {



    if (restyling.trim().isEmpty) return '';



    final data = _buildRestylingCardDataFor(make, model, restyling);



    return data.title;



  }

  List<int> _restylingIdsForCar(_CarItem car) {
    final id = _RemoteCarCatalog.restylingIdFor(
      car.make,
      car.model,
      car.restyling,
    );
    if (id == null || id <= 0) return const [];
    return [id];
  }







  static bool _isCarEmpty(_CarItem c) {



    final fields = [



      c.sourceUrl.trim(),



      c.sellerPhone.trim(),



      c.note?.trim() ?? '',



      c.make.trim(),



      c.model.trim(),



      c.restyling.trim(),



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











        if (patch.make != null) {



          _cars[i] = next.copyWith(



            _CarItemPatch(model: '', restyling: ''),



          );



          final make = patch.make ?? '';



          if (make.isNotEmpty) {



            _RemoteCarCatalog.ensureModels(make);



          }



          return;



        }



        if (patch.model != null) {



          _cars[i] = next.copyWith(_CarItemPatch(restyling: ''));



          final make = next.make;



          final model = patch.model ?? '';



          if (make.isNotEmpty && model.isNotEmpty) {



            _RemoteCarCatalog.ensureRestylings(make, model);



          }



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
    final dueDateValid = _validateDueDate();







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



          c.restyling.trim().isNotEmpty;







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



      }







      if (ce.isNotEmpty) _carErrors[c.id] = ce;



    }







    for (final id in toOpen) {



      _manualOpen[id] = true;



    }







    setState(() {});



    return _formError.isEmpty && _carErrors.isEmpty && dueDateValid;



  }







    Future<void> _submitByCar() async {
    if (!_validateCars()) return;

    final activeCars = _cars.where((c) => !_isCarEmpty(c)).toList();
    if (activeCars.isEmpty) return;

    final dueAt = _dueDate == null ? null : _formatDateIso(_dueDate!);
    final requestCars = activeCars.map((c) {
      final phone = c.sellerPhone.trim();
      final url = c.sourceUrl.trim();
      return {
        'restylings': _restylingIdsForCar(c),
        'phone': phone.isEmpty ? null : phone,
        'url': url.isEmpty ? null : url,
        if (dueAt != null) 'dueAt': dueAt,
      };
    }).toList();
    final displayCars = activeCars.map((c) {
      final restDisplay = _restylingDisplayFor(c.make, c.model, c.restyling);
      final phone = c.sellerPhone.trim();
      final url = c.sourceUrl.trim();
      return {
        'make': c.make,
        'makeName': c.make,
        'brandName': c.make,
        'model': c.model,
        'modelName': c.model,
        'modelRus': c.model,
        if (c.restyling.trim().isNotEmpty) 'restyling': c.restyling,
        if (restDisplay.trim().isNotEmpty) 'restylingName': restDisplay.trim(),
        if (phone.isNotEmpty) 'phone': phone,
        if (url.isNotEmpty) 'url': url,
        if (dueAt != null) 'dueAt': dueAt,
      };
    }).toList();

    try {
      final result = await StorageApi.createRequest(
        requestType: 'by_car',
        requestCars: requestCars,
      );
      final override = <String, dynamic>{'requestCars': displayCars};
      if (result.id > 0) {
        await UserSimplePreferences.setRequestDisplayOverride(
          result.id.toString(),
          override,
        );
      }
      if (result.requestNumber.trim().isNotEmpty) {
        await UserSimplePreferences.setRequestDisplayOverride(
          result.requestNumber.trim(),
          override,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку.')),
        );
      }
      return;
    }

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
    final list = <String>[];
    final seen = <String>{};

    void addUnique(String value) {
      if (value.isEmpty) return;
      if (seen.add(value)) list.add(value);
    }

    addUnique(hint);

    if (options.isNotEmpty) {
      for (final opt in options) {
        if (opt != hint) addUnique(opt);
      }
    } else if (loading) {
      addUnique('Загрузка...');
    }

    if (selected.isNotEmpty) addUnique(selected);
    return list;
  }

  Future<void> _openRestylingPickerForCar(_CarItem car) async {



    if (car.make.trim().isEmpty || car.model.trim().isEmpty) {



      ScaffoldMessenger.of(context).showSnackBar(



        const SnackBar(content: Text('Сначала выберите марку и модель.')),



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



            final media = MediaQuery.of(ctx);



            final sheetHeight =



                (media.size.height - media.padding.top) * 0.88;







            return AnimatedPadding(



              duration: const Duration(milliseconds: 120),



              curve: Curves.easeOut,



              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),



              child: SafeArea(



                child: Padding(



                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),



                  child: SizedBox(



                    height: sheetHeight,



                    child: Column(



                      mainAxisSize: MainAxisSize.max,



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



                              final options = _RemoteCarCatalog.restylingsFor(



                                car.make,



                                car.model,



                              );



                              final items = options



                                  .map(



                                    (rest) => _buildRestylingCardDataFor(



                                      car.make,



                                      car.model,



                                      rest,



                                    ),



                                  )



                                  .where(



                                    (item) => _matchesRestylingQuery(item, query),



                                  )



                                  .toList();



                              final loading =



                                  _RemoteCarCatalog.isRestylingsLoading(



                                car.make,



                                car.model,



                              );







                              if (items.isEmpty && loading) {



                                return const Center(



                                  child: CircularProgressIndicator(strokeWidth: 2),



                                );



                              }







                              if (items.isEmpty) {



                                return const Center(



                                  child: MyText(



                                    text: 'Ничего не найдено',



                                    size: 12,



                                    color: kGreyColor,



                                  ),



                                );



                              }







                              return ListView.separated(



                                padding: const EdgeInsets.only(bottom: 6),



                                itemCount: items.length,



                                separatorBuilder: (_, __) =>



                                    const SizedBox(height: 12),



                                itemBuilder: (context, index) {



                                  final data = items[index];



                                  final selected = car.restyling == data.value;



                                  return SizedBox(



                                    width: double.infinity,



                                    child: _RestylingCard(



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



                                    ),



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



    final baseRestLabel = meta?.restylingLabel ?? rest;
    final restLabel = baseRestLabel == '\u0411\u0435\u0437 \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433\u0430' ? '' : baseRestLabel;



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



        subtitle += ', \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';



      }



    } else if (restLabel.isNotEmpty) {



      subtitle = '\u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';



    }







    return _RestylingCardData(



      value: rest,



      title: title.isEmpty
          ? _fallbackRestylingTitle(
              restLabel.isEmpty ? baseRestLabel : restLabel,
            )
          : title,



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



      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,



      padding: AppSizes.listPaddingWithBottomBar(),



      children: [



        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 6,
          spacing: 8,



          children: [



            MyText(



              text:



                  '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u0438 (${_cars.length})',



              size: 16,



              weight: FontWeight.w700,



            ),






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
        MyTextField(
          labelText: '\u0421\u0440\u043e\u043a \u0432\u044b\u043f\u043e\u043b\u043d\u0435\u043d\u0438\u044f \u0434\u043e',
          hintText: '\u0414\u0414.\u041c\u041c.\u0413\u0413\u0413\u0413',
          controller: _dueDateController,
          keyboardType: TextInputType.number,
          inputFormatters: [_RuDateFormatter()],
          onChanged: _onDueDateChanged,
        ),
        _ErrorText(text: _dueDateError),
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



    if (item.make.isNotEmpty && item.model.isNotEmpty) {



      return '${item.make} ${item.model}'



          '${restylingDisplay.isNotEmpty ? ' $restylingDisplay' : ''}';



    }



    return '\u0410\u0432\u0442\u043E\u043C\u043E\u0431\u0438\u043B\u044C \u2116${index + 1}';



  }







  @override



  Widget build(BuildContext context) {



    final makes = makeOptions;



    final models = modelOptions;



    final restylings = restylingOptions;



    final makeItems = withHint(



      '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u0430\u0440\u043A\u0443',



      makes,



      item.make,



      loading: makeLoading,



    );



    final modelItems = withHint(



      '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043C\u043E\u0434\u0435\u043B\u044C',



      models,



      item.model,



      loading: modelLoading,



    );



    final restylingItems = withHint(



      '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435',



      restylings,



      item.restyling,



      loading: restylingLoading,



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



                    const SizedBox(height: 12),



                    MyTextField(



                      labelText:



                          '\u0422\u0435\u043B\u0435\u0444\u043E\u043D \u043F\u0440\u043E\u0434\u0430\u0432\u0446\u0430',



                      hintText: '+7',



                      keyboardType: TextInputType.number,
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



                    _twoColumn(
                      context,
                      left: CustomDropDown(
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
                      right: CustomDropDown(
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



                    _ErrorText(text: errors['make']),



                    _ErrorText(text: errors['model']),



                    _SelectField(
                      label:
                          '\u041F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435 / \u043A\u0443\u0437\u043E\u0432',
                      placeholder: '\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435 \u043F\u043E\u043A\u043E\u043B\u0435\u043D\u0438\u0435',
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



                    _ErrorText(text: errors['restyling']),



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



    this.sourceUrl = '',



    this.sellerPhone = '',



    this.note = '',



  });







  final String id;



  final String make;



  final String model;



  final String restyling;



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



    this.sourceUrl,



    this.sellerPhone,



    this.note,



  });







  final String? make;



  final String? model;



  final String? restyling;



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




  DateTime? _dueDate;
  final TextEditingController _dueDateController = TextEditingController();
  String _dueDateError = '';






  @override



  void initState() {



    super.initState();



    _RemoteCarCatalog.stamp.addListener(_handleRemoteUpdate);



    _RemoteCarCatalog.ensureBrands();



  }







  @override



  void dispose() {



    _RemoteCarCatalog.stamp.removeListener(_handleRemoteUpdate);
    _dueDateController.dispose();



    super.dispose();



  }







  void _handleRemoteUpdate() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }







    void _onDueDateChanged(String value) {
    if (_dueDateError.isNotEmpty) {
      setState(() {
        _dueDateError = '';
      });
    }
    _dueDate = _tryParseRuDate(value);
  }

  bool _validateDueDate() {
    _dueDateError = '';
    final raw = _dueDateController.text.trim();
    if (raw.isEmpty) {
      _dueDate = null;
      return true;
    }
    final parsed = _tryParseRuDate(raw);
    if (parsed == null) {
      _dueDate = null;
      _dueDateError = 'Укажите дату в формате ДД.ММ.ГГГГ';
      return false;
    }
    _dueDate = parsed;
    return true;
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



            final media = MediaQuery.of(ctx);



            final sheetHeight =



                (media.size.height - media.padding.top) * 0.88;







            return AnimatedPadding(



              duration: const Duration(milliseconds: 120),



              curve: Curves.easeOut,



              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),



              child: SafeArea(



                child: Padding(



                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),



                  child: SizedBox(



                    height: sheetHeight,



                    child: Column(



                      mainAxisSize: MainAxisSize.max,



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



                              final items = options



                                  .map((rest) => _buildRestylingCardData(rest))



                                  .where(



                                    (item) => _matchesRestylingQuery(item, query),



                                  )



                                  .toList();







                              if (items.isEmpty) {



                                return const Center(



                                  child: MyText(



                                    text: 'Ничего не найдено',



                                    size: 12,



                                    color: kGreyColor,



                                  ),



                                );



                              }







                              return ListView.separated(



                                padding: const EdgeInsets.only(bottom: 6),



                                itemCount: items.length,



                                separatorBuilder: (_, __) =>



                                    const SizedBox(height: 12),



                                itemBuilder: (context, index) {



                                  final data = items[index];



                                  final selected = temp.contains(data.value);



                                  return SizedBox(



                                    width: double.infinity,



                                    child: _RestylingCard(



                                      title: data.title,



                                      subtitle: data.subtitle,



                                      imageUrl: data.imageUrl,



                                      selected: selected,



                                      onTap: () => setSheet(() {



                                        if (selected) {



                                          temp.remove(data.value);



                                        } else {



                                          temp.add(data.value);



                                        }



                                      }),



                                    ),



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



    final baseRestLabel = meta?.restylingLabel ?? restName;
    final restLabel = baseRestLabel == '\u0411\u0435\u0437 \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433\u0430' ? '' : baseRestLabel;



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



        subtitle += ', \u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';



      }



    } else if (restLabel.isNotEmpty) {



      subtitle = '\u0440\u0435\u0441\u0442\u0430\u0439\u043B\u0438\u043D\u0433';



    }







    return _RestylingCardData(



      value: rest,



      title: title.isEmpty
          ? _fallbackRestylingTitle(
              restLabel.isEmpty ? baseRestLabel : restLabel,
            )
          : title,



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
  int? _turnkeyRestylingIdFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('|');
    if (parts.length >= 3) {
      final make = parts[0].trim();
      final model = parts[1].trim();
      final restName = parts.sublist(2).join('|').trim();
      final id = _RemoteCarCatalog.restylingIdFor(make, model, restName);
      if (id != null && id > 0) return id;
    }

    final directId = _RemoteCarCatalog.restylingIdFor('', '', trimmed);
    if (directId != null && directId > 0) return directId;

    final makes = _tkMakes.isNotEmpty ? _tkMakes : _carCatalog.keys.toList();
    final selectedModels = _tkModels;
    for (final make in makes) {
      final models = selectedModels.isNotEmpty
          ? selectedModels
          : _RemoteCarCatalog.modelsFor(make);
      for (final model in models) {
        final id = _RemoteCarCatalog.restylingIdFor(make, model, trimmed);
        if (id != null && id > 0) return id;
      }
    }

    return null;
  }
    Future<void> _submitTurnkey() async {
    final dueDateValid = _validateDueDate();
    if (!dueDateValid) {
      setState(() {});
      return;
    }

    final restylingIds = _tkRestylings
        .map(_turnkeyRestylingIdFor)
        .whereType<int>()
        .toSet()
        .toList();
    final dueAt = _dueDate == null ? null : _formatDateIso(_dueDate!);
    final requestCars = restylingIds.isEmpty
        ? [
            {
              'restylings': <int>[],
              'phone': null,
              'url': null,
              if (dueAt != null) 'dueAt': dueAt,
            }
          ]
        : restylingIds
            .map(
              (id) => {
                'restylings': [id],
                'phone': null,
                'url': null,
                if (dueAt != null) 'dueAt': dueAt,
              },
            )
            .toList();

    try {
      await StorageApi.createRequest(
        requestType: 'turnkey',
        requestCars: requestCars,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить заявку.')),
        );
      }
      return;
    }

    if (!mounted) return;

    _showCreatedSnack(context);

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }








  @override



  Widget build(BuildContext context) {



    return ListView(



      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,



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



        _twoColumn(
          context,
          left: MyTextField(
            labelText: '\u0411\u044E\u0434\u0436\u0435\u0442 \u043E\u0442',
            hintText: '2500000',
            marginBottom: 0,
          ),
          right: MyTextField(
            labelText: '\u0411\u044E\u0434\u0436\u0435\u0442 \u0434\u043E',
            hintText: '3500000',
            marginBottom: 0,
          ),
        ),



        const SizedBox(height: 16),
        MyTextField(
          labelText: '\u0421\u0440\u043e\u043a \u0432\u044b\u043f\u043e\u043b\u043d\u0435\u043d\u0438\u044f \u0434\u043e',
          hintText: '\u0414\u0414.\u041c\u041c.\u0413\u0413\u0413\u0413',
          controller: _dueDateController,
          keyboardType: TextInputType.number,
          inputFormatters: [_RuDateFormatter()],
          onChanged: _onDueDateChanged,
        ),
        _ErrorText(text: _dueDateError),
        const SizedBox(height: 16),



        _twoColumn(
          context,
          left: _MultiSelectField(
            label: '\u041C\u0430\u0440\u043A\u0430',
            placeholder: '\u041B\u044E\u0431\u0430\u044F',
            value: _tkMakes,
            onTap: () => _openMultiSelect(
              title: '\u041C\u0430\u0440\u043A\u0430',
              options: _allMakes(),
              initial: _tkMakes,
              onApply: _setMakes,
            ),
          ),
          right: _MultiSelectField(
            label: '\u041C\u043E\u0434\u0435\u043B\u044C',
            placeholder: '\u041B\u044E\u0431\u0430\u044F',
            value: _tkModels,
            onTap: () => _openMultiSelect(
              title: '\u041C\u043E\u0434\u0435\u043B\u044C',
              options: _allModelsForMakes(_tkMakes),
              initial: _tkModels,
              onApply: _setModels,
            ),
          ),
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



        _twoColumn(
          context,
          left: MyTextField(
            labelText: '\u041F\u0440\u043E\u0431\u0435\u0433 \u0434\u043E',
            hintText: '120000',
            marginBottom: 0,
          ),
          right: MyTextField(
            labelText:
                '\u041A\u043E\u043B\u0438\u0447\u0435\u0441\u0442\u0432\u043E \u0432\u043B\u0430\u0434\u0435\u043B\u044C\u0446\u0435\u0432',
            hintText: '2',
            marginBottom: 0,
          ),
        ),



        const SizedBox(height: 16),



        MyTextField(
          labelText: '\u0417\u0430\u043c\u0435\u0442\u043a\u0430',
          hintText:
              '\u041f\u043e\u0436\u0435\u043b\u0430\u043d\u0438\u044f, \u043e\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u044f, \u043e\u043f\u0446\u0438\u0438',
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



        ? '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430...'



        : enabled



        ? placeholder



        : '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0432\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043c\u0430\u0440\u043a\u0443 \u0438 \u043c\u043e\u0434\u0435\u043b\u044c';



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
    required this.restylingId,



    required this.yearStart,



    required this.yearEnd,



    required this.frames,
    required this.restylingLabel,



  });







  final int generation;
  final int? restylingId;



  final int? yearStart;



  final int? yearEnd;



  final List<String> frames;
  final String restylingLabel;



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






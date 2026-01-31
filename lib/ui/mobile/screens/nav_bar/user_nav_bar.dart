import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/constants/popular_cars_ru.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/auto_request_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/my_requests_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/reports/report_detail.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_drawer/u_drawer.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/inspectors/inspectors_screen.dart';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class UserNavBar extends StatefulWidget {
  const UserNavBar({super.key});

  @override
  State<UserNavBar> createState() => _UserNavBarState();
}

class _UserNavBarState extends State<UserNavBar> {
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    3,
    (_) => GlobalKey<NavigatorState>(),
  );
  final ValueNotifier<int> _requestsRefresh = ValueNotifier<int>(0);

  void _getCurrentIndex(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    if (index == 1) {
      _requestsRefresh.value++;
    }
  }

  final _key = GlobalKey<ScaffoldState>();
  String _query = '';
  String _sortOrder =
      '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435';
  List<String> _selectedMakes = [];
  List<String> _selectedModels = [];
  List<String> _selectedStatuses = [];
  List<String> _selectedInspectors = [];
  List<String> _brandOptions = [];
  Map<String, String> _brandRusByName = {};
  bool _brandLoading = false;
  bool _brandFallback = false;
  Timer? _brandRetryTimer;
  int _brandRetryCount = 0;
  String _brandError = '';
  static const Duration _brandCacheTtl = Duration(hours: 24);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadBrands();
  }

  @override
  void dispose() {
    _brandRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final query = await UserSimplePreferences.getReportQuery();
    final sort = await UserSimplePreferences.getReportSortOrder();
    final makes = await UserSimplePreferences.getReportMakes();
    final models = await UserSimplePreferences.getReportModels();
    final inspectors = await UserSimplePreferences.getReportInspectors();
    final verdicts = await UserSimplePreferences.getReportVerdicts();
    if (!mounted) return;
    setState(() {
      _query = query ?? '';
      _sortOrder =
          sort ??
          '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435';
      _selectedMakes = makes ?? [];
      _selectedModels = models ?? [];
      _selectedInspectors = inspectors ?? [];
      _selectedStatuses = verdicts ?? [];
    });
  }

  Future<void> _loadBrands({bool forceRefresh = false}) async {
    if (_brandLoading) return;
    _brandRetryTimer?.cancel();
    setState(() => _brandLoading = true);
    try {
      const int maxAttempts = 2;
      Object? lastError;
      for (int i = 0; i < maxAttempts; i++) {
        try {
          final catalog = await StorageApi.fetchBrandCatalog();
          final sortedNames = sortMakesByPopularity(catalog.names);
          if (!mounted) return;
          setState(() {
            _brandOptions = sortedNames;
            _brandRusByName = catalog.rusByName;
            _brandLoading = false;
            _brandError = '';
            _brandRetryCount = 0;
            _brandFallback = false;
          });
          await UserSimplePreferences.setBrandCache(
            sortedNames,
            catalog.rusByName,
          );
          return;
        } catch (e) {
          lastError = e;
          if (i < maxAttempts - 1) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      throw lastError ?? Exception('Brand fetch failed');
    } catch (_) {
      final cached = await UserSimplePreferences.getBrandCache();
      final cachedRus = await UserSimplePreferences.getBrandRusCache();
      if (!mounted) return;
      setState(() {
        if (cached != null && cached.isNotEmpty) {
          _brandOptions = sortMakesByPopularity(cached);
          _brandRusByName = cachedRus;
        } else if (_brandOptions.isEmpty) {
          _brandOptions = sortMakesByPopularity(kPopularMakesRu);
        }
        _brandLoading = false;
        _brandFallback = true;
        _brandError = _brandOptions.isEmpty
            ? '\u0421\u043f\u0440\u0430\u0432\u043e\u0447\u043d\u0438\u043a \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u0435\u043d, \u043f\u0440\u043e\u0431\u0443\u0435\u043c \u0441\u043d\u043e\u0432\u0430...'
            : '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0431\u043d\u043e\u0432\u0438\u0442\u044c. \u041f\u043e\u043a\u0430\u0437\u0430\u043d \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u044b\u0439 \u0441\u043f\u0438\u0441\u043e\u043a.';
      });
      _scheduleBrandRetry();
    }
  }

  void _scheduleBrandRetry() {
    if (_brandRetryCount >= 5) {
      setState(() {
        _brandError =
            '\u0421\u043f\u0440\u0430\u0432\u043e\u0447\u043d\u0438\u043a \u0432\u0440\u0435\u043c\u0435\u043d\u043d\u043e \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u0435\u043d. \u041f\u0440\u043e\u0432\u0435\u0440\u044c\u0442\u0435 \u043f\u043e\u0437\u0436\u0435.';
      });
      return;
    }
    _brandRetryCount += 1;
    final delay = Duration(seconds: 10 * (1 << (_brandRetryCount - 1)));
    _brandRetryTimer = Timer(delay, () {
      if (!mounted) return;
      _loadBrands();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'icon': Assets.imagesHome,
        'label': '\u041e\u0442\u0447\u0451\u0442\u044b',
      },
      {
        'icon': Assets.imagesCar,
        'label': '\u041c\u043e\u0438 \u0437\u0430\u044f\u0432\u043a\u0438',
      },
      {
        'icon': Assets.imagesProfile,
        'label':
            '\u0410\u0432\u0442\u043e\u043f\u043e\u0434\u0431\u043e\u0440\u0449\u0438\u043a\u0438',
      },
    ];

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      key: _key,
      drawer: UDrawer(),
      resizeToAvoidBottomInset: false,
      body: WillPopScope(
        onWillPop: _onWillPop,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, (_) => _buildHome()),
            _buildTabNavigator(
              1,
              (_) => MyRequestsScreen(refresh: _requestsRefresh),
            ),
            _buildTabNavigator(2, (_) => const InspectorsScreen()),
          ],
        ),
      ),
      bottomNavigationBar: _buildNavBar(items),
    );
  }

  Future<bool> _onWillPop() async {
    final navigator = _navigatorKeys[_currentIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    return true;
  }

  Widget _buildTabNavigator(int index, WidgetBuilder builder) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: builder, settings: settings);
      },
    );
  }

  Widget _buildNavBar(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: Border(top: BorderSide(color: kBorderColor)),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: kWhiteColor,
        elevation: 0,
        currentIndex: _currentIndex,
        onTap: (index) => _getCurrentIndex(index),
        selectedItemColor: kSecondaryColor,
        unselectedItemColor: kGreyColor,
        items: items.map((data) {
          final index = items.indexOf(data);
          return BottomNavigationBarItem(
            icon: Image.asset(
              data['icon'],
              height: 22,
              color: _currentIndex == index ? kSecondaryColor : kGreyColor,
            ),
            label: data['label'],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHome() {
    final reports = _allReports();
    final filteredReports = reports.where((r) {
      final q = _query.trim().toLowerCase();
      final hay =
          '${r['car']} ${r['inspector']} ${r['vin']} ${r['plate']} ${r['make']} ${r['model']}'
              .toLowerCase();
      if (q.isNotEmpty && !hay.contains(q)) return false;
      if (_selectedMakes.isNotEmpty && !_selectedMakes.contains(r['make'])) {
        return false;
      }
      if (_selectedModels.isNotEmpty && !_selectedModels.contains(r['model'])) {
        return false;
      }
      if (_selectedStatuses.isNotEmpty &&
          !_selectedStatuses.contains(r['verdict'])) {
        return false;
      }
      if (_selectedInspectors.isNotEmpty &&
          !_selectedInspectors.contains(r['inspector'])) {
        return false;
      }
      return true;
    }).toList();

    filteredReports.sort((a, b) {
      final ad = _parseDate(a['date'] ?? '');
      final bd = _parseDate(b['date'] ?? '');
      if (_sortOrder ==
          '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0441\u0442\u0430\u0440\u044b\u0435') {
        return ad.compareTo(bd);
      }
      return bd.compareTo(ad);
    });

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: AppSizes.listPaddingWithBottomBar(),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _key.currentState!.openDrawer(),
                    child: Image.asset(Assets.imagesMenu, height: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MyText(
                      text:
                          '\u041e\u0442\u0447\u0451\u0442\u044b \u0430\u0432\u0442\u043e\u043f\u043e\u0434\u0431\u043e\u0440\u0449\u0438\u043a\u043e\u0432',
                      size: 18,
                      weight: FontWeight.w700,
                      maxLines: 1,
                      textOverflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterIconButton(
                    active:
                        _selectedMakes.isNotEmpty ||
                        _selectedModels.isNotEmpty ||
                        _selectedStatuses.isNotEmpty ||
                        _selectedInspectors.isNotEmpty,
                    onTap: () => _openFilters(reports),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _sortOrder =
                            _sortOrder ==
                                '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435'
                            ? '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0441\u0442\u0430\u0440\u044b\u0435'
                            : '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435';
                        UserSimplePreferences.setReportSortOrder(_sortOrder);
                      });
                    },
                    icon: const Icon(Icons.sort, color: kSecondaryColor),
                    tooltip:
                        '\u0421\u043e\u0440\u0442\u0438\u0440\u043e\u0432\u043a\u0430',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSearch(),
              const SizedBox(height: 20),
              _ReportsList(reports: filteredReports),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AutoRequestScreen()),
                );
                if (created == true) {
                  _requestsRefresh.value++;
                  if (mounted) {
                    setState(() {
                      _currentIndex = 1;
                    });
                  }
                }
              },
              backgroundColor: kSecondaryColor,
              icon: const Icon(Icons.add, size: 18, color: kWhiteColor),
              label: const Text(
                '\u041d\u043e\u0432\u0430\u044f \u0437\u0430\u044f\u0432\u043a\u0430',
                style: TextStyle(color: kWhiteColor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (v) {
        setState(() => _query = v);
        UserSimplePreferences.setReportQuery(v);
      },
      decoration: InputDecoration(
        hintText:
            '\u041f\u043e\u0438\u0441\u043a: VIN, \u0433\u043e\u0441\u043d\u043e\u043c\u0435\u0440, \u043c\u0430\u0440\u043a\u0430 \u0438\u043b\u0438 \u044d\u043a\u0441\u043f\u0435\u0440\u0442',
        prefixIcon: const Icon(Icons.search, color: kSecondaryColor),
        filled: true,
        fillColor: kWhiteColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kSecondaryColor),
        ),
      ),
    );
  }

  DateTime _parseDate(String text) {
    try {
      final parts = text.split('.');
      if (parts.length != 3) return DateTime(2000);
      final d = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final y = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return DateTime(2000);
    }
  }

  List<Map<String, dynamic>> _allReports() {
    return [
      {
        'car': 'Toyota Camry 2019',
        'make': 'Toyota',
        'model': 'Camry',
        'inspector':
            '\u0418\u043b\u044c\u044f \u0412\u043b\u0430\u0441\u043e\u0432',
        'date': '12.01.2026',
        'verdict':
            '\u041c\u043e\u0436\u043d\u043e \u043f\u043e\u043a\u0443\u043f\u0430\u0442\u044c',
        'score': '8.7/10',
        'price': '2 850 000 \u20bd',
        'issues':
            '\u041c\u0435\u043b\u043a\u0438\u0435 \u0441\u043a\u043e\u043b\u044b, \u043a\u0440\u0430\u0441\u0438\u043b\u043e\u0441\u044c \u043a\u0440\u044b\u043b\u043e',
        'summary':
            '\u0410\u0432\u0442\u043e \u0432 \u0445\u043e\u0440\u043e\u0448\u0435\u043c \u0441\u043e\u0441\u0442\u043e\u044f\u043d\u0438\u0438, \u043a\u043e\u0441\u043c\u0435\u0442\u0438\u0447\u0435\u0441\u043a\u0438\u0439 \u043e\u043a\u0440\u0430\u0441 \u043e\u0434\u043d\u043e\u0433\u043e \u044d\u043b\u0435\u043c\u0435\u043d\u0442\u0430.',
        'vin': 'JTNB11HK1K3000001',
        'plate': 'A123BC77',
        'mileage': '78 000 \u043a\u043c',
        'owners': '2 \u0432\u043b\u0430\u0434\u0435\u043b\u044c\u0446\u0430',
        'engine': '2.5 \u0431\u0435\u043d\u0437\u0438\u043d',
        'transmission': 'AT',
        'drive': '\u041f\u0435\u0440\u0435\u0434\u043d\u0438\u0439',
        'reportsCount': 2,
        'images': [
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200&q=80&auto=format&fit=crop',
        ],
        'premium': {
          'paintThickness':
              '\u041b\u041a\u041f: 120-170 \u043c\u043a\u043c, \u043e\u043a\u0440\u0430\u0441\u044b: \u043f\u0435\u0440\u0435\u0434\u043d\u0435\u0435 \u043b\u0435\u0432\u043e\u0435 \u043a\u0440\u044b\u043b\u043e',
          'panelPhotos':
              '\u0424\u043e\u0442\u043e \u044d\u043b\u0435\u043c\u0435\u043d\u0442\u043e\u0432: 16/16, \u0435\u0441\u0442\u044c \u0444\u043e\u0442\u043e VIN',
          'video':
              '\u0412\u0438\u0434\u0435\u043e \u043e\u0441\u043c\u043e\u0442\u0440\u0430: 2 \u0440\u043e\u043b\u0438\u043a\u0430 (\u0445\u043e\u0434\u043e\u0432\u0430\u044f + \u0441\u0430\u043b\u043e\u043d)',
          'legal':
              '\u042e\u0440. \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0430: \u0431\u0435\u0437 \u043e\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u0439, \u0438\u0441\u0442\u043e\u0440\u0438\u044f \u0447\u0438\u0441\u0442\u0430\u044f',
        },
      },
      {
        'car': 'Volkswagen Tiguan 2018',
        'make': 'Volkswagen',
        'model': 'Tiguan',
        'inspector':
            '\u0410\u043b\u0435\u043a\u0441\u0430\u043d\u0434\u0440 \u041a\u0438\u043c',
        'date': '05.01.2026',
        'verdict':
            '\u041d\u0443\u0436\u043d\u0430 \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0430',
        'score': '7.2/10',
        'price': '2 350 000 \u20bd',
        'issues':
            '\u0417\u0430\u043c\u0435\u043d\u0430 \u0442\u043e\u0440\u043c\u043e\u0437\u043e\u0432, \u043f\u043e\u0434\u043a\u0440\u0430\u0441\u043a\u0430 \u0434\u0432\u0435\u0440\u0438',
        'summary':
            '\u041d\u0435\u0431\u043e\u043b\u044c\u0448\u043e\u0435 \u0432\u043c\u0435\u0448\u0430\u0442\u0435\u043b\u044c\u0441\u0442\u0432\u043e \u043f\u043e \u043a\u0443\u0437\u043e\u0432\u0443, \u0445\u043e\u0434\u043e\u0432\u0430\u044f \u0442\u0440\u0435\u0431\u0443\u0435\u0442 \u0432\u043d\u0438\u043c\u0430\u043d\u0438\u044f.',
        'vin': 'WVGZZZ5NZHW000002',
        'plate': 'K777KK77',
        'mileage': '92 500 \u043a\u043c',
        'owners': '1 \u0432\u043b\u0430\u0434\u0435\u043b\u0435\u0446',
        'engine': '2.0 \u0431\u0435\u043d\u0437\u0438\u043d',
        'transmission': 'AT',
        'drive': '\u041f\u043e\u043b\u043d\u044b\u0439',
        'reportsCount': 1,
        'images': [
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1449426468159-d96dbf08f19f?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1493238792000-8113da705763?w=1200&q=80&auto=format&fit=crop',
        ],
        'premium': {
          'paintThickness':
              '\u041b\u041a\u041f: 110-210 \u043c\u043a\u043c, \u043e\u043a\u0440\u0430\u0441\u044b: \u043f\u0440\u0430\u0432\u0430\u044f \u043f\u0435\u0440\u0435\u0434\u043d\u044f\u044f \u0434\u0432\u0435\u0440\u044c',
          'panelPhotos':
              '\u0424\u043e\u0442\u043e \u044d\u043b\u0435\u043c\u0435\u043d\u0442\u043e\u0432: 14/16, \u043d\u0435\u0442 \u0444\u043e\u0442\u043e \u043d\u0438\u0437\u0430',
          'video':
              '\u0412\u0438\u0434\u0435\u043e \u043e\u0441\u043c\u043e\u0442\u0440\u0430: 1 \u0440\u043e\u043b\u0438\u043a (\u043a\u0443\u0437\u043e\u0432)',
          'legal':
              '\u042e\u0440. \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0430: \u043e\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u0439 \u043d\u0435\u0442, \u044d\u0441\u0442\u044c \u0437\u0430\u043b\u043e\u0433',
        },
      },
      {
        'car': 'BMW X3 2020',
        'make': 'BMW',
        'model': 'X3',
        'inspector':
            '\u0420\u0443\u0441\u043b\u0430\u043d \u0410\u0441\u0430\u043d\u043e\u0432',
        'date': '27.12.2025',
        'verdict':
            '\u041d\u0435 \u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0443\u0435\u043c',
        'score': '5.4/10',
        'price': '3 900 000 \u20bd',
        'issues':
            '\u041a\u0440\u0443\u043f\u043d\u043e\u0435 \u0414\u0422\u041f, \u0441\u043b\u0435\u0434\u044b \u0440\u0435\u043c\u043e\u043d\u0442\u0430',
        'summary':
            '\u0412\u044b\u044f\u0432\u043b\u0435\u043d\u044b \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0435\u043d\u043d\u044b\u0435 \u043f\u043e\u0432\u0440\u0435\u0436\u0434\u0435\u043d\u0438\u044f, \u0442\u0440\u0435\u0431\u0443\u0435\u0442 \u043a\u0440\u0443\u043f\u043d\u044b\u0445 \u0432\u043b\u043e\u0436\u0435\u043d\u0438\u0439.',
        'vin': 'WBAWX7C58L0000003',
        'plate': 'M555MM77',
        'mileage': '115 000 \u043a\u043c',
        'owners': '3 \u0432\u043b\u0430\u0434\u0435\u043b\u044c\u0446\u0430',
        'engine': '2.0 \u0431\u0435\u043d\u0437\u0438\u043d',
        'transmission': 'AT',
        'drive': '\u041f\u043e\u043b\u043d\u044b\u0439',
        'reportsCount': 3,
        'images': [
          'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80&auto=format&fit=crop',
        ],
        'premium': {
          'paintThickness':
              '\u041b\u041a\u041f: 260-600 \u043c\u043a\u043c, \u043e\u043a\u0440\u0430\u0441\u044b: \u043a\u0440\u044b\u0448\u0430, \u0434\u0432\u0435\u0440\u0438, \u043a\u0440\u044b\u043b\u044c\u044f',
          'panelPhotos':
              '\u0424\u043e\u0442\u043e \u044d\u043b\u0435\u043c\u0435\u043d\u0442\u043e\u0432: 12/16, \u043f\u043e\u0432\u0440\u0435\u0436\u0434\u0435\u043d\u044b \u043f\u043e\u0440\u043e\u0433\u0438',
          'video':
              '\u0412\u0438\u0434\u0435\u043e \u043e\u0441\u043c\u043e\u0442\u0440\u0430: 3 \u0440\u043e\u043b\u0438\u043a\u0430 (\u043a\u0443\u0437\u043e\u0432 + \u0434\u043d\u043e + \u0441\u0430\u043b\u043e\u043d)',
          'legal':
              '\u042e\u0440. \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0430: \u0435\u0441\u0442\u044c \u043e\u0433\u0440\u0430\u043d\u0438\u0447\u0435\u043d\u0438\u044f, \u0442\u0440\u0435\u0431\u0443\u0435\u0442 \u0441\u043d\u044f\u0442\u0438\u044f',
        },
      },
    ];
  }

  void _openFilters(List<Map<String, dynamic>> reports) {
    if (_brandFallback && !_brandLoading) {
      _loadBrands(forceRefresh: true);
    }
    final fallbackMakes = sortMakesByPopularity(
      reports.map((r) => r['make'] as String).toSet().toList(),
    );
    final allMakes = _brandOptions.isNotEmpty ? _brandOptions : fallbackMakes;
    final allModels = sortModelsByPopularity(
      '',
      reports.map((r) => r['model'] as String).toSet().toList(),
    );
    final allStatuses =
        reports.map((r) => r['verdict'] as String).toSet().toList()..sort();
    final allInspectors =
        reports.map((r) => r['inspector'] as String).toSet().toList()..sort();

    final tempMakes = List<String>.from(_selectedMakes);
    final tempModels = List<String>.from(_selectedModels);
    final tempStatuses = List<String>.from(_selectedStatuses);
    final tempInspectors = List<String>.from(_selectedInspectors);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final height = MediaQuery.of(ctx).size.height * 0.85;
            return SafeArea(
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: MyText(
                              text:
                                  '\u0424\u0438\u043b\u044c\u0442\u0440\u044b',
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
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (_brandLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: LinearProgressIndicator(minHeight: 2),
                                ),
                              if (_brandError.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: kGreyColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _brandError,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: kGreyColor,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _brandLoading
                                            ? null
                                            : () {
                                                _brandRetryTimer?.cancel();
                                                _brandRetryCount = 0;
                                                _loadBrands(forceRefresh: true);
                                              },
                                        child: const Text(
                                          '\u041f\u043e\u0432\u0442\u043e\u0440\u0438\u0442\u044c',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              _SearchMultiSelect(
                                label: '\u041c\u0430\u0440\u043a\u0430',
                                options: allMakes,
                                altNames: _brandRusByName,
                                selected: tempMakes,
                                onChanged: (v) => setSheet(() {
                                  tempMakes
                                    ..clear()
                                    ..addAll(v);
                                }),
                              ),
                              const SizedBox(height: 12),
                              _SearchMultiSelect(
                                label: '\u041c\u043e\u0434\u0435\u043b\u044c',
                                options: allModels,
                                selected: tempModels,
                                onChanged: (v) => setSheet(() {
                                  tempModels
                                    ..clear()
                                    ..addAll(v);
                                }),
                              ),
                              const SizedBox(height: 12),
                              _SearchMultiSelect(
                                label: '\u0421\u0442\u0430\u0442\u0443\u0441',
                                options: allStatuses,
                                selected: tempStatuses,
                                onChanged: (v) => setSheet(() {
                                  tempStatuses
                                    ..clear()
                                    ..addAll(v);
                                }),
                              ),
                              const SizedBox(height: 12),
                              _SearchMultiSelect(
                                label:
                                    '\u0410\u0432\u0442\u043e\u043f\u043e\u0434\u0431\u043e\u0440\u0449\u0438\u043a',
                                options: allInspectors,
                                selected: tempInspectors,
                                onChanged: (v) => setSheet(() {
                                  tempInspectors
                                    ..clear()
                                    ..addAll(v);
                                }),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheet(() {
                                  tempMakes.clear();
                                  tempModels.clear();
                                  tempStatuses.clear();
                                  tempInspectors.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: kSecondaryColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                                setState(() {
                                  _selectedMakes = List<String>.from(tempMakes);
                                  _selectedModels = List<String>.from(
                                    tempModels,
                                  );
                                  _selectedStatuses = List<String>.from(
                                    tempStatuses,
                                  );
                                  _selectedInspectors = List<String>.from(
                                    tempInspectors,
                                  );
                                  UserSimplePreferences.setReportMakes(
                                    _selectedMakes,
                                  );
                                  UserSimplePreferences.setReportModels(
                                    _selectedModels,
                                  );
                                  UserSimplePreferences.setReportVerdicts(
                                    _selectedStatuses,
                                  );
                                  UserSimplePreferences.setReportInspectors(
                                    _selectedInspectors,
                                  );
                                });
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kSecondaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsList extends StatelessWidget {
  const _ReportsList({required this.reports});
  final List<Map<String, dynamic>> reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: reports
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(data: r),
            ),
          )
          .toList(),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.data});
  final Map<String, dynamic> data;

  Color _verdictColor(String verdict) {
    if (verdict ==
        '\u041c\u043e\u0436\u043d\u043e \u043f\u043e\u043a\u0443\u043f\u0430\u0442\u044c') {
      return kGreenColor;
    }
    if (verdict ==
        '\u041d\u0443\u0436\u043d\u0430 \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0430') {
      return kYellowColor;
    }
    return kRedColor;
  }

  @override
  Widget build(BuildContext context) {
    final verdict = data['verdict'] ?? '';
    final reportsCount = data['reportsCount'] ?? 1;
    final images = (data['images'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: kTertiaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (images.isNotEmpty) _ReportCarousel(images: images),
          if (images.isNotEmpty) const SizedBox(height: 10),
          MyText(
            text:
                data['car'] ??
                '\u0410\u0432\u0442\u043e\u043c\u043e\u0431\u0438\u043b\u044c',
            size: 16,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: MyText(
                  text:
                      '\u042d\u043a\u0441\u043f\u0435\u0440\u0442: ${data['inspector'] ?? '?'}',
                  size: 12,
                  color: kGreyColor,
                ),
              ),
              MyText(text: data['date'] ?? '', size: 12, color: kGreyColor),
            ],
          ),
          const SizedBox(height: 6),
          MyText(
            text:
                '\u041e\u0442\u0447\u0451\u0442\u043e\u0432 \u043f\u043e \u0430\u0432\u0442\u043e: $reportsCount',
            size: 12,
            color: kGreyColor,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _verdictColor(verdict).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _verdictColor(verdict).withValues(alpha: 0.4),
                  ),
                ),
                child: MyText(
                  text: verdict,
                  size: 12,
                  weight: FontWeight.w700,
                  color: _verdictColor(verdict),
                ),
              ),
              const SizedBox(width: 10),
              MyText(
                text:
                    '\u041e\u0446\u0435\u043d\u043a\u0430: ${data['score'] ?? '?'}',
                size: 12,
                weight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 10),
          MyText(
            text:
                '\u0420\u044b\u043d\u043e\u0447\u043d\u0430\u044f \u0446\u0435\u043d\u0430: ${data['price'] ?? '?'}',
            size: 12,
            weight: FontWeight.w600,
          ),
          const SizedBox(height: 6),
          MyText(
            text:
                '\u0417\u0430\u043c\u0435\u0447\u0430\u043d\u0438\u044f: ${data['issues'] ?? '?'}',
            size: 12,
            color: kGreyColor,
            lineHeight: 1.4,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportDetailScreen(report: data),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: kSecondaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text(
              '\u041f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u043f\u043e\u0434\u0440\u043e\u0431\u043d\u0435\u0435',
              style: TextStyle(
                color: kSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Image.asset(
            Assets.imagesFilter,
            height: 20,
            color: kSecondaryColor,
          ),
          tooltip: '\u0424\u0438\u043b\u044c\u0442\u0440\u044b',
        ),
        if (active)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: kRedColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchMultiSelect extends StatefulWidget {
  const _SearchMultiSelect({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.altNames = const {},
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Map<String, String> altNames;

  @override
  State<_SearchMultiSelect> createState() => _SearchMultiSelectState();
}

class _SearchMultiSelectState extends State<_SearchMultiSelect> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((opt) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      if (opt.toLowerCase().contains(q)) return true;
      final alt = widget.altNames[opt]?.toLowerCase() ?? '';
      return alt.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(text: widget.label, size: 12, weight: FontWeight.w600),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _query = v),
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
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            border: Border.all(color: kBorderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Нет данных',
                      style: TextStyle(fontSize: 12, color: kGreyColor),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final checked = widget.selected.contains(item);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        final next = List<String>.from(widget.selected);
                        if (v == true) {
                          if (!next.contains(item)) next.add(item);
                        } else {
                          next.remove(item);
                        }
                        widget.onChanged(next);
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
      ],
    );
  }
}

class _ReportCarousel extends StatefulWidget {
  const _ReportCarousel({required this.images});
  final List<String> images;

  @override
  State<_ReportCarousel> createState() => _ReportCarouselState();
}

class _ReportCarouselState extends State<_ReportCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  final src = widget.images[index];
                  if (src.startsWith('http://') || src.startsWith('https://')) {
                    return Image.network(
                      src,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loading) {
                        if (loading == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: kBorderColor,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    );
                  }
                  return Image.asset(
                    src,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.images.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 16 : 6,
              decoration: BoxDecoration(
                color: active ? kSecondaryColor : kBorderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

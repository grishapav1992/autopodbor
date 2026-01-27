import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/auto_request_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/reports/report_detail.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_drawer/u_drawer.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_saved/u_saved.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class UserNavBar extends StatefulWidget {
  const UserNavBar({super.key});

  @override
  State<UserNavBar> createState() => _UserNavBarState();
}

class _UserNavBarState extends State<UserNavBar> {
  int _currentIndex = 0;
  void _getCurrentIndex(int index) => setState(() {
        _currentIndex = index;
      });

  final _key = GlobalKey<ScaffoldState>();
  String _query = '';
  String _sortOrder = '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435';
  List<String> _selectedMakes = [];
  List<String> _selectedModels = [];
  List<String> _selectedStatuses = [];
  List<String> _selectedInspectors = [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
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
      _sortOrder = sort ?? '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435';
      _selectedMakes = makes ?? [];
      _selectedModels = models ?? [];
      _selectedInspectors = inspectors ?? [];
      _selectedStatuses = verdicts ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Assets.imagesHome, 'label': '\u041e\u0442\u0447\u0451\u0442\u044b'},
      {'icon': Assets.imagesCar, 'label': '\u0417\u0430\u044f\u0432\u043a\u0430'},
      {'icon': Assets.imagesHeart, 'label': '\u0418\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0435'},
    ];

    final List<Widget> screens = [
      const SizedBox.shrink(),
      const AutoRequestScreen(),
      const USaved(),
    ];

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      key: _key,
      drawer: UDrawer(),
      resizeToAvoidBottomInset: false,
      body: _currentIndex == 0
          ? _buildHome()
          : IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildNavBar(items),
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
      final hay = '${r['car']} ${r['inspector']}'.toLowerCase();
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
      if (_sortOrder == '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0441\u0442\u0430\u0440\u044b\u0435') {
        return ad.compareTo(bd);
      }
      return bd.compareTo(ad);
    });

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: AppSizes.DEFAULT,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _key.currentState!.openDrawer(),
                    child: Image.asset(Assets.imagesMenu, height: 24),
                  ),
                  const SizedBox(width: 12),
                  MyText(
                    text: '\u041e\u0442\u0447\u0451\u0442\u044b \u0430\u0432\u0442\u043e\u043f\u043e\u0434\u0431\u043e\u0440\u0449\u0438\u043a\u043e\u0432',
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                  const Spacer(),
                  _FilterIconButton(
                    active: _selectedMakes.isNotEmpty ||
                        _selectedModels.isNotEmpty ||
                        _selectedStatuses.isNotEmpty ||
                        _selectedInspectors.isNotEmpty,
                    onTap: () => _openFilters(reports),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _sortOrder = _sortOrder ==
                                '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435'
                            ? '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0441\u0442\u0430\u0440\u044b\u0435'
                            : '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435';
                        UserSimplePreferences.setReportSortOrder(_sortOrder);
                      });
                    },
                    icon: const Icon(Icons.sort, color: kSecondaryColor),
                    tooltip: '\u0421\u043e\u0440\u0442\u0438\u0440\u043e\u0432\u043a\u0430',
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
              onPressed: () {
                _getCurrentIndex(1);
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
            '\u041f\u043e\u0438\u0441\u043a \u043f\u043e \u0430\u0432\u0442\u043e \u0438\u043b\u0438 \u044d\u043a\u0441\u043f\u0435\u0440\u0442\u0443',
        prefixIcon: const Icon(Icons.search, color: kSecondaryColor),
        filled: true,
        fillColor: kWhiteColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        'inspector': '\u0418\u043b\u044c\u044f \u0412\u043b\u0430\u0441\u043e\u0432',
        'date': '12.01.2026',
        'verdict': '\u041c\u043e\u0436\u043d\u043e \u043f\u043e\u043a\u0443\u043f\u0430\u0442\u044c',
        'score': '8.7/10',
        'price': '2 850 000 \u20bd',
        'issues':
            '\u041c\u0435\u043b\u043a\u0438\u0435 \u0441\u043a\u043e\u043b\u044b, \u043a\u0440\u0430\u0441\u0438\u043b\u043e\u0441\u044c \u043a\u0440\u044b\u043b\u043e',
        'reportsCount': 2,
        'images': [
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200&q=80&auto=format&fit=crop',
        ],
      },
      {
        'car': 'Volkswagen Tiguan 2018',
        'make': 'Volkswagen',
        'model': 'Tiguan',
        'inspector': '\u0410\u043b\u0435\u043a\u0441\u0430\u043d\u0434\u0440 \u041a\u0438\u043c',
        'date': '05.01.2026',
        'verdict': '\u041d\u0443\u0436\u043d\u0430 \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0430',
        'score': '7.2/10',
        'price': '2 350 000 \u20bd',
        'issues': '\u0417\u0430\u043c\u0435\u043d\u0430 \u0442\u043e\u0440\u043c\u043e\u0437\u043e\u0432, \u043f\u043e\u0434\u043a\u0440\u0430\u0441\u043a\u0430 \u0434\u0432\u0435\u0440\u0438',
        'reportsCount': 1,
        'images': [
          'https://images.unsplash.com/photo-1489515217757-5fd1be406fef?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1449426468159-d96dbf08f19f?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1493238792000-8113da705763?w=1200&q=80&auto=format&fit=crop',
        ],
      },
      {
        'car': 'BMW X3 2020',
        'make': 'BMW',
        'model': 'X3',
        'inspector': '\u0420\u0443\u0441\u043b\u0430\u043d \u0410\u0441\u0430\u043d\u043e\u0432',
        'date': '27.12.2025',
        'verdict': '\u041d\u0435 \u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0443\u0435\u043c',
        'score': '5.4/10',
        'price': '3 900 000 \u20bd',
        'issues': '\u041a\u0440\u0443\u043f\u043d\u043e\u0435 \u0414\u0422\u041f, \u0441\u043b\u0435\u0434\u044b \u0440\u0435\u043c\u043e\u043d\u0442\u0430',
        'reportsCount': 3,
        'images': [
          'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop',
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80&auto=format&fit=crop',
        ],
      },
    ];
  }

  void _openFilters(List<Map<String, dynamic>> reports) {
    final allMakes =
        reports.map((r) => r['make'] as String).toSet().toList()..sort();
    final allModels =
        reports.map((r) => r['model'] as String).toSet().toList()..sort();
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
                              text: '\u0424\u0438\u043b\u044c\u0442\u0440\u044b',
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
                              _SearchMultiSelect(
                                label: '\u041c\u0430\u0440\u043a\u0430',
                                options: allMakes,
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
                                label: '\u0410\u0432\u0442\u043e\u043f\u043e\u0434\u0431\u043e\u0440\u0449\u0438\u043a',
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
                                setState(() {
                                  _selectedMakes =
                                      List<String>.from(tempMakes);
                                  _selectedModels =
                                      List<String>.from(tempModels);
                                  _selectedStatuses =
                                      List<String>.from(tempStatuses);
                                  _selectedInspectors =
                                      List<String>.from(tempInspectors);
                                  UserSimplePreferences.setReportMakes(
                                      _selectedMakes);
                                  UserSimplePreferences.setReportModels(
                                      _selectedModels);
                                  UserSimplePreferences.setReportVerdicts(
                                      _selectedStatuses);
                                  UserSimplePreferences.setReportInspectors(
                                      _selectedInspectors);
                                });
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
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReportCard(data: r),
              ))
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
            text: data['car'] ?? '\u0410\u0432\u0442\u043e\u043c\u043e\u0431\u0438\u043b\u044c',
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
              MyText(
                text: data['date'] ?? '',
                size: 12,
                color: kGreyColor,
              ),
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
                text: '\u041e\u0446\u0435\u043d\u043a\u0430: ${data['score'] ?? '?'}',
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
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_SearchMultiSelect> createState() => _SearchMultiSelectState();
}

class _SearchMultiSelectState extends State<_SearchMultiSelect> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((opt) {
      if (_query.trim().isEmpty) return true;
      return opt.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          text: widget.label,
          size: 12,
          weight: FontWeight.w600,
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: '\u041d\u0430\u0439\u0442\u0438...',
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: kWhiteColor,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          child: ListView.builder(
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                },
              ),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) {
                  return Image.asset(
                    widget.images[index],
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

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_assignment_create_screen.dart';
import 'spark_joy_assignment_detail_screen.dart';
import 'spark_joy_assignment_edit_screen.dart';
import 'spark_joy_company_assignments_screen.dart';
import 'spark_joy_company_dashboard_screen.dart';
import 'spark_joy_company_profile_screen.dart';
import 'spark_joy_company_reports_screen.dart';
import 'spark_joy_company_specialists_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_report_detail_screen.dart';
import 'spark_joy_reports_list_screen.dart';
import 'spark_joy_specialist_assignments_screen.dart';
import 'spark_joy_specialist_detail_screen.dart';
import 'spark_joy_specialist_invite_screen.dart';
import 'spark_joy_specialist_profile_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_ui.dart';

class SparkJoyShell extends StatefulWidget {
  const SparkJoyShell({super.key});

  @override
  State<SparkJoyShell> createState() => _SparkJoyShellState();
}

class _SparkJoyShellState extends State<SparkJoyShell> {
  bool _loading = true;
  bool _loggedIn = false;
  SparkJoyRole _role = SparkJoyRole.specialist;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await SparkJoyStorage.ensureSeedData();
    final loggedIn = await SparkJoyStorage.isLoggedIn();
    final role = await SparkJoyStorage.currentRole();
    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _role = role;
      _loading = false;
      _index = 0;
    });
  }

  Future<void> _loginAs(SparkJoyRole role) async {
    await SparkJoyStorage.login(role);
    if (!mounted) return;
    setState(() {
      _loggedIn = true;
      _role = role;
      _index = 0;
    });
  }

  Future<void> _logout() async {
    await SparkJoyStorage.logout();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _index = 0;
    });
  }

  Future<Map<String, dynamic>?> _findReportById(String reportId) async {
    if (reportId.isEmpty) return null;

    final completed = await SparkJoyStorage.loadCompleted();
    for (final report in completed) {
      if (sjRead(report, 'id') == reportId) {
        return report;
      }
    }

    final platform = sparkPlatformReports.where(
      (r) => sjRead(r, 'id') == reportId,
    );
    if (platform.isEmpty) return null;

    final row = platform.first;
    final vehicle = sjRead(row, 'vehicle');

    return {
      'id': sjRead(row, 'id'),
      'reportName': vehicle,
      'car': vehicle,
      'vin': sjRead(row, 'vin'),
      'createdAt': sjRead(row, 'createdAt'),
      'score':
          '${((double.tryParse(sjRead(row, 'score')) ?? 0) * 10).round()}/100',
      'verdict': 'with_reservations',
      'sections': [
        {
          'title': 'Автомобиль',
          'status': 'ok',
          'details': [
            {'label': 'Модель', 'value': vehicle, 'severity': 'ok'},
            {'label': 'VIN', 'value': sjRead(row, 'vin'), 'severity': 'ok'},
          ],
        },
      ],
      'summaryNote':
          'Детальная версия отчёта не сохранена в локальном хранилище.',
    };
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SparkJoyReportDetailScreen(report: report),
      ),
    );
  }

  Future<void> _openAssignmentCreate() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SparkJoyAssignmentCreateScreen()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAssignmentEdit(Map<String, dynamic> assignment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyAssignmentEditScreen(assignment: assignment),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAssignmentDetail(Map<String, dynamic> assignment) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyAssignmentDetailScreen(
          assignment: assignment,
          onEdit: () => _openAssignmentEdit(assignment),
          onOpenReport: () async {
            final reportId = sjRead(assignment, 'reportId');
            final report = await _findReportById(reportId);
            if (report == null || !mounted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Отчёт не найден')),
                );
              }
              return;
            }
            await _openReport(report);
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSpecialistDetail(Map<String, dynamic> specialist) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SparkJoySpecialistDetailScreen(
          specialist: specialist,
          onCreateAssignment: _openAssignmentCreate,
          onOpenReport: _openReport,
        ),
      ),
    );
  }

  Future<void> _openSpecialistInvite() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SparkJoySpecialistInviteScreen()),
    );
  }

  Future<void> _openCompanyProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SparkJoyCompanyProfileScreen()),
    );
  }

  List<Widget> _tabs() {
    if (_role == SparkJoyRole.company) {
      return [
        SparkJoyCompanyDashboardScreen(
          onOpenCreateAssignment: _openAssignmentCreate,
          onOpenInviteSpecialist: _openSpecialistInvite,
          onOpenProfile: _openCompanyProfile,
        ),
        SparkJoyCompanySpecialistsScreen(
          onInvite: _openSpecialistInvite,
          onOpenDetail: _openSpecialistDetail,
          onCreateAssignment: _openAssignmentCreate,
        ),
        SparkJoyCompanyAssignmentsScreen(
          onCreate: _openAssignmentCreate,
          onOpen: _openAssignmentDetail,
        ),
        SparkJoyCompanyReportsScreen(onOpenReport: _openReport),
      ];
    }

    return const [
      SparkJoyReportsListScreen(),
      SparkJoySpecialistAssignmentsScreen(),
      SparkJoySpecialistProfileScreen(),
    ];
  }

  List<BottomNavigationBarItem> _navItems() {
    if (_role == SparkJoyRole.company) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Главная',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.groups_2_outlined),
          label: 'Спецы',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          label: 'Заявки',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          label: 'Отчёты',
        ),
      ];
    }

    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.description_outlined),
        label: 'Отчёты',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.assignment_outlined),
        label: 'Заявки',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Профиль',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (!_loggedIn) {
      return _SparkJoyRoleLogin(onLogin: _loginAs);
    }

    final tabs = _tabs();
    final navItems = _navItems();
    final index = _index >= tabs.length ? 0 : _index;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            constraints: const BoxConstraints(minHeight: 32),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: kSecondaryColor.withValues(alpha: 0.08),
            ),
            child: MyText(
              text: sparkJoyRoleLabel(_role),
              size: 12,
              maxLines: 1,
              lineHeight: 1.1,
              textAlign: TextAlign.center,
              color: kSecondaryColor,
              weight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 20),
          ),
        ],
      ),
      body: IndexedStack(index: index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        onTap: (value) => setState(() => _index = value),
        selectedItemColor: kSecondaryColor,
        unselectedItemColor: kGreyColor,
        items: navItems,
      ),
    );
  }
}

class _SparkJoyRoleLogin extends StatelessWidget {
  const _SparkJoyRoleLogin({required this.onLogin});

  final ValueChanged<SparkJoyRole> onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: kSecondaryColor.withValues(alpha: 0.08),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.build_circle_outlined,
                      size: 36,
                      color: kSecondaryColor,
                    ),
                  ),
                  const MyText(
                    text: 'AutoCheck',
                    size: 26,
                    weight: FontWeight.w700,
                    textAlign: TextAlign.center,
                  ),
                  const MyText(
                    text: 'Платформа автомобильной экспертизы',
                    size: 12,
                    color: kGreyColor,
                    textAlign: TextAlign.center,
                    paddingTop: 4,
                    paddingBottom: 20,
                  ),
                  const MyText(
                    text: 'Войти как',
                    size: 11,
                    color: kGreyColor,
                    weight: FontWeight.w700,
                    textAlign: TextAlign.center,
                    paddingBottom: 8,
                  ),
                  _RoleCard(
                    title: 'Компания',
                    subtitle: 'Управление специалистами, осмотрами и отчётами',
                    icon: Icons.business_outlined,
                    onTap: () => onLogin(SparkJoyRole.company),
                  ),
                  const SizedBox(height: 10),
                  _RoleCard(
                    title: 'Специалист',
                    subtitle: 'Осмотры автомобилей и составление отчётов',
                    icon: Icons.handyman_outlined,
                    onTap: () => onLogin(SparkJoyRole.specialist),
                  ),
                  const SizedBox(height: 14),
                  const MyText(
                    text: 'Демо-режим • Данные хранятся локально',
                    size: 10,
                    color: kGreyColor,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: kSecondaryColor.withValues(alpha: 0.08),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: kSecondaryColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(text: title, size: 14, weight: FontWeight.w700),
                    MyText(
                      text: subtitle,
                      size: 11,
                      color: kGreyColor,
                      paddingTop: 2,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: kGreyColor),
            ],
          ),
        ),
      ),
    );
  }
}

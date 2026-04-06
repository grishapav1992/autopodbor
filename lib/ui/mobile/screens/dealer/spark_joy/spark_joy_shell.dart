import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_reports_list_screen.dart';
import 'spark_joy_specialist_assignments_screen.dart';
import 'spark_joy_specialist_profile_screen.dart';
import 'spark_joy_storage.dart';

class SparkJoyShell extends StatefulWidget {
  const SparkJoyShell({super.key});

  @override
  State<SparkJoyShell> createState() => _SparkJoyShellState();
}

class _SparkJoyShellState extends State<SparkJoyShell> {
  bool _loading = true;
  bool _loggedIn = false;
  SparkJoyRole _role = SparkJoyRole.specialist;
  String? _businessType;
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
    final businessType = await SparkJoyStorage.currentBusinessType();
    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _role = role;
      _businessType = businessType;
      _loading = false;
      _index = 0;
    });
  }

  Future<void> _login() async {
    final role = await SparkJoyStorage.currentRole();
    await SparkJoyStorage.login(role);
    final businessType = await SparkJoyStorage.currentBusinessType();
    if (!mounted) return;
    setState(() {
      _loggedIn = true;
      _role = role;
      _businessType = businessType;
      _index = 0;
    });
  }

  void _onBusinessStatusChanged(String? businessType) {
    if (!mounted) return;
    setState(() {
      _role = businessType == null
          ? SparkJoyRole.specialist
          : SparkJoyRole.company;
      _businessType = businessType;
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

  List<BottomNavigationBarItem> _navItems() {
    if (_role == SparkJoyRole.specialist) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          label: 'Отчёты',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Профиль',
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

  String _roleBadgeLabel() {
    if (_role == SparkJoyRole.company && _businessType == 'ip') {
      return 'ИП';
    }
    return sparkJoyRoleLabel(_role);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (!_loggedIn) {
      return _SparkJoyLogin(onLogin: _login);
    }

    final tabs = _role == SparkJoyRole.specialist
        ? <Widget>[
            const SparkJoyReportsListScreen(),
            SparkJoySpecialistProfileScreen(
              onBusinessStatusChanged: _onBusinessStatusChanged,
            ),
          ]
        : <Widget>[
            const SparkJoyReportsListScreen(),
            const SparkJoySpecialistAssignmentsScreen(),
            SparkJoySpecialistProfileScreen(
              onBusinessStatusChanged: _onBusinessStatusChanged,
            ),
          ];
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
              text: _roleBadgeLabel(),
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

class _SparkJoyLogin extends StatelessWidget {
  const _SparkJoyLogin({required this.onLogin});

  final VoidCallback onLogin;

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
                  FilledButton.icon(
                    onPressed: onLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Войти'),
                  ),
                  const SizedBox(height: 12),
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

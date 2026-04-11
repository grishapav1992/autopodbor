import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_staff_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_reports_list_screen.dart';
import 'spark_joy_specialist_profile_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_tokens.dart';
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

  List<NavigationDestination> _navDestinations() {
    if (_role == SparkJoyRole.specialist) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.description_outlined),
          selectedIcon: Icon(Icons.description_rounded),
          label: 'Отчёты',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Профиль',
        ),
      ];
    }
    return const [
      NavigationDestination(
        icon: Icon(Icons.description_outlined),
        selectedIcon: Icon(Icons.description_rounded),
        label: 'Отчёты',
      ),
      NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups_rounded),
        label: 'Сотрудники',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Профиль',
      ),
    ];
  }

  String _currentTabTitle() {
    if (_role == SparkJoyRole.specialist) {
      switch (_index) {
        case 1:
          return 'Профиль';
        case 0:
        default:
          return 'Отчёты';
      }
    }
    switch (_index) {
      case 1:
        return 'Сотрудники';
      case 2:
        return 'Профиль';
      case 0:
      default:
        return 'Отчёты';
    }
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
      return Scaffold(
        body: SparkLoadingState(
          message: sjT(
            'spark.state.loading.profileBootstrap',
            fallback: 'Подготовка профиля...',
          ),
        ),
      );
    }

    if (!_loggedIn) {
      return _SparkJoyLogin(onLogin: _login);
    }

    final tabs = _role == SparkJoyRole.specialist
        ? <Widget>[
            const SparkJoyReportsListScreen(companyMode: false),
            SparkJoySpecialistProfileScreen(
              onBusinessStatusChanged: _onBusinessStatusChanged,
            ),
          ]
        : <Widget>[
            const SparkJoyReportsListScreen(companyMode: true),
            const SparkJoyCompanyStaffScreen(),
            SparkJoySpecialistProfileScreen(
              onBusinessStatusChanged: _onBusinessStatusChanged,
            ),
          ];
    final destinations = _navDestinations();
    final index = _index >= tabs.length ? 0 : _index;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: SparkSpace.section,
        title: Text(
          _currentTabTitle(),
          style: const TextStyle(
            fontSize: SparkTextSize.titleLg,
            fontWeight: FontWeight.w700,
            color: kPrimaryColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: SparkSpace.md),
            child: Center(
              child: SparkChip(
                text: _roleBadgeLabel(),
                background: kSecondaryColor.withValues(alpha: 0.08),
                color: kSecondaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.xl,
                  vertical: SparkSpace.sm,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: SparkSize.iconLg),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(SparkSpace.hairline),
          child: Container(height: SparkSpace.hairline, color: kBorderColor),
        ),
      ),
      body: IndexedStack(index: index, children: tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: kWhiteColor,
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: SparkTextSize.caption,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? kSecondaryColor : kGreyColor,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: SparkSize.iconSm,
              color: selected ? kSecondaryColor : kGreyColor,
            );
          }),
          indicatorColor: kSecondaryColor.withValues(alpha: 0.12),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: destinations,
        ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.section,
            vertical: SparkSpace.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: SparkSize.modalWide),
              child: SparkCard(
                padding: const EdgeInsets.all(SparkSpace.section),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: SparkSize.authLogo,
                      height: SparkSize.authLogo,
                      margin: const EdgeInsets.only(bottom: SparkSpace.xxl),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SparkRadius.xl),
                        color: kSecondaryColor.withValues(alpha: 0.08),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.build_circle_outlined,
                        size: SparkSize.icon3xl,
                        color: kSecondaryColor,
                      ),
                    ),
                    const MyText(
                      text: 'AutoCheck',
                      size: SparkTextSize.hero,
                      weight: FontWeight.w700,
                      textAlign: TextAlign.center,
                    ),
                    const MyText(
                      text: 'Платформа автомобильной экспертизы',
                      size: SparkTextSize.body,
                      color: kGreyColor,
                      textAlign: TextAlign.center,
                      paddingTop: SparkSpace.xs,
                      paddingBottom: SparkSpace.section,
                    ),
                    SparkPrimaryActionButton(
                      label: 'Войти',
                      onTap: onLogin,
                      icon: Icons.login,
                    ),
                    const SizedBox(height: SparkSpace.xl),
                    const MyText(
                      text: 'Демо-режим • Данные хранятся локально',
                      size: SparkTextSize.chip,
                      color: kGreyColor,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/ai_queue_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/ai_queue_offline_runner.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:get/get.dart';

import 'spark_joy_company_requests_screen.dart';
import 'spark_joy_company_request_detail_screen.dart';
import 'spark_joy_company_staff_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_error_snackbar.dart';
import 'spark_joy_notifications_screen.dart';
import 'spark_joy_notifications_storage.dart';
import 'spark_joy_onboarding.dart';
import 'spark_joy_reports_list_screen.dart';
import 'spark_joy_specialist_requests_screen.dart';
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

  // Lets other tabs ask the reports screen to switch its inner segmented
  // tab — profile's "Отчётов" stat card taps this to deep-link straight
  // to the завершённые list. The reports screen listens, reacts once,
  // and resets the value back to null.
  final ValueNotifier<String?> _requestedReportsTab = ValueNotifier<String?>(
    null,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _requestedReportsTab.dispose();
    super.dispose();
  }

  /// Fires tab-specific onboarding bottom sheets that don't belong on
  /// shell mount. The staff tab (index 1 for `company`) is pre-built
  /// inside the IndexedStack — without this hook its onboarding would
  /// trigger immediately on login while the user is still on the reports
  /// tab. We trigger it instead when the user actually selects the tab.
  void _maybeShowTabOnboarding(int newIndex) {
    if (_role != SparkJoyRole.company) return;
    if (newIndex != 1) return;
    SparkJoyOnboarding.showOnce(
      context,
      flagKey: UserSimplePreferences.sparkOnbStaffKey,
      titleI18nKey: 'spark.onboarding.staff.title',
      titleFallback: 'Сотрудники компании',
      allowedRoles: const ['company'],
      bullets: const [
        SparkJoyOnboardingBullet(
          i18nKey: 'spark.onboarding.staff.b1',
          fallback:
              'Здесь отображаются только специалисты, реально привязанные к вашей компании.',
          icon: Icons.groups_2_outlined,
        ),
        SparkJoyOnboardingBullet(
          i18nKey: 'spark.onboarding.staff.b2',
          fallback:
              'Нового сотрудника можно пригласить по номеру телефона — он появится в списке после принятия приглашения.',
          icon: Icons.send_to_mobile_rounded,
        ),
        SparkJoyOnboardingBullet(
          i18nKey: 'spark.onboarding.staff.b3',
          fallback:
              'Сотрудника можно удалить из штата, если у него нет активных назначенных заявок.',
          icon: Icons.person_remove_outlined,
        ),
      ],
    );
  }

  Future<void> _bootstrap() async {
    await SparkJoyStorage.ensureSeedData();
    await SparkJoyNotificationsStorage.ensureSeedData();
    // Best-effort, once-per-session reclaim of local media/thumbnails left
    // behind by completed/discarded reports. Fire-and-forget so it never
    // blocks the shell coming up.
    unawaited(SparkJoyStorage.gcOrphanedMedia());
    final loggedIn = await SparkJoyStorage.isLoggedIn();
    if (loggedIn) {
      await SparkJoyStorage.syncRoleFromServer();
    }
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
    final newRole = businessType == null
        ? SparkJoyRole.specialist
        : SparkJoyRole.company;
    // Preserve the user's semantic tab across role transitions.
    // Tab layout depends on role:
    //   specialist → 0=Reports, 1=Заявки, 2=Profile
    //   company    → 0=Reports, 1=Staff, 2=Заявки, 3=Profile
    // If we left `_index` untouched, verifying INN on Profile (2→2)
    // would land on Staff, and resetting on Profile (3→clamped→0)
    // would land on Reports. Both jarring. So we keep the user on
    // the semantic destination: Reports, Заявки, Profile. Company-only
    // Staff falls back to Profile when user demotes.
    int nextIndex = _index;
    if (_role != newRole) {
      final wasReports = _index == 0;
      final wasRequests =
          (_role == SparkJoyRole.specialist && _index == 1) ||
          (_role == SparkJoyRole.company && _index == 2);
      final wasProfile =
          (_role == SparkJoyRole.specialist && _index == 2) ||
          (_role == SparkJoyRole.company && _index == 3);
      final requestsIndex = newRole == SparkJoyRole.specialist ? 1 : 2;
      final profileIndex = newRole == SparkJoyRole.specialist ? 2 : 3;
      if (wasReports) {
        nextIndex = 0;
      } else if (wasRequests) {
        nextIndex = requestsIndex;
      } else if (wasProfile) {
        nextIndex = profileIndex;
      } else {
        nextIndex = profileIndex;
      }
    }
    setState(() {
      _role = newRole;
      _businessType = businessType;
      _index = nextIndex;
    });
  }

  Future<void> _logout() async {
    // SparkJoyStorage.logout() clears spark-joy-specific caches (drafts
    // / frame catalog / user-tags). Auth tokens used to stay behind,
    // so `hasSavedSession` would flip the app straight back into Home
    // on the next launch. Clear both here.
    await SparkJoyStorage.logout();
    await AiQueueOfflineRunner.instance.resetAll();
    AiQueueApi.resetCaches();
    await UserSimplePreferences.clearAuthTokens();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _index = 0;
    });
    // Jump the whole route stack back to the login route. Without
    // this the shell stays mounted but empty and no phone-login UI
    // appears until next cold start.
    Get.offAllNamed(AppLinks.login);
  }

  /// Pushes the notifications feed as a full-screen route.
  /// Wrapping here (instead of giving [SparkJoyNotificationsScreen] its
  /// own Scaffold) keeps the screen reusable as a tab body too if we
  /// ever want to bring it back in-place.
  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: SparkSpace.md,
            title: const Text(
              'Уведомления',
              style: TextStyle(
                fontSize: SparkTextSize.titleLg,
                fontWeight: FontWeight.w700,
                color: kPrimaryColor,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(SparkSpace.hairline),
              child: Container(
                height: SparkSpace.hairline,
                color: kBorderColor,
              ),
            ),
          ),
          body: SparkJoyNotificationsScreen(
            onOpenRequest: (requestId) async {
              Navigator.of(context).pop();
              await _openRequestFromNotification(requestId);
            },
          ),
        ),
      ),
    );
  }

  int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  Future<void> _openRequestFromNotification(int requestId) async {
    if (!mounted) return;
    final requestTabIndex = _role == SparkJoyRole.specialist ? 1 : 2;
    setState(() => _index = requestTabIndex);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final requests = await storage_api.StorageApi.getAllRequests();
      if (!mounted) return;
      final matched = requests.where((request) {
        return _readInt(request['id']) == requestId;
      }).toList();
      if (matched.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Заявка не найдена в списке')),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _role == SparkJoyRole.specialist
              ? SparkJoySpecialistRequestDetailScreen(initial: matched.first)
              : SparkJoyCompanyRequestDetailScreen(initial: matched.first),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось открыть заявку',
      );
    }
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
          icon: Icon(Icons.assignment_ind_outlined),
          selectedIcon: Icon(Icons.assignment_ind_rounded),
          label: 'Заявки',
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
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment_rounded),
        label: 'Заявки',
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
          return 'Заявки';
        case 2:
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
        return 'Заявки';
      case 3:
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

  /// Tap по role-чипу в AppBar открывает короткое объяснение: какая
  /// сейчас роль, чем company отличается от specialist, как сменить.
  /// Реальный role-switch — через «Профиль → Проверка компании» (ввод
  /// ИНН / сброс статуса), здесь только nav-hint, чтобы юзер не
  /// тапал чип и не ожидал dropdown.
  void _showRoleInfoSheet(BuildContext context) {
    final isCompany = _role == SparkJoyRole.company;
    final label = _roleBadgeLabel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.lg),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(SparkSpace.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCompany ? Icons.business_rounded : Icons.person_rounded,
                      size: SparkSize.iconLg,
                      color: kSecondaryColor,
                    ),
                    const SizedBox(width: SparkSpace.md),
                    MyText(
                      text: 'Роль: $label',
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w800,
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.lg),
                MyText(
                  text: isCompany
                      ? 'Аккаунт оформлен как ${_businessType == 'ip' ? 'ИП' : 'юридическое лицо'}. Отчёты публикуются от имени компании, доступен раздел «Сотрудники».'
                      : 'Индивидуальный профиль автоподборщика. Чтобы переключиться на работу от лица компании или ИП, укажите ИНН в «Профиль → Проверка компании».',
                  size: SparkTextSize.body,
                  color: kGreyColor,
                  lineHeight: 1.40,
                ),
                const SizedBox(height: SparkSpace.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Понятно'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

    final isSpecialist = _role == SparkJoyRole.specialist;
    final tabCount = isSpecialist ? 3 : 4;
    final index = _index >= tabCount ? 0 : _index;
    final tabs = isSpecialist
        ? <Widget>[
            SparkJoyReportsListScreen(
              active: index == 0,
              companyMode: false,
              tabRequest: _requestedReportsTab,
            ),
            SparkJoySpecialistRequestsScreen(active: index == 1),
            SparkJoySpecialistProfileScreen(
              onBusinessStatusChanged: _onBusinessStatusChanged,
              onLogout: _logout,
            ),
          ]
        : <Widget>[
            SparkJoyReportsListScreen(
              active: index == 0,
              companyMode: true,
              tabRequest: _requestedReportsTab,
            ),
            SparkJoyCompanyStaffScreen(active: index == 1),
            SparkJoyCompanyRequestsScreen(active: index == 2),
            SparkJoySpecialistProfileScreen(
              onBusinessStatusChanged: _onBusinessStatusChanged,
              onLogout: _logout,
            ),
          ];
    final destinations = _navDestinations();

    // Progressive trim: 72 → 60 → 56 (89f65dd icon-only-inactive) →
    // 64 here. User asked the inactive labels back; with always-show
    // labels Material needs more vertical room, so bumped up 8px to
    // 64 — still noticeably tighter than the original 72.
    const navHeight = 64.0;

    return Scaffold(
      // Keep extendBody for the frosted BottomNav (it floats over the
      // tail of scroll content, which reads nicely). But the AppBar is
      // pinned opaquely — the earlier extendBodyBehindAppBar + frosted
      // flexibleSpace experiment made the top feel like content was
      // swimming under a translucent surface, especially when the body
      // background shared kPrimaryColor with the AppBar. Users asked
      // for the same solid, fixed top we use in the report editor.
      extendBody: true,
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: SparkSpace.section,
        backgroundColor: kPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: SparkSpace.hairline),
        ),
        title: Text(
          _currentTabTitle(),
          style: const TextStyle(
            fontSize: SparkTextSize.titleLg,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: kSecondaryColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: SparkSpace.md),
            child: Center(
              child: InkWell(
                onTap: () => _showRoleInfoSheet(context),
                borderRadius: BorderRadius.circular(SparkRadius.pill),
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
          ),
          IconButton(
            tooltip: 'Уведомления',
            onPressed: () => _openNotifications(context),
            icon: const _NotificationNavIcon(
              icon: Icons.notifications_none_rounded,
            ),
          ),
          // Logout-кнопка раньше жила прямо в AppBar — самый «легко
          // доступный» угол экрана, случайный тап = выход из аккаунта.
          // Теперь действие переехало вглубь Профиля (см.
          // SparkJoySpecialistProfileScreen → onLogout callback) с
          // обязательным confirm-диалогом.
        ],
      ),
      body: SparkShellInsets(
        // Pinned AppBar — content starts below the AppBar naturally
        // (Scaffold handles the top inset), so shellTop is 0.
        // Keeps bottomInset so tab content reserves space for the
        // still-extendBody frosted nav.
        topInset: 0,
        bottomInset: navHeight,
        child: IndexedStack(index: index, children: tabs),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8,
            sigmaY: 8,
            tileMode: TileMode.clamp,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: kBorderColor,
                  width: SparkSpace.hairline,
                ),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: kWhiteColor.withValues(alpha: 0.78),
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                height: navHeight,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return TextStyle(
                    // Bumped caption → body so labels are legible at
                    // arm's length; weight pops for the selected item.
                    fontSize: SparkTextSize.body,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? kSecondaryColor : kGreyColor,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  final selected = states.contains(WidgetState.selected);
                  return IconThemeData(
                    // Bumped iconSm (16) → iconLg (20). Matches
                    // standard Material NavigationBar metrics; the old
                    // 16 looked "tiny" against the bar's width.
                    size: SparkSize.iconLg,
                    color: selected ? kSecondaryColor : kGreyColor,
                  );
                }),
                indicatorColor: kSecondaryColor.withValues(alpha: 0.12),
              ),
              child: NavigationBar(
                selectedIndex: index,
                // Labels always visible — pulling them from inactive
                // destinations read as mystery-meat icons. Height was
                // bumped to compensate.
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (value) {
                  if (value != index) {
                    HapticFeedback.selectionClick();
                  }
                  setState(() => _index = value);
                  if (value == 0) {
                    _requestedReportsTab.value = 'drafts';
                  }
                  _maybeShowTabOnboarding(value);
                },
                destinations: destinations,
              ),
            ),
          ),
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
                      weight: FontWeight.w800,
                      lineHeight: 1.30,
                      tracking: true,
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

/// Nav-bar notifications icon with a live unread-count badge.
///
/// Wraps the standard bell icon in a Stack and overlays a small red
/// circle with the count whenever there are unread notifications in
/// [SparkJoyNotificationsStorage]. Rebuilds reactively via the storage's
/// [ValueNotifier] so the badge vanishes the moment the user marks the
/// last notification as read.
class _NotificationNavIcon extends StatelessWidget {
  const _NotificationNavIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SparkJoyNotificationsStorage.notifier,
      builder: (context, _, _) {
        return FutureBuilder<int>(
          future: SparkJoyNotificationsStorage.unreadCount(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            final baseIcon = Icon(icon);
            if (count <= 0) return baseIcon;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                baseIcon,
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: kRedColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kWhiteColor, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: kWhiteColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

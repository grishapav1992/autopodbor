import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_create_request_screen.dart';
import 'spark_joy_company_request_detail_screen.dart';
import 'spark_joy_error_snackbar.dart';
import 'spark_joy_onboarding.dart';
import 'spark_joy_request_filter_bar.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Вкладка «Заявки» для роли company:
///  * Pull-to-refresh + `Storage.GetRequest` для актуального списка
///  * Empty-state с большой кнопкой «Создать заявку» когда заявок нет
///  * Header-row + inline «+» когда список не пустой
///  * Карточка заявки: номер + бренд/модель + статус-пилл + срок
///  * Авто-refresh после `Navigator.pop` из формы создания
///  * Онбординг при первом открытии (одноразовый, через
///    [SparkJoyOnboarding.showOnce]).
class SparkJoyCompanyRequestsScreen extends StatefulWidget {
  const SparkJoyCompanyRequestsScreen({super.key, this.active = false});

  final bool active;

  @override
  State<SparkJoyCompanyRequestsScreen> createState() =>
      _SparkJoyCompanyRequestsScreenState();
}

class _SparkJoyCompanyRequestsScreenState
    extends State<SparkJoyCompanyRequestsScreen> {
  List<Map<String, dynamic>>? _requests;
  bool _loading = true;
  String? _loadError;
  RequestStatusFilter _statusFilter = RequestStatusFilter.all;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _load();
      _showOnboarding();
    }
  }

  @override
  void didUpdateWidget(covariant SparkJoyCompanyRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (_requests == null) {
        _load();
      }
      _showOnboarding();
    }
  }

  void _showOnboarding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      SparkJoyOnboarding.showOnce(
        context,
        flagKey: UserSimplePreferences.sparkOnbCompanyRequestsKey,
        titleI18nKey: 'spark.onboarding.companyRequests.title',
        titleFallback: 'Заявки компании',
        allowedRoles: const ['company'],
        bullets: const [
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.companyRequests.b1',
            fallback:
                'Здесь собраны заявки вашей компании: статус, назначенный специалист и результат работы.',
            icon: Icons.assignment_outlined,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.companyRequests.b2',
            fallback:
                'Нажмите «+», выберите автомобиль, срок и назначьте исполнителя из штата или по телефону.',
            icon: Icons.add_circle_outline_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.companyRequests.b3',
            fallback:
                'До начала работы заявку можно переназначить или отменить; после готового отчёта доступна ссылка для клиента.',
            icon: Icons.ios_share_rounded,
          ),
        ],
      );
    });
  }

  Future<List<Map<String, dynamic>>> _getRequestsWithRetry() async {
    try {
      return await storage_api.StorageApi.getRequests();
    } on storage_api.SessionExpiredException {
      rethrow;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return storage_api.StorageApi.getRequests();
    }
  }

  Future<void> _load() async {
    // Если есть данные — refresh идёт «тихо»: spinner не вешаем,
    // снэк появится только при ошибке. Это даёт offline-friendly
    // experience: юзер видит стабильный список, понимает что
    // обновление не удалось через snackbar, но не теряет UI.
    final hadData = _requests != null;
    setState(() {
      _loading = !hadData;
      _loadError = null;
    });
    try {
      final result = await _getRequestsWithRetry();
      if (!mounted) return;
      setState(() {
        _requests = result;
        _loading = false;
      });
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      const msg = 'Сессия истекла. Войдите заново.';
      if (hadData) {
        _showRefreshErrorSnackbar(msg);
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _loadError = msg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (hadData) {
        _showRefreshErrorSnackbar(e, fallback: 'Не удалось обновить список');
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _loadError = sparkJoyReadableErrorText(
            e,
            fallback: 'Не удалось загрузить список',
          );
        });
      }
    }
  }

  void _showRefreshErrorSnackbar(Object error, {String? fallback}) {
    showSparkJoyErrorSnackBar(context, error, fallback: fallback);
  }

  Future<void> _openCreateRequest() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SparkJoyCompanyCreateRequestScreen(),
      ),
    );
    if (!mounted) return;
    // Юзер вернулся из формы — обновляем список, чтобы новая заявка
    // (если была создана) сразу появилась без pull-to-refresh.
    await _load();
  }

  Future<void> _openDetail(Map<String, dynamic> request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SparkJoyCompanyRequestDetailScreen(initial: request),
      ),
    );
    if (!mounted) return;
    // После возврата — refresh для свежего статуса/истории.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SparkScreenList(
        bottomInset: 24,
        children: const [SizedBox(height: 60), SparkLoadingState()],
      );
    }
    if (_loadError != null) {
      return SparkScreenList(
        bottomInset: 24,
        onRefresh: _load,
        children: [
          const SizedBox(height: 24),
          SparkErrorState(
            title: 'Не удалось загрузить заявки',
            subtitle: _loadError!,
            copyText: _loadError,
            onRetry: _load,
          ),
        ],
      );
    }
    final allRequests = _requests ?? const [];
    if (allRequests.isEmpty) {
      return SparkScreenList(
        bottomInset: 24,
        onRefresh: _load,
        children: [
          const SizedBox(height: 60),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kSecondaryColor.withValues(alpha: 0.1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.assignment_outlined,
                size: 40,
                color: kSecondaryColor,
              ),
            ),
          ),
          const SizedBox(height: SparkSpace.xxl),
          const Center(
            child: MyText(
              text: 'У вас пока нет заявок',
              size: SparkTextSize.titleLg,
              weight: FontWeight.w800,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: SparkSpace.sm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: SparkSpace.xxxl),
            child: MyText(
              text:
                  'Создайте первую заявку, чтобы назначить осмотр '
                  'специалисту из штата вашей компании.',
              size: SparkTextSize.body,
              color: kGreyColor,
              textAlign: TextAlign.center,
              lineHeight: 1.4,
            ),
          ),
          const SizedBox(height: SparkSpace.xxxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xxxl),
            child: SparkPrimaryActionButton(
              label: 'Создать заявку',
              icon: Icons.add_rounded,
              onTap: _openCreateRequest,
            ),
          ),
        ],
      );
    }
    final filteredRequests = allRequests
        .where((request) => requestMatchesStatusFilter(request, _statusFilter))
        .toList();
    return SparkScreenList(
      bottomInset: 24,
      onRefresh: _load,
      children: [
        Row(
          children: [
            Expanded(child: SparkSectionTitle('Мои заявки')),
            IconButton(
              onPressed: _openCreateRequest,
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: kSecondaryColor,
                size: SparkSize.iconXl,
              ),
              tooltip: 'Создать заявку',
            ),
          ],
        ),
        SparkJoyRequestFilterBar(
          value: _statusFilter,
          onChanged: (filter) => setState(() => _statusFilter = filter),
        ),
        const SizedBox(height: SparkSpace.lg),
        if (filteredRequests.isEmpty)
          const SparkHintCard(text: 'Заявок с таким статусом нет')
        else
          ...filteredRequests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.md),
              child: _RequestCard(data: r, onTap: () => _openDetail(r)),
            ),
          ),
      ],
    );
  }
}

/// Карточка одной заявки в списке. Tap → детальный экран
/// ([SparkJoyCompanyRequestDetailScreen]).
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  String _str(String key) => (data[key] ?? '').toString();

  String get _title {
    final number = _str('requestNumber');
    return number.isNotEmpty ? 'Заявка №$number' : 'Заявка';
  }

  String get _subtitle {
    // Бэк отдаёт массив авто внутри `requestCars` (в spec). Каждый
    // элемент имеет вложенные `brand.name` и `model.model`. Если
    // структура другая — пробуем плоские поля для совместимости.
    final cars = data['requestCars'] ?? data['cars'];
    if (cars is List && cars.isNotEmpty) {
      final first = cars.first;
      if (first is Map) {
        final brand = (first['brand'] is Map)
            ? (first['brand']['name'] ?? '').toString()
            : (first['brand'] ?? '').toString();
        final model = (first['model'] is Map)
            ? (first['model']['model'] ?? first['model']['name'] ?? '')
                  .toString()
            : (first['model'] ?? '').toString();
        final combined = [
          brand.trim(),
          model.trim(),
        ].where((s) => s.isNotEmpty).join(' ');
        if (combined.isNotEmpty) return combined;
      }
    }
    final flatBrand = _str('brand');
    final flatModel = _str('model');
    final combined = [
      flatBrand,
      flatModel,
    ].where((s) => s.isNotEmpty).join(' ');
    return combined.isEmpty ? 'Автомобиль не указан' : combined;
  }

  String get _meta {
    final due = _str('dueAt');
    final specialist = _specialistLabel;
    final parts = <String>[
      if (specialist.isNotEmpty) 'Специалист: $specialist',
    ];
    if (due.isNotEmpty) {
      // dueAt приходит как YYYY-MM-DD от бэка.
      parts.add('Срок: ${_formatRuDate(due)}');
    }
    return parts.join(' · ');
  }

  int? _int(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  String get _specialistLabel {
    final raw = data['assignedSpecialist'];
    final specialist = raw is Map ? Map<String, dynamic>.from(raw) : null;
    if (specialist != null) {
      final firstName = (specialist['firstName'] ?? '').toString().trim();
      final lastName = (specialist['lastName'] ?? '').toString().trim();
      final middleName = (specialist['middleName'] ?? '').toString().trim();
      final full = [
        lastName,
        firstName,
        middleName,
      ].where((part) => part.isNotEmpty).join(' ');
      if (full.isNotEmpty) return full;
    }
    final id =
        _int(data['assignedSpecialistId']) ??
        _int(data['assignedSpecialistUserId']) ??
        _int(specialist?['id']);
    return id == null ? '' : '#$id';
  }

  String _formatRuDate(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final badge = requestStatusBadge(_str('status'));
    return SparkCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: SparkSize.iconLg,
            color: kSecondaryColor,
          ),
          const SizedBox(width: SparkSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: _title,
                        size: SparkTextSize.bodyLg,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.sm),
                    SparkChip(
                      text: badge.label,
                      background: badge.bg,
                      color: badge.fg,
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.xxs),
                MyText(
                  text: _subtitle,
                  size: SparkTextSize.body,
                  color: kGreyColor,
                ),
                if (_meta.isNotEmpty) ...[
                  const SizedBox(height: SparkSpace.xxs),
                  MyText(
                    text: _meta,
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: kGreyColor,
            size: SparkSize.iconMd,
          ),
        ],
      ),
    );
  }
}

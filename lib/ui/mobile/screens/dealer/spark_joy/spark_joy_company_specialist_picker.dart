import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Источник выбора специалиста — для UI message и future-routing.
enum AssigneeSource { staff, phone }

/// Результат выбора специалиста.
///
/// `userId` теперь всегда integer (от `Storage.GetCompanySpecialists` /
/// `Storage.GetSpecialists`), backend
/// принимает его как `assignedSpecialistId` в `CreateRequest`. Валидация
/// бэка: спец должен быть `company_id == текущая компания` — иначе
/// CreateRequest отвергнет. Tab «По телефону» при найденном НЕ-штатном
/// спеце вернёт его userId, но CreateRequest откажет — это backend-gap.
class SelectedAssignee {
  const SelectedAssignee({
    required this.displayName,
    required this.source,
    required this.userId,
    this.phone,
    this.urlAvatar,
    this.city,
  });

  final String displayName;
  final AssigneeSource source;
  final int userId;
  final String? phone;
  final String? urlAvatar;
  final String? city;
}

/// Bottom-sheet picker. Возвращает [SelectedAssignee] или null.
Future<SelectedAssignee?> showSpecialistPicker(BuildContext context) async {
  return await showModalBottomSheet<SelectedAssignee>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kWhiteColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SparkRadius.lg)),
    ),
    builder: (_) => const _SpecialistPickerSheet(),
  );
}

class _SpecialistPickerSheet extends StatefulWidget {
  const _SpecialistPickerSheet();

  @override
  State<_SpecialistPickerSheet> createState() => _SpecialistPickerSheetState();
}

class _SpecialistPickerSheetState extends State<_SpecialistPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: media.size.height * 0.75,
        child: Padding(
          padding: EdgeInsets.only(
            left: SparkSpace.xxxl,
            right: SparkSpace.xxxl,
            top: SparkSpace.xxxl,
            bottom: media.viewInsets.bottom + SparkSpace.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: MyText(
                      text: 'Выбрать специалиста',
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: SparkSpace.md),
              TabBar(
                controller: _tabController,
                labelColor: kSecondaryColor,
                unselectedLabelColor: kGreyColor,
                indicatorColor: kSecondaryColor,
                labelStyle: const TextStyle(
                  fontSize: SparkTextSize.body,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: SparkTextSize.body,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Из штата'),
                  Tab(text: 'По телефону'),
                ],
              ),
              const SizedBox(height: SparkSpace.md),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [_StaffTab(), _PhoneTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Staff tab ────────────────────────────────────────────────────────

class _StaffTab extends StatefulWidget {
  const _StaffTab();

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<SpecialistItem> _staff = const [];

  // Сохраняем state при swipe между табами — иначе при возврате на
  // «Из штата» список перезагружался бы из сети без причины.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await storage_api.StorageApi.getCompanySpecialistsPage(
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _staff = page.specialists;
        _loading = false;
      });
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Сессия истекла. Войдите заново.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить список: $e';
      });
    }
  }

  void _pick(SpecialistItem spec) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(
      SelectedAssignee(
        displayName: spec.displayName,
        source: AssigneeSource.staff,
        userId: spec.id,
        phone: spec.phone,
        urlAvatar: spec.urlAvatar,
        city: spec.city,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // обязательно для AutomaticKeepAliveClientMixin
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SparkSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: kRedColor,
                size: SparkSize.iconXl,
              ),
              const SizedBox(height: SparkSpace.md),
              MyText(
                text: _error!,
                size: SparkTextSize.body,
                color: kRedColor,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SparkSpace.lg),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (_staff.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(SparkSpace.xl),
          child: MyText(
            text:
                'В штате компании ещё нет специалистов. '
                'Пригласите их через раздел «Сотрудники».',
            size: SparkTextSize.body,
            color: kGreyColor,
            textAlign: TextAlign.center,
            lineHeight: 1.4,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _staff.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: kBorderColor),
      itemBuilder: (_, i) {
        final s = _staff[i];
        return _StaffRow(spec: s, onTap: () => _pick(s));
      },
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.spec, required this.onTap});

  final SpecialistItem spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final city = (spec.city ?? '').trim();
    final ratingPct = (spec.rating * 100).round();
    final hasRating = spec.likeUp + spec.likeDown > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.sm,
            vertical: SparkSpace.lg,
          ),
          child: Row(
            children: [
              SparkInitialsAvatar(
                name: spec.displayName,
                size: SparkSize.icon4xl,
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MyText(
                      text: spec.displayName,
                      size: SparkTextSize.body,
                      weight: FontWeight.w700,
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: SparkSpace.xxs),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: SparkSize.iconSm,
                            color: kGreyColor,
                          ),
                          const SizedBox(width: SparkSpace.xxs),
                          MyText(
                            text: city,
                            size: SparkTextSize.caption,
                            color: kGreyColor,
                          ),
                        ],
                      ),
                    ],
                    if (hasRating) ...[
                      const SizedBox(height: SparkSpace.xxs),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: SparkSize.iconSm,
                            color: kYellowColor,
                          ),
                          const SizedBox(width: SparkSpace.xxs),
                          MyText(
                            text: '$ratingPct%',
                            size: SparkTextSize.caption,
                            color: kGreyColor,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: SparkSize.iconLg,
                color: kGreyColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phone tab ────────────────────────────────────────────────────────

class _PhoneTab extends StatefulWidget {
  const _PhoneTab();

  @override
  State<_PhoneTab> createState() => _PhoneTabState();
}

class _PhoneTabState extends State<_PhoneTab>
    with AutomaticKeepAliveClientMixin {
  final _phoneController = TextEditingController();
  String _normalized = '';
  bool _searching = false;
  String? _error;
  List<SpecialistItem>? _results;

  // Сохраняем введённый телефон + результаты поиска при переключении
  // на «Из штата» и обратно.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final next = digits.length == 10 ? digits : '';
    if (next == _normalized) return;
    setState(() {
      _normalized = next;
      // Сбрасываем результаты при изменении номера, чтобы юзер не
      // видел старый «не найден» для другого номера.
      _results = null;
      _error = null;
    });
  }

  Future<void> _search() async {
    if (_normalized.isEmpty || _searching) return;
    HapticFeedback.selectionClick();
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    try {
      final phoneE164 = '+7$_normalized';
      final page = await storage_api.StorageApi.getSpecialists(
        search: phoneE164,
        limit: 20,
      );
      if (!mounted) return;
      // Defensive double-filter: бэк уже сужает по точному
      // совпадению search-параметра. Этот endsWith — defense-in-depth
      // на случай если поле phone имеет особенности форматирования
      // (+7 vs 7 vs 8). Удаляем все не-digit для нормализации.
      final exact = page.specialists.where((s) {
        final p = (s.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        return p.endsWith(_normalized);
      }).toList();
      // Если ровно 1 match — auto-pop без промежуточного setState
      // (widget сейчас unmount'нется, лишний rebuild dangerous).
      if (exact.length == 1) {
        _pick(exact.first);
        return;
      }
      setState(() {
        _results = exact;
        _searching = false;
      });
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Сессия истекла. Войдите заново.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Не удалось выполнить поиск: $e';
      });
    }
  }

  void _pick(SpecialistItem spec) {
    Navigator.of(context).pop(
      SelectedAssignee(
        displayName: spec.displayName,
        source: AssigneeSource.phone,
        userId: spec.id,
        phone: spec.phone,
        urlAvatar: spec.urlAvatar,
        city: spec.city,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // обязательно для AutomaticKeepAliveClientMixin
    final canSearch = _normalized.isNotEmpty && !_searching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [RuPhoneFormatter()],
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            if (canSearch) _search();
          },
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: sparkInputDecoration(
            '+7-___-___-__-__',
            prefixIcon: const Icon(Icons.phone_outlined, color: kGreyColor),
          ),
        ),
        const SizedBox(height: SparkSpace.md),
        SizedBox(
          height: SparkSize.actionHeight,
          child: FilledButton.icon(
            onPressed: canSearch ? _search : null,
            icon: _searching
                ? const SizedBox(
                    width: SparkSize.spinner,
                    height: SparkSize.spinner,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kWhiteColor,
                    ),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(_searching ? 'Ищем...' : 'Найти специалиста'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
            ),
          ),
        ),
        const SizedBox(height: SparkSpace.lg),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SparkSpace.xl),
          child: MyText(
            text: _error!,
            size: SparkTextSize.body,
            color: kRedColor,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(SparkSpace.xl),
          child: MyText(
            text:
                'Введите номер телефона специалиста — мы найдём его в '
                'нашей базе. Назначить можно только специалистов, '
                'состоящих в вашей компании.',
            size: SparkTextSize.caption,
            color: kGreyColor,
            textAlign: TextAlign.center,
            lineHeight: 1.4,
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(SparkSpace.xl),
          child: MyText(
            text:
                'Специалист с этим номером не найден. Возможно он '
                'ещё не зарегистрирован в системе.',
            size: SparkTextSize.body,
            color: kGreyColor,
            textAlign: TextAlign.center,
            lineHeight: 1.4,
          ),
        ),
      );
    }
    // >1 match — показываем список (маловероятно, но возможно).
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: kBorderColor),
      itemBuilder: (_, i) {
        return _StaffRow(spec: results[i], onTap: () => _pick(results[i]));
      },
    );
  }
}

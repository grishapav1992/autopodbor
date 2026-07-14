import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_company_request_detail_screen.dart';
import 'spark_joy_error_snackbar.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_profile_photo_viewer.dart';
import 'spark_joy_public_profile_merge.dart';
import 'spark_joy_request_detail_ui.dart';
import 'spark_joy_request_status.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyStaffDetailScreen extends StatefulWidget {
  const SparkJoyCompanyStaffDetailScreen({
    super.key,
    required this.specialist,
    required this.requests,
    this.profileLoader,
  });

  final Map<String, dynamic> specialist;
  final List<Map<String, dynamic>> requests;

  /// Test seam for loading the expanded public specialist profile.
  final Future<Map<String, dynamic>> Function(int specialistId)? profileLoader;

  @override
  State<SparkJoyCompanyStaffDetailScreen> createState() =>
      _SparkJoyCompanyStaffDetailScreenState();
}

class _SparkJoyCompanyStaffDetailScreenState
    extends State<SparkJoyCompanyStaffDetailScreen> {
  late Map<String, dynamic> _profile;
  bool _profileLoading = false;
  String? _profileLoadError;

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.specialist);
    final specialistId = _intValue(_profile, 'id');
    if (specialistId > 0) {
      _profileLoading = true;
      _loadFullProfile(specialistId);
    }
  }

  Future<void> _loadFullProfile(int specialistId) async {
    try {
      final loader = widget.profileLoader;
      final fetched = loader == null
          ? await storage_api.StorageApi.getSpecialistProfile(
              specialistId: specialistId,
            )
          : await loader(specialistId);
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        if (fetched.isEmpty) {
          _profileLoadError = 'Полный профиль сотрудника не найден';
        } else {
          _profile = mergeSparkJoySpecialistPublicProfile(_profile, fetched);
          _profileLoadError = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _profileLoadError = sparkJoyReadableErrorText(
          error,
          fallback: 'Не удалось загрузить полные данные сотрудника',
        );
      });
    }
  }

  Future<void> _retryFullProfile() async {
    if (_profileLoading) return;
    final specialistId = _intValue(_profile, 'id');
    if (specialistId <= 0) return;
    setState(() {
      _profileLoading = true;
      _profileLoadError = null;
    });
    await _loadFullProfile(specialistId);
  }

  Future<void> _openRequest(
    BuildContext context,
    Map<String, dynamic> request,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCompanyRequestDetailScreen(initial: request),
      ),
    );
  }

  String _str(Map<String, dynamic> data, String key) {
    return (data[key] ?? '').toString();
  }

  int _intValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readAny(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _str(data, key).trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _requestTitle(Map<String, dynamic> request) {
    final number = _str(request, 'requestNumber');
    return number.isEmpty ? 'Заявка' : 'Заявка №$number';
  }

  String _requestCarTitle(Map<String, dynamic> request) {
    final cars = request['requestCars'] ?? request['cars'];
    if (cars is List && cars.isNotEmpty) {
      final first = cars.first;
      if (first is Map) {
        final brand = first['brand'] is Map
            ? (first['brand']['name'] ?? '').toString()
            : (first['brand'] ?? '').toString();
        final model = first['model'] is Map
            ? (first['model']['model'] ?? first['model']['name'] ?? '')
                  .toString()
            : (first['model'] ?? '').toString();
        final title = [
          brand.trim(),
          model.trim(),
        ].where((part) => part.isNotEmpty).join(' ');
        if (title.isNotEmpty) return title;
      }
    }
    final title = [
      _str(request, 'brand').trim(),
      _str(request, 'model').trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    return title.isEmpty ? 'Автомобиль не указан' : title;
  }

  String _formatRuDate(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
    if (m == null) return iso;
    return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> request) {
    final badge = requestStatusBadge(_str(request, 'status'));
    final dueAt = _str(request, 'dueAt');

    return SparkListCard(
      onTap: () => _openRequest(context, request),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: SparkSize.iconSm,
            color: kSecondaryColor,
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MyText(
                        text: _requestTitle(request),
                        size: SparkTextSize.bodyLg,
                        weight: FontWeight.w700,
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
                MyText(
                  text: _requestCarTitle(request),
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  paddingTop: SparkSpace.xxs,
                ),
                if (dueAt.isNotEmpty)
                  MyText(
                    text: 'Срок: ${_formatRuDate(dueAt)}',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                  ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          const Icon(
            Icons.chevron_right_rounded,
            size: SparkSize.iconMd,
            color: kGreyColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffName = sjRead(_profile, 'name', fallback: 'Сотрудник');
    final specialization = _readAny(_profile, [
      'description',
      'specialization',
      'about',
    ]);
    final phone = sjRead(_profile, 'phone');
    final email = sjRead(_profile, 'email');
    final city = sjRead(_profile, 'city');
    final avatarUrl = _readAny(_profile, [
      'urlAvatar',
      'avatarUrl',
      'photoUrl',
    ]);
    final rating = _doubleValue(_profile, 'rating');
    final likeUp = _intValue(_profile, 'likeUp');
    final likeDown = _intValue(_profile, 'likeDown');
    final hasProfileInfo =
        specialization.isNotEmpty ||
        phone.isNotEmpty ||
        email.isNotEmpty ||
        city.isNotEmpty ||
        rating > 0 ||
        likeUp > 0 ||
        likeDown > 0;
    // At-a-glance workload for the company viewing this staff member (B10).
    final totalRequests = widget.requests.length;
    final completedRequests = widget.requests
        .where((r) => normalizeRequestStatus(_str(r, 'status')) == 'done')
        .length;
    final activeRequests = widget.requests.where((r) {
      final s = normalizeRequestStatus(_str(r, 'status'));
      return s == 'in_work' || s == 'paid_escrow';
    }).length;

    return SparkPageScaffold(
      appBar: sparkAppBar(title: staffName),
      bottomInset: SparkSpace.xl,
      children: [
        SparkPageHeader(
          title: 'Профиль сотрудника',
          subtitle: specialization.isEmpty
              ? 'Данные сотрудника и назначенные заявки'
              : specialization,
        ),
        SparkCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SparkJoyProfilePhotoAvatar(
                tapKey: const ValueKey('staff-avatar-preview'),
                name: staffName,
                imageUrl: avatarUrl,
                photoTitle: 'Фото сотрудника',
                semanticLabel: 'Открыть фото сотрудника',
                size: SparkSize.icon6xl,
                textSize: SparkTextSize.modalTitle,
              ),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: staffName,
                      size: SparkTextSize.label,
                      weight: FontWeight.w700,
                    ),
                    if (specialization.isNotEmpty)
                      MyText(
                        text: specialization,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                  ],
                ),
              ),
              SparkChip(
                text: sjT('spark.status.confirmed', fallback: 'Подтверждён'),
                background: kChipCompletedBg,
                color: kChipCompletedFg,
              ),
            ],
          ),
        ),
        if (_profileLoading)
          const SparkHintCard(
            text: 'Обновляем полные данные сотрудника…',
            icon: Icons.sync_rounded,
          )
        else if (_profileLoadError != null)
          SparkHintCard(
            text: _profileLoadError!,
            icon: Icons.warning_amber_rounded,
            textColor: kRedColor,
            trailing: TextButton(
              onPressed: _retryFullProfile,
              child: const Text('Повторить'),
            ),
          ),
        if (hasProfileInfo) ...[
          const SparkSectionTitle('Данные профиля', top: SparkSpace.xl),
          SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.sm,
            ),
            child: Column(
              children: [
                if (city.isNotEmpty)
                  SparkProfileRow(
                    icon: Icons.location_city_outlined,
                    label: 'Город',
                    value: city,
                    muted: true,
                  ),
                if (phone.isNotEmpty)
                  SparkProfileRow(
                    icon: Icons.phone_outlined,
                    label: 'Телефон',
                    value: phone,
                    onTap: () => sparkLaunchPhone(context, phone),
                    showChevron: false,
                    trailing: const Icon(
                      Icons.call_rounded,
                      size: SparkSize.iconLg,
                      color: kSecondaryColor,
                    ),
                  ),
                if (email.isNotEmpty)
                  SparkProfileRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: email,
                    onTap: () => sparkLaunchEmail(context, email),
                    showChevron: false,
                    trailing: const Icon(
                      Icons.mail_rounded,
                      size: SparkSize.iconLg,
                      color: kSecondaryColor,
                    ),
                  ),
                if (specialization.isNotEmpty)
                  SparkProfileRow(
                    icon: Icons.description_outlined,
                    label: 'Описание услуг',
                    value: specialization,
                    muted: true,
                  ),
                if (rating > 0)
                  SparkProfileRow(
                    icon: Icons.star_border_rounded,
                    label: 'Рейтинг',
                    value: rating.toStringAsFixed(1),
                    muted: true,
                  ),
                if (likeUp > 0 || likeDown > 0)
                  SparkProfileRow(
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'Оценки',
                    value: 'Плюсов: $likeUp · минусов: $likeDown',
                    muted: true,
                  ),
              ],
            ),
          ),
        ],
        const SparkSectionTitle('Активность', top: SparkSpace.xl),
        SparkCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.md,
            vertical: SparkSpace.sm,
          ),
          child: Column(
            children: [
              SparkProfileRow(
                icon: Icons.assignment_outlined,
                label: 'Всего заявок',
                value: totalRequests.toString(),
                muted: true,
              ),
              SparkProfileRow(
                icon: Icons.pending_actions_outlined,
                label: 'В работе',
                value: activeRequests.toString(),
                muted: true,
              ),
              SparkProfileRow(
                icon: Icons.task_alt_rounded,
                label: 'Завершено',
                value: completedRequests.toString(),
                muted: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: SparkSpace.xl),
        const SparkSectionTitle('Назначенные заявки'),
        if (widget.requests.isEmpty)
          const SparkHintCard(text: 'Назначенных заявок пока нет')
        else
          ...widget.requests.map((request) => _requestCard(context, request)),
      ],
    );
  }
}

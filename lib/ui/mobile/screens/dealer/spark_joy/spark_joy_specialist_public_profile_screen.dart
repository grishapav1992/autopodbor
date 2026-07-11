import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_error_snackbar.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_request_detail_ui.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Публичный профиль специалиста — зеркало [SparkJoyCompanyPublicProfileScreen].
///
/// `initialProfile` (данные, уже пришедшие с заявкой/отчётом: имя, город,
/// телефон, email, рейтинг, аватар) рендерится мгновенно; при наличии
/// [specialistId] поверх подгружается `Storage.GetSpecialistProfile`.
/// RPC контакты НЕ отдаёт (так спроектирован бэк), поэтому мерж накатывает
/// только непустые поля ответа — телефон/email из initialProfile выживают.
class SparkJoySpecialistPublicProfileScreen extends StatefulWidget {
  const SparkJoySpecialistPublicProfileScreen({
    super.key,
    this.specialistId,
    this.initialProfile,
  });

  final int? specialistId;
  final Map<String, dynamic>? initialProfile;

  @override
  State<SparkJoySpecialistPublicProfileScreen> createState() =>
      _SparkJoySpecialistPublicProfileScreenState();
}

class _SparkJoySpecialistPublicProfileScreenState
    extends State<SparkJoySpecialistPublicProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile == null
        ? null
        : Map<String, dynamic>.from(widget.initialProfile!);
    if (widget.specialistId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final specialistId = widget.specialistId;
    if (specialistId == null || specialistId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fetched = await storage_api.StorageApi.getSpecialistProfile(
        specialistId: specialistId,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (fetched.isNotEmpty) {
          _profile = _merge(_profile, fetched);
        } else if (_profile == null) {
          // Пустой result = удалён/не специалист. Если с заявкой уже
          // пришли данные — показываем их, ошибкой не пугаем.
          _error = 'Специалист не найден';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Сеть упала, но initialProfile есть — молча остаёмся на нём.
        if (_profile == null) {
          _error = sparkJoyReadableErrorText(
            e,
            fallback: 'Не удалось загрузить профиль специалиста',
          );
        }
      });
    }
  }

  /// Накатывает только непустые поля [fetched] поверх [base] — контакты и
  /// рейтинг из initialProfile не должны затираться null'ами RPC.
  static Map<String, dynamic> _merge(
    Map<String, dynamic>? base,
    Map<String, dynamic> fetched,
  ) {
    final merged = Map<String, dynamic>.from(base ?? const {});
    for (final entry in fetched.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      merged[entry.key] = value;
    }
    return merged;
  }

  String _read(String key, {String fallback = ''}) {
    final value = _profile?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  /// First non-empty value across [keys] — поле может приехать и из RPC,
  /// и из payload заявки с разным неймингом (см. company-профиль, B8).
  String _readAny(List<String> keys) {
    for (final key in keys) {
      final value = _read(key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _fullName() {
    final composed = [
      _read('lastName'),
      _read('firstName'),
      _read('middleName'),
    ].where((part) => part.isNotEmpty).join(' ');
    if (composed.isNotEmpty) return composed;
    final single = _readAny(['name', 'displayName', 'fullName']);
    return single.isEmpty ? 'Специалист' : single;
  }

  String _rating() {
    final value = _profile?['rating'] ?? _profile?['ratingAverage'];
    if (value is num && value > 0) {
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = _fullName();
    final city = _read('city');
    final phone = _readAny(['phone', 'contactPhone', 'phoneNumber']);
    final email = _readAny(['email', 'contactEmail']);
    final description = _readAny(['description', 'specialization']);
    final avatarUrl = _readAny(['urlAvatar', 'avatarUrl', 'photoUrl']);
    final rating = _rating();

    final infoRows = <Widget>[
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
          icon: Icons.email_outlined,
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
      if (rating.isNotEmpty)
        SparkProfileRow(
          icon: Icons.star_outline_rounded,
          label: 'Рейтинг',
          value: rating,
          muted: true,
        ),
      if (description.isNotEmpty)
        SparkProfileRow(
          icon: Icons.description_outlined,
          label: 'Описание услуг',
          value: description,
          muted: true,
        ),
    ];

    return SparkPageScaffold(
      appBar: sparkAppBar(title: 'Профиль специалиста'),
      bottomInset: SparkSpace.xl,
      children: [
        if (_loading && profile == null)
          const SparkLoadingState(message: 'Загрузка профиля специалиста...')
        else if (_error != null && profile == null)
          SparkErrorState(
            title: sjT('spark.state.error.title', fallback: 'Ошибка загрузки'),
            subtitle: _error!,
            copyText: _error,
            onRetry: _load,
          )
        else ...[
          SparkCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SparkInitialsAvatar(
                  name: name,
                  size: SparkSize.icon6xl,
                  textSize: SparkTextSize.modalTitle,
                  imageUrl: avatarUrl.isEmpty ? null : avatarUrl,
                ),
                const SizedBox(width: SparkSpace.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        text: name,
                        size: SparkTextSize.title,
                        weight: FontWeight.w800,
                        lineHeight: 1.25,
                      ),
                      if (city.isNotEmpty)
                        MyText(
                          text: city,
                          size: SparkTextSize.body,
                          color: kGreyColor,
                          paddingTop: SparkSpace.xxs,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SparkSectionTitle('Информация', top: SparkSpace.xl),
          SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.md,
              vertical: SparkSpace.sm,
            ),
            child: Column(
              children: infoRows.isEmpty
                  ? const [
                      SparkHintCard(
                        text:
                            'Специалист пока не заполнил публичную информацию',
                      ),
                    ]
                  : infoRows,
            ),
          ),
        ],
      ],
    );
  }
}

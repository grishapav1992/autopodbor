import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_error_snackbar.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_profile_photo_viewer.dart';
import 'spark_joy_request_detail_ui.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyPublicProfileScreen extends StatefulWidget {
  const SparkJoyCompanyPublicProfileScreen({
    super.key,
    this.companyId,
    this.initialProfile,
    this.profileLoader,
  });

  final int? companyId;
  final Map<String, dynamic>? initialProfile;

  /// Test seam for the authoritative server refresh.
  final Future<Map<String, dynamic>> Function(int companyId)? profileLoader;

  @override
  State<SparkJoyCompanyPublicProfileScreen> createState() =>
      _SparkJoyCompanyPublicProfileScreenState();
}

class _SparkJoyCompanyPublicProfileScreenState
    extends State<SparkJoyCompanyPublicProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile == null
        ? null
        : Map<String, dynamic>.from(widget.initialProfile!);
    if (widget.companyId != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final companyId = widget.companyId;
    if (companyId == null || companyId <= 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.profileLoader;
      final fetched = loader == null
          ? await storage_api.StorageApi.getCompanyProfile(companyId: companyId)
          : await loader(companyId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (fetched.isNotEmpty) {
          // This RPC owns the complete public company profile. Replace the
          // navigation snapshot even when individual values are null/empty,
          // otherwise deleted information remains visible indefinitely.
          _profile = Map<String, dynamic>.from(fetched);
        } else {
          _profile = null;
          _error = 'Компания не найдена';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // If navigation supplied a compact company card, keep showing it
        // offline. A load error is only blocking when there is no fallback.
        if (_profile == null) {
          _error = sparkJoyReadableErrorText(
            e,
            fallback: 'Не удалось загрузить профиль компании',
          );
        }
      });
    }
  }

  String _read(String key, {String fallback = ''}) {
    final value = _profile?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  /// First non-empty value across [keys] — backend field naming varies, so
  /// we probe a few variants and surface whatever it actually returns (B8).
  String _readAny(List<String> keys) {
    for (final key in keys) {
      final value = _read(key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _companyName() {
    for (final key in const ['companyName', 'name', 'fullName', 'title']) {
      final value = _read(key);
      if (value.isNotEmpty) return value;
    }
    return 'Компания';
  }

  String _companyInn() {
    for (final key in const ['companyInn', 'inn', 'tin']) {
      final value = _read(key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _avatarUrl() {
    for (final key in const [
      'urlAvatar',
      'avatarUrl',
      'avatar_url',
      'photoUrl',
    ]) {
      final value = _read(key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _verified() {
    final value = _profile?['isVerifyCompany'] ?? _profile?['isVerified'];
    if (value is bool) return value;
    return value.toString().trim().toLowerCase() == 'true';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = _companyName();
    final city = _read('city');
    final description = _readAny([
      'description',
      'about',
      'servicesDescription',
    ]);
    final inn = _companyInn();
    final avatarUrl = _avatarUrl();
    // Surface whatever else the backend returns — naming varies, so probe
    // several variants per field and render only the ones present (B8).
    final phone = _readAny(['phone', 'contactPhone', 'phoneNumber']);
    final email = _readAny(['email', 'contactEmail']);
    final website = _readAny(['website', 'webSite', 'site', 'url']);
    final address = _readAny([
      'address',
      'legalAddress',
      'addressLegal',
      'companyAddress',
    ]);
    final ogrn = _readAny(['ogrn', 'companyOgrn', 'ogrnip']);
    final rating = _readAny(['rating', 'ratingAverage']);
    final staffCount = _readAny([
      'staffCount',
      'specialistsCount',
      'employeesCount',
    ]);
    final reportsCount = _readAny(['reportsCount', 'completedReportsCount']);
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
      if (website.isNotEmpty)
        SparkProfileRow(
          icon: Icons.language_rounded,
          label: 'Сайт',
          value: website,
          muted: true,
        ),
      if (address.isNotEmpty)
        SparkProfileRow(
          icon: Icons.location_on_outlined,
          label: 'Адрес',
          value: address,
          muted: true,
        ),
      if (inn.isNotEmpty)
        SparkProfileRow(
          icon: Icons.numbers_rounded,
          label: 'ИНН',
          value: inn,
          muted: true,
        ),
      if (ogrn.isNotEmpty)
        SparkProfileRow(
          icon: Icons.badge_outlined,
          label: 'ОГРН',
          value: ogrn,
          muted: true,
        ),
      if (rating.isNotEmpty)
        SparkProfileRow(
          icon: Icons.star_outline_rounded,
          label: 'Рейтинг',
          value: rating,
          muted: true,
        ),
      if (staffCount.isNotEmpty)
        SparkProfileRow(
          icon: Icons.groups_outlined,
          label: 'Специалистов',
          value: staffCount,
          muted: true,
        ),
      if (reportsCount.isNotEmpty)
        SparkProfileRow(
          icon: Icons.description_outlined,
          label: 'Отчётов',
          value: reportsCount,
          muted: true,
        ),
      if (description.isNotEmpty)
        SparkProfileRow(
          icon: Icons.notes_rounded,
          label: 'Описание',
          value: description,
          muted: true,
        ),
    ];

    return SparkPageScaffold(
      appBar: sparkAppBar(title: 'Профиль компании'),
      bottomInset: SparkSpace.xl,
      children: [
        if (_loading && profile == null)
          const SparkLoadingState(message: 'Загрузка профиля компании...')
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
                SparkJoyProfilePhotoAvatar(
                  tapKey: const ValueKey('company-avatar-preview'),
                  name: name,
                  imageUrl: avatarUrl,
                  photoTitle: 'Фото компании',
                  semanticLabel: 'Открыть фото компании',
                  size: SparkSize.icon6xl,
                  textSize: SparkTextSize.modalTitle,
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
                if (_verified()) ...[
                  const SizedBox(width: SparkSpace.sm),
                  const SparkChip(
                    text: 'Проверена',
                    icon: Icons.verified_rounded,
                    background: Color(0x1A1FA463),
                    color: kGreenColor,
                  ),
                ],
              ],
            ),
          ),
          if (infoRows.isNotEmpty) ...[
            const SparkSectionTitle('Информация', top: SparkSpace.xl),
            SparkCard(
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.sm,
              ),
              child: Column(children: infoRows),
            ),
          ],
        ],
      ],
    );
  }
}

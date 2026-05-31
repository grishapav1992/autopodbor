import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_error_snackbar.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyCompanyPublicProfileScreen extends StatefulWidget {
  const SparkJoyCompanyPublicProfileScreen({
    super.key,
    this.companyId,
    this.initialProfile,
  });

  final int? companyId;
  final Map<String, dynamic>? initialProfile;

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
    if (_profile == null && widget.companyId != null) {
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
      final profile = await storage_api.StorageApi.getCompanyProfile(
        companyId: companyId,
      );
      if (!mounted) return;
      setState(() {
        _profile = profile.isEmpty ? null : profile;
        _loading = false;
        _error = profile.isEmpty ? 'Компания не найдена' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = sparkJoyReadableErrorText(
          e,
          fallback: 'Не удалось загрузить профиль компании',
        );
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
    final description = _read('description');
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
          muted: true,
        ),
      if (email.isNotEmpty)
        SparkProfileRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: email,
          muted: true,
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
      appBar: AppBar(centerTitle: false, title: const Text('Профиль компании')),
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
                            'Компания пока не заполнила публичную информацию',
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

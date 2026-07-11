import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/city_picker_bottom_sheet.dart';
import 'package:flutter_application_1/ui/common/widgets/app_adaptive_bottom_sheet.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/personal_data_consent.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/privacy_policy.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/terms.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'spark_joy_data.dart';
import 'spark_joy_error_snackbar.dart';
import 'spark_joy_feedback_screen.dart';
import 'spark_joy_company_public_profile_screen.dart';
import 'spark_joy_profile_refresh_bus.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Result of the email-code dialog. `editEmail` lets the user bail out of a
/// code sent to a wrong address and correct the email instead of being stuck
/// with only «Отмена» / «Подтвердить» (B4).
enum _EmailVerifyAction { confirm, cancel, editEmail }

class SparkJoySpecialistProfileScreen extends StatefulWidget {
  const SparkJoySpecialistProfileScreen({
    super.key,
    this.onBusinessStatusChanged,
    this.onLogout,
  });

  final ValueChanged<String?>? onBusinessStatusChanged;

  /// Logout вынесен из AppBar в нижнюю часть Профиля (как row
  /// «Выйти из аккаунта» с confirm-диалогом). Иконка `Icons.logout` в
  /// правом-верхнем углу AppBar была destructive-action на самом
  /// доступном месте — случайный тап на ней выкидывал из аккаунта.
  final Future<void> Function()? onLogout;

  @override
  State<SparkJoySpecialistProfileScreen> createState() =>
      _SparkJoySpecialistProfileScreenState();
}

class _SparkJoySpecialistProfileScreenState
    extends State<SparkJoySpecialistProfileScreen> {
  static const List<String> _presetSpecializations = <String>[
    'Подбор под ключ',
    'Осмотр кузова',
    'Техническая диагностика',
    'Компьютерная диагностика',
    'Проверка документов',
    'Юридическая проверка',
    'Выездной осмотр',
    'Экспертное заключение',
  ];

  final _innController = TextEditingController();
  // ФИО раздельно (server schema: firstName/lastName/middleName).
  // Legacy single `name` мигрируется в _applyProfileToControllers.
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  // Free-form «описание услуг». Chip-suggestions below the textarea
  // just append their label into this controller — the textarea is
  // the single source of truth. Маппится в server `description`.
  final _specializationController = TextEditingController();
  // Название компании. Парная companyInn (см. _verifiedInn) — пара
  // имя+ИНН отправляется на сервер атомарно (server требует оба).
  final _companyNameController = TextEditingController();

  bool _isVerifying = false;
  bool _isSavingProfile = false;
  bool _isAccountDeletionRequesting = false;
  // Generation counter для invalidation in-flight _fetchServerProfile.
  // Каждый запрос захватывает myGen в начале и проверяет перед apply.
  // Если кто-то bumped (например _resetBusinessStatus) — fetch больше
  // не имеет права писать в state. Без этого in-flight fetch с
  // company-snapshot откатывал UI обратно после успешного reset.
  int _fetchGeneration = 0;
  // Server-side флаг модерации компании (поле `isVerifyCompany` из
  // GetProfile). null до первой синхронизации; true/false после.
  bool? _isVerifyCompany;
  // Идёт ли сейчас запрос Storage.VerifyEmail — блокирует повторные
  // нажатия кнопки «Подтвердить email» и меняет её надпись на
  // «Подтверждаем...».
  bool _isVerifyingEmail = false;
  // Email, загруженный с сервера / из локального профиля при последнем
  // _applyProfileToControllers. Используется для сравнения с текущим
  // значением в _emailController — кнопка «Подтвердить email» появляется
  // только когда current != _originalEmail (инспектор реально изменил
  // адрес). После успешной верификации server fetch обновит это поле.
  String _originalEmail = '';
  // Originals остальных профильных полей — нужны для diff-based payload:
  // _pushProfileToServer кладёт в UpdateProfile только те поля, где
  // current != original. Это критично для email: backend на каждое
  // присутствие поля `email` в payload запускает verification flow, и
  // если мы шлём прежний email при обычном save (например, поменялся
  // только город) — пользователь получает лишнее письмо с кодом.
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalMiddleName = '';
  String _originalCity = '';
  String _originalDescription = '';
  String _originalCompanyName = '';
  // Идёт ли сейчас UpdateProfile для переименования компании в
  // verified-state — блокирует повторные нажатия «Изменить».
  bool _isVerifyingCompanyName = false;
  // Email, ожидающий подтверждения через Storage.VerifyEmail. Set
  // когда пользователь сменил email и сервер принял (auto-open sheet +
  // banner). Clear при успешном verify или повторной смене на тот же
  // что _originalEmail. Persist в UserSimplePreferences чтобы пережить
  // рестарт приложения.
  String? _pendingEmailVerify;
  // Публичный URL аватарки из S3 (поле urlAvatar в GetProfile/UpdateProfile).
  // null до первой синхронизации или если аватарка не установлена.
  // Приоритетнее _avatarBase64 при рендеринге.
  String? _urlAvatar;
  // Идёт ли сейчас загрузка фото в S3 — блокирует повторный тап на аватарку
  // и показывает spinner поверх виджета.
  bool _isUploadingAvatar = false;
  // Аватар (base64-JPEG) — local-only, fallback пока server-URL не получен
  // или как оптимистичный preview в момент загрузки. Backend теперь
  // поддерживает upload через ObjectStorage.Profile.*.
  String? _avatarBase64;
  // Альтернатива _avatarBase64 — индекс preset-аватара (стилизованная
  // авто-плитка из kSparkAvatarPresets). Mutual exclusive с base64.
  int? _avatarPresetIndex;

  String? _innError;
  String? _verifiedInn;
  String? _businessType;
  Map<String, dynamic>? _specialistProfile;
  int? _linkedCompanyId;
  Map<String, dynamic>? _linkedCompanyProfile;
  bool _isLoadingLinkedCompany = false;
  String? _linkedCompanyError;

  // После user-action смены роли (verify ИНН → company, reset → specialist)
  // backend имеет eventual consistency: GetProfile может несколько секунд
  // возвращать stale role. Без guard'а fetch перетирает только что
  // установленное local-state (role-guard в _fetchServerProfile чистит
  // _verifiedInn если server-role != 'company'). Этот pending-target
  // сохраняет «куда я только что перешёл» — пока server не подтвердит
  // через GetProfile или не истечёт окно eventual consistency, fetch
  // не имеет права менять role/company-поля.
  String? _pendingTargetRole;
  DateTime? _pendingTargetSince;
  // Eventual-consistency window — типичный backend write-replication
  // SLA. Если сервер за это время не подтвердил новую роль —
  // прекращаем верить локальному пендингу (вдруг backend потерял
  // update). Тестировалось 10-15s; 20s — c запасом.
  static const Duration _pendingRoleTimeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBusinessStatus();
    // Refresh when the profile changes elsewhere — e.g. accepting a staff
    // invite from a notification links a company that must show up here
    // immediately (B7). The screen stays mounted in the shell IndexedStack,
    // so it receives the signal even when another tab is active.
    SparkJoyProfileRefreshBus.notifier.addListener(_onProfileRefreshRequested);
  }

  void _onProfileRefreshRequested() {
    if (!mounted) return;
    unawaited(_fetchServerProfile());
    unawaited(_loadBusinessStatus());
  }

  @override
  void dispose() {
    SparkJoyProfileRefreshBus.notifier.removeListener(
      _onProfileRefreshRequested,
    );
    _innController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _fallbackSpecialist() {
    return cloneMap(
      sparkSpecialists.firstWhere(
        (s) => sjRead(s, 'id') == kSparkSpecialistId,
        orElse: () => sparkSpecialists.first,
      ),
    );
  }

  Map<String, dynamic> _specialist() {
    final fallback = _fallbackSpecialist();
    final profile = _specialistProfile;
    if (profile == null) return fallback;
    return {...fallback, ...profile};
  }

  void _applyProfileToControllers(Map<String, dynamic> profile) {
    // Сначала пробуем структурированные поля; если их нет — мигрируем
    // legacy single `name` (Фамилия Имя Отчество, разделённые пробелами).
    final structuredFirst = sjRead(profile, 'firstName').trim();
    final structuredLast = sjRead(profile, 'lastName').trim();
    final structuredMiddle = sjRead(profile, 'middleName').trim();
    if (structuredFirst.isNotEmpty ||
        structuredLast.isNotEmpty ||
        structuredMiddle.isNotEmpty) {
      _firstNameController.text = structuredFirst;
      _lastNameController.text = structuredLast;
      _middleNameController.text = structuredMiddle;
    } else {
      final parts = sjRead(
        profile,
        'name',
      ).trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      _lastNameController.text = parts.isNotEmpty ? parts[0] : '';
      _firstNameController.text = parts.length > 1 ? parts[1] : '';
      _middleNameController.text = parts.length > 2
          ? parts.sublist(2).join(' ')
          : '';
    }
    _cityController.text = sjRead(profile, 'city');
    _phoneController.text = sjRead(profile, 'phone');
    _emailController.text = sjRead(profile, 'email');
    _specializationController.text = _extractSpecializationText(profile);
    _companyNameController.text = sjRead(profile, 'companyName');
    // Запоминаем оригиналы — diff-baseline для _pushProfileToServer.
    // Только реально изменённые поля улетают в UpdateProfile (без
    // этого присутствие `email` в payload триггерит лишний verify).
    _originalEmail = sjRead(profile, 'email').trim();
    _originalFirstName = _firstNameController.text.trim();
    _originalLastName = _lastNameController.text.trim();
    _originalMiddleName = _middleNameController.text.trim();
    _originalCity = _cityController.text.trim();
    _originalDescription = _specializationController.text.trim();
    _originalCompanyName = _companyNameController.text.trim();
  }

  /// Собирает ФИО обратно в одну строку «Фамилия Имя Отчество» для
  /// legacy-полей которые ещё ожидают `name` (карточки, summary и т.п.).
  String _composeFullName() {
    final parts = <String>[
      _lastNameController.text.trim(),
      _firstNameController.text.trim(),
      _middleNameController.text.trim(),
    ].where((p) => p.isNotEmpty);
    return parts.join(' ');
  }

  int? _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  /// Reads the profile's specialization as a plain-text description.
  /// Legacy profiles stored it as a `specializations` list of tags;
  /// we format those as a bullet list so the textarea reads
  /// consistently with the current append-chip UX. New saves always
  /// write the single `specialization` string.
  String _extractSpecializationText(Map<String, dynamic> profile) {
    final text = sjRead(profile, 'specialization').trim();
    if (text.isNotEmpty) return text;
    final fromList = profile['specializations'];
    if (fromList is List && fromList.isNotEmpty) {
      final parts = <String>[];
      for (final raw in fromList) {
        final value = raw.toString().trim();
        if (value.isNotEmpty) parts.add('• $value');
      }
      return parts.join('\n');
    }
    return '';
  }

  Future<void> _loadProfile() async {
    // Cache-as-seed: если local cache есть (последний server snapshot),
    // используем его для мгновенного заполнения form-controllers — юзер
    // сразу видит свои данные на cold start, не ждёт network round-trip.
    // На fresh install / logout cache отсутствует: чистим personal-поля
    // mock seed (rating/reportCount остаются для stat-карточек) чтобы
    // mock-данные («Максим Егоров», «egorov@mail.ru») не протекли через
    // _specialist() в build() header или emailChanged-detection.
    // Form-controllers стартуют пустыми. Параллельно всегда тянем
    // свежий server snapshot через _fetchServerProfile().
    final cached = await SparkJoyStorage.loadSpecialistProfileOrNull();
    final pending = await UserSimplePreferences.getPendingEmailVerify();
    final avatar = await UserSimplePreferences.getAvatarBase64();
    if (!mounted) return;
    if (cached != null) {
      // Мерджим cache поверх mock base — base даёт metadata
      // (rating/reportCount/experience/status), cache перебивает
      // personal-поля. Apply controllers — UI заполнится сразу.
      final base = _fallbackSpecialist();
      final merged = <String, dynamic>{...base, ...cached};
      _applyProfileToControllers(merged);
      final cachedUrl = (cached['urlAvatar'] as String? ?? '').trim();
      setState(() {
        _specialistProfile = merged;
        _pendingEmailVerify = pending;
        if (cachedUrl.isNotEmpty) _urlAvatar = cachedUrl;
        _avatarBase64 = avatar;
        _avatarPresetIndex = null;
      });
    } else {
      final seed = _fallbackSpecialist();
      // Используем remove (а не set='') — sjRead возвращает fallback
      // только на null/missing key. Иначе header «Специалист» (см.
      // build() — sjRead(specialist, 'name', fallback: 'Специалист'))
      // станет пустой строкой вместо корректного fallback'а.
      for (final key in const <String>[
        'name',
        'firstName',
        'lastName',
        'middleName',
        'email',
        'phone',
        'city',
        'specialization',
        'specializations',
        'companyName',
        'companyId',
      ]) {
        seed.remove(key);
      }
      setState(() {
        _specialistProfile = seed;
        _pendingEmailVerify = pending;
        _avatarBase64 = avatar;
        _avatarPresetIndex = null;
      });
    }
    unawaited(_fetchServerProfile());
  }

  /// Тянет профиль с сервера и перезаписывает контроллеры —
  /// server-данные приоритетнее локальных.
  ///
  /// Race-protection: каждый вызов захватывает `myGen` в начале.
  /// Если кто-то bumped `_fetchGeneration` (например _resetBusinessStatus
  /// invalidate'ил in-flight fetch'ы), результат тихо отбрасывается —
  /// мы не имеем права писать в state, иначе stale snapshot откатит UI.
  ///
  /// Sheet-based editor держит свой локальный TextEditingController;
  /// фоновый fetch свободно может переписать screen-level controllers —
  /// открытый sheet не пострадает (он берёт snapshot в начале и пишет
  /// обратно только на «Сохранить»).
  Future<void> _fetchServerProfile() async {
    final myGen = ++_fetchGeneration;
    try {
      final result = await storage_api.StorageApi.getProfile();
      if (!mounted || myGen != _fetchGeneration) return;
      // Server-side role («specialist» / «company» / «client») — единый
      // источник правды для роли. Синкаем в локальные prefs до setState,
      // чтобы shell-callback увидел консистентное состояние.
      final serverRole = (result['role'] ?? '').toString().trim();

      // Eventual-consistency guard: если юзер только что переключил
      // роль (verify ИНН или reset), backend может ещё несколько секунд
      // возвращать старую роль. Доверяем local-pending'у в окне таймаута.
      //
      // Pending НЕ очищается даже когда сервер один раз подтвердил
      // новую роль — потому что у бэка могут быть распределённые реплики:
      // первый GetProfile вернул свежий `specialist`, но следующий
      // (на другой реплике) ещё отдаёт stale `company`. Если очистить
      // pending на первом match, второй ответ просочится → UI flick'нется
      // обратно. Pending снимается ТОЛЬКО по timeout — окно фиксированное.
      final pendingTarget = _pendingTargetRole;
      final pendingSince = _pendingTargetSince;
      final pendingExpired =
          pendingSince != null &&
          DateTime.now().difference(pendingSince) > _pendingRoleTimeout;
      final pendingActive = pendingTarget != null && !pendingExpired;
      final serverMatchesPending =
          pendingTarget != null && serverRole.toLowerCase() == pendingTarget;

      if (pendingExpired) {
        _pendingTargetRole = null;
        _pendingTargetSince = null;
      }

      // Если pending активен и server ещё не догнал — переопределяем
      // effective-роль локальным pending'ом. _syncServerRoleToLocal,
      // setState и cache-snapshot работают по effectiveRole, не по
      // server'у. Это держит UI стабильным в окне eventual consistency.
      final effectiveRole = pendingActive && !serverMatchesPending
          ? pendingTarget
          : serverRole;
      await _syncServerRoleToLocal(effectiveRole, result['companyInn']);
      if (!mounted || myGen != _fetchGeneration) return;
      // Все company-поля применяем ТОЛЬКО когда effective-role == 'company'.
      // Это закрывает два сценария:
      //   1) Reset завершился, fetch ещё видит stale role='company' →
      //      effectiveRole='specialist' (из pending), company-поля
      //      зачищаются.
      //   2) Promote завершился, fetch ещё видит stale role='specialist' →
      //      effectiveRole='company' (из pending), company-поля
      //      сохраняются (server потом догонит и pending очистится).
      final isCompanyRole = effectiveRole.toLowerCase() == 'company';
      final linkedCompanyId = isCompanyRole
          ? null
          : _readInt(result['companyId']);
      Map<String, dynamic>? linkedCompanyProfile;
      String? linkedCompanyError;
      if (linkedCompanyId != null && linkedCompanyId > 0) {
        if (mounted && myGen == _fetchGeneration) {
          setState(() {
            _linkedCompanyId = linkedCompanyId;
            _linkedCompanyProfile = null;
            _isLoadingLinkedCompany = true;
            _linkedCompanyError = null;
          });
        }
        try {
          final company = await storage_api.StorageApi.getCompanyProfile(
            companyId: linkedCompanyId,
          );
          linkedCompanyProfile = company.isEmpty ? null : company;
          if (linkedCompanyProfile == null) {
            linkedCompanyError = 'Компания не найдена';
          }
        } catch (e) {
          linkedCompanyError = 'Не удалось загрузить компанию';
          if (kDebugMode) {
            debugPrint('[profile] GetCompanyProfile failed: $e');
          }
        }
      }
      if (!mounted || myGen != _fetchGeneration) return;
      // Маппим server fields в текущий profile-map поверх локальных,
      // потом переприменяем через _applyProfileToControllers — это
      // переиспользует мигратор legacy `name` если структурированных
      // полей нет.
      final merged = <String, dynamic>{
        ...(_specialistProfile ?? const <String, dynamic>{}),
        if (result['firstName'] != null) 'firstName': result['firstName'],
        if (result['lastName'] != null) 'lastName': result['lastName'],
        if (result['middleName'] != null) 'middleName': result['middleName'],
        if (result['email'] != null) 'email': result['email'],
        if (result['phone'] != null) 'phone': result['phone'],
        if (result['description'] != null)
          'specialization': result['description'],
        if (result['companyId'] != null) 'companyId': result['companyId'],
        // Server отдаёт companyInn как int — приводим к строке для
        // унификации с _verifiedInn (тоже String).
        if (isCompanyRole && result['companyName'] != null)
          'companyName': result['companyName'].toString(),
      };
      // Когда роль specialist — явно зачищаем кэш-снимок company-полей,
      // чтобы _applyProfileToControllers стёр companyName-controller.
      if (!isCompanyRole) {
        merged.remove('companyName');
      }
      // city пока не в GetProfile response, но возможно появится —
      // на всякий случай маппим.
      if (result['city'] != null) merged['city'] = result['city'];
      _applyProfileToControllers(merged);
      final serverInn = result['companyInn'];
      final serverUrlAvatar = result['urlAvatar']?.toString().trim() ?? '';
      setState(() {
        _specialistProfile = merged;
        _urlAvatar = serverUrlAvatar.isNotEmpty ? serverUrlAvatar : null;
        _linkedCompanyId = linkedCompanyId;
        _linkedCompanyProfile = linkedCompanyProfile;
        _linkedCompanyError = linkedCompanyError;
        _isLoadingLinkedCompany = false;
        if (isCompanyRole) {
          _isVerifyCompany = result['isVerifyCompany'] == true;
          if (serverInn != null) {
            final innStr = serverInn.toString();
            _verifiedInn = innStr;
            _innController.text = innStr;
          }
        } else {
          // Specialist-режим: company-карточка скрыта. Чистим in-memory
          // company-state даже если бэк вернул stale-поля — UI следует
          // за ролью, а не за company-полями.
          _isVerifyCompany = null;
          _verifiedInn = null;
          _innController.text = '';
        }
        if (isCompanyRole || linkedCompanyId == null) {
          _linkedCompanyId = null;
          _linkedCompanyProfile = null;
          _linkedCompanyError = null;
          _isLoadingLinkedCompany = false;
        }
      });
      // Authoritative server snapshot → local cache. Полная замена
      // (не merge) чтобы reset/downgrade корректно очищали cached
      // company-поля, которых нет в новом response. Сохраняем только
      // server-полученные поля + computed (без mock metadata),
      // иначе следующий cold start засосёт mock rating/reportCount
      // как «cached» — и они никогда не очистятся.
      final cacheSnapshot = <String, dynamic>{
        if (result['firstName'] != null) 'firstName': result['firstName'],
        if (result['lastName'] != null) 'lastName': result['lastName'],
        if (result['middleName'] != null) 'middleName': result['middleName'],
        if (result['email'] != null) 'email': result['email'],
        if (result['phone'] != null) 'phone': result['phone'],
        if (result['description'] != null)
          'specialization': result['description'],
        if (result['companyId'] != null) 'companyId': result['companyId'],
        if (isCompanyRole && result['companyName'] != null)
          'companyName': result['companyName'].toString(),
        if (result['city'] != null) 'city': result['city'],
        if (result['role'] != null) 'role': result['role'],
        'urlAvatar': result['urlAvatar'],
        if (isCompanyRole && serverInn != null)
          'companyInn': serverInn.toString(),
        if (isCompanyRole && result['isVerifyCompany'] != null)
          'isVerifyCompany': result['isVerifyCompany'] == true,
      };
      unawaited(SparkJoyStorage.saveSpecialistProfile(cacheSnapshot));
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      // Offline / network / parsing. Раньше silent — но controllers
      // теперь стартуют пустыми (см. _loadProfile), и без обратной связи
      // юзер видит просто пустую форму и не понимает что произошло.
      // Показываем тонкий снэк, дальнейшее редактирование возможно —
      // на save UpdateProfile сам ретрайнется.
      if (kDebugMode) {
        debugPrint('[profile] GetProfile failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось загрузить профиль. Проверьте соединение'),
        ),
      );
    }
  }

  /// Fire-and-forget push изменений профиля на сервер. Локально уже
  /// сохранено к этому моменту — на ошибку показываем тонкий снэк
  /// (или silent если можно).
  Future<bool> _pushProfileToServer() async {
    final payload = <String, dynamic>{};
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final email = _emailController.text.trim();
    final city = _cityController.text.trim();
    final description = _specializationController.text.trim();
    final companyName = _companyNameController.text.trim();
    final companyInn = (_verifiedInn ?? '').trim();

    // Diff-based payload: шлём ТОЛЬКО изменившиеся поля. Server на
    // каждое присутствие `email` в payload запускает verify-flow —
    // если шлём прежний email при save (например, поменялся только
    // город), пользователь получает лишнее письмо с кодом.
    final emailChanged =
        email.isNotEmpty && email.toLowerCase() != _originalEmail.toLowerCase();
    final firstNameChanged = firstName != _originalFirstName;
    final lastNameChanged = lastName != _originalLastName;
    final middleNameChanged = middleName != _originalMiddleName;
    final cityChanged = city != _originalCity;
    final descriptionChanged = description != _originalDescription;
    final companyNameChanged = companyName != _originalCompanyName;

    // Шлём all changed fields включая пустые — иначе пользователь не
    // может очистить optional поля (description, middleName, etc).
    // Required-fields (lastName/firstName/email/city) гейтятся
    // validator'ом формы — _saveProfile.validate() не пропустит empty.
    // Server сам отвергнет некорректные значения если нужно.
    // emailChanged уже включает .isNotEmpty проверку выше (clear email
    // не разрешается — это identity-поле, требует verify-flow).
    if (lastNameChanged) payload['lastName'] = lastName;
    if (firstNameChanged) payload['firstName'] = firstName;
    if (middleNameChanged) payload['middleName'] = middleName;
    if (emailChanged) payload['email'] = email;
    if (cityChanged) payload['city'] = city;
    if (descriptionChanged) {
      payload['description'] = description;
    }
    // companyName и companyInn сервер сохраняет только парой — шлём
    // обе если companyName изменилось и обе непустые. ИНН по
    // отдельности не меняется через save: его флоу — `_verifyInn`.
    if (companyNameChanged && companyName.isNotEmpty && companyInn.isNotEmpty) {
      payload['companyName'] = companyName;
      // Server ожидает companyInn как строку (см. UpdateProfile
      // schema), хотя в GetProfile возвращается как integer.
      payload['companyInn'] = companyInn;
    }
    if (payload.isEmpty) return true;

    try {
      await storage_api.StorageApi.updateProfile(profile: payload);
      if (!mounted) return false;
      // Двигаем все originals вперёд — server теперь знает эти
      // значения, и следующий save с теми же controllers должен дать
      // пустой diff (никаких лишних UpdateProfile вызовов).
      _originalFirstName = firstName;
      _originalLastName = lastName;
      _originalMiddleName = middleName;
      _originalCity = city;
      _originalDescription = description;
      if (companyNameChanged &&
          companyName.isNotEmpty &&
          companyInn.isNotEmpty) {
        _originalCompanyName = companyName;
      }
      // Patch local cache новыми server-accepted значениями. Merge
      // (не replace) — _fetchServerProfile при следующем заходе
      // переопределит из authoritative source.
      //
      // Email НЕ кешируем: после UpdateProfile с новым email сервер
      // уходит в pending-verify, primary email в БД остаётся прежним.
      // Если запатчить cache новым (неподтверждённым) email — на
      // cold start юзер увидит pending-значение, потом GetProfile
      // вернёт primary, и controller снова обновится. Хуже, если
      // юзер ввёл некорректный email (опечатка `.ru` вместо `.com`)
      // — он застрянет в cache навсегда. Email обновляется только
      // через _fetchServerProfile.success (authoritative).
      final cachePatch = Map<String, dynamic>.from(payload);
      cachePatch.remove('email');
      if (cachePatch.isNotEmpty) {
        unawaited(SparkJoyStorage.mergeIntoSpecialistProfileCache(cachePatch));
      }
      if (emailChanged) {
        // Email сменился — сервер отправил код подтверждения. Если
        // pending уже указывает на тот же email (повторный save без
        // подтверждения) — НЕ переоткрываем sheet и не сбрасываем
        // прогресс, только обновляем _originalEmail.
        final alreadyPending =
            _pendingEmailVerify?.toLowerCase() == email.toLowerCase();
        await UserSimplePreferences.setPendingEmailVerify(email);
        if (!mounted) return false;
        setState(() {
          _pendingEmailVerify = email;
          // Server теперь знает наш новый email — двигаем «origin»
          // вперёд, иначе повторный save без изменений снова бы
          // сматчился как emailChanged=true и зациклил auto-open.
          _originalEmail = email;
        });
        if (!alreadyPending) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            if (_pendingEmailVerify == null) return;
            unawaited(_promptEmailVerificationCode());
          });
        }
      } else if (_pendingEmailVerify != null &&
          _pendingEmailVerify!.toLowerCase() != email.toLowerCase()) {
        // Email не менялся в этом save, но pending всё ещё указывает на
        // другой адрес (edge: пользователь успел вернуться к
        // _originalEmail до того как fetch синкнул state). Чистим
        // stale pending — banner не должен висеть для не-current email.
        await UserSimplePreferences.setPendingEmailVerify(null);
        if (!mounted) return false;
        setState(() => _pendingEmailVerify = null);
      }
      return true;
    } on storage_api.SessionExpiredException {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[profile] UpdateProfile failed: $e');
      }
      if (!mounted) return false;
      // Сёрфим КОНКРЕТНУЮ причину от бэкенда (например «Этот email уже
      // зарегистрирован») вместо generic «Не удалось сохранить профиль».
      // sparkJoyReadableError извлекает код ошибки из RPC-исключения и
      // маппит его в человекочитаемое сообщение (B3).
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось сохранить профиль',
      );
      return false;
    }
  }

  /// Приводит локальный кэш роли (UserSimplePreferences + SparkJoyStorage
  /// + локальный `_businessType`) к серверной правде. Раньше при login'е
  /// записывалась роль по локальной эвристике (verifyInnAndPromote);
  /// если backend поменял роль или JWT был issued под company, но
  /// локально валялся stale «specialist» — UI показывал не то.
  ///
  /// Server role → action:
  /// - `company`: пишем `userRole=company` + `SparkJoyStorage.login(company)`.
  ///   `_businessType` определяем по длине companyInn (10 → ИП, 12 →
  ///   ООО/Компания), либо ставим `'company'` если INN не пришёл —
  ///   это лучше чем оставлять null когда сервер уверенно говорит роль.
  /// - `specialist` / `client` / прочее: `userRole=specialist`,
  ///   `SparkJoyStorage.login(specialist)`, `_businessType = null`.
  ///
  /// Если роль реально поменялась — нотифицируем shell через
  /// `widget.onBusinessStatusChanged`, чтобы nav-bar пересобрался под
  /// актуальную роль. Без этого UI остаётся в старом режиме до
  /// перезапуска.
  Future<void> _syncServerRoleToLocal(
    String serverRole,
    Object? companyInnRaw,
  ) async {
    final normalizedRole = serverRole.toLowerCase();
    final isCompany = normalizedRole == 'company';
    final newRoleString = isCompany ? 'company' : 'specialist';

    // Маппинг companyInn → _businessType ('ip' для 10 цифр, 'company'
    // для 12; иначе fallback на 'company' если роль company).
    String? nextBusinessType;
    if (isCompany) {
      final innStr = companyInnRaw?.toString().trim() ?? '';
      if (innStr.length == 10) {
        nextBusinessType = 'ip';
      } else if (innStr.length == 12) {
        nextBusinessType = 'company';
      } else {
        nextBusinessType = 'company';
      }
    }

    // Записываем в локальные prefs (используется shell'ом и onboarding'ом).
    await UserSimplePreferences.setUserRole(newRoleString);
    await SparkJoyStorage.login(
      isCompany ? SparkJoyRole.company : SparkJoyRole.specialist,
    );

    // JWT refresh после смены роли централизован в StorageApi.updateProfile:
    // если payload содержит role='company'/'specialist', токены
    // ротируются сразу после успешного Storage.UpdateProfile.

    if (!mounted) return;
    final roleChanged = _businessType != nextBusinessType;
    if (roleChanged) {
      setState(() {
        _businessType = nextBusinessType;
      });
      // Нотифицируем shell — он пересоберёт nav-bar под актуальную
      // роль. Без этого новая роль применится только после рестарта.
      widget.onBusinessStatusChanged?.call(nextBusinessType);
    }
  }

  Future<void> _loadBusinessStatus() async {
    final inn = await SparkJoyStorage.currentVerifiedInn();
    final businessType = await SparkJoyStorage.currentBusinessType();
    final localRole = await SparkJoyStorage.currentRole();
    if (!mounted) return;
    setState(() {
      // Race-guard: если server fetch уже установил _verifiedInn —
      // не затираем свежее серверное значение локальным стейл-кэшем.
      // Когда инспектор делает Сбросить (см. _resetBusinessStatus),
      // он явно ставит _verifiedInn = null, и тогда локальное значение
      // всё равно не подхватится — но это ожидаемое поведение reset'а.
      //
      // Role-guard: если local role == specialist (после reset или
      // первоначально), подтягивать companyInn нельзя даже из локального
      // кэша — иначе на cold-start с stale local INN карточка «Компания»
      // мигнёт до прихода server-ответа и зафиксируется при offline.
      final isCompanyRoleLocal = localRole == SparkJoyRole.company;
      if (isCompanyRoleLocal &&
          _verifiedInn == null &&
          inn != null &&
          inn.isNotEmpty) {
        _verifiedInn = inn;
        _innController.text = inn;
      }
      if (isCompanyRoleLocal) {
        _businessType ??= businessType;
      }
    });
  }

  String _businessTypeLabel() {
    if (_businessType == 'ip') return 'ИП';
    return 'Компания';
  }

  String? _innValidator(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Введите ИНН';
    final normalized = SparkJoyStorage.normalizeInn(raw);
    if (normalized.length != 10 && normalized.length != 12) {
      return 'ИНН должен содержать 10 или 12 цифр';
    }
    if (!SparkJoyStorage.isValidInn(normalized, strict: false)) {
      return 'Введите корректный ИНН';
    }
    return null;
  }

  Future<void> _verifyInn() async {
    if (_isVerifying) return;
    final validationError = _innValidator(_innController.text);
    if (validationError != null) {
      setState(() => _innError = validationError);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final companyName = _companyNameController.text.trim();
    if (companyName.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала укажите название компании, затем подтверждайте ИНН',
          ),
        ),
      );
      return;
    }
    final normalizedInn = SparkJoyStorage.normalizeInn(_innController.text);

    HapticFeedback.mediumImpact();
    setState(() => _isVerifying = true);

    try {
      // UpdateProfile с парой companyName+companyInn + role='company':
      // сервер валидирует ИНН и поднимает isVerifyCompany=false (на
      // модерации). Раньше тут был local mock с 700ms-имитацией.
      await storage_api.StorageApi.updateProfile(
        profile: <String, dynamic>{
          'role': 'company',
          'companyName': companyName,
          'companyInn': normalizedInn,
        },
      );
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verifiedInn = normalizedInn;
        _innController.text = normalizedInn;
        _innError = null;
        // Pending guard: до тех пор пока GetProfile не подтвердит
        // role='company', не позволяем fetch'ам перезатереть только что
        // установленное состояние (eventual consistency на бэке).
        _pendingTargetRole = 'company';
        _pendingTargetSince = DateTime.now();
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Данные компании отправлены на модерацию'),
        ),
      );
      // Re-fetch GetProfile подтянет isVerifyCompany + актуальную роль
      // от сервера. StorageApi.updateProfile уже обновил токены после
      // role='company'. Если backend ещё не успел реплицировать —
      // pending-guard сохранит local-state.
      unawaited(_fetchServerProfile());
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Не удалось отправить данные компании: $e'),
          backgroundColor: kRedColor,
        ),
      );
    }
  }

  /// Open a dialog to rename the verified company without full reset.
  /// Sends UpdateProfile со существующим ИНН + новым companyName —
  /// сервер перезапустит модерацию (isVerifyCompany=false до проверки).
  /// Альтернатива «сбросить → новая регистрация», которая удаляла бы
  /// drafts/штат — здесь только rename, минимально-инвазивно.
  Future<void> _promptEditCompanyName() async {
    if (_isVerifyingCompanyName) return;
    final currentInn = _verifiedInn?.trim() ?? '';
    if (currentInn.isEmpty) return;
    final initial = _companyNameController.text.trim();
    final controller = TextEditingController(text: initial);
    String? error;
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocal) {
            void submit() {
              final value = controller.text.trim();
              if (value.isEmpty) {
                setLocal(() => error = 'Введите название компании');
                return;
              }
              if (value == initial) {
                Navigator.of(dialogCtx).pop();
                return;
              }
              Navigator.of(dialogCtx).pop(value);
            }

            return AlertDialog(
              title: const Text('Изменить название компании'),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(255)],
                onChanged: (_) {
                  if (error != null) setLocal(() => error = null);
                },
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  hintText: 'ООО «Авто-Подбор»',
                  errorText: error,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: submit,
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
    _disposeTextControllersAfterRouteClose(controller);
    if (newName == null || !mounted) return;

    setState(() => _isVerifyingCompanyName = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await storage_api.StorageApi.updateProfile(
        profile: <String, dynamic>{
          'role': 'company',
          'companyName': newName,
          'companyInn': currentInn,
        },
      );
      if (!mounted) return;
      setState(() {
        _isVerifyingCompanyName = false;
        _companyNameController.text = newName;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Название обновлено, отправлено на повторную модерацию',
          ),
        ),
      );
      // _fetchServerProfile подтянет свежий isVerifyCompany (false до
      // проверки) и зафиксирует новое имя в _specialistProfile.
      unawaited(_fetchServerProfile());
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() => _isVerifyingCompanyName = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifyingCompanyName = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Не удалось обновить название: $e'),
          backgroundColor: kRedColor,
        ),
      );
    }
  }

  /// Hard-reset the company role. Shows a confirmation dialog
  /// enumerating every piece of local data that will be wiped
  /// (drafts, pending invites, staff preferences) so the user can't
  /// lose work by accident. На confirm сначала шлём UpdateProfile
  /// с role='specialist' (зеркально к _verifyInn — server-first), и
  /// только после server success делаем локальный cleanup через
  /// [SparkJoyStorage.cancelCompanyMode] + явный _syncServerRoleToLocal
  /// (для refreshTokens + role-prefs sync) + cache patch.
  ///
  /// **НЕ** вызываем _fetchServerProfile() сразу: backend имеет
  /// eventual consistency на смене role, его GetProfile в окне
  /// нескольких секунд после downgrade всё ещё возвращает stale
  /// company-state (companyName/companyInn/role='company') — и
  /// _applyProfileToControllers перезаписал бы только что очищенные
  /// controllers, а setState восстановил бы _verifiedInn. UI откатился
  /// бы обратно в company. На следующем заходе в профиль
  /// _fetchServerProfile сам подтянет актуальное.
  Future<void> _resetBusinessStatus() async {
    if (_isVerifying) return;
    final messenger = ScaffoldMessenger.of(context);
    final summary = await SparkJoyStorage.buildCompanyCancelSummary();
    if (!mounted) return;
    final confirmed = await _showCancelCompanyDialog(summary);
    if (confirmed != true) return;
    // Invalidate любой in-flight _fetchServerProfile. Без этого fetch,
    // запущенный из _loadProfile (или другого пути) до клика «Сбросить»,
    // мог вернуться с stale company-snapshot после нашего setState reset
    // и восстановить _verifiedInn/_isVerifyCompany — UI откатился бы
    // обратно в company. Generation guard в _fetchServerProfile тихо
    // отбрасывает результат при mismatch.
    _fetchGeneration++;
    setState(() => _isVerifying = true);
    // Флаг для catch'а: server downgrade уже применился (БД пишет
    // specialist), последующий fail — это уже local-sync проблема,
    // НЕ "не удалось сбросить". Без флага юзер видит «не удалось»,
    // но при заходе через секунду статус оказывается сброшенным —
    // путаница.
    var serverDowngraded = false;
    try {
      await storage_api.StorageApi.updateProfile(
        profile: <String, dynamic>{'role': 'specialist'},
      );
      serverDowngraded = true;
      // Sync local prefs role. **ПЕРЕД** cancelCompanyMode:
      // последний внутри вызывает resetBusinessVerification который сам
      // ставит UserSimplePreferences.setUserRole('specialist'). Если
      // _syncServerRoleToLocal позвать ПОСЛЕ — он прочитает previousRole=
      // 'specialist' (только что установленный), и shell может не увидеть
      // смену роли. JWT refresh делает StorageApi.updateProfile сразу
      // после успешного role='specialist'.
      await _syncServerRoleToLocal('specialist', null);
      await SparkJoyStorage.cancelCompanyMode();
      // Patch local profile cache — удаляем company-поля и
      // фиксируем role='specialist'. Иначе следующий cold start
      // в profile screen использовал бы stale cache как seed.
      final cached =
          await SparkJoyStorage.loadSpecialistProfileOrNull() ??
          <String, dynamic>{};
      cached.remove('companyName');
      cached.remove('companyInn');
      cached.remove('isVerifyCompany');
      // role в cache не сохраняем — никто из cache его не читает
      // (role — это UserSimplePreferences.userRole, синкается через
      // _syncServerRoleToLocal). Раньше тут было cached['role']='specialist',
      // но это dead-write — убрал чтобы не путать.
      unawaited(SparkJoyStorage.saveSpecialistProfile(cached));
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verifiedInn = null;
        _businessType = null;
        // Сбрасываем и связанное состояние компании, иначе в unverified-
        // карточке остался бы prefilled старый companyName + протёкший
        // badge модерации.
        _isVerifyCompany = null;
        _companyNameController.clear();
        _innController.clear();
        // Diff baseline: следующий save с пустым companyName не должен
        // считаться «изменением» (всё равно отсечётся проверкой на
        // непустоту в _pushProfileToServer, но семантически правильно).
        _originalCompanyName = '';
        // Pending guard: pull-to-refresh после reset может вернуть stale
        // role='company' (eventual consistency); pending переопределит
        // server-role на 'specialist' пока бэк не догонит.
        _pendingTargetRole = 'specialist';
        _pendingTargetSince = DateTime.now();
      });
      widget.onBusinessStatusChanged?.call(null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Статус сброшен: теперь вы специалист')),
      );
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            serverDowngraded
                ? 'Статус сброшен на сервере, но локальная синхронизация '
                      'не удалась. Перезайдите в профиль для обновления.'
                : 'Не удалось сбросить статус: $e',
          ),
          backgroundColor: kRedColor,
        ),
      );
    }
  }

  Future<bool?> _showCancelCompanyDialog(CompanyCancelSummary s) {
    // Enumerate only the categories that actually have data so the
    // bullet list doesn't waste space on zeros. An empty summary still
    // shows the generic "your account will switch to specialist" line.
    final bullets = <String>[];
    if (s.totalDrafts > 0) {
      final assigned = s.assignedDrafts;
      final invites = s.pendingInviteDrafts;
      final breakdown = <String>[];
      if (assigned > 0) breakdown.add('$assigned назначено сотрудникам');
      if (invites > 0) breakdown.add('$invites ожидают приглашения');
      final suffix = breakdown.isEmpty ? '' : ' (${breakdown.join(', ')})';
      bullets.add(
        '${s.totalDrafts} ${_draftsPlural(s.totalDrafts)} будут удалены$suffix',
      );
    }
    if (s.promotedStaff > 0 || s.hiddenStaff > 0) {
      bullets.add('Настройки штата (повышенные/скрытые) будут очищены');
    }
    bullets.add('Ваш аккаунт станет специалистом');

    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SparkRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SparkSpace.xxxl,
            SparkSpace.xxxl,
            SparkSpace.xxxl,
            SparkSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MyText(
                text: 'Сбросить статус компании?',
                size: SparkTextSize.title,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: SparkSpace.md),
              const MyText(
                text: 'После сброса:',
                size: SparkTextSize.body,
                color: kGreyColor,
              ),
              const SizedBox(height: SparkSpace.sm),
              for (final b in bullets) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: SparkSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: '• ',
                        size: SparkTextSize.body,
                        color: kGreyColor,
                      ),
                      Expanded(
                        child: MyText(
                          text: b,
                          size: SparkTextSize.body,
                          color: kTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: SparkSpace.sm),
              const MyText(
                text: 'Это действие необратимо.',
                size: SparkTextSize.caption,
                color: kRedColor,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: SparkSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: SparkSpace.md),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: kRedColor),
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      child: const Text('Сбросить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _draftsPlural(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'черновик';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'черновика';
    }
    return 'черновиков';
  }

  String? _emailValidator(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final isValid = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(raw);
    if (!isValid) return 'Введите корректный Email';
    return null;
  }

  /// Открывает диалог ввода кода подтверждения email (6-значный код
  /// приходит на email после смены через UpdateProfile). После ввода
  /// дёргает `Storage.VerifyEmail({code})` и показывает результат
  /// snackbar'ом. Контракт — `{code: string}` per backend пример.
  /// GetProfile пока не возвращает флаг isVerifyEmail, поэтому UI
  /// статуса нет — только success/error по результату метода.
  /// Показывать ли persistent banner «Email ждёт подтверждения». Условие:
  /// pending state установлен и совпадает с текущим email (case-
  /// insensitive). Email передаётся параметром, а не читается через
  /// `_emailController.text` напрямую — caller (ValueListenableBuilder)
  /// уже подсовывает свежее значение и гарантирует rebuild на каждый
  /// keystroke.
  bool _shouldShowEmailPendingBanner(String currentEmail) {
    final pending = _pendingEmailVerify?.trim().toLowerCase() ?? '';
    if (pending.isEmpty) return false;
    return pending == currentEmail.trim().toLowerCase();
  }

  /// Жёлтый banner в шапке профиля: «⚠️ Email `email` ждёт подтверждения».
  /// Inline-кнопка «Подтвердить» открывает code-entry sheet — тот же путь
  /// что и автоматическое открытие после save.
  Widget _buildEmailPendingBanner() {
    final email = _pendingEmailVerify ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.lg,
        vertical: SparkSpace.md,
      ),
      decoration: BoxDecoration(
        color: kYellowColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SparkRadius.md),
        border: Border.all(color: kYellowColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            color: kYellowColor,
            size: SparkSize.iconMd,
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: 'Email ждёт подтверждения',
                  size: SparkTextSize.body,
                  weight: FontWeight.w700,
                  color: kTertiaryColor,
                ),
                const SizedBox(height: 2),
                MyText(
                  text: email,
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.md),
          FilledButton(
            onPressed: _isVerifyingEmail ? null : _promptEmailVerificationCode,
            style: FilledButton.styleFrom(
              backgroundColor: kYellowColor,
              foregroundColor: kWhiteColor,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.lg,
                vertical: SparkSpace.sm,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SparkRadius.md),
              ),
            ),
            child: Text(_isVerifyingEmail ? '...' : 'Подтвердить'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptEmailVerificationCode() async {
    if (_isVerifyingEmail) return;
    var codeValue = '';
    String? codeError;
    final action = await showDialog<_EmailVerifyAction>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            void submit() {
              final value = codeValue.trim();
              if (value.length < 6) {
                setLocalState(
                  () => codeError = 'Введите 6-значный код из письма',
                );
                return;
              }
              Navigator.of(dialogContext).pop(_EmailVerifyAction.confirm);
            }

            return AlertDialog(
              title: const Text('Подтверждение email'),
              // AutofillGroup обязателен для того чтобы Flutter передал
              // `autofillHints` в системный autofill provider. На iOS
              // это включает Security Code AutoFill — система скан Mail
              // на код вида «Your code is 123456» и предлагает его в
              // QuickType-баре над клавиатурой. На web транслируется в
              // HTML `autocomplete="one-time-code"` — Chrome предлагает
              // из буфера/messaging-suggestions. Android: ОС не детектит
              // email-OTP, инспектор копирует вручную.
              content: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Введите код, который мы отправили на '
                      '${_emailController.text.trim()}.',
                    ),
                    const SizedBox(height: SparkSpace.md),
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      autofillHints: const <String>[AutofillHints.oneTimeCode],
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        // Backend пример показывает 6-значный код.
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(fontSize: 24, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        errorText: codeError,
                        counterText: '',
                      ),
                      onChanged: (value) {
                        codeValue = value;
                        if (codeError != null) {
                          setLocalState(() => codeError = null);
                        }
                        // Auto-submit когда введены все 6 цифр — экономит
                        // лишний тап. Autofill вставляет код одним блоком
                        // и сразу триггерит submit. Через `Future.microtask`
                        // дилог закроется на следующем тике event-loop,
                        // после того как onChanged полностью отработает —
                        // безопаснее чем синхронный Navigator.pop из
                        // обработчика ввода (защита от race с rebuild).
                        if (value.length == 6) {
                          Future.microtask(submit);
                        }
                      },
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: SparkSpace.sm),
                    const Text(
                      'Ошиблись адресом? Нажмите «Изменить email» — '
                      'отправим код заново.',
                      style: TextStyle(fontSize: 12, color: kGreyColor),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_EmailVerifyAction.editEmail),
                  child: const Text('Изменить email'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_EmailVerifyAction.cancel),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: submit,
                  child: const Text('Подтвердить'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (action == _EmailVerifyAction.editEmail) {
      // Пользователь понял, что код ушёл на неверный адрес — даём
      // исправить email прямо отсюда. _editEmailSheet → _saveProfile
      // перешлёт код на новый адрес (B4).
      await _editEmailSheet();
      return;
    }
    if (action != _EmailVerifyAction.confirm) return;

    setState(() => _isVerifyingEmail = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await storage_api.StorageApi.verifyEmail(code: codeValue.trim());
      if (!mounted) return;
      // Email подтверждён — clear pending state + persist. Banner на
      // экране профиля исчезнет на следующем rebuild'е через setState.
      await UserSimplePreferences.setPendingEmailVerify(null);
      if (!mounted) return;
      setState(() => _pendingEmailVerify = null);
      messenger.showSnackBar(
        const SnackBar(content: Text('Email подтверждён')),
      );
      // После verify backend начинает возвращать новый email как primary
      // в GetProfile. Мы не кешируем email из push payload (см. комментарий
      // в _pushProfileToServer.success), так что cache всё ещё имеет
      // старый primary. Re-fetch обновит cache на новый verified email
      // и подтянет актуальные флаги модерации.
      unawaited(_fetchServerProfile());
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      if (!mounted) return;
      // Конкретная причина от бэкенда (код истёк / неверный код / email
      // занят) вместо generic «Проверьте код» (B3).
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось подтвердить email',
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingEmail = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;
    // Валидация теперь происходит внутри bottom-sheet'а конкретного
    // поля до того, как sheet pop'нется и controllers обновятся.
    // Раньше тут был formKey.validate() для общей edit-form'ы.
    HapticFeedback.mediumImpact();
    setState(() => _isSavingProfile = true);

    // Запоминаем «до»-снимок email чтобы после save показать подсказку
    // «требует повторной верификации» если значение изменилось. Server
    // при смене email инвалидирует подтверждение, инспектор должен
    // открыть письмо и подтвердить новый адрес.
    final previousEmail = sjRead(_specialist(), 'email').trim();
    final newEmail = _emailController.text.trim();
    final emailChanged =
        newEmail.isNotEmpty &&
        newEmail.toLowerCase() != previousEmail.toLowerCase();

    // «Описание услуг» уходит на сервер как есть — модерация контактов в
    // обход платформы остаётся на сервере (локальный LLM-guard удалён).
    final description = _specializationController.text.trim();

    final current = _specialist();
    final next = {
      ...current,
      'id': sjRead(current, 'id', fallback: kSparkSpecialistId),
      // Структурированные ФИО + legacy `name` для совместимости с
      // остальным кодом, который ещё читает sjRead(profile, 'name').
      'lastName': _lastNameController.text.trim(),
      'firstName': _firstNameController.text.trim(),
      'middleName': _middleNameController.text.trim(),
      'name': _composeFullName(),
      'city': _cityController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'specialization': description,
      // Explicitly drop the legacy `specializations` list — the
      // string above is now the single source of truth. Without this
      // the stored list from older saves would keep drifting.
      'specializations': const <String>[],
      'companyName': _companyNameController.text.trim(),
    };
    // API-only mode: больше не пишем в SparkJoyStorage.saveSpecialistProfile.
    // Server становится единственным источником правды через
    // _pushProfileToServer + следующий _fetchServerProfile. `next` -
    // только in-memory state (для read-only view'а до server-ответа).

    if (!mounted) return;
    setState(() {
      _specialistProfile = next;
    });

    final serverSaved = await _pushProfileToServer();
    if (!mounted) return;
    setState(() => _isSavingProfile = false);
    if (!serverSaved) return;

    final messenger = ScaffoldMessenger.of(context);
    // Один тост на сохранение. Раньше «Профиль сохранён» + «Email изменён»
    // + guard-warning показывались тремя отдельными SnackBar'ами и
    // выстраивались в очередь, всплывая друг за другом (особенно заметно
    // при инлайн-правке города/имени — выглядело как два всплывающих
    // окна). Схлопываем в одно сообщение и гасим предыдущее (B5).
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          emailChanged
              ? 'Профиль сохранён. Email изменён — подтвердите по ссылке '
                    'из письма.'
              : 'Профиль сохранён',
        ),
      ),
    );
  }

  Widget _buildLinkedCompanyProfile() {
    if (_isLoadingLinkedCompany && _linkedCompanyProfile == null) {
      return const Row(
        children: [
          SizedBox(
            width: SparkSize.spinner,
            height: SparkSize.spinner,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: SparkSpace.md),
          Expanded(
            child: MyText(
              text: 'Загружаем компанию...',
              size: SparkTextSize.body,
              color: kGreyColor,
            ),
          ),
        ],
      );
    }

    final company = _linkedCompanyProfile;
    if (company == null || company.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.business_outlined,
                size: SparkSize.iconLg,
                color: kGreyColor,
              ),
              SizedBox(width: SparkSpace.md),
              Expanded(
                child: MyText(
                  text: 'Компания не загружена',
                  size: SparkTextSize.bodyLg,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.sm),
          MyText(
            text:
                _linkedCompanyError ??
                'Информация о компании появится после привязки к штату.',
            size: SparkTextSize.body,
            color: kGreyColor,
            lineHeight: 1.35,
          ),
          if (_linkedCompanyId != null) ...[
            const SizedBox(height: SparkSpace.lg),
            OutlinedButton.icon(
              onPressed: _fetchServerProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ],
      );
    }

    final name = sjRead(company, 'companyName', fallback: 'Компания').trim();
    final inn = sjRead(company, 'companyInn').trim();
    final avatarUrl = sjRead(company, 'urlAvatar').trim();
    final verified = company['isVerifyCompany'] == true;

    // Компактная карточка в одном ритме с «своей» компанией: детали
    // (город/описание) живут в публичном профиле, который открывает тап.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (avatarUrl.isEmpty)
          Container(
            width: SparkSize.icon5xl,
            height: SparkSize.icon5xl,
            decoration: BoxDecoration(
              color: kLightGreyColor,
              borderRadius: BorderRadius.circular(SparkRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.business_rounded,
              size: SparkSize.iconXl,
              color: kSecondaryColor,
            ),
          )
        else
          SparkInitialsAvatar(
            name: name,
            size: SparkSize.icon5xl,
            textSize: SparkTextSize.label,
            imageUrl: avatarUrl,
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
              const SizedBox(height: SparkSpace.xxs),
              MyText(
                text: inn.isEmpty
                    ? 'Вы состоите в штате компании'
                    : 'ИНН $inn',
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            ],
          ),
        ),
        if (verified) ...[
          const SizedBox(width: SparkSpace.sm),
          const SparkChip(
            text: 'Проверена',
            icon: Icons.verified_rounded,
            background: Color(0x1A1FA463),
            color: kGreenColor,
          ),
        ],
        const SizedBox(width: SparkSpace.sm),
        const Icon(
          Icons.chevron_right_rounded,
          size: SparkSize.iconLg,
          color: kGreyColor,
        ),
      ],
    );
  }

  // «Компания» — verified state (владелец).
  //
  // Компактная карточка «как в макете»: плитка-иконка + название +
  // «ИНН …» + chevron. Все действия (переименовать / сбросить статус)
  // переехали в bottom-sheet, который открывает тап по карточке —
  // прежние inline-rows с overflow-меню «⋯» дробили карточку на
  // несколько зон и выглядели противоречиво со status-pill.
  Widget _buildCompanyCardVerified() {
    final companyName = _companyNameController.text.trim();
    final displayName = companyName.isEmpty
        ? _businessTypeLabel()
        : companyName;
    final inn = (_verifiedInn ?? '').trim();
    final verified = _isVerifyCompany == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: SparkSize.icon5xl,
          height: SparkSize.icon5xl,
          decoration: BoxDecoration(
            color: kLightGreyColor,
            borderRadius: BorderRadius.circular(SparkRadius.md),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.business_rounded,
            size: SparkSize.iconXl,
            color: kSecondaryColor,
          ),
        ),
        const SizedBox(width: SparkSpace.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: _isVerifyingCompanyName ? '...' : displayName,
                size: SparkTextSize.title,
                weight: FontWeight.w800,
                lineHeight: 1.25,
              ),
              const SizedBox(height: SparkSpace.xxs),
              MyText(
                text: inn.isEmpty ? 'ИНН не указан' : 'ИНН $inn',
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            ],
          ),
        ),
        // «Проверена» — только при подтверждении. На модерации (false)
        // или до первой синхронизации (null) чип не показываем, чтобы
        // не создавать тревожный «pending»-сигнал (прежняя политика
        // status-pill сохранена).
        if (verified) ...[
          const SizedBox(width: SparkSpace.sm),
          const SparkChip(
            text: 'Проверена',
            icon: Icons.verified_rounded,
            background: Color(0x1A1FA463),
            color: kGreenColor,
          ),
        ],
        const SizedBox(width: SparkSpace.sm),
        const Icon(
          Icons.chevron_right_rounded,
          size: SparkSize.iconLg,
          color: kGreyColor,
        ),
      ],
    );
  }

  /// Sheet действий со своей компанией: переименование и сброс статуса.
  /// ИНН показан в подзаголовке с объяснением, что меняется только
  /// сбросом — прежний отдельный info-sheet по тапу на ИНН стал лишним.
  Future<void> _openOwnCompanySheet() async {
    final companyName = _companyNameController.text.trim();
    final displayName = companyName.isEmpty
        ? _businessTypeLabel()
        : companyName;
    final inn = (_verifiedInn ?? '').trim();
    final action = await showAppAdaptiveBottomSheet<String>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xl,
              SparkSpace.xl,
              SparkSpace.xl,
              SparkSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                    vertical: SparkSpace.sm,
                  ),
                  child: MyText(
                    text: displayName,
                    size: SparkTextSize.modalTitle,
                    weight: FontWeight.w800,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SparkSpace.md,
                    0,
                    SparkSpace.md,
                    SparkSpace.lg,
                  ),
                  child: MyText(
                    text: inn.isEmpty
                        ? 'ИНН не указан.'
                        : 'ИНН $inn. Изменить ИНН можно только сбросом '
                              'статуса компании и повторной регистрацией.',
                    size: SparkTextSize.body,
                    color: kGreyColor,
                    lineHeight: 1.35,
                  ),
                ),
                _SheetActionRow(
                  icon: Icons.edit_outlined,
                  label: 'Изменить название',
                  onTap: () => Navigator.of(ctx).pop('rename'),
                ),
                _SheetActionRow(
                  icon: Icons.restart_alt_rounded,
                  label: 'Сбросить статус компании',
                  color: kRedColor,
                  onTap: () => Navigator.of(ctx).pop('reset'),
                ),
                const SizedBox(height: SparkSpace.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                  ),
                  child: SizedBox(
                    height: SparkSize.actionHeight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SparkRadius.lg),
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    if (action == 'rename') {
      await _promptEditCompanyName();
    } else if (action == 'reset') {
      await _resetBusinessStatus();
    }
  }

  // «Проверка компании» — unverified state.
  //
  // Focused mini-form: prompt → labelled input → single primary button.
  // ИНН-поле визуально читается как часть общего input-стиля
  // (sparkInputDecoration), а не как standalone oddity.
  Widget _buildBusinessUnverified() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MyText(
          text:
              'Укажите название компании и ИНН — данные уйдут в тех. проверку, после модерации откроются функции компании или ИП.',
          size: SparkTextSize.body,
          color: kGreyColor,
        ),
        const SizedBox(height: SparkSpace.lg),
        // Название компании. Сервер сохраняет companyName + companyInn
        // только атомарно (per UpdateProfile docs), так что пара полей
        // живёт здесь рядом. `_verifyInn` валидирует non-empty перед
        // отправкой UpdateProfile. maxLength=255 — типичный лимит
        // полей такого рода на бэке; защищает от случайной 10k-вставки.
        TextField(
          controller: _companyNameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          maxLength: 255,
          inputFormatters: [LengthLimitingTextInputFormatter(255)],
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: sparkInputDecoration(
            'Название — ООО «Авто-Подбор»',
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: SparkSpace.md),
        // Dropped the separate "ИНН" label — the input hint
        // ("10 или 12 цифр") + section title "Проверка компании"
        // already tell the user what this field is. One less layer of
        // grey text to parse.
        TextField(
          controller: _innController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          // iOS heuristically offers «Scan Credit Card» / «Scan Text»
          // on numeric fields, popping the camera when the user taps
          // the QuickType suggestion. An explicit empty autofillHints
          // + disabled suggestions/autocorrect tells iOS we manage
          // this field ourselves and kills the scan affordance.
          autofillHints: const <String>[],
          enableSuggestions: false,
          autocorrect: false,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onChanged: (_) {
            if (_innError != null) {
              setState(() => _innError = null);
            }
          },
          decoration: sparkInputDecoration(
            'ИНН — 10 или 12 цифр',
            errorText: _innError,
          ),
        ),
        const SizedBox(height: SparkSpace.lg),
        // Promoted to full-width gradient primary (SparkPrimaryActionButton)
        // so this CTA reads clearly as THE action of the card. The
        // previous OutlinedButton got lost next to the input. There's
        // no competing primary on this screen right now — Save lives
        // inside the Information edit-mode card only when editing.
        SparkPrimaryActionButton(
          label: _isVerifying ? 'Проверяем...' : 'Проверить ИНН',
          icon: Icons.verified_outlined,
          onTap: () {
            if (_isVerifying) return;
            _verifyInn();
          },
          busy: _isVerifying,
        ),
      ],
    );
  }

  /// Карточка «Контакты»: Телефон / Email / Услуги. Город переехал в
  /// бейдж hero-шапки, «Описание услуг» стало рядом «Услуги» с чипами.
  Widget _buildContactsCard(Map<String, dynamic> specialist) {
    final phone = _phoneController.text.trim().isNotEmpty
        ? _phoneController.text.trim()
        : sjRead(specialist, 'phone').trim();
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : sjRead(specialist, 'email').trim();

    Widget? emailTrailing;
    if (_pendingEmailVerify != null &&
        _pendingEmailVerify!.toLowerCase() == email.toLowerCase()) {
      emailTrailing = const SparkChip(
        text: 'Не подтверждён',
        background: Color(0x33FFA500),
        color: Color(0xFFB36B00),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SparkProfileRow(
          icon: Icons.phone_outlined,
          label: 'Телефон',
          value: phone.isEmpty ? 'Не указан' : phone,
          valueIsPlaceholder: phone.isEmpty,
          // Телефон = auth identity, не редактируется. Тап открывает
          // info-sheet с объяснением вместо dead-end'а.
          onTap: phone.isEmpty ? null : _showPhoneReadonlySheet,
        ),
        _rowDivider(),
        SparkProfileRow(
          icon: Icons.mail_outline_rounded,
          label: 'Email',
          value: email.isEmpty ? 'Не указан' : email,
          valueIsPlaceholder: email.isEmpty,
          trailing: emailTrailing,
          onTap: _isSavingProfile
              ? null
              : () {
                  // Если есть pending verify (юзер уже сменил email,
                  // server принял, ждём OTP) — тап на row открывает
                  // OTP-диалог напрямую, чтобы не путать редактором.
                  if (_pendingEmailVerify != null &&
                      _pendingEmailVerify!.toLowerCase() ==
                          email.toLowerCase()) {
                    unawaited(_promptEmailVerificationCode());
                  } else {
                    unawaited(_editEmailSheet());
                  }
                },
        ),
        _rowDivider(),
        _buildServicesRow(specialist),
      ],
    );
  }

  /// Разбирает free-text «описание услуг» на короткие теги: каждая
  /// непустая строка минус ведущий буллет. Формат «• Подбор под ключ»
  /// пишет chip-редактор описания, так что для типовых профилей это
  /// точный обратный парсинг.
  List<String> _parseServiceTags(String description) {
    return description
        .split('\n')
        .map(
          (line) => line.replaceFirst(RegExp(r'^\s*[•\-–—]+\s*'), '').trim(),
        )
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  /// Ряд «Услуги»: короткие пункты рендерим чипами (как в макете),
  /// длинный free-text — 3-строчным превью. Тап всегда открывает
  /// полноценный редактор описания.
  Widget _buildServicesRow(Map<String, dynamic> specialist) {
    final description = _specializationController.text.trim().isNotEmpty
        ? _specializationController.text.trim()
        : sjRead(specialist, 'specialization').trim();
    final tags = _parseServiceTags(description);
    final asChips =
        tags.isNotEmpty && tags.length <= 8 && tags.every((t) => t.length <= 36);

    final Widget valueWidget;
    if (description.isEmpty) {
      valueWidget = const MyText(
        text: 'Не указаны',
        size: SparkTextSize.bodyLg,
        color: kGreyColor,
        lineHeight: 1.30,
      );
    } else if (asChips) {
      valueWidget = Wrap(
        spacing: SparkSpace.sm,
        runSpacing: SparkSpace.sm,
        children: [for (final tag in tags) _serviceChip(tag)],
      );
    } else {
      valueWidget = MyText(
        text: description,
        size: SparkTextSize.bodyLg,
        weight: FontWeight.w600,
        lineHeight: 1.30,
        maxLines: 3,
        textOverflow: TextOverflow.ellipsis,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSavingProfile ? null : _editDescriptionSheet,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xs,
            vertical: SparkSpace.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.list_alt_rounded,
                size: SparkSize.iconLg,
                color: description.isEmpty ? kGreyColor : kSecondaryColor,
              ),
              const SizedBox(width: SparkSpace.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MyText(
                      text: 'Услуги',
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                    const SizedBox(height: SparkSpace.xs),
                    valueWidget,
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.xs),
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

  Widget _serviceChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.lg,
        vertical: SparkSpace.sm,
      ),
      decoration: BoxDecoration(
        color: kGreyColor2,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
      ),
      child: MyText(
        text: text,
        size: SparkTextSize.body,
        weight: FontWeight.w600,
        color: kTertiaryColor,
      ),
    );
  }

  /// Info-sheet для телефона: поле read-only (это идентификатор входа),
  /// объясняем почему и куда идти за сменой номера.
  Future<void> _showPhoneReadonlySheet() async {
    await showAppAdaptiveBottomSheet<void>(
      context: context,
      extent: AppBottomSheetExtent.content,
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
                  children: const [
                    Icon(
                      Icons.phone_outlined,
                      size: SparkSize.iconLg,
                      color: kSecondaryColor,
                    ),
                    SizedBox(width: SparkSpace.md),
                    MyText(
                      text: 'Телефон изменить нельзя',
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w800,
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.lg),
                const MyText(
                  text:
                      'Номер телефона используется для входа в аккаунт '
                      'и привязан к нему. Если нужно перенести аккаунт '
                      'на другой номер — напишите нам через «Обратная '
                      'связь» в настройках.',
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

  // ─── Field-editor bottom sheets ─────────────────────────────────────
  //
  // Раньше «Информация» переключалась в edit-mode целиком — пользователь
  // не понимал, какое именно поле он правит. Теперь tap на row →
  // focused-sheet с одним полем (или связанной группой полей для ФИО) +
  // Сохранить/Отмена. Sheets держат локальные TextEditingController —
  // фоновые fetch'и не перезатирают введённое; на Save переносим в
  // screen-level controllers и зовём _saveProfile (диф-payload).

  /// Action-sheet выбора аватара. Опции: Камера / Галерея / Удалить.
  /// Picked-image → base64 → S3. Side-effects (snackbar / setState)
  /// живут здесь, а sheet — чисто UI слой.
  Future<void> _openAvatarPickerSheet() async {
    final hasAvatar =
        (_urlAvatar ?? '').isNotEmpty || (_avatarBase64 ?? '').isNotEmpty;
    final action = await showAppAdaptiveBottomSheet<String>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xl,
              SparkSpace.xl,
              SparkSpace.xl,
              SparkSpace.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(ctx).height * 0.36,
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: SparkSpace.md,
                      vertical: SparkSpace.sm,
                    ),
                    child: MyText(
                      text: 'Фото профиля',
                      size: SparkTextSize.modalTitle,
                      weight: FontWeight.w800,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SparkSpace.md,
                      0,
                      SparkSpace.md,
                      SparkSpace.lg,
                    ),
                    child: MyText(
                      text: hasAvatar
                          ? 'Посмотрите текущее фото или замените его.'
                          : 'Добавьте фото с камеры или из галереи.',
                      size: SparkTextSize.bodyLg,
                      color: kGreyColor,
                      lineHeight: 1.25,
                    ),
                  ),
                  if (hasAvatar) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop('preview'),
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: SparkSpace.md,
                            vertical: SparkSpace.sm,
                          ),
                          padding: const EdgeInsets.all(SparkSpace.md),
                          decoration: BoxDecoration(
                            color: kInputBgColor,
                            borderRadius: BorderRadius.circular(SparkRadius.lg),
                            border: Border.all(color: kBorderColor),
                          ),
                          child: Row(
                            children: [
                              SparkInitialsAvatar(
                                name: _composeFullName().isEmpty
                                    ? 'Специалист'
                                    : _composeFullName(),
                                size: 72,
                                textSize: SparkTextSize.titleLg,
                                imageUrl: _urlAvatar,
                                imageBase64: _avatarBase64,
                              ),
                              const SizedBox(width: SparkSpace.lg),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MyText(
                                      text: 'Посмотреть фото',
                                      size: SparkTextSize.bodyLg,
                                      weight: FontWeight.w800,
                                    ),
                                    SizedBox(height: SparkSpace.xxxs),
                                    MyText(
                                      text: 'Открыть на весь экран',
                                      size: SparkTextSize.caption,
                                      color: kGreyColor,
                                    ),
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
                    ),
                    const SizedBox(height: SparkSpace.sm),
                  ],
                  _SheetActionRow(
                    icon: Icons.photo_camera_outlined,
                    label: hasAvatar ? 'Сделать новое фото' : 'Сделать фото',
                    onTap: () => Navigator.of(ctx).pop('camera'),
                  ),
                  _sheetRowDivider(),
                  _SheetActionRow(
                    icon: Icons.photo_library_outlined,
                    label: 'Выбрать из галереи',
                    onTap: () => Navigator.of(ctx).pop('gallery'),
                  ),
                  if (hasAvatar) ...[
                    _sheetRowDivider(),
                    _SheetActionRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Удалить фото',
                      color: kRedColor,
                      onTap: () => Navigator.of(ctx).pop('delete'),
                    ),
                  ],
                  const SizedBox(height: SparkSpace.xxl),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.md,
                    ),
                    child: SizedBox(
                      height: SparkSize.actionHeight,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SparkRadius.lg),
                          ),
                        ),
                        child: const Text('Отмена'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    if (action == 'delete') {
      await _deleteAvatar();
      return;
    }
    if (action == 'preview') {
      await _openAvatarPreview();
      return;
    }
    final source = action == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      // Берём оригинал в высоком разрешении — кроп уменьшит до 800.
      final xfile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 86,
        requestFullMetadata: false,
      );
      if (xfile == null || !mounted) return;
      // Camera capture returns from a native route and immediately opening
      // a native cropper is unstable on some iOS devices and Android builds:
      // the app can be killed or the cropper plugin can submit a cancelled
      // result twice. For fresh camera shots we prepare a centered square in
      // Dart instead of chaining native controllers. Gallery keeps manual crop.
      final useSafeCameraPipeline =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android) &&
          source == ImageSource.camera;
      final bytes = useSafeCameraPipeline
          ? await _prepareAvatarBytesWithoutNativeCrop(xfile)
          : await _cropAvatarSquare(xfile.path);
      if (bytes == null || !mounted) return;
      if (bytes.length > 25 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Слишком большое фото (максимум 25 МБ).'),
            backgroundColor: kRedColor,
          ),
        );
        return;
      }
      // Оптимистичный preview: показываем base64 пока идёт upload.
      final encoded = base64Encode(bytes);
      await UserSimplePreferences.setAvatarBase64(encoded);
      if (!mounted) return;
      setState(() {
        _avatarBase64 = encoded;
        _avatarPresetIndex = null;
        _isUploadingAvatar = true;
      });
      // Кроп всегда отдаёт JPEG — имя фиксируем под расширение.
      await _uploadAvatarToS3('avatar.jpg', bytes);
    } on PlatformException catch (e) {
      if (!mounted) return;
      // Коды отказа различаются по платформам: iOS шлёт
      // camera_access_denied / photo_access_denied, Android — варианты
      // с PERMISSION/denied, поэтому матчим по подстроке.
      final code = e.code.toLowerCase();
      final reason = code.contains('denied') || code.contains('permission')
          ? 'Нет доступа. Разрешите в Настройках устройства.'
          : 'Не удалось загрузить фото: ${e.code}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось загрузить фото: $e')));
    }
  }

  Future<Uint8List?> _prepareAvatarBytesWithoutNativeCrop(XFile xfile) async {
    final raw = await xfile.readAsBytes();
    if (raw.isEmpty) return null;
    return compute(_normalizeAvatarJpegBytes, Uint8List.fromList(raw));
  }

  bool _hasProfilePhoto() =>
      (_urlAvatar ?? '').isNotEmpty || (_avatarBase64 ?? '').isNotEmpty;

  Uint8List? _avatarPreviewBytes() {
    final raw = _avatarBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openAvatarPreview() async {
    if (!_hasProfilePhoto()) {
      await _openAvatarPickerSheet();
      return;
    }
    final avatarUrl = (_urlAvatar ?? '').trim();
    final avatarBytes = _avatarPreviewBytes();
    if (avatarUrl.isEmpty && avatarBytes == null) {
      await _openAvatarPickerSheet();
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) {
          final image = avatarUrl.isNotEmpty
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person_rounded,
                    size: 96,
                    color: kWhiteColor,
                  ),
                )
              : Image.memory(
                  avatarBytes!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                );
          return Scaffold(
            backgroundColor: kBlackColor,
            appBar: AppBar(
              backgroundColor: kBlackColor,
              foregroundColor: kWhiteColor,
              elevation: 0,
              title: const Text('Фото профиля'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) unawaited(_openAvatarPickerSheet());
                    });
                  },
                  child: const Text(
                    'Изменить',
                    style: TextStyle(
                      color: kWhiteColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: image,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Открывает круглый кроппер (как в Telegram: фиксированная круглая
  /// рамка, фото двигаешь/зумишь под ней). Возвращает JPEG-байты или null
  /// если отменили. Native — uCrop/TOCropViewController с CropStyle.circle;
  /// web — cropper.js (круг через CSS в web/index.html, drag-move).
  Future<Uint8List?> _cropAvatarSquare(String sourcePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 800,
      maxHeight: 800,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 420, height: 420),
          // Telegram-стиль: тянешь фото, рамка зафиксирована по центру.
          dragMode: WebDragMode.move,
          cropBoxMovable: false,
          cropBoxResizable: false,
          toggleDragModeOnDblclick: false,
          guides: false,
          highlight: false,
          center: false,
          movable: true,
          zoomable: true,
          translations: const WebTranslations(
            title: 'Фото профиля',
            rotateLeftTooltip: 'Повернуть влево',
            rotateRightTooltip: 'Повернуть вправо',
            cancelButton: 'Отмена',
            cropButton: 'Готово',
          ),
        ),
        IOSUiSettings(
          title: 'Фото профиля',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          rotateButtonsHidden: true,
          cropStyle: CropStyle.circle,
          doneButtonTitle: 'Готово',
          cancelButtonTitle: 'Отмена',
        ),
        AndroidUiSettings(
          toolbarTitle: 'Фото профиля',
          lockAspectRatio: true,
          hideBottomControls: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null) return null;
    return cropped.readAsBytes();
  }

  Future<void> _uploadAvatarToS3(
    String originalFilename,
    List<int> bytes,
  ) async {
    final String publicUrl;
    // Фаза 1 — загрузка байтов в S3 (initiate/PUT/complete).
    try {
      publicUrl = await storage_api.StorageApi.uploadProfileAvatar(
        bytes: bytes,
        originalFilename: originalFilename,
      );
    } on storage_api.ProfileAvatarUploadException catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: kRedColor),
      );
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('[avatar] S3 upload failed: $e');
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось загрузить фото. Попробуйте ещё раз.'),
          backgroundColor: kRedColor,
        ),
      );
      return;
    }
    // Cache-busting: ключ в S3 всегда `avatar.png`, поэтому publicUrl не
    // меняется между загрузками и браузер/Image-кэш отдаёт старое фото.
    // Добавляем версионный ?v={ts} — каждая загрузка = уникальный URL,
    // кэш сбрасывается везде (немедленно + при перезагрузке + на других
    // устройствах, т.к. бэкенд хранит и отдаёт URL с параметром as-is).
    final sep = publicUrl.contains('?') ? '&' : '?';
    final versionedUrl =
        '$publicUrl${sep}v=${DateTime.now().millisecondsSinceEpoch}';
    // Фаза 2 — привязка versionedUrl к профилю. Файл уже в S3; если
    // UpdateProfile упал — оставляем base64-превью локально (юзер видит
    // своё фото), профиль допривяжется при следующем сохранении.
    try {
      await storage_api.StorageApi.updateProfile(
        profile: {'urlAvatar': versionedUrl},
      );
      if (!mounted) return;
      await UserSimplePreferences.clearAvatar();
      if (!mounted) return;
      setState(() {
        _urlAvatar = versionedUrl;
        _avatarBase64 = null;
        _isUploadingAvatar = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[avatar] UpdateProfile(urlAvatar) failed: $e');
      }
      if (!mounted) return;
      // Спиннер гасим, base64-превью оставляем как fallback.
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Фото загружено, но не сохранилось в профиль.'),
          backgroundColor: kRedColor,
        ),
      );
    }
  }

  Future<void> _deleteAvatar() async {
    // Инвалидируем in-flight _fetchServerProfile — иначе запрос, улетевший
    // до удаления, вернёт старый urlAvatar и восстановит аватарку на экране.
    ++_fetchGeneration;
    try {
      await storage_api.StorageApi.deleteProfileAvatar();
    } catch (_) {
      // Продолжаем даже при ошибке — UI чистим локально.
    }
    await UserSimplePreferences.clearAvatar();
    if (!mounted) return;
    setState(() {
      _urlAvatar = null;
      _avatarBase64 = null;
      _avatarPresetIndex = null;
    });
  }

  Future<void> _editFullNameSheet() async {
    final lastCtrl = TextEditingController(text: _lastNameController.text);
    final firstCtrl = TextEditingController(text: _firstNameController.text);
    final middleCtrl = TextEditingController(text: _middleNameController.text);
    Map<String, String>? lastErrors;

    final saved = await showAppAdaptiveBottomSheet<Map<String, String>>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              final last = lastCtrl.text.trim();
              final first = firstCtrl.text.trim();
              final middle = middleCtrl.text.trim();
              final errors = <String, String>{};
              if (last.isEmpty) errors['last'] = 'Введите фамилию';
              if (first.isEmpty) errors['first'] = 'Введите имя';
              if (errors.isNotEmpty) {
                setLocal(() => lastErrors = errors);
                return;
              }
              Navigator.of(
                sheetCtx,
              ).pop({'last': last, 'first': first, 'middle': middle});
            }

            return _SheetScaffold(
              title: 'ФИО',
              onCancel: () => Navigator.of(sheetCtx).pop(),
              onSubmit: submit,
              children: [
                _SheetTextField(
                  controller: lastCtrl,
                  label: 'Фамилия',
                  hint: 'Иванов',
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  errorText: lastErrors?['last'],
                  onChanged: (_) {
                    if (lastErrors != null) {
                      setLocal(() => lastErrors = null);
                    }
                  },
                ),
                _SheetTextField(
                  controller: firstCtrl,
                  label: 'Имя',
                  hint: 'Иван',
                  textCapitalization: TextCapitalization.words,
                  errorText: lastErrors?['first'],
                  onChanged: (_) {
                    if (lastErrors != null) {
                      setLocal(() => lastErrors = null);
                    }
                  },
                ),
                _SheetTextField(
                  controller: middleCtrl,
                  label: 'Отчество',
                  hint: 'Иванович',
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => submit(),
                ),
              ],
            );
          },
        );
      },
    );
    _disposeTextControllersAfterRouteClose(lastCtrl, firstCtrl, middleCtrl);
    if (saved == null || !mounted) return;

    final last = saved['last']!;
    final first = saved['first']!;
    final middle = saved['middle']!;
    final unchanged =
        last == _lastNameController.text.trim() &&
        first == _firstNameController.text.trim() &&
        middle == _middleNameController.text.trim();
    if (unchanged) return;
    _lastNameController.text = last;
    _firstNameController.text = first;
    _middleNameController.text = middle;
    await _saveProfile();
  }

  Future<void> _editCitySheet() async {
    final picked = await showCityPickerBottomSheet(
      context,
      currentValue: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
    );
    if (picked == null || !mounted) return;
    final city = picked.shortLabel.trim();
    if (city == _cityController.text.trim()) return;
    _cityController.text = city;
    await _saveProfile();
  }

  Future<void> _editEmailSheet() async {
    final saved = await _showSingleFieldSheet(
      title: 'Email',
      label: 'Email',
      hint: 'name@example.com',
      initial: _emailController.text,
      keyboardType: TextInputType.emailAddress,
      textCapitalization: TextCapitalization.none,
      validate: _emailValidator,
    );
    if (saved == null) return;
    if (saved.trim().toLowerCase() ==
        _emailController.text.trim().toLowerCase()) {
      return;
    }
    _emailController.text = saved.trim();
    await _saveProfile();
  }

  /// Лист «Услуги» (макет 2а): построчный редактор пунктов — каждая
  /// строка отдельный пункт с крестиком удаления, тогл-чипы «Быстрое
  /// добавление» (✓ = уже в списке, повторный тап убирает). Хранится
  /// по-прежнему одной строкой описания «• пункт\n• пункт» — формат
  /// полностью совместим со старыми профилями и парсером чипов.
  Future<void> _editDescriptionSheet() async {
    final saved = await showAppAdaptiveBottomSheet<String>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (sheetCtx) => _ServicesEditorSheet(
        initialItems: _parseServiceTags(_specializationController.text.trim()),
        presets: _presetSpecializations,
      ),
    );
    if (saved == null || !mounted) return;
    if (saved.trim() == _specializationController.text.trim()) return;
    _specializationController.text = saved;
    await _saveProfile();
  }

  Future<String?> _showSingleFieldSheet({
    required String title,
    required String label,
    required String initial,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    String? Function(String value)? validate,
  }) async {
    final ctrl = TextEditingController(text: initial);
    String? error;
    final result = await showAppAdaptiveBottomSheet<String>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              final value = ctrl.text;
              final err = validate?.call(value);
              if (err != null) {
                setLocal(() => error = err);
                return;
              }
              Navigator.of(sheetCtx).pop(value);
            }

            return _SheetScaffold(
              title: title,
              onCancel: () => Navigator.of(sheetCtx).pop(),
              onSubmit: submit,
              children: [
                _SheetTextField(
                  controller: ctrl,
                  label: label,
                  hint: hint,
                  autofocus: true,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  errorText: error,
                  onChanged: (_) {
                    if (error != null) setLocal(() => error = null);
                  },
                  onSubmitted: (_) => submit(),
                ),
              ],
            );
          },
        );
      },
    );
    _disposeTextControllersAfterRouteClose(ctrl);
    return result;
  }

  void _disposeTextControllersAfterRouteClose(
    TextEditingController first, [
    TextEditingController? second,
    TextEditingController? third,
  ]) {
    final controllers = <TextEditingController>[
      first,
      if (second != null) second,
      if (third != null) third,
    ];
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  void _openLinkedCompanyProfile() {
    final companyId = _linkedCompanyId;
    final profile = _linkedCompanyProfile;
    if ((companyId == null || companyId <= 0) && profile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SparkJoyCompanyPublicProfileScreen(
          companyId: companyId,
          initialProfile: profile,
        ),
      ),
    );
  }

  /// Подпись роли в бейдже hero-шапки. Владелец — подтверждённая своя
  /// компания/ИП; сотрудник — специалист, привязанный к чужой компании;
  /// иначе — независимый специалист.
  String _heroRoleLabel() {
    if ((_verifiedInn ?? '').isNotEmpty) return 'Владелец';
    if (_linkedCompanyId != null || _linkedCompanyProfile != null) {
      return 'Сотрудник';
    }
    return 'Специалист';
  }

  /// Тёмная hero-«шапка» профиля (макет 1a): аватар с камера-бейджем,
  /// имя+фамилия крупно, отчество отдельной строкой, пилюля
  /// «роль · город». Зоны тапа независимые: аватар → управление фото,
  /// имя/карандаш → редактор ФИО, пилюля → выбор города.
  Widget _buildHeroCard(Map<String, dynamic> specialist, String profileName) {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final middle = _middleNameController.text.trim();
    final mainLine = [first, last].where((p) => p.isNotEmpty).join(' ');
    // «Имя Фамилия» — как в макете; отчество вынесено вниз. Fallback —
    // полное составное имя (или «Специалист») из build().
    final displayName = mainLine.isNotEmpty ? mainLine : profileName;
    final city = _cityController.text.trim();
    final roleLabel = _heroRoleLabel();
    final badgeText = city.isEmpty ? roleLabel : '$roleLabel · $city';
    final blocked = sjRead(specialist, 'status') != 'active';
    final busy = _isSavingProfile || _isUploadingAvatar;

    return Container(
      padding: const EdgeInsets.all(SparkSpace.section),
      decoration: BoxDecoration(
        color: kSecondaryColor,
        borderRadius: BorderRadius.circular(SparkRadius.sheet),
        boxShadow: const [
          BoxShadow(
            color: kShadowColor,
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : _openAvatarPickerSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(SparkSpace.xxs),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kWhiteColor.withValues(alpha: 0.28),
                      width: 2,
                    ),
                  ),
                  child: SparkInitialsAvatar(
                    name: displayName,
                    size: 72,
                    textSize: SparkTextSize.pageTitle,
                    backgroundColor: kWhiteColor.withValues(alpha: 0.14),
                    textColor: kWhiteColor,
                    imageUrl: _urlAvatar,
                    imageBase64: _avatarBase64,
                    presetIndex: _avatarPresetIndex,
                  ),
                ),
                if (_isUploadingAvatar)
                  Positioned.fill(
                    child: ClipOval(
                      child: ColoredBox(
                        color: Colors.black45,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: kWhiteColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: -2,
                  bottom: -2,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: kWhiteColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: kSecondaryColor.withValues(alpha: 0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      size: 14,
                      color: kSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.xxl),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isSavingProfile ? null : _editFullNameSheet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: displayName,
                    size: SparkTextSize.pageTitle,
                    weight: FontWeight.w800,
                    color: kWhiteColor,
                    lineHeight: 1.20,
                  ),
                  if (middle.isNotEmpty)
                    MyText(
                      text: middle,
                      size: SparkTextSize.label,
                      color: kWhiteColor.withValues(alpha: 0.66),
                      paddingTop: SparkSpace.xxs,
                    ),
                  const SizedBox(height: SparkSpace.lg),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSavingProfile ? null : _editCitySheet,
                      borderRadius: BorderRadius.circular(SparkRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SparkSpace.lg,
                          vertical: SparkSpace.sm,
                        ),
                        decoration: BoxDecoration(
                          color: kWhiteColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            SparkRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: SparkSize.iconXs,
                              color: kWhiteColor,
                            ),
                            const SizedBox(width: SparkSpace.xs),
                            Flexible(
                              child: MyText(
                                text: badgeText,
                                size: SparkTextSize.caption,
                                weight: FontWeight.w700,
                                color: kWhiteColor,
                                maxLines: 1,
                                textOverflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (blocked)
                    Padding(
                      padding: const EdgeInsets.only(top: SparkSpace.sm),
                      child: SparkChip(
                        text: 'Неактивен',
                        background: kRedColor.withValues(alpha: 0.85),
                        color: kWhiteColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSavingProfile ? null : _editFullNameSheet,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(SparkSpace.sm),
                child: Icon(
                  Icons.edit_outlined,
                  size: SparkSize.iconLg,
                  color: kWhiteColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final specialist = _specialist();
    final composedName = _composeFullName();
    final profileName = composedName.isEmpty
        ? sjRead(specialist, 'name', fallback: 'Специалист')
        : composedName;
    final hasVerifiedBusiness = (_verifiedInn ?? '').isNotEmpty;
    final hasLinkedCompany =
        !hasVerifiedBusiness &&
        (_linkedCompanyId != null ||
            _linkedCompanyProfile != null ||
            _isLoadingLinkedCompany);

    return SparkScreenList(
      bottomInset: 56,
      onRefresh: () async {
        // Pull-to-refresh = принудительный pull с сервера. _loadProfile
        // здесь не годится: он показал бы cached snapshot мгновенно
        // (cache-as-seed), и unawaited(_fetchServerProfile) уехал бы
        // async — refresh-индикатор схлопнулся бы до прихода свежих
        // данных, а юзер увидел кэш. Дёргаем _fetchServerProfile
        // напрямую и await'им — индикатор уезжает только когда server
        // response применился. _fetchServerProfile сам бампит generation,
        // поэтому любой уже-летящий fetch invalidate'ится автоматически.
        await Future.wait([_fetchServerProfile(), _loadBusinessStatus()]);
        // Re-sync pendingEmailVerify из prefs — на случай если verify
        // прошёл через внешний канал (deep-link, push) пока юзер был
        // на этом экране. Сейчас такого канала нет, но defensive.
        if (!mounted) return;
        final pending = await UserSimplePreferences.getPendingEmailVerify();
        if (!mounted || pending == _pendingEmailVerify) return;
        setState(() => _pendingEmailVerify = pending);
      },
      children: [
        // Persistent banner «Email ждёт подтверждения» — рендерится
        // когда _pendingEmailVerify установлен и совпадает с текущим
        // значением в _emailController (case-insensitive). Реактивно
        // через ValueListenableBuilder — sheet-editor пишет в
        // _emailController на «Сохранить», и banner мгновенно
        // подстраивается без явного setState.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _emailController,
          builder: (context, value, _) {
            if (!_shouldShowEmailPendingBanner(value.text)) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.lg),
              child: _buildEmailPendingBanner(),
            );
          },
        ),
        // Тёмная hero-«шапка» владеет identity: аватар (тап → управление
        // фото), имя+карандаш (тап → редактор ФИО), бейдж «роль · город»
        // (тап → выбор города). Роль в бейдже заменяет чип из AppBar.
        _buildHeroCard(specialist, profileName),
        const SparkSectionTitle('Контакты', top: SparkSpace.section),
        SparkCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.md,
            vertical: SparkSpace.sm,
          ),
          child: _buildContactsCard(specialist),
        ),
        const SparkSectionTitle('Компания', top: SparkSpace.section),
        SparkCard(
          // Своя компания → sheet действий (переименовать / сбросить),
          // компания-работодатель → её публичный профиль.
          onTap: hasVerifiedBusiness
              ? _openOwnCompanySheet
              : (hasLinkedCompany ? _openLinkedCompanyProfile : null),
          child: hasVerifiedBusiness
              ? _buildCompanyCardVerified()
              : hasLinkedCompany
              ? _buildLinkedCompanyProfile()
              : _buildBusinessUnverified(),
        ),
        const SparkSectionTitle('Настройки', top: SparkSpace.section),
        SparkCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.md,
            vertical: SparkSpace.sm,
          ),
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.shield_outlined,
                title: 'Политика конфиденциальности',
                onTap: _openPrivacyPolicy,
              ),
              _rowDivider(),
              _SettingsRow(
                icon: Icons.fact_check_outlined,
                title: 'Согласие и условия',
                onTap: _openConsentAndTermsSheet,
              ),
              _rowDivider(),
              _SettingsRow(
                icon: Icons.chat_outlined,
                title: 'Обратная связь',
                onTap: _openFeedback,
              ),
            ],
          ),
        ),
        const SizedBox(height: SparkSpace.section),
        _buildAccountActions(),
      ],
    );
  }

  /// Нижний ряд аккаунт-действий: широкая «Выйти» + компактная красная
  /// корзина (удаление аккаунта). Обе за confirm-диалогами. Раньше это
  /// были две полноширинные красные карточки под заголовком «Аккаунт» —
  /// слишком много алармового красного в постоянной зоне экрана.
  Widget _buildAccountActions() {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SparkRadius.lg),
    );
    final deleteBusy = _isAccountDeletionRequesting;
    final Widget deleteButton = Material(
      color: kRedColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(SparkRadius.lg),
      child: InkWell(
        onTap: deleteBusy ? null : _confirmAccountDeactivation,
        borderRadius: BorderRadius.circular(SparkRadius.lg),
        child: Container(
          width: SparkSize.inputHeightLg,
          height: SparkSize.inputHeightLg,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SparkRadius.lg),
            border: Border.all(color: kRedColor.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: deleteBusy
              ? const SizedBox(
                  width: SparkSize.spinner,
                  height: SparkSize.spinner,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kRedColor,
                  ),
                )
              : const Icon(
                  Icons.delete_outline_rounded,
                  color: kRedColor,
                  size: SparkSize.iconXl,
                ),
        ),
      ),
    );

    if (widget.onLogout == null) {
      // Logout недоступен (screen встроен без callback'а) — удаление
      // остаётся единственным действием, растягиваем его на всю ширину.
      return SizedBox(
        height: SparkSize.inputHeightLg,
        child: OutlinedButton.icon(
          onPressed: deleteBusy ? null : _confirmAccountDeactivation,
          icon: const Icon(Icons.delete_outline_rounded,
              size: SparkSize.iconMd),
          label: Text(deleteBusy ? 'Удаляем аккаунт...' : 'Удалить аккаунт'),
          style: OutlinedButton.styleFrom(
            backgroundColor: kWhiteColor,
            foregroundColor: kRedColor,
            side: BorderSide(color: kRedColor.withValues(alpha: 0.35)),
            shape: buttonShape,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: SparkSize.inputHeightLg,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded, size: SparkSize.iconMd),
              label: const Text('Выйти'),
              style: OutlinedButton.styleFrom(
                backgroundColor: kWhiteColor,
                foregroundColor: kTertiaryColor,
                side: const BorderSide(color: kBorderColor),
                textStyle: const TextStyle(
                  fontSize: SparkTextSize.label,
                  fontWeight: FontWeight.w700,
                ),
                shape: buttonShape,
              ),
            ),
          ),
        ),
        const SizedBox(width: SparkSpace.lg),
        deleteButton,
      ],
    );
  }

  /// «Согласие и условия» объединяет два правовых документа в один
  /// пункт «Настроек» (как в макете) — sheet даёт выбрать конкретный.
  Future<void> _openConsentAndTermsSheet() async {
    final action = await showAppAdaptiveBottomSheet<String>(
      context: context,
      extent: AppBottomSheetExtent.content,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xl,
              SparkSpace.xl,
              SparkSpace.xl,
              SparkSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                    vertical: SparkSpace.sm,
                  ),
                  child: MyText(
                    text: 'Согласие и условия',
                    size: SparkTextSize.modalTitle,
                    weight: FontWeight.w800,
                  ),
                ),
                _SheetActionRow(
                  icon: Icons.fact_check_outlined,
                  label: 'Согласие на обработку персональных данных',
                  onTap: () => Navigator.of(ctx).pop('consent'),
                ),
                _SheetActionRow(
                  icon: Icons.description_outlined,
                  label: 'Условия использования',
                  onTap: () => Navigator.of(ctx).pop('terms'),
                ),
                const SizedBox(height: SparkSpace.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                  ),
                  child: SizedBox(
                    height: SparkSize.actionHeight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SparkRadius.lg),
                        ),
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    if (action == 'consent') {
      _openPersonalDataConsent();
    } else if (action == 'terms') {
      _openTerms();
    }
  }

  /// Confirm-диалог перед logout — раньше в AppBar был просто
  /// `IconButton(onPressed: _logout)` без confirmation. Случайный тап
  /// = выход + потеря всех несинхронизированных черновиков (drafts
  /// живут в storage, но re-login требует SMS-call-pass + ввод снова).
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Локальные черновики останутся на устройстве, но войти '
          'заново можно только через звонок на номер.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: kRedColor),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onLogout?.call();
    }
  }

  void _openFeedback() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SparkJoyFeedbackScreen()));
  }

  void _openPrivacyPolicy() {
    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicy(sparkHeader: true),
      ),
    );
  }

  void _openPersonalDataConsent() {
    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => const PersonalDataConsent(sparkHeader: true),
      ),
    );
  }

  void _openTerms() {
    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(builder: (_) => const Terms(sparkHeader: true)),
    );
  }

  Future<void> _confirmAccountDeactivation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Аккаунт будет отключён, а сохранённая сессия удалена с устройства. '
          'Повторный вход по телефону снова активирует аккаунт.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: kRedColor),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deactivateAccount();
    }
  }

  Future<void> _deactivateAccount() async {
    if (_isAccountDeletionRequesting) return;
    setState(() => _isAccountDeletionRequesting = true);
    try {
      await storage_api.StorageApi.deactivateAccount();
      if (!mounted) return;
      if (widget.onLogout != null) {
        await widget.onLogout!.call();
      } else {
        await SparkJoyStorage.logout();
        await UserSimplePreferences.clearAuthTokens();
      }
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      if (!mounted) return;
      showSparkJoyErrorSnackBar(
        context,
        e,
        fallback: 'Не удалось удалить аккаунт',
      );
    } finally {
      if (mounted) setState(() => _isAccountDeletionRequesting = false);
    }
  }
}

/// Тонкий разделитель между рядами внутри карточки-группы. Отступ слева
/// выравнивает линию под текст ряда (иконка 20 + gap 12 + h-padding 4).
Widget _rowDivider() {
  return Padding(
    padding: const EdgeInsets.only(
      left: SparkSize.iconLg + SparkSpace.xl + SparkSpace.xs,
    ),
    child: Container(
      height: SparkSpace.hairline,
      color: kBorderColor.withValues(alpha: 0.6),
    ),
  );
}

/// Ряд карточки «Настройки»: иконка + заголовок + chevron, единый ритм
/// со SparkProfileRow. Раньше каждый пункт был отдельной карточкой.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xs,
            vertical: SparkSpace.lg,
          ),
          child: Row(
            children: [
              Icon(icon, color: kSecondaryColor, size: SparkSize.iconLg),
              const SizedBox(width: SparkSpace.xl),
              Expanded(
                child: MyText(
                  text: title,
                  size: SparkTextSize.bodyLg,
                  weight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: kGreyColor,
                size: SparkSize.iconLg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Каркас bottom-sheet для редактирования профиля: заголовок (+
/// опциональный подзаголовок), scrollable-body (входит в keyboard-safe
/// padding), action-row «Отмена / Сохранить» в стиле макета — серая
/// filled-отмена и широкая тёмная «Сохранить». Используется всеми
/// _edit*-методами профиля.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.onCancel,
    required this.onSubmit,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SparkRadius.lg),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: SparkSpace.xxxl,
          right: SparkSpace.xxxl,
          bottom: SparkSpace.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: MyText(
                    text: title,
                    size: SparkTextSize.modalTitle,
                    weight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Отмена',
                ),
              ],
            ),
            if (subtitle != null)
              MyText(
                text: subtitle!,
                size: SparkTextSize.bodyLg,
                color: kGreyColor,
                lineHeight: 1.30,
                paddingBottom: SparkSpace.sm,
              ),
            const SizedBox(height: SparkSpace.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
            const SizedBox(height: SparkSpace.xl),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: SparkSize.inputHeight,
                    child: FilledButton(
                      onPressed: onCancel,
                      style: FilledButton.styleFrom(
                        backgroundColor: kGreyColor2,
                        foregroundColor: kTertiaryColor,
                        textStyle: const TextStyle(
                          fontSize: SparkTextSize.label,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: buttonShape,
                      ),
                      child: const Text('Отмена'),
                    ),
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: SparkSize.inputHeight,
                    child: FilledButton(
                      onPressed: onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: kSecondaryColor,
                        foregroundColor: kWhiteColor,
                        textStyle: const TextStyle(
                          fontSize: SparkTextSize.label,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: buttonShape,
                      ),
                      child: const Text('Сохранить'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Тело листа «Услуги»: список пунктов-строк в одной рамке (каждая
/// строка — свой TextField с «•» и крестиком) + тогл-чипы пресетов.
/// Возвращает через Navigator.pop сериализованное описание
/// («• пункт\n• пункт») или null при отмене. Владеет контроллерами
/// строк и корректно их освобождает.
class _ServicesEditorSheet extends StatefulWidget {
  const _ServicesEditorSheet({
    required this.initialItems,
    required this.presets,
  });

  final List<String> initialItems;
  final List<String> presets;

  @override
  State<_ServicesEditorSheet> createState() => _ServicesEditorSheetState();
}

class _ServicesEditorSheetState extends State<_ServicesEditorSheet> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    for (final item in widget.initialItems) {
      _createItem(_controllers.length, item);
    }
    if (_controllers.isEmpty) _createItem(0, '');
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _createItem(int index, String text) {
    _controllers.insert(index, TextEditingController(text: text));
    _nodes.insert(index, FocusNode());
  }

  void _removeAt(int index) {
    final controller = _controllers.removeAt(index);
    final node = _nodes.removeAt(index);
    // Виджет строки ещё в дереве до конца кадра — освобождаем после.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      node.dispose();
    });
    if (_controllers.isEmpty) _createItem(0, '');
    setState(() {});
  }

  /// Перенос строки внутри пункта = разделение на отдельные пункты.
  /// Так «каждая строка — отдельный пункт» работает и для ручного
  /// Enter, и для вставки многострочного текста из буфера.
  void _handleChanged(int index, String value) {
    if (value.contains('\n')) {
      final parts = value.split('\n');
      final first = parts.first;
      _controllers[index].value = TextEditingValue(
        text: first,
        selection: TextSelection.collapsed(offset: first.length),
      );
      var insertAt = index + 1;
      for (final part in parts.skip(1)) {
        _createItem(insertAt, part.trim());
        insertAt++;
      }
      final lastInserted = insertAt - 1;
      _nodes[lastInserted].requestFocus();
      final tail = _controllers[lastInserted];
      tail.selection = TextSelection.collapsed(offset: tail.text.length);
    }
    // Перерисовка нужна и без переноса: чипы/крестики зависят от текста.
    setState(() {});
  }

  int _indexOfText(String text) {
    final needle = text.trim().toLowerCase();
    return _controllers.indexWhere(
      (c) => c.text.trim().toLowerCase() == needle,
    );
  }

  void _togglePreset(String label) {
    HapticFeedback.selectionClick();
    final existing = _indexOfText(label);
    if (existing >= 0) {
      _removeAt(existing);
      return;
    }
    // Заполняем первую пустую строку, чтобы не плодить хвосты; иначе —
    // новый пункт в конец.
    final emptyIndex = _controllers.indexWhere((c) => c.text.trim().isEmpty);
    if (emptyIndex >= 0) {
      _controllers[emptyIndex].value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
    } else {
      _createItem(_controllers.length, label);
    }
    setState(() {});
  }

  void _submit() {
    final items = [
      for (final c in _controllers) c.text.trim(),
    ].where((t) => t.isNotEmpty).toList(growable: false);
    final text = [for (final t in items) '• $t'].join('\n');
    Navigator.of(context).pop(text);
  }

  Widget _buildItemRow(int index) {
    final hasText = _controllers[index].text.trim().isNotEmpty;
    return Row(
      key: ObjectKey(_controllers[index]),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: SparkSpace.lg),
          child: MyText(
            text: '•',
            size: SparkTextSize.label,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: SparkSpace.md),
        Expanded(
          child: TextField(
            controller: _controllers[index],
            focusNode: _nodes[index],
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Опишите услугу',
              contentPadding: EdgeInsets.symmetric(vertical: SparkSpace.lg),
            ),
            onChanged: (value) => _handleChanged(index, value),
          ),
        ),
        // Крестик — только у заполненных пунктов (как в макете: строка
        // с курсором без крестика).
        if (hasText)
          InkWell(
            onTap: () => _removeAt(index),
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(SparkSpace.md),
              child: Icon(
                Icons.close_rounded,
                size: SparkSize.iconMd,
                color: kGreyColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetChip(String label) {
    final selected = _indexOfText(label) >= 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _togglePreset(label),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xxl,
            vertical: SparkSpace.lg,
          ),
          decoration: BoxDecoration(
            color: selected ? kGreyColor2 : kWhiteColor,
            borderRadius: BorderRadius.circular(SparkRadius.pill),
            border: Border.all(
              color: selected ? Colors.transparent : kBorderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                size: SparkSize.iconSm,
                color: selected ? kGreenColor : kSecondaryColor,
              ),
              const SizedBox(width: SparkSpace.sm),
              MyText(
                text: label,
                size: SparkTextSize.bodyLg,
                weight: FontWeight.w600,
                color: selected ? kGreyColor : kTertiaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Услуги',
      subtitle: 'Опишите услуги своими словами или добавляйте готовые пункты.',
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xl,
            vertical: SparkSpace.sm,
          ),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(SparkRadius.lg),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _controllers.length; i++) _buildItemRow(i),
            ],
          ),
        ),
        const MyText(
          text: 'Каждая строка — отдельный пункт',
          size: SparkTextSize.caption,
          color: kGreyColor,
          textAlign: TextAlign.right,
          paddingTop: SparkSpace.sm,
        ),
        const SparkSectionTitle('Быстрое добавление', top: SparkSpace.xl),
        Wrap(
          spacing: SparkSpace.md,
          runSpacing: SparkSpace.md,
          children: [
            for (final preset in widget.presets) _buildPresetChip(preset),
          ],
        ),
      ],
    );
  }
}

Uint8List _normalizeAvatarJpegBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final oriented = img.bakeOrientation(decoded);
  final side = math.min(oriented.width, oriented.height);
  if (side <= 0) return bytes;

  final cropped = img.copyCrop(
    oriented,
    x: ((oriented.width - side) / 2).round(),
    y: ((oriented.height - side) / 2).round(),
    width: side,
    height: side,
  );
  final resized = side > 800
      ? img.copyResize(
          cropped,
          width: 800,
          height: 800,
          interpolation: img.Interpolation.cubic,
        )
      : cropped;

  return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
}

/// Лейбл сверху + TextField снизу — единый стиль для всех полей
/// внутри sheet'ов. Парный к `_SheetScaffold`.
class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(
            text: label,
            size: SparkTextSize.body,
            color: kGreyColor,
            paddingBottom: SparkSpace.sm,
          ),
          TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            textInputAction: onSubmitted != null
                ? TextInputAction.done
                : TextInputAction.next,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: sparkInputDecoration(
              hint ?? label,
            ).copyWith(errorText: errorText),
          ),
        ],
      ),
    );
  }
}

/// Тонкий разделитель между action-рядами bottom-sheet'ов (фото профиля,
/// компания, согласие и условия). Отступ слева выравнивает линию под
/// текст ряда `_SheetActionRow` (h-padding 8 + иконка 20 + gap 10).
Widget _sheetRowDivider() {
  return Padding(
    padding: const EdgeInsets.only(
      left: SparkSpace.md + SparkSize.iconLg + SparkSpace.lg,
      right: SparkSpace.md,
    ),
    child: Container(
      height: SparkSpace.hairline,
      color: kBorderColor.withValues(alpha: 0.7),
    ),
  );
}

/// Row-кнопка в bottom-sheet'ах профиля. Иконка + лейбл, цвет
/// переключается на `kRedColor` для destructive-действий.
class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? kSecondaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.md,
            vertical: SparkSpace.lg,
          ),
          child: Row(
            children: [
              Icon(icon, color: tint, size: SparkSize.iconLg),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: MyText(
                  text: label,
                  size: SparkTextSize.bodyLg,
                  weight: FontWeight.w700,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

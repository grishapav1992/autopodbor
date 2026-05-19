import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/local_llm_profile_guard_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:image_picker/image_picker.dart';

import 'spark_joy_data.dart';
import 'spark_joy_feedback_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

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
  final VoidCallback? onLogout;

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

  // LLM-guard для description — проверяет на «контакты в обход
  // платформы» перед push'ом на сервер.
  final _llmGuard = LocalLlmProfileGuardApi();

  bool _isVerifying = false;
  bool _isSavingProfile = false;
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
  }

  @override
  void dispose() {
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
    final avatarPreset = await UserSimplePreferences.getAvatarPresetIndex();
    if (!mounted) return;
    if (cached != null) {
      // Мерджим cache поверх mock base — base даёт metadata
      // (rating/reportCount/experience/status), cache перебивает
      // personal-поля. Apply controllers — UI заполнится сразу.
      final base = _fallbackSpecialist();
      final merged = <String, dynamic>{...base, ...cached};
      _applyProfileToControllers(merged);
      final cachedUrl =
          (cached['urlAvatar'] as String? ?? '').trim();
      setState(() {
        _specialistProfile = merged;
        _pendingEmailVerify = pending;
        if (cachedUrl.isNotEmpty) _urlAvatar = cachedUrl;
        _avatarBase64 = avatar;
        _avatarPresetIndex = avatarPreset;
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
      ]) {
        seed.remove(key);
      }
      setState(() {
        _specialistProfile = seed;
        _pendingEmailVerify = pending;
        _avatarBase64 = avatar;
        _avatarPresetIndex = avatarPreset;
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
      final serverUrlAvatar =
          result['urlAvatar']?.toString().trim() ?? '';
      setState(() {
        _specialistProfile = merged;
        _urlAvatar = serverUrlAvatar.isNotEmpty ? serverUrlAvatar : null;
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
  Future<void> _pushProfileToServer({required bool descriptionAllowed}) async {
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
    if (descriptionChanged && descriptionAllowed) {
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
    if (payload.isEmpty) return;

    try {
      await storage_api.StorageApi.updateProfile(profile: payload);
      if (!mounted) return;
      // Двигаем все originals вперёд — server теперь знает эти
      // значения, и следующий save с теми же controllers должен дать
      // пустой diff (никаких лишних UpdateProfile вызовов).
      _originalFirstName = firstName;
      _originalLastName = lastName;
      _originalMiddleName = middleName;
      _originalCity = city;
      if (descriptionAllowed) _originalDescription = description;
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
        if (!mounted) return;
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
        if (!mounted) return;
        setState(() => _pendingEmailVerify = null);
      }
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[profile] UpdateProfile failed: $e');
      }
      // Молча — локально уже сохранено, ретрай при следующем save.
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
    controller.dispose();
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
    final confirmed = await showDialog<bool>(
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
              Navigator.of(dialogContext).pop(true);
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
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
    if (confirmed != true || !mounted) return;

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
      final message = e.toString().contains('код')
          ? e.toString()
          : 'Не удалось подтвердить email. Проверьте код и попробуйте ещё раз.';
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: kRedColor),
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

    // Прогоняем description («Описание услуг») через локальный
    // LLM-guard перед server push — он блокирует контакты в обход
    // платформы (phone/email/@-handle). Локально description
    // сохраняется в любом случае; на сервер шлём только если guard
    // не заблокировал.
    //
    // На web guard'а нет (нет ожидания, что у юзера крутится локальный
    // llama.cpp на 127.0.0.1:8081) — пропускаем call, иначе каждый
    // save выдаёт красный CORS preflight fail в DevTools. Боевая
    // защита от контактов в любом случае должна быть на сервере.
    final description = _specializationController.text.trim();
    var descriptionAllowed = true;
    String? guardWarning;
    if (description.isNotEmpty && !kIsWeb) {
      try {
        final guard = await _llmGuard.checkAboutText(description);
        if (guard.blocked) {
          descriptionAllowed = false;
          guardWarning = guard.errors.isNotEmpty
              ? guard.errors.join('; ')
              : (guard.note ?? 'Описание содержит контактные данные');
        }
      } catch (e) {
        // Guard offline — не блокируем save, отправляем как есть.
        if (kDebugMode) {
          debugPrint('[profile] LLM guard failed: $e');
        }
      }
    }

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
      _isSavingProfile = false;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Профиль сохранен')));
    if (emailChanged) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Email изменён — проверьте почту, потребуется повторное '
            'подтверждение.',
          ),
        ),
      );
    }
    if (guardWarning != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Описание услуг не отправлено на сервер: $guardWarning',
          ),
          backgroundColor: kRedColor,
        ),
      );
    }

    // Server push — fire-and-forget; локально уже сохранено.
    unawaited(_pushProfileToServer(descriptionAllowed: descriptionAllowed));
  }

  // «Проверка компании» — verified state.
  //
  // List-style rows (паттерн идентичен «Информации»): Название
  // tappable → переименование; ИНН — read-only info-row, тап
  // открывает info-dialog «как сменить ИНН». Status-pill — только
  // при isVerifyCompany=true (зелёная). Когда pill скрыт, header-row
  // тоже исчезает целиком, чтобы карточка не висела с пустым
  // пространством сверху — overflow-меню (⋯) переезжает в trailing
  // первой row. Раньше карточка одновременно показывала «Статус
  // подтверждён» (зелёная галочка) и отдельный бейдж «На модерации» —
  // пользователь видел это как противоречие.
  Widget _buildBusinessVerified() {
    final canEditName =
        _companyNameController.text.trim().isNotEmpty &&
        !_isVerifyingCompanyName;
    final companyName = _companyNameController.text.trim();
    final pillVisible = _isVerifyCompany == true;
    final overflowMenu = _buildCompanyOverflowMenu();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header rendering: pill + ⋯ когда есть pill; иначе ничего
        // (⋯ переезжает в trailing первой row, см. ниже).
        if (pillVisible) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildCompanyStatusPill()),
              overflowMenu,
            ],
          ),
          const SizedBox(height: SparkSpace.xs),
        ],
        if (companyName.isNotEmpty)
          SparkProfileRow(
            icon: Icons.business_rounded,
            label: 'Название',
            value: _isVerifyingCompanyName ? '...' : companyName,
            onTap: canEditName ? _promptEditCompanyName : null,
            // Когда нет pill — overflow-menu сюда, как trailing.
            trailing: pillVisible ? null : overflowMenu,
          ),
        SparkProfileRow(
          icon: Icons.numbers_rounded,
          label: 'ИНН',
          value: _verifiedInn ?? '',
          muted: true,
          // ИНН не редактируется напрямую — но юзер всё равно тянет тап.
          // Открываем info-bottom-sheet с объяснением, что для смены ИНН
          // нужно сбросить статус.
          onTap: _showInnReadonlySheet,
          // Если pill нет И имя пустое (edge: только ИНН пришёл с
          // сервера) — overflow-menu переезжает сюда.
          trailing: (!pillVisible && companyName.isEmpty) ? overflowMenu : null,
        ),
      ],
    );
  }

  Widget _buildCompanyOverflowMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Действия с компанией',
      icon: const Icon(
        Icons.more_horiz,
        size: SparkSize.iconLg,
        color: kGreyColor,
      ),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'reset') {
          unawaited(_resetBusinessStatus());
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'reset',
          child: Row(
            children: [
              Icon(
                Icons.restart_alt_rounded,
                size: SparkSize.iconSm,
                color: kRedColor,
              ),
              SizedBox(width: SparkSpace.sm),
              MyText(
                text: 'Сбросить статус',
                size: SparkTextSize.body,
                color: kRedColor,
                weight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Info-bottom-sheet для ИНН: объясняет, что поле read-only и как
  /// его поменять (через сброс статуса). Юзер тапает по ИНН — это
  /// очевидное действие; вместо deadeлок'а даём явный hint.
  Future<void> _showInnReadonlySheet() async {
    await showModalBottomSheet<void>(
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
                  children: const [
                    Icon(
                      Icons.numbers_rounded,
                      size: SparkSize.iconLg,
                      color: kSecondaryColor,
                    ),
                    SizedBox(width: SparkSpace.md),
                    MyText(
                      text: 'ИНН изменить нельзя',
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w800,
                    ),
                  ],
                ),
                const SizedBox(height: SparkSpace.lg),
                const MyText(
                  text:
                      'ИНН задаётся при регистрации компании. Чтобы '
                      'указать другой ИНН, сбросьте текущий статус '
                      'компании (меню «⋯» сверху карточки) и пройдите '
                      'регистрацию заново.',
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

  /// Hero status-pill для карточки компании. Рендерим **только** при
  /// `_isVerifyCompany == true` — зелёная «Подтверждено». На модерации
  /// (false) или до первой синхронизации (null) — pill не показываем,
  /// чтобы не создавать тревожный «pending»-сигнал на UI: фактическая
  /// статусная информация всё равно ходит через server, и юзеру
  /// достаточно знать, когда уже подтверждено.
  Widget _buildCompanyStatusPill() {
    if (_isVerifyCompany != true) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.md,
        vertical: SparkSpace.xs,
      ),
      decoration: BoxDecoration(
        color: kGreenColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: SparkSize.iconSm,
            color: kGreenColor,
          ),
          const SizedBox(width: SparkSpace.xs),
          MyText(
            text: '${_businessTypeLabel()} подтверждена',
            size: SparkTextSize.caption,
            weight: FontWeight.w700,
            color: kGreenColor,
          ),
        ],
      ),
    );
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

  Widget _buildProfileInfoRead(Map<String, dynamic> specialist) {
    final city = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : sjRead(specialist, 'city').trim();
    final description = _specializationController.text.trim().isNotEmpty
        ? _specializationController.text.trim()
        : sjRead(specialist, 'specialization').trim();
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
        // ФИО намеренно отсутствует — оно живёт в identity-card сверху
        // (avatar + name), которая теперь tappable → _editFullNameSheet.
        // Дублирование row снизу было лишним.
        SparkProfileRow(
          icon: Icons.location_on_outlined,
          label: 'Город',
          value: city.isEmpty ? 'Не указан' : city,
          valueIsPlaceholder: city.isEmpty,
          onTap: _isSavingProfile ? null : _editCitySheet,
        ),
        SparkProfileRow(
          icon: Icons.list_alt_rounded,
          label: 'Описание услуг',
          value: description.isEmpty ? 'Не указано' : description,
          valueIsPlaceholder: description.isEmpty,
          // Превью обрезается до 3 строк (с «…») — full-text открывается
          // в редакторе. Без этого карточка пухла на 5+ строк, ломая
          // ритм list-rows.
          maxLinesValue: description.isEmpty ? null : 3,
          onTap: _isSavingProfile ? null : _editDescriptionSheet,
        ),
        SparkProfileRow(
          icon: Icons.phone_outlined,
          label: 'Телефон',
          value: phone.isEmpty ? 'Не указан' : phone,
          valueIsPlaceholder: phone.isEmpty,
          // Телефон = auth identity, не редактируется. `muted` даёт
          // серую иконку + dim-text, чтобы row не выглядел tappable.
          muted: phone.isNotEmpty,
        ),
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
      ],
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

  /// Action-sheet выбора аватара. Опции: Камера / Галерея / Удалить +
  /// горизонтальный preset-rail (10 авто-плиток). Picked-image → base64
  /// или выбранный preset → index → UserSimplePreferences. Side-effects
  /// (snackbar / setState) живут здесь, а sheet — чисто UI слой.
  Future<void> _openAvatarPickerSheet() async {
    final hasAvatar =
        (_urlAvatar ?? '').isNotEmpty ||
        (_avatarBase64 ?? '').isNotEmpty ||
        _avatarPresetIndex != null;
    final action = await showModalBottomSheet<String>(
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
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xl,
              vertical: SparkSpace.lg,
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
                    size: SparkTextSize.titleLg,
                    weight: FontWeight.w800,
                  ),
                ),
                _AvatarSheetAction(
                  icon: Icons.photo_camera_outlined,
                  label: 'Сделать фото',
                  onTap: () => Navigator.of(ctx).pop('camera'),
                ),
                _AvatarSheetAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Выбрать из галереи',
                  onTap: () => Navigator.of(ctx).pop('gallery'),
                ),
                if (hasAvatar)
                  _AvatarSheetAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Удалить фото',
                    color: kRedColor,
                    onTap: () => Navigator.of(ctx).pop('delete'),
                  ),
                const SizedBox(height: SparkSpace.lg),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                    vertical: SparkSpace.xs,
                  ),
                  child: MyText(
                    text: 'ИЗ ПОДБОРКИ',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    weight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.md,
                      vertical: SparkSpace.xs,
                    ),
                    itemCount: kSparkAvatarPresets.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: SparkSpace.md),
                    itemBuilder: (_, idx) {
                      final preset = kSparkAvatarPresets[idx];
                      final selected =
                          _avatarPresetIndex == idx &&
                          (_avatarBase64 ?? '').isEmpty;
                      return GestureDetector(
                        onTap: () => Navigator.of(ctx).pop('preset:$idx'),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: preset.background,
                            border: Border.all(
                              color: selected
                                  ? kSecondaryColor
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            preset.icon,
                            color: preset.foreground,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: SparkSpace.md),
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
    if (action == 'delete') {
      await _deleteAvatar();
      return;
    }
    if (action.startsWith('preset:')) {
      final idx = int.tryParse(action.substring('preset:'.length));
      if (idx == null) return;
      await UserSimplePreferences.setAvatarPresetIndex(idx);
      if (!mounted) return;
      setState(() {
        _urlAvatar = null;
        _avatarBase64 = null;
        _avatarPresetIndex = idx;
      });
      return;
    }
    final source = action == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final xfile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (xfile == null || !mounted) return;
      final bytes = await xfile.readAsBytes();
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
      await _uploadAvatarToS3(xfile.name, bytes);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final reason =
          e.code == 'camera_access_denied' || e.code == 'photo_access_denied'
          ? 'Нет доступа. Разрешите в Настройках устройства.'
          : 'Не удалось загрузить фото: ${e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить фото: $e')),
      );
    }
  }

  Future<void> _uploadAvatarToS3(String originalFilename, List<int> bytes) async {
    // Безопасное имя файла: только latin + цифры + расширение.
    final ext = originalFilename.contains('.')
        ? originalFilename.split('.').last.toLowerCase()
        : 'jpg';
    final safeExt = RegExp(r'^[a-z0-9]{1,10}$').hasMatch(ext) ? ext : 'jpg';
    final filename = 'avatar.$safeExt';
    String? uploadId;
    try {
      final session =
          await storage_api.StorageApi.initiateProfileMultipartUpload(
        filename: filename,
        contentLength: bytes.length,
      );
      uploadId = session.uploadId;
      final urlsResult =
          await storage_api.StorageApi.getProfilePartUploadUrls(
        filename: session.filename,
        uploadId: uploadId,
        partCount: 1,
      );
      if (urlsResult.urls.isEmpty) {
        throw Exception('Сервер не вернул URL для загрузки');
      }
      final partUrl = urlsResult.urls.first.url;
      final contentType = safeExt == 'png' ? 'image/png' : 'image/jpeg';
      final etag = await storage_api.StorageApi.uploadBytesToPresignedUrl(
        url: partUrl,
        bytes: bytes,
        contentType: contentType,
      );
      final complete =
          await storage_api.StorageApi.completeProfileMultipartUpload(
        filename: session.filename,
        uploadId: uploadId,
        parts: [storage_api.MultipartUploadedPart(partNumber: 1, etag: etag)],
      );
      if (complete.hasError) {
        final msg = complete.error == 'file_too_large'
            ? 'Файл слишком большой (максимум 25 МБ).'
            : 'Ошибка при завершении загрузки: ${complete.error}';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kRedColor),
        );
        setState(() => _isUploadingAvatar = false);
        return;
      }
      if (complete.publicUrl.isEmpty) {
        throw Exception('Сервер не вернул публичный URL аватарки');
      }
      // Сохраняем publicUrl в профиле на сервере.
      await storage_api.StorageApi.updateProfile(
        profile: {'urlAvatar': complete.publicUrl},
      );
      if (!mounted) return;
      // Чистим base64 — теперь будет грузиться с S3.
      await UserSimplePreferences.clearAvatar();
      if (!mounted) return;
      setState(() {
        _urlAvatar = complete.publicUrl;
        _avatarBase64 = null;
        _isUploadingAvatar = false;
      });
    } catch (e) {
      if (uploadId != null) {
        unawaited(
          storage_api.StorageApi.abortProfileMultipartUpload(
            filename: filename,
            uploadId: uploadId,
          ).catchError((_) {}),
        );
      }
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить фото: $e')),
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

    final saved = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.lg),
        ),
      ),
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
    lastCtrl.dispose();
    firstCtrl.dispose();
    middleCtrl.dispose();
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
    final saved = await _showSingleFieldSheet(
      title: 'Город',
      label: 'Город',
      hint: 'Город осмотров',
      initial: _cityController.text,
      textCapitalization: TextCapitalization.words,
      validate: (value) => value.trim().isEmpty ? 'Введите город' : null,
    );
    if (saved == null) return;
    if (saved.trim() == _cityController.text.trim()) return;
    _cityController.text = saved.trim();
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

  Future<void> _editDescriptionSheet() async {
    final ctrl = TextEditingController(text: _specializationController.text);
    String? error;
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.lg),
        ),
      ),
      builder: (sheetCtx) {
        void append(String suggestion) {
          final current = ctrl.text.trimRight();
          final separator = current.isEmpty ? '' : '\n';
          final next = '$current$separator• $suggestion';
          ctrl.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void submit() {
              Navigator.of(sheetCtx).pop(ctrl.text);
            }

            return _SheetScaffold(
              title: 'Описание услуг',
              onCancel: () => Navigator.of(sheetCtx).pop(),
              onSubmit: submit,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 500,
                  buildCounter:
                      (
                        _, {
                        required int currentLength,
                        required int? maxLength,
                        required bool isFocused,
                      }) => null,
                  textInputAction: TextInputAction.newline,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: (_) {
                    if (error != null) setLocal(() => error = null);
                  },
                  decoration: sparkInputDecoration(
                    'Например: выездной осмотр в Москве и области, '
                    'кузов, электрика',
                  ).copyWith(errorText: error),
                ),
                const SizedBox(height: SparkSpace.lg),
                const MyText(
                  text: 'Быстрое добавление',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  paddingBottom: SparkSpace.sm,
                ),
                Wrap(
                  spacing: SparkSpace.sm,
                  runSpacing: SparkSpace.sm,
                  children: _presetSpecializations
                      .map(
                        (s) => ActionChip(
                          label: Text(s),
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: SparkSize.iconSm,
                            color: kSecondaryColor,
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            append(s);
                          },
                          backgroundColor: kInputBgColor,
                          side: const BorderSide(color: kBorderColor),
                          labelStyle: const TextStyle(
                            color: kTertiaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: SparkTextSize.body,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -2,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            );
          },
        );
      },
    );
    ctrl.dispose();
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
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkRadius.lg),
        ),
      ),
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
    ctrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final specialist = _specialist();
    final composedName = _composeFullName();
    final profileName = composedName.isEmpty
        ? sjRead(specialist, 'name', fallback: 'Специалист')
        : composedName;
    final hasVerifiedBusiness = (_verifiedInn ?? '').isNotEmpty;

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
        // SparkPageHeader removed — the shell's AppBar already shows
        // "Профиль" as the tab title, and the shapka card below owns
        // the specialist's identity. The extra "Мой профиль" + subtitle
        // were a third redundant greeting and crowded the top of the
        // screen.
        SparkCard(
          // Identity-card раньше была tappable целиком → ФИО-редактор.
          // Теперь две независимые tap-зоны: аватар → photo picker
          // (sheet с камерой/галереей/удалить), name+chevron → ФИО
          // редактор. Avatar получил badge-overlay с иконкой камеры
          // для visual affordance (паттерн iOS Settings / Telegram).
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (_isSavingProfile || _isUploadingAvatar)
                    ? null
                    : _openAvatarPickerSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SparkInitialsAvatar(
                      name: profileName,
                      size: SparkSize.icon6xl,
                      textSize: SparkTextSize.modalTitle,
                      imageUrl: _urlAvatar,
                      imageBase64: _avatarBase64,
                      presetIndex: _avatarPresetIndex,
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
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: kSecondaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: kWhiteColor, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 12,
                          color: kWhiteColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.xl),
              Expanded(
                child: InkWell(
                  onTap: _isSavingProfile ? null : _editFullNameSheet,
                  borderRadius: BorderRadius.circular(SparkRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: SparkSpace.xs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MyText(
                                text: profileName,
                                size: SparkTextSize.title,
                                weight: FontWeight.w800,
                                lineHeight: 1.30,
                                tracking: true,
                              ),
                              // Status chip: показываем ТОЛЬКО когда юзер
                              // заблокирован («Неактивен» — красный).
                              () {
                                final active =
                                    sjRead(specialist, 'status') == 'active';
                                if (active) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: SparkSpace.xs,
                                  ),
                                  child: SparkChip(
                                    text: 'Неактивен',
                                    background: kRedColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    color: kRedColor,
                                  ),
                                );
                              }(),
                            ],
                          ),
                        ),
                        const SizedBox(width: SparkSpace.sm),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: kGreyColor,
                          size: SparkSize.iconLg,
                        ),
                      ],
                    ),
                  ),
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
          child: _buildProfileInfoRead(specialist),
        ),
        const SparkSectionTitle('Компания', top: SparkSpace.xl),
        SparkCard(
          // Если карточка в verified-state — list-style padding, как у
          // «Информации». В unverified-state (форма ИНН) — стандартный
          // card padding xl со всех сторон.
          padding: hasVerifiedBusiness
              ? const EdgeInsets.symmetric(
                  horizontal: SparkSpace.md,
                  vertical: SparkSpace.sm,
                )
              : const EdgeInsets.all(SparkSpace.xl),
          child: hasVerifiedBusiness
              ? _buildBusinessVerified()
              : _buildBusinessUnverified(),
        ),
        const SparkSectionTitle('Поддержка', top: SparkSpace.xl),
        SparkCard(
          onTap: _openFeedback,
          child: Row(
            children: [
              const Icon(
                Icons.feedback_outlined,
                color: kSecondaryColor,
                size: SparkSize.iconLg,
              ),
              const SizedBox(width: SparkSpace.md),
              const Expanded(
                child: MyText(
                  text: 'Оставить обратную связь',
                  size: SparkTextSize.body,
                  weight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: kGreyColor,
                size: SparkSize.iconMd,
              ),
            ],
          ),
        ),
        if (widget.onLogout != null) ...[
          const SparkSectionTitle('Аккаунт', top: SparkSpace.xl),
          SparkCard(
            onTap: _confirmLogout,
            child: Row(
              children: [
                const Icon(
                  Icons.logout_rounded,
                  color: kRedColor,
                  size: SparkSize.iconLg,
                ),
                const SizedBox(width: SparkSpace.md),
                const Expanded(
                  child: MyText(
                    text: 'Выйти из аккаунта',
                    size: SparkTextSize.body,
                    weight: FontWeight.w600,
                    color: kRedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
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
      widget.onLogout?.call();
    }
  }

  void _openFeedback() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SparkJoyFeedbackScreen()));
  }
}

/// Каркас bottom-sheet для редактирования профиля: заголовок,
/// scrollable-body (входит в keyboard-safe padding), action-row
/// «Отмена / Сохранить». Используется всеми _edit*-методами профиля.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.onCancel,
    required this.onSubmit,
  });

  final String title;
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
          top: SparkSpace.xxxl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + SparkSpace.xxxl,
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
                    size: SparkTextSize.titleLg,
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
                  child: SizedBox(
                    height: SparkSize.actionHeight,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(shape: buttonShape),
                      child: const Text('Отмена'),
                    ),
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                Expanded(
                  child: SizedBox(
                    height: SparkSize.actionHeight,
                    child: FilledButton(
                      onPressed: onSubmit,
                      style: FilledButton.styleFrom(shape: buttonShape),
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

/// Row-кнопка в avatar bottom-sheet'е. Иконка + лейбл, цвет
/// переключается на `kRedColor` для destructive «Удалить».
class _AvatarSheetAction extends StatelessWidget {
  const _AvatarSheetAction({
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
            vertical: SparkSpace.md,
          ),
          child: Row(
            children: [
              Icon(icon, color: tint, size: SparkSize.iconLg),
              const SizedBox(width: SparkSpace.lg),
              Expanded(
                child: MyText(
                  text: label,
                  size: SparkTextSize.body,
                  weight: FontWeight.w600,
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

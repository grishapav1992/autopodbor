import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/local_llm_profile_guard_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
import 'spark_joy_feedback_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoySpecialistProfileScreen extends StatefulWidget {
  const SparkJoySpecialistProfileScreen({
    super.key,
    this.onBusinessStatusChanged,
    this.onOpenCompletedReports,
  });

  final ValueChanged<String?>? onBusinessStatusChanged;

  /// Optional callback the shell wires in so that tapping the
  /// "Отчётов" stat card on the profile can jump back to the reports
  /// tab and switch the segmented control to "Завершённые". Without a
  /// wiring shell the tap becomes a no-op (stat card stays static).
  final VoidCallback? onOpenCompletedReports;

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

  final _profileFormKey = GlobalKey<FormState>();
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
  bool _profileDirty = false;
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

  // View-by-default for "Информация". The profile opens as a read-only
  // summary (SparkInfoRow list + non-interactive specialization chips);
  // tapping the pencil action flips this flag and reveals the Form with
  // inputs + Save/Cancel buttons. Reduces visual noise on a screen users
  // visit often to glance, rarely to edit.
  bool _profileEditMode = false;
  String? _innError;
  String? _verifiedInn;
  String? _businessType;
  Map<String, dynamic>? _specialistProfile;

  // Real counts of saved drafts + completed reports, loaded from local
  // storage. Fall back to the seed value from sparkSpecialists only while
  // the first load is in flight so the cards never show "0" during a
  // cold start.
  int? _localDraftCount;
  int? _localCompletedCount;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBusinessStatus();
    _loadReportCounts();
  }

  Future<void> _loadReportCounts() async {
    // Drafts are local; completed is online-only now. If the network is
    // down we just show 0 rather than stale cached numbers.
    final drafts = await SparkJoyStorage.loadDrafts();
    var completedCount = 0;
    try {
      final completed = await storage_api.StorageApi.getSpecialistReport(
        page: 1,
        limit: 100,
        isDraft: false,
      );
      completedCount = completed.length;
    } catch (_) {
      completedCount = 0;
    }
    if (!mounted) return;
    setState(() {
      _localDraftCount = drafts.length;
      _localCompletedCount = completedCount;
    });
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
      final parts = sjRead(profile, 'name')
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
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

  void _setProfileDirty() {
    if (_profileDirty) return;
    setState(() => _profileDirty = true);
  }

  /// Appends a preset service to the textarea on a new bullet line —
  /// comma-joined list was cramped and hard to read when the user
  /// mixed in free-form text. Each tap starts a fresh line with `• `
  /// prefix, so the result reads as a clean enumerated list.
  /// Idempotent-free by design — the user can add the same phrase
  /// twice and edit later.
  void _appendSpecializationSuggestion(String suggestion) {
    HapticFeedback.selectionClick();
    final current = _specializationController.text.trimRight();
    final separator = current.isEmpty ? '' : '\n';
    final next = '$current$separator• $suggestion';
    _specializationController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _setProfileDirty();
  }

  Future<void> _loadProfile() async {
    // Cache-as-seed: если local cache есть (последний server snapshot),
    // используем его для мгновенного заполнения form-controllers — юзер
    // сразу видит свои данные на cold start, не ждёт network round-trip.
    // На fresh install / logout cache отсутствует: чистим personal-поля
    // mock seed (rating/reportCount остаются для stat-карточек) чтобы
    // mock-данные («Максим Егоров», «egorov@mail.ru») не протекли через
    // _specialist() в build() header, _cancelProfileEdit(), emailChanged-
    // detection. Form-controllers стартуют пустыми. Параллельно всегда
    // тянем свежий server snapshot через _fetchServerProfile().
    final cached = await SparkJoyStorage.loadSpecialistProfileOrNull();
    final pending = await UserSimplePreferences.getPendingEmailVerify();
    if (!mounted) return;
    if (cached != null) {
      // Мерджим cache поверх mock base — base даёт metadata
      // (rating/reportCount/experience/status), cache перебивает
      // personal-поля. Apply controllers — UI заполнится сразу.
      final base = _fallbackSpecialist();
      final merged = <String, dynamic>{...base, ...cached};
      _applyProfileToControllers(merged);
      setState(() {
        _specialistProfile = merged;
        _profileDirty = false;
        _pendingEmailVerify = pending;
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
        _profileDirty = false;
        _pendingEmailVerify = pending;
      });
    }
    unawaited(_fetchServerProfile());
  }

  /// Тянет профиль с сервера и перезаписывает контроллеры —
  /// server-данные приоритетнее локальных. Если поле инспектор уже
  /// редактирует (_profileDirty), НЕ затираем — иначе потеряются
  /// несохранённые правки.
  ///
  /// Race-protection: каждый вызов захватывает `myGen` в начале.
  /// Если кто-то bumped `_fetchGeneration` (например _resetBusinessStatus
  /// invalidate'ил in-flight fetch'ы), результат тихо отбрасывается —
  /// мы не имеем права писать в state, иначе stale snapshot откатит UI.
  Future<void> _fetchServerProfile() async {
    final myGen = ++_fetchGeneration;
    try {
      final result = await storage_api.StorageApi.getProfile();
      if (!mounted || myGen != _fetchGeneration) return;
      // Server-side role («specialist» / «company» / «client») — единый
      // источник правды для роли. Синкаем в локальные prefs до setState,
      // чтобы shell-callback увидел консистентное состояние.
      final serverRole = (result['role'] ?? '').toString().trim();
      await _syncServerRoleToLocal(serverRole, result['companyInn']);
      if (!mounted || myGen != _fetchGeneration) return;
      if (_profileDirty) {
        // Инспектор уже что-то правит — обновляем только метаданные
        // (флаг модерации), сами поля не трогаем.
        setState(() {
          _isVerifyCompany = result['isVerifyCompany'] == true;
        });
        return;
      }
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
        if (result['companyName'] != null)
          'companyName': result['companyName'].toString(),
      };
      // city пока не в GetProfile response, но возможно появится —
      // на всякий случай маппим.
      if (result['city'] != null) merged['city'] = result['city'];
      _applyProfileToControllers(merged);
      final serverInn = result['companyInn'];
      setState(() {
        _specialistProfile = merged;
        _isVerifyCompany = result['isVerifyCompany'] == true;
        if (serverInn != null) {
          final innStr = serverInn.toString();
          _verifiedInn = innStr;
          _innController.text = innStr;
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
        if (result['middleName'] != null)
          'middleName': result['middleName'],
        if (result['email'] != null) 'email': result['email'],
        if (result['phone'] != null) 'phone': result['phone'],
        if (result['description'] != null)
          'specialization': result['description'],
        if (result['companyName'] != null)
          'companyName': result['companyName'].toString(),
        if (result['city'] != null) 'city': result['city'],
        if (result['role'] != null) 'role': result['role'],
        if (serverInn != null) 'companyInn': serverInn.toString(),
        if (result['isVerifyCompany'] != null)
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
    final emailChanged = email.isNotEmpty &&
        email.toLowerCase() != _originalEmail.toLowerCase();
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
    if (companyNameChanged &&
        companyName.isNotEmpty &&
        companyInn.isNotEmpty) {
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
      if (companyNameChanged && companyName.isNotEmpty && companyInn.isNotEmpty) {
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

    // Захватываем предыдущую роль ДО записи новой, чтобы детектить
    // реальную смену и триггерить RefreshToken (per UpdateProfile docs:
    // «Если меняется role, после успешного ответа клиент должен вызвать
    // RefreshToken и заменить access/refresh токены»). Без этого JWT
    // claim role остаётся stale.
    final previousRole = await UserSimplePreferences.getUserRole();
    final localRoleChanged = previousRole != newRoleString;

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

    // RefreshToken только если роль реально поменялась — иначе лишний
    // запрос на каждый GetProfile-pull. На fail просто логируем: на
    // следующем API-call'е `_postRpc` 401-retry-flow сам ротирует
    // токены, если access-claim role стал отвергаться сервером.
    if (localRoleChanged) {
      final refreshed = await storage_api.StorageApi.tryRefreshTokens();
      if (!refreshed && kDebugMode) {
        debugPrint(
          '[profile] role changed ($previousRole → $newRoleString) but '
          'tryRefreshTokens failed; relying on _postRpc 401-retry-flow',
        );
      }
    }

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
    if (!mounted) return;
    setState(() {
      // Race-guard: если server fetch уже установил _verifiedInn —
      // не затираем свежее серверное значение локальным стейл-кэшем.
      // Когда инспектор делает Сбросить (см. _resetBusinessStatus),
      // он явно ставит _verifiedInn = null, и тогда локальное значение
      // всё равно не подхватится — но это ожидаемое поведение reset'а.
      if (_verifiedInn == null && inn != null && inn.isNotEmpty) {
        _verifiedInn = inn;
        _innController.text = inn;
      }
      _businessType ??= businessType;
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
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Данные компании отправлены на модерацию'),
        ),
      );
      // Re-fetch GetProfile подтянет isVerifyCompany + актуальную роль
      // от сервера. _syncServerRoleToLocal внутри _fetchServerProfile
      // увидит смену роли (specialist → company) и сам дёрнет
      // RefreshToken чтобы JWT claim role обновился.
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
      await SparkJoyStorage.cancelCompanyMode();
      // Sync local prefs role + RefreshToken. Раньше делалось через
      // unawaited(_fetchServerProfile()) → _syncServerRoleToLocal,
      // но fetch триггерит race с server-side eventual consistency
      // (см. doc-комментарий выше). Зовём напрямую — уже знаем
      // что после успешного UpdateProfile role обязана быть specialist.
      await _syncServerRoleToLocal('specialist', null);
      // Patch local profile cache — удаляем company-поля и
      // фиксируем role='specialist'. Иначе следующий cold start
      // в profile screen использовал бы stale cache как seed.
      final cached = await SparkJoyStorage.loadSpecialistProfileOrNull() ??
          <String, dynamic>{};
      cached.remove('companyName');
      cached.remove('companyInn');
      cached.remove('isVerifyCompany');
      cached['role'] = 'specialist';
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
      bullets.add('${s.totalDrafts} ${_draftsPlural(s.totalDrafts)} будут удалены$suffix');
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

  String? _requiredValidator(String? value, String fieldLabel) {
    if ((value ?? '').trim().isEmpty) {
      return 'Заполните поле: $fieldLabel';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final raw = (value ?? '').trim();
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
                      autofillHints: const <String>[
                        AutofillHints.oneTimeCode,
                      ],
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        // Backend пример показывает 6-значный код.
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
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
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSavingProfile = true);

    // Запоминаем «до»-снимок email чтобы после save показать подсказку
    // «требует повторной верификации» если значение изменилось. Server
    // при смене email инвалидирует подтверждение, инспектор должен
    // открыть письмо и подтвердить новый адрес.
    final previousEmail = sjRead(_specialist(), 'email').trim();
    final newEmail = _emailController.text.trim();
    final emailChanged =
        newEmail.isNotEmpty && newEmail.toLowerCase() != previousEmail.toLowerCase();

    // Прогоняем description («Описание услуг») через локальный
    // LLM-guard перед server push — он блокирует контакты в обход
    // платформы (phone/email/@-handle). Локально description
    // сохраняется в любом случае; на сервер шлём только если guard
    // не заблокировал.
    final description = _specializationController.text.trim();
    var descriptionAllowed = true;
    String? guardWarning;
    if (description.isNotEmpty) {
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
      _profileDirty = false;
      _isSavingProfile = false;
      // Collapse back to the read-only summary after a successful save
      // — users want to see the result of their edit, not stay in
      // edit-mode with the same buttons.
      _profileEditMode = false;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Профиль сохранен')),
    );
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
  // Cleaner than the previous mixed layout (info-rows + still-visible
  // input + retry button): we commit to a success card that shows the
  // result and a single subtle "Сбросить" link. If the user needs to
  // re-verify they tap reset first, which clears state and switches
  // this card to the unverified layout.
  Widget _buildBusinessVerified() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              size: SparkSize.iconMd,
              color: kGreenColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            Expanded(
              child: MyText(
                text: 'Статус «${_businessTypeLabel()}» подтверждён',
                size: SparkTextSize.body,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.md),
        SparkInfoRow(label: 'ИНН', value: _verifiedInn ?? ''),
        if (_companyNameController.text.trim().isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          Row(
            children: [
              Expanded(
                child: SparkInfoRow(
                  label: 'Название',
                  value: _companyNameController.text.trim(),
                ),
              ),
              // Edit-link для переименования компании без полного
              // reset'а. Открывает диалог ввода → UpdateProfile со
              // существующим ИНН — server сохранит новое имя и
              // перезапустит модерацию (isVerifyCompany=false).
              TextButton.icon(
                onPressed: _isVerifyingCompanyName
                    ? null
                    : _promptEditCompanyName,
                icon: const Icon(Icons.edit_outlined, size: SparkSize.iconSm),
                label: Text(
                  _isVerifyingCompanyName ? '...' : 'Изменить',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: kSecondaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.sm,
                    vertical: SparkSpace.xxs,
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                ),
              ),
            ],
          ),
        ],
        // Server-side флаг модерации (isVerifyCompany) — серый pending
        // или зелёное «Компания подтверждена». Локальный
        // «verifyInnAndPromote» — это только проверка длины ИНН, а
        // настоящую модерацию делает бэк.
        if (_isVerifyCompany != null) ...[
          const SizedBox(height: SparkSpace.md),
          _buildCompanyVerifyBadge(_isVerifyCompany!),
        ],
        const SizedBox(height: SparkSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _resetBusinessStatus,
            style: TextButton.styleFrom(
              foregroundColor: kRedColor,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.md,
                vertical: SparkSpace.xs,
              ),
              visualDensity: const VisualDensity(
                horizontal: -2,
                vertical: -2,
              ),
            ),
            child: const Text('Сбросить статус'),
          ),
        ),
      ],
    );
  }

  /// Бейдж статуса модерации компании. Отображает что сервер сказал
  /// про `isVerifyCompany`: true → подтверждено (зелёный), false →
  /// на модерации (оранжевый). Бейдж не показывается пока сервер
  /// не вернул значение (`_isVerifyCompany == null`).
  Widget _buildCompanyVerifyBadge(bool verified) {
    final color = verified ? kGreenColor : Colors.orange;
    final icon = verified ? Icons.verified_rounded : Icons.pending_outlined;
    final label = verified ? 'Компания подтверждена' : 'На модерации';
    return Row(
      children: [
        Icon(icon, size: SparkSize.iconSm, color: color),
        const SizedBox(width: SparkSpace.sm),
        MyText(
          text: label,
          size: SparkTextSize.caption,
          weight: FontWeight.w600,
          color: color,
        ),
      ],
    );
  }

  // «Проверка компании» — unverified state.
  //
  // Focused mini-form: prompt → labelled input → single primary button.
  // Layout mirrors _profileTextField so the ИНН field reads as part of
  // the same visual system, not a standalone oddity.
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

  void _cancelProfileEdit() {
    final specialist = _specialist();
    _applyProfileToControllers(specialist);
    setState(() {
      _profileDirty = false;
      _profileEditMode = false;
    });
  }

  Widget _buildProfileInfoRead(Map<String, dynamic> specialist) {
    final specializationText = _specializationController.text.trim().isEmpty
        ? sjRead(specialist, 'specialization').trim()
        : _specializationController.text.trim();
    String valueOrDash(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '—' : trimmed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: hint + pencil "Изменить" action.
        Row(
          children: [
            const Expanded(
              child: MyText(
                text: 'Контактные данные и специализация',
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _profileEditMode = true);
              },
              icon: const Icon(Icons.edit_outlined, size: SparkSize.iconSm),
              label: const Text('Изменить'),
              style: TextButton.styleFrom(
                foregroundColor: kSecondaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.md,
                  vertical: SparkSpace.xs,
                ),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.md),
        SparkInfoRow(
          label: 'ФИО',
          value: valueOrDash(
            _composeFullName().isEmpty
                ? sjRead(specialist, 'name')
                : _composeFullName(),
          ),
        ),
        SparkInfoRow(
          label: 'Город',
          value: valueOrDash(
            _cityController.text.isEmpty
                ? sjRead(specialist, 'city')
                : _cityController.text,
          ),
        ),
        // Specialization is now a free-form description. Render as a
        // paragraph so line breaks and longer sentences read
        // naturally; fall back to an em-dash for empty profiles.
        const SizedBox(height: SparkSpace.md),
        const MyText(
          text: 'Описание услуг',
          size: SparkTextSize.body,
          color: kGreyColor,
        ),
        const SizedBox(height: SparkSpace.sm),
        MyText(
          text: specializationText.isEmpty ? '—' : specializationText,
          size: SparkTextSize.body,
          color: specializationText.isEmpty ? kGreyColor : kTertiaryColor,
        ),
        const SizedBox(height: SparkSpace.md),
        SparkInfoRow(
          label: 'Телефон',
          value: valueOrDash(
            _phoneController.text.isEmpty
                ? sjRead(specialist, 'phone')
                : _phoneController.text,
          ),
        ),
        SparkInfoRow(
          label: 'Email',
          value: valueOrDash(
            _emailController.text.isEmpty
                ? sjRead(specialist, 'email')
                : _emailController.text,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoEdit() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileTextField(
            controller: _lastNameController,
            label: 'Фамилия',
            hint: 'Иванов',
            validator: (value) => _requiredValidator(value, 'Фамилия'),
          ),
          _profileTextField(
            controller: _firstNameController,
            label: 'Имя',
            hint: 'Иван',
            validator: (value) => _requiredValidator(value, 'Имя'),
          ),
          _profileTextField(
            controller: _middleNameController,
            label: 'Отчество',
            hint: 'Иванович',
          ),
          _profileTextField(
            controller: _cityController,
            label: 'Город',
            hint: 'Город осмотров',
            validator: (value) => _requiredValidator(value, 'Город'),
          ),
          _buildSpecializationEditor(),
          _profileTextField(
            controller: _phoneController,
            label: 'Телефон',
            hint: '+7...',
            keyboardType: TextInputType.phone,
            readOnly: true,
            helperText: 'Авторизация по номеру — менять нельзя',
          ),
          _profileTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          // Кнопка-ссылка «Подтвердить email» под полем. Сервер шлёт
          // 6-значный код на email при СМЕНЕ через UpdateProfile;
          // Storage.VerifyEmail({code}) подтверждает. Показываем ТОЛЬКО
          // когда инспектор реально изменил адрес (current != original) —
          // иначе сбивает с толку («email не подтверждён?»).
          // ValueListenableBuilder слушает _emailController на каждое
          // нажатие клавиши, в отличие от _setProfileDirty с early-return.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _emailController,
            builder: (context, value, _) {
              final current = value.text.trim();
              // Email де-факто case-insensitive (Gmail, Outlook, большинство
              // SMTP). Сравниваем в нижнем регистре чтобы смена T/t не
              // создавала ложный сигнал «email изменён».
              if (current.isEmpty ||
                  current.toLowerCase() == _originalEmail.toLowerCase()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: SparkSpace.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isVerifyingEmail
                        ? null
                        : _promptEmailVerificationCode,
                    icon: const Icon(
                      Icons.mark_email_read_outlined,
                      size: SparkSize.iconSm,
                    ),
                    label: Text(
                      _isVerifyingEmail
                          ? 'Подтверждаем...'
                          : 'Подтвердить email кодом из письма',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: kSecondaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.md,
                        vertical: SparkSpace.xs,
                      ),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Название компании раньше жило здесь; теперь рендерится в
          // карточке «Проверка компании» ниже — рядом с ИНН, как и
          // должно быть концептуально (пара companyName + companyInn).
          const SizedBox(height: SparkSpace.xs),
          // Same explicit RoundedRectangleBorder on both Cancel + Save
          // so the theme's default FilledButton StadiumBorder doesn't
          // turn one into a pill while the other stays a rectangle.
          () {
            final buttonShape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SparkRadius.lg),
            );
            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: SparkSize.actionHeight,
                    child: OutlinedButton(
                      onPressed: _isSavingProfile ? null : _cancelProfileEdit,
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
                      onPressed: _isSavingProfile ? null : _saveProfile,
                      style: FilledButton.styleFrom(shape: buttonShape),
                      child: Text(
                        _isSavingProfile ? 'Сохраняем...' : 'Сохранить',
                      ),
                    ),
                  ),
                ),
              ],
            );
          }(),
        ],
      ),
    );
  }

  Widget _profileTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? helperText,
  }) {
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
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            readOnly: readOnly,
            // Не помечаем dirty при изменении read-only-полей (теоретически
            // их и нельзя поменять, но защищаемся от программных setText).
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: readOnly ? null : (_) => _setProfileDirty(),
            decoration: sparkInputDecoration(
              hint ?? label,
            ).copyWith(helperText: helperText),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationEditor() {
    return Padding(
      padding: const EdgeInsets.only(bottom: SparkSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Описание услуг',
            size: SparkTextSize.body,
            color: kGreyColor,
            paddingBottom: SparkSpace.md,
          ),
          TextField(
            controller: _specializationController,
            maxLines: 4,
            minLines: 3,
            // Limit enforced but counter suppressed — Flutter's default
            // `187/500` footer is unstyled and doesn't match the
            // spark_joy design.
            maxLength: 500,
            buildCounter: (
              context, {
              required int currentLength,
              required int? maxLength,
              required bool isFocused,
            }) =>
                null,
            textInputAction: TextInputAction.newline,
            onTapOutside: (_) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => _setProfileDirty(),
            decoration: sparkInputDecoration(
              'Например: выездной осмотр в Москве и области, кузов, электрика',
            ),
          ),
          const SizedBox(height: SparkSpace.sm),
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
                    onPressed: () => _appendSpecializationSuggestion(s),
                    backgroundColor: kInputBgColor,
                    side: const BorderSide(color: kBorderColor),
                    labelStyle: const TextStyle(
                      color: kTertiaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: SparkTextSize.body,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity:
                        const VisualDensity(horizontal: 0, vertical: -2),
                  ),
                )
                .toList(growable: false),
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

    return SparkScreenList(
      bottomInset: 56,
      onRefresh: () async {
        await Future.wait([
          _loadProfile(),
          _loadBusinessStatus(),
          _loadReportCounts(),
        ]);
      },
      children: [
        // Persistent banner «Email ждёт подтверждения» — рендерится
        // когда _pendingEmailVerify установлен и совпадает с текущим
        // значением в _emailController (case-insensitive). Реактивно
        // через ValueListenableBuilder — иначе после первого изменения
        // email setState больше не триггерится (_setProfileDirty имеет
        // early-return), и banner застревал бы в stale-состоянии.
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SparkInitialsAvatar(
                name: profileName,
                size: SparkSize.icon6xl,
                textSize: SparkTextSize.modalTitle,
              ),
              const SizedBox(width: SparkSpace.xl),
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
                    const SizedBox(height: SparkSpace.xs),
                    Wrap(
                      spacing: SparkSpace.sm,
                      runSpacing: SparkSpace.sm,
                      children: [
                        SparkChip(
                          text:
                              sparkFormatLabels[sjRead(specialist, 'format')] ??
                              'Специалист',
                          background: kSecondaryColor.withValues(alpha: 0.1),
                          color: kSecondaryColor,
                        ),
                        // Status chip: грей-на-грей «Неактивен» в прошлом
                        // варианте визуально тонул. Инактив — это реальная
                        // проблема пользователя (заблокирован / выключен),
                        // а не нейтральная декорация; даём red-tint так же
                        // как делает green для активного статуса.
                        () {
                          final active = sjRead(specialist, 'status') == 'active';
                          return SparkChip(
                            text: active ? 'Активен' : 'Неактивен',
                            background: active
                                ? kGreenColor.withValues(alpha: 0.15)
                                : kRedColor.withValues(alpha: 0.12),
                            color: active ? kGreenColor : kRedColor,
                          );
                        }(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Reordered: Stats before Info before Business. The old order
        // (Info → Business → Stats at the very bottom) buried the
        // glanceable counters under a 6-field form. Users read stats
        // often and edit profile rarely, so the top-to-bottom ordering
        // matches actual interaction frequency.
        const SparkSectionTitle('Статистика', top: SparkSpace.xxl),
        Row(
          children: [
            Expanded(
              // Semantics container so VoiceOver/TalkBack announce the
              // whole stat card as one focused element ("Отчётов, 42"),
              // not two independent nodes (bare digits + bare word).
              // Excludes child semantics for the same no-redundancy
              // reason as the draft progress bar (92b0135).
              child: Semantics(
                container: true,
                button: widget.onOpenCompletedReports != null,
                label: 'Отчётов',
                value: (_localCompletedCount ?? 0).toString(),
                hint: widget.onOpenCompletedReports == null
                    ? null
                    : 'Двойной тап открывает список завершённых отчётов',
                excludeSemantics: true,
                child: SparkCard(
                  // Tap the "Отчётов" counter to jump back to the reports
                  // tab with the completed segment selected. Wired via the
                  // shell's onOpenCompletedReports callback; if the shell
                  // didn't wire it (e.g. in preview/tests) the card is
                  // just a static counter.
                  onTap: widget.onOpenCompletedReports == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          widget.onOpenCompletedReports!();
                        },
                  child: Column(
                    children: [
                      MyText(
                        text: (_localCompletedCount ?? 0).toString(),
                        size: SparkSize.iconXl,
                        weight: FontWeight.w800,
                        color: kSecondaryColor,
                        tabularFigures: true,
                      ),
                      const MyText(
                        text: 'Отчётов',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: SparkSpace.lg),
            Expanded(
              child: Semantics(
                container: true,
                label: 'Активных осмотров',
                value: (_localDraftCount ?? 0).toString(),
                excludeSemantics: true,
                child: SparkCard(
                  child: Column(
                    children: [
                      MyText(
                        text: (_localDraftCount ?? 0).toString(),
                        size: SparkSize.iconXl,
                        weight: FontWeight.w800,
                        color: kSecondaryColor,
                        tabularFigures: true,
                      ),
                      const MyText(
                        text: 'Активных осмотров',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SparkSectionTitle('Информация', top: SparkSpace.xxl),
        SparkCard(
          child: _profileEditMode
              ? _buildProfileInfoEdit()
              : _buildProfileInfoRead(specialist),
        ),
        const SparkSectionTitle('Проверка компании', top: SparkSpace.xxl),
        SparkCard(
          child: hasVerifiedBusiness
              ? _buildBusinessVerified()
              : _buildBusinessUnverified(),
        ),
        const SparkSectionTitle('Поддержка', top: SparkSpace.xxl),
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
      ],
    );
  }

  void _openFeedback() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SparkJoyFeedbackScreen(),
      ),
    );
  }
}


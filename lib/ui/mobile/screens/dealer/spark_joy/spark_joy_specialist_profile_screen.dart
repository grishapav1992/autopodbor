import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/local_llm_profile_guard_api.dart';
import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
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
  final _experienceController = TextEditingController();
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
  // Server-side флаг модерации компании (поле `isVerifyCompany` из
  // GetProfile). null до первой синхронизации; true/false после.
  bool? _isVerifyCompany;

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
    _experienceController.dispose();
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
    _experienceController.text = sjRead(profile, 'experience');
    _specializationController.text = _extractSpecializationText(profile);
    _companyNameController.text = sjRead(profile, 'companyName');
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
    final profile = await SparkJoyStorage.loadSpecialistProfile();
    if (!mounted) return;
    _applyProfileToControllers(profile);
    setState(() {
      _specialistProfile = profile;
      _profileDirty = false;
    });
    // Параллельно пытаемся подтянуть данные с сервера. На ошибку
    // (offline / 401) тихо откатываемся к локальным — никакого
    // блокирующего UI.
    unawaited(_fetchServerProfile());
  }

  /// Тянет профиль с сервера и перезаписывает контроллеры —
  /// server-данные приоритетнее локальных. Если поле инспектор уже
  /// редактирует (_profileDirty), НЕ затираем — иначе потеряются
  /// несохранённые правки.
  Future<void> _fetchServerProfile() async {
    try {
      final result = await storage_api.StorageApi.getProfile();
      if (!mounted) return;
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
    } on storage_api.SessionExpiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия истекла — войдите заново')),
      );
    } catch (e) {
      // Offline / network / parsing — silently fall back to local.
      if (kDebugMode) {
        debugPrint('[profile] GetProfile failed: $e');
      }
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

    if (lastName.isNotEmpty) payload['lastName'] = lastName;
    if (firstName.isNotEmpty) payload['firstName'] = firstName;
    if (middleName.isNotEmpty) payload['middleName'] = middleName;
    if (email.isNotEmpty) payload['email'] = email;
    if (city.isNotEmpty) payload['city'] = city;
    if (descriptionAllowed && description.isNotEmpty) {
      payload['description'] = description;
    }
    // companyName и companyInn сервер сохраняет только парой — если
    // оба заполнены, шлём оба; иначе пропускаем оба.
    if (companyName.isNotEmpty && companyInn.isNotEmpty) {
      payload['companyName'] = companyName;
      // Server ожидает companyInn как строку (см. UpdateProfile
      // schema), хотя в GetProfile возвращается как integer.
      payload['companyInn'] = companyInn;
    }
    if (payload.isEmpty) return;

    try {
      await storage_api.StorageApi.updateProfile(profile: payload);
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
      setState(() {
        _innError = validationError;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isVerifying = true);
    // Имитация «технической проверки». Ранее тут был сетевой запрос
    // в api-cloud.ru/pb_nalog; сейчас провайдер не подключён, так
    // что просто валидируем формат ИНН локально. Когда появится
    // новый провайдер — `verifyInnAndPromote` будет дёргать его API,
    // а delay уйдёт.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final businessType = await SparkJoyStorage.verifyInnAndPromote(
      _innController.text,
    );

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
    });

    if (businessType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось подтвердить ИНН')),
      );
      return;
    }

    final inn = SparkJoyStorage.normalizeInn(_innController.text);
    setState(() {
      _businessType = businessType;
      _verifiedInn = inn;
      _innController.text = inn;
      _innError = null;
    });

    widget.onBusinessStatusChanged?.call(businessType);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          businessType == 'ip'
              ? 'Тех. проверка пройдена: статус ИП'
              : 'Тех. проверка пройдена: статус Компания',
        ),
      ),
    );
  }

  /// Hard-reset the company role. Shows a confirmation dialog
  /// enumerating every piece of local data that will be wiped
  /// (drafts, pending invites, staff preferences) so the user can't
  /// lose work by accident. On confirm, [SparkJoyStorage.cancelCompanyMode]
  /// deletes the drafts and resets the business verification.
  Future<void> _resetBusinessStatus() async {
    if (_isVerifying) return;
    final messenger = ScaffoldMessenger.of(context);
    final summary = await SparkJoyStorage.buildCompanyCancelSummary();
    if (!mounted) return;
    final confirmed = await _showCancelCompanyDialog(summary);
    if (confirmed != true) return;
    await SparkJoyStorage.cancelCompanyMode();
    if (!mounted) return;
    setState(() {
      _verifiedInn = null;
      _businessType = null;
    });
    widget.onBusinessStatusChanged?.call(null);
    messenger.showSnackBar(
      const SnackBar(content: Text('Статус сброшен: теперь вы специалист')),
    );
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
      'experience': _experienceController.text.trim(),
      'companyName': _companyNameController.text.trim(),
    };
    await SparkJoyStorage.saveSpecialistProfile(next);

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
          SparkInfoRow(
            label: 'Название',
            value: _companyNameController.text.trim(),
          ),
        ],
        // Server-side флаг модерации (isVerifyCompany) — серый pending
        // или зелёное «Компания подтверждена». Локальный
        // «verifyInnAndPromote» — это только проверка длины ИНН, а
        // настоящую модерацию делает бэк. Поле «Название компании»
        // редактируется в основной форме edit-mode (см.
        // _buildProfileInfoEdit) — рядом с ФИО / email / city, чтобы
        // save-кнопка профиля захватывала все поля сразу.
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
              'Подтвердите ИНН, чтобы открыть функции компании или ИП. Данные уйдут в тех. проверку.',
          size: SparkTextSize.body,
          color: kGreyColor,
        ),
        const SizedBox(height: SparkSpace.lg),
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
          label: 'Опыт',
          value: valueOrDash(
            _experienceController.text.isEmpty
                ? sjRead(specialist, 'experience')
                : _experienceController.text,
          ),
        ),
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
            controller: _experienceController,
            label: 'Опыт',
            hint: 'Например: 8 лет',
          ),
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
          // Название компании парная к ИНН (ниже на экране, в карточке
          // «Проверка компании»). Server сохраняет companyName +
          // companyInn только атомарно. Если ИНН не подтверждён —
          // companyName проигнорируется при server push.
          _profileTextField(
            controller: _companyNameController,
            label: 'Название компании',
            hint: 'ООО «Авто-Подбор»',
            helperText: 'Сохраняется только если подтверждён ИНН ниже',
          ),
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
        if (kDebugMode) const _NotifDebugBar(),
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

/// Dev-only bar with two buttons that fire
/// `Notification.DebugSendNotificationToSelf` (reminder / system).
/// Backend gates the RPC behind `APP_DEBUG=true`; this widget is also
/// compiled out in release via `kDebugMode`.
class _NotifDebugBar extends StatefulWidget {
  const _NotifDebugBar();

  @override
  State<_NotifDebugBar> createState() => _NotifDebugBarState();
}

class _NotifDebugBarState extends State<_NotifDebugBar> {
  bool _busy = false;

  Future<void> _send(NotificationType type) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await NotificationApi.debugSendToSelf(
        type: type,
        title: type == NotificationType.reminder
            ? 'Тест: напоминание'
            : 'Тест: системное',
        body: 'Push-проверка через WebSocket',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: kGreenColor,
          content: Text('Отправлено — должно прилететь через WS'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kRedColor,
          content: Text('Ошибка: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: SparkSpace.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.lg,
      ),
      decoration: BoxDecoration(
        color: kBlueColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SparkRadius.md),
        border: Border.all(color: kBlueColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bug_report_outlined,
            size: SparkSize.iconMd,
            color: kBlueColor,
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: MyText(
              text: 'Notif debug:',
              size: SparkTextSize.body,
              color: kBlueColor,
              weight: FontWeight.w700,
            ),
          ),
          _NotifDebugSendButton(
            label: 'reminder',
            busy: _busy,
            onTap: () => _send(NotificationType.reminder),
          ),
          const SizedBox(width: SparkSpace.sm),
          _NotifDebugSendButton(
            label: 'system',
            busy: _busy,
            onTap: () => _send(NotificationType.system),
          ),
        ],
      ),
    );
  }
}

class _NotifDebugSendButton extends StatelessWidget {
  const _NotifDebugSendButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.5 : 1,
      child: Material(
        color: kBlueColor,
        borderRadius: BorderRadius.circular(SparkRadius.sm),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(SparkRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.lg,
              vertical: SparkSpace.sm,
            ),
            child: MyText(
              text: label,
              size: SparkTextSize.caption,
              color: kWhiteColor,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

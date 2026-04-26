import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_data.dart';
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
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _experienceController = TextEditingController();
  // Free-form «описание услуг». Chip-suggestions below the textarea
  // just append their label into this controller — the textarea is
  // the single source of truth.
  final _specializationController = TextEditingController();

  bool _isVerifying = false;
  bool _isSavingProfile = false;
  bool _profileDirty = false;

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
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
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
    _nameController.text = sjRead(profile, 'name');
    _cityController.text = sjRead(profile, 'city');
    _phoneController.text = sjRead(profile, 'phone');
    _emailController.text = sjRead(profile, 'email');
    _experienceController.text = sjRead(profile, 'experience');
    _specializationController.text = _extractSpecializationText(profile);
  }

  /// Reads the profile's specialization as a plain-text description.
  /// Legacy profiles stored it as a `specializations` list of tags;
  /// we join those with `, ` so the textarea reads naturally. New
  /// saves always write the single `specialization` string.
  String _extractSpecializationText(Map<String, dynamic> profile) {
    final text = sjRead(profile, 'specialization').trim();
    if (text.isNotEmpty) return text;
    final fromList = profile['specializations'];
    if (fromList is List && fromList.isNotEmpty) {
      final parts = <String>[];
      for (final raw in fromList) {
        final value = raw.toString().trim();
        if (value.isNotEmpty) parts.add(value);
      }
      return parts.join(', ');
    }
    return '';
  }

  void _setProfileDirty() {
    if (_profileDirty) return;
    setState(() => _profileDirty = true);
  }

  /// Appends a preset service to the textarea. Idempotent-free by
  /// design — the user can add the same phrase twice and edit later;
  /// we don't want to swallow taps silently.
  void _appendSpecializationSuggestion(String suggestion) {
    HapticFeedback.selectionClick();
    final current = _specializationController.text;
    final separator = current.trim().isEmpty ? '' : ', ';
    final next = '$current$separator$suggestion';
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
  }

  Future<void> _loadBusinessStatus() async {
    final inn = await SparkJoyStorage.currentVerifiedInn();
    final businessType = await SparkJoyStorage.currentBusinessType();
    if (!mounted) return;
    setState(() {
      _verifiedInn = inn;
      _businessType = businessType;
      if (inn != null && inn.isNotEmpty) {
        _innController.text = inn;
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

  String? _phoneValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      return 'Введите корректный телефон';
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
    final current = _specialist();
    final next = {
      ...current,
      'id': sjRead(current, 'id', fallback: kSparkSpecialistId),
      'name': _nameController.text.trim(),
      'city': _cityController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'specialization': _specializationController.text.trim(),
      // Explicitly drop the legacy `specializations` list — the
      // string above is now the single source of truth. Without this
      // the stored list from older saves would keep drifting.
      'specializations': const <String>[],
      'experience': _experienceController.text.trim(),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Профиль сохранен')));
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
            _nameController.text.isEmpty
                ? sjRead(specialist, 'name')
                : _nameController.text,
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
            controller: _nameController,
            label: 'ФИО',
            hint: 'Имя специалиста',
            validator: (value) => _requiredValidator(value, 'ФИО'),
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
            validator: _phoneValidator,
          ),
          _profileTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
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
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => _setProfileDirty(),
            decoration: sparkInputDecoration(hint ?? label),
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
    final profileName = _nameController.text.trim().isEmpty
        ? sjRead(specialist, 'name', fallback: 'Специалист')
        : _nameController.text.trim();
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
      ],
    );
  }
}

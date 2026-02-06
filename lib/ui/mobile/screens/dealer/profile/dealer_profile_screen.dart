import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/utils/contact_redaction.dart';
import 'package:flutter_application_1/data/api/local_llm_profile_guard_api.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

class DealerProfileScreen extends StatefulWidget {
  const DealerProfileScreen({super.key});

  @override
  State<DealerProfileScreen> createState() => _DealerProfileScreenState();
}

class _DealerProfileScreenState extends State<DealerProfileScreen>
    with SingleTickerProviderStateMixin {
  static const int _aboutMaxLength = 900;

  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _llmQuestionController = TextEditingController();
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final LocalLlmProfileGuardApi _llmGuardApi = LocalLlmProfileGuardApi();
  bool _loading = true;
  bool _saving = false;
  bool _llmChecking = true;
  bool _llmOnline = false;
  String _llmStatusMessage =
      '\u041D\u0435\u0439\u0440\u043E\u0441\u0435\u0442\u044C: \u043F\u0440\u043E\u0432\u0435\u0440\u044F\u0435\u043C...';
  List<String> _validationErrors = const [];
  String? _aiNote;
  bool _llmAsking = false;
  String? _llmChatError;
  String _llmChatAnswer = '';

  @override
  void initState() {
    super.initState();
    _aboutController.addListener(_onAboutChanged);
    _checkLlmStatus();
    _loadProfile();
  }

  @override
  void dispose() {
    _aboutController.removeListener(_onAboutChanged);
    _aboutController.dispose();
    _llmQuestionController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onAboutChanged() {
    if (!mounted) return;
    if (_validationErrors.isNotEmpty) {
      _validationErrors = const [];
    }
    if (_aiNote != null) {
      _aiNote = null;
    }
    setState(() {});
  }

  Future<void> _loadProfile() async {
    final savedAbout = await UserSimplePreferences.getInspectorAbout();
    if (!mounted) return;
    _aboutController.text = savedAbout ?? '';
    setState(() => _loading = false);
  }

  Future<void> _checkLlmStatus() async {
    if (!mounted) return;
    setState(() {
      _llmChecking = true;
      _llmStatusMessage =
          '\u041D\u0435\u0439\u0440\u043E\u0441\u0435\u0442\u044C: \u043F\u0440\u043E\u0432\u0435\u0440\u044F\u0435\u043C...';
    });

    final status = await _llmGuardApi.checkServerStatus();
    if (!mounted) return;
    setState(() {
      _llmChecking = false;
      _llmOnline = status.online;
      _llmStatusMessage = status.message;
    });
  }

  Future<void> _askLlmQuestion() async {
    if (_llmAsking) return;
    final question = _llmQuestionController.text.trim();
    if (question.isEmpty) {
      setState(() {
        _llmChatError = 'Введите вопрос для нейросети.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _llmAsking = true;
      _llmChatError = null;
      _llmChatAnswer = '';
    });

    final response = await _llmGuardApi.askQuestion(question);
    if (!mounted) return;

    setState(() {
      _llmAsking = false;
      if (response.success) {
        _llmChatAnswer = response.answer ?? '';
        _llmChatError = null;
      } else {
        _llmChatAnswer = '';
        _llmChatError =
            response.error ?? 'Не удалось получить ответ от нейросети.';
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final about = _aboutController.text.trim();
    final validation = ContactRedaction.validateProfileText(about);
    if (validation.hasViolations) {
      if (mounted) {
        _tabController.animateTo(0);
      }
      setState(() {
        _saving = false;
        _validationErrors = validation.errors;
        _aiNote = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C '
            '\u0441\u043E\u0445\u0440\u0430\u043D\u0438\u0442\u044C '
            '\u043F\u0440\u043E\u0444\u0438\u043B\u044C: '
            '\u0443\u0431\u0435\u0440\u0438\u0442\u0435 '
            '\u043A\u043E\u043D\u0442\u0430\u043A\u0442\u043D\u044B\u0435 '
            '\u0434\u0430\u043D\u043D\u044B\u0435 \u0438\u0437 \u00AB\u041E '
            '\u0441\u0435\u0431\u0435\u00BB.',
          ),
          backgroundColor: kRedColor,
        ),
      );
      return;
    }

    final aiGuard = await _llmGuardApi.checkAboutText(about);
    if (!mounted) return;
    final llmMessage = aiGuard.checked
        ? '\u041D\u0435\u0439\u0440\u043E\u0441\u0435\u0442\u044C: \u043F\u043E\u0434\u043A\u043B\u044E\u0447\u0435\u043D\u0430'
        : (aiGuard.note ??
              '\u041D\u0435\u0439\u0440\u043E\u0441\u0435\u0442\u044C: \u043D\u0435\u0434\u043E\u0441\u0442\u0443\u043F\u043D\u0430');
    if (aiGuard.blocked) {
      final reasons = aiGuard.errors.isNotEmpty
          ? aiGuard.errors
          : const [
              '\u041D\u0435\u0439\u0440\u043E\u0441\u0435\u0442\u044C '
                  '\u043D\u0430\u0448\u043B\u0430 \u043F\u043E\u0434\u043E\u0437\u0440\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0435 '
                  '\u043A\u043E\u043D\u0442\u0430\u043A\u0442\u043D\u044B\u0435 '
                  '\u0434\u0430\u043D\u043D\u044B\u0435. \u041F\u0435\u0440\u0435\u043F\u0438\u0448\u0438\u0442\u0435 '
                  '\u043E\u043F\u0438\u0441\u0430\u043D\u0438\u0435 \u0431\u0435\u0437 \u043A\u043E\u043D\u0442\u0430\u043A\u0442\u043E\u0432.',
            ];
      if (mounted) {
        _tabController.animateTo(0);
      }
      setState(() {
        _saving = false;
        _validationErrors = reasons;
        _aiNote = null;
        _llmChecking = false;
        _llmOnline = aiGuard.checked;
        _llmStatusMessage = llmMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u041D\u0435\u0439\u0440\u043E\u0441\u0435\u0442\u044C '
            '\u043E\u0442\u043A\u043B\u043E\u043D\u0438\u043B\u0430 '
            '\u0442\u0435\u043A\u0441\u0442. \u0423\u0431\u0435\u0440\u0438\u0442\u0435 '
            '\u043A\u043E\u043D\u0442\u0430\u043A\u0442\u044B \u0438 '
            '\u043F\u043E\u043F\u0440\u043E\u0431\u0443\u0439\u0442\u0435 '
            '\u0441\u043D\u043E\u0432\u0430.',
          ),
          backgroundColor: kRedColor,
        ),
      );
      return;
    }

    await UserSimplePreferences.setInspectorAbout(about);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _validationErrors = const [];
      _aiNote = aiGuard.note;
      _llmChecking = false;
      _llmOnline = aiGuard.checked;
      _llmStatusMessage = llmMessage;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u041F\u0440\u043E\u0444\u0438\u043B\u044C \u0441\u043E\u0445\u0440\u0430\u043D\u0435\u043D',
        ),
        backgroundColor: kSecondaryColor,
      ),
    );
    if (aiGuard.note != null && aiGuard.note!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aiGuard.note!), backgroundColor: kYellowColor),
      );
    }
  }

  bool get _isProfileFilled => _aboutController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final publicText = ContactRedaction.redactPublicText(
      _aboutController.text.trim(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '\u041F\u0440\u043E\u0444\u0438\u043B\u044C \u0430\u0432\u0442\u043E\u043F\u043E\u0434\u0431\u043E\u0440\u0449\u0438\u043A\u0430',
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kSecondaryColor,
          indicatorWeight: 3,
          labelColor: kTertiaryColor,
          unselectedLabelColor: kGreyColor,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(
              text:
                  '\u0420\u0435\u0434\u0430\u043A\u0442\u0438\u0440\u043E\u0432\u0430\u043D\u0438\u0435',
            ),
            Tab(
              text:
                  '\u041A\u0430\u043A \u0432\u0438\u0434\u0438\u0442 \u043A\u043B\u0438\u0435\u043D\u0442',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _ProfileStatusBar(filled: _isProfileFilled),
          _LlmConnectionBar(
            checking: _llmChecking,
            online: _llmOnline,
            message: _llmStatusMessage,
            onRefresh: _checkLlmStatus,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EditAboutView(
                  aboutController: _aboutController,
                  llmQuestionController: _llmQuestionController,
                  maxLength: _aboutMaxLength,
                  validationErrors: _validationErrors,
                  aiNote: _aiNote,
                  llmAsking: _llmAsking,
                  llmChatError: _llmChatError,
                  llmChatAnswer: _llmChatAnswer,
                  onAskQuestion: _askLlmQuestion,
                ),
                _PublicPreviewView(
                  text: publicText.text,
                  hasRedactions: publicText.redacted,
                  onEdit: () => _tabController.animateTo(0),
                ),
              ],
            ),
          ),
          SafeArea(
            minimum: AppSizes.DEFAULT.copyWith(top: 4),
            child: MyButton(
              buttonText: _saving
                  ? '\u0421\u043E\u0445\u0440\u0430\u043D\u044F\u0435\u043C...'
                  : '\u0421\u043E\u0445\u0440\u0430\u043D\u0438\u0442\u044C \u043F\u0440\u043E\u0444\u0438\u043B\u044C',
              onTap: _saveProfile,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatusBar extends StatelessWidget {
  const _ProfileStatusBar({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final text = filled
        ? '\u041F\u0440\u043E\u0444\u0438\u043B\u044C \u0437\u0430\u043F\u043E\u043B\u043D\u0435\u043D'
        : '\u041F\u0440\u043E\u0444\u0438\u043B\u044C \u043D\u0435 \u0437\u0430\u043F\u043E\u043B\u043D\u0435\u043D';
    final color = filled ? kGreenColor : kRedColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: MyText(
          text: text,
          size: 12,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LlmConnectionBar extends StatelessWidget {
  const _LlmConnectionBar({
    required this.checking,
    required this.online,
    required this.message,
    required this.onRefresh,
  });

  final bool checking;
  final bool online;
  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = checking ? kYellowColor : (online ? kGreenColor : kRedColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: MyText(
                text: message,
                size: 11,
                weight: FontWeight.w600,
                color: color == kYellowColor ? kTertiaryColor : color,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: checking ? null : onRefresh,
              child: const Text(
                '\u041E\u0431\u043D\u043E\u0432\u0438\u0442\u044C',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditAboutView extends StatelessWidget {
  const _EditAboutView({
    required this.aboutController,
    required this.llmQuestionController,
    required this.maxLength,
    required this.validationErrors,
    required this.aiNote,
    required this.llmAsking,
    required this.llmChatError,
    required this.llmChatAnswer,
    required this.onAskQuestion,
  });

  final TextEditingController aboutController;
  final TextEditingController llmQuestionController;
  final int maxLength;
  final List<String> validationErrors;
  final String? aiNote;
  final bool llmAsking;
  final String? llmChatError;
  final String llmChatAnswer;
  final VoidCallback onAskQuestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: AppSizes.DEFAULT.copyWith(bottom: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MyText(
                text: '\u041E \u0441\u0435\u0431\u0435',
                size: 18,
                weight: FontWeight.w700,
                paddingBottom: 6,
              ),
              const MyText(
                text:
                    '\u0420\u0430\u0441\u0441\u043A\u0430\u0436\u0438\u0442\u0435 \u043E \u0441\u0432\u043E\u0435\u043C \u043E\u043F\u044B\u0442\u0435, \u043F\u043E\u0434\u0445\u043E\u0434\u0435 \u043A \u043F\u0440\u043E\u0432\u0435\u0440\u043A\u0435 \u0430\u0432\u0442\u043E \u0438 \u0441\u0438\u043B\u044C\u043D\u044B\u0445 \u0441\u0442\u043E\u0440\u043E\u043D\u0430\u0445.',
                size: 12,
                color: kGreyColor,
                lineHeight: 1.4,
                paddingBottom: 12,
              ),
              TextField(
                controller: aboutController,
                maxLines: 10,
                minLines: 7,
                maxLength: maxLength,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 13,
                  color: kTertiaryColor,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:
                      '\u041D\u0430\u043F\u0440\u0438\u043C\u0435\u0440: 8 \u043B\u0435\u0442 \u0432 \u043F\u043E\u0434\u0431\u043E\u0440\u0435, 500+ \u043F\u0440\u043E\u0432\u0435\u0440\u0435\u043D\u043D\u044B\u0445 \u0430\u0432\u0442\u043E, \u0440\u0430\u0431\u043E\u0442\u0430\u044E \u043F\u043E \u0434\u043E\u0433\u043E\u0432\u043E\u0440\u0443 \u0438 \u0434\u0430\u044E \u043F\u043E\u0434\u0440\u043E\u0431\u043D\u044B\u0439 \u043E\u0442\u0447\u0435\u0442.',
                  hintStyle: const TextStyle(fontSize: 12, color: kHintColor),
                  filled: true,
                  fillColor: kWhiteColor,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kSecondaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorderColor),
                ),
                child: const MyText(
                  text:
                      '\u041A\u043E\u043D\u0442\u0430\u043A\u0442\u044B '
                      '(\u0442\u0435\u043B\u0435\u0444\u043E\u043D, email, '
                      'Telegram/WhatsApp, @\u043D\u0438\u043A\u0438) '
                      '\u0432 \u0440\u0430\u0437\u0434\u0435\u043B\u0435 '
                      '\u00AB\u041E \u0441\u0435\u0431\u0435\u00BB \u0437\u0430\u043F\u0440\u0435\u0449\u0435\u043D\u044B. '
                      '\u041A\u043B\u0438\u0435\u043D\u0442 \u0443\u0432\u0438\u0434\u0438\u0442 '
                      '\u043A\u043E\u043D\u0442\u0430\u043A\u0442\u044B '
                      '\u0442\u043E\u043B\u044C\u043A\u043E \u043F\u043E\u0441\u043B\u0435 '
                      '\u0432\u044B\u0431\u043E\u0440\u0430 \u0438 \u043E\u043F\u043B\u0430\u0442\u044B.',
                  size: 11,
                  color: kGreyColor,
                  lineHeight: 1.4,
                ),
              ),
              if (validationErrors.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kRedColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: kRedColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text:
                            '\u041F\u0440\u043E\u0444\u0438\u043B\u044C '
                            '\u043D\u0435 \u0441\u043E\u0445\u0440\u0430\u043D\u0435\u043D:',
                        size: 12,
                        weight: FontWeight.w700,
                        color: kRedColor,
                        paddingBottom: 6,
                      ),
                      ...validationErrors.map(
                        (msg) => MyText(
                          text: '\u2022 $msg',
                          size: 11,
                          color: kRedColor,
                          lineHeight: 1.35,
                          paddingBottom: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (aiNote != null && aiNote!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kYellowColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: kYellowColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: MyText(
                    text: aiNote!,
                    size: 11,
                    color: kTertiaryColor,
                    lineHeight: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MyText(
                text: 'Вопрос к нейросети (тест)',
                size: 18,
                weight: FontWeight.w700,
                paddingBottom: 6,
              ),
              const MyText(
                text:
                    'Задайте вопрос модели и проверьте, что локальный сервер отвечает.',
                size: 12,
                color: kGreyColor,
                lineHeight: 1.4,
                paddingBottom: 12,
              ),
              TextField(
                controller: llmQuestionController,
                maxLines: 4,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  fontSize: 13,
                  color: kTertiaryColor,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Например: как лучше описать мой опыт без контактных данных?',
                  hintStyle: const TextStyle(fontSize: 12, color: kHintColor),
                  filled: true,
                  fillColor: kWhiteColor,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kSecondaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: llmAsking ? null : onAskQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,
                    foregroundColor: kWhiteColor,
                    disabledBackgroundColor: kGreyColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    llmAsking ? 'Отправляем...' : 'Спросить нейросеть',
                  ),
                ),
              ),
              if (llmChatError != null && llmChatError!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kRedColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: kRedColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: MyText(
                    text: llmChatError!,
                    size: 11,
                    color: kRedColor,
                    lineHeight: 1.35,
                  ),
                ),
              ],
              if (llmChatAnswer.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: 'Ответ модели:',
                        size: 12,
                        weight: FontWeight.w700,
                        color: kTertiaryColor,
                        paddingBottom: 6,
                      ),
                      MyText(
                        text: llmChatAnswer,
                        size: 12,
                        color: kGreyColor,
                        lineHeight: 1.45,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PublicPreviewView extends StatelessWidget {
  const _PublicPreviewView({
    required this.text,
    required this.hasRedactions,
    required this.onEdit,
  });

  final String text;
  final bool hasRedactions;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: AppSizes.DEFAULT.copyWith(bottom: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MyText(
                text:
                    '\u041A\u0430\u043A \u0432\u0438\u0434\u0438\u0442 \u043A\u043B\u0438\u0435\u043D\u0442',
                size: 18,
                weight: FontWeight.w700,
                paddingBottom: 10,
              ),
              if (text.isNotEmpty)
                MyText(text: text, size: 13, color: kGreyColor, lineHeight: 1.5)
              else
                const MyText(
                  text:
                      '\u0420\u0430\u0437\u0434\u0435\u043B \u043F\u043E\u043A\u0430 \u043D\u0435 \u0437\u0430\u043F\u043E\u043B\u043D\u0435\u043D. \u0414\u043E\u0431\u0430\u0432\u044C\u0442\u0435 \u0438\u043D\u0444\u043E\u0440\u043C\u0430\u0446\u0438\u044E \u0432 \u0440\u0435\u0436\u0438\u043C\u0435 \u0440\u0435\u0434\u0430\u043A\u0442\u0438\u0440\u043E\u0432\u0430\u043D\u0438\u044F.',
                  size: 13,
                  color: kGreyColor,
                  lineHeight: 1.5,
                ),
              if (hasRedactions) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: const MyText(
                    text:
                        '\u041A\u043E\u043D\u0442\u0430\u043A\u0442\u044B \u0432 \u0442\u0435\u043A\u0441\u0442\u0435 \u0441\u043A\u0440\u044B\u0432\u0430\u044E\u0442\u0441\u044F \u0434\u043E \u043E\u043F\u043B\u0430\u0442\u044B.',
                    size: 11,
                    color: kGreyColor,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              MyButton(buttonText: 'Редактировать профиль', onTap: onEdit),
            ],
          ),
        ),
      ],
    );
  }
}

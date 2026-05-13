import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';
import 'package:flutter_application_1/data/api/feedback_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart'
    show SessionExpiredException;
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'spark_joy_comment_utils.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// User-feedback form accessible from the Specialist/Company profile.
/// Captures `topic` (вопрос / помощь / предложение) + free-text message
/// (10..5000 chars), submits via `Feedback.SendFeedback`. The message
/// field has a voice dictation toggle (no AI rewrite — feedback should
/// land on the team verbatim).
class SparkJoyFeedbackScreen extends StatefulWidget {
  const SparkJoyFeedbackScreen({super.key});

  static const int minTextLength = 10;
  static const int maxTextLength = 5000;

  @override
  State<SparkJoyFeedbackScreen> createState() => _SparkJoyFeedbackScreenState();
}

class _SparkJoyFeedbackScreenState extends State<SparkJoyFeedbackScreen> {
  // Human-readable label → wire-enum value for the dropdown. Order
  // matters — это первое, что видит юзер при открытии селектора.
  static const Map<String, FeedbackTopic> _topicLabels = {
    'Вопрос': FeedbackTopic.question,
    'Помощь / что-то не работает': FeedbackTopic.help,
    'Предложение по улучшению': FeedbackTopic.proposal,
  };

  String _topicLabel = _topicLabels.keys.first;
  final TextEditingController _textController = TextEditingController();
  bool _submitting = false;

  // Voice dictation — speech_to_text is already in pubspec for the
  // Spark Joy inspection flow. Лазейка: NO AI, raw recognised text
  // appended into the message field via `appendRecognizedTranscript`.
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _speechInitializing = false;
  bool _isDictating = false;

  @override
  void dispose() {
    unawaited(_speech.stop());
    _textController.dispose();
    super.dispose();
  }

  Future<void> _ensureSpeech() async {
    if (_speechAvailable || _speechInitializing) return;
    _speechInitializing = true;
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isDictating = false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _isDictating = false);
        },
      );
      if (!_speechAvailable && mounted) {
        _showSnack('Надиктовка недоступна — проверьте доступ к микрофону.');
      }
    } catch (_) {
      _speechAvailable = false;
      if (mounted) _showSnack('Не удалось инициализировать распознавание речи.');
    } finally {
      _speechInitializing = false;
    }
  }

  Future<void> _toggleDictation() async {
    if (_isDictating) {
      await _stopDictation();
      return;
    }
    await _startDictation();
  }

  Future<void> _startDictation() async {
    await _ensureSpeech();
    if (!_speechAvailable || !mounted) return;
    try {
      await _speech.listen(
        localeId: 'ru_RU',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: false,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!result.finalResult) return;
          final next = SparkJoyCommentUtils.appendRecognizedTranscript(
            previous: _textController.text,
            transcript: result.recognizedWords,
          );
          if (next == _textController.text) return;
          _textController
            ..text = next
            ..selection = TextSelection.collapsed(offset: next.length);
          setState(() {});
        },
      );
      if (!mounted) return;
      setState(() => _isDictating = true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Не удалось запустить надиктовку.');
    }
  }

  Future<void> _stopDictation() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isDictating = false);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_isDictating) await _stopDictation();
    final text = _textController.text.trim();
    if (text.length < SparkJoyFeedbackScreen.minTextLength) {
      _showSnack(
        'Опишите подробнее — нужно минимум ${SparkJoyFeedbackScreen.minTextLength} символов.',
      );
      return;
    }
    if (text.length > SparkJoyFeedbackScreen.maxTextLength) {
      _showSnack(
        'Слишком длинно — лимит ${SparkJoyFeedbackScreen.maxTextLength} символов.',
      );
      return;
    }
    final topic = _topicLabels[_topicLabel] ?? FeedbackTopic.question;
    setState(() => _submitting = true);
    try {
      final result = await FeedbackApi.sendFeedback(
        topic: topic,
        message: text,
      );
      if (!mounted) return;
      if (result.accepted) {
        _showSnack(
          'Спасибо! Мы получим ваше обращение и ответим на почту, указанную в профиле.',
        );
        Navigator.of(context).pop();
        return;
      }
      _showSnack(
        result.errorMessage ??
            'Не удалось отправить обращение. Попробуйте ещё раз.',
      );
    } on SessionExpiredException {
      if (!mounted) return;
      _showSnack('Сессия истекла. Войдите снова и повторите.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Не удалось отправить: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final textLength = _textController.text.trim().length;
    final canSend = !_submitting &&
        textLength >= SparkJoyFeedbackScreen.minTextLength &&
        textLength <= SparkJoyFeedbackScreen.maxTextLength;

    return Scaffold(
      appBar: simpleAppBar(title: 'Обратная связь'),
      body: SparkScreenList(
        children: [
          const MyText(
            text: 'Тип обращения',
            size: SparkTextSize.title,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.md),
          _buildTopicDropdown(),
          const SizedBox(height: SparkSpace.xl),
          const MyText(
            text: 'Описание',
            size: SparkTextSize.title,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.md),
          SparkCard(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xl,
              SparkSpace.md,
              SparkSpace.xl,
              SparkSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textController,
                  minLines: 6,
                  maxLines: 14,
                  maxLength: SparkJoyFeedbackScreen.maxTextLength,
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: const InputDecoration(
                    hintText:
                        'Опишите проблему или предложение. Можно надиктовать голосом — нажмите кнопку «Голос» ниже.',
                    hintStyle: TextStyle(color: kGreyColor),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                  style: const TextStyle(fontSize: SparkTextSize.bodyLg),
                ),
                const SizedBox(height: SparkSpace.md),
                if (_isDictating) ...[
                  const MyText(
                    text: 'Идёт надиктовка...',
                    size: SparkTextSize.caption,
                    color: kRedColor,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: SparkSpace.sm),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => unawaited(_toggleDictation()),
                    borderRadius: BorderRadius.circular(SparkRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.lg,
                        vertical: SparkSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SparkRadius.pill),
                        border: Border.all(
                          color: _isDictating
                              ? kRedColor.withValues(alpha: 0.45)
                              : kBorderColor,
                        ),
                        color: _isDictating
                            ? kRedColor.withValues(alpha: 0.08)
                            : kInputBgColor,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isDictating
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            size: SparkTextSize.bodyLg,
                            color:
                                _isDictating ? kRedColor : kSecondaryColor,
                          ),
                          const SizedBox(width: SparkSpace.xs),
                          MyText(
                            text: _isDictating ? 'Стоп' : 'Голос',
                            size: SparkTextSize.chip,
                            weight: FontWeight.w700,
                            color:
                                _isDictating ? kRedColor : kTertiaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SparkSpace.sm),
          MyText(
            text: '$textLength / ${SparkJoyFeedbackScreen.maxTextLength} '
                'символов (минимум ${SparkJoyFeedbackScreen.minTextLength})',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
          const SizedBox(height: SparkSpace.section),
          IgnorePointer(
            ignoring: !canSend,
            child: Opacity(
              opacity: canSend ? 1 : 0.55,
              child: MyButton(
                buttonText: _submitting ? 'Отправляем...' : 'Отправить',
                onTap: () => unawaited(_submit()),
              ),
            ),
          ),
          const SizedBox(height: SparkSpace.lg),
          const MyText(
            text:
                'Имя, email и контакты подгрузим из вашего профиля — отдельно вводить не нужно.',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTopicDropdown() {
    return SparkCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.sm,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _topicLabel,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          style: const TextStyle(fontSize: SparkTextSize.bodyLg, color: kBlackColor),
          items: _topicLabels.keys
              .map(
                (label) => DropdownMenuItem<String>(
                  value: label,
                  child: MyText(
                    text: label,
                    size: SparkTextSize.bodyLg,
                    color: kBlackColor,
                  ),
                ),
              )
              .toList(),
          onChanged: (next) {
            if (next == null) return;
            setState(() => _topicLabel = next);
          },
        ),
      ),
    );
  }
}

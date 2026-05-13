import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_onboarding.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';

class SparkJoyCommentInputPanel extends StatefulWidget {
  const SparkJoyCommentInputPanel({
    super.key,
    required this.controller,
    required this.isDictating,
    required this.onToggleDictation,
    required this.onAiFormat,
    required this.onDismissKeyboard,
    this.hint = 'Добавьте комментарий',
    // Heights tuned twice: 7/10 → 9/13 → 12/16. Each Spark Joy step
    // has exactly one comment field as the primary input; users
    // write 5-15 lines on average for inspection notes / TD problems
    // / docs mismatches, and the previous 9-line panel forced
    // mid-text scroll for that volume. 12 lines visible by default
    // covers the common case without scroll, 16 caps growth so the
    // panel doesn't shove the «Готово» / «Продолжить» action bar
    // off the screen on iPhone SE class devices.
    this.minLines = 12,
    this.maxLines = 16,
    this.aiBusy = false,
    this.suppressOnboarding = false,
  });

  final TextEditingController controller;
  final bool isDictating;
  final VoidCallback onToggleDictation;
  final VoidCallback onAiFormat;
  final VoidCallback onDismissKeyboard;
  final String hint;
  final int minLines;
  final int maxLines;

  /// Если true — ИИ-кнопка показывает spinner и не реагирует на тап
  /// (запрос в полёте). Используется в inspection editor'е, где
  /// `onAiFormat` вызывает реальный сетевой запрос к AiQueue.
  final bool aiBusy;

  /// Если true — не запускать onboarding-шит про микрофон/ИИ. Нужно для
  /// экранов, у которых есть свой первичный онбординг (например, шаг
  /// «Итог»), чтобы юзеру не показывали два шита подряд.
  final bool suppressOnboarding;

  @override
  State<SparkJoyCommentInputPanel> createState() =>
      _SparkJoyCommentInputPanelState();
}

class _SparkJoyCommentInputPanelState extends State<SparkJoyCommentInputPanel> {
  @override
  void initState() {
    super.initState();
    if (widget.suppressOnboarding) return;
    // Onboarding sheet must be scheduled exactly once per mount — running
    // it from `build` schedules a post-frame callback on every rebuild,
    // and some of those callbacks fire after the BuildContext has been
    // deactivated (e.g. when the media editor's parent rebuilds while
    // opening the image picker), throwing
    // «Looking up a deactivated widget's ancestor is unsafe» and the
    // `_dependents.isEmpty` assertion on Flutter web.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SparkJoyOnboarding.showOnce(
        context,
        flagKey: UserSimplePreferences.sparkOnbCommentAiKey,
        titleI18nKey: 'spark.onboarding.commentAi.title',
        titleFallback: 'Голос и ИИ-помощник',
        bullets: const [
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.commentAi.b1',
            fallback:
                'Микрофон — надиктовка комментария голосом, удобно прямо во время осмотра.',
            icon: Icons.mic_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.commentAi.b2',
            fallback:
                'Кнопка «ИИ» переформулирует ваш черновик в аккуратный текст для отчёта.',
            icon: Icons.auto_awesome_rounded,
          ),
          SparkJoyOnboardingBullet(
            i18nKey: 'spark.onboarding.commentAi.b3',
            fallback:
                'Исходные слова всегда сохраняются — ИИ только улучшает формулировки.',
            icon: Icons.edit_note_rounded,
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SparkCard(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.xl,
        SparkSpace.lg,
        SparkSpace.xl,
        SparkSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            onTapOutside: (_) => widget.onDismissKeyboard(),
            style: const TextStyle(fontSize: SparkTextSize.label),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                fontSize: SparkTextSize.label,
                color: kGreyColor,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: SparkSpace.lg),
          if (widget.isDictating) ...[
            const MyText(
              text: 'Идёт надиктовка...',
              size: SparkTextSize.caption,
              color: kRedColor,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: SparkSpace.md,
              runSpacing: SparkSpace.md,
              children: [
                InkWell(
                  onTap: widget.onToggleDictation,
                  borderRadius: BorderRadius.circular(SparkRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.lg,
                      vertical: SparkSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SparkRadius.pill),
                      border: Border.all(
                        color: widget.isDictating
                            ? kRedColor.withValues(alpha: 0.45)
                            : kBorderColor,
                      ),
                      color: widget.isDictating
                          ? kRedColor.withValues(alpha: 0.08)
                          : kInputBgColor,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isDictating
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          size: SparkTextSize.bodyLg,
                          color: widget.isDictating
                              ? kRedColor
                              : kSecondaryColor,
                        ),
                        const SizedBox(width: SparkSpace.xs),
                        MyText(
                          text: widget.isDictating ? 'Стоп' : 'Голос',
                          size: SparkTextSize.chip,
                          weight: FontWeight.w700,
                          color: widget.isDictating
                              ? kRedColor
                              : kTertiaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.aiBusy ? null : widget.onAiFormat,
                  borderRadius: BorderRadius.circular(SparkRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.lg,
                      vertical: SparkSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SparkRadius.pill),
                      border: Border.all(
                        color: kSecondaryColor.withValues(alpha: 0.25),
                      ),
                      color: kSecondaryColor.withValues(alpha: 0.08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.aiBusy)
                          const SizedBox(
                            width: SparkTextSize.bodyLg,
                            height: SparkTextSize.bodyLg,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kSecondaryColor,
                            ),
                          )
                        else
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: SparkTextSize.bodyLg,
                            color: kSecondaryColor,
                          ),
                        const SizedBox(width: SparkSpace.xs),
                        MyText(
                          text: widget.aiBusy ? 'ИИ...' : 'ИИ',
                          size: SparkTextSize.chip,
                          weight: FontWeight.w700,
                          color: kSecondaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SparkJoyCommentAudioItemView {
  const SparkJoyCommentAudioItemView({
    required this.name,
    required this.isPlaying,
  });

  final String name;
  final bool isPlaying;
}

class SparkJoyCommentAudioBlock extends StatelessWidget {
  const SparkJoyCommentAudioBlock({
    super.key,
    required this.items,
    required this.isRecording,
    required this.recordingLabel,
    required this.onToggleRecording,
    required this.onTogglePlay,
    required this.onRemoveAt,
  });

  final List<SparkJoyCommentAudioItemView> items;
  final bool isRecording;
  final String recordingLabel;
  final Future<void> Function() onToggleRecording;
  final Future<void> Function(int index) onTogglePlay;
  final ValueChanged<int> onRemoveAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await onToggleRecording();
            },
            icon: Icon(
              isRecording
                  ? Icons.stop_circle_outlined
                  : Icons.graphic_eq_rounded,
              size: SparkSize.iconSm,
            ),
            label: Text(
              isRecording ? 'Стоп ($recordingLabel)' : 'Записать голосовое',
            ),
            style: OutlinedButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, SparkSize.actionHeightSm),
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          SparkCard(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.lg,
              SparkSpace.lg,
              SparkSpace.lg,
              SparkSpace.md,
            ),
            backgroundColor: kInputBgColor,
            child: Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : SparkSpace.sm,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.lg,
                      vertical: SparkSpace.md,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SparkRadius.md),
                      border: Border.all(color: kBorderColor),
                      color: kWhiteColor,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            await onTogglePlay(index);
                          },
                          borderRadius: BorderRadius.circular(SparkRadius.pill),
                          child: Padding(
                            padding: const EdgeInsets.all(SparkSpace.xxs),
                            child: Icon(
                              item.isPlaying
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              size: SparkSize.iconLg,
                              color: kSecondaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: SparkSpace.md),
                        Expanded(
                          child: MyText(
                            text: item.name.trim().isEmpty
                                ? 'Аудиозапись ${index + 1}'
                                : item.name,
                            size: SparkTextSize.caption,
                            maxLines: 1,
                            color: kTertiaryColor,
                          ),
                        ),
                        InkWell(
                          onTap: () => onRemoveAt(index),
                          borderRadius: BorderRadius.circular(SparkRadius.pill),
                          child: const Padding(
                            padding: EdgeInsets.all(SparkSpace.xxs),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: SparkSize.iconSm,
                              color: kGreyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

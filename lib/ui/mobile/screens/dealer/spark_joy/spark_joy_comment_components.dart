import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

class SparkJoyCommentInputPanel extends StatelessWidget {
  const SparkJoyCommentInputPanel({
    super.key,
    required this.controller,
    required this.isDictating,
    required this.onToggleDictation,
    required this.onAiFormat,
    required this.onDismissKeyboard,
    this.hint = 'Добавьте комментарий',
    this.minLines = 7,
    this.maxLines = 10,
  });

  final TextEditingController controller;
  final bool isDictating;
  final VoidCallback onToggleDictation;
  final VoidCallback onAiFormat;
  final VoidCallback onDismissKeyboard;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
        color: kWhiteColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            onTapOutside: (_) => onDismissKeyboard(),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: kGreyColor),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          if (isDictating) ...[
            const MyText(
              text: 'Идёт надиктовка...',
              size: 11,
              color: kRedColor,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: onToggleDictation,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDictating
                            ? kRedColor.withValues(alpha: 0.45)
                            : kBorderColor,
                      ),
                      color: isDictating
                          ? kRedColor.withValues(alpha: 0.08)
                          : kInputBgColor,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDictating ? Icons.mic_off_rounded : Icons.mic_rounded,
                          size: 13,
                          color: isDictating ? kRedColor : kSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        MyText(
                          text: isDictating ? 'Стоп' : 'Голос',
                          size: 9,
                          weight: FontWeight.w700,
                          color: isDictating ? kRedColor : kTertiaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: onAiFormat,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: kSecondaryColor.withValues(alpha: 0.25),
                      ),
                      color: kSecondaryColor.withValues(alpha: 0.08),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 13,
                          color: kSecondaryColor,
                        ),
                        SizedBox(width: 4),
                        MyText(
                          text: 'ИИ',
                          size: 9,
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
    required this.onAddAudio,
    required this.onTogglePlay,
    required this.onRemoveAt,
  });

  final List<SparkJoyCommentAudioItemView> items;
  final bool isRecording;
  final String recordingLabel;
  final Future<void> Function() onToggleRecording;
  final Future<void> Function() onAddAudio;
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
              isRecording ? Icons.stop_circle_outlined : Icons.graphic_eq_rounded,
              size: 16,
            ),
            label: Text(
              isRecording ? 'Стоп ($recordingLabel)' : 'Записать голосовое',
            ),
            style: OutlinedButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, 36),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await onAddAudio();
            },
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Приложить аудиофайл'),
            style: OutlinedButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, 36),
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderColor),
              color: kInputBgColor,
            ),
            child: Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorderColor),
                      color: kWhiteColor,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            await onTogglePlay(index);
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              item.isPlaying
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              size: 20,
                              color: kSecondaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MyText(
                            text: item.name.trim().isEmpty
                                ? 'Аудиозапись ${index + 1}'
                                : item.name,
                            size: 11,
                            maxLines: 1,
                            color: kTertiaryColor,
                          ),
                        ),
                        InkWell(
                          onTap: () => onRemoveAt(index),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
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

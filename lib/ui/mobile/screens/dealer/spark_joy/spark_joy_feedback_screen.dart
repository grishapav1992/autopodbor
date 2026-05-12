import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:image_picker/image_picker.dart';

import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// User-feedback form accessible from the Specialist/Company profile.
/// Captures: type («Проблема» / «Улучшение»), free text, up to 3
/// attachments. Submissions are appended to a local list in
/// SharedPreferences (`UserSimplePreferences.addFeedbackEntry`) —
/// TODO: replace with an RPC call once the backend exposes a feedback
/// endpoint.
class SparkJoyFeedbackScreen extends StatefulWidget {
  const SparkJoyFeedbackScreen({super.key});

  static const int maxAttachments = 3;
  static const int maxTextLength = 2000;

  @override
  State<SparkJoyFeedbackScreen> createState() => _SparkJoyFeedbackScreenState();
}

enum _FeedbackType { problem, improvement }

class _SparkJoyFeedbackScreenState extends State<SparkJoyFeedbackScreen> {
  _FeedbackType _type = _FeedbackType.problem;
  final TextEditingController _textController = TextEditingController();
  final List<XFile> _attachments = <XFile>[];
  final ImagePicker _picker = ImagePicker();
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_attachments.length >= SparkJoyFeedbackScreen.maxAttachments) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _attachments.add(picked));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось добавить изображение. Попробуйте ещё раз.'),
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) return;
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опишите проблему или предложение.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final role = await UserSimplePreferences.getUserRole();
    final entry = <String, dynamic>{
      'type': _type == _FeedbackType.problem ? 'problem' : 'improvement',
      'text': text,
      'imagePaths': _attachments.map((file) => file.path).toList(),
      'imageCount': _attachments.length,
      'submittedAt': DateTime.now().toIso8601String(),
      'role': role ?? '',
    };
    // TODO(backend): replace this local append with a `Storage.SubmitFeedback`
    // (or whatever the API surface ends up being) RPC call. Local storage
    // exists only to retain the user's submission until then.
    await UserSimplePreferences.addFeedbackEntry(entry);
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Спасибо! Мы прочитаем ваше сообщение и постараемся улучшить продукт.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _textController.text.trim().isNotEmpty && !_submitting;
    final canAddMore =
        _attachments.length < SparkJoyFeedbackScreen.maxAttachments;

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
          _buildTypeSelector(),
          const SizedBox(height: SparkSpace.xl),
          const MyText(
            text: 'Описание',
            size: SparkTextSize.title,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.md),
          SparkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xl,
              vertical: SparkSpace.md,
            ),
            child: TextField(
              controller: _textController,
              minLines: 6,
              maxLines: 14,
              maxLength: SparkJoyFeedbackScreen.maxTextLength,
              onChanged: (_) => setState(() {}),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                hintText:
                    'Опишите проблему или предложите, как улучшить функционал. '
                    'Чем подробнее — тем быстрее мы разберёмся.',
                hintStyle: TextStyle(color: kGreyColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
              ),
              style: const TextStyle(fontSize: SparkTextSize.bodyLg),
            ),
          ),
          const SizedBox(height: SparkSpace.xl),
          MyText(
            text:
                'Изображения · ${_attachments.length}/${SparkJoyFeedbackScreen.maxAttachments}',
            size: SparkTextSize.title,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.md),
          _buildAttachments(canAddMore: canAddMore),
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
                'Сообщения сохраняются на устройстве. После обновления — отправим в нашу команду.',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_FeedbackType>(
        segments: const [
          ButtonSegment<_FeedbackType>(
            value: _FeedbackType.problem,
            icon: Icon(Icons.bug_report_outlined),
            label: Text('Проблема'),
          ),
          ButtonSegment<_FeedbackType>(
            value: _FeedbackType.improvement,
            icon: Icon(Icons.lightbulb_outline),
            label: Text('Улучшение'),
          ),
        ],
        selected: {_type},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          if (selection.isEmpty) return;
          setState(() => _type = selection.first);
        },
      ),
    );
  }

  Widget _buildAttachments({required bool canAddMore}) {
    return Wrap(
      spacing: SparkSpace.md,
      runSpacing: SparkSpace.md,
      children: [
        for (var i = 0; i < _attachments.length; i++)
          _AttachmentThumb(
            file: _attachments[i],
            onRemove: () => _removeAttachment(i),
          ),
        if (canAddMore) _AddAttachmentTile(onTap: _pickAttachment),
      ],
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  Future<Uint8List> _readBytes() => file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.md),
          child: Container(
            width: SparkSize.mediaCardThumb,
            height: SparkSize.mediaCardThumb,
            color: kInputBgColor,
            child: kIsWeb
                ? FutureBuilder<Uint8List>(
                    future: _readBytes(),
                    builder: (ctx, snap) {
                      if (snap.hasData) {
                        return Image.memory(snap.data!, fit: BoxFit.cover);
                      }
                      return const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  )
                : Image.file(File(file.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(SparkRadius.pill),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: kBlackColor.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: SparkSize.iconSm,
                color: kWhiteColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddAttachmentTile extends StatelessWidget {
  const _AddAttachmentTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SparkRadius.md),
      child: Container(
        width: SparkSize.mediaCardThumb,
        height: SparkSize.mediaCardThumb,
        decoration: BoxDecoration(
          color: kInputBgColor,
          borderRadius: BorderRadius.circular(SparkRadius.md),
          border: Border.all(color: kBorderColor),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: SparkSize.iconLg,
              color: kGreyColor,
            ),
            SizedBox(height: SparkSpace.xs),
            MyText(
              text: 'Добавить',
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
          ],
        ),
      ),
    );
  }
}

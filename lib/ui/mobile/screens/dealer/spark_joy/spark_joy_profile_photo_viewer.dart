import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

/// Profile avatar that keeps the initials fallback, but opens a real photo.
class SparkJoyProfilePhotoAvatar extends StatelessWidget {
  const SparkJoyProfilePhotoAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.photoTitle,
    required this.semanticLabel,
    required this.size,
    required this.textSize,
    this.tapKey,
  });

  final String name;
  final String imageUrl;
  final String photoTitle;
  final String semanticLabel;
  final double size;
  final double textSize;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    final avatar = SparkInitialsAvatar(
      name: name,
      size: size,
      textSize: textSize,
      imageUrl: url.isEmpty ? null : url,
    );
    if (url.isEmpty) return avatar;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: 'Открыть фото',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: tapKey,
            customBorder: const CircleBorder(),
            onTap: () => openSparkJoyProfilePhoto(
              context,
              imageUrl: url,
              title: photoTitle,
            ),
            child: avatar,
          ),
        ),
      ),
    );
  }
}

/// Opens a public profile photo without cropping it to the avatar circle.
Future<void> openSparkJoyProfilePhoto(
  BuildContext context, {
  required String imageUrl,
  required String title,
}) async {
  final url = imageUrl.trim();
  if (url.isEmpty) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SparkJoyProfilePhotoScreen(imageUrl: url, title: title),
    ),
  );
}

class _SparkJoyProfilePhotoScreen extends StatelessWidget {
  const _SparkJoyProfilePhotoScreen({
    required this.imageUrl,
    required this.title,
  });

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlackColor,
      appBar: AppBar(
        backgroundColor: kBlackColor,
        foregroundColor: kWhiteColor,
        elevation: 0,
        title: Text(title),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(SparkSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 72,
                      color: kWhiteColor,
                    ),
                    SizedBox(height: SparkSpace.md),
                    MyText(
                      text: 'Не удалось загрузить фото',
                      size: SparkTextSize.body,
                      color: kWhiteColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

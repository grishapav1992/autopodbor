import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';

class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    required this.subTitle,
    this.marginTop,
    this.textAlign = TextAlign.left,
  });
  final String? title;
  final String? subTitle;
  final double? marginTop;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          paddingTop: marginTop ?? 0,
          text: title ?? '',
          size: 24,
          textAlign: textAlign,
          paddingBottom: 10,
          weight: FontWeight.w600,
        ),
        if (subTitle!.isNotEmpty)
          MyText(
            text: subTitle ?? '',
            size: 16,
            textAlign: textAlign,
            lineHeight: 1.5,
            paddingBottom: 30,
            weight: FontWeight.w500,
          ),
      ],
    );
  }
}

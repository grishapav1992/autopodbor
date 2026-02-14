import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

class PepConsent extends StatelessWidget {
  const PepConsent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: 'Согласие на ПЭП'),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.listPaddingWithBottomBar(),
        physics: const BouncingScrollPhysics(),
        children: const [
          MyText(
            text: 'Согласие на получение простой электронной подписи',
            size: 16,
            weight: FontWeight.w700,
            paddingBottom: 10,
          ),
          MyText(
            text:
                'Я подтверждаю, что ознакомлен(а) с условиями использования простой электронной подписи '
                'в сервисе и согласен(на) подписывать юридически значимые действия в электронном виде.',
            size: 12,
            color: kGreyColor,
            lineHeight: 1.5,
            paddingBottom: 10,
          ),
          MyText(
            text:
                'Настоящее согласие действует в рамках использования сервиса и может быть отозвано '
                'пользователем в порядке, предусмотренном пользовательским соглашением.',
            size: 12,
            color: kGreyColor,
            lineHeight: 1.5,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/utils/contact_redaction.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

class InspectorProfileScreen extends StatelessWidget {
  const InspectorProfileScreen({super.key, required this.offer, this.onChoose});

  final Map<String, dynamic> offer;
  final VoidCallback? onChoose;

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final photos =
        (offer['photos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [
          Assets.imagesDmImage,
          Assets.imagesDummyMap,
          Assets.imagesNoImageFound,
        ];
    final name = offer['name']?.toString() ?? 'Автоподборщик';
    final company = offer['company']?.toString() ?? '';
    final about = offer['about']?.toString() ?? '';
    final extra = offer['extra']?.toString() ?? '';
    final aboutPublic = ContactRedaction.redactPublicText(about);
    final extraPublic = ContactRedaction.redactPublicText(extra);
    final hasHiddenContacts = aboutPublic.redacted || extraPublic.redacted;
    final city = offer['city']?.toString() ?? '';
    final rating = offer['rating']?.toString() ?? '-';
    final reviews = offer['reviews']?.toString() ?? '0';
    final reports = offer['reports']?.toString() ?? '0';
    final success = offer['successDeals']?.toString() ?? '0';
    final experience = offer['experienceYears']?.toString() ?? '0';
    final memberSince = offer['memberSince']?.toString() ?? '';
    final responseHours = offer['responseHours']?.toString() ?? '';
    final price = offer['price'] as num?;
    final days = offer['days']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Профиль автоподборщика'),
      ),
      body: ListView(
        padding: AppSizes.listPaddingWithBottomBar(),
        children: [
          _PhotoCarousel(photos: photos),
          const SizedBox(height: 12),
          MyText(text: name, size: 18, weight: FontWeight.w700),
          if (company.isNotEmpty)
            MyText(text: company, size: 12, color: kGreyColor),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(label: 'Рейтинг', value: rating),
              const SizedBox(width: 8),
              _InfoChip(label: 'Отзывы', value: reviews),
              const SizedBox(width: 8),
              _InfoChip(label: 'Отчеты', value: reports),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Успешных сделок', value: success),
          _InfoRow(label: 'Опыт', value: '$experience лет'),
          if (memberSince.isNotEmpty)
            _InfoRow(label: 'На сервисе с', value: memberSince),
          if (city.isNotEmpty) _InfoRow(label: 'Город', value: city),
          if (responseHours.isNotEmpty)
            _InfoRow(label: 'Ответ', value: '$responseHours ч'),
          const SizedBox(height: 12),
          MyText(
            text: 'Описание',
            size: 14,
            weight: FontWeight.w700,
            paddingBottom: 6,
          ),
          if (about.isNotEmpty)
            MyText(text: aboutPublic.text, size: 12, color: kGreyColor)
          else
            MyText(text: 'Описание не заполнено', size: 12, color: kGreyColor),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 8),
            MyText(text: extraPublic.text, size: 12, color: kGreyColor),
          ],
          if (hasHiddenContacts) ...[
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
                    '\u041A\u043E\u043D\u0442\u0430\u043A\u0442\u044B '
                    '\u0430\u0432\u0442\u043E\u043F\u043E\u0434\u0431\u043E\u0440\u0449\u0438\u043A\u0430 '
                    '\u043E\u0442\u043A\u0440\u043E\u044E\u0442\u0441\u044F '
                    '\u043F\u043E\u0441\u043B\u0435 \u0432\u044B\u0431\u043E\u0440\u0430 '
                    '\u0438 \u043E\u043F\u043B\u0430\u0442\u044B.',
                size: 11,
                color: kGreyColor,
              ),
            ),
          ],
          const SizedBox(height: 16),
          MyText(
            text: 'Предложение',
            size: 14,
            weight: FontWeight.w700,
            paddingBottom: 6,
          ),
          if (price != null)
            MyText(
              text: 'Стоимость: ${_formatMoney(price)} руб.',
              size: 12,
              color: kGreyColor,
            ),
          if (days.isNotEmpty)
            MyText(text: 'Срок: $days дн.', size: 12, color: kGreyColor),
          if (onChoose != null) ...[
            const SizedBox(height: 12),
            MyButton(
              buttonText: 'Выбрать',
              onTap: () {
                onChoose?.call();
                Navigator.of(context).pop();
              },
              textSize: 12,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderColor),
            ),
            child: MyText(
              text:
                  'Совет: выбирайте автоподборщика с подтвержденной статистикой и быстрым откликом.',
              size: 11,
              color: kGreyColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: MyText(text: label, size: 12, color: kGreyColor),
          ),
          MyText(text: value, size: 12, weight: FontWeight.w600),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          MyText(text: label, size: 10, color: kGreyColor),
          const SizedBox(width: 4),
          MyText(text: value, size: 10, weight: FontWeight.w700),
        ],
      ),
    );
  }
}

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.photos});

  final List<String> photos;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.photos.isNotEmpty
        ? widget.photos
        : [Assets.imagesNoImageFound];

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) {
                final src = items[index];
                if (src.startsWith('http')) {
                  return Image.network(src, fit: BoxFit.cover);
                }
                return Image.asset(src, fit: BoxFit.cover);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 12 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? kSecondaryColor : kBorderColor,
                borderRadius: BorderRadius.circular(6),
              ),
            );
          }),
        ),
      ],
    );
  }
}

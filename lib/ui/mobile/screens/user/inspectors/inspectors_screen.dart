import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/auto_request/inspector_profile_screen.dart';

class InspectorsScreen extends StatelessWidget {
  const InspectorsScreen({super.key});

  List<Map<String, dynamic>> _inspectors() {
    return [
      {
        'name': 'SelectCar',
        'company': 'SelectCar Pro',
        'rating': 4.9,
        'reviews': 204,
        'reports': 520,
        'successDeals': 458,
        'experienceYears': 8,
        'memberSince': '2019',
        'city': 'Москва',
        'responseHours': 2,
        'price': 42000,
        'days': 5,
        'photos': [
          Assets.imagesDmImage,
          Assets.imagesDummyMap,
          Assets.imagesNoImageFound,
        ],
        'about':
            'Подбираю автомобили под ключ, специализация — немецкие и японские марки.',
        'extra': 'Работаю по договору, выезжаю на осмотры в день обращения.',
      },
      {
        'name': 'AutoExpert',
        'company': 'AutoExpert Team',
        'rating': 4.8,
        'reviews': 126,
        'reports': 312,
        'successDeals': 265,
        'experienceYears': 6,
        'memberSince': '2020',
        'city': 'Санкт-Петербург',
        'responseHours': 4,
        'price': 35000,
        'days': 7,
        'photos': [
          Assets.imagesDmImage,
          Assets.imagesEvents,
          Assets.imagesNoImageFound,
        ],
        'about': 'Полный цикл подбора: поиск, торг, юридическая проверка.',
        'extra': 'Сопровождаю сделку и помогаю с оформлением.',
      },
      {
        'name': 'CheckAuto',
        'company': 'CheckAuto Lab',
        'rating': 4.7,
        'reviews': 88,
        'reports': 190,
        'successDeals': 143,
        'experienceYears': 5,
        'memberSince': '2021',
        'city': 'Казань',
        'responseHours': 6,
        'price': 28000,
        'days': 10,
        'photos': [
          Assets.imagesDmImage,
          Assets.imagesDummyMap,
          Assets.imagesNoImageFound,
        ],
        'about':
            'Проверяю техническое состояние и историю, даю подробный отчет.',
        'extra': 'Можно заказать отдельные проверки, если нужно ускориться.',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = _inspectors();
    return ListView(
      padding: AppSizes.listPaddingWithBottomBar(),
      children: [
        MyText(text: 'Автоподборщики', size: 18, weight: FontWeight.w700),
        const SizedBox(height: 12),
        ...data.map(
          (item) => _InspectorCard(
            data: item,
            onProfile: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InspectorProfileScreen(offer: item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InspectorCard extends StatelessWidget {
  const _InspectorCard({required this.data, required this.onProfile});

  final Map<String, dynamic> data;
  final VoidCallback onProfile;

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
    final name = data['name']?.toString() ?? 'Автоподборщик';
    final company = data['company']?.toString() ?? '';
    final rating = data['rating']?.toString() ?? '-';
    final success = data['successDeals']?.toString() ?? '0';
    final reports = data['reports']?.toString() ?? '0';
    final reviews = data['reviews']?.toString() ?? '0';
    final experience = data['experienceYears']?.toString() ?? '0';
    final city = data['city']?.toString() ?? '';
    final responseHours = data['responseHours']?.toString() ?? '';
    final priceRaw = data['price'];
    final price = priceRaw is num
        ? _formatMoney(priceRaw)
        : (priceRaw?.toString() ?? '');
    final days = data['days']?.toString() ?? '';
    final photos =
        (data['photos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [Assets.imagesNoImageFound];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InspectorPhoto(photos: photos),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(text: name, size: 14, weight: FontWeight.w700),
                    if (company.isNotEmpty)
                      MyText(text: company, size: 11, color: kGreyColor),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: MyText(
                  text: 'Рейтинг $rating',
                  size: 10,
                  weight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 6,
            children: [
              MyText(text: 'Успешные сделки: $success', size: 11, color: kGreyColor),
              MyText(text: 'Отчетов: $reports', size: 11, color: kGreyColor),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 6,
            children: [
              MyText(text: 'Отзывы: $reviews', size: 11, color: kGreyColor),
              MyText(text: 'Опыт: $experience лет', size: 11, color: kGreyColor),
            ],
          ),
          if (city.isNotEmpty || responseHours.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 6,
              children: [
                if (city.isNotEmpty)
                  MyText(text: 'Город: $city', size: 11, color: kGreyColor),
                if (responseHours.isNotEmpty)
                  MyText(text: 'Ответ: $responseHours ч', size: 11, color: kGreyColor),
              ],
            ),
          ],
          if (price.isNotEmpty || days.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 6,
              children: [
                if (price.isNotEmpty)
                  MyText(text: 'Цена: $price руб.', size: 11, color: kGreyColor),
                if (days.isNotEmpty)
                  MyText(text: 'Срок: $days дн.', size: 11, color: kGreyColor),
              ],
            ),
          ],
          const SizedBox(height: 10),
          MyButton(buttonText: 'Профиль', onTap: onProfile, textSize: 12),
        ],
      ),
    );
  }
}

class _InspectorPhoto extends StatefulWidget {
  const _InspectorPhoto({required this.photos});

  final List<String> photos;

  @override
  State<_InspectorPhoto> createState() => _InspectorPhotoState();
}

class _InspectorPhotoState extends State<_InspectorPhoto> {
  int _index = 0;

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
            borderRadius: BorderRadius.circular(12),
            child: PageView.builder(
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
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 10 : 5,
              height: 5,
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

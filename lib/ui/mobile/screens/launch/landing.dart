import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_LandingSlide> _slides = const [
    _LandingSlide(
      title: 'Создайте заявку за 2–3 минуты',
      description:
          'Короткая форма с понятными шагами. Выбираете параметры авто — остальное поможем собрать.',
      image: Assets.imagesCar,
    ),
    _LandingSlide(
      title: 'Проверка и подбор под ключ',
      description:
          'Получайте предложения от автоподборщиков, сравнивайте условия и выбирайте исполнителя.',
      image: Assets.imagesCarDealer,
    ),
    _LandingSlide(
      title: 'Прозрачные статусы и отчёты',
      description:
          'Фиксируем этапы работы, результаты осмотров и рекомендации по покупке.',
      image: Assets.imagesCarPedia,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }
    Get.offAllNamed(AppLinks.chooseUserType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSizes.DEFAULT,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Image.asset(Assets.imagesLogo, height: 48)],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 220,
                          width: 220,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: kWhiteColor,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: kBorderColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: kGreyColor.withValues(alpha: 0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(slide.image),
                        ),
                        const SizedBox(height: 28),
                        MyText(
                          text: slide.title,
                          size: 20,
                          weight: FontWeight.w700,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        MyText(
                          text: slide.description,
                          size: 14,
                          color: kGreyColor,
                          textAlign: TextAlign.center,
                          lineHeight: 1.5,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: i == _index ? 22 : 6,
                    decoration: BoxDecoration(
                      color: i == _index ? kSecondaryColor : kBorderColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              MyButton(
                onTap: _next,
                buttonText: _index == _slides.length - 1 ? 'Начать' : 'Далее',
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Get.offAllNamed(AppLinks.chooseUserType),
                child: const Text(
                  'Пропустить',
                  style: TextStyle(
                    color: kGreyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingSlide {
  final String title;
  final String description;
  final String image;

  const _LandingSlide({
    required this.title,
    required this.description,
    required this.image,
  });
}

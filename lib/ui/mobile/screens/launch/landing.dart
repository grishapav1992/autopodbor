import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_fonts.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/config/routes/routes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Палитра онбординга (макет «Онбординг.dc.html»): основа — общие константы
// app_colors, ниже только оттенки, которых в общей палитре нет.
const _kBgTop = Color(0xffEEF3F8);
const _kHeroGradientTop = Color(0xff12314F);
const _kHeroGradientBottom = Color(0xff0B2138);
const _kShimmerHighlight = Color(0xffDBE6F5);

/// Ширина, под которую свёрстаны мини-экраны внутри hero-карточек.
/// FittedBox масштабирует иллюстрацию целиком, поэтому внутри неё
/// используются фиксированные размеры без адаптивных пересчётов.
const _kMockWidth = 314.0;

const _kSwipeDuration = Duration(milliseconds: 500);

/// Стиль текста внутри мини-экранов: без масштабирования MyText, чтобы
/// пропорции «иллюстрации» не расходились с макетом.
TextStyle _mockStyle(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = kTertiaryColor,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: AppFonts.URBANIST,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _checkingSession = true;

  final List<_LandingSlide> _slides = const [
    _LandingSlide(
      title: 'Отчёты быстрее с ИИ',
      description:
          'ИИ заполнит данные, разложит фото по разделам и подготовит итог.',
      hero: _HeroCard(child: _AiReportMock()),
    ),
    _LandingSlide(
      title: 'Управляйте командой',
      description:
          'Добавляйте сотрудников, назначайте заявки и контролируйте отчёты.',
      hero: _HeroCard(mirrored: true, child: _TeamMock()),
    ),
    _LandingSlide(
      title: 'Проверяйте авто по базам',
      description:
          'Данные ГИБДД, такси, залоги, лизинг и сертификация — прямо в отчёте.',
      hero: _HeroCard(child: _ChecksMock()),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final hasSession = await StorageApi.hasSavedSession();
    if (!mounted) return;
    if (hasSession) {
      await SparkJoyStorage.syncRoleFromServer();
      if (!mounted) return;
      Get.offAllNamed(AppLinks.dealerHome);
      return;
    }
    setState(() {
      _checkingSession = false;
    });
  }

  void _skip() => Get.offAllNamed(AppLinks.login);

  void _next() {
    if (_index < _slides.length - 1) {
      _controller.nextPage(
        duration: _kSwipeDuration,
        curve: Curves.fastOutSlowIn,
      );
      return;
    }
    Get.offAllNamed(AppLinks.login);
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: _kSwipeDuration,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, kPrimaryColor, kWhiteColor],
            stops: [0, 0.3, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _skip,
                    child: const MyText(
                      text: 'Пропустить',
                      size: 14,
                      weight: FontWeight.w500,
                      color: kGreyColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) =>
                      _LandingSlideView(slide: _slides[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (i) => _PageDot(
                          index: i,
                          active: i == _index,
                          onTap: () => _goTo(i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _CtaButton(
                      label: _index == _slides.length - 1 ? 'Начать' : 'Далее',
                      onTap: _next,
                    ),
                  ],
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
  final Widget hero;

  const _LandingSlide({
    required this.title,
    required this.description,
    required this.hero,
  });
}

class _LandingSlideView extends StatelessWidget {
  final _LandingSlide slide;

  const _LandingSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: AppSizes.HORIZONTAL,
              child: Column(
                children: [
                  const SizedBox(height: 2),
                  slide.hero,
                  _FadeUp(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 26, 6, 8),
                      child: Column(
                        children: [
                          MyText(
                            text: slide.title,
                            size: 24,
                            weight: FontWeight.w700,
                            color: kSecondaryColor,
                            letterSpacing: -0.3,
                            lineHeight: 1.25,
                            textAlign: TextAlign.center,
                          ),
                          MyText(
                            paddingTop: 12,
                            text: slide.description,
                            size: 15,
                            color: kGreyColor,
                            lineHeight: 1.55,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Тёмно-синяя витринная карточка слайда с «сиянием» по углам и
/// мини-экраном приложения внутри.
class _HeroCard extends StatelessWidget {
  final Widget child;

  /// Слайд «Штат» зеркалит подсветку углов относительно остальных.
  final bool mirrored;

  const _HeroCard({required this.child, this.mirrored = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 318,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment(-0.37, -0.93),
          end: Alignment(0.37, 0.93),
          colors: [_kHeroGradientTop, kSecondaryColor, _kHeroGradientBottom],
          stops: [0, 0.52, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: kSecondaryColor.withValues(alpha: 0.6),
            blurRadius: 46,
            offset: const Offset(0, 26),
            spreadRadius: -20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              top: -46,
              right: mirrored ? null : -34,
              left: mirrored ? -34 : null,
              child: _Glow(
                diameter: 190,
                color: kAccentGlow.withValues(alpha: 0.5),
              ),
            ),
            Positioned(
              bottom: -56,
              left: mirrored ? null : -46,
              right: mirrored ? -46 : null,
              child: _Glow(
                diameter: 210,
                color: kAccentColor.withValues(alpha: 0.24),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 24,
                ),
                // Мини-экран — иллюстрация: системное масштабирование текста
                // внутри неё отключено, на узких экранах сжимается целиком.
                child: MediaQuery.withNoTextScaling(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: _kMockWidth,
                      child: _RiseIn(child: child),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double diameter;
  final Color color;

  const _Glow({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  final int index;
  final bool active;
  final VoidCallback onTap;

  const _PageDot({
    required this.index,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Слайд ${index + 1}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: 7,
            width: active ? 24 : 7,
            decoration: BoxDecoration(
              color: active ? kAccentColor : kBorderColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CtaButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kAccentColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: kWhiteColor.withValues(alpha: 0.12),
          highlightColor: kWhiteColor.withValues(alpha: 0.08),
          child: Center(
            child: MyText(
              text: label,
              size: 16,
              weight: FontWeight.w700,
              color: kWhiteColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Мини-экраны внутри hero-карточек
// ---------------------------------------------------------------------------

/// Белая подложка мини-экрана.
class _MockCard extends StatelessWidget {
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _MockCard({
    required this.borderRadius,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: kBlackColor.withValues(alpha: 0.35),
            blurRadius: 38,
            offset: const Offset(0, 20),
            spreadRadius: -14,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MockPill extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const _MockPill({
    required this.text,
    required this.foreground,
    required this.background,
    required this.fontSize,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: _mockStyle(fontSize, weight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

/// Слайд 1 — «Материалы автомобиля»: ИИ-интейк с разделами отчёта.
class _AiReportMock extends StatelessWidget {
  const _AiReportMock();

  @override
  Widget build(BuildContext context) {
    return _MockCard(
      borderRadius: 16,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Материалы автомобиля',
                      style: _mockStyle(
                        14,
                        weight: FontWeight.w700,
                        color: kSecondaryColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ИИ распределит файлы по разделам отчёта',
                      style: _mockStyle(11, color: kGreyColor, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: kSurfaceTint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: kAccentColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ИИ',
                      style: _mockStyle(
                        11,
                        weight: FontWeight.w700,
                        color: kAccentColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _MockOutlineButton(
                  icon: Icons.photo_camera_outlined,
                  label: 'Фото и видео',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MockOutlineButton(
                  icon: Icons.description_outlined,
                  label: 'Документы',
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const _MockSectionRow(label: 'Автомобиль'),
          const _MockSectionRow(label: 'Осмотр'),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 9, 0, 2),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kAccentColor,
                    backgroundColor: kSurfaceTint,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'Итог осмотра',
                  style: _mockStyle(
                    12,
                    weight: FontWeight.w500,
                    color: kGreyColor,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(child: _ShimmerBar()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MockOutlineButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: kBorderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: kSecondaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: _mockStyle(
              11,
              weight: FontWeight.w600,
              color: kSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockSectionRow extends StatelessWidget {
  final String label;

  const _MockSectionRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kGreyColor2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: _mockStyle(12, weight: FontWeight.w500),
          ),
          _MockPill(
            text: 'Заполнено',
            foreground: kGreenColor,
            background: kGreenColor.withValues(alpha: 0.12),
            fontSize: 10.5,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          ),
        ],
      ),
    );
  }
}

/// Слайд 2 — «Штат»: поиск, сотрудники и приглашение по телефону.
class _TeamMock extends StatelessWidget {
  const _TeamMock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MockCard(
          borderRadius: 16,
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kLightGreyColor,
                  border: Border.all(color: kGreyColor2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 14, color: kGreyColor),
                    const SizedBox(width: 7),
                    Text(
                      'Поиск по имени, телефону или городу',
                      style: _mockStyle(10.5, color: kGreyColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const _MockStaffRow(
                initials: 'АК',
                name: 'Артём Ковалёв',
                subtitle: 'Автоэксперт · Москва',
              ),
              const _MockStaffRow(
                initials: 'МС',
                name: 'Мария Соколова',
                subtitle: 'Диагностика · Казань',
              ),
              const _MockStaffRow(
                initials: 'ДВ',
                name: 'Дмитрий Волков',
                subtitle: 'Осмотр · Санкт-Петербург',
                divider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FloatY(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: kWhiteColor.withValues(alpha: 0.14),
              border: Border.all(color: kWhiteColor.withValues(alpha: 0.22)),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: kWhiteColor),
                const SizedBox(width: 8),
                Text(
                  'Пригласить по телефону',
                  style: _mockStyle(
                    12,
                    weight: FontWeight.w600,
                    color: kWhiteColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MockStaffRow extends StatelessWidget {
  final String initials;
  final String name;
  final String subtitle;
  final bool divider;

  const _MockStaffRow({
    required this.initials,
    required this.name,
    required this.subtitle,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: kGreyColor2))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kSecondaryColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: _mockStyle(
                11,
                weight: FontWeight.w700,
                color: kWhiteColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mockStyle(12.5, weight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mockStyle(10.5, color: kGreyColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MockPill(
            text: 'В штате',
            foreground: kSecondaryColor,
            background: kSecondaryColor.withValues(alpha: 0.08),
            fontSize: 10,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: kGreyColor),
        ],
      ),
    );
  }
}

/// Слайд 3 — «Материалы проверки»: VIN, госномер и проверки по базам.
class _ChecksMock extends StatelessWidget {
  const _ChecksMock();

  @override
  Widget build(BuildContext context) {
    return _MockCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: kLightGreyColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 15, color: kGreyColor),
                      const SizedBox(width: 7),
                      Text(
                        'XW8ZZZ…4021',
                        style: _mockStyle(
                          12,
                          weight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const _MockPlate(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 16,
                color: kSecondaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Материалы проверки',
                style: _mockStyle(
                  12.5,
                  weight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _MockCheckRow(
            label: 'Залог (реестр нотариусов)',
            status: 'не найдено',
            statusColor: kGreenColor,
          ),
          const _MockCheckRow(
            label: 'Лизинг (Федресурс)',
            status: 'не найдено',
            statusColor: kGreenColor,
          ),
          const _MockCheckRow(
            label: 'Работа в такси',
            status: 'не найдено',
            statusColor: kGreenColor,
          ),
          const _MockCheckRow(
            label: 'Сертификат ГОСТ',
            status: 'выполнено',
            statusColor: kSecondaryColor,
            divider: false,
          ),
        ],
      ),
    );
  }
}

class _MockPlate extends StatelessWidget {
  const _MockPlate();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhiteColor,
        border: Border.all(color: kTertiaryColor, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 6, 5),
              child: Text(
                'А123ВС',
                style: _mockStyle(
                  13,
                  weight: FontWeight.w700,
                  color: kQuaternaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: kTertiaryColor, width: 1.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '77',
                    style: _mockStyle(
                      11,
                      weight: FontWeight.w700,
                      color: kQuaternaryColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    'RUS',
                    style: _mockStyle(
                      5,
                      color: kQuaternaryColor,
                      letterSpacing: 0.3,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockCheckRow extends StatelessWidget {
  final String label;
  final String status;
  final Color statusColor;
  final bool divider;

  const _MockCheckRow({
    required this.label,
    required this.status,
    required this.statusColor,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: kGreyColor2))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mockStyle(11.5, color: kGreyColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: _mockStyle(
              11.5,
              weight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Анимации макета
// ---------------------------------------------------------------------------

/// Появление мини-экрана: подъём с лёгким масштабом (obRise из макета).
class _RiseIn extends StatelessWidget {
  final Widget child;

  const _RiseIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: const Cubic(0.2, 0.7, 0.3, 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Transform.scale(scale: 0.96 + 0.04 * value, child: child),
        ),
      ),
      child: child,
    );
  }
}

/// Появление заголовка и описания слайда (obFade из макета).
class _FadeUp extends StatelessWidget {
  final Widget child;

  const _FadeUp({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Плавное «парение» приглашения (obFloat из макета).
class _FloatY extends StatefulWidget {
  final Widget child;

  const _FloatY({required this.child});

  @override
  State<_FloatY> createState() => _FloatYState();
}

class _FloatYState extends State<_FloatY>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Полупериод: repeat(reverse) даёт полный цикл 3.4с, как в макете.
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -7 * _animation.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Бегущий блик на полосе прогресса «Итог осмотра» (obShimmer из макета).
class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar();

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: const [kGreyColor2, _kShimmerHighlight, kGreyColor2],
            ),
          ),
        );
      },
    );
  }
}

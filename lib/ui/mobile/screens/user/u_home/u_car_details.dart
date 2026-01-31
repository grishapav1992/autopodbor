import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_home/all_features.dart';
import 'package:flutter_application_1/ui/mobile/screens/user/u_home/u_showroom_details/u_showroom_details.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class UCarDetails extends StatelessWidget {
  UCarDetails({super.key});
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        physics: BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildAppBar()];
        },
        body: ListView(
          shrinkWrap: true,
          padding: AppSizes.listPaddingWithBottomBar(),
          physics: BouncingScrollPhysics(),
          children: [
            Row(
              children: [
                MyText(text: 'БМВ Х4', size: 24, weight: FontWeight.w700),
                MyText(text: ' (2018)', size: 16, weight: FontWeight.w700),
              ],
            ),
            MyText(
              paddingTop: 8,
              paddingBottom: 8,
              text: '2.0 xDrive 220d Спорт',
              size: 16,
              weight: FontWeight.w600,
            ),
            MyText(
              text: '₽ 899',
              size: 22,
              color: kSecondaryColor,
              weight: FontWeight.w700,
            ),
            _Divider(),
            Row(
              children: [
                Image.asset(Assets.imagesSpm, height: 20),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MyText(
                        text: '77 000 км',
                        size: 16,
                        weight: FontWeight.w600,
                        paddingBottom: 4,
                      ),
                      MyText(
                        text: 'На 2122 км ниже среднего',
                        color: kHintColor,
                        weight: FontWeight.w500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(Assets.imagesCylinder, width: 24),
                      MyText(
                        paddingLeft: 10,
                        paddingRight: 10,
                        text: '4 цилиндра',
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(Assets.imagesTank, width: 24),
                      MyText(
                        paddingLeft: 10,
                        paddingRight: 10,
                        text: '2.0 л — 2.1 л',
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(Assets.imagesManual, width: 24),
                      MyText(
                        paddingLeft: 10,
                        paddingRight: 10,
                        text: 'Механика',
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(Assets.imagesDl, width: 24),
                      MyText(
                        paddingLeft: 10,
                        paddingRight: 10,
                        text: 'Дизель',
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(Assets.imagesDoor, width: 24),
                      MyText(
                        paddingLeft: 10,
                        paddingRight: 10,
                        text: '4 двери',
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(Assets.imagesSpc, width: 24),
                      MyText(
                        paddingLeft: 10,
                        paddingRight: 10,
                        text: 'Характеристики, США',
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Divider(),
            Row(
              children: [
                Expanded(
                  child: MyText(text: "interior".tr, weight: FontWeight.w600),
                ),
                MyText(
                  text: 'Кожа',
                  color: kHintColor,
                  weight: FontWeight.w500,
                ),
              ],
            ),
            _Divider(marginV: 8),
            Row(
              children: [
                Expanded(
                  child: MyText(
                    text: "numberOfSeats".tr,
                    weight: FontWeight.w600,
                  ),
                ),
                MyText(
                  text: '6 мест',
                  color: kHintColor,
                  weight: FontWeight.w500,
                ),
              ],
            ),
            _Divider(marginV: 8),
            Row(
              children: [
                Expanded(
                  child: MyText(text: "damage".tr, weight: FontWeight.w600),
                ),
                MyText(
                  text: 'Окрашено',
                  color: kHintColor,
                  weight: FontWeight.w500,
                ),
              ],
            ),
            _Divider(marginV: 8),
            Row(
              children: [
                Expanded(
                  child: MyText(
                    text: "plateRegistration".tr,
                    weight: FontWeight.w600,
                  ),
                ),
                MyText(
                  text: 'Багдад',
                  color: kHintColor,
                  weight: FontWeight.w500,
                ),
              ],
            ),
            _Divider(marginV: 8),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MyText(
                    text: 'Опции',
                    size: 16,
                    weight: FontWeight.w600,
                  ),
                ),
                MyText(
                  onTap: () => Get.to(() => AllFeatures()),
                  text: "seeMore".tr,
                  size: 12,
                  weight: FontWeight.w600,
                  color: kSecondaryColor,
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(4, (index) {
                final List<String> items = [
                  "airConditioning".tr,
                  "alarm".tr,
                  "audioRemoteControl".tr,
                  "digitalRadio".tr,
                ];
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(width: 1.0, color: kBorderColor),
                  ),
                  child: MyText(text: items[index], size: 12),
                );
              }),
            ),
            MyText(
              paddingTop: 16,
              text: "description".tr,
              size: 16,
              weight: FontWeight.w600,
              paddingBottom: 8,
            ),
            MyText(
              text:
                  "loremIpsumDolorSitAmetConsecteturAdipiscingElitSedDoEiusmodTemporIncididuntUtLaboreEtDoloreMagnaAliq"
                      .tr,
              size: 14,
              lineHeight: 1.4,
              color: kHintColor,
              paddingBottom: 16,
            ),
            MyText(
              text: "contactSeller".tr,
              size: 16,
              weight: FontWeight.w600,
              paddingBottom: 8,
            ),
            GestureDetector(
              onTap: () => Get.to(() => UShowroomDetails()),
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kWhiteColor,
                  border: Border.all(width: 1.0, color: kBorderColor),
                ),
                child: Row(
                  children: [
                    CommonImageView(
                      height: 45,
                      width: 45,
                      radius: 8,
                      url: dummyImg,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              MyText(
                                text: 'Автопедия',
                                size: 17,
                                weight: FontWeight.w600,
                                paddingRight: 6,
                              ),
                              Image.asset(
                                Assets.imagesVerified,
                                height: 20,
                                color: kSecondaryColor,
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Image.asset(
                                Assets.imagesLocation,
                                color: kRedColor,
                                height: 14,
                              ),
                              MyText(
                                paddingLeft: 4,
                                text: 'Багдад',
                                size: 12,
                                color: kHintColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Image.asset(Assets.imagesWhatsapp, height: 38),
                    SizedBox(width: 6),
                    Image.asset(Assets.imagesCall, height: 38),
                  ],
                ),
              ),
            ),
            MyText(
              paddingTop: 16,
              text: "similarCars".tr,
              size: 16,
              weight: FontWeight.w600,
              paddingBottom: 8,
            ),
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: 4,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 230,
              ),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: kWhiteColor,
                    border: Border.all(width: 1.0, color: kBorderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: CommonImageView(
                                height: Get.height,
                                width: Get.width,
                                radius: 0,
                                url: dummyImg,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                height: 24,
                                width: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kWhiteColor.withValues(alpha: 0.5),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    Assets.imagesFavorite,
                                    height: 14,
                                    color: kRedColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MyText(
                              text: 'Тойота Супра 1990',
                              size: 12,
                              weight: FontWeight.w600,
                              paddingBottom: 8,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: MyText(
                                    text: "mileage".tr,
                                    size: 10,
                                    color: kHintColor,
                                  ),
                                ),
                                MyText(
                                  text: '77 000 км',
                                  size: 10,
                                  weight: FontWeight.w600,
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: MyText(
                                    text: "engine".tr,
                                    size: 10,
                                    color: kHintColor,
                                  ),
                                ),
                                MyText(
                                  text: '2.0 л — 2.5 л',
                                  size: 10,
                                  weight: FontWeight.w600,
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: MyText(
                                    text: "type".tr,
                                    size: 10,
                                    color: kHintColor,
                                  ),
                                ),
                                MyText(
                                  text: 'Бензин',
                                  size: 10,
                                  weight: FontWeight.w600,
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: MyText(
                                    text: "gearBox".tr,
                                    size: 10,
                                    color: kHintColor,
                                  ),
                                ),
                                MyText(
                                  text: 'Автомат',
                                  size: 10,
                                  weight: FontWeight.w600,
                                ),
                              ],
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 6),
                              height: 1,
                              color: kBorderColor,
                            ),
                            MyText(
                              text: '₽ 899',
                              size: 16,
                              weight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      centerTitle: true,
      expandedHeight: 300,
      title: MyText(
        text: "details".tr,
        size: 18,
        weight: FontWeight.w600,
        color: kWhiteColor,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          clipBehavior: Clip.none,
          children: [
            PageView.builder(
              itemCount: 3,
              controller: _controller,
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return CommonImageView(
                  url: dummyImg,
                  height: Get.height,
                  width: Get.width,
                  radius: 0,
                );
              },
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: ExpandingDotsEffect(
                  dotHeight: 7,
                  dotWidth: 7,
                  activeDotColor: kSecondaryColor,
                  dotColor: kWhiteColor,
                  expansionFactor: 5,
                  spacing: 4,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Center(
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(width: 1.0, color: kBorderColor),
              color: kWhiteColor,
            ),
            child: Center(
              child: Image.asset(
                Assets.imagesHeart,
                height: 20,
                color: kRedColor,
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Center(
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(width: 1.0, color: kBorderColor),
              color: kWhiteColor,
            ),
            child: Center(child: Image.asset(Assets.imagesShare, height: 20)),
          ),
        ),
        SizedBox(width: 20),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({this.marginV = 16});
  final double? marginV;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: marginV!),
      height: 1,
      color: kBorderColor,
    );
  }
}

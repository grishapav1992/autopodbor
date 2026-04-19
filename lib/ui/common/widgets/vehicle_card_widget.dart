import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/design_tokens.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class VehicleCard extends StatelessWidget {
  final PageController _controller = PageController();
  final bool? isFavorite;

  VehicleCard({super.key, this.isFavorite = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SparkSpace.xl),
      margin: EdgeInsets.only(bottom: SparkSpace.xl),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(SparkRadius.md),
        border: Border.all(width: 1, color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(SparkRadius.sm),
                child: SizedBox(
                  height: 204,
                  child: PageView.builder(
                    itemCount: 3,
                    controller: _controller,
                    physics: BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return CommonImageView(
                        url: dummyImg,
                        height: 204,
                        width: Get.width,
                        radius: 0,
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: -SparkSize.iconLg,
                right: SparkSpace.xxxl,
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 1.0, color: kBorderColor),
                    color: kWhiteColor,
                  ),
                  child: Center(
                    child: Image.asset(
                      isFavorite! ? Assets.imagesFavorite : Assets.imagesHeart,
                      height: SparkSize.iconXl,
                      color: kRedColor,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: SparkSpace.xxxl,
                left: SparkSpace.xxxl,
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: ExpandingDotsEffect(
                    dotHeight: 5,
                    dotWidth: 5,
                    activeDotColor: kSecondaryColor,
                    dotColor: kWhiteColor,
                    expansionFactor: 5,
                    spacing: SparkSpace.xs,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 27),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SparkSpace.md,
            runSpacing: SparkSpace.sm,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: MyText(
                  text: 'Автосалон «Автоцентр»',
                  size: SparkTextSize.body,
                  color: kHintColor,
                  weight: FontWeight.w500,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(Assets.imagesLocation, height: SparkSize.iconSm),
                  MyText(
                    paddingLeft: SparkSpace.xs,
                    text: '3 256 км',
                    size: SparkTextSize.body,
                    color: kHintColor,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(Assets.imagesReviews, height: SparkSize.iconSm),
                  MyText(
                    paddingLeft: SparkSpace.xs,
                    text: '12[4]',
                    size: SparkTextSize.body,
                    color: kHintColor,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: SparkSpace.lg),
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: 'Тойота Камри',
                  size: SparkTextSize.pageTitle,
                  weight: FontWeight.w800,
                  lineHeight: 1.30,
                  tracking: true,
                ),
              ),
              MyText(
                text: '₽ 899',
                size: SparkTextSize.pageTitle,
                color: kSecondaryColor,
                weight: FontWeight.w800,
                lineHeight: 1.30,
                tracking: true,
                tabularFigures: true,
              ),
            ],
          ),
          MyText(
            paddingTop: SparkSpace.xl,
            text: '2023 (Тойота Камри....₽123/мес.) ',
            size: SparkTextSize.body,
            color: kHintColor,
            weight: FontWeight.w500,
            paddingBottom: SparkSpace.xl,
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset(Assets.imagesMiles, height: SparkSize.iconLg),
                    MyText(
                      text: '32 518 км',
                      paddingLeft: 9,
                      size: SparkTextSize.body,
                      color: kHintColor,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Image.asset(Assets.imagesSpeed, height: SparkSize.iconLg),
                    MyText(
                      text: 'Комплектация С',
                      paddingLeft: 9,
                      size: SparkTextSize.body,
                      color: kHintColor,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: SparkSpace.md),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset(Assets.imagesDiesel, height: SparkSize.iconLg),
                    MyText(
                      text: 'Дизель',
                      paddingLeft: 9,
                      size: SparkTextSize.body,
                      color: kHintColor,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Image.asset(
                      Assets.imagesTransmission,
                      height: SparkSize.iconLg,
                    ),
                    MyText(
                      text: 'Автомат',
                      paddingLeft: 9,
                      size: SparkTextSize.body,
                      color: kHintColor,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


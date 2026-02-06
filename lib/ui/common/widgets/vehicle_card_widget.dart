import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
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
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(width: 1, color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                bottom: -20,
                right: 16,
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
                      height: 24,
                      color: kRedColor,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: ExpandingDotsEffect(
                    dotHeight: 5,
                    dotWidth: 5,
                    activeDotColor: kSecondaryColor,
                    dotColor: kWhiteColor,
                    expansionFactor: 5,
                    spacing: 4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 27),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: MyText(
                  text: 'Автосалон «Автоцентр»',
                  size: 12,
                  color: kHintColor,
                  weight: FontWeight.w500,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(Assets.imagesLocation, height: 16),
                  MyText(
                    paddingLeft: 4,
                    text: '3 256 км',
                    size: 12,
                    color: kHintColor,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(Assets.imagesReviews, height: 16),
                  MyText(
                    paddingLeft: 4,
                    text: '12[4]',
                    size: 12,
                    color: kHintColor,
                    weight: FontWeight.w500,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: 'Тойота Камри',
                  size: 22,
                  weight: FontWeight.w700,
                ),
              ),
              MyText(
                text: '₽ 899',
                size: 22,
                color: kSecondaryColor,
                weight: FontWeight.w700,
              ),
            ],
          ),
          MyText(
            paddingTop: 12,
            text: '2023 (Тойота Камри....₽123/мес.) ',
            size: 12,
            color: kHintColor,
            weight: FontWeight.w500,
            paddingBottom: 12,
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset(Assets.imagesMiles, height: 20),
                    MyText(
                      text: '32 518 км',
                      paddingLeft: 9,
                      size: 12,
                      color: kHintColor,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Image.asset(Assets.imagesSpeed, height: 20),
                    MyText(
                      text: 'Комплектация С',
                      paddingLeft: 9,
                      size: 12,
                      color: kHintColor,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset(Assets.imagesDiesel, height: 20),
                    MyText(
                      text: 'Дизель',
                      paddingLeft: 9,
                      size: 12,
                      color: kHintColor,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Image.asset(Assets.imagesTransmission, height: 20),
                    MyText(
                      text: 'Автомат',
                      paddingLeft: 9,
                      size: 12,
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


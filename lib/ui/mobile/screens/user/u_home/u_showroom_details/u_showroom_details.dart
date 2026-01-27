import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_fonts.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/app/main.dart';
import 'package:flutter_application_1/ui/common/widgets/common_image_view_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UShowroomDetails extends StatefulWidget {
  const UShowroomDetails({super.key});

  @override
  State<UShowroomDetails> createState() => _UShowroomDetailsState();
}

class _UShowroomDetailsState extends State<UShowroomDetails> {
  int _currentTab = 0;

  void _onSelect(int index) {
    setState(() {
      _currentTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> items = ["details".tr, "cars".tr];
    return Scaffold(
      appBar: simpleAppBar(title: "showroomDetails".tr),
      body: DefaultTabController(
        length: items.length,
        initialIndex: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: BouncingScrollPhysics(),
                children: [
                  CommonImageView(
                    height: 195,
                    width: Get.width,
                    url: dummyImg,
                    radius: 0,
                  ),
                  Padding(
                    padding: AppSizes.DEFAULT,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Image.asset(Assets.imagesTime, height: 24),
                            MyText(
                              paddingLeft: 6,
                              text: "closed".tr,
                              size: 12,
                              weight: FontWeight.w600,
                              color: kSecondaryColor,
                            ),
                            MyText(
                              text: ' - РћС‚РєСЂС‹РІР°РµС‚СЃСЏ РІ 13:00 ',
                              size: 12,
                              color: kHintColor,
                              weight: FontWeight.w600,
                            ),
                          ],
                        ),
                        _Divider(),
                        Row(
                          children: [
                            Image.asset(Assets.imagesCarPedia, height: 24),
                            MyText(
                              paddingLeft: 6,
                              text: 'Автопедия',
                              size: 12,
                              weight: FontWeight.w600,
                              color: kHintColor,
                            ),
                          ],
                        ),
                        _Divider(),
                        Row(
                          children: [
                            Image.asset(
                              Assets.imagesLocation,
                              height: 24,
                              color: kSecondaryColor,
                            ),
                            MyText(
                              paddingLeft: 6,
                              text: 'СѓР». РҐСЌРјРїС‚РѕРЅ, 634',
                              size: 12,
                              weight: FontWeight.w600,
                              color: kHintColor,
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          color: kWhiteColor,
                          child: TabBar(
                            onTap: (index) => _onSelect(index),
                            labelColor: kSecondaryColor,
                            unselectedLabelColor: kQuaternaryColor,
                            indicatorColor: kSecondaryColor,
                            indicatorWeight: 2,
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppFonts.URBANIST,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: AppFonts.URBANIST,
                            ),
                            automaticIndicatorColorAdjustment: false,
                            tabs: items.map((e) {
                              return Tab(text: e);
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: 16),
                        _currentTab == 0 ? _Details() : _Cars(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _currentTab == 0
                ? Padding(
                    padding: AppSizes.DEFAULT,
                    child: Row(
                      children: [
                        Image.asset(Assets.imagesWhatsapp, height: 48),
                        SizedBox(width: 12),
                        Expanded(
                          child: MyButton(
                            customChild: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(Assets.imagesCall, height: 48),
                                MyText(
                                  paddingRight: 30,
                                  text: "callSeller".tr,
                                  size: 16,
                                  weight: FontWeight.w600,
                                  color: kWhiteColor,
                                ),
                              ],
                            ),
                            buttonText: '',
                            onTap: () {
                              // Get.to(() => SignUp());
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          text:
              "loremIpsumDolorSitAmetConsecteturAcEtOrciInterdumAcNibhProinQuisDisNullaUltricesPharetraLectusIpsumS"
                  .tr,
          color: kHintColor,
          lineHeight: 1.5,
          paddingBottom: 16,
        ),
        Image.asset(Assets.imagesDummyMap, height: 190, width: Get.width),
        SizedBox(height: 16),
      ],
    );
  }
}

class _Cars extends StatelessWidget {
  const _Cars();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      physics: BouncingScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(10),
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: kWhiteColor,
            border: Border.all(width: 1.0, color: kBorderColor),
          ),
          child: Row(
            children: [
              CommonImageView(height: 90, width: 90, radius: 8, url: dummyImg),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MyText(
                      text: 'Автопедия',
                      size: 12,
                      weight: FontWeight.w500,
                      paddingBottom: 4,
                      color: kHintColor,
                    ),
                    MyText(
                      text: 'Модель ФОКС 1990',
                      size: 14,
                      weight: FontWeight.w600,
                      paddingBottom: 4,
                    ),
                    MyText(
                      text: 'РљСЂР°С‚РєРѕРµ РѕРїРёСЃР°РЅРёРµ Р°РІС‚РѕРјРѕР±РёР»СЏ.',
                      size: 12,
                      weight: FontWeight.w500,
                      paddingBottom: 6,
                      color: kHintColor,
                    ),
                    MyText(
                      text: 'в‚Ѕ120 000',
                      size: 16,
                      color: kSecondaryColor,
                      weight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Divider({this.marginV = 10});
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


import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_tile_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_slider_thumb_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_slider_tool_tip.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';
import 'package:get/get.dart';

class UPreferences extends StatefulWidget {
  const UPreferences({super.key});

  @override
  State<UPreferences> createState() => _UPreferencesState();
}

class _UPreferencesState extends State<UPreferences> {
  double _min = 16;

  double _max = 65;
  double _minDis = 10.0;
  double _maxDis = 100.0;
  final List<String> _plateCities = [
    "baghdad".tr,
    "erbil".tr,
    "sulaymaniyah".tr,
    "dohuk".tr,
    "kirkuk".tr,
    "mosul".tr,
    "basra".tr,
    "najaf".tr,
    "karbala".tr,
    "tikrit".tr,
    "ramadi".tr,
    "diwaniyah".tr,
    "nasiriyah".tr,
    "amarah".tr,
    "hillah".tr,
    "samawah".tr,
    "baqubah".tr,
    "kut".tr,
  ];
  final List<String> _plateType = [
    "all".tr,
    "private".tr,
    "taxi".tr,
    "temporary".tr,
    "commercial".tr,
  ];
  final List<String> _fuelType = [
    "diesel76".tr,
    "electric10".tr,
    "petrol10".tr,
  ];
  final List<String> _engineSize = [
    "10l14l".tr,
    "15l18l".tr,
    "20l25l".tr,
    "30l35l".tr,
    "40l50l".tr,
    "50lAndAbove".tr,
  ];
  final List<String> _cylinder = [
    "3cylinder".tr,
    "4cylinder".tr,
    "5cylinder".tr,
    "6cylinderv6".tr,
    "3cylinder".tr,
    "4cylinder".tr,
    "5cylinder".tr,
    "6cylinderv6".tr,
  ];
  final List<String> _importCountry = [
    "all".tr,
    "iraq".tr,
    "usa".tr,
    "gcc".tr,
    "canada".tr,
    "eu".tr,
    "korea".tr,
  ];
  final List<String> _conditions = ["all".tr, "new".tr, "used".tr];
  final List<String> _gearBoxes = ["automatic76".tr, "manual10".tr];
  final List<String> _seats = ["allFabric".tr, "leather".tr, "mix".tr];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: "preferences".tr),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.listPaddingWithBottomBar(),
        physics: BouncingScrollPhysics(),
        children: [
          MyExpandableTile(
            title: "years".tr,
            expanded: Row(
              children: [
                Expanded(
                  child: CustomDropDown(
                    labelText: "min".tr,
                    hint: "2005".tr,
                    items: [
                      "2005".tr,
                      "2006".tr,
                      "2007".tr,
                      "2008".tr,
                      "2009".tr,
                      "2010".tr,
                    ],
                    selectedValue: '2005',
                    onChanged: (v) {},
                    marginBottom: 0.0,
                  ),
                ),
                MyText(
                  paddingTop: 18,
                  text: 'до',
                  paddingLeft: 15,
                  paddingRight: 15,
                ),
                Expanded(
                  child: CustomDropDown(
                    labelText: "max".tr,
                    hint: "2005".tr,
                    items: [
                      "2005".tr,
                      "2006".tr,
                      "2007".tr,
                      "2008".tr,
                      "2009".tr,
                      "2010".tr,
                    ],
                    selectedValue: '2005',
                    onChanged: (v) {},
                    marginBottom: 0.0,
                  ),
                ),
              ],
            ),
          ),
          MyExpandableTile(
            title: "price".tr,
            expanded: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MyText(
                      text: '₽500',
                      size: 12,
                      weight: FontWeight.w600,
                      color: kHintColor,
                    ),
                    MyText(
                      text: '₽50,000',
                      size: 12,
                      weight: FontWeight.w600,
                      color: kHintColor,
                    ),
                  ],
                ),
                FlutterSlider(
                  values: [_min, _max],
                  rangeSlider: true,
                  min: 16,
                  max: 65,
                  tooltip: CustomSliderToolTip(),
                  // handlerWidth: Get.width * 0.03,
                  handlerHeight: 18,
                  handler: FlutterSliderHandler(
                    decoration: BoxDecoration(),
                    child: CustomSliderThumb(),
                  ),
                  rightHandler: FlutterSliderHandler(
                    decoration: BoxDecoration(),
                    child: CustomSliderThumb(),
                  ),
                  trackBar: FlutterSliderTrackBar(
                    activeTrackBarHeight: 8,
                    inactiveTrackBarHeight: 10,
                    activeTrackBar: BoxDecoration(
                      color: kSecondaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    inactiveTrackBar: BoxDecoration(
                      color: kWhiteColor,
                      border: Border.all(width: 1.0, color: kBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onDragging: (handlerIndex, lowerValue, upperValue) {
                    setState(() {
                      _min = lowerValue;
                      _max = upperValue;
                    });
                  },
                ),
              ],
            ),
          ),
          MyExpandableTile(
            title: "distance".tr,
            expanded: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 15),
                MyText(
                  text: "any".tr,
                  size: 12,
                  weight: FontWeight.w600,
                  color: kHintColor,
                ),
                FlutterSlider(
                  values: [_minDis, _maxDis],
                  rangeSlider: true,
                  min: 10,
                  max: 100,
                  tooltip: CustomSliderToolTip(),
                  // handlerWidth: Get.width * 0.03,
                  handlerHeight: 18,
                  handler: FlutterSliderHandler(
                    decoration: BoxDecoration(),
                    child: CustomSliderThumb(),
                  ),
                  rightHandler: FlutterSliderHandler(
                    decoration: BoxDecoration(),
                    child: CustomSliderThumb(),
                  ),
                  trackBar: FlutterSliderTrackBar(
                    activeTrackBarHeight: 8,
                    inactiveTrackBarHeight: 10,
                    activeTrackBar: BoxDecoration(
                      color: kSecondaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    inactiveTrackBar: BoxDecoration(
                      color: kWhiteColor,
                      border: Border.all(width: 1.0, color: kBorderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onDragging: (handlerIndex, lowerValue, upperValue) {
                    setState(() {
                      _minDis = lowerValue;
                      _maxDis = upperValue;
                    });
                  },
                ),
              ],
            ),
          ),
          MyExpandableTile(
            title: "plateCity".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _plateCities.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _plateCities[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "plateType".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _plateType.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _plateType[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "fuelType".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _fuelType.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _fuelType[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "engineSize".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _engineSize.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _engineSize[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "cylinder".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _cylinder.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _cylinder[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "importCountry".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _importCountry.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _importCountry[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "condition".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _conditions.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _conditions[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "geargearBox".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _gearBoxes.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _gearBoxes[index],
                );
              },
            ),
          ),
          MyExpandableTile(
            title: "seat".tr,
            expanded: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              itemCount: _seats.length,
              itemBuilder: (context, index) {
                return CustomCheckBoxTile(
                  isActive: index == 0,
                  onTap: () {},
                  title: _seats[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MyExpandableTile extends StatelessWidget {
  final String title;
  final Widget expanded;

  const MyExpandableTile({
    super.key,
    required this.title,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return ExpandableNotifier(
      child: ScrollOnExpand(
        scrollOnExpand: true,
        scrollOnCollapse: false,
        child: ExpandablePanel(
          theme: const ExpandableThemeData(
            headerAlignment: ExpandablePanelHeaderAlignment.center,
            tapBodyToCollapse: true,
          ),
          header: Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 1.0,
                  color: kBlackColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: MyText(text: title, size: 16),
          ),
          collapsed: SizedBox(),
          expanded: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: expanded,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_fonts.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/notifications/notifications.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class DHome extends StatelessWidget {
  const DHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(
        title: "welcome".tr,
        haveLeading: false,
        centerTitle: false,
        actions: [
          Center(
            child: GestureDetector(
              onTap: () {
                Get.to(() => Notifications());
              },
              child: Image.asset(Assets.imagesNotificationIcon, height: 40),
            ),
          ),
          SizedBox(width: 20),
        ],
      ),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.DEFAULT,
        physics: BouncingScrollPhysics(),
        children: [
          _PerformanceRating(),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: "carsAdvertised".tr,
                  size: 14,
                  color: kHintColor,
                  weight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: MyText(text: '40', size: 16, weight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: "carsOver40Days".tr,
                  size: 14,
                  color: kHintColor,
                  weight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: MyText(text: '20', size: 16, weight: FontWeight.w600),
              ),
            ],
          ),
          MyText(
            paddingTop: 20,
            text: "interactionSummary".tr,
            size: 16,
            weight: FontWeight.w600,
            paddingBottom: 10,
          ),
          GridView.builder(
            itemCount: 4,
            shrinkWrap: true,
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              crossAxisCount: 2,
              mainAxisExtent: 80,
            ),
            itemBuilder: (context, index) {
              final List<Map<String, dynamic>> items = [
                {
                  'icon': Assets.imagesTextLeads,
                  'title': 'Лиды (чат)',
                  'value': '8',
                },
                {
                  'icon': Assets.imagesWhatsappLeads,
                  'title': 'Лиды (WhatsApp)',
                  'value': '5',
                },
                {
                  'icon': Assets.imagesPhoneLeads,
                  'title': 'Лиды (тел.)',
                  'value': '10',
                },
                {
                  'icon': Assets.imagesMapViews,
                  'title': 'Просмотры карты',
                  'value': '8',
                },
              ];
              return Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: kWhiteColor,
                  border: Border.all(width: 1.0, color: kBorderColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset(items[index]['icon'], height: 24),
                        MyText(
                          text: items[index]['value'],
                          size: 16,
                          weight: FontWeight.w700,
                          paddingLeft: 8,
                          paddingRight: 8,
                        ),
                      ],
                    ),
                    MyText(
                      text: items[index]['title'],
                      size: 12,
                      color: kGreyColor,
                      weight: FontWeight.w600,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PerformanceRating extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: kWhiteColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MyText(
            text: "performanceRating".tr,
            size: 14,
            weight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
          MyText(
            paddingTop: 6,
            text: "yesterday’sAdvertisedStock".tr,
            size: 14,
            color: kHintColor,
            weight: FontWeight.w500,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: SfCartesianChart(
              tooltipBehavior: TooltipBehavior(enable: true),
              margin: EdgeInsets.zero,
              borderWidth: 0,
              borderColor: Colors.transparent,
              plotAreaBorderWidth: 0,
              enableAxisAnimation: true,
              primaryYAxis: NumericAxis(
                name: 'yAxis',
                maximum: 100,
                minimum: 0,
                interval: 20,
                isVisible: true,
                plotOffset: 10.0,
                majorGridLines: MajorGridLines(width: 1, color: kBorderColor),
                majorTickLines: MajorTickLines(width: 0),
                axisLine: AxisLine(width: 0),
                opposedPosition: false,
                labelStyle: TextStyle(
                  color: kGreyColor,
                  fontSize: 12.0,
                  fontFamily: AppFonts.URBANIST,
                ),
              ),
              primaryXAxis: CategoryAxis(
                name: 'xAxis',
                maximum: 6,
                minimum: 0,
                interval: 1,
                plotOffset: 5,
                majorGridLines: MajorGridLines(width: 0),
                axisLine: AxisLine(width: 0),
                majorTickLines: MajorTickLines(width: 0),
                labelStyle: TextStyle(
                  color: kGreyColor,
                  fontSize: 12.0,
                  fontFamily: AppFonts.URBANIST,
                ),
              ),
              series: graphData(),
            ),
          ),
          MyText(
            paddingTop: 16,
            text: "numberOfCars".tr,
            size: 14,
            weight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  dynamic graphData() {
    final List<_DataModel> dataSource = [
      _DataModel('10', 30),
      _DataModel('20', 40),
      _DataModel('30', 60),
      _DataModel('40', 50),
      _DataModel('50', 70),
      _DataModel('60', 60),
      _DataModel('70', 80),
    ];
    return [
      ColumnSeries<_DataModel, dynamic>(
        dataSource: dataSource,
        xValueMapper: (_DataModel data, _) => data.xValueMapper,
        yValueMapper: (_DataModel data, _) => data.yValueMapper,
        xAxisName: 'xAxis',
        yAxisName: 'yAxis',
        // gradient: LinearGradient(
        //   begin: Alignment.topCenter,
        //   end: Alignment.bottomCenter,
        //   stops: [
        //     0.1,
        //     0.9,
        //   ],
        //   colors: [
        //     kSecondaryColor,
        //     kSecondaryColor.withValues(alpha:0.33),
        //   ],
        // ),
        width: 0.7,
        spacing: 0,
        borderRadius: BorderRadius.zero,
        pointColorMapper: (_DataModel data, index) {
          Color color;
          if (data.yValueMapper! <= 30 && data.yValueMapper! >= 20) {
            color = kRedColor;
          } else if (data.yValueMapper! <= 50 && data.yValueMapper! >= 30) {
            color = kYellowColor;
          } else if (data.yValueMapper! <= 90 && data.yValueMapper! >= 50) {
            color = kGreenColor;
          } else {
            color = kGreenColor;
          }
          return color;
        },
      ),
    ];
  }
}

class _DataModel {
  _DataModel(this.xValueMapper, this.yValueMapper);

  String? xValueMapper;
  int? yValueMapper;
}

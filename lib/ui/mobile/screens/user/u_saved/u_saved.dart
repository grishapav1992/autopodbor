import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/vehicle_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class USaved extends StatelessWidget {
  const USaved({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(title: "favorite".tr, haveLeading: false),
      body: ListView.builder(
        physics: BouncingScrollPhysics(),
        shrinkWrap: true,
        itemCount: 8,
        padding: AppSizes.DEFAULT,
        itemBuilder: (context, index) {
          return VehicleCard(isFavorite: true);
        },
      ),
    );
  }
}

import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TechnicalDetails extends StatelessWidget {
  const TechnicalDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomDropDown(
          labelText: "importCountry".tr,
          hint: "selectCountry".tr,
          items: ['Выберите страну'],
          selectedValue: 'Выберите страну',
          onChanged: (v) {},
        ),
        CustomDropDown(
          labelText: "transmission".tr,
          hint: 'Выберите трансмиссию',
          items: ['Выберите трансмиссию'],
          selectedValue: 'Выберите трансмиссию',
          onChanged: (v) {},
        ),
        Row(
          children: [
            Expanded(
              child: CustomDropDown(
                labelText: "brand".tr,
                hint: 'Любой',
                items: ['Любой'],
                selectedValue: 'Любой',
                onChanged: (v) {},
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: CustomDropDown(
                labelText: "cylinders".tr,
                hint: 'Любой',
                items: ['Любой'],
                selectedValue: 'Любой',
                onChanged: (v) {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}


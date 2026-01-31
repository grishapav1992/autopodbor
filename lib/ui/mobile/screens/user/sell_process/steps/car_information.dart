import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CarInformation extends StatelessWidget {
  const CarInformation({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomDropDown(
          labelText: "brand".tr,
          hint: 'БМВ',
          items: ['БМВ'],
          selectedValue: 'БМВ',
          onChanged: (v) {},
        ),
        CustomDropDown(
          labelText: "model".tr,
          hint: 'Выберите модель',
          items: ['Выберите модель'],
          selectedValue: 'Выберите модель',
          onChanged: (v) {},
        ),
        CustomDropDown(
          labelText: "yearModel".tr,
          hint: 'Выберите год',
          items: ['Выберите год'],
          selectedValue: 'Выберите год',
          onChanged: (v) {},
        ),
        CustomDropDown(
          labelText: "trim".tr,
          hint: 'Выберите комплектацию',
          items: ['Выберите комплектацию'],
          selectedValue: 'Выберите комплектацию',
          onChanged: (v) {},
        ),
      ],
    );
  }
}

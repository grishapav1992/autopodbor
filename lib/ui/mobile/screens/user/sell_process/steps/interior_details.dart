import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_check_box_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_drop_down_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InteriorDetails extends StatelessWidget {
  const InteriorDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyText(
          text: "seatMaterial".tr,
          size: 12,
          paddingBottom: 6,
          weight: FontWeight.bold,
        ),
        Row(
          children: List.generate(3, (index) {
            final List<String> items = ["fabric".tr, "leather".tr, "mix".tr];
            return Expanded(
              child: Row(
                children: [
                  CustomRadio(isActive: index == 0, onTap: () {}),
                  Expanded(
                    child: MyText(
                      paddingLeft: 8,
                      size: 12,
                      weight: FontWeight.w600,
                      color: kHintColor,
                      text: items[index],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        SizedBox(height: 20),
        CustomDropDown(
          labelText: "seatNumber".tr,
          hint: "selectSeatNumber".tr,
          items: ['Выберите количество мест'],
          selectedValue: 'Выберите количество мест',
          onChanged: (v) {},
        ),
        Row(
          children: [
            Expanded(
              flex: 7,
              child: CustomDropDown(
                labelText: "millage".tr,
                hint: 'Выберите количество мест',
                items: ['Выберите количество мест'],
                selectedValue: 'Выберите количество мест',
                onChanged: (v) {},
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: CustomDropDown(
                labelText: '',
                hint: 'м',
                items: ['м'],
                selectedValue: 'м',
                onChanged: (v) {},
              ),
            ),
          ],
        ),
        CustomDropDown(
          labelText: "color".tr,
          hint: 'Выберите цвет',
          items: ['Выберите цвет'],
          selectedValue: 'Выберите цвет',
          onChanged: (v) {},
        ),
        CustomDropDown(
          labelText: "fuel".tr,
          hint: 'Выберите тип топлива',
          items: ['Выберите тип топлива'],
          selectedValue: 'Выберите тип топлива',
          onChanged: (v) {},
        ),
      ],
    );
  }
}

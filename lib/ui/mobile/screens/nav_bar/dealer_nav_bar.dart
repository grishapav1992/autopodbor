import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/d_home/d_home.dart';
import 'package:flutter_application_1/ui/mobile/screens/profile_screens/profile.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/leads/leads.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/pricing/piricing_tools.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class DealerNavBar extends StatefulWidget {
  const DealerNavBar({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DealerNavBarState createState() => _DealerNavBarState();
}

class _DealerNavBarState extends State<DealerNavBar> {
  int _currentIndex = 0;
  void _getCurrentIndex(int index) => setState(() {
    _currentIndex = index;
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'icon': Assets.imagesHome,
        'iconA': Assets.imagesHome,
        'label': 'Главная',
      },
      {
        'icon': Assets.imagesTagIcon,
        'iconA': Assets.imagesTagIcon,
        'label': 'Цены',
      },
      {
        'icon': Assets.imagesLeads,
        'iconA': Assets.imagesLeads,
        'label': 'Лиды',
      },
      {
        'icon': Assets.imagesProfileIconNew,
        'iconA': Assets.imagesProfileIconNew,
        'label': 'Профиль',
      },
    ];

    final List<Widget> screens = [DHome(), PricingTools(), Leads(), Profile()];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildNavBar(items),
    );
  }

  Container _buildNavBar(List<Map<String, dynamic>> items) {
    return Container(
      margin: AppSizes.DEFAULT,
      height: 60,
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(width: 1.0, color: kBorderColor)),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 14,
            color: kTertiaryColor.withValues(alpha: 0.12),
          ),
        ],
      ),
      child: BottomNavigationBar(
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedFontSize: 0,
        unselectedFontSize: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: kSecondaryColor,
        unselectedItemColor: kGreyColor,
        currentIndex: _currentIndex,
        onTap: (index) => _getCurrentIndex(index),
        items: List.generate(items.length, (index) {
          var data = items[index];
          return BottomNavigationBarItem(
            icon: Column(
              children: [
                AnimatedContainer(
                  width: 36,
                  height: 36,
                  duration: 220.milliseconds,
                  curve: Curves.easeIn,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? kSecondaryColor
                        : kWhiteColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Image.asset(
                      _currentIndex == index ? data['iconA'] : data['icon'],
                      height: 22,
                      color: _currentIndex == index
                          ? kPrimaryColor
                          : kGreyColor,
                    ),
                  ),
                ),
                MyText(
                  text: data['label'],
                  size: 10,
                  color: _currentIndex == index ? kSecondaryColor : kGreyColor,
                  weight: FontWeight.w600,
                ),
              ],
            ),
            label: data['label'].toString(),
          );
        }),
      ),
    );
  }
}

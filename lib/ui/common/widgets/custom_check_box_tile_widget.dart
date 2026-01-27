import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';

class CustomCheckBoxTile extends StatelessWidget {
  const CustomCheckBoxTile({
    super.key,
    required this.isActive,
    required this.onTap,
    required this.title,
  });
  final bool isActive;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 230),
              curve: Curves.easeInOut,
              height: 20,
              width: 20,
              decoration: BoxDecoration(
                color: isActive ? kSecondaryColor : Colors.transparent,
                border: Border.all(width: 1.0, color: kBorderColor),
              ),
              child: !isActive
                  ? SizedBox()
                  : Icon(Icons.check, size: 16, color: kPrimaryColor),
            ),
          ),
          Expanded(child: MyText(paddingLeft: 7, text: title)),
        ],
      ),
    );
  }
}

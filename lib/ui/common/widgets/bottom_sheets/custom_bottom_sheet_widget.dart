import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter/material.dart';

class CustomBottomSheet extends StatelessWidget {
  const CustomBottomSheet({
    super.key,
    required this.child,
    required this.buttonText,
    required this.onTap,
    required this.height,
  });

  final double height;
  final Widget child;
  final String buttonText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 50),
      height: height,
      decoration: BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                height: 5,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: kGreyColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          Expanded(child: child),
          if (buttonText != '')
            Padding(
              padding: AppSizes.DEFAULT,
              child: MyButton(buttonText: buttonText, onTap: onTap),
            ),
        ],
      ),
    );
  }
}

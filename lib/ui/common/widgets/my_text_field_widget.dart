import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_images.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ignore: must_be_immutable
class MyTextField extends StatefulWidget {
  MyTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.onChanged,
    this.isObSecure = false,
    this.marginBottom = 16.0,
    this.maxLines = 1,
    this.labelSize,
    this.prefix,
    this.suffix,
    this.isReadOnly,
    this.onTap,
    this.textAlign,
    this.inputFormatters,
  });

  String? labelText, hintText;
  TextEditingController? controller;
  ValueChanged<String>? onChanged;
  bool? isObSecure, isReadOnly;
  double? marginBottom;
  int? maxLines;
  double? labelSize;
  Widget? prefix, suffix;
  final VoidCallback? onTap;
  TextAlign? textAlign;
  List<TextInputFormatter>? inputFormatters;

  @override
  State<MyTextField> createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.marginBottom!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.labelText != null)
            MyText(
              text: widget.labelText ?? '',
              size: widget.labelSize ?? 14,
              color: kTertiaryColor,
              paddingBottom: 6,
              weight: FontWeight.bold,
            ),
          TextFormField(
            textAlign: widget.textAlign ?? TextAlign.start,
            onTap: widget.onTap,
            textAlignVertical: widget.prefix != null || widget.suffix != null
                ? TextAlignVertical.center
                : null,
            cursorColor: kSecondaryColor,
            maxLines: widget.maxLines,
            readOnly: widget.isReadOnly ?? false,
            controller: widget.controller,
            onChanged: widget.onChanged,
            inputFormatters: widget.inputFormatters,
            textInputAction: TextInputAction.next,
            obscureText: widget.isObSecure!,
            obscuringCharacter: '*',
            style: TextStyle(
              fontSize: 12,
              color: kTertiaryColor,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              fillColor: kWhiteColor,
              filled: true,
              prefixIcon: widget.prefix,
              suffixIcon: widget.suffix,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: widget.maxLines! > 1 ? 15 : 0,
              ),
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: 12,
                color: kHintColor,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kBorderColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: kSecondaryColor, width: 1),
              ),
              errorBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: must_be_immutable
class PhoneField extends StatefulWidget {
  PhoneField({
    super.key,
    this.controller,
    this.onChanged,
    this.marginBottom = 16.0,
  });

  TextEditingController? controller;
  ValueChanged<String>? onChanged;
  double? marginBottom;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        cursorColor: kTertiaryColor,
        controller: widget.controller,
        onChanged: widget.onChanged,
        keyboardType: TextInputType.phone,
        inputFormatters: [RuPhoneFormatter()],
        textInputAction: TextInputAction.next,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          filled: true,
          fillColor: kWhiteColor,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 6),
            child: Image.asset(Assets.imagesPhone, height: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          contentPadding: EdgeInsets.symmetric(horizontal: 15),
          hintText: '+7',
          hintStyle: TextStyle(
            fontSize: 12,
            color: kHintColor,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kBorderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kSecondaryColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: InputBorder.none,
        ),
      ),
    );
  }
}

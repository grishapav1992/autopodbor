import 'package:flutter/services.dart';

class RuPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    if (digits.startsWith('8') || digits.startsWith('7')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    String take(int start, int length) {
      if (digits.length <= start) return '';
      final end = start + length;
      return digits.substring(start, end > digits.length ? digits.length : end);
    }

    final g1 = take(0, 3);
    final g2 = take(3, 3);
    final g3 = take(6, 2);
    final g4 = take(8, 2);

    var out = '+7';
    if (g1.isNotEmpty) out += g1;
    if (g2.isNotEmpty) out += '-$g2';
    if (g3.isNotEmpty) out += '-$g3';
    if (g4.isNotEmpty) out += '-$g4';

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

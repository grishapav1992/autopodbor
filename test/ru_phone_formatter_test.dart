import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/ui/common/formatters/ru_phone_formatter.dart';

void main() {
  final formatter = RuPhoneFormatter();

  TextEditingValue fmt(String input) {
    return formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      TextEditingValue(text: input),
    );
  }

  test('empty input stays empty', () {
    expect(fmt('').text, '');
  });

  test('starts with 7 or 8 normalizes to +7', () {
    expect(fmt('7').text, '+7');
    expect(fmt('8').text, '+7');
  });

  test('formats ru phone with dashes', () {
    expect(fmt('+79528168245').text, '+7952-816-82-45');
  });

  test('limits to 10 digits after +7', () {
    expect(fmt('799999999999').text, '+7999-999-99-99');
  });
}

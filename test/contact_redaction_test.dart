import 'package:flutter_application_1/core/utils/contact_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactRedaction', () {
    test('redacts email and phone', () {
      const input =
          '\u041F\u0438\u0448\u0438\u0442\u0435 \u043D\u0430 test.user+1@mail.ru '
          '\u0438\u043B\u0438 \u0437\u0432\u043E\u043D\u0438\u0442\u0435 +7 (999) 123-45-67';
      final result = ContactRedaction.redactPublicText(input);

      expect(result.redacted, isTrue);
      expect(result.text, isNot(contains('mail.ru')));
      expect(result.text, isNot(contains('123-45-67')));
      expect(
        result.text,
        contains(
          '[\u041A\u043E\u043D\u0442\u0430\u043A\u0442\u044B '
          '\u0441\u043A\u0440\u044B\u0442\u044B \u0434\u043E \u043E\u043F\u043B\u0430\u0442\u044B]',
        ),
      );
    });

    test('redacts messenger links and handles', () {
      const input = 'Telegram: t.me/autopodbor_best and @best_picker';
      final result = ContactRedaction.redactPublicText(input);

      expect(result.redacted, isTrue);
      expect(result.text, isNot(contains('t.me')));
      expect(result.text, isNot(contains('@best_picker')));
    });

    test('blocks obfuscated contact attempts with number words', () {
      const input =
          '\u041C\u043E\u0439 \u043D\u043E\u043C\u0435\u0440 \u0432 '
          '\u0432\u0430\u0442\u0441\u0430\u043F: \u0432\u043E\u0441\u0435\u043C\u044C '
          '\u0434\u0435\u0432\u044F\u0442\u044C \u0434\u0435\u0432\u044F\u0442\u044C '
          '\u0434\u0435\u0432\u044F\u0442\u044C \u043E\u0434\u0438\u043D \u0434\u0432\u0430 '
          '\u0442\u0440\u0438 \u0447\u0435\u0442\u044B\u0440\u0435 '
          '\u043F\u044F\u0442\u044C \u0448\u0435\u0441\u0442\u044C';
      final result = ContactRedaction.redactPublicText(input);

      expect(result.redacted, isTrue);
      expect(
        result.text,
        '\u041A\u043E\u043D\u0442\u0430\u043A\u0442\u044B \u0441\u043A\u0440\u044B\u0442\u044B '
        '\u0434\u043E \u043E\u043F\u043B\u0430\u0442\u044B. \u041E\u043F\u0438\u0448\u0438\u0442\u0435 '
        '\u043E\u043F\u044B\u0442 \u0438 \u043F\u043E\u0434\u0445\u043E\u0434 '
        '\u0431\u0435\u0437 \u043A\u043E\u043D\u0442\u0430\u043A\u0442\u043E\u0432.',
      );
    });

    test('does not redact normal profile text', () {
      const input =
          '\u041F\u043E\u0434\u0431\u0438\u0440\u0430\u044E \u0430\u0432\u0442\u043E '
          '\u043F\u043E\u0434 \u043A\u043B\u044E\u0447, \u043F\u0440\u043E\u0432\u0435\u0440\u044F\u044E '
          '\u0434\u043E\u043A\u0443\u043C\u0435\u043D\u0442\u044B, \u0432\u044B\u0435\u0437\u0436\u0430\u044E '
          '\u043D\u0430 \u043E\u0441\u043C\u043E\u0442\u0440 \u0432 '
          '\u0434\u0435\u043D\u044C \u043E\u0431\u0440\u0430\u0449\u0435\u043D\u0438\u044F.';
      final result = ContactRedaction.redactPublicText(input);

      expect(result.redacted, isFalse);
      expect(result.text, input);
    });

    test('validateProfileText returns violations for contacts', () {
      const input =
          'Пишите на test@mail.ru, Telegram: t.me/tester, +7 (999) 111-22-33';
      final validation = ContactRedaction.validateProfileText(input);

      expect(validation.hasViolations, isTrue);
      expect(validation.errors, isNotEmpty);
      expect(validation.errors.any((e) => e.contains('email')), isTrue);
    });

    test('validateProfileText returns no violations for normal text', () {
      const input =
          '\u0414\u0435\u043B\u0430\u044E '
          '\u043F\u043E\u043B\u043D\u0443\u044E '
          '\u0434\u0438\u0430\u0433\u043D\u043E\u0441\u0442\u0438\u043A\u0443 '
          '\u0438 \u0441\u043E\u043F\u0440\u043E\u0432\u043E\u0436\u0434\u0430\u044E '
          '\u0441\u0434\u0435\u043B\u043A\u0443 \u043F\u043E \u0434\u043E\u0433\u043E\u0432\u043E\u0440\u0443.';
      final validation = ContactRedaction.validateProfileText(input);

      expect(validation.hasViolations, isFalse);
      expect(validation.errors, isEmpty);
    });

    test('blocks telegram nick even when it is written as nick@', () {
      const input =
          '\u041C\u043E\u0439 \u043D\u0438\u043A '
          '\u0432 \u0442\u0435\u043B\u0435\u0433\u0440\u0430\u043C '
          'pavlenko_fgrgr@';
      final validation = ContactRedaction.validateProfileText(input);

      expect(validation.hasViolations, isTrue);
    });

    test('blocks telegram nick without @ when context is explicit', () {
      const input =
          '\u041D\u0438\u043A \u0432 \u0442\u0435\u043B\u0435\u0433\u0435 auto_inspector';
      final validation = ContactRedaction.validateProfileText(input);

      expect(validation.hasViolations, isTrue);
    });
  });
}

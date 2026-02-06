import 'package:flutter_application_1/core/utils/contact_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

class _ModerationCase {
  const _ModerationCase({
    required this.id,
    required this.field,
    required this.input,
    required this.expected,
  });

  final String id;
  final ContactModerationField field;
  final String input;
  final ContactModerationDecision expected;
}

void main() {
  final cases = <_ModerationCase>[
    const _ModerationCase(
      id: 'A01',
      field: ContactModerationField.about,
      input: 'Звоните +7 999 123-45-67',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A02',
      field: ContactModerationField.about,
      input: 'Мой телефон: 8 (999) 123 45 67',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A03',
      field: ContactModerationField.about,
      input: 'WhatsApp: +7 999 123 45 67',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A04',
      field: ContactModerationField.about,
      input: 'Telegram: @auto_inspector',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A05',
      field: ContactModerationField.about,
      input: 't.me/auto_inspector',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A06',
      field: ContactModerationField.about,
      input: 'Почта: inspector@mail.ru',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A07',
      field: ContactModerationField.about,
      input: 'Сайт: https://autopodbor.ru',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A08',
      field: ContactModerationField.about,
      input: 'VK: vk.com/inspectorman',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A09',
      field: ContactModerationField.serviceTitle,
      input: 'Осмотр (пишите в тг @auto)',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A10',
      field: ContactModerationField.description,
      input: 'Пишите, договоримся: wa.me/79991234567',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A11',
      field: ContactModerationField.about,
      input: 'мой ник в телеграм grigori_pavlenko',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A12',
      field: ContactModerationField.about,
      input: 'ник в телеграм: grigori_pavlenko',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A13',
      field: ContactModerationField.about,
      input: 'telegram: grigori_pavlenko',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A14',
      field: ContactModerationField.about,
      input: 'тг ник grigori_pavlenko',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'A15',
      field: ContactModerationField.about,
      input: 'мой телеграм — grigori_pavlenko',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'B01',
      field: ContactModerationField.about,
      input: 'плюс семь 999 123 45 67',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'B02',
      field: ContactModerationField.about,
      input: 'восемь 999 123 45 67',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'B03',
      field: ContactModerationField.about,
      input: '+7(999)1234567',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'B04',
      field: ContactModerationField.about,
      input: '9 9 9 1 2 3 4 5 6 7',
      expected: ContactModerationDecision.review,
    ),
    const _ModerationCase(
      id: 'B05',
      field: ContactModerationField.about,
      input: 'мой тг: @a_u_t_o_i_n_s_p',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'B06',
      field: ContactModerationField.about,
      input: 't (точка) me / auto_inspector',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'B07',
      field: ContactModerationField.about,
      input: 'auto_inspector собака gmail точка com',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'B08',
      field: ContactModerationField.about,
      input: 'пиши в ватс ап, номер дам',
      expected: ContactModerationDecision.review,
    ),
    const _ModerationCase(
      id: 'B09',
      field: ContactModerationField.about,
      input: 'пиши в телегу, ник скину',
      expected: ContactModerationDecision.review,
    ),
    const _ModerationCase(
      id: 'B10',
      field: ContactModerationField.about,
      input: 'в личку в тг, тут редко',
      expected: ContactModerationDecision.review,
    ),
    const _ModerationCase(
      id: 'C01',
      field: ContactModerationField.about,
      input: 'Работаю в Краснодаре, выезд по краю.',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'C02',
      field: ContactModerationField.about,
      input: 'Осмотр за 2–3 часа, отчёт в PDF.',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'C03',
      field: ContactModerationField.about,
      input: 'Толщиномер, эндоскоп, диагностика OBD.',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'C04',
      field: ContactModerationField.about,
      input: 'Связь после оплаты заказа в сервисе.',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'C05',
      field: ContactModerationField.about,
      input: 'Договор, акт, чек предоставляю.',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'D01',
      field: ContactModerationField.about,
      input: 'Работаю с BMW E39, E60, E90.',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'D02',
      field: ContactModerationField.about,
      input: 'Отчет на 12 страниц, 5 разделов.',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'D03',
      field: ContactModerationField.about,
      input: 'Работаю по ГОСТ 33997-2016',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'D04',
      field: ContactModerationField.about,
      input: 'Рейтинг 4.9/5',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'D05',
      field: ContactModerationField.about,
      input: 'Телефон в машине не ловит',
      expected: ContactModerationDecision.allow,
    ),
    const _ModerationCase(
      id: 'E01',
      field: ContactModerationField.fileName,
      input: 'Отчет_+79991234567.pdf',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'E02',
      field: ContactModerationField.portfolioText,
      input: 'Пример отчёта на mysite.ru',
      expected: ContactModerationDecision.block,
    ),
    const _ModerationCase(
      id: 'E03',
      field: ContactModerationField.comment,
      input: 'В отчете оставил контакты',
      expected: ContactModerationDecision.review,
    ),
  ];

  group('Contact moderation matrix A-E', () {
    for (final testCase in cases) {
      test('${testCase.id} -> ${testCase.expected.name}', () {
        final result = ContactRedaction.moderateText(
          testCase.input,
          field: testCase.field,
        );

        expect(result.decision, testCase.expected);
        if (testCase.expected != ContactModerationDecision.allow) {
          expect(result.reasons, isNotEmpty);
        }
      });
    }
  });
}

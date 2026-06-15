import 'package:flutter_application_1/data/api/ai_queue_api.dart';
import 'package:flutter_application_1/data/services/ai_queue_cliche_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiQueue prompt rules', () {
    test('uses gpt-5.4 as product default model', () async {
      expect(await AiQueueApi.resolveDefaultModel(), 'gpt-5.4');
    });

    test('element cliche treats car context as internal reasoning only', () {
      final cliche = AiQueueClicheBuilder.buildElementClicheFromLabels(
        elementLabel: 'Крыша',
        selectedTagLabels: const ['Вмятина'],
        seriousTagLabels: const <String>{},
        carContext: 'Kia Rio, 2020, 1.6, АКПП',
      );

      expect(cliche, contains('Контекст автомобиля'));
      expect(cliche, contains('типичные слабые места'));
      expect(cliche, contains('не называй автомобиль'));
      expectNoHumanRole(cliche);
    });

    test('test-drive cliche does not mention human roles', () {
      final cliche = AiQueueClicheBuilder.buildTdCommentCliche(
        tdMode: 'problems',
        subsystemStatus: const <String, bool?>{'engine': false},
        subsystemTags: const <String, List<String>>{
          'engine': <String>['Плавающие обороты'],
        },
      );

      expectNoHumanRole(cliche);
    });

    test('report-facts cliche has no buy/refuse verdict or prescriptions', () {
      final cliche = AiQueueClicheBuilder.buildReportFactsCliche(
        reportLabel: 'Осмотр Kia Rio',
        carContext: 'Kia Rio, 2020, 1.6, АКПП',
      );

      // Verdict marker and its buy/refuse variants are gone (B15).
      expect(cliche, isNot(contains('РЕКОМЕНДАЦИЯ')));
      expect(cliche, isNot(contains('рекомендуется к покупке')));
      expect(cliche, isNot(contains('не рекомендуется')));
      // The template still drives the descriptive structure.
      expect(cliche, contains('Кузов:'));
      expect(cliche, contains('Не осмотрено'));
    });

    test('legal cliche does not advise client actions', () {
      final cliche = AiQueueClicheBuilder.buildLegalCommentCliche(
        filesCount: 2,
        fileNames: const ['ПТС', 'СТС'],
      );

      expect(cliche, isNot(contains('рекомендуются клиенту')));
    });

    test('vin-params cliche demands strict JSON with exact enum options', () {
      final cliche = AiQueueClicheBuilder.buildVinParamsCliche(
        vin: 'XTAGFL110JY123456',
        carContext: 'LADA VESTA, 2017, 1.6, бензин',
        wmiInfo: 'производитель LADA, страна Россия',
      );

      expect(cliche, contains('XTAGFL110JY123456'));
      expect(cliche, contains('СТРОГО один JSON'));
      expect(cliche, contains('{text}'));
      // Все enum-значения перечислены дословно (дропдаун строгий).
      expect(cliche, contains('"Газ/Бензин"'));
      expect(cliche, contains('"Вариатор"'));
      expect(cliche, contains('"Полный"'));
      // Анти-галлюцинация + явный отказ угадывать.
      expect(cliche, contains('не угадывай'));
      // Грунтовка подмешана в промпт.
      expect(cliche, contains('LADA VESTA'));
      expect(cliche, contains('WMI'));
    });
  });
}

void expectNoHumanRole(String cliche) {
  for (final term in const [
    'Дилер',
    'дилер',
    'Инспектор',
    'инспектор',
    'Исполнитель',
    'исполнитель',
    'Автоэксперт',
    'автоэксперт',
    'Специалист',
    'специалист',
  ]) {
    expect(cliche, isNot(contains(term)), reason: 'prompt contains "$term"');
  }
}

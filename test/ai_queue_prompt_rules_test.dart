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
      // Holistic synthesis (fix: «итог по одному элементу» → целостная сводка):
      // обязательный ведущий абзац + охват всех зон, включая юр-проверки.
      expect(cliche, contains('Общая оценка состояния'));
      expect(cliche, contains('Идентификация и параметры:'));
      expect(cliche, contains('Юридические проверки и материалы:'));
      expect(cliche, contains('е ограничивайся одним элементом'));
    });

    test('legal cliche does not advise client actions', () {
      final cliche = AiQueueClicheBuilder.buildLegalCommentCliche();

      expect(cliche, isNot(contains('рекомендуются клиенту')));
    });

    test(
      'legal cliche exposes only performed facts without provider jargon',
      () {
        final cliche = AiQueueClicheBuilder.buildLegalCommentCliche(
          checksInfo:
              'Залог (реестр нотариусов) — не обнаружено; '
              'Работа в такси — не обнаружено',
        );

        expect(cliche, contains('Факты выполненных проверок'));
        expect(cliche, contains('Залог (реестр нотариусов) — не обнаружено'));
        expect(cliche, contains('Работа в такси — не обнаружено'));
        expect(cliche, contains('Назови только реально выполненные проверки'));
        expect(cliche, contains('даже в виде оговорок'));
        expect(cliche, isNot(contains('ApiCloud')));
        expect(cliche, isNot(contains('Документы не приложены')));
        // Имена/количество файлов больше НЕ передаются (содержимое недоступно).
        expect(cliche, isNot(contains('Приложенные документы')));
        expect(cliche, isNot(contains('остались непроверенными')));
      },
    );

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

    test('video intake cliche returns one verdict for original video', () {
      final cliche = AiQueueClicheBuilder.buildIntakeVideoDistributionCliche(
        inspectionGroups: const [
          (
            key: 'body',
            title: 'Кузов',
            elements: [(id: 'hood', label: 'Капот')],
          ),
        ],
      );

      expect(cliche, contains('ОДИН видеофайл'));
      expect(cliche, contains('hash ОРИГИНАЛЬНОГО видео'));
      expect(cliche, contains('РОВНО один объект'));
      expect(cliche, contains('"body"'));
      expect(cliche, contains('"hood"'));
      expect(cliche, contains('{text}'));
    });

    test(
      'factual builders: no prescriptions, keep inspector recs, no risk-speculation',
      () {
        final cliches = <String>[
          AiQueueClicheBuilder.buildElementClicheFromLabels(
            elementLabel: 'Капот',
            selectedTagLabels: const ['Скол'],
            seriousTagLabels: const <String>{},
          ),
          AiQueueClicheBuilder.buildDocsCheckCommentCliche(
            ownerMatch: false,
            vinMatch: true,
            engineMatch: true,
          ),
          AiQueueClicheBuilder.buildTdCommentCliche(
            tdMode: 'problems',
            subsystemStatus: const <String, bool?>{'engine': false},
            subsystemTags: const <String, List<String>>{},
          ),
          AiQueueClicheBuilder.buildLegalCommentCliche(),
          AiQueueClicheBuilder.buildReportFactsCliche(reportLabel: 'Осмотр'),
        ];
        for (final cliche in cliches) {
          // факты-только + запрет советов покупателю
          expect(cliche, contains('ничего не домысливай'), reason: cliche);
          expect(
            cliche,
            contains('Не давай покупателю советов'),
            reason: cliche,
          );
          // исключение: рекомендацию инспектора из его текста сохраняем
          expect(cliche, contains('сохрани её как есть'), reason: cliche);
          // убраны провокации к домыслам о последствиях
          expect(cliche, isNot(contains('какие риски это несёт')));
          expect(cliche, isNot(contains('какие риски они несут')));
        }
      },
    );
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

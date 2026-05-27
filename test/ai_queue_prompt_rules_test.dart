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

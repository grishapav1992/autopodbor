import 'package:flutter_application_1/data/api/storage_api.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_legal_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legalReviewBatchPending (B2 polling stop condition)', () {
    test('empty list is pending (nothing settled yet)', () {
      expect(legalReviewBatchPending(const <Map<String, dynamic>>[]), isTrue);
    });

    test('any pending/processing check keeps the batch pending', () {
      expect(
        legalReviewBatchPending(const [
          {'checkType': 'a', 'status': 'done'},
          {'checkType': 'b', 'status': 'pending'},
        ]),
        isTrue,
      );
      expect(
        legalReviewBatchPending(const [
          {'status': 'PROCESSING'},
        ]),
        isTrue,
      );
    });

    test('empty/missing status counts as pending', () {
      expect(
        legalReviewBatchPending(const [
          {'checkType': 'a', 'status': ''},
        ]),
        isTrue,
      );
      expect(
        legalReviewBatchPending(const [
          {'checkType': 'a'},
        ]),
        isTrue,
      );
    });

    test('all terminal statuses → not pending', () {
      expect(
        legalReviewBatchPending(const [
          {'status': 'done'},
          {'status': 'completed'},
          {'status': 'failed'},
          {'status': 'error'},
        ]),
        isFalse,
      );
    });

    test('stale pending status with persisted response is terminal', () {
      expect(
        legalReviewBatchPending(const [
          {
            'status': 'pending',
            'responseNormalized': '{"found":false,"certificate":[]}',
          },
        ]),
        isFalse,
      );
      expect(
        legalReviewBatchPending(const [
          {'status': 'pending', 'responseNormalized': <dynamic>[]},
        ]),
        isFalse,
      );
    });

    test('stale pending status with executedAt is terminal', () {
      expect(
        legalReviewBatchPending(const [
          {'status': 'pending', 'executedAt': '2026-07-15T01:03:05Z'},
        ]),
        isFalse,
      );
    });
  });

  group('legalReviewBatchSettled (summary fallback)', () {
    test('uses completed summary when individual statuses are stale', () {
      expect(
        legalReviewBatchSettled(
          const {
            'summary': {'total': 2, 'completed': 2, 'pending': 0, 'failed': 0},
          },
          const [
            {'status': 'pending'},
            {'status': 'pending'},
          ],
        ),
        isTrue,
      );
    });

    test('does not settle an unregistered empty batch', () {
      expect(
        legalReviewBatchSettled(const {
          'summary': {'total': 0, 'completed': 0, 'pending': 0, 'failed': 0},
        }, const []),
        isFalse,
      );
    });
  });

  group('legalReviewBatchNumbers (batches key, live-confirmed 2026-06-01)', () {
    test('reads bare string elements from `batches`', () {
      expect(
        legalReviewBatchNumbers(const <String, dynamic>{
          'batches': ['LEG-A1', 'LEG-A2'],
        }),
        ['LEG-A1', 'LEG-A2'],
      );
    });

    test('reads batchNumber from object elements', () {
      expect(
        legalReviewBatchNumbers(const <String, dynamic>{
          'batches': [
            {'batchNumber': 'LEG-A1', 'status': 'completed'},
            {'number': 'LEG-A2'},
          ],
        }),
        ['LEG-A1', 'LEG-A2'],
      );
    });

    test('tolerates legacy `batchIds` key as fallback', () {
      expect(
        legalReviewBatchNumbers(const <String, dynamic>{
          'batchIds': ['LEG-OLD'],
        }),
        ['LEG-OLD'],
      );
    });

    test('dedupes and drops empty entries', () {
      expect(
        legalReviewBatchNumbers(const <String, dynamic>{
          'batches': ['X', 'X', '', '  '],
        }),
        ['X'],
      );
    });

    test('missing / non-list → empty', () {
      expect(legalReviewBatchNumbers(const <String, dynamic>{}), isEmpty);
      expect(
        legalReviewBatchNumbers(const <String, dynamic>{'batches': 'nope'}),
        isEmpty,
      );
    });
  });

  group('sparkJoyHumanizeLegalCheckMessage (raw provider text → русский)', () {
    test('живой кейс ApiCloud: forbidden symbols в госномере', () {
      expect(
        sparkJoyHumanizeLegalCheckMessage('gosNumber% forbidden symbols present'),
        'Сервис проверки не принял госномер — нужен российский номер '
        'кириллицей и цифрами',
      );
    });

    test('таймаут провайдера переводится в «попробуйте позже»', () {
      expect(
        sparkJoyHumanizeLegalCheckMessage(
          'cURL error 28: Operation timed out after 10001 milliseconds',
        ),
        'Сервис проверки не ответил вовремя — попробуйте позже',
      );
    });

    test('errorMessage бэка: класс исключения и file:line отбрасываются', () {
      expect(
        sparkJoyHumanizeLegalCheckMessage(
          r'App\Workerman\Service\MainHttpService\Exception\ApiCloudException'
          r' | gosNumber% forbidden symbols present'
          r' | /var/www/src/Service/ApiCloudClient.php:87',
        ),
        'Сервис проверки не принял госномер — нужен российский номер '
        'кириллицей и цифрами',
      );
    });

    test('русский текст бэка проходит без изменений', () {
      expect(
        sparkJoyHumanizeLegalCheckMessage('В базе такси не найдено'),
        'В базе такси не найдено',
      );
    });

    test('пустая строка остаётся пустой', () {
      expect(sparkJoyHumanizeLegalCheckMessage('   '), '');
    });
  });
}

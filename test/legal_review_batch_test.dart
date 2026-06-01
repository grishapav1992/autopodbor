import 'package:flutter_application_1/data/api/storage_api.dart';
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
}

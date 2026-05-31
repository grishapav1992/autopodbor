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
}

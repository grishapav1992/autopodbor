import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_request_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cancelReasonForRequestStatus', () {
    test('maps cancellable statuses to backend reasons', () {
      expect(cancelReasonForRequestStatus('created'), 'canceled_not_signed');
      expect(
        cancelReasonForRequestStatus('await_payment'),
        'canceled_signed_unpaid',
      );
    });

    test('normalizes status and rejects non-cancellable statuses', () {
      expect(
        cancelReasonForRequestStatus(' AWAIT_PAYMENT '),
        'canceled_signed_unpaid',
      );
      expect(cancelReasonForRequestStatus('paid_escrow'), isNull);
      expect(cancelReasonForRequestStatus('canceled'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/data/api/notification_api.dart';
import 'package:flutter_application_1/state/notification_controller.dart';

class _RecordingNotificationController extends NotificationController {
  int reloadCalls = 0;

  @override
  Future<void> reload() async {
    reloadCalls++;
  }
}

void main() {
  testWidgets('push with requiresFetch=false still reloads the feed', (
    tester,
  ) async {
    final controller = _RecordingNotificationController();

    controller.handlePushEvent(
      NotificationPushEvent(
        notificationId: 'first-assignment',
        event: NotificationPushEventType.created,
        requiresFetch: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(controller.reloadCalls, 1);
    controller.onClose();
  });
}

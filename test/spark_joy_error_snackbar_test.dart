import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_error_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sparkJoyReadableErrorText', () {
    test('maps known backend codes', () {
      expect(
        sparkJoyReadableErrorText(
          Exception('request_status_does_not_allow_cancel'),
        ),
        'Заявку нельзя отменить в текущем статусе',
      );
    });

    test('makes unknown snake_case codes readable', () {
      expect(
        sparkJoyReadableErrorText(Exception('notification_not_found')),
        'Уведомление не найдено',
      );
      expect(
        sparkJoyReadableErrorText(Exception('profile_city_required')),
        'Заполните обязательное поле: Город',
      );
    });

    test('surfaces a clear message when the email is already taken (B3)', () {
      for (final code in const [
        'email_already_exists',
        'email_already_in_use',
        'email_taken',
      ]) {
        expect(
          sparkJoyReadableErrorText(
            Exception('Bad response from Storage.UpdateProfile: $code'),
          ),
          'Этот email уже зарегистрирован',
          reason: code,
        );
      }
    });

    test('hides technical transport messages from user text', () {
      expect(
        sparkJoyReadableErrorText(
          Exception('Invalid JSON response from Storage.GetRequest: <html>'),
        ),
        'Сервер вернул некорректный ответ. Повторите позже.',
      );
    });

    test('keeps technical details in support text', () {
      final readable = sparkJoyReadableError(
        Exception('Bad response from Storage.CancelRequest: request_not_found'),
      );
      expect(readable.message, 'Заявка не найдена');
      expect(readable.supportText, contains('Сообщение: Заявка не найдена'));
      expect(readable.supportText, contains('Код ошибки: request_not_found'));
      expect(readable.supportText, contains('Метод: Storage.CancelRequest'));
      expect(readable.supportText, contains('Техническая ошибка:'));
    });
  });
}

import 'package:flutter_application_1/data/api/storage_api.dart'
    show CreateRequestPossiblyCommittedException, PermissionDeniedException;
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
        'Заполните поле: Город',
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
      expect(readable.code, SparkJoyErrorCode.serverRejected);
      expect(readable.supportText, contains('Код: SRV-04'));
      expect(readable.supportText, contains('Сообщение: Заявка не найдена'));
      expect(readable.supportText, contains('Код сервера: request_not_found'));
      expect(readable.supportText, contains('Метод: Storage.CancelRequest'));
      expect(readable.supportText, contains('Техническая ошибка:'));
    });

    test('maps invite "pending invitation already exists" to friendly text', () {
      final readable = sparkJoyReadableError(
        Exception(
          'Notification.SendNotification: Pending invitation to this '
          'specialist already exists.',
        ),
      );
      expect(
        readable.message,
        'Этому специалисту уже отправлено приглашение — оно ожидает принятия.',
      );
      // Сырой техничный текст и метод убраны из сообщения, но остаются в
      // support-тексте для диагностики.
      expect(
        readable.message,
        isNot(contains('Notification.SendNotification')),
      );
      expect(readable.message, isNot(contains('Pending invitation')));
      expect(
        readable.supportText,
        contains('Метод: Notification.SendNotification'),
      );
    });

    test('shows backend russian rejection text as-is with SRV-04 class', () {
      // Живой кейс: повторный accept приглашения после таймаута первого —
      // Notification.ActionNotification кладёт русский текст в result.error
      // без какого-либо кода.
      final readable = sparkJoyReadableError(
        Exception(
          'Notification.ActionNotification: Оповещение уже обработано.',
        ),
      );
      expect(readable.message, 'Оповещение уже обработано.');
      expect(readable.code, SparkJoyErrorCode.serverRejected);
      expect(
        readable.supportText,
        contains('Метод: Notification.ActionNotification'),
      );
    });

    test('maps PermissionDeniedException to a clean RBAC message (B1)', () {
      final readable = sparkJoyReadableError(
        PermissionDeniedException('Storage.GetCompanySpecialists', 'forbidden'),
      );
      expect(readable.message, 'Недостаточно прав для этого действия');
      expect(readable.code, SparkJoyErrorCode.authForbidden);
      expect(readable.supportText, contains('Код: AUTH-02'));
      // Method + server detail stay in the copyable support text.
      expect(
        readable.supportText,
        contains('Метод: Storage.GetCompanySpecialists'),
      );
      expect(readable.supportText, contains('forbidden'));
    });

    test('maps uncertain CreateRequest timeout to a no-retry message', () {
      const technical =
          'Timeout on Storage.CreateRequest after 12s '
          '(elapsed=12014ms): TimeoutException after 0:00:12.000000';
      final readable = sparkJoyReadableError(
        const CreateRequestPossiblyCommittedException(
          technicalMessage: technical,
        ),
      );
      expect(
        readable.message,
        CreateRequestPossiblyCommittedException.userMessage,
      );
      expect(readable.code, SparkJoyErrorCode.netTimeout);
      expect(readable.supportText, contains('Код: NET-02'));
      expect(readable.supportText, contains('Метод: Storage.CreateRequest'));
      expect(readable.supportText, contains(technical));
    });
  });

  group('internal support codes', () {
    ({String raw, String code, String? message}) c(
      String raw,
      String code, [
      String? message,
    ]) => (raw: raw, code: code, message: message);

    final cases = <({String raw, String code, String? message})>[
      // Живой кейс с поля (скриншот 2026-07-06): connect-таймаут RPC.
      c(
        'ClientException with SocketException: HTTP connection timed out '
            'after 0:00:10.000000, host: app.carreports.ru, port: 443, '
            'uri=https://app.carreports.ru',
        SparkJoyErrorCode.netTimeout,
        'Сервер не ответил вовремя. Проверьте подключение и повторите.',
      ),
      c(
        'TimeoutException after 0:03:00.000000: Future not completed',
        SparkJoyErrorCode.netTimeout,
      ),
      c(
        'Exception: Timeout on Storage.CreateRequest after 12s '
            '(elapsed=12014ms): TimeoutException after 0:00:12.000000: '
            'Future not completed',
        SparkJoyErrorCode.netTimeout,
        'Сервер не ответил вовремя. Проверьте подключение и повторите.',
      ),
      // Живой кейс: «Принять» приглашение в штат — RPC-таймаут 12с, при этом
      // сервер успел закоммитить accept (см. isAlreadyProcessed).
      c(
        'Timeout on Notification.ActionNotification after 12s '
            '(elapsed=12008ms): TimeoutException after 0:00:12.000000: '
            'Future not completed',
        SparkJoyErrorCode.netTimeout,
        'Сервер не ответил вовремя. Проверьте подключение и повторите.',
      ),
      c(
        "SocketException: Failed host lookup: 'app.carreports.ru'",
        SparkJoyErrorCode.netNoConnection,
        'Нет подключения к интернету. Проверьте связь и повторите.',
      ),
      c(
        'SocketException: Network is unreachable',
        SparkJoyErrorCode.netNoConnection,
      ),
      c(
        'HandshakeException: Handshake error in client '
            '(OS Error: CERTIFICATE_VERIFY_FAILED)',
        SparkJoyErrorCode.netTls,
        'Не удалось установить защищённое соединение. Обновите приложение '
            'до последней версии или попробуйте другую сеть.',
      ),
      c('SocketException: Connection refused', SparkJoyErrorCode.netRefused),
      c(
        'ClientException: Connection closed before full header was received',
        SparkJoyErrorCode.netInterrupted,
      ),
      c('ClientException: Failed to fetch', SparkJoyErrorCode.netGeneric),
      c(
        'Bad response from Storage.PrepareSpecialistReport: HTTP 502 '
            '<html>Bad Gateway</html>',
        SparkJoyErrorCode.serverUnavailable,
        'Сервер временно недоступен. Повторите позже.',
      ),
      c(
        'HTTP 429 Too Many Requests',
        SparkJoyErrorCode.serverRateLimited,
        'Слишком много запросов. Подождите минуту и повторите.',
      ),
      c(
        'Invalid JSON response from Storage.GetRequest: <html>',
        SparkJoyErrorCode.serverBadResponse,
      ),
      c('HTTP 401 Unauthorized', SparkJoyErrorCode.authSession),
      // Кириллический текст без техничных маркеров = адресованное
      // пользователю сообщение бэка → показывается как есть, класс SRV-04.
      c(
        'совсем незнакомый текст ошибки',
        SparkJoyErrorCode.serverRejected,
        'совсем незнакомый текст ошибки',
      ),
      c('some totally unfamiliar error text', SparkJoyErrorCode.unknown),
    ];

    for (final testCase in cases) {
      test('«${testCase.raw}» → ${testCase.code}', () {
        final readable = sparkJoyReadableError(Exception(testCase.raw));
        expect(readable.code, testCase.code);
        expect(readable.supportText, contains('Код: ${testCase.code}'));
        if (testCase.message != null) {
          expect(readable.message, testCase.message);
        }
      });
    }

    test('backend rate-limit code maps to SRV-02, not SRV-04', () {
      final readable = sparkJoyReadableError(
        Exception(
          'Bad response from Storage.RunBatchLegalReview: '
          'too_many_requests',
        ),
      );
      expect(readable.code, SparkJoyErrorCode.serverRateLimited);
      expect(readable.supportText, contains('Код сервера: too_many_requests'));
    });
  });

  group('sparkJoyUploadSupportText', () {
    test('assembles full support block for the upload banner copy button', () {
      final text = sparkJoyUploadSupportText(
        code: SparkJoyErrorCode.netTimeout,
        message:
            'Сервер не ответил вовремя. Проверьте подключение и '
            'повторите.',
        technical:
            'ClientException with SocketException: HTTP connection timed out '
            'after 0:00:10.000000, host: app.carreports.ru, port: 443',
        reportNumber: 'REP-A743739',
        stage: 'Готовим отчёт на сервере (это может занять 1–3 минуты)…',
        timestamp: DateTime(2026, 7, 6, 19, 29),
      );
      expect(text, contains('Ошибка выгрузки отчёта'));
      expect(text, contains('Код: NET-02'));
      expect(text, contains('Сообщение: Сервер не ответил вовремя.'));
      expect(text, contains('Отчёт: REP-A743739'));
      expect(text, contains('Этап: Готовим отчёт на сервере'));
      expect(text, contains('Время: 2026-07-06T19:29'));
      expect(text, contains('Техническая ошибка: ClientException'));
    });

    test('omits empty context lines and falls back to UNK-01', () {
      final text = sparkJoyUploadSupportText(code: '', message: 'Сообщение');
      expect(text, contains('Код: UNK-01'));
      expect(text, isNot(contains('Отчёт:')));
      expect(text, isNot(contains('Этап:')));
      expect(text, isNot(contains('Время:')));
      expect(text, isNot(contains('Техническая ошибка:')));
    });
  });
}

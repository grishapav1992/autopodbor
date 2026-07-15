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

    test('live pending shape: responseNormalized="null" string stays pending', () {
      // GetBatchLegalReviewResults на проде отдаёт у неисполненных чеков
      // literal-строку 'null' (LEG-A423525, 2026-07-15) — это НЕ ответ.
      expect(
        legalReviewBatchPending(const [
          {'status': 'pending', 'responseNormalized': 'null'},
        ]),
        isTrue,
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
      // Точная строка с прода (батч LEG-A152604, 2026-07-15): пробел внутри
      // «p resent» — так отдаёт сам ApiCloud, матчим по 'forbidden symbols'.
      expect(
        sparkJoyHumanizeLegalCheckMessage(
          'gosNumber: forbidden symbols p resent',
        ),
        'Сервис проверки не принял госномер — нужен российский номер '
        'кириллицей и цифрами',
      );
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

  group('sparkJoyLegalCheckTypeHint (подзаголовок «ещё не сформировано»)', () {
    test('описание источника для каждого known-типа', () {
      expect(
        sparkJoyLegalCheckTypeHint('api_cloud_zalog_notary'),
        'Реестр уведомлений о залоге ФНП',
      );
      expect(
        sparkJoyLegalCheckTypeHint('api_cloud_zalog_fedresurs'),
        'Реестр договоров лизинга',
      );
      expect(
        sparkJoyLegalCheckTypeHint('api_cloud_gost_certificate'),
        'Официальные данные автомобиля',
      );
      expect(
        sparkJoyLegalCheckTypeHint('api_cloud_taxi_search'),
        'Признаки эксплуатации в такси',
      );
      expect(
        sparkJoyLegalCheckTypeHint('api_cloud_fgis_taxi_search'),
        'Реестр разрешений на такси',
      );
    });

    test('неизвестный тип — без подзаголовка, а не выдуманный текст', () {
      expect(sparkJoyLegalCheckTypeHint('api_cloud_brand_new_check'), '');
      expect(sparkJoyLegalCheckTypeHint(''), '');
    });
  });

  group('sparkJoyLegalRowTone (тон строки проверки)', () {
    test('found: true у рисковой проверки → тревожный тон', () {
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_zalog_notary',
          'status': 'found',
          'responseNormalized': '{"found": true, "count": 1}',
        }),
        SparkJoyLegalTone.found,
      );
    });

    test('status found без responseNormalized → находка, а не «чисто»', () {
      // Регресс: персистентность на бэке не атомарна — статус успевает
      // смениться раньше, чем запишется ответ, и чек в этот момент уже
      // считается терминальным (legalReviewBatchPending). Вью-модель, которая
      // смотрит только в responseNormalized, покажет зелёное «чисто» на
      // найденном залоге.
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_zalog_notary',
          'status': 'found',
        }),
        SparkJoyLegalTone.found,
      );
      expect(
        legalReviewBatchPending(const [
          {'checkType': 'api_cloud_zalog_notary', 'status': 'found'},
        ]),
        isFalse,
        reason: 'такой чек уже терминальный — вердикт с него будет показан',
      );
    });

    test('status found + пустой responseNormalized → находка', () {
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_zalog_notary',
          'status': 'found',
          'responseNormalized': '{}',
        }),
        SparkJoyLegalTone.found,
      );
    });

    test('ГОСТ со status found остаётся данными', () {
      // Информационные типы отсекаются раньше ветки находки.
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_gost_certificate',
          'status': 'found',
        }),
        SparkJoyLegalTone.data,
      );
    });

    test('found: false → чисто', () {
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_zalog_notary',
          'status': 'not_found',
          'responseNormalized': '{"found": false}',
        }),
        SparkJoyLegalTone.clean,
      );
    });

    test('ГОСТ с found: true — это данные, а не находка', () {
      // Регресс: наивное ветвление по `found` красило успешный сертификат в
      // оранжевый «найдено» и тащило его в баннер находок.
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_gost_certificate',
          'status': 'completed',
          'responseNormalized':
              '{"found": true, "certificate": [{"product": "TOYOTA"}]}',
        }),
        SparkJoyLegalTone.data,
      );
    });

    test('конвертер — тоже информационная проверка', () {
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_converter_search',
          'status': 'completed',
          'responseNormalized': '{"found": true, "vin": "XW7BF4FK00S123456"}',
        }),
        SparkJoyLegalTone.data,
      );
    });

    test('status failed → ошибка', () {
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_taxi_search',
          'status': 'failed',
        }),
        SparkJoyLegalTone.error,
      );
    });

    test('not_found + errorMessage → ошибка, а не «чисто»', () {
      // BACKEND_REQUESTS.md P1 баг 2: ApiCloud отвечает HTTP 200 на невалидный
      // вход, бэк отдаёт not_found. Отрапортовать «чисто» = соврать в пользу
      // автомобиля.
      expect(
        sparkJoyLegalRowTone(const {
          'checkType': 'api_cloud_fgis_taxi_search',
          'status': 'not_found',
          'responseNormalized': '{"found": false, "permit": null}',
          'errorMessage': 'gosNumber% forbidden symbols present',
        }),
        SparkJoyLegalTone.error,
      );
    });
  });

  group('sparkJoyLegalFoundBanner', () {
    const cleanZalog = {
      'checkType': 'api_cloud_zalog_notary',
      'status': 'not_found',
      'responseNormalized': '{"found": false}',
    };
    const foundZalog = {
      'checkType': 'api_cloud_zalog_notary',
      'status': 'found',
      'responseNormalized': '{"found": true, "count": 1}',
    };
    const failedTaxi = {
      'checkType': 'api_cloud_taxi_search',
      'status': 'failed',
      'errorMessage': 'timeout',
    };

    test('нет находок — баннера нет', () {
      expect(sparkJoyLegalFoundBanner(const [cleanZalog]), isNull);
      expect(sparkJoyLegalFoundBanner(const []), isNull);
    });

    test('одна находка среди чистых — с хвостом «остальные чистые»', () {
      expect(
        sparkJoyLegalFoundBanner(const [
          foundZalog,
          {
            'checkType': 'api_cloud_zalog_fedresurs',
            'status': 'not_found',
            'responseNormalized': '{"found": false}',
          },
        ]),
        'Найдено: Залог (реестр нотариусов) — остальные проверки чистые',
      );
    });

    test('находка + упавшая проверка — без хвоста: остальные не проверены', () {
      expect(
        sparkJoyLegalFoundBanner(const [foundZalog, failedTaxi]),
        'Найдено: Залог (реестр нотариусов)',
      );
    });

    test('несколько находок перечисляются', () {
      expect(
        sparkJoyLegalFoundBanner(const [
          foundZalog,
          {
            'checkType': 'api_cloud_zalog_fedresurs',
            'status': 'found',
            'responseNormalized': '{"found": true}',
          },
        ]),
        'Найдено: Залог (реестр нотариусов), Лизинг (Федресурс)',
      );
    });

    test('ГОСТ с данными не считается находкой', () {
      expect(
        sparkJoyLegalFoundBanner(const [
          cleanZalog,
          {
            'checkType': 'api_cloud_gost_certificate',
            'status': 'completed',
            'responseNormalized':
                '{"found": true, "certificate": [{"product": "TOYOTA"}]}',
          },
        ]),
        isNull,
      );
    });
  });

  group('legalReviewCheckHasBody (снимок гонки персиста)', () {
    test('терминальный статус без тела — нет body', () {
      // Живой кейс: поллинг застал status=success до записи responseNormalized;
      // такой снимок уходит в черновик и должен быть дочитан из батча.
      expect(
        legalReviewCheckHasBody(const {
          'checkType': 'api_cloud_gost_certificate',
          'status': 'success',
          'executedAt': '2026-06-25T19:28:11+00:00',
        }),
        isFalse,
      );
      expect(
        legalReviewCheckHasBody(const {'status': 'success', 'responseNormalized': '{}'}),
        isFalse,
      );
      expect(
        legalReviewCheckHasBody(const {'status': 'success', 'responseNormalized': 'null'}),
        isFalse,
      );
    });

    test('responseNormalized или errorMessage — body есть', () {
      expect(
        legalReviewCheckHasBody(const {
          'status': 'success',
          'responseNormalized': '{"found": true}',
        }),
        isTrue,
      );
      expect(
        legalReviewCheckHasBody(const {
          'status': 'error',
          'errorMessage': 'timeout',
        }),
        isTrue,
      );
    });
  });

  group('sparkJoyGostCertSummary (сводка сертификата в подзаголовке)', () {
    test('живая форма ответа ApiCloud → «марка модель · год · объём»', () {
      // Поля — из live-ответа батча LEG-A404259 (2026-06-25).
      expect(
        sparkJoyGostCertSummary(const {
          'VIN': 'WVGZZZ5NZLW359215',
          'product': 'VOLKSWAGEN',
          'tradename': 'TIGUAN',
          'yearofmanufacturing': '2020',
          'enginecylindersusefulcapacity': '1968 куб.см',
          'bodytype': 'универсал/5',
        }),
        'VOLKSWAGEN TIGUAN · 2020 · 2.0 л',
      );
    });

    test('частичные данные — без пустых сегментов', () {
      expect(
        sparkJoyGostCertSummary(const {'product': 'TOYOTA'}),
        'TOYOTA',
      );
      expect(
        sparkJoyGostCertSummary(const {
          'product': 'TOYOTA',
          'yearofmanufacturing': '-',
        }),
        'TOYOTA',
      );
    });

    test('пустой сертификат → пустая строка (фолбэк на общий текст)', () {
      expect(sparkJoyGostCertSummary(const {}), '');
    });
  });

  group('sparkJoyPluralBases / sparkJoyLegalCheckedSummary', () {
    test('склонение по русским правилам', () {
      expect(sparkJoyPluralBases(1), 'база');
      expect(sparkJoyPluralBases(2), 'базы');
      expect(sparkJoyPluralBases(4), 'базы');
      expect(sparkJoyPluralBases(5), 'баз');
      expect(sparkJoyPluralBases(11), 'баз');
      expect(sparkJoyPluralBases(14), 'баз');
      expect(sparkJoyPluralBases(21), 'база');
      expect(sparkJoyPluralBases(22), 'базы');
      expect(sparkJoyPluralBases(0), 'баз');
    });

    test('подпись завершённого прогона', () {
      expect(sparkJoyLegalCheckedSummary(5), 'Проверено · 5 баз');
      expect(sparkJoyLegalCheckedSummary(1), 'Проверено · 1 база');
    });
  });
}

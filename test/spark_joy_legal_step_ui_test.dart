import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_create_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/spark_test_harness.dart';

/// Черновик с уже приехавшими результатами проверок. Фазы «идёт проверка» и
/// «готово» разворачиваются целиком из черновика, без сети — в отличие от
/// «ещё не сформировано», где список строится из каталога типов, а он тянется
/// запросом (в тесте недоступен).
Map<String, dynamic> _draftWithChecks({
  required bool loaded,
  required List<Map<String, dynamic>> checks,
  bool timedOut = false,
}) {
  return <String, dynamic>{
    'vin': 'XW7BF4FK00S123456',
    'legalLoaded': loaded,
    // legalLoading в черновике не ставим: восстановленный «идёт проверка»
    // крутит спиннеры, до которых pumpAndSettle не досчитывается (а без
    // legalBatchNumber экран всё равно сразу переведёт его в таймаут).
    'legalLoading': false,
    'legalTimedOut': timedOut,
    'legalCheckResults': checks,
  };
}

const _zalogFound = {
  'checkType': 'api_cloud_zalog_notary',
  'status': 'found',
  'responseNormalized':
      '{"found": true, "count": 1, "message": "Найдена запись о залоге", '
      '"items": [{"pledgee": "ПАО «Банк ВТБ»", "date": "12.03.2023", '
      '"number": "2023-007-654321-001"}]}',
};

const _leasingClean = {
  'checkType': 'api_cloud_zalog_fedresurs',
  'status': 'not_found',
  'responseNormalized': '{"found": false}',
};

const _gostData = {
  'checkType': 'api_cloud_gost_certificate',
  'status': 'completed',
  'responseNormalized':
      '{"found": true, "certificate": [{"product": "TOYOTA", '
      '"tradename": "CAMRY", "yearofmanufacturing": "2019"}]}',
};

const _taxiPending = {
  'checkType': 'api_cloud_taxi_search',
  'status': 'pending',
};

/// [settle] = false для фазы «идёт проверка»: спиннеры крутятся бесконечно,
/// и pumpAndSettle до них не досчитывается.
Future<void> _openLegalSection(
  WidgetTester tester,
  Map<String, dynamic> draft, {
  bool settle = true,
  bool canRunReview = true,
}) async {
  Future<void> advance() async {
    if (settle) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Запуск проверок гейтится правом run_legal_review, которое экран читает из
  // кэша прав в prefs.
  await resetSparkPreferences(
    canRunReview
        ? const {
            'userPermissions': <String>['run_legal_review'],
          }
        : const <String, Object>{},
  );
  await tester.pumpWidget(
    wrapWithSparkHarness(
      size: const Size(800, 1600),
      child: SparkJoyCreateReportScreen(draft: draft),
    ),
  );
  await advance();
  await tester.tap(find.text('Материалы проверки').first);
  await advance();
}

void main() {
  testWidgets('готово: вердикты по строкам и подпись прогона', (tester) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(
        loaded: true,
        checks: const [_zalogFound, _leasingClean, _gostData],
      ),
    );

    expect(find.text('Проверено · 3 базы'), findsOneWidget);
    expect(find.text('Залог (реестр нотариусов)'), findsOneWidget);
    expect(find.text('Лизинг (Федресурс)'), findsOneWidget);
    expect(find.text('Сертификат ГОСТ'), findsOneWidget);
    // Вердикты: находка, чистая проверка и информационная.
    expect(find.text('найдено'), findsOneWidget);
    expect(find.text('чисто'), findsOneWidget);
    expect(find.text('данные'), findsOneWidget);
  });

  testWidgets('готово: находка выносится в баннер и раскрыта сразу', (
    tester,
  ) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(
        loaded: true,
        checks: const [_zalogFound, _leasingClean, _gostData],
      ),
    );

    // ГОСТ пришёл с found:true, но он информационный — в баннер попадает
    // только реальная находка.
    expect(
      find.text('Найдено: Залог (реестр нотариусов) — остальные проверки чистые'),
      findsOneWidget,
    );
    // Детали находки видны без тапа — ради них сюда и смотрят.
    expect(find.textContaining('ПАО «Банк ВТБ»'), findsOneWidget);
    // Чистая проверка остаётся свёрнутой.
    expect(find.textContaining('2023-007-654321-001'), findsOneWidget);
  });

  testWidgets('ГОСТ: сводка сертификата в подзаголовке, детали по тапу', (
    tester,
  ) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(loaded: true, checks: const [_gostData]),
    );

    // Вместо генерик-«Обнаружено» — сводка из сертификата.
    expect(find.text('TOYOTA CAMRY · 2019'), findsOneWidget);
    // Метка _gostRow несёт хвостовые пробелы ('$label  ') — ищем по вхождению.
    expect(find.textContaining('Марка/модель:'), findsNothing);

    await tester.tap(find.text('Сертификат ГОСТ'));
    await tester.pumpAndSettle();
    // Раскрытие показывает полные поля сертификата.
    expect(find.textContaining('Марка/модель:'), findsOneWidget);
    expect(find.text('TOYOTA CAMRY'), findsOneWidget);
    expect(find.textContaining('Год выпуска:'), findsOneWidget);
  });

  testWidgets('ГОСТ без результата: «нет данных» и подсказка про VIN', (
    tester,
  ) async {
    // Живой кейс: VIN с опечаткой OCR → ГОСТ вернул found:false. Раньше строка
    // показывала «данные» + «Данные получены» — пустота маскировалась под
    // непрочитанные данные.
    await _openLegalSection(
      tester,
      _draftWithChecks(
        loaded: true,
        checks: const [
          {
            'checkType': 'api_cloud_gost_certificate',
            'status': 'not_found',
            'responseNormalized': '{"found": false, "certificate": []}',
          },
        ],
      ),
    );

    expect(find.text('нет данных'), findsOneWidget);
    expect(find.text('данные'), findsNothing);
    expect(find.text('Данные получены'), findsNothing);
    expect(
      find.text('Сертификат в реестре не найден — проверьте VIN'),
      findsOneWidget,
    );
  });

  testWidgets('готово: детали сворачиваются тапом по строке', (tester) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(
        loaded: true,
        checks: const [_zalogFound, _leasingClean],
      ),
    );

    expect(find.textContaining('ПАО «Банк ВТБ»'), findsOneWidget);
    await tester.tap(find.text('Залог (реестр нотариусов)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ПАО «Банк ВТБ»'), findsNothing);
  });

  testWidgets('таймаут ApiCloud: текст сохранён, результаты видны', (
    tester,
  ) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(
        loaded: false,
        timedOut: true,
        checks: const [_zalogFound, _taxiPending],
      ),
    );

    expect(
      find.textContaining('ApiCloud ещё обрабатывает запросы'),
      findsOneWidget,
    );
    // Незавершённая строка показывает описание источника, а не выдуманный
    // вердикт.
    expect(find.text('Признаки эксплуатации в такси'), findsOneWidget);
    // Уже приехавший результат никуда не делся.
    expect(find.text('найдено'), findsOneWidget);
  });

  testWidgets('каталог не загрузился: запуск не предлагают, объясняют почему', (
    tester,
  ) async {
    // В виджет-тестах сети нет, поэтому каталог типов пуст — ровно то
    // состояние, в котором кнопка запуска отправила бы пустой список и
    // упёрлась в «Выберите хотя бы одну проверку».
    await _openLegalSection(
      tester,
      _draftWithChecks(loaded: false, checks: const [_zalogFound]),
    );

    expect(find.text('Сформировать материалы'), findsNothing);
    // Состояние каталога объяснено: «Загрузка списка проверок…», пока запрос
    // в полёте, либо «Не удалось загрузить…», когда он уже упал.
    final inFlight = find.text('Загрузка списка проверок…');
    final failed = find.textContaining('Не удалось загрузить список проверок');
    expect(
      inFlight.evaluate().isNotEmpty || failed.evaluate().isNotEmpty,
      isTrue,
      reason: 'пустой каталог должен быть объяснён, а не молчать',
    );
    // Уже оплаченные результаты показываются независимо от каталога.
    expect(find.text('Залог (реестр нотариусов)'), findsOneWidget);
  });

  testWidgets('готово без каталога: «Обновить» есть, но не активна', (
    tester,
  ) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(loaded: true, checks: const [_zalogFound]),
    );

    final refresh = find.text('Обновить');
    expect(refresh, findsOneWidget);
    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: refresh, matching: find.byType(InkWell)).first,
    );
    expect(
      inkWell.onTap,
      isNull,
      reason: 'без каталога повтор упёрся бы в «Выберите хотя бы одну проверку»',
    );
  });

  testWidgets('упавшая проверка не рапортует «чисто»', (tester) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(
        loaded: true,
        checks: const [
          {
            'checkType': 'api_cloud_fgis_taxi_search',
            'status': 'not_found',
            'responseNormalized': '{"found": false, "permit": null}',
            'errorMessage': 'gosNumber% forbidden symbols present',
          },
        ],
      ),
    );

    expect(find.text('ошибка'), findsOneWidget);
    expect(find.text('чисто'), findsNothing);
    // Сырой английский текст ApiCloud переведён.
    expect(
      find.textContaining('Сервис проверки не принял госномер'),
      findsOneWidget,
    );
  });

  testWidgets('без права run_legal_review: запуск скрыт, материалы видны', (
    tester,
  ) async {
    await _openLegalSection(
      tester,
      _draftWithChecks(loaded: true, checks: const [_zalogFound, _gostData]),
      canRunReview: false,
    );

    expect(find.textContaining('Недостаточно прав'), findsOneWidget);
    expect(find.text('Сформировать материалы'), findsNothing);
    expect(find.text('Обновить'), findsNothing);
    // Просмотр уже оплаченных материалов права на запуск не требует.
    expect(find.text('Залог (реестр нотариусов)'), findsOneWidget);
    expect(find.text('найдено'), findsOneWidget);
    expect(find.textContaining('ПАО «Банк ВТБ»'), findsOneWidget);
  });
}

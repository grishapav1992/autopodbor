import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_vin_params_ai.dart';

/// Человекочитаемое русское название типа ApiCloud-проверки по стабильному
/// `value` (бэк в `name` отдаёт техничный PascalCase: `ApiCloudZalogNotary`).
///
/// Единый источник истины для шага «Материалы проверки»
/// (`spark_joy_step_legal.dart`) и ленты уведомлений
/// (`spark_joy_notifications_screen.dart`) — чтобы названия проверок не
/// расходились между двумя экранами.
///
/// Неизвестный тип — мягкий фолбэк: убрать префикс `api_cloud_`, `_`→пробел,
/// первая буква заглавная; если пусто — вернуть исходный `value`.
String sparkJoyLegalCheckTypeLabel(String value) {
  switch (value) {
    case 'api_cloud_zalog_notary':
      return 'Залог (реестр нотариусов)';
    case 'api_cloud_zalog_fedresurs':
      return 'Лизинг (Федресурс)';
    case 'api_cloud_gost_certificate':
      return 'Сертификат ГОСТ';
    case 'api_cloud_taxi_search':
      return 'Работа в такси';
    case 'api_cloud_fgis_taxi_search':
      return 'Разрешение такси (ФГИС)';
    case 'api_cloud_converter_search':
      return 'Определение по VIN/госномеру';
    default:
      final cleaned = value
          .replaceFirst('api_cloud_', '')
          .replaceAll('_', ' ')
          .trim();
      if (cleaned.isEmpty) return value;
      return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

/// Короткое описание источника проверки — подзаголовок строки в состоянии
/// «ещё не сформировано», где результата нет и сказать по строке нечего.
/// Неизвестный тип → `''` (строка останется без подзаголовка).
String sparkJoyLegalCheckTypeHint(String value) {
  switch (value) {
    case 'api_cloud_zalog_notary':
      return 'Реестр уведомлений о залоге ФНП';
    case 'api_cloud_zalog_fedresurs':
      return 'Реестр договоров лизинга';
    case 'api_cloud_gost_certificate':
      return 'Официальные данные автомобиля';
    case 'api_cloud_taxi_search':
      return 'Признаки эксплуатации в такси';
    case 'api_cloud_fgis_taxi_search':
      return 'Реестр разрешений на такси';
    case 'api_cloud_converter_search':
      return 'Идентификация автомобиля';
    default:
      return '';
  }
}

/// Смысловой тон результата проверки — им красится строка списка «Материалов
/// проверки» (бейдж, вердикт, рамка).
enum SparkJoyLegalTone {
  /// Риск не найден: залога/лизинга/такси нет.
  clean,

  /// Риск найден — единственный тон, требующий внимания.
  found,

  /// Проверка информационная: приносит данные, а не вердикт (ГОСТ, конвертер).
  data,

  /// Проверка не выполнилась.
  error,
}

/// Проверки, которые НЕ выносят вердикт «чисто/найдено», а просто приносят
/// данные об автомобиле. Для них `found: true` означает «данные получены»
/// (сертификат ГОСТ найден — это норма, а не проблема), поэтому их нужно
/// отсекать ДО ветки `found`, иначе успешный ГОСТ покрасится в тревожный
/// оранжевый и попадёт в баннер находок.
const _sparkJoyInformationalChecks = <String>{
  'api_cloud_gost_certificate',
  'api_cloud_converter_search',
};

/// Тон одного чека из `legalCheckResults` (ключи `checkType` / `status` /
/// `responseNormalized` / `errorMessage`).
///
/// Ошибка проверяется первой: ApiCloud отвечает HTTP 200 на невалидный вход, и
/// бэк отдаёт такой чек со статусом `not_found` (см. BACKEND_REQUESTS.md, P1
/// баг 2) — без приоритета ошибки провалившаяся проверка отрапортовала бы
/// «чисто», то есть соврала бы в пользу автомобиля.
///
/// Находку признаём по ЛЮБОМУ из двух источников — `status == 'found'` и
/// `responseNormalized.found == true`. Они рассинхронизированы by design:
/// персистентность на бэке не атомарна (см. `legalReviewBatchPending` в
/// storage_api), поэтому статус успевает смениться раньше, чем запишется
/// ответ, — а чек в этот момент уже считается терминальным. Если смотреть
/// только в `responseNormalized`, найденный залог покажется «чистым».
SparkJoyLegalTone sparkJoyLegalRowTone(Map<String, dynamic> check) {
  final status = (check['status'] ?? '').toString().trim().toLowerCase();
  final errorMessage = (check['errorMessage'] ?? '').toString().trim();
  if (status == 'error' || status == 'failed' || errorMessage.isNotEmpty) {
    return SparkJoyLegalTone.error;
  }
  final type = (check['checkType'] ?? '').toString();
  if (_sparkJoyInformationalChecks.contains(type)) {
    return SparkJoyLegalTone.data;
  }
  if (status == 'found' ||
      gostBoolField(check['responseNormalized'], 'found') == true) {
    return SparkJoyLegalTone.found;
  }
  return SparkJoyLegalTone.clean;
}

/// Информационная проверка, у которой провайдер явно ответил «не найдено»
/// (`found: false`): данных нет. Живой кейс — ГОСТ по VIN с опечаткой OCR
/// (`…NZ1W…` вместо `…NZLW…`) вернул `{"found": false, "certificate": []}`,
/// а строка показывала вердикт «данные» с подписью «Данные получены» — пустота
/// маскировалась под «данные есть, но не открываются».
bool sparkJoyLegalDataEmpty(Map<String, dynamic> check) {
  final type = (check['checkType'] ?? '').toString();
  if (!_sparkJoyInformationalChecks.contains(type)) return false;
  return gostBoolField(check['responseNormalized'], 'found') == false;
}

/// Короткий вердикт справа в строке проверки. [dataEmpty] — информационная
/// проверка без результата (см. [sparkJoyLegalDataEmpty]).
String sparkJoyLegalVerdictLabel(
  SparkJoyLegalTone tone, {
  bool dataEmpty = false,
}) {
  switch (tone) {
    case SparkJoyLegalTone.clean:
      return 'чисто';
    case SparkJoyLegalTone.found:
      return 'найдено';
    case SparkJoyLegalTone.data:
      return dataEmpty ? 'нет данных' : 'данные';
    case SparkJoyLegalTone.error:
      return 'ошибка';
  }
}

/// Текст баннера над списком, когда хоть одна проверка что-то нашла. Нет
/// находок → `null` (баннер не рендерится).
///
/// Хвост «остальные проверки чистые» дописывается, только если остальные и
/// правда чистые: при упавшей проверке мы этого не знаем и молчим.
String? sparkJoyLegalFoundBanner(List<Map<String, dynamic>> results) {
  final found = <String>[];
  var hasError = false;
  for (final check in results) {
    switch (sparkJoyLegalRowTone(check)) {
      case SparkJoyLegalTone.found:
        found.add(sparkJoyLegalCheckTypeLabel((check['checkType'] ?? '').toString()));
      case SparkJoyLegalTone.error:
        hasError = true;
      case SparkJoyLegalTone.clean:
      case SparkJoyLegalTone.data:
        break;
    }
  }
  if (found.isEmpty) return null;
  final head = 'Найдено: ${found.join(', ')}';
  final others = results.length - found.length;
  if (others > 0 && !hasError) return '$head — остальные проверки чистые';
  return head;
}

/// Компактная сводка ГОСТ-сертификата для подзаголовка строки проверки
/// («VOLKSWAGEN TIGUAN · 2020 · 2.0 л») — как в макете. Универсальное
/// «Обнаружено» для информационной проверки звучало как находка риска и не
/// говорило ничего; полные поля сертификата остаются в раскрытии строки.
/// Нечего показать → `''` (вызывающий падает на общий текст).
String sparkJoyGostCertSummary(Map<String, dynamic> cert) {
  String f(String k) {
    final v = (cert[k] ?? '').toString().trim();
    return v == '-' ? '' : v;
  }

  final parts = <String>[];
  final markModel = [
    f('product'),
    f('tradename'),
  ].where((s) => s.isNotEmpty).join(' ');
  if (markModel.isNotEmpty) parts.add(markModel);
  final year = f('yearofmanufacturing');
  if (year.isNotEmpty) parts.add(year);
  final cc = int.tryParse(
    RegExp(r'\d+').firstMatch(f('enginecylindersusefulcapacity'))?.group(0) ??
        '',
  );
  if (cc != null && cc > 0) parts.add('${(cc / 1000).toStringAsFixed(1)} л');
  return parts.join(' · ');
}

/// «Проверено · 5 баз» — подпись под завершённым прогоном.
String sparkJoyLegalCheckedSummary(int count) =>
    'Проверено · $count ${sparkJoyPluralBases(count)}';

/// Склонение «база» для русского счёта (1 база, 2 базы, 5 баз, 11 баз).
String sparkJoyPluralBases(int n) {
  final abs = n.abs();
  final mod10 = abs % 10;
  final mod100 = abs % 100;
  if (mod10 == 1 && mod100 != 11) return 'база';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'базы';
  return 'баз';
}

/// Переводит сырое сообщение провайдера проверки (ApiCloud → бэк пробрасывает
/// его в `responseNormalized.message` / `errorMessage` как есть) в понятный
/// русский текст. Живой пример: «gosNumber% forbidden symbols present» —
/// ответ ApiCloud на пустой/невалидный госномер, в таком виде он доходил до
/// пользователя (репорт 2026-07-15).
///
/// `errorMessage` бэк собирает как «ExceptionClass | текст | /path/file.php:123»
/// (`ApiCloudLegalReviewProvider::formatErrorMessage`) — технические части
/// отбрасываем, неизвестный текст возвращаем как есть.
String sparkJoyHumanizeLegalCheckMessage(String raw) {
  var message = raw.trim();
  if (message.isEmpty) return '';
  if (message.contains(' | ')) {
    final human = message
        .split(' | ')
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty &&
              // PHP-класс исключения: App\Workerman\…\ApiCloudException.
              !RegExp(r'^[A-Za-z0-9_\\]+(Exception|Error)$').hasMatch(part) &&
              // Файл и строка: /var/www/src/….php:123.
              !RegExp(r'\.php:\d+$').hasMatch(part),
        )
        .toList();
    if (human.isNotEmpty) message = human.join(' | ');
  }
  final lower = message.toLowerCase();
  if (lower.contains('forbidden symbols')) {
    return 'Сервис проверки не принял госномер — нужен российский номер '
        'кириллицей и цифрами';
  }
  if (lower.contains('curl') ||
      lower.contains('timeout') ||
      lower.contains('timed out')) {
    return 'Сервис проверки не ответил вовремя — попробуйте позже';
  }
  return message;
}

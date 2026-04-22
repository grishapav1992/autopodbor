/// Модели ответа api-cloud.ru/converter (Конвертер VIN ↔ ГРЗ).
///
/// Схема: https://api-cloud.ru/converter
///
/// Один endpoint с type=search сам определяет, что на входе — VIN или
/// ГРЗ, и отдаёт оба значения плюс базовые данные авто. Повторного
/// запроса «в обратную сторону» не нужно.
library;

import 'api_cloud_errors.dart';

export 'api_cloud_errors.dart' show ApiCloudErrorKind;

/// Что мы послали в API.
enum ConverterQueryKind { vin, plate }

/// Результат конвертации. Если `found` = false, поля пустые.
///
/// `raw` сохраняем целиком — чтобы при расширении UI (например,
/// показать `body`/`chassis`) не надо было снова ходить в API.
class ConverterResult {
  const ConverterResult({
    required this.found,
    required this.brand,
    required this.model,
    required this.year,
    required this.vin,
    required this.regNumber,
    required this.body,
    required this.chassis,
    required this.raw,
  });

  /// Пустой (not-found) результат — удобно в мок-клиенте и при
  /// обработке `partner.found = false`.
  const ConverterResult.empty(this.raw)
      : found = false,
        brand = '',
        model = '',
        year = 0,
        vin = '',
        regNumber = '',
        body = '',
        chassis = '';

  final bool found;
  final String brand;
  final String model;
  /// 0 если API не вернул год.
  final int year;
  final String vin;
  /// ГРЗ в том виде, как вернул API (обычно кириллица).
  final String regNumber;
  final String body;
  final String chassis;
  final Map<String, dynamic> raw;

  /// Объединённая строка «BRAND MODEL» для UI, когда нет по отдельности.
  String get brandModel {
    if (brand.isEmpty && model.isEmpty) return '';
    return '$brand $model'.trim();
  }

  /// Разбирает ответ `/api/converter.php`. Структура:
  /// `{status, partner: {status, found, result: {brand, model, year, vin, regNumber, body, chassis}}, inquiry: {...}}`.
  ///
  /// Ошибку формата `{"error":"...","errormsg":"..."}` здесь НЕ обрабатываем —
  /// это ответственность HTTP-клиента (он бросит [ConverterException]).
  factory ConverterResult.fromJson(Map<String, dynamic> json) {
    final partnerRaw = json['partner'];
    if (partnerRaw is! Map) {
      return ConverterResult.empty(Map<String, dynamic>.from(json));
    }
    final partner = Map<String, dynamic>.from(partnerRaw);
    final found = partner['found'] == true;
    final resultRaw = partner['result'];
    final result = resultRaw is Map
        ? Map<String, dynamic>.from(resultRaw)
        : const <String, dynamic>{};

    if (!found || result.isEmpty) {
      return ConverterResult.empty(Map<String, dynamic>.from(json));
    }

    return ConverterResult(
      found: true,
      brand: _str(result['brand']),
      model: _str(result['model']),
      year: _toInt(result['year']) ?? 0,
      vin: _str(result['vin']),
      regNumber: _str(result['regNumber']),
      body: _str(result['body']),
      chassis: _str(result['chassis']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

/// Ошибка converter-запроса. Коды общие для api-cloud.ru
/// (см. `api_cloud_errors.dart`); доменно-специфичных у converter'а нет.
class ConverterException implements Exception {
  ConverterException(this.code, this.message)
      : kind = kindForApiCloudCode(code);

  final String code;
  final String message;
  final ApiCloudErrorKind kind;

  /// Сообщение для UI (ru). Admin-ошибки обёрнуты доменным текстом,
  /// чтобы юзер понимал, что именно недоступно.
  String get userMessage {
    switch (kind) {
      case ApiCloudErrorKind.userInput:
        return _userInputMessage(code);
      case ApiCloudErrorKind.transient:
        return transientMessageForApiCloudCode(code);
      case ApiCloudErrorKind.admin:
        return 'Автоподбор данных по VIN/ГРЗ временно недоступен. '
            'Введите данные вручную.';
    }
  }

  /// Для логов / будущей админ-панели.
  String get diagnosticMessage => '[$code] $message';

  @override
  String toString() => 'ConverterException($code, kind=$kind): $message';

  static String _userInputMessage(String code) {
    switch (code) {
      case '888':
        return 'Недопустимые символы в VIN или госномере';
      default:
        return sharedUserInputMessage(code);
    }
  }
}

// ─── helpers ────────────────────────────────────────────────────────────

String _str(dynamic v) {
  if (v == null) return '';
  return v.toString();
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString();
  return int.tryParse(s);
}

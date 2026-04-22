/// Модели ответа api-cloud.ru/pb_nalog (ФНС «Прозрачный бизнес»).
///
/// Схема: https://api-cloud.ru/pb_nalog
///
/// Здесь только типы и разбор JSON. Сетевая часть — в [PbNalogApiHttp],
/// тестовый мок — в [PbNalogApiMock] (файл `pb_nalog_api.dart`).
library;

/// Тип субъекта.
enum PbNalogKind { ip, organization, unknown }

/// Статус регистрации. Сливает statusIP (0/1) и statusORG (0..5)
/// в один enum, чтобы UI работал единообразно независимо от типа.
enum PbNalogStatus {
  active,
  terminated,
  bankruptcy,
  exclusion,
  reorganization,
  liquidation,
  unknown,
}

/// `statusIP`: 1 = действующий, 0 = прекращён.
PbNalogStatus pbNalogStatusFromIp(dynamic raw) {
  final code = _toInt(raw);
  switch (code) {
    case 1:
      return PbNalogStatus.active;
    case 0:
      return PbNalogStatus.terminated;
    default:
      return PbNalogStatus.unknown;
  }
}

/// `statusORG`: 0..5. См. раздел 9 документации.
PbNalogStatus pbNalogStatusFromOrg(dynamic raw) {
  final code = _toInt(raw);
  switch (code) {
    case 0:
      return PbNalogStatus.terminated;
    case 1:
      return PbNalogStatus.active;
    case 2:
      return PbNalogStatus.bankruptcy;
    case 3:
      return PbNalogStatus.exclusion;
    case 4:
      return PbNalogStatus.reorganization;
    case 5:
      return PbNalogStatus.liquidation;
    default:
      return PbNalogStatus.unknown;
  }
}

/// Стабильный строковый ключ статуса для сериализации в SharedPreferences
/// и другие persistent-хранилища.
///
/// Отвязан от `enum.name`, чтобы рефакторинг значений enum'а
/// (например, переименование `active` → `operational`) не ломал
/// уже сохранённые записи на устройствах пользователей. Пары
/// enum↔string зафиксированы и проверяются в unit-тестах.
String pbNalogStatusToStorageKey(PbNalogStatus status) {
  switch (status) {
    case PbNalogStatus.active:
      return 'active';
    case PbNalogStatus.terminated:
      return 'terminated';
    case PbNalogStatus.bankruptcy:
      return 'bankruptcy';
    case PbNalogStatus.exclusion:
      return 'exclusion';
    case PbNalogStatus.reorganization:
      return 'reorganization';
    case PbNalogStatus.liquidation:
      return 'liquidation';
    case PbNalogStatus.unknown:
      return 'unknown';
  }
}

/// Обратная конверсия. Неизвестные/старые ключи → [PbNalogStatus.unknown],
/// чтобы UI корректно отрисовал серый чип и не падал при апгрейде.
PbNalogStatus pbNalogStatusFromStorageKey(String key) {
  switch (key) {
    case 'active':
      return PbNalogStatus.active;
    case 'terminated':
      return PbNalogStatus.terminated;
    case 'bankruptcy':
      return PbNalogStatus.bankruptcy;
    case 'exclusion':
      return PbNalogStatus.exclusion;
    case 'reorganization':
      return PbNalogStatus.reorganization;
    case 'liquidation':
      return PbNalogStatus.liquidation;
    default:
      return PbNalogStatus.unknown;
  }
}

/// Короткий человекочитаемый ярлык статуса (RU).
String pbNalogStatusLabel(PbNalogStatus status) {
  switch (status) {
    case PbNalogStatus.active:
      return 'Действующий';
    case PbNalogStatus.terminated:
      return 'Деятельность прекращена';
    case PbNalogStatus.bankruptcy:
      return 'Банкротство';
    case PbNalogStatus.exclusion:
      return 'В процессе исключения';
    case PbNalogStatus.reorganization:
      return 'Реорганизация';
    case PbNalogStatus.liquidation:
      return 'Ликвидация';
    case PbNalogStatus.unknown:
      return 'Статус неизвестен';
  }
}

/// Одна запись по ИП (`search_ip`).
class PbNalogIpEntry {
  const PbNalogIpEntry({
    required this.ogrn,
    required this.inn,
    required this.okved,
    required this.okvedName,
    required this.name,
    required this.dateReg,
    required this.status,
    required this.statusDesc,
    required this.participatesInEdo,
    required this.raw,
  });

  final String ogrn;
  final String inn;
  final String okved;
  final String okvedName;
  /// ФИО предпринимателя.
  final String name;
  final String dateReg;
  final PbNalogStatus status;
  final String statusDesc;
  final bool participatesInEdo;
  final Map<String, dynamic> raw;

  factory PbNalogIpEntry.fromJson(Map<String, dynamic> json) {
    return PbNalogIpEntry(
      ogrn: _str(json['ogrn']),
      inn: _str(json['inn']),
      okved: _str(json['okved']),
      okvedName: _str(json['okved_name']),
      name: _str(json['name']),
      dateReg: _str(json['dateReg']),
      status: pbNalogStatusFromIp(json['statusIP']),
      statusDesc: _str(json['statusIPDesc']),
      participatesInEdo: _str(json['edo']).trim().isNotEmpty,
      raw: Map<String, dynamic>.from(json),
    );
  }
}

/// Одна запись по юрлицу (`search_org`).
///
/// Сохраняем полный `raw` JSON — большинство полей (masruk, arrear,
/// taxpay, taxlist, employeeslist, okvedList) нам пока не нужно
/// отображать, но пригодится в следующей итерации UI.
class PbNalogOrgEntry {
  const PbNalogOrgEntry({
    required this.ogrn,
    required this.inn,
    required this.kpp,
    required this.fullName,
    required this.shortName,
    required this.region,
    required this.address,
    required this.dateReg,
    required this.status,
    required this.statusDesc,
    required this.participatesInEdo,
    required this.okved,
    required this.okvedName,
    required this.raw,
  });

  final String ogrn;
  final String inn;
  final String kpp;
  final String fullName;
  final String shortName;
  final String region;
  final String address;
  final String dateReg;
  final PbNalogStatus status;
  final String statusDesc;
  final bool participatesInEdo;
  final String okved;
  final String okvedName;
  final Map<String, dynamic> raw;

  factory PbNalogOrgEntry.fromJson(Map<String, dynamic> json) {
    return PbNalogOrgEntry(
      ogrn: _str(json['ogrn']),
      inn: _str(json['inn']),
      kpp: _str(json['kpp']),
      fullName: _str(json['name']),
      shortName: _str(json['abbreviated_name']),
      region: _str(json['region']),
      address: _str(json['adress']),
      dateReg: _str(json['dateReg']),
      status: pbNalogStatusFromOrg(json['statusORG']),
      statusDesc: _str(json['statusORGDesc']),
      participatesInEdo: _str(json['edo']).trim().isNotEmpty,
      okved: _str(json['okved']),
      okvedName: _str(json['okved_name']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

/// Итог запроса к pb_nalog — обёртка над IP или Org ответом.
///
/// [raw] — весь оригинальный JSON; сохраняется, чтобы экран профиля
/// мог позже вытащить дополнительные поля (учредители, недоимки),
/// не меняя эту модель.
class PbNalogResult {
  const PbNalogResult({
    required this.kind,
    required this.found,
    required this.count,
    required this.ipEntries,
    required this.orgEntries,
    required this.raw,
  });

  final PbNalogKind kind;
  final bool found;
  final int count;
  final List<PbNalogIpEntry> ipEntries;
  final List<PbNalogOrgEntry> orgEntries;
  final Map<String, dynamic> raw;

  /// Основная запись для UI: первая активная, иначе просто первая.
  PbNalogIpEntry? get primaryIp {
    if (ipEntries.isEmpty) return null;
    for (final e in ipEntries) {
      if (e.status == PbNalogStatus.active) return e;
    }
    return ipEntries.first;
  }

  PbNalogOrgEntry? get primaryOrg {
    if (orgEntries.isEmpty) return null;
    for (final e in orgEntries) {
      if (e.status == PbNalogStatus.active) return e;
    }
    return orgEntries.first;
  }

  /// Разбор ответа. Тип определяется по наличию `statusIP`/`statusORG`
  /// в первой записи `data[]`, что совпадает с тем, какой `type`
  /// запрашивали (search_ip vs search_org) — но мы проверяем
  /// реальные поля, а не полагаемся на параметр запроса.
  factory PbNalogResult.fromJson(Map<String, dynamic> json) {
    final found = json['found'] == true;
    final count = _toInt(json['count']) ?? 0;
    final rawData = json['data'];
    final data = rawData is List ? rawData : const <dynamic>[];

    final ipEntries = <PbNalogIpEntry>[];
    final orgEntries = <PbNalogOrgEntry>[];
    PbNalogKind kind = PbNalogKind.unknown;

    for (final item in data) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      if (m.containsKey('statusIP')) {
        ipEntries.add(PbNalogIpEntry.fromJson(m));
        kind = PbNalogKind.ip;
      } else if (m.containsKey('statusORG')) {
        orgEntries.add(PbNalogOrgEntry.fromJson(m));
        kind = PbNalogKind.organization;
      }
    }

    return PbNalogResult(
      kind: kind,
      found: found,
      count: count,
      ipEntries: ipEntries,
      orgEntries: orgEntries,
      raw: Map<String, dynamic>.from(json),
    );
  }
}

/// Категория ошибки pb_nalog — определяет, что показывать в UI.
///
/// Разделение нужно, чтобы юзер в приложении не видел внутренние
/// проблемы интеграции («закончились деньги на балансе», «токен
/// заблокирован»). Он получает общий «сервис недоступен», а полные
/// коды и сообщения уходят в логи и в будущую админ-панель.
enum PbNalogErrorKind {
  /// Юзер сам может исправить — неверный формат ИНН, запрещённые
  /// символы. Показываем конкретно в UI.
  userInput,

  /// Транзиентное — сеть/таймаут/rate-limit. «Попробуйте позже».
  transient,

  /// Наша конфигурация/биллинг/доступ — пользователь ничего не
  /// сделает. UI показывает «проверка временно недоступна», детали
  /// в [diagnosticMessage] для логов и админки.
  admin,
}

/// Ошибка pb_nalog-запроса с кодом (строка — чтобы сохранить
/// оригинальные значения из API, в т.ч. «331», «498»).
///
/// Для UI используйте [userMessage]. Для логов и админ-панели —
/// [diagnosticMessage] (содержит код и технический текст от API).
class PbNalogException implements Exception {
  PbNalogException(this.code, this.message)
      : kind = _kindFor(code);

  final String code;
  final String message;
  final PbNalogErrorKind kind;

  /// Сообщение для конечного юзера (ru). Для [PbNalogErrorKind.admin]
  /// возвращает намеренно обобщённый текст.
  String get userMessage {
    switch (kind) {
      case PbNalogErrorKind.userInput:
        return _userInputMessage(code);
      case PbNalogErrorKind.transient:
        return _transientMessage(code);
      case PbNalogErrorKind.admin:
        return 'Проверка ИНН временно недоступна. Попробуйте позже.';
    }
  }

  /// Расшифровка для логов и будущей админки — с кодом и оригинальным
  /// message. НЕ показывать пользователю.
  String get diagnosticMessage => '[$code] $message';

  @override
  String toString() => 'PbNalogException($code, kind=$kind): $message';

  static PbNalogErrorKind _kindFor(String code) {
    switch (code) {
      case '331':
      case '332':
      case '888':
        return PbNalogErrorKind.userInput;
      case '404':
      case '456':
      case 'net_offline':
        return PbNalogErrorKind.transient;
      case '498':
      case '499':
      case '500':
      case '502':
      case '503':
      case '504':
      case '602':
      case '766':
      case '1':
      case '2':
      case '3':
        return PbNalogErrorKind.admin;
      default:
        // Неизвестный код трактуем как admin — пусть разбирается тот,
        // кто читает логи. Пользователю никаких технических деталей.
        return PbNalogErrorKind.admin;
    }
  }

  static String _userInputMessage(String code) {
    switch (code) {
      case '331':
      case '332':
        return 'Неверный формат ИНН';
      case '888':
        return 'Недопустимые символы в ИНН';
      default:
        return 'Проверьте ИНН и попробуйте снова';
    }
  }

  static String _transientMessage(String code) {
    switch (code) {
      case '404':
        return 'Источник ФНС не ответил. Попробуйте ещё раз через пару минут.';
      case '456':
        return 'Слишком много запросов подряд. Попробуйте через минуту.';
      case 'net_offline':
        return 'Нет подключения к интернету. Проверьте сеть и попробуйте снова.';
      default:
        return 'Сервис проверки сейчас занят. Попробуйте ещё раз.';
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

// Data classes returned by the JSON-RPC endpoints exposed by [StorageApi].
//
// This file exists to keep [storage_api.dart] focused on RPC plumbing —
// the 22 public classes below used to live there and accounted for the
// first ~270 lines of the file. Splitting them out makes both files
// easier to navigate without changing the import surface: `storage_api.dart`
// re-exports this file, so callers can keep writing
// `import 'package:.../storage_api.dart';` and get every model + the API
// class in one go.
//
// No RPC logic or private class lives here. Two private helpers
// (`_CreateRequestCacheEntry`, `_TokenPair`) remain in storage_api.dart
// because they are implementation details of the StorageApi class.

import 'package:flutter/foundation.dart';

class BrandCatalog {
  final List<BrandItem> items;
  final List<String> names;
  final Map<String, String> rusByName;
  final Map<String, int> idByName;

  BrandCatalog({
    required this.items,
    required this.names,
    required this.rusByName,
    required this.idByName,
  });
}

class BrandItem {
  final int id;
  final String name;
  final String nameRus;

  BrandItem({required this.id, required this.name, required this.nameRus});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'nameRus': nameRus};

  static BrandItem? tryFromJson(dynamic raw) {
    final map = _catalogJsonMap(raw);
    final id = _catalogJsonInt(map['id']);
    if (id == null) return null;
    return BrandItem(
      id: id,
      name: _catalogJsonString(map['name']),
      nameRus: _catalogJsonString(map['nameRus']),
    );
  }
}

class ModelItem {
  final int id;
  final int brandId;
  final String model;
  final String modelRus;

  ModelItem({
    required this.id,
    required this.brandId,
    required this.model,
    required this.modelRus,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'brandId': brandId,
    'model': model,
    'modelRus': modelRus,
  };

  static ModelItem? tryFromJson(dynamic raw) {
    final map = _catalogJsonMap(raw);
    final id = _catalogJsonInt(map['id']);
    final brandId = _catalogJsonInt(map['brandId']);
    if (id == null || brandId == null) return null;
    return ModelItem(
      id: id,
      brandId: brandId,
      model: _catalogJsonString(map['model']),
      modelRus: _catalogJsonString(map['modelRus']),
    );
  }
}

class FrameItem {
  final int id;
  final String frame;

  FrameItem({required this.id, required this.frame});

  Map<String, dynamic> toJson() => {'id': id, 'frame': frame};

  static FrameItem? tryFromJson(dynamic raw) {
    final map = _catalogJsonMap(raw);
    final id = _catalogJsonInt(map['id']);
    if (id == null) return null;
    return FrameItem(id: id, frame: _catalogJsonString(map['frame']));
  }
}

class PhotoItem {
  final int id;
  final String size;
  final String urlX1;
  final String urlX2;

  PhotoItem({
    required this.id,
    required this.size,
    required this.urlX1,
    required this.urlX2,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'size': size,
    'urlX1': urlX1,
    'urlX2': urlX2,
  };

  static PhotoItem? tryFromJson(dynamic raw) {
    final map = _catalogJsonMap(raw);
    final id = _catalogJsonInt(map['id']);
    if (id == null) return null;
    return PhotoItem(
      id: id,
      size: _catalogJsonString(map['size']),
      urlX1: _catalogJsonString(map['urlX1']),
      urlX2: _catalogJsonString(map['urlX2']),
    );
  }
}

class RestylingItem {
  final int id;
  final String restyling;
  final int? yearStart;
  final int? yearEnd;
  final List<FrameItem> frames;
  final List<PhotoItem> photos;

  RestylingItem({
    required this.id,
    required this.restyling,
    required this.yearStart,
    required this.yearEnd,
    required this.frames,
    required this.photos,
  });

  /// Годовой диапазон рестайлинга в том же формате, что и у поколения
  /// («2020–2022» / «с 2020» / «по 2022»). `null`, если годов нет.
  String? get yearRange {
    final s = yearStart;
    final e = yearEnd;
    if (s != null && e != null) return e > s ? '$s–$e' : '$s';
    if (s != null) return 'с $s';
    if (e != null) return 'по $e';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'restyling': restyling,
    'yearStart': yearStart,
    'yearEnd': yearEnd,
    'frames': frames.map((f) => f.toJson()).toList(growable: false),
    'photos': photos.map((p) => p.toJson()).toList(growable: false),
  };

  static RestylingItem? tryFromJson(dynamic raw) {
    final map = _catalogJsonMap(raw);
    final id = _catalogJsonInt(map['id']);
    if (id == null) return null;
    return RestylingItem(
      id: id,
      restyling: _catalogJsonString(map['restyling']),
      yearStart: _catalogJsonYear(map['yearStart']),
      yearEnd: _catalogJsonYear(map['yearEnd']),
      frames: _catalogJsonList(map['frames'], FrameItem.tryFromJson),
      photos: _catalogJsonList(map['photos'], PhotoItem.tryFromJson),
    );
  }
}

class GenerationItem {
  final int id;
  final int modelCarId;
  final int generation;
  final List<FrameItem> frames;
  final List<RestylingItem> restylings;

  GenerationItem({
    required this.id,
    required this.modelCarId,
    required this.generation,
    required this.frames,
    required this.restylings,
  });

  String get label => 'Поколение $generation';

  /// Диапазон годов выпуска поколения, посчитанный из годов его рестайлингов
  /// (`RestylingItem.yearStart`/`yearEnd`). У самого поколения в каталоге
  /// годов нет — они висят на рестайлингах, поэтому берём минимальный старт и
  /// максимальный конец по всем рестайлингам. Если хотя бы у одного рестайлинга
  /// год окончания не задан (модель ещё выпускается) — диапазон открытый.
  /// Возвращает `null`, когда год не известен ни у одного рестайлинга — тогда
  /// вызывающий код показывает номер поколения как раньше.
  String? get yearRange {
    int? start;
    int? end;
    var openEnded = false;
    for (final restyling in restylings) {
      final s = restyling.yearStart;
      final e = restyling.yearEnd;
      if (s != null) {
        if (start == null || s < start) start = s;
        if (e == null) openEnded = true;
      }
      if (e != null && (end == null || e > end)) end = e;
    }
    if (start == null) return null;
    if (openEnded || end == null) return 'с $start';
    if (end <= start) return '$start';
    return '$start–$end';
  }

  /// Человекочитаемая подпись поколения для UI: диапазон годов, если он
  /// известен, иначе — номер поколения.
  String get yearRangeOrNumber => yearRange ?? '$generation';

  /// Диапазон годов, посчитанный напрямую из «сырого» списка рестайлингов
  /// (list of maps в контракте [RestylingItem.toJson]) — для экранов, где под
  /// рукой нет собранного [GenerationItem], а только сохранённый/пришедший с
  /// бэка `restylings`. Возвращает `null`, если список не распознан или годов
  /// в нём нет — тогда вызывающий код показывает номер поколения. Никогда не
  /// бросает: незнакомая форма молча даёт `null`.
  static String? yearRangeFromRestylingsJson(dynamic rawRestylings) {
    final list = _catalogJsonList(rawRestylings, RestylingItem.tryFromJson);
    if (list.isEmpty) return null;
    return GenerationItem(
      id: 0,
      modelCarId: 0,
      generation: 0,
      frames: const [],
      restylings: list,
    ).yearRange;
  }

  /// Человекочитаемое значение поколения из ответа `Storage.GetRequestCar`.
  ///
  /// В этом контракте номер поколения лежит в `generation`, а годы — внутри
  /// `restyling` (singular). Старые/кэшированные ответы могут использовать
  /// `restylings` (plural), поэтому поддерживаем обе формы. Если годов нет,
  /// сохраняем обратную совместимость и возвращаем номер поколения.
  static String? displayValueFromRequestCarJson(dynamic rawCar) {
    final car = _catalogJsonMap(rawCar);
    final range =
        yearRangeFromRestylingsJson(car['restylings']) ??
        yearRangeFromRestylingsJson(car['restyling']);
    if (range != null) return range;

    final rawGeneration = car['generation'];
    final number = _catalogJsonInt(rawGeneration);
    if (number != null) return number > 0 ? '$number' : null;
    final text = _catalogJsonString(rawGeneration).trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'modelCarId': modelCarId,
    'generation': generation,
    'frames': frames.map((f) => f.toJson()).toList(growable: false),
    'restylings': restylings.map((r) => r.toJson()).toList(growable: false),
  };

  static GenerationItem? tryFromJson(dynamic raw) {
    final map = _catalogJsonMap(raw);
    final id = _catalogJsonInt(map['id']);
    if (id == null) return null;
    return GenerationItem(
      id: id,
      modelCarId: _catalogJsonInt(map['modelCarId']) ?? 0,
      generation: _catalogJsonInt(map['generation']) ?? 0,
      frames: _catalogJsonList(map['frames'], FrameItem.tryFromJson),
      restylings: _catalogJsonList(
        map['restylings'],
        RestylingItem.tryFromJson,
      ),
    );
  }
}

// ── Каталожная JSON-сериализация ────────────────────────────────────────
// toJson/tryFromJson шести каталожных классов выше — это wire-контракт
// сразу двух персистов: файлового кэша каталога (CarCatalogStore) и
// черновика заявки компании (persisted до появления кэша с теми же
// ключами). Менять имена ключей нельзя — сломаются и старые черновики,
// и уже записанные файлы кэша. tryFromJson терпимы к мусору: без
// валидного id запись молча выбрасывается (битый элемент не должен
// ронять весь кэш).

Map<String, dynamic> _catalogJsonMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

int? _catalogJsonInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

int? _catalogJsonYear(dynamic raw) {
  final direct = _catalogJsonInt(raw);
  if (direct != null) return direct;
  if (raw is Map) return _catalogJsonYear(raw['date']);
  if (raw is String) {
    final match = RegExp(r'\d{4}').firstMatch(raw.trim());
    return match == null ? null : int.tryParse(match.group(0)!);
  }
  return null;
}

String _catalogJsonString(dynamic raw) {
  if (raw is String) return raw;
  if (raw == null) return '';
  return raw.toString();
}

List<T> _catalogJsonList<T>(dynamic raw, T? Function(dynamic) parse) {
  if (raw is! List) return <T>[];
  final items = <T>[];
  for (final entry in raw) {
    final parsed = parse(entry);
    if (parsed != null) items.add(parsed);
  }
  return items;
}

class AuthStartResult {
  final String callPhone;
  final String? sessionId;

  /// Same JWT as `AuthVerifyResult.notificationToken` — backend returns
  /// it from both `Storage.Auth` and `Storage.AuthVerify`. We persist it
  /// here too so that the WebSocket can connect immediately after the
  /// user dials the verification number, without waiting for the verify
  /// RPC to finish.
  final String? notificationToken;

  const AuthStartResult({
    required this.callPhone,
    this.sessionId,
    this.notificationToken,
  });
}

class AuthVerifyResult {
  final String? accessToken;
  final String? refreshToken;

  /// JWT for the realtime notification WebSocket channel
  /// (`wss://ws.carreports.ru/auth`). Returned by `Storage.Auth` /
  /// `Storage.AuthVerify` since the 2026-04 backend update. Lives 72h —
  /// shorter than the regular access token but long enough that we
  /// don't need to refresh it inside a single session.
  final String? notificationToken;

  const AuthVerifyResult({
    this.accessToken,
    this.refreshToken,
    this.notificationToken,
  });

  bool get hasTokens =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      refreshToken != null &&
      refreshToken!.isNotEmpty;

  bool get hasNotificationToken =>
      notificationToken != null && notificationToken!.isNotEmpty;
}

class CreateRequestResult {
  final int id;
  final String requestNumber;

  const CreateRequestResult({required this.id, required this.requestNumber});
}

class RequestActionResult {
  final int requestId;
  final String requestNumber;
  final String status;
  final bool success;
  final String? error;
  final int? reportId;
  final String? reportNumber;

  const RequestActionResult({
    required this.requestId,
    required this.requestNumber,
    required this.status,
    this.success = true,
    this.error,
    this.reportId,
    this.reportNumber,
  });
}

class RequestCarDetails {
  final List<Map<String, dynamic>> cars;
  final List<Map<String, dynamic>> requestStatusHistories;

  const RequestCarDetails({
    required this.cars,
    required this.requestStatusHistories,
  });
}

class CompanySpecialistUnlinkResult {
  final bool success;
  final int? specialistId;
  final int? companyId;
  final bool changed;
  final int? activeAssignedRequests;
  final String? error;

  const CompanySpecialistUnlinkResult({
    required this.success,
    this.specialistId,
    this.companyId,
    this.changed = false,
    this.activeAssignedRequests,
    this.error,
  });
}

class CompanySpecialistUnlinkException implements Exception {
  final String code;
  final int? activeAssignedRequests;

  const CompanySpecialistUnlinkException({
    required this.code,
    this.activeAssignedRequests,
  });

  String get message {
    switch (code) {
      case 'specialist_has_active_assigned_requests':
        final count = activeAssignedRequests;
        return count == null || count <= 0
            ? 'Нельзя удалить сотрудника: у него есть активные заявки'
            : 'Нельзя удалить сотрудника: активных заявок $count';
      case 'specialist_not_found_or_not_linked_to_your_company':
        return 'Сотрудник не найден в штате компании';
      default:
        return code.isEmpty
            ? 'Не удалось удалить сотрудника из штата'
            : 'Не удалось удалить сотрудника из штата: $code';
    }
  }

  @override
  String toString() => message;
}

/// User tag returned by `Storage.GetUserTags` / `Storage.AddUserTag`.
///
/// Domain invariant: every tag has a severity. The server's enum is
/// `serious` / `non_serious`; nulls and stale `nonserious` (no
/// underscore) values from older clients also normalize cleanly. The
/// parser [UserTagType.normalize] folds everything into [UserTagType]
/// so screens can switch on two values without null checks.
///
/// `step` / `section` stay nullable — their null carries meaning
/// (system tags without an owning step), unlike `type`.
class UserTag {
  final int id;
  final String? step;
  final String? section;
  final String name;
  final String slug;
  final UserTagType type;
  final String? createdAt;

  /// Owner's user id from `Storage.GetUserTags` response. `null` means
  /// it's a system / shared tag — only the user's own tags (non-null
  /// userId) can be deleted via `Storage.RemoveUserTag`. Use [isCustom]
  /// for UI delete-affordance gating.
  final int? userId;

  const UserTag({
    required this.id,
    required this.name,
    required this.slug,
    this.type = UserTagType.nonSerious,
    this.step,
    this.section,
    this.createdAt,
    this.userId,
  });

  bool get isSerious => type == UserTagType.serious;

  /// True for tags the current user (or any user) created. False for
  /// system / shared tags. Mirrors the server's `RemoveUserTag`
  /// permission model: system tags can't be removed.
  bool get isCustom => userId != null;
}

/// Two-value severity of a [UserTag]. No `null` variant — the boundary
/// parser coerces server nulls and unknown strings into [nonSerious].
enum UserTagType {
  serious,
  nonSerious;

  /// Canonical wire form — server accepts and emits the same string
  /// for both `Storage.AddUserTag` input and `Storage.GetUserTags`
  /// response (`serious` / `non_serious`). Used everywhere.
  String get wireName {
    switch (this) {
      case UserTagType.serious:
        return 'serious';
      case UserTagType.nonSerious:
        return 'non_serious';
    }
  }

  /// Accepts every known server form + internal string and folds to
  /// the canonical enum. Unknown / null / empty → [nonSerious].
  static UserTagType normalize(Object? raw) {
    if (raw is UserTagType) return raw;
    final text = (raw ?? '').toString().trim().toLowerCase();
    if (text == 'serious') return UserTagType.serious;
    // Tolerate the older `nonserious` (no underscore) — earlier client
    // builds wrote it into the persisted tag catalog and the
    // OpenRPC spec briefly listed it as the input enum. Fold both into
    // the canonical [nonSerious].
    if (text == 'non_serious' || text == 'nonserious') {
      return UserTagType.nonSerious;
    }
    // Empty / null arrives for system tags that the server shipped
    // without a stored severity. Treat those silently as nonSerious.
    if (text.isNotEmpty) {
      // Anything else is a contract violation — log so we notice
      // server-side drift (new enum value, typo) before it stays
      // mislabeled in the UI.
      debugPrint(
        '[UserTagType] unknown severity "$raw" — defaulting to nonSerious',
      );
    }
    return UserTagType.nonSerious;
  }
}

class PrepareSpecialistReportResult {
  final String reportNumber;
  final int? reportId;
  final List<PreparedUploadFile> uploadFiles;
  final Map<String, dynamic> result;

  const PrepareSpecialistReportResult({
    required this.reportNumber,
    required this.reportId,
    required this.uploadFiles,
    required this.result,
  });

  bool get hasReportNumber => reportNumber.trim().isNotEmpty;
}

class PreparedUploadFile {
  final String filename;
  final String type;
  final String key;

  const PreparedUploadFile({
    required this.filename,
    required this.type,
    required this.key,
  });
}

class SpecialistReportCompletionResult {
  final bool? success;
  final int? reportId;
  final Map<String, dynamic> result;

  const SpecialistReportCompletionResult({
    required this.success,
    required this.reportId,
    required this.result,
  });
}

class SpecialistReportShareUrlResult {
  final String url;
  final Map<String, dynamic> result;

  const SpecialistReportShareUrlResult({
    required this.url,
    required this.result,
  });
}

class MultipartUploadSession {
  final String uploadId;
  final String key;
  final Map<String, dynamic> result;

  const MultipartUploadSession({
    required this.uploadId,
    required this.key,
    required this.result,
  });
}

class MultipartUploadUrl {
  final int partNumber;
  final String url;

  const MultipartUploadUrl({required this.partNumber, required this.url});
}

class MultipartUploadUrlsResult {
  final String key;
  final List<MultipartUploadUrl> urls;
  final Map<String, dynamic> result;

  const MultipartUploadUrlsResult({
    required this.key,
    required this.urls,
    required this.result,
  });
}

class MultipartUploadedPart {
  final int partNumber;
  final String etag;

  const MultipartUploadedPart({required this.partNumber, required this.etag});

  Map<String, dynamic> toJson() => {'partNumber': partNumber, 'etag': etag};
}

class MultipartCompleteResult {
  final String key;
  final Map<String, dynamic> result;

  const MultipartCompleteResult({required this.key, required this.result});
}

class MultipartAbortResult {
  final bool success;
  final Map<String, dynamic> result;

  const MultipartAbortResult({required this.success, required this.result});
}

class MultipartListPartsResult {
  final String key;
  final List<MultipartUploadedPart> parts;

  const MultipartListPartsResult({required this.key, required this.parts});
}

/// Возвращается `Storage.GetSpecialists`. Email и phone приходят **только
/// при точном совпадении** search-параметра — без явного поиска по
/// конкретному значению эти поля null (privacy by default).
class SpecialistItem {
  final int id;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? urlAvatar;
  final String? description;
  final int likeUp;
  final int likeDown;
  final double rating;
  final String? city;
  final String? email;
  final String? phone;

  const SpecialistItem({
    required this.id,
    this.fullName,
    this.firstName,
    this.lastName,
    this.middleName,
    this.urlAvatar,
    this.description,
    this.likeUp = 0,
    this.likeDown = 0,
    this.rating = 0,
    this.city,
    this.email,
    this.phone,
  });

  /// «Фамилия Имя» (Отчество — не показываем для компактности списка).
  /// Если ФИО нет вообще — fallback на email/phone или «Специалист #ID».
  String get displayName {
    final full = (fullName ?? '').trim();
    if (full.isNotEmpty) return full;
    final ln = (lastName ?? '').trim();
    final fn = (firstName ?? '').trim();
    if (ln.isNotEmpty || fn.isNotEmpty) {
      return [ln, fn].where((s) => s.isNotEmpty).join(' ');
    }
    final em = (email ?? '').trim();
    if (em.isNotEmpty) return em;
    final ph = (phone ?? '').trim();
    if (ph.isNotEmpty) return ph;
    return 'Специалист #$id';
  }
}

class ProfileMultipartSession {
  final String uploadId;
  final String filename;
  final String key;
  final String publicUrl;

  const ProfileMultipartSession({
    required this.uploadId,
    required this.filename,
    required this.key,
    required this.publicUrl,
  });
}

class ProfileMultipartCompleteResult {
  final String key;
  final String publicUrl;
  final int contentSize;
  final String? error;
  final int? maxSize;
  final int? actual;

  const ProfileMultipartCompleteResult({
    required this.key,
    required this.publicUrl,
    required this.contentSize,
    this.error,
    this.maxSize,
    this.actual,
  });

  bool get hasError => error != null && error!.isNotEmpty;
}

/// Типизированная ошибка флоу загрузки аватара в S3. Поле [code] —
/// машинно-читаемый идентификатор (`file_too_large`, `checksum_mismatch`,
/// `no_url`, `empty_url`, `transport`), [message] — готовая строка для UI.
class ProfileAvatarUploadException implements Exception {
  final String code;
  final String message;
  final int? maxSize;
  final int? actualSize;

  const ProfileAvatarUploadException({
    required this.code,
    required this.message,
    this.maxSize,
    this.actualSize,
  });

  @override
  String toString() => 'ProfileAvatarUploadException($code): $message';
}

/// Пагинированный ответ `Storage.GetSpecialists`.
class SpecialistsPage {
  final List<SpecialistItem> specialists;
  final int page;
  final int limit;
  final int total;
  final int pages;

  const SpecialistsPage({
    required this.specialists,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });
}

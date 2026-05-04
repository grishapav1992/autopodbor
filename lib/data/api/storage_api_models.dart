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
}

class FrameItem {
  final int id;
  final String frame;

  FrameItem({required this.id, required this.frame});
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
}

class AuthStartResult {
  final String callPhone;
  final String? sessionId;

  const AuthStartResult({required this.callPhone, this.sessionId});
}

class AuthVerifyResult {
  final String? accessToken;
  final String? refreshToken;

  /// JWT for the realtime notification WebSocket channel
  /// (`wss://...:2350/auth`). Returned by `Storage.Auth` /
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
  final Map<String, dynamic> result;

  const MultipartListPartsResult({
    required this.key,
    required this.parts,
    required this.result,
  });
}

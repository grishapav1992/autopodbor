/// User-facing name for media returned by a platform picker.
///
/// iOS' image picker often exposes its own temporary filename (for example
/// `image_picker_<uuid>.jpg`) instead of the Photos asset name. That transport
/// detail must not leak into the report UI. Real filenames selected through
/// Files are preserved verbatim; only known picker-generated names are
/// replaced with a stable, readable label.
String sparkJoyUserFacingPickedName({
  required String rawName,
  required String mimeType,
  required DateTime pickedAt,
  int sequence = 0,
}) {
  final trimmed = rawName.trim();
  if (trimmed.isNotEmpty && !sparkJoyIsTechnicalPickerName(trimmed)) {
    return sparkJoySafeDisplayName(trimmed);
  }

  final label = mimeType.startsWith('image/')
      ? 'Фото'
      : mimeType.startsWith('video/')
      ? 'Видео'
      : 'Файл';
  final suffix = sequence > 0 ? ' ${sequence + 1}' : '';
  final extension = _sparkJoyPickedFileExtension(trimmed, mimeType);
  final date =
      '${_twoDigits(pickedAt.day)}.${_twoDigits(pickedAt.month)}.'
      '${pickedAt.year}';
  final time =
      '${_twoDigits(pickedAt.hour)}-'
      '${_twoDigits(pickedAt.minute)}-${_twoDigits(pickedAt.second)}';
  return '$label $date $time$suffix.$extension';
}

bool sparkJoyIsTechnicalPickerName(String rawName) {
  final name = rawName
      .trim()
      .replaceAll('\\', '/')
      .split('/')
      .last
      .toLowerCase();
  final base = name.replaceFirst(RegExp(r'\.[a-z0-9]{1,10}$'), '');
  return RegExp(
    r'^(?:scaled_)?(?:image|video)_picker[_-][0-9a-f-]{16,}(?:-\d+)?$',
  ).hasMatch(base);
}

/// Readable fallback for drafts created before picker filenames were cleaned
/// at ingestion time. It deliberately affects presentation only: stored local
/// paths, hashes and upload object names stay untouched.
String sparkJoyReadableStoredName({
  required String rawName,
  required String mimeType,
  int ordinal = 0,
}) {
  final trimmed = rawName.trim();
  if (trimmed.isNotEmpty && !sparkJoyIsTechnicalPickerName(trimmed)) {
    return sparkJoySafeDisplayName(trimmed);
  }
  final label = mimeType.startsWith('image/')
      ? 'Фото'
      : mimeType.startsWith('video/')
      ? 'Видео'
      : 'Файл';
  final number = ordinal >= 0 ? ' ${ordinal + 1}' : '';
  return '$label$number.${_sparkJoyPickedFileExtension(trimmed, mimeType)}';
}

/// Removes path fragments, control characters and Unicode bidi controls from
/// a filename before rendering it. The untouched value remains available as
/// `originalName`; this function is presentation-only.
String sparkJoySafeDisplayName(String rawName) {
  final basename = rawName.trim().replaceAll('\\', '/').split('/').last;
  final cleaned = basename
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), '')
      .trim();
  return cleaned.isEmpty ? 'Файл' : cleaned;
}

String sparkJoyPreferredPickerMimeType({
  required String? declaredMimeType,
  required String fallbackMimeType,
}) {
  final declared = (declaredMimeType ?? '').trim().toLowerCase();
  if (declared.isNotEmpty && declared != 'application/octet-stream') {
    return declared;
  }
  return fallbackMimeType.trim().isEmpty
      ? 'application/octet-stream'
      : fallbackMimeType.trim().toLowerCase();
}

String _sparkJoyPickedFileExtension(String rawName, String mimeType) {
  final dot = rawName.lastIndexOf('.');
  if (dot >= 0 && dot < rawName.length - 1) {
    final candidate = rawName.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,10}$').hasMatch(candidate)) return candidate;
  }
  const byMime = <String, String>{
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'image/heif': 'heif',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'video/x-m4v': 'm4v',
    'video/webm': 'webm',
  };
  return byMime[mimeType.toLowerCase()] ?? 'bin';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

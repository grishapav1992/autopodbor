String sparkJoyMediaPrimaryRef({
  required String itemId,
  required String dataUrl,
}) {
  final id = itemId.trim();
  if (id.isNotEmpty) return id;
  return dataUrl.trim();
}

Set<String> sparkJoyMediaAllRefs({
  required String itemId,
  required String dataUrl,
}) {
  return <String>{
    if (itemId.trim().isNotEmpty) itemId.trim(),
    if (dataUrl.trim().isNotEmpty) dataUrl.trim(),
  };
}

bool sparkJoyMediaTargetMatches({
  required String targetRef,
  required String itemId,
  required String dataUrl,
}) {
  return sparkJoyMediaPrimaryRef(itemId: itemId, dataUrl: dataUrl) ==
      targetRef.trim();
}

String sparkJoyServerFileToken(String raw, {required String fallback}) {
  final token = raw
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return token.isEmpty ? fallback : token;
}

String sparkJoyUploadFilename({
  required String contextPrefix,
  required String itemId,
  required String originalName,
  required String fallbackExtension,
  required int index,
}) {
  final context = contextPrefix.trim();
  final original = _ensureFileExtension(
    originalName,
    fallbackPrefix: context.isEmpty ? 'upload' : context,
    fallbackExtension: fallbackExtension,
  );
  if (context.isEmpty) return original;

  final dotIndex = original.lastIndexOf('.');
  final hasExtension = dotIndex > 0 && dotIndex < original.length - 1;
  final rawBase = hasExtension ? original.substring(0, dotIndex) : original;
  final extension = hasExtension
      ? original.substring(dotIndex).toLowerCase()
      : '.$fallbackExtension';
  final itemToken = sparkJoyServerFileToken(
    itemId,
    fallback: '${context}_${index + 1}',
  );
  final baseToken = sparkJoyServerFileToken(rawBase, fallback: 'file');
  return '${context}_${itemToken}_$baseToken$extension';
}

/// Deterministic S3 object name for a video's poster (preview JPEG), derived
/// from the video's filename with the EXTENSION STRIPPED. MUST stay the single
/// source of truth for both sides of the contract:
///   • upload  — `_uploadVideoPostersBestEffort` PUTs the local thumbnail here
///               (called with the uploaded video name, e.g. `…clip.mov`);
///   • view    — the completed-report hydrator derives the same name to resolve
///               a presigned GET URL (`videoThumbUrl`).
///
/// Why strip the extension: the backend transcodes uploaded videos to HLS and
/// RENAMES them (`…clip.mov` → `…clip.m3u8`) while keeping the base identical
/// (live-verified 2026-06-25: poster sat in S3 as `…clip.mov.thumb.jpg` but the
/// view side derived `…clip.m3u8.thumb.jpg` → 404). Dropping the extension makes
/// both sides agree on `…clip.thumb.jpg` regardless of the swap. iOS can't
/// extract a frame from the remote presigned URL (sync `AVAssetImageGenerator`
/// fails before the asset's tracks load), so this pre-made poster is how
/// completed reports get a video thumbnail at all.
String sparkJoyVideoPosterFilename(String videoFilename) {
  final name = videoFilename.trim();
  if (name.isEmpty) return '';
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  return '$base.thumb.jpg';
}

String sparkJoyUploadStateKey({
  required String filename,
  required String source,
  required String itemId,
  required int index,
}) {
  final normalizedFilename = filename.trim();
  if (normalizedFilename.isNotEmpty) return 'filename:$normalizedFilename';
  final normalizedSource = source.trim();
  if (normalizedSource.isNotEmpty) return normalizedSource;
  return 'idx:$index:$itemId';
}

String _ensureFileExtension(
  String raw, {
  required String fallbackPrefix,
  required String fallbackExtension,
}) {
  var name = raw
      .trim()
      .replaceAll(RegExp(r'[\\/]'), '_')
      .replaceAll(RegExp(r'[\x00-\x1F]'), '')
      .trim();
  if (name.isEmpty) {
    name = '${fallbackPrefix.trim()}.$fallbackExtension';
  }
  final dotIndex = name.lastIndexOf('.');
  final hasExtension = dotIndex > 0 && dotIndex < name.length - 1;
  return hasExtension ? name : '$name.$fallbackExtension';
}

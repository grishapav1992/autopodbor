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

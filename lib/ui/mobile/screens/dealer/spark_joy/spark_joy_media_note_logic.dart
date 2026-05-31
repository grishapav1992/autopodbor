/// Pure note-derivation logic for a media group, extracted so it can be
/// unit-tested without mounting the (plugin-heavy) report screen.
///
/// The group note is a cache over the per-file notes. It must follow the
/// files, never a stale group-level value — otherwise clearing a photo's
/// note resurrected the previous group note on the next sync (B16).
///
/// Rule: prefer the editor's explicit note when present; otherwise derive
/// from the files (which already reflect the latest per-file apply); when no
/// file carries a note, the group note is empty (the cleared state wins).
String sparkJoyDeriveGroupNote(String explicitNote, List<String> fileNotes) {
  final explicit = explicitNote.trim();
  if (explicit.isNotEmpty) return explicit;
  for (final note in fileNotes) {
    final trimmed = note.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

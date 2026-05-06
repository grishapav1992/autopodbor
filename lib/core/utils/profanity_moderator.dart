import 'package:flutter/foundation.dart' show visibleForTesting;

import '_profanity_roots.dart';

/// Result of a single profanity check. `decision` is what callers
/// switch on; `matchedRoots` is for telemetry/log only — never display
/// the raw roots in the UI.
class ProfanityModerationResult {
  const ProfanityModerationResult({
    required this.decision,
    required this.matchedRoots,
    this.userMessage,
  });

  final ProfanityModerationDecision decision;

  /// Profanity-root substrings that triggered the block. Empty when
  /// `decision == allow`. Useful for backend reporting and crash-free
  /// debugging — DO NOT surface to end users.
  final List<String> matchedRoots;

  /// Russian-language message safe to drop into a SnackBar / inline
  /// error label. Includes the optional [fieldLabel] passed to
  /// [ProfanityModerator.moderateText] when one was given.
  final String? userMessage;

  bool get isAllow => decision == ProfanityModerationDecision.allow;
  bool get isBlock => decision == ProfanityModerationDecision.block;
}

enum ProfanityModerationDecision { allow, block }

/// Russian-language profanity filter. Static utility, mirrors the
/// shape of `ContactRedaction` in this same directory so submit-gate
/// callsites read symmetrically:
///
/// ```dart
/// final contactCheck = ContactRedaction.validateProfileText(text);
/// if (contactCheck.hasViolations) { ... }
/// final profanityCheck = ProfanityModerator.moderateText(text);
/// if (profanityCheck.isBlock) { ... }
/// ```
///
/// The filter is lexical (root list + morphology), not ML-based.
/// Coverage tradeoff: catches the canonical Russian mat plus its
/// inflected forms, common lookalike substitutions (a -> @, o -> 0,
/// latin -> cyrillic), and a small set of English/transliterated
/// profanity. It does NOT catch heavy obfuscation (`п и д о р`),
/// novel slurs, or domain-specific insults outside the curated list
/// in `_profanity_roots.dart`.
class ProfanityModerator {
  ProfanityModerator._();

  /// User-visible message template. `{field}` is replaced with the
  /// provided field label, or "поле" when no label is passed. Kept
  /// terse — surfaced in SnackBars and inline error labels.
  static const String _blockedTemplate =
      'В тексте обнаружены недопустимые слова. Поправьте {field} и попробуйте снова.';

  /// Inspect [raw] and decide whether to allow or block. Empty / null
  /// / whitespace input is always allowed (nothing to moderate). Pass
  /// [fieldLabel] for a more specific error message; if omitted the
  /// generic "поле" wording is used.
  static ProfanityModerationResult moderateText(
    String? raw, {
    String? fieldLabel,
  }) {
    if (raw == null) return _allowed;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return _allowed;

    final matches = _findMatches(trimmed);
    if (matches.isEmpty) return _allowed;

    final fieldLabelOrDefault = fieldLabel?.trim().isNotEmpty == true
        ? fieldLabel!.trim()
        : 'поле';
    return ProfanityModerationResult(
      decision: ProfanityModerationDecision.block,
      matchedRoots: List.unmodifiable(matches),
      userMessage:
          _blockedTemplate.replaceFirst('{field}', '«$fieldLabelOrDefault»'),
    );
  }

  /// Convenience boolean — `true` iff the input is allowed. Use when
  /// you don't need the userMessage / matchedRoots, just a gate.
  static bool isClean(String? raw) =>
      moderateText(raw).decision == ProfanityModerationDecision.allow;

  /// Test-only — exposes the internal pattern matcher. Returns the
  /// list of profanity roots that matched. Empty if clean.
  @visibleForTesting
  static List<String> debugFindMatches(String raw) => _findMatches(raw);

  // ----------------------------------------------------------------
  // Internals.
  // ----------------------------------------------------------------

  static const ProfanityModerationResult _allowed = ProfanityModerationResult(
    decision: ProfanityModerationDecision.allow,
    matchedRoots: <String>[],
  );

  /// Digit / symbol substitution map applied for BOTH alphabets.
  /// Cheap "leetspeak" replacements: @ -> а, 0 -> о, 1 -> и, 3 -> з,
  /// ! -> и, 4 -> а. Language-agnostic — used by both the RU and EN
  /// matching paths so `b1tch` and `f4ck` are caught.
  static const Map<String, String> _digitFolds = {
    '@': 'а',
    '4': 'а',
    '0': 'о',
    '1': 'и',
    '!': 'и',
    '3': 'з',
  };

  /// Lookalike substitution map. Each entry maps a "fake" Latin twin
  /// to its canonical Cyrillic counterpart. Used ONLY in the Russian-
  /// matching path; the English-matching path keeps Latin letters as-
  /// is so EN roots like "fuck" find their literal substring in
  /// transliterated input.
  ///
  /// Narrow on purpose — adding too many entries risks corrupting
  /// unrelated Latin text in the input.
  static const Map<String, String> _lookalikes = {
    'a': 'а',
    'o': 'о',
    'e': 'е',
    'c': 'с',
    'p': 'р',
    'x': 'х',
    'y': 'у',
    'k': 'к',
    'm': 'м',
    'n': 'н',
    't': 'т',
    'b': 'б',
    'h': 'н',
  };

  /// Normalise [text] for the Russian-matching path: lower-case,
  /// yo->ye, digit-folds, Latin->Cyrillic lookalikes. Returns the
  /// same length as the input (we never insert or drop characters).
  static String _normaliseRu(String text) {
    final buf = StringBuffer();
    for (final ch in text.toLowerCase().runes) {
      var s = String.fromCharCode(ch);
      if (s == 'ё') s = 'е';
      s = _digitFolds[s] ?? _lookalikes[s] ?? s;
      buf.write(s);
    }
    return buf.toString();
  }

  /// Normalise [text] for the English-matching path: lower-case +
  /// digit-folds only. Latin letters are preserved so EN roots like
  /// "fuck" find their literal substring even in inputs like
  /// "F u c k" (after lowercase) or "f4ck" (after digit-fold) —
  /// without being corrupted by the Latin->Cyrillic substitution
  /// that the RU path applies.
  static String _normaliseEn(String text) {
    final buf = StringBuffer();
    for (final ch in text.toLowerCase().runes) {
      final s = String.fromCharCode(ch);
      buf.write(_digitFolds[s] ?? s);
    }
    return buf.toString();
  }

  /// Token regex: any run of Cyrillic OR Latin letters.
  static final RegExp _tokenRx = RegExp(r'[а-яa-z]+');

  static List<String> _findMatches(String raw) {
    final ruNormalised = _normaliseRu(raw);
    final enNormalised = _normaliseEn(raw);
    final matched = <String>{};

    // RU pass — lookalikes folded into Cyrillic so "ху@р" reads as
    // Cyrillic and matches a Cyrillic root.
    for (final m in _tokenRx.allMatches(ruNormalised)) {
      final token = m.group(0)!;
      if (token.length < 4) continue;
      if (_isWhitelisted(token)) continue;
      for (final root in kProfanityRootsRu) {
        if (!token.contains(root)) continue;
        if (!_matchesAfterPrefix(token, root)) continue;
        matched.add(root);
      }
    }

    // EN pass — Latin preserved; EN roots use literal Latin chars
    // and find substrings directly. Whitelist applies in both passes
    // so brand names ("kuban", "sukhoi") never trip either matcher.
    for (final m in _tokenRx.allMatches(enNormalised)) {
      final token = m.group(0)!;
      if (token.length < 4) continue;
      if (_isWhitelisted(token)) continue;
      for (final root in kProfanityRootsEn) {
        if (!token.contains(root)) continue;
        matched.add(root);
      }
    }

    return matched.toList(growable: false);
  }

  /// True iff the token starts with one of the known prefixes
  /// immediately followed by `root`. This is what stops "лохматый"
  /// from matching against any "лох*" root: "ло" / "лох" / "лохм" are
  /// not in [kProfanityPrefixes], so we refuse to align the root
  /// somewhere mid-token.
  static bool _matchesAfterPrefix(String token, String root) {
    for (final prefix in kProfanityPrefixes) {
      if (token.startsWith(prefix + root)) return true;
    }
    return false;
  }

  /// True if any whitelist entry is a prefix of the token. We use
  /// startsWith rather than contains so that benign words ("мудрость"
  /// startsWith "мудр") pass while pathological middle-substring
  /// matches ("похамудряга" containing "мудр") still go through the
  /// regular root scan. Whitelist entries are deliberately curated
  /// as meaningful prefixes — see [kProfanityWhitelist] docs.
  static bool _isWhitelisted(String token) {
    for (final w in kProfanityWhitelist) {
      if (token.startsWith(w)) return true;
    }
    return false;
  }
}

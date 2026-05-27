// PRIVATE root list for [ProfanityModerator]. Sourced from public
// Russian profanity dictionaries (github.com/bars38/Russian_ban_words,
// github.com/cl-pa-pa/russianBadWordsApi) plus manual curation tuned
// to the autopodbor domain — neutral automotive slang ("тачка",
// "тарантас", "бабки") is intentionally NOT here.
//
// Conventions:
//   - All roots are lowercase, ё→е normalised, minimum 4 characters.
//     Anything shorter has too many false positives across Russian
//     prose (e.g. "лох" inside "лохматый").
//   - Each entry is a ROOT, not a whole word. Inflectional prefixes
//     and suffixes are added at runtime by `ProfanityModerator` via
//     [kProfanityPrefixes] + a "anything trailing" tolerance.
//   - No entry contains the letter `ё` — input is ё→е folded before
//     matching, so a `ёбан` root would never fire. Use `ебан`.
//   - No entry is a strict substring of another shorter entry.
//     `пиздат` would be redundant when `пизд` already catches it.
//   - When in doubt about whether a word is profanity vs. coarse-but-
//     allowed slang, leave it OUT. False positives erode user trust
//     fast; missing a borderline word is recoverable on next refresh.
//
// Update protocol:
//   1. Edit this list,
//   2. Run `flutter test test/profanity_moderator_test.dart`,
//   3. Commit with `chore(profanity): refresh root list`.

/// Russian profanity roots. Each entry catches its own inflectional
/// family via [kProfanityPrefixes] + arbitrary suffix tolerance in
/// [ProfanityModerator]. Order is alphabetical for diff hygiene.
const List<String> kProfanityRootsRu = [
  // canonical (mat)
  'бляд',
  'выеб',
  'долбоеб',
  'ебал',
  'ебан',
  'ебат',
  'ебеш',
  'ебнут',
  'ебун',
  'еблив',
  'заеб',
  'наеб',
  'отъеб',
  'переебн',
  'пизд',
  'поеб',
  'разъеб',
  'уеб',
  'хуев',
  'хуеп',
  'хуес',
  'хуйн',
  'хуяр',
  'хуяч',

  // hard insults that cluster near mat in usage
  'гондон',
  'мудак',
  'мудац',
  'мудил',
  'педер',
  'пидар',
  'пидор',
  'пидрил',
  'сволоч',
  'хуило',
  'чмошн',
  'шлюх',
];

/// Short exact-token profanity that is too short for the root matcher
/// above. Keep this list conservative: entries match whole tokens only,
/// not substrings.
const List<String> kProfanityShortWordsRu = ['бля', 'сука', 'хуй'];

/// Light coverage for English profanity that occasionally gets
/// transliterated into Russian text on a phone keyboard. Not
/// exhaustive — autopodbor is a Russian-language product.
const List<String> kProfanityRootsEn = [
  'asshole',
  'bastard',
  'bitch',
  'bullshit',
  'cunt',
  'fuck',
  'fucker',
  'fuckin',
  'motherfuck',
  'pussy',
  'shit',
  'shitt',
];

/// Words that pass even though they share a prefix with a profanity
/// root. Matched via `startsWith` in [ProfanityModerator] — so each
/// entry should itself be a meaningful prefix that uniquely
/// identifies a benign word family (e.g. `'мудр'` covers мудрость /
/// мудрый / мудрая without overshooting into nonsense).
///
/// If you find yourself wanting to add many entries, the underlying
/// root in [kProfanityRootsRu] is probably too aggressive; tighten
/// the root instead of bloating this list.
const List<String> kProfanityWhitelist = [
  // — false positives observed in inspector reports —
  'лохмат', // лохматый, лохматая, лохматого
  'охапк', // охапка, охапку, охапкой
  'хирург', // хирург, хирурги, хирургический
  'мудр', // мудрость, мудрый, мудрая, мудрец
  'блюд', // блюдо, блюсти, блюдце, блюди
  'охват', // охват, охватный, охватывать
  'страх', // straх itself + страховой / страховка
  // — Latin lookalikes that ARE valid product names —
  'sukhoi', // brand name
  'kuban', // region — not a profanity, never block
];

/// Inflectional prefixes that are tolerated in front of a root. The
/// empty string is included — most matches start the token directly.
/// Order matters only for readability. Common Russian appendical /
/// derivational prefixes only; we deliberately do NOT include rare
/// or compound forms because each new prefix opens up false-positive
/// surface ("плохуевший" against root "хуев" requires "пло" to match,
/// which we refuse).
const List<String> kProfanityPrefixes = [
  '',
  'не',
  'про',
  'за',
  'по',
  'об',
  'от',
  'вы',
  'пере',
  'до',
  'у',
  'в',
  'на',
  'с',
  'раз',
  'без',
  'при',
  'из',
  'воз',
  'под',
  'над',
];

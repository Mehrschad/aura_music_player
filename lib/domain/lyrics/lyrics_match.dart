/// Title/artist normalization + candidate scoring for lyric matching.
///
/// Lyric providers index songs under noisy titles ("Song (Remastered 2011)",
/// "Song - Single Version", "Song feat. X"). Matching raw strings misses a lot,
/// so we normalize both sides to a canonical form and score candidates by a
/// blend of token similarity (title + artist) and duration proximity. Pure Dart,
/// no dependencies — safe to run on the main isolate (cheap) or off it.
library;

/// Parenthetical / trailing qualifiers that don't change the lyrics, so they're
/// stripped before matching: remaster, version, edit, mix, live, etc.
final RegExp _noiseGroup = RegExp(
  r'[\(\[\{]\s*[^\)\]\}]*\b('
  r'feat|ft|featuring|with|remaster(ed)?|re-?master|version|edit|mix|remix|'
  r'mono|stereo|deluxe|bonus|explicit|clean|live|acoustic|instrumental|'
  r'radio|single|album|original|extended|demo|reprise|interlude|skit|'
  r'anniversary|expanded)\b[^\)\]\}]*[\)\]\}]',
  caseSensitive: false,
);

/// Trailing " - Remastered 2011" / " - Single Version" style qualifiers.
final RegExp _trailingQualifier = RegExp(
  r'\s[-–—]\s*[^-–—]*\b('
  r'remaster(ed)?|re-?master|version|edit|mix|remix|mono|stereo|deluxe|'
  r'bonus|explicit|clean|live|acoustic|radio|single|original|extended|demo'
  r')\b.*$',
  caseSensitive: false,
);

/// "feat. X", "ft X", "featuring X" up to the end (artist or title tail).
final RegExp _featTail = RegExp(
  r'\s*(feat\.?|ft\.?|featuring|with)\s+.*$',
  caseSensitive: false,
);

// Keep ASCII alphanumerics + Arabic/Persian, Japanese kana, CJK, and Hangul so
// non-Latin titles still tokenize; strip everything else (punctuation/symbols).
final RegExp _nonAlnum =
    RegExp(r'[^a-z0-9؀-ۿ぀-ヿ一-鿿가-힣\s]');
final RegExp _spaces = RegExp(r'\s+');

/// A small Latin diacritic fold (no `package:diacritic`). Covers the accents
/// that actually show up in Western track/artist tags.
const Map<String, String> _foldMap = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
};

String _fold(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_foldMap[ch] ?? ch);
  }
  return b.toString();
}

/// Canonical form of a track title for matching: lowercased, diacritic-folded,
/// stripped of feat/remaster/version qualifiers and punctuation, whitespace
/// collapsed.
String normalizeTitle(String raw) {
  var s = raw.toLowerCase().trim();
  s = _fold(s);
  // Repeatedly remove noise groups (a title can carry more than one).
  String prev;
  do {
    prev = s;
    s = s.replaceAll(_noiseGroup, ' ');
  } while (s != prev);
  s = s.replaceAll(_trailingQualifier, ' ');
  s = s.replaceAll(_featTail, ' ');
  s = s.replaceAll(_nonAlnum, ' ');
  s = s.replaceAll(_spaces, ' ').trim();
  return s;
}

/// Canonical form of an artist for matching. Splits on the common multi-artist
/// separators so "A & B", "A, B", "A feat. B" all reduce to their lead token
/// set; feat/with tails are dropped.
String normalizeArtist(String raw) {
  var s = raw.toLowerCase().trim();
  s = _fold(s);
  s = s.replaceAll(_featTail, ' ');
  s = s.replaceAll(RegExp(r'\b(feat\.?|ft\.?|featuring|with|vs\.?|x)\b'), ' ');
  s = s.replaceAll(_nonAlnum, ' ');
  s = s.replaceAll(_spaces, ' ').trim();
  return s;
}

/// A light, human-readable cleanup for building *search queries* (as opposed to
/// [normalizeTitle], which is aggressive and punctuation-free for scoring). It
/// strips feat/remaster/version qualifiers that push providers off the match,
/// while preserving casing and in-title punctuation the provider may index on.
String cleanForQuery(String raw) {
  var s = raw.trim();
  String prev;
  do {
    prev = s;
    s = s.replaceAll(_noiseGroup, ' ');
  } while (s != prev);
  s = s.replaceAll(_trailingQualifier, ' ');
  s = s.replaceAll(_featTail, ' ');
  s = s.replaceAll(_spaces, ' ').trim();
  return s.isEmpty ? raw.trim() : s;
}

Set<String> _tokens(String normalized) =>
    normalized.split(' ').where((t) => t.isNotEmpty).toSet();

/// Sørensen–Dice token-set similarity in [0,1]. Order-independent and forgiving
/// of extra/missing words — the right tool for messy title/artist comparison.
double tokenSimilarity(String a, String b) {
  final ta = _tokens(a);
  final tb = _tokens(b);
  if (ta.isEmpty && tb.isEmpty) return 1.0;
  if (ta.isEmpty || tb.isEmpty) return 0.0;
  final inter = ta.intersection(tb).length;
  return (2.0 * inter) / (ta.length + tb.length);
}

/// Duration proximity in [0,1]: 1.0 at an exact match, fading linearly to 0 at
/// [maxDeltaSec] seconds apart. Unknown (<= 0) durations score neutral 0.5.
double durationScore(int aSec, int bSec, {int maxDeltaSec = 15}) {
  if (aSec <= 0 || bSec <= 0) return 0.5;
  final delta = (aSec - bSec).abs();
  if (delta >= maxDeltaSec) return 0.0;
  return 1.0 - delta / maxDeltaSec;
}

/// Blended match score in [0,1] for a candidate against the query. Title is
/// weighted highest, then artist, then duration — the ordering that best
/// separates true matches from near-collisions in practice.
double matchScore({
  required String queryTitle,
  required String queryArtist,
  required int queryDurationSec,
  required String candidateTitle,
  required String candidateArtist,
  required int candidateDurationSec,
}) {
  final t = tokenSimilarity(normalizeTitle(queryTitle), normalizeTitle(candidateTitle));
  final a =
      tokenSimilarity(normalizeArtist(queryArtist), normalizeArtist(candidateArtist));
  final d = durationScore(queryDurationSec, candidateDurationSec);
  return t * 0.55 + a * 0.30 + d * 0.15;
}

/// Minimum blended score to accept a fuzzy candidate. Below this we'd rather
/// show nothing than the wrong song's lyrics.
const double kMatchAcceptThreshold = 0.55;

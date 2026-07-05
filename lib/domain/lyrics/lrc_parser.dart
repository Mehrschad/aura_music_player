import '../models/lyrics.dart';

/// Matches an LRC time tag `[mm:ss.xx]` / `[mm:ss.xxx]` / `[mm:ss]`.
final _timeTag = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

/// Matches a word-level time tag `<mm:ss.xx>` (extended LRC).
final _wordTag = RegExp(r'<(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?>');

/// Matches the global `[offset:+/-ms]` tag.
final _offsetTag = RegExp(r'\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

Duration _toDuration(String mm, String ss, String? frac) {
  final minutes = int.parse(mm);
  final seconds = int.parse(ss);
  var ms = 0;
  if (frac != null && frac.isNotEmpty) {
    // 2 digits = centiseconds, 3 = milliseconds.
    ms = frac.length == 2 ? int.parse(frac) * 10 : int.parse(frac.padRight(3, '0').substring(0, 3));
  }
  return Duration(minutes: minutes, seconds: seconds, milliseconds: ms);
}

/// Auto-detects format: LRC if any time tag is present, otherwise plain text.
Lyrics parseLyrics(String raw) {
  if (_timeTag.hasMatch(raw)) return parseLrc(raw);
  return parsePlainLyrics(raw);
}

/// Parses standard and word-level (extended) LRC.
///
/// Handles multiple time tags per line (each emits a line sharing the text),
/// the `[offset:]` correction (baked into every line time), and `<..>` word
/// timings. Metadata tags (`[ar:]`, `[ti:]`, …) are ignored. Lines are returned
/// sorted by time.
Lyrics parseLrc(String raw) {
  var offset = Duration.zero;
  final offMatch = _offsetTag.firstMatch(raw);
  if (offMatch != null) {
    offset = Duration(milliseconds: int.parse(offMatch.group(1)!));
  }

  final out = <LyricsLine>[];
  for (final rawLine in raw.split('\n')) {
    final line = rawLine.trimRight();
    final times = _timeTag.allMatches(line).toList();
    if (times.isEmpty) continue; // metadata-only or blank line

    // Text is whatever follows the final leading time tag.
    final lastTag = times.last;
    final body = line.substring(lastTag.end);

    final words = _parseWords(body, offset);
    final plainText = _stripWordTags(body).trim();
    if (plainText.isEmpty && words.isEmpty) continue;

    for (final t in times) {
      final base = _toDuration(t.group(1)!, t.group(2)!, t.group(3));
      final time = _applyOffset(base, offset);
      out.add(LyricsLine(time: time, text: plainText, words: words));
    }
  }

  out.sort((a, b) => a.time.compareTo(b.time));
  return Lyrics(lines: out, synced: out.isNotEmpty, offset: offset);
}

/// Treats each non-empty line as an untimed lyric line.
Lyrics parsePlainLyrics(String raw) {
  final lines = <LyricsLine>[];
  for (final rawLine in raw.split('\n')) {
    final text = rawLine.trim();
    if (text.isEmpty) continue;
    lines.add(LyricsLine(time: Duration.zero, text: text));
  }
  return Lyrics(lines: lines, synced: false);
}

List<LyricWord> _parseWords(String body, Duration offset) {
  final matches = _wordTag.allMatches(body).toList();
  if (matches.isEmpty) return const [];

  final words = <LyricWord>[];
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final start =
        _applyOffset(_toDuration(m.group(1)!, m.group(2)!, m.group(3)), offset);
    final textStart = m.end;
    final textEnd = i + 1 < matches.length ? matches[i + 1].start : body.length;
    final text = body.substring(textStart, textEnd);
    if (text.trim().isEmpty) continue;
    words.add(LyricWord(start: start, text: text));
  }
  return words;
}

String _stripWordTags(String body) => body.replaceAll(_wordTag, '');

Duration _applyOffset(Duration base, Duration offset) {
  final ms = base.inMilliseconds + offset.inMilliseconds;
  return Duration(milliseconds: ms < 0 ? 0 : ms);
}

/// Attaches [translated]'s lines onto [base] as per-line translations, matched
/// by exact start time. Providers that ship a separate translated LRC (NetEase
/// `tlyric`, QQ `trans`) fold into the dual-language view through this.
Lyrics mergeTranslations(Lyrics base, Lyrics translated) {
  if (!base.synced || !translated.synced || translated.isEmpty) return base;
  final byMs = <int, String>{
    for (final l in translated.lines)
      if (l.text.trim().isNotEmpty) l.time.inMilliseconds: l.text,
  };
  if (byMs.isEmpty) return base;
  final merged = [
    for (final l in base.lines)
      LyricsLine(
        time: l.time,
        text: l.text,
        words: l.words,
        translation: byMs[l.time.inMilliseconds] ?? l.translation,
      ),
  ];
  return Lyrics(lines: merged, synced: base.synced, offset: base.offset);
}

/// Index of the line that should be highlighted at [position]: the last line
/// whose start time is at or before [position]. Returns -1 before the first
/// line, or for unsynced lyrics. Binary search — cheap to call every tick.
int currentLineIndex(List<LyricsLine> lines, Duration position) {
  if (lines.isEmpty) return -1;
  var lo = 0;
  var hi = lines.length - 1;
  var result = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= position) {
      result = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return result;
}

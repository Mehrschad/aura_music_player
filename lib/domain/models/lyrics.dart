import 'package:flutter/foundation.dart';

/// A single timed word within a line (extended/word-level LRC).
@immutable
class LyricWord {
  const LyricWord({required this.start, required this.text});

  /// Start time of this word, relative to the track (offset already applied).
  final Duration start;
  final String text;
}

/// One lyric line: a start [time], its [text], optional per-[words] timings for
/// karaoke, and an optional [translation] for the dual-language view.
@immutable
class LyricsLine {
  const LyricsLine({
    required this.time,
    required this.text,
    this.words = const [],
    this.translation,
  });

  final Duration time;
  final String text;
  final List<LyricWord> words;
  final String? translation;

  bool get hasWordTimings => words.isNotEmpty;
}

/// A parsed lyrics document.
///
/// [synced] is false for plain-text lyrics (no timestamps): those render as a
/// static, scrollable block with no highlighting. [offset] is the parsed global
/// `[offset:]` correction, already applied to every [LyricsLine.time]; it's
/// retained so the sync editor (step 8) can show and adjust it.
@immutable
class Lyrics {
  const Lyrics({
    required this.lines,
    required this.synced,
    this.offset = Duration.zero,
  });

  static const Lyrics empty = Lyrics(lines: [], synced: false);

  final List<LyricsLine> lines;
  final bool synced;
  final Duration offset;

  bool get isEmpty => lines.isEmpty;
  bool get hasTranslations => lines.any((l) => l.translation != null);
  bool get hasWordTimings => lines.any((l) => l.hasWordTimings);
}

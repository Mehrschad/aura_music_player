/// Estimated pacing for lyrics that carry no timestamps.
///
/// Plain lyrics are a wall of text: nothing moves, nothing tells you where you
/// are. Rather than leave them inert next to the synced view, we walk them at
/// the track's own pace so they get the same focus-and-dim treatment. The timing
/// is a *guess*, never presented as real sync — the UI labels it, and it is
/// deliberately conservative:
///
///   • lyrics rarely start on the first second or run to the last, so the lines
///     are spread across an inner window of the track rather than its whole
///     length;
///   • before that window opens the first line leads, after it closes the last
///     line holds — no jitter at the edges.
library;

/// Fraction of the track where the first line is assumed to land.
const double kLyricsLeadIn = 0.06;

/// Fraction of the track where the last line is assumed to have passed.
const double kLyricsTailOut = 0.94;

/// The line index to focus at [position] for an untimed lyric of [lineCount]
/// lines over a track of [duration]. Returns -1 when it cannot be estimated
/// (no lines, or an unknown/zero duration), which the UI reads as "render the
/// block plainly".
int estimatedLineIndex(int lineCount, Duration position, Duration duration) {
  if (lineCount <= 0) return -1;
  final totalMs = duration.inMilliseconds;
  if (totalMs <= 0) return -1;
  if (lineCount == 1) return 0;

  final progress = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  final span = kLyricsTailOut - kLyricsLeadIn;
  final within = ((progress - kLyricsLeadIn) / span).clamp(0.0, 1.0);
  final index = (within * (lineCount - 1)).round();
  return index.clamp(0, lineCount - 1);
}

/// The inverse of [estimatedLineIndex]: where to seek so that [index] would be
/// the focused line. Lets a tap on an untimed line still jump roughly to it.
Duration estimatedLineStart(int index, int lineCount, Duration duration) {
  if (lineCount <= 1 || duration <= Duration.zero) return Duration.zero;
  final within = (index / (lineCount - 1)).clamp(0.0, 1.0);
  final progress = kLyricsLeadIn + within * (kLyricsTailOut - kLyricsLeadIn);
  return Duration(
      milliseconds: (duration.inMilliseconds * progress).round());
}

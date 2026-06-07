import '../models/lyrics.dart';
import '../models/song.dart';

/// Source of lyrics for a track.
///
/// [SampleLyricsRepository] is active (bundled lyrics for the sample library, so
/// the synced view, karaoke and dual-language render with no network). On
/// device a composite tries the Isar cache, then embedded tags (USLT / Vorbis),
/// then [LrcLibLyricsRepository], caching the result — see the source files.
abstract interface class LyricsRepository {
  /// Returns parsed lyrics for [song], or null if none are available.
  Future<Lyrics?> lyricsFor(Song song);
}

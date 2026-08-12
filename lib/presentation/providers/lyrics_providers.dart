import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/lyrics_cache/shared_prefs_lyrics_cache.dart';
import '../../data/remote/lyrics_api/lrclib_lyrics_repository.dart';
import '../../data/remote/lyrics_api/lyrics_ovh_lyrics_repository.dart';
import '../../data/remote/lyrics_api/netease_lyrics_repository.dart';
import '../../data/remote/lyrics_api/qq_lyrics_repository.dart';
import '../../data/repositories/composite_lyrics_repository.dart';
import '../../data/repositories/sample_lyrics_repository.dart';
import '../../domain/lyrics/lrc_parser.dart';
import '../../domain/lyrics/lyrics_pacing.dart';
import '../../domain/models/lyrics.dart';
import '../../domain/repositories/lyrics_repository.dart';
import 'playback_providers.dart';
import 'settings_providers.dart';

/// Lyrics font-size preference.
enum LyricsFontSize { small, medium, large }

/// Shared lyrics cache (SharedPreferences-backed).
final lyricsCacheProvider = Provider<SharedPrefsLyricsCache>((ref) {
  return SharedPrefsLyricsCache();
});

/// The active lyrics source. With auto-fetch enabled, a composite resolver
/// checks a local sidecar `.lrc` first, then races LRCLIB, NetEase and QQ
/// Music in parallel (the synced/quality tier — each with its own internal
/// query ladder, and the tier retried once on a transient failure), returning
/// the richest match (synced › word-level › translated). If all three come up
/// empty it falls back to lyrics.ovh (plain text, different catalogue) so far
/// fewer tracks end up with nothing. With auto-fetch disabled it uses bundled
/// sample data (also keeps tests fast and offline).
final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  final autoFetch = ref.watch(settingsProvider.select((s) => s.lyricsAutoFetch));
  if (!autoFetch) return const SampleLyricsRepository();
  return CompositeLyricsRepository(
    network: [
      LrcLibLyricsRepository(),
      NeteaseLyricsRepository(),
      QQLyricsRepository(),
    ],
    fallback: [
      LyricsOvhLyricsRepository(),
    ],
    // Wide enough for LRCLIB's multi-rung ladder; sources race in parallel so
    // this bounds the whole tier, not each request.
    timeout: const Duration(seconds: 10),
  );
});

/// User-saved lyrics overrides, keyed by song id (e.g. results of the tap-to-
/// sync editor). Session-scoped; persists to Isar on device alongside the
/// lyrics cache. The lyrics view consults these before any source.
class LyricsOverrides extends StateNotifier<Map<String, Lyrics>> {
  LyricsOverrides() : super(const {});

  void save(String songId, Lyrics lyrics) =>
      state = {...state, songId: lyrics};

  /// Clears all saved lyric overrides (the lyrics "cache" in Settings).
  void clear() => state = const {};
}

final lyricsOverridesProvider =
    StateNotifierProvider<LyricsOverrides, Map<String, Lyrics>>(
  (ref) => LyricsOverrides(),
);

/// Lyrics for the current track. Priority: user override → cache → repository.
/// Fetched lyrics are auto-saved to cache for offline use.
final currentLyricsProvider = FutureProvider<Lyrics?>((ref) async {
  final song = ref.watch(currentSongProvider);
  if (song == null) return null;

  // 1. User override (from sync editor) — always wins.
  final override = ref.watch(lyricsOverridesProvider)[song.id];
  if (override != null) return override;

  final cache = ref.read(lyricsCacheProvider);

  // 2. Persistent cache — works offline. Empty entries (poisoned by older
  //    builds that cached header-only payloads) are ignored so the network
  //    lookup below gets a chance to repair them. Reading is best-effort like
  //    writing: if the store is unavailable (no platform channel under test,
  //    corrupt prefs) we fall through to the repository rather than failing
  //    the whole lookup and showing the track as having no lyrics at all.
  Lyrics? cached;
  try {
    cached = await cache.read(song.id);
  } catch (_) {/* cache unavailable — fall through */}
  if (cached != null && !cached.isEmpty) return cached;

  // 3. Remote repository — fetch and cache the result (never cache empties).
  final result = await ref.watch(lyricsRepositoryProvider).lyricsFor(song);
  if (result != null && !result.isEmpty) {
    try {
      await cache.write(song.id, result);
    } catch (_) {/* cache write failure must never lose the lyrics */}
    return result;
  }
  return null;
});

final lyricsFontSizeProvider =
    StateProvider<LyricsFontSize>((ref) => LyricsFontSize.medium);

final dualLanguageProvider = StateProvider<bool>((ref) => false);

/// The index of the active lyric line at the current position. Recomputes every
/// position tick internally but only notifies dependents when the line actually
/// changes, so the lyrics list rebuilds on line transitions, not 5×/second.
final currentLyricLineProvider = Provider<int>((ref) {
  // unwrapPrevious: while the next track's lyrics load, Riverpod keeps the
  // previous data inside AsyncLoading — without unwrapping, the old track's
  // lines would keep highlighting (and showing) under the new track.
  final lyrics = ref.watch(currentLyricsProvider).unwrapPrevious().valueOrNull;
  if (lyrics == null || !lyrics.synced) return -1;
  final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
  return currentLineIndex(lyrics.lines, position);
});

/// The line to focus right now, whether or not the lyrics carry timestamps.
///
/// For synced lyrics this is [currentLyricLineProvider]. For plain lyrics it is
/// an estimate walked at the track's pace, so the untimed view gets the same
/// living focus treatment instead of sitting as a static block. -1 means
/// "nothing to focus" (no lyrics, or an unknown duration).
final activeLyricLineProvider = Provider<int>((ref) {
  final lyrics = ref.watch(currentLyricsProvider).unwrapPrevious().valueOrNull;
  if (lyrics == null || lyrics.isEmpty) return -1;
  if (lyrics.synced) return ref.watch(currentLyricLineProvider);

  final song = ref.watch(currentSongProvider);
  if (song == null) return -1;
  final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
  return estimatedLineIndex(lyrics.lines.length, position, song.duration);
});

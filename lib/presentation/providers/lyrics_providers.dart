import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/lyrics_cache/shared_prefs_lyrics_cache.dart';
import '../../data/remote/lyrics_api/lrclib_lyrics_repository.dart';
import '../../data/repositories/sample_lyrics_repository.dart';
import '../../domain/lyrics/lrc_parser.dart';
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

/// The active lyrics source. Uses LRCLIB when auto-fetch is enabled in settings,
/// falls back to sample data otherwise (also keeps tests fast).
final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  final autoFetch = ref.watch(settingsProvider.select((s) => s.lyricsAutoFetch));
  return autoFetch ? LrcLibLyricsRepository() : const SampleLyricsRepository();
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

  // 2. Persistent cache — works offline.
  final cached = await cache.read(song.id);
  if (cached != null) return cached;

  // 3. Remote repository — fetch and cache the result.
  final result = await ref.watch(lyricsRepositoryProvider).lyricsFor(song);
  if (result != null) await cache.write(song.id, result);
  return result;
});

final lyricsFontSizeProvider =
    StateProvider<LyricsFontSize>((ref) => LyricsFontSize.medium);

final dualLanguageProvider = StateProvider<bool>((ref) => false);

/// The index of the active lyric line at the current position. Recomputes every
/// position tick internally but only notifies dependents when the line actually
/// changes, so the lyrics list rebuilds on line transitions, not 5×/second.
final currentLyricLineProvider = Provider<int>((ref) {
  final lyrics = ref.watch(currentLyricsProvider).valueOrNull;
  if (lyrics == null || !lyrics.synced) return -1;
  final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
  return currentLineIndex(lyrics.lines, position);
});

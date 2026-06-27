import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/lyrics/lyrics_match.dart';
import '../../../domain/models/song.dart';
import '../../providers/artist_bio_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/lyrics_providers.dart';
import '../../providers/playback_persistence_provider.dart';
import '../../providers/settings_providers.dart';

/// Invisible background worker: once the library is scanned, walks every song
/// and downloads + caches its lyrics, then every artist and downloads + caches
/// their biography — so both are available fully offline afterwards.
///
/// Design constraints:
///  * Sequential with a polite delay between API calls (LRCLIB and Wikipedia
///    are free services).
///  * Resumable and incremental: songs whose lyrics are already cached (or
///    recently confirmed missing) are skipped, so subsequent launches only
///    fetch what's new. Newly added songs are picked up automatically when
///    the library refreshes, because the sweep re-runs on every
///    [songsProvider] change.
///  * Inert in widget tests: when [playbackPersistenceProvider] is null
///    (i.e. not the real app entrypoint) it renders nothing and never touches
///    the network or platform channels.
class OfflinePrefetcher extends ConsumerStatefulWidget {
  const OfflinePrefetcher({super.key});

  @override
  ConsumerState<OfflinePrefetcher> createState() => _OfflinePrefetcherState();
}

class _OfflinePrefetcherState extends ConsumerState<OfflinePrefetcher> {
  static const Duration _betweenRequests = Duration(milliseconds: 400);

  bool _sweeping = false;
  bool _kickedInitial = false;
  List<Song>? _queued;

  void _onLibrary(List<Song> songs) {
    if (_sweeping) {
      _queued = songs; // sweep again with the fresh list when done
      return;
    }
    _sweep(songs);
  }

  Future<void> _sweep(List<Song> songs) async {
    _sweeping = true;
    try {
      await _sweepLyrics(songs);
      await _sweepBios(songs);
    } finally {
      _sweeping = false;
      final queued = _queued;
      _queued = null;
      if (queued != null && mounted) _sweep(queued);
    }
  }

  Future<void> _sweepLyrics(List<Song> songs) async {
    if (!mounted) return;
    // Respect the user's "auto-fetch lyrics" switch.
    if (!ref.read(settingsProvider).lyricsAutoFetch) return;
    final cache = ref.read(lyricsCacheProvider);

    for (final song in songs) {
      if (!mounted) return;
      try {
        // Content-addressed key, consistent with currentLyricsProvider, so a
        // song cached here is found by the player (and shared across files).
        final key = lyricsContentKey(song.artist, song.title);
        if (await cache.contains(key)) continue;
        if (await cache.hasFreshMiss(key)) continue;

        final lyrics =
            await ref.read(lyricsRepositoryProvider).lyricsFor(song);
        if (lyrics != null) {
          await cache.write(key, lyrics);
        } else {
          await cache.markMiss(key);
        }
        await Future<void>.delayed(_betweenRequests);
      } catch (_) {
        // Offline or API hiccup — leave it for the next sweep.
      }
    }
  }

  Future<void> _sweepBios(List<Song> songs) async {
    if (!mounted) return;
    final cache = ref.read(artistBioCacheProvider);
    final repo = ref.read(artistBioRepositoryProvider);

    final names = <String>{
      for (final s in songs)
        if (s.artist.trim().isNotEmpty) s.artist.trim(),
    };

    for (final name in names) {
      if (!mounted) return;
      try {
        if (await cache.contains(name)) continue;
        if (await cache.hasFreshMiss(name)) continue;

        final bio = await repo.bioFor(name);
        if (bio != null) {
          await cache.write(name, bio);
        } else {
          await cache.markMiss(name);
        }
        await Future<void>.delayed(_betweenRequests);
      } catch (_) {
        // Retry on the next sweep.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProduction = ref.watch(playbackPersistenceProvider) != null;
    if (!isProduction) return const SizedBox.shrink();

    ref.listen(songsProvider, (_, next) {
      final songs = next.valueOrNull;
      if (songs != null && songs.isNotEmpty) _onLibrary(songs);
    });

    // Kick the first sweep if the library was already loaded before this
    // widget mounted (listen only fires on *changes*).
    if (!_kickedInitial) {
      _kickedInitial = true;
      final initial = ref.read(songsProvider).valueOrNull;
      if (initial != null && initial.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_sweeping) _onLibrary(initial);
        });
      }
    }

    return const SizedBox.shrink();
  }
}

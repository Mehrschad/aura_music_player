import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/bio_cache/shared_prefs_artist_bio_cache.dart';
import '../../data/remote/artist_bio/wikipedia_artist_bio_repository.dart';
import 'playback_persistence_provider.dart';

/// Shared artist-biography cache (SharedPreferences-backed).
final artistBioCacheProvider = Provider<SharedPrefsArtistBioCache>((ref) {
  return SharedPrefsArtistBioCache();
});

/// The Wikipedia biography source.
final artistBioRepositoryProvider =
    Provider<WikipediaArtistBioRepository>((ref) {
  return WikipediaArtistBioRepository();
});

/// Biography text for an artist (by display name). Cache first, then
/// Wikipedia; fetched results are stored for offline use.
///
/// Network fetches only happen in the real app (where the playback
/// persistence override is installed in main) — in widget tests this resolves
/// to null without touching platform channels.
final artistBioProvider =
    FutureProvider.family<String?, String>((ref, artistName) async {
  final isProduction = ref.watch(playbackPersistenceProvider) != null;
  if (!isProduction) return null;

  final cache = ref.read(artistBioCacheProvider);
  final cached = await cache.read(artistName);
  if (cached != null) return cached;

  if (await cache.hasFreshMiss(artistName)) return null;

  final bio = await ref.read(artistBioRepositoryProvider).bioFor(artistName);
  if (bio != null) {
    await cache.write(artistName, bio);
  } else {
    await cache.markMiss(artistName);
  }
  return bio;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/song.dart';
import '../../domain/taste/taste_engine.dart';
import '../../domain/taste/taste_profile.dart';
import 'artist_favorites_providers.dart';
import 'favorites_providers.dart';
import 'library_providers.dart';
import 'song_ratings_provider.dart';
import 'stats_providers.dart';

/// The user's inferred [TasteProfile], recomputed whenever the listening
/// history, favourites, or ratings change. This is the single source of truth
/// for "what is this person into right now" — read it for taste read-outs
/// ("your top artists/genres") or feed it to recommendations.
final tasteProfileProvider = Provider<TasteProfile>((ref) {
  final history = ref.watch(playHistoryProvider);
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  if (songs.isEmpty && history.isEmpty) return TasteProfile.empty;

  final byId = <String, Song>{for (final s in songs) s.id: s};

  // Favourites are keyed by artist id; resolve them to names so they line up
  // with the artist names carried on play events.
  final favArtistIds = ref.watch(artistFavoritesProvider);
  final favArtistNames = <String>{
    for (final s in songs)
      if (favArtistIds.contains(s.artistId)) s.artist,
  };
  // The genres of favourited songs become explicit genre signals.
  final favSongIds = ref.watch(favoritesProvider);
  final favGenres = <String>{
    for (final s in songs)
      if (favSongIds.contains(s.id) && (s.genre?.isNotEmpty ?? false)) s.genre!,
  };

  return TasteEngine.profileFrom(
    history: history,
    songsById: byId,
    favoriteArtists: favArtistNames,
    favoriteGenres: favGenres,
  );
});

/// The ranked, diversified, lightly-explored recommendation list scored from
/// the user's *own library* against [tasteProfileProvider]. Each entry carries
/// a score and a human-readable reason ("Because you listen to …").
final recommendationsProvider = Provider<List<ScoredSong>>((ref) {
  final profile = ref.watch(tasteProfileProvider);
  if (profile.isEmpty) return const [];
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  if (songs.isEmpty) return const [];

  final favs = ref.watch(favoritesProvider);
  final ratings = ref.watch(songRatingsProvider);

  final now = DateTime.now();
  // Stable within a day so the "For You" mix doesn't reshuffle on every rebuild,
  // but refreshes tomorrow.
  final daySeed = now.year * 10000 + now.month * 100 + now.day;

  return TasteEngine.recommend(
    library: songs,
    profile: profile,
    favoriteIds: favs,
    ratings: ratings,
    currentHour: now.hour,
    daySeed: daySeed,
    limit: 40,
  );
});

/// Convenience: just the recommended [Song]s (drops scores/reasons) for simple
/// list/grid surfaces like a "For You" shelf.
final forYouSongsProvider = Provider<List<Song>>(
  (ref) => [for (final r in ref.watch(recommendationsProvider)) r.song],
);

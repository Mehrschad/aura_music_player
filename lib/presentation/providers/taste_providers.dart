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
/// Minimum completed plays before any recommendations are produced — the
/// cold-start gate shared by everything downstream (For You, Hidden Gems,
/// Suggested Artists), so a brand-new install sees none of it until enough
/// listening data has accrued.
const int kMinPlaysForRecommendations = 20;

final recommendationsProvider = Provider<List<ScoredSong>>((ref) {
  final profile = ref.watch(tasteProfileProvider);
  if (profile.isEmpty || profile.playCount < kMinPlaysForRecommendations) {
    return const [];
  }
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  if (songs.isEmpty) return const [];

  final favs = ref.watch(favoritesProvider);
  final ratings = ref.watch(songRatingsProvider);

  final now = DateTime.now();
  // Refresh the mix every 3 days for variety — stable within each 3-day window
  // so it doesn't reshuffle on every rebuild, then rotates.
  final daySeed = now.difference(DateTime(2020)).inDays ~/ 3;

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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/shared_prefs_playlist_repository.dart';
import '../../domain/library/playlist_logic.dart';
import '../../domain/library/playlist_suggestions.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'favorites_providers.dart';
import 'library_providers.dart';

/// The active playlist store — persists via SharedPreferences.
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final repo = SharedPrefsPlaylistRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// All user playlists, live.
final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  return ref.watch(playlistRepositoryProvider).watchPlaylists();
});

/// A single playlist by id.
final playlistByIdProvider = Provider.family<Playlist?, String>((ref, id) {
  return ref.watch(playlistsProvider).maybeWhen(
        data: (list) {
          for (final p in list) {
            if (p.id == id) return p;
          }
          return null;
        },
        orElse: () => null,
      );
});

/// Resolves a user playlist's song ids to [Song]s, in playlist order, skipping
/// any ids no longer in the library.
final userPlaylistSongsProvider =
    Provider.family<AsyncValue<List<Song>>, String>((ref, id) {
  final playlist = ref.watch(playlistByIdProvider(id));
  return ref.watch(effectiveSongsProvider).whenData((songs) {
    if (playlist == null) return const <Song>[];
    final byId = {for (final s in songs) s.id: s};
    return [
      for (final sid in playlist.songIds)
        if (byId[sid] != null) byId[sid]!,
    ];
  });
});

/// Taste-based suggestions for a playlist: library songs similar to the ones
/// already in it (same artists / genres / eras), excluding those present.
final playlistSuggestionsProvider =
    Provider.family<List<Song>, String>((ref, id) {
  final playlistSongs =
      ref.watch(userPlaylistSongsProvider(id)).valueOrNull ?? const <Song>[];
  final library =
      ref.watch(effectiveSongsProvider).valueOrNull ?? const <Song>[];
  return suggestForPlaylist(playlistSongs, library);
});

/// The derived songs for an auto-playlist (Recently added / Most played /
/// Recently played / Favorites).
final autoPlaylistSongsProvider =
    Provider.family<AsyncValue<List<Song>>, AutoPlaylist>((ref, type) {
  final favorites = ref.watch(favoritesProvider);
  return ref.watch(effectiveSongsProvider).whenData(
        (songs) =>
            autoPlaylistSongs(type, songs, favoriteIds: favorites),
      );
});

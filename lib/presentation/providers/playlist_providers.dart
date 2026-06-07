import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/in_memory_playlist_repository.dart';
import '../../domain/library/playlist_logic.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'favorites_providers.dart';
import 'library_providers.dart';

/// The active playlist store. Override with `IsarPlaylistRepository()` on device.
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final repo = InMemoryPlaylistRepository();
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

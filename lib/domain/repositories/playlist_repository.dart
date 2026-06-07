import '../models/playlist.dart';

/// Storage for user-created playlists.
///
/// As with the library and audio seams, the UI depends only on this interface.
/// [InMemoryPlaylistRepository] is active (session-scoped, fully functional);
/// an Isar-backed implementation persists across restarts on device — see
/// `data/local/database/isar_playlist_repository.dart`.
abstract interface class PlaylistRepository {
  /// Emits the full playlist list and re-emits on every mutation.
  Stream<List<Playlist>> watchPlaylists();

  /// The current list synchronously (for one-off reads).
  List<Playlist> get current;

  Future<Playlist> create(String name);
  Future<void> rename(String id, String name);
  Future<void> delete(String id);

  /// Appends [songIds] to the playlist, skipping ids already present.
  Future<void> addSongs(String id, List<String> songIds);

  Future<void> removeSongAt(String id, int index);
  Future<void> reorder(String id, int oldIndex, int newIndex);

  Future<void> dispose();
}

import '../../../domain/models/playlist.dart';
import '../../../domain/repositories/playlist_repository.dart';

/// Persistent [PlaylistRepository] backed by Isar.
///
/// Documented stub — it intentionally doesn't import `isar` so the project
/// compiles and runs on [InMemoryPlaylistRepository]. To enable on device:
///   1. `isar` / `isar_flutter_libs` are already in `pubspec.yaml` (step 2).
///   2. Define an `@collection` `PlaylistEntity { id; name; songIds (List<String>);
///      createdAt; updatedAt; }`, run `build_runner` to generate the adapter.
///   3. Implement the methods below against the Isar instance, mapping entities
///      to [Playlist]; back [watchPlaylists] with a `.watch(fireImmediately:true)`
///      query so the UI updates reactively, exactly like the in-memory stream.
///   4. Point `playlistRepositoryProvider` here.
///
/// The "Favorites" auto-playlist also persists here on device (a favourited-ids
/// set), graduating the session-only favourites store from step 4.
class IsarPlaylistRepository implements PlaylistRepository {
  IsarPlaylistRepository();

  Never _unimplemented() => throw UnimplementedError(
        'IsarPlaylistRepository requires Isar + a real device. '
        'InMemoryPlaylistRepository is active until then.',
      );

  @override
  Stream<List<Playlist>> watchPlaylists() => _unimplemented();

  @override
  List<Playlist> get current => _unimplemented();

  @override
  Future<Playlist> create(String name) => _unimplemented();

  @override
  Future<void> rename(String id, String name) => _unimplemented();

  @override
  Future<void> delete(String id) => _unimplemented();

  @override
  Future<void> addSongs(String id, List<String> songIds) => _unimplemented();

  @override
  Future<void> removeSongAt(String id, int index) => _unimplemented();

  @override
  Future<void> reorder(String id, int oldIndex, int newIndex) =>
      _unimplemented();

  @override
  Future<void> dispose() async {}
}

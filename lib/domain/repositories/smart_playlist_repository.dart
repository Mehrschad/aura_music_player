import '../library/smart_playlist.dart';

/// Persists smart-playlist definitions (the rules, not the resulting songs —
/// those are evaluated live against the library).
///
/// [InMemorySmartPlaylistRepository] is active; the Isar-backed implementation
/// is the device step.
abstract interface class SmartPlaylistRepository {
  Future<List<SmartPlaylist>> all();

  /// Creates (when [SmartPlaylist.id] is empty) or updates a definition,
  /// returning the stored value.
  Future<SmartPlaylist> save(SmartPlaylist playlist);

  Future<void> delete(String id);
}

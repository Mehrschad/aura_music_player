import '../models/song.dart';

/// The contract every library data source fulfils.
///
/// The UI and providers depend only on this interface, never on a concrete
/// source. Two implementations sit behind it:
///   • [SampleLibraryRepository] — curated in-memory data, active in
///     development and tests so the whole library experience is visible
///     without a device.
///   • the device scanner (`on_audio_query` + Isar cache) — wired on a real
///     phone; see `data/local/audio_query/device_library_repository.dart`.
abstract interface class LibraryRepository {
  /// Returns every song in the library.
  ///
  /// On the device implementation this reads from the Isar cache when present
  /// and triggers a background scan otherwise; [forceRescan] bypasses the
  /// cache. The scan itself runs off the main isolate via `compute()`.
  Future<List<Song>> fetchSongs({bool forceRescan = false});
}

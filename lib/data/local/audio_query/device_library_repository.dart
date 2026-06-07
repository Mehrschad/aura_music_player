import '../../../domain/models/song.dart';
import '../../../domain/repositories/library_repository.dart';

/// The on-device [LibraryRepository], backed by `on_audio_query` for the media
/// scan and Isar for the cache.
///
/// This file deliberately does **not** import `on_audio_query`,
/// `permission_handler`, or `isar` yet, so the project compiles and runs on any
/// platform via [SampleLibraryRepository]. Wiring it up on a real device is a
/// localized change:
///
/// 1. In `pubspec.yaml`, the step-2 dependency block is already uncommented
///    (`on_audio_query`, `permission_handler`, `isar`, `isar_flutter_libs`,
///    `path_provider`).
/// 2. Replace the body of [fetchSongs] with the reference implementation in the
///    doc comment below.
/// 3. In `library_providers.dart`, point `libraryRepositoryProvider` at this
///    class instead of [SampleLibraryRepository].
///
/// Reference implementation:
/// ```dart
/// final OnAudioQuery _query = OnAudioQuery();
///
/// @override
/// Future<List<Song>> fetchSongs({bool forceRescan = false}) async {
///   // 1. Permission — request READ_MEDIA_AUDIO (Android 13+) / storage.
///   final granted = await _query.permissionsStatus();
///   if (!granted) {
///     final ok = await _query.permissionsRequest();
///     if (!ok) throw const LibraryPermissionDenied();
///   }
///
///   // 2. Serve the Isar cache unless a rescan is forced.
///   if (!forceRescan) {
///     final cached = await _cache.readAllSongs();
///     if (cached.isNotEmpty) return cached;
///   }
///
///   // 3. Query device media, then map + thumbnail-cache OFF the main
///   //    isolate so a 5k-song library never janks the UI.
///   final raw = await _query.querySongs(
///     sortType: SongSortType.TITLE,
///     uriType: UriType.EXTERNAL,
///   );
///   final songs = await compute(_mapSongs, raw);
///
///   // 4. Persist to Isar (256x256 thumbnails pre-generated) and return.
///   await _cache.writeAllSongs(songs);
///   return songs;
/// }
/// ```
class DeviceLibraryRepository implements LibraryRepository {
  const DeviceLibraryRepository();

  @override
  Future<List<Song>> fetchSongs({bool forceRescan = false}) {
    throw UnimplementedError(
      'DeviceLibraryRepository requires on_audio_query + Isar and a real '
      'device. See the doc comment for the wiring steps; SampleLibraryRepository '
      'is the active source until then.',
    );
  }
}

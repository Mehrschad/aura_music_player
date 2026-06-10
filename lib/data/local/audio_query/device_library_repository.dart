import 'package:on_audio_query/on_audio_query.dart';

import '../../../domain/models/song.dart';
import '../../../domain/repositories/library_repository.dart';

/// The on-device [LibraryRepository] backed by `on_audio_query`.
///
/// Queries the system media store (EXTERNAL storage), maps every audio file to
/// the domain [Song] model, and filters by [sourceFolders] when the user has
/// configured them. Permissions are requested inline; throws
/// [LibraryPermissionDenied] only if the user explicitly denies them.
class DeviceLibraryRepository implements LibraryRepository {
  DeviceLibraryRepository({this.sourceFolders = const []});

  final List<String> sourceFolders;
  final _query = OnAudioQuery();

  @override
  Future<List<Song>> fetchSongs({bool forceRescan = false}) async {
    final granted = await _query.permissionsStatus();
    if (!granted) {
      final ok = await _query.permissionsRequest();
      if (!ok) throw const LibraryPermissionDenied();
    }

    final raw = await _query.querySongs(
      sortType: SongSortType.TITLE,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final songs = raw
        .where((s) => s.isMusic != false && s.duration != null && s.duration! > 0)
        .map(_mapSong)
        .toList();

    if (sourceFolders.isEmpty) return songs;
    return songs
        .where((s) => sourceFolders.any((f) => s.filePath.startsWith(f)))
        .toList();
  }

  static Song _mapSong(SongModel s) {
    String clean(String? v, String fallback) {
      if (v == null || v.isEmpty || v == '<unknown>') return fallback;
      return v;
    }

    return Song(
      id: s.id.toString(),
      title: s.title,
      artist: clean(s.artist, 'Unknown Artist'),
      album: clean(s.album, 'Unknown Album'),
      albumId: (s.albumId ?? s.id).toString(),
      artistId: (s.artistId ?? 0).toString(),
      duration: Duration(milliseconds: s.duration ?? 0),
      filePath: s.data,
      dateAdded: s.dateAdded != null
          ? DateTime.fromMillisecondsSinceEpoch(s.dateAdded! * 1000)
          : DateTime.now(),
      year: null,
      trackNumber: s.track,
      genre: clean(s.genre, '') == '' ? null : s.genre,
      composer: clean(s.composer, '') == '' ? null : s.composer,
      bitrate: null,
      // Optimistically true so QueryArtworkWidget always attempts to load art.
      // The widget falls back to the placeholder automatically when no art exists.
      hasArtwork: true,
    );
  }
}

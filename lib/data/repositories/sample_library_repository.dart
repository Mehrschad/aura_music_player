import '../../domain/models/song.dart';
import '../../domain/repositories/library_repository.dart';

/// An in-memory [LibraryRepository] with a curated, realistic catalogue.
///
/// This is the *active* repository in development and tests. It lets the entire
/// library experience — list / grid / compact rendering, every sort field,
/// album and artist grouping, and search — be exercised on any platform with
/// no device, no permissions, and no native plugins. On a real phone the
/// device scanner replaces it behind the same interface (one provider override).
///
/// Track metadata is deliberately varied (some missing years, varied play
/// counts and last-played dates, a couple of "no artwork" entries) so the sort
/// edge cases and placeholder artwork are visible.
class SampleLibraryRepository implements LibraryRepository {
  const SampleLibraryRepository();

  @override
  Future<List<Song>> fetchSongs({bool forceRescan = false}) async {
    // A small simulated scan latency so loading states are real and visible.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _catalogue;
  }

  static final DateTime _now = DateTime(2026, 5, 28, 9);

  static DateTime _daysAgo(int d) => _now.subtract(Duration(days: d));

  static final List<Song> _catalogue = [
    _track(
      id: 's1', title: 'Aurora Skyline', artist: 'Marlowe', album: 'Northern Glass',
      albumId: 'a1', artistId: 'ar1', secs: 252, year: 2023, track: 1,
      added: _daysAgo(4), plays: 42, lastPlayed: _daysAgo(0), bitrate: 1024,
      hasArt: true, hasLyrics: true, genre: 'Electronic',
    ),
    _track(
      id: 's2', title: 'Paper Boats', artist: 'Marlowe', album: 'Northern Glass',
      albumId: 'a1', artistId: 'ar1', secs: 198, year: 2023, track: 2,
      added: _daysAgo(4), plays: 31, lastPlayed: _daysAgo(1), bitrate: 1024,
      hasArt: true, hasLyrics: true, genre: 'Electronic',
    ),
    _track(
      id: 's3', title: 'Slow Tide', artist: 'Marlowe', album: 'Northern Glass',
      albumId: 'a1', artistId: 'ar1', secs: 276, year: 2023, track: 3,
      added: _daysAgo(4), plays: 18, lastPlayed: _daysAgo(6), bitrate: 1024,
      hasArt: true, genre: 'Electronic',
    ),
    _track(
      id: 's4', title: 'Cinder & Smoke', artist: 'The Hollow Pines',
      album: 'Field Recordings', albumId: 'a2', artistId: 'ar2', secs: 314,
      year: 2021, track: 1, added: _daysAgo(40), plays: 88,
      lastPlayed: _daysAgo(2), bitrate: 320, hasArt: true, hasLyrics: true,
      genre: 'Folk',
    ),
    _track(
      id: 's5', title: 'Long Way Down', artist: 'The Hollow Pines',
      album: 'Field Recordings', albumId: 'a2', artistId: 'ar2', secs: 229,
      year: 2021, track: 2, added: _daysAgo(40), plays: 64,
      lastPlayed: _daysAgo(3), bitrate: 320, hasArt: true, genre: 'Folk',
    ),
    _track(
      id: 's6', title: 'Static Bloom', artist: 'Vela', album: 'Halcyon',
      albumId: 'a3', artistId: 'ar3', secs: 187, year: 2024, track: 1,
      added: _daysAgo(2), plays: 5, lastPlayed: _daysAgo(2), bitrate: 256,
      hasArt: true, genre: 'Pop',
    ),
    _track(
      id: 's7', title: 'Glasshouse', artist: 'Vela', album: 'Halcyon',
      albumId: 'a3', artistId: 'ar3', secs: 241, year: 2024, track: 2,
      added: _daysAgo(2), plays: 9, lastPlayed: _daysAgo(0), bitrate: 256,
      hasArt: true, hasLyrics: true, genre: 'Pop',
    ),
    _track(
      id: 's8', title: 'Midnight Arithmetic', artist: 'Kaze', album: 'Single',
      albumId: 'a4', artistId: 'ar4', secs: 203, track: 1, added: _daysAgo(11),
      plays: 0, bitrate: 192, genre: 'Hip-Hop',
    ),
    _track(
      id: 's9', title: 'Ember', artist: 'Kaze', album: 'Single',
      albumId: 'a4', artistId: 'ar4', secs: 168, track: 2, added: _daysAgo(11),
      plays: 2, lastPlayed: _daysAgo(9), bitrate: 192, genre: 'Hip-Hop',
    ),
    _track(
      id: 's10', title: 'Adagio in Grey', artist: 'Orchestre Lumen',
      album: 'Nocturnes', albumId: 'a5', artistId: 'ar5', secs: 421, year: 2019,
      track: 1, added: _daysAgo(120), plays: 120, lastPlayed: _daysAgo(5),
      bitrate: 1411, hasArt: true, genre: 'Classical',
    ),
    _track(
      id: 's11', title: 'Nocturne No. 4', artist: 'Orchestre Lumen',
      album: 'Nocturnes', albumId: 'a5', artistId: 'ar5', secs: 388, year: 2019,
      track: 2, added: _daysAgo(120), plays: 77, lastPlayed: _daysAgo(14),
      bitrate: 1411, hasArt: true, hasLyrics: true, genre: 'Classical',
    ),
    _track(
      id: 's12', title: 'Zephyr', artist: 'Vela', album: 'Halcyon',
      albumId: 'a3', artistId: 'ar3', secs: 215, year: 2024, track: 3,
      added: _daysAgo(2), plays: 14, lastPlayed: _daysAgo(1), bitrate: 256,
      hasArt: true, genre: 'Pop',
    ),
  ];

  static Song _track({
    required String id,
    required String title,
    required String artist,
    required String album,
    required String albumId,
    required String artistId,
    required int secs,
    required DateTime added,
    int? year,
    int? track,
    int plays = 0,
    DateTime? lastPlayed,
    int? bitrate,
    bool hasArt = false,
    bool hasLyrics = false,
    String? genre,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      albumId: albumId,
      artistId: artistId,
      duration: Duration(seconds: secs),
      filePath: '/storage/emulated/0/Music/$artist/$album/$title.flac',
      dateAdded: added,
      year: year,
      trackNumber: track,
      playCount: plays,
      lastPlayed: lastPlayed,
      bitrate: bitrate,
      hasArtwork: hasArt,
      hasLyrics: hasLyrics,
      genre: genre,
    );
  }
}

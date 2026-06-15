import '../models/album.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import '../models/song.dart';

/// Derives the album list from the flat song index.
///
/// Pure and deterministic: albums are keyed by [Song.albumId], the song count
/// is tallied, the year is taken as the max year seen (an album reissue tag
/// shouldn't drag the whole album backward), and the result is returned sorted
/// A–Z by album name.
List<Album> groupAlbums(List<Song> songs) {
  final byId = <String, _AlbumAcc>{};
  for (final s in songs) {
    final acc = byId.putIfAbsent(
      s.albumId,
      () => _AlbumAcc(id: s.albumId, name: s.album, artist: s.albumArtist ?? s.artist),
    );
    acc.count++;
    // Prefer a song that has artwork for the representative ID so the
    // ArtworkImageProvider (ArtworkType.AUDIO) has the best chance of
    // finding embedded cover art.
    acc.firstSongId ??= int.tryParse(s.id);
    if (s.hasArtwork) {
      acc.hasArtwork = true;
      acc.firstSongId = int.tryParse(s.id);
    }
    if (s.year != null && (acc.year == null || s.year! > acc.year!)) {
      acc.year = s.year;
    }
  }
  final albums = byId.values
      .map((a) => Album(
            id: a.id,
            name: a.name,
            artist: a.artist,
            songCount: a.count,
            year: a.year,
            hasArtwork: a.hasArtwork,
            firstSongId: a.firstSongId,
          ))
      .toList()
    ..sort((x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()));
  return albums;
}

/// Derives the artist list from the flat song index, counting distinct albums
/// and total songs per artist. Returned sorted A–Z by artist name.
List<Artist> groupArtists(List<Song> songs) {
  final byId = <String, _ArtistAcc>{};
  for (final s in songs) {
    final acc =
        byId.putIfAbsent(s.artistId, () => _ArtistAcc(id: s.artistId, name: s.artist));
    acc.songCount++;
    acc.albumIds.add(s.albumId);
    // Always track the first song id. on_audio_query doesn't set hasArtwork
    // reliably — let QueryArtworkWidget attempt the load and fall back to the
    // placeholder automatically via nullArtworkWidget.
    if (acc.firstSongId == null) {
      acc.firstSongId = int.tryParse(s.id);
      acc.hasArtwork = true;
    } else if (s.hasArtwork) {
      acc.hasArtwork = true;
    }
  }
  final artists = byId.values
      .map((a) => Artist(
            id: a.id,
            name: a.name,
            albumCount: a.albumIds.length,
            songCount: a.songCount,
            hasArtwork: a.hasArtwork,
            firstSongId: a.firstSongId,
          ))
      .toList()
    ..sort((x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()));
  return artists;
}

/// Derives the genre list from the flat song index, bucketing by the trimmed
/// genre tag (an empty bucket holds untagged songs). Returned sorted A–Z by
/// genre name, with the untagged bucket always last.
List<Genre> groupGenres(List<Song> songs) {
  final byName = <String, _GenreAcc>{};
  for (final s in songs) {
    final key = (s.genre ?? '').trim();
    final acc = byName.putIfAbsent(key, () => _GenreAcc(name: key));
    acc.songCount++;
    acc.firstSongId ??= int.tryParse(s.id);
  }
  final genres = byName.values
      .map((g) => Genre(
            name: g.name,
            songCount: g.songCount,
            firstSongId: g.firstSongId,
          ))
      .toList()
    ..sort((x, y) {
      // The untagged bucket (empty name) always sorts last.
      if (x.name.isEmpty) return y.name.isEmpty ? 0 : 1;
      if (y.name.isEmpty) return -1;
      return x.name.toLowerCase().compareTo(y.name.toLowerCase());
    });
  return genres;
}

class _AlbumAcc {
  _AlbumAcc({required this.id, required this.name, required this.artist});
  final String id;
  final String name;
  final String artist;
  int count = 0;
  int? year;
  bool hasArtwork = false;
  int? firstSongId;
}

class _ArtistAcc {
  _ArtistAcc({required this.id, required this.name});
  final String id;
  final String name;
  int songCount = 0;
  final Set<String> albumIds = {};
  bool hasArtwork = false;
  int? firstSongId;
}

class _GenreAcc {
  _GenreAcc({required this.name});
  final String name;
  int songCount = 0;
  int? firstSongId;
}

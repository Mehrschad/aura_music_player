import '../models/album.dart';
import '../models/artist.dart';
import '../models/song.dart';
import 'library_grouping.dart';

/// Which hierarchy the Songs list is folded into.
enum SongTreeMode {
  /// One section per initial letter of the title (A, B, C …), tracks beneath.
  title,

  /// One section per album (A→Z), its tracks numbered beneath.
  album,

  /// One section per artist (A→Z); each artist holds album sub-sections whose
  /// tracks are numbered — a three-level tree.
  artist,
}

/// The kind of a flattened tree row, so the view can pick a widget + a fixed
/// height for it without re-deriving structure.
enum LibRowKind { letter, artist, album, song }

/// A single flattened row of the Songs tree. The list is a depth-first
/// flattening of the hierarchy: a header row followed by its children, so it
/// can drive one lazy [SliverList] while [depth] carries the indentation the
/// view draws as VS-Code-style guide lines.
class LibRow {
  const LibRow._({
    required this.kind,
    required this.depth,
    this.label,
    this.artist,
    this.album,
    this.song,
    this.songIndex = -1,
    this.trackNumber,
    this.isLastInGroup = false,
  });

  /// A letter divider ("A"). Depth 0.
  const LibRow.letter(String label)
      : this._(kind: LibRowKind.letter, depth: 0, label: label);

  /// An artist section header. Depth 0.
  const LibRow.artist(Artist artist)
      : this._(kind: LibRowKind.artist, depth: 0, artist: artist);

  /// An album section header at [depth] (0 in album mode, 1 nested under an
  /// artist).
  const LibRow.album(Album album, {required int depth})
      : this._(kind: LibRowKind.album, depth: depth, album: album);

  /// A track row at [depth]. [songIndex] points into [SongTreeData.orderedSongs]
  /// so a tap can start the queue there; [trackNumber] is the 1-based position
  /// shown for album/artist trees (null in the title tree, which shows artwork
  /// instead).
  const LibRow.song(
    Song song, {
    required int depth,
    required int songIndex,
    int? trackNumber,
    bool isLastInGroup = false,
  }) : this._(
          kind: LibRowKind.song,
          depth: depth,
          song: song,
          songIndex: songIndex,
          trackNumber: trackNumber,
          isLastInGroup: isLastInGroup,
        );

  final LibRowKind kind;
  final int depth;
  final String? label;
  final Artist? artist;
  final Album? album;
  final Song? song;
  final int songIndex;
  final int? trackNumber;

  /// True for the last track of its immediate group — lets the view drop the
  /// trailing hairline so sections read as distinct blocks.
  final bool isLastInGroup;
}

/// The fully flattened Songs tree plus the queue order its rows point into.
class SongTreeData {
  const SongTreeData({
    required this.rows,
    required this.orderedSongs,
    required this.letterFirstRow,
  });

  final List<LibRow> rows;

  /// Songs in visual (tree) order — the queue a track row plays into via its
  /// [LibRow.songIndex].
  final List<Song> orderedSongs;

  /// Uppercase initial ('A'…'Z' or '#') → index in [rows] of the first
  /// top-level section starting with it. Drives the A–Z scrubber's jumps.
  final Map<String, int> letterFirstRow;
}

/// Folds [songs] into the [mode] hierarchy. [songs] is assumed already sorted
/// for [SongTreeMode.title] (its incoming title order is preserved); album and
/// artist modes regroup and re-sort internally so a track tap plays the album
/// in its natural running order.
SongTreeData buildSongTree(List<Song> songs, SongTreeMode mode) {
  switch (mode) {
    case SongTreeMode.title:
      return _buildTitleTree(songs);
    case SongTreeMode.album:
      return _buildAlbumTree(songs);
    case SongTreeMode.artist:
      return _buildArtistTree(songs);
  }
}

/// The A–Z bucket for a display string: its first letter uppercased, or '#'
/// for anything that doesn't start with a Latin letter (digits, symbols, empty).
String _bucketOf(String name) {
  final k = name.trimLeft();
  if (k.isEmpty) return '#';
  final c = k[0].toUpperCase();
  final code = c.codeUnitAt(0);
  return (code >= 65 && code <= 90) ? c : '#';
}

/// Sorts a single album's tracks by disc then track number (missing numbers
/// last), matching the album detail page.
int _byDiscThenTrack(Song a, Song b) {
  final discCmp = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
  if (discCmp != 0) return discCmp;
  return (a.trackNumber ?? 0).compareTo(b.trackNumber ?? 0);
}

SongTreeData _buildTitleTree(List<Song> songs) {
  final rows = <LibRow>[];
  final letterFirstRow = <String, int>{};
  String? currentBucket;
  for (var i = 0; i < songs.length; i++) {
    final song = songs[i];
    final bucket = _bucketOf(song.title);
    if (bucket != currentBucket) {
      currentBucket = bucket;
      letterFirstRow.putIfAbsent(bucket, () => rows.length);
      rows.add(LibRow.letter(bucket));
    }
    final lastInGroup =
        i == songs.length - 1 || _bucketOf(songs[i + 1].title) != bucket;
    rows.add(LibRow.song(song,
        depth: 1, songIndex: i, isLastInGroup: lastInGroup));
  }
  // orderedSongs is exactly the incoming (title-sorted) order.
  return SongTreeData(
      rows: rows, orderedSongs: songs, letterFirstRow: letterFirstRow);
}

SongTreeData _buildAlbumTree(List<Song> songs) {
  final byAlbum = <String, List<Song>>{};
  for (final s in songs) {
    byAlbum.putIfAbsent(s.albumId, () => <Song>[]).add(s);
  }
  final albums = groupAlbums(songs); // A→Z by name
  final rows = <LibRow>[];
  final ordered = <Song>[];
  final letterFirstRow = <String, int>{};
  for (final album in albums) {
    final tracks = (byAlbum[album.id] ?? const <Song>[]).toList()
      ..sort(_byDiscThenTrack);
    letterFirstRow.putIfAbsent(_bucketOf(album.name), () => rows.length);
    rows.add(LibRow.album(album, depth: 0));
    for (var i = 0; i < tracks.length; i++) {
      rows.add(LibRow.song(
        tracks[i],
        depth: 1,
        songIndex: ordered.length,
        trackNumber: i + 1,
        isLastInGroup: i == tracks.length - 1,
      ));
      ordered.add(tracks[i]);
    }
  }
  return SongTreeData(
      rows: rows, orderedSongs: ordered, letterFirstRow: letterFirstRow);
}

SongTreeData _buildArtistTree(List<Song> songs) {
  final byArtist = <String, List<Song>>{};
  for (final s in songs) {
    byArtist.putIfAbsent(s.artistId, () => <Song>[]).add(s);
  }
  final artists = groupArtists(songs); // A→Z by name
  final rows = <LibRow>[];
  final ordered = <Song>[];
  final letterFirstRow = <String, int>{};
  for (final artist in artists) {
    final artistSongs = byArtist[artist.id] ?? const <Song>[];
    letterFirstRow.putIfAbsent(_bucketOf(artist.name), () => rows.length);
    rows.add(LibRow.artist(artist));

    final byAlbum = <String, List<Song>>{};
    for (final s in artistSongs) {
      byAlbum.putIfAbsent(s.albumId, () => <Song>[]).add(s);
    }
    final albums = groupAlbums(artistSongs); // A→Z within the artist
    for (final album in albums) {
      final tracks = (byAlbum[album.id] ?? const <Song>[]).toList()
        ..sort(_byDiscThenTrack);
      rows.add(LibRow.album(album, depth: 1));
      for (var i = 0; i < tracks.length; i++) {
        rows.add(LibRow.song(
          tracks[i],
          depth: 2,
          songIndex: ordered.length,
          trackNumber: i + 1,
          isLastInGroup: i == tracks.length - 1,
        ));
        ordered.add(tracks[i]);
      }
    }
  }
  return SongTreeData(
      rows: rows, orderedSongs: ordered, letterFirstRow: letterFirstRow);
}

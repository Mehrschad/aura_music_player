import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/widgets/media_browser_tree.dart';
import 'package:flutter_test/flutter_test.dart';

Song _s(String id, {String album = 'A1', String albumId = 'al1', String artistId = 'ar1'}) =>
    Song(
      id: id,
      title: 'T$id',
      artist: 'Artist',
      album: album,
      albumId: albumId,
      artistId: artistId,
      duration: const Duration(seconds: 100),
      filePath: '/m/$id',
      dateAdded: DateTime(2024),
    );

void main() {
  final songs = [
    _s('1', albumId: 'al1', artistId: 'ar1'),
    _s('2', albumId: 'al1', artistId: 'ar1'),
    _s('3', album: 'A2', albumId: 'al2', artistId: 'ar2'),
  ];

  test('root lists the browse categories', () {
    final root = mediaChildren(MediaIds.root, songs);
    expect(root.map((n) => n.id),
        [MediaIds.library, MediaIds.albums, MediaIds.artists]);
    expect(root.every((n) => n.browsable), isTrue);
  });

  test('library lists every song as playable', () {
    final lib = mediaChildren(MediaIds.library, songs);
    expect(lib.length, 3);
    expect(lib.every((n) => n.playable), isTrue);
  });

  test('drilling into an album returns its songs', () {
    final children = mediaChildren('${MediaIds.albumPrefix}al1', songs);
    expect(children.map((n) => songIdFromNode(n.id)), ['1', '2']);
  });

  test('drilling into an artist returns their songs', () {
    final children = mediaChildren('${MediaIds.artistPrefix}ar2', songs);
    expect(children.map((n) => songIdFromNode(n.id)), ['3']);
  });

  test('unknown parent yields nothing', () {
    expect(mediaChildren('bogus', songs), isEmpty);
  });
}

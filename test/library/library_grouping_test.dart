import 'package:aura_music_player/domain/library/library_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fixtures.dart';

void main() {
  test('groupAlbums tallies song count and picks max year', () {
    final songs = [
      song(id: '1', album: 'X', albumId: 'x', year: 2000),
      song(id: '2', album: 'X', albumId: 'x', year: 2005),
      song(id: '3', album: 'Y', albumId: 'y'),
    ];
    final albums = groupAlbums(songs);
    expect(albums.length, 2);
    final x = albums.firstWhere((a) => a.id == 'x');
    expect(x.songCount, 2);
    expect(x.year, 2005);
  });

  test('groupArtists counts distinct albums and total songs', () {
    final songs = [
      song(id: '1', artistId: 'ar', albumId: 'a1'),
      song(id: '2', artistId: 'ar', albumId: 'a1'),
      song(id: '3', artistId: 'ar', albumId: 'a2'),
    ];
    final artists = groupArtists(songs);
    expect(artists.length, 1);
    expect(artists.single.songCount, 3);
    expect(artists.single.albumCount, 2);
  });
}

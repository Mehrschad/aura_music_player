import 'package:aura_music_player/domain/library/song_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fixtures.dart';

void main() {
  test('empty query returns nothing', () {
    expect(searchSongs([song(id: '1')], '   '), isEmpty);
  });

  test('title hit outranks artist hit for the same term', () {
    final songs = [
      song(id: 'artistMatch', title: 'Something', artist: 'Aurora'),
      song(id: 'titleMatch', title: 'Aurora', artist: 'Someone'),
    ];
    final out = searchSongs(songs, 'aurora');
    expect(out.first.id, 'titleMatch');
  });

  test('matches are case-insensitive and substring', () {
    final songs = [song(id: '1', title: 'Midnight Arithmetic')];
    expect(searchSongs(songs, 'ARITH').single.id, '1');
  });
}

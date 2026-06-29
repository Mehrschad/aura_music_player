import 'package:aura_music_player/domain/library/library_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fixtures.dart';

void main() {
  test('groupGenres buckets by genre and sorts alphabetically', () {
    final songs = [
      song(id: '1', genre: 'Rock'),
      song(id: '2', genre: 'Rock'),
      song(id: '3', genre: 'Jazz'),
    ];
    final genres = groupGenres(songs);
    expect(genres.length, 2);
    // Alphabetical: Jazz before Rock.
    expect(genres.map((g) => g.name).toList(), ['Jazz', 'Rock']);
    expect(genres.firstWhere((g) => g.name == 'Rock').songCount, 2);
    expect(genres.firstWhere((g) => g.name == 'Jazz').songCount, 1);
  });

  test('null and empty genres bucket together as unknown, sorted last', () {
    final songs = [
      song(id: '1', genre: 'Pop'),
      song(id: '2', genre: null),
      song(id: '3', genre: ''),
    ];
    final genres = groupGenres(songs);
    expect(genres.length, 2);
    final unknown = genres.last;
    expect(unknown.isUnknown, isTrue);
    expect(unknown.name, '');
    expect(unknown.songCount, 2);
  });

  test('whitespace-only genre is treated as unknown', () {
    final genres = groupGenres([song(id: '1', genre: '   ')]);
    expect(genres.single.isUnknown, isTrue);
    expect(genres.single.songCount, 1);
  });
}

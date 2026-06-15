import 'package:aura_music_player/domain/library/song_sorting.dart';
import 'package:aura_music_player/domain/models/library_sort.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fixtures.dart';

void main() {
  group('sortSongs', () {
    test('title A–Z is case-insensitive', () {
      final songs = [
        song(id: '1', title: 'banana'),
        song(id: '2', title: 'Apple'),
        song(id: '3', title: 'cherry'),
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.title, SortDirection.ascending),
      );
      expect(out.map((s) => s.id), ['2', '1', '3']);
    });

    test('title Z–A reverses', () {
      final songs = [
        song(id: '1', title: 'Apple'),
        song(id: '2', title: 'banana'),
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.title, SortDirection.descending),
      );
      expect(out.map((s) => s.id), ['2', '1']);
    });

    test('play count descending', () {
      final songs = [
        song(id: 'a', plays: 5),
        song(id: 'b', plays: 50),
        song(id: 'c', plays: 1),
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.playCount, SortDirection.descending),
      );
      expect(out.map((s) => s.id), ['b', 'a', 'c']);
    });

    test('null years sort LAST in ascending order', () {
      final songs = [
        song(id: 'noyear', title: 'a'),
        song(id: 'y2000', title: 'b', year: 2000),
        song(id: 'y1990', title: 'c', year: 1990),
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.year, SortDirection.ascending),
      );
      expect(out.map((s) => s.id), ['y1990', 'y2000', 'noyear']);
    });

    test('null years STILL sort last in descending order (not first)', () {
      final songs = [
        song(id: 'noyear', title: 'a'),
        song(id: 'y2000', title: 'b', year: 2000),
        song(id: 'y1990', title: 'c', year: 1990),
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.year, SortDirection.descending),
      );
      expect(out.map((s) => s.id), ['y2000', 'y1990', 'noyear']);
    });

    test('ties break deterministically by title (A–Z) regardless of direction',
        () {
      final songs = [
        song(id: '1', title: 'Zed', plays: 10),
        song(id: '2', title: 'Alpha', plays: 10),
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.playCount, SortDirection.descending),
      );
      // Equal play counts -> ascending title tie-break.
      expect(out.map((s) => s.id), ['2', '1']);
    });

    test('rating descending: highest first, unrated last', () {
      final songs = [
        song(id: '1', title: 'A', rating: 3),
        song(id: '2', title: 'B', rating: 5),
        song(id: '3', title: 'C'), // no rating
        song(id: '4', title: 'D', rating: 1),
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.rating, SortDirection.descending),
      );
      expect(out.map((s) => s.id), ['2', '1', '4', '3']);
    });

    test('rating ascending: lowest first, unrated last', () {
      final songs = [
        song(id: '1', title: 'A', rating: 4),
        song(id: '2', title: 'B', rating: 2),
        song(id: '3', title: 'C'), // no rating — always last
      ];
      final out = sortSongs(
        songs,
        const LibrarySort(SortField.rating, SortDirection.ascending),
      );
      expect(out.map((s) => s.id), ['2', '1', '3']);
    });

    test('does not mutate the input list', () {
      final songs = [song(id: '1', title: 'b'), song(id: '2', title: 'a')];
      final before = List.of(songs);
      sortSongs(songs, LibrarySort.defaultSort);
      expect(songs.map((s) => s.id), before.map((s) => s.id));
    });
  });
}

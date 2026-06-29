import 'package:aura_music_player/domain/library/song_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../library/_fixtures.dart';

void main() {
  group('isSubsequence', () {
    test('matches in-order non-contiguous chars', () {
      expect(isSubsequence('blk', 'black'), isTrue);
    });

    test('rejects chars not present in order', () {
      expect(isSubsequence('xyz', 'black'), isFalse);
    });

    test('empty query is false', () {
      expect(isSubsequence('', 'black'), isFalse);
    });
  });

  group('fuzzy matching', () {
    test('subsequence (not substring) query still matches', () {
      final songs = [song(id: '1', title: 'Black Sabbath')];
      expect(searchSongs(songs, 'blksab').single.id, '1');
    });

    test('substring match ranks above a fuzzy-only match', () {
      final songs = [
        // Fuzzy-only: "blk" is a subsequence of the title but not a substring.
        song(id: 'fuzzy', title: 'Black Lake', artist: 'X'),
        // Substring: "blk" appears literally.
        song(id: 'substr', title: 'BLK Mix', artist: 'Y'),
      ];
      final out = searchSongs(songs, 'blk');
      expect(out.first.id, 'substr');
    });

    test('single-char query does not trigger fuzzy noise', () {
      // "z" is not a substring of any field; fuzzy is disabled for length 1.
      final songs = [song(id: '1', title: 'Black', artist: 'Zed Album')];
      // It must only match via substring (the artist contains 'z').
      final hit = song(id: '2', title: 'Nope', artist: 'Nope', album: 'Nope');
      expect(searchSongs([hit], 'q'), isEmpty);
      // Sanity: a real substring 'z' still matches.
      expect(searchSongs(songs, 'z').single.id, '1');
    });

    test('exact title hit still outranks artist hit', () {
      final songs = [
        song(id: 'artistMatch', title: 'Something', artist: 'Aurora'),
        song(id: 'titleMatch', title: 'Aurora', artist: 'Someone'),
      ];
      expect(searchSongs(songs, 'aurora').first.id, 'titleMatch');
    });
  });
}

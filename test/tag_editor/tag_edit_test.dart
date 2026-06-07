import 'package:aura_music_player/domain/library/tag_edit.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song(String id, {String? genre, int? year, String title = 'T'}) => Song(
      id: id,
      title: title,
      artist: 'A',
      album: 'Al',
      albumId: 'al1',
      artistId: 'ar1',
      duration: const Duration(seconds: 100),
      filePath: '/m/$id.flac',
      dateAdded: DateTime(2024),
      genre: genre,
      year: year,
    );

void main() {
  group('SongTagEdit', () {
    test('isEmpty when nothing set', () {
      expect(const SongTagEdit().isEmpty, isTrue);
      expect(const SongTagEdit(title: 'x').isEmpty, isFalse);
    });

    test('applyTo changes only set fields', () {
      final s = _song('s1', genre: 'Rock', year: 2001, title: 'Old');
      final out = const SongTagEdit(title: 'New', genre: 'Jazz').applyTo(s);
      expect(out.title, 'New');
      expect(out.genre, 'Jazz');
      expect(out.year, 2001); // untouched
      expect(out.id, 's1');
    });

    test('applyToAll maps every song', () {
      final songs = [_song('a'), _song('b')];
      final out = const SongTagEdit(genre: 'Pop').applyToAll(songs);
      expect(out.every((s) => s.genre == 'Pop'), isTrue);
      expect(out.map((s) => s.id), ['a', 'b']);
    });
  });

  group('commonValue', () {
    test('shared value when all equal', () {
      final songs = [_song('a', genre: 'Rock'), _song('b', genre: 'Rock')];
      final c = commonValue(songs, (s) => s.genre);
      expect(c.multiple, isFalse);
      expect(c.value, 'Rock');
    });

    test('multiple when values differ', () {
      final songs = [_song('a', genre: 'Rock'), _song('b', genre: 'Pop')];
      final c = commonValue(songs, (s) => s.genre);
      expect(c.multiple, isTrue);
      expect(c.value, isNull);
    });

    test('single song is never multiple', () {
      final c = commonValue([_song('a', genre: 'Rock')], (s) => s.genre);
      expect(c.multiple, isFalse);
      expect(c.value, 'Rock');
    });
  });
}

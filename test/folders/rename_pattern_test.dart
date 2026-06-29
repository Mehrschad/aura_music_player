import 'package:aura_music_player/domain/library/rename_pattern.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song({
  String title = 'The National Anthem',
  String artist = 'Radiohead',
  String? albumArtist = 'Radiohead',
  String album = 'Kid A',
  int? year = 2000,
  int? track = 3,
  int? disc = 1,
  String path = '/Music/anthem.flac',
}) =>
    Song(
      id: 'x',
      title: title,
      artist: artist,
      albumArtist: albumArtist,
      album: album,
      albumId: 'al',
      artistId: 'ar',
      year: year,
      trackNumber: track,
      discNumber: disc,
      duration: const Duration(seconds: 200),
      filePath: path,
      dateAdded: DateTime(2024),
    );

void main() {
  test('renders a full directory pattern', () {
    final out = RenamePattern.render(
      '{albumartist}/{album} ({year})/{track:02} - {title}.{ext}',
      _song(),
    );
    expect(out, 'Radiohead/Kid A (2000)/03 - The National Anthem.flac');
  });

  test('zero-pads track and disc', () {
    final out = RenamePattern.render('{disc:02}-{track:02} {title}.{ext}',
        _song(track: 7, disc: 2));
    expect(out, '02-07 The National Anthem.flac');
  });

  test('keeps the song extension when {ext} used', () {
    final out =
        RenamePattern.render('{title}.{ext}', _song(path: '/m/x.mp3'));
    expect(out, 'The National Anthem.mp3');
  });

  test('sanitises illegal characters in values', () {
    final out = RenamePattern.render(
      '{title}.{ext}',
      _song(title: 'A/B: "C" <D>?'),
    );
    // Slashes and reserved chars become spaces, then whitespace collapses;
    // no new folders are created from a slash inside a tag value.
    expect(out.contains('/'), isFalse);
    expect(out, 'A B C D.flac');
  });

  test('drops fully empty path segments', () {
    final out = RenamePattern.render(
      '{albumartist}/{album}/{title}.{ext}',
      _song(album: ''),
    );
    // The empty {album} segment vanishes rather than leaving a `//`.
    expect(out, 'Radiohead/The National Anthem.flac');
  });

  test('albumartist falls back to artist', () {
    final out = RenamePattern.render('{albumartist}/{title}.{ext}',
        _song(albumArtist: null, artist: 'Solo'));
    expect(out, 'Solo/The National Anthem.flac');
  });

  test('preview limits to N rows', () {
    final songs = [for (var i = 0; i < 10; i++) _song(track: i)];
    final preview = RenamePattern.preview(songs, '{track} {title}.{ext}',
        limit: 5);
    expect(preview.length, 5);
    expect(preview.first.result, '0 The National Anthem.flac');
  });
}

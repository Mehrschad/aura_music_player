import 'package:aura_music_player/domain/library/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parentDir / basename', () {
    test('splits a normal path', () {
      expect(PathUtils.parentDir('/storage/emulated/0/Music/a.flac'),
          '/storage/emulated/0/Music');
      expect(PathUtils.basename('/storage/emulated/0/Music/a.flac'), 'a.flac');
    });

    test('handles trailing slashes', () {
      expect(PathUtils.parentDir('/a/b/'), '/a');
      expect(PathUtils.basename('/a/b/'), 'b');
    });

    test('top-level file', () {
      expect(PathUtils.parentDir('/a.flac'), '/');
    });
  });

  group('extension', () {
    test('lower-cases and strips the dot', () {
      expect(PathUtils.extension('/m/Song.FLAC'), 'flac');
      expect(PathUtils.extension('/m/track.mp3'), 'mp3');
    });
    test('no extension', () {
      expect(PathUtils.extension('/m/folder'), '');
      expect(PathUtils.extension('/m/.hidden'), '');
    });
  });

  group('isWithin (segment-aware)', () {
    test('true for self and descendants', () {
      expect(PathUtils.isWithin('/a/b', '/a/b'), isTrue);
      expect(PathUtils.isWithin('/a/b/c', '/a/b'), isTrue);
    });
    test('false for sibling prefixes', () {
      expect(PathUtils.isWithin('/a/bc', '/a/b'), isFalse);
    });
    test('empty parent contains everything', () {
      expect(PathUtils.isWithin('/a/b', ''), isTrue);
    });
  });

  group('join', () {
    test('single separator regardless of slashes', () {
      expect(PathUtils.join('/a/', '/b'), '/a/b');
      expect(PathUtils.join('/a', 'b'), '/a/b');
    });
  });

  group('storage labels (mixed internal + SD)', () {
    test('internal storage', () {
      expect(PathUtils.storageLabel('/storage/emulated/0/Music/x.mp3'),
          'Internal');
      expect(PathUtils.isRemovable('/storage/emulated/0/Music/x.mp3'), isFalse);
    });
    test('removable SD volume', () {
      expect(PathUtils.storageLabel('/storage/1A2B-3C4D/Music/x.mp3'),
          'SD card');
      expect(PathUtils.isRemovable('/storage/1A2B-3C4D/Music/x.mp3'), isTrue);
    });
  });
}

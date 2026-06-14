import 'package:aura_music_player/domain/library/folder_logic.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song(String path, {int seconds = 100}) => Song(
      id: path,
      title: 'T',
      artist: 'A',
      album: 'Al',
      albumId: 'al',
      artistId: 'ar',
      duration: Duration(seconds: seconds),
      filePath: path,
      dateAdded: DateTime(2024),
    );

void main() {
  group('exclusion', () {
    test('isExcluded matches self and descendants only', () {
      expect(FolderLogic.isExcluded('/a/b', ['/a/b']), isTrue);
      expect(FolderLogic.isExcluded('/a/b/c', ['/a/b']), isTrue);
      expect(FolderLogic.isExcluded('/a/bc', ['/a/b']), isFalse);
      expect(FolderLogic.isExcluded('/a/b', ['/x']), isFalse);
    });

    test('filter drops excluded folders', () {
      final songs = [
        _song('/Music/keep/1.mp3'),
        _song('/Music/skip/2.mp3'),
        _song('/Music/skip/sub/3.mp3'),
      ];
      final out = FolderLogic.filter(songs,
          excludedFolders: ['/Music/skip'], hideDotFolders: false);
      expect(out.map((s) => s.id), ['/Music/keep/1.mp3']);
    });
  });

  group('hidden rules', () {
    test('hides dot folders', () {
      final songs = [
        _song('/Music/.thumbnails/a.mp3'),
        _song('/Music/Albums/b.mp3'),
      ];
      final out = FolderLogic.filter(songs, hideDotFolders: true);
      expect(out.map((s) => s.id), ['/Music/Albums/b.mp3']);
    });

    test('drops short tracks below the minimum', () {
      final songs = [
        _song('/M/a.mp3', seconds: 5),
        _song('/M/b.mp3', seconds: 90),
      ];
      final out = FolderLogic.filter(songs,
          hideDotFolders: false, minTrackSeconds: 30);
      expect(out.map((s) => s.id), ['/M/b.mp3']);
    });

    test('no-op when all rules disabled returns same list', () {
      final songs = [_song('/M/a.mp3')];
      expect(
        identical(FolderLogic.filter(songs, hideDotFolders: false), songs),
        isTrue,
      );
    });
  });

  group('grouping (mixed internal + SD)', () {
    test('groups by immediate directory', () {
      final songs = [
        _song('/storage/emulated/0/Music/Rock/1.mp3'),
        _song('/storage/emulated/0/Music/Rock/2.mp3'),
        _song('/storage/1A2B-3C4D/Pop/3.mp3'),
      ];
      final folders = FolderLogic.groupByFolder(songs);
      expect(folders.length, 2);
      final rock =
          folders.firstWhere((f) => f.path.endsWith('Rock'));
      expect(rock.trackCount, 2);
      expect(rock.storageLabel, 'Internal');
      final pop = folders.firstWhere((f) => f.path.endsWith('Pop'));
      expect(pop.storageLabel, 'SD card');
    });

    test('sort by track count is descending', () {
      final songs = [
        _song('/M/A/1.mp3'),
        _song('/M/B/1.mp3'),
        _song('/M/B/2.mp3'),
      ];
      final folders =
          FolderLogic.groupByFolder(songs, sort: FolderSort.trackCount);
      expect(folders.first.path.endsWith('B'), isTrue);
    });
  });

  group('hierarchical browse', () {
    final songs = [
      _song('/M/Rock/1.mp3'),
      _song('/M/Rock/Live/2.mp3'),
      _song('/M/Pop/3.mp3'),
      _song('/M/top.mp3'),
    ];

    test('common ancestor', () {
      expect(FolderLogic.commonAncestor(songs), '/M');
    });

    test('browse root lists immediate children + direct songs', () {
      final listing = FolderLogic.browse(songs, '/M');
      expect(listing.folders.map((f) => f.path).toSet(),
          {'/M/Rock', '/M/Pop'});
      // Rock carries both its direct + nested track (recursive count).
      final rock = listing.folders.firstWhere((f) => f.path == '/M/Rock');
      expect(rock.trackCount, 2);
      expect(listing.songs.map((s) => s.id), ['/M/top.mp3']);
    });

    test('browse into a subfolder', () {
      final listing = FolderLogic.browse(songs, '/M/Rock');
      expect(listing.folders.map((f) => f.path), ['/M/Rock/Live']);
      expect(listing.songs.map((s) => s.id), ['/M/Rock/1.mp3']);
    });
  });
}

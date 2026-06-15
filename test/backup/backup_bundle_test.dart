import 'package:aura_music_player/domain/backup/backup_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupBundle', () {
    test('toJson/fromJson round-trips every field', () {
      final bundle = BackupBundle(
        formatVersion: BackupBundle.currentFormatVersion,
        appVersion: '1.2.3',
        createdAtMs: 1700000000000,
        sections: {
          BackupSections.ratings: {'song-1': 5},
          BackupSections.favoriteArtists: ['a-1', 'a-2'],
        },
      );

      final restored = BackupBundle.fromJson(bundle.toJson());

      expect(restored.formatVersion, BackupBundle.currentFormatVersion);
      expect(restored.appVersion, '1.2.3');
      expect(restored.createdAtMs, 1700000000000);
      expect(restored.createdAt,
          DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(restored.sections[BackupSections.ratings], {'song-1': 5});
      expect(restored.sections[BackupSections.favoriteArtists], ['a-1', 'a-2']);
    });

    test('sectionCount reflects the number of sections', () {
      final bundle = BackupBundle(
        formatVersion: 1,
        appVersion: 'x',
        createdAtMs: 0,
        sections: const {'a': 1, 'b': 2, 'c': 3},
      );
      expect(bundle.sectionCount, 3);
    });

    test('fromJson throws when formatVersion is missing', () {
      expect(
        () => BackupBundle.fromJson({'sections': <String, dynamic>{}}),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('fromJson throws when formatVersion is not an int', () {
      expect(
        () => BackupBundle.fromJson(
            {'formatVersion': '1', 'sections': <String, dynamic>{}}),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('fromJson throws on an unsupported newer format version', () {
      expect(
        () => BackupBundle.fromJson({
          'formatVersion': BackupBundle.currentFormatVersion + 1,
          'sections': <String, dynamic>{},
        }),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('fromJson throws when sections is missing', () {
      expect(
        () => BackupBundle.fromJson({'formatVersion': 1}),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('fromJson throws when sections is not a map', () {
      expect(
        () => BackupBundle.fromJson({'formatVersion': 1, 'sections': 'nope'}),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('fromJson accepts an older but supported format version', () {
      final bundle = BackupBundle.fromJson({
        'formatVersion': 1,
        'appVersion': '0.9',
        'createdAt': 42,
        'sections': {'settings': <String, dynamic>{}},
      });
      expect(bundle.formatVersion, 1);
      expect(bundle.appVersion, '0.9');
      expect(bundle.createdAtMs, 42);
      expect(bundle.sectionCount, 1);
    });

    test('fromJson falls back gracefully on optional fields', () {
      final bundle = BackupBundle.fromJson({
        'formatVersion': 1,
        'sections': <String, dynamic>{},
      });
      expect(bundle.appVersion, 'unknown');
      expect(bundle.createdAtMs, 0);
    });
  });
}

import 'package:aura_music_player/domain/library/playlist_logic.dart';
import 'package:aura_music_player/domain/models/playlist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../library/_fixtures.dart';

void main() {
  final now = DateTime(2026, 6, 1);

  group('buildM3u8', () {
    test('emits header, EXTINF and path lines', () {
      final m3u = buildM3u8([
        song(id: '1', title: 'Title', artist: 'Artist', secs: 200),
      ]);
      expect(m3u.startsWith('#EXTM3U\n'), isTrue);
      expect(m3u, contains('#EXTINF:200,Artist - Title'));
      expect(m3u, contains('/m/1.flac'));
    });
  });

  group('autoPlaylistSongs', () {
    final songs = [
      song(id: 'old', added: now.subtract(const Duration(days: 60)), plays: 0),
      song(id: 'new1', added: now.subtract(const Duration(days: 2)), plays: 5,
          lastPlayed: now.subtract(const Duration(days: 1))),
      song(id: 'new2', added: now.subtract(const Duration(days: 10)), plays: 99,
          lastPlayed: now.subtract(const Duration(hours: 2))),
    ];

    test('recentlyAdded keeps last 30 days, newest first', () {
      final out = autoPlaylistSongs(AutoPlaylist.recentlyAdded, songs,
          favoriteIds: const {}, now: now);
      expect(out.map((s) => s.id), ['new1', 'new2']);
    });

    test('mostPlayed keeps plays > 0, highest first', () {
      final out = autoPlaylistSongs(AutoPlaylist.mostPlayed, songs,
          favoriteIds: const {}, now: now);
      expect(out.map((s) => s.id), ['new2', 'new1']);
    });

    test('recentlyPlayed keeps played tracks, most recent first', () {
      final out = autoPlaylistSongs(AutoPlaylist.recentlyPlayed, songs,
          favoriteIds: const {}, now: now);
      expect(out.map((s) => s.id), ['new2', 'new1']);
    });

    test('favorites keeps only favourited ids in library order', () {
      final out = autoPlaylistSongs(AutoPlaylist.favorites, songs,
          favoriteIds: {'old', 'new2'}, now: now);
      expect(out.map((s) => s.id), ['old', 'new2']);
    });
  });
}

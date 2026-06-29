import 'package:aura_music_player/domain/models/play_event.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:aura_music_player/domain/stats/stats_logic.dart';
import 'package:flutter_test/flutter_test.dart';

PlayEvent _ev({
  String song = 's1',
  String artist = 'A',
  String album = 'Al',
  String? genre = 'Rock',
  required DateTime at,
  int minutes = 3,
  bool completed = true,
}) =>
    PlayEvent(
      songId: song,
      title: song,
      artist: artist,
      album: album,
      genre: genre,
      atMs: at.millisecondsSinceEpoch,
      msPlayed: minutes * 60000,
      completed: completed,
    );

void main() {
  final now = DateTime(2026, 6, 14, 12); // a Sunday

  group('period filtering', () {
    test('today excludes earlier days and skips', () {
      final events = [
        _ev(at: DateTime(2026, 6, 14, 9)),
        _ev(at: DateTime(2026, 6, 13, 9)),
        _ev(at: DateTime(2026, 6, 14, 8), completed: false), // skip excluded
      ];
      final today = StatsLogic.inPeriod(events, StatsPeriod.today, now);
      expect(today.length, 1);
    });

    test('week starts Monday', () {
      // now is Sunday 14th; Monday of this week is the 8th.
      final events = [
        _ev(at: DateTime(2026, 6, 8, 1)), // Monday — included
        _ev(at: DateTime(2026, 6, 7, 23)), // Sunday prior — excluded
      ];
      expect(StatsLogic.inPeriod(events, StatsPeriod.week, now).length, 1);
    });

    test('all time keeps everything completed', () {
      final events = [
        _ev(at: DateTime(2020, 1, 1)),
        _ev(at: DateTime(2010, 1, 1)),
      ];
      expect(StatsLogic.inPeriod(events, StatsPeriod.allTime, now).length, 2);
    });
  });

  group('overview', () {
    test('aggregates plays, time and uniques', () {
      final plays = [
        _ev(song: 's1', artist: 'A', album: 'X', at: now, minutes: 3),
        _ev(song: 's2', artist: 'B', album: 'X', at: now, minutes: 4),
        _ev(song: 's1', artist: 'A', album: 'X', at: now, minutes: 3),
      ];
      final o = StatsLogic.overview(plays);
      expect(o.totalPlays, 3);
      expect(o.totalListening, const Duration(minutes: 10));
      expect(o.uniqueTracks, 2);
      expect(o.uniqueArtists, 2);
      expect(o.uniqueAlbums, 1);
    });

    test('empty overview', () {
      expect(StatsLogic.overview(const []).totalPlays, 0);
    });
  });

  group('top lists', () {
    final plays = [
      _ev(song: 's1', artist: 'A', at: now),
      _ev(song: 's1', artist: 'A', at: now),
      _ev(song: 's2', artist: 'B', at: now),
    ];

    test('top songs ranked by plays with label resolution', () {
      final top = StatsLogic.topSongs(plays, labelFor: (id) => 'T-$id');
      expect(top.first.key, 's1');
      expect(top.first.plays, 2);
      expect(top.first.label, 'T-s1');
    });

    test('top artists', () {
      final top = StatsLogic.topArtists(plays);
      expect(top.first.label, 'A');
      expect(top.first.plays, 2);
    });

    test('top genres ranked by plays', () {
      final genrePlays = [
        _ev(song: 's1', genre: 'Rock', at: now),
        _ev(song: 's2', genre: 'Rock', at: now),
        _ev(song: 's3', genre: 'Jazz', at: now),
      ];
      final top = StatsLogic.topGenres(genrePlays);
      expect(top.first.label, 'Rock');
      expect(top.first.plays, 2);
      expect(top[1].label, 'Jazz');
    });
  });

  group('heatmap', () {
    test('always has exactly N day keys and buckets minutes', () {
      final plays = [
        _ev(at: DateTime(2026, 6, 14, 10), minutes: 5),
        _ev(at: DateTime(2026, 6, 14, 11), minutes: 5),
        _ev(at: DateTime(2026, 6, 10, 9), minutes: 8),
      ];
      final map = StatsLogic.heatmap(plays, days: 30, now: now);
      expect(map.length, 30);
      expect(map[DateTime(2026, 6, 14)], 10);
      expect(map[DateTime(2026, 6, 10)], 8);
      expect(map[DateTime(2026, 6, 13)], 0);
    });

    test('drops events older than the window', () {
      final plays = [_ev(at: DateTime(2025, 1, 1), minutes: 9)];
      final map = StatsLogic.heatmap(plays, days: 30, now: now);
      expect(map.values.fold<int>(0, (a, b) => a + b), 0);
    });
  });

  group('time-of-day / day-of-week', () {
    test('buckets by hour', () {
      final plays = [
        _ev(at: DateTime(2026, 6, 14, 9), minutes: 2),
        _ev(at: DateTime(2026, 6, 14, 9), minutes: 3),
        _ev(at: DateTime(2026, 6, 14, 22), minutes: 1),
      ];
      final hours = StatsLogic.timeOfDay(plays);
      expect(hours.length, 24);
      expect(hours[9], 5);
      expect(hours[22], 1);
    });

    test('buckets by weekday (Mon=0)', () {
      final plays = [_ev(at: DateTime(2026, 6, 8, 9), minutes: 4)]; // Monday
      final dow = StatsLogic.dayOfWeek(plays);
      expect(dow[0], 4);
    });
  });

  group('streak', () {
    test('counts consecutive days ending today', () {
      final plays = [
        _ev(at: DateTime(2026, 6, 14, 8)),
        _ev(at: DateTime(2026, 6, 13, 8)),
        _ev(at: DateTime(2026, 6, 12, 8)),
        // gap on the 11th
        _ev(at: DateTime(2026, 6, 10, 8)),
      ];
      expect(StatsLogic.currentStreak(plays, now), 3);
    });

    test('allows the streak to count from yesterday', () {
      final plays = [
        _ev(at: DateTime(2026, 6, 13, 8)),
        _ev(at: DateTime(2026, 6, 12, 8)),
      ];
      expect(StatsLogic.currentStreak(plays, now), 2);
    });

    test('zero when last play is too old', () {
      final plays = [_ev(at: DateTime(2026, 6, 1, 8))];
      expect(StatsLogic.currentStreak(plays, now), 0);
    });

    test('ignores sub-minute plays', () {
      final plays = [
        PlayEvent(
            songId: 's',
            title: 's',
            artist: 'A',
            album: 'X',
            genre: null,
            atMs: now.millisecondsSinceEpoch,
            msPlayed: 30000, // < 1 min
            completed: true),
      ];
      expect(StatsLogic.currentStreak(plays, now), 0);
    });
  });

  group('forgotten gems', () {
    Song song(String id, {int plays = 0, required DateTime added}) => Song(
          id: id,
          title: id,
          artist: 'A',
          album: 'Al',
          albumId: 'al',
          artistId: 'ar',
          duration: const Duration(minutes: 3),
          filePath: '/m/$id.mp3',
          dateAdded: added,
          playCount: plays,
        );

    test('old + rarely played, oldest first', () {
      final songs = [
        song('new', added: DateTime(2026, 6, 13)), // too new
        song('played', plays: 5, added: DateTime(2026, 1, 1)), // too played
        song('gemB', added: DateTime(2026, 3, 1)),
        song('gemA', added: DateTime(2026, 1, 15)),
      ];
      final gems = StatsLogic.forgottenGems(songs, now: now);
      expect(gems.map((s) => s.id), ['gemA', 'gemB']);
    });
  });
}

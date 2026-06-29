import 'package:aura_music_player/domain/models/play_event.dart';
import 'package:aura_music_player/domain/stats/history_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

PlayEvent _ev({
  String song = 's1',
  String artist = 'A',
  String album = 'Al',
  String? genre = 'Rock',
  required DateTime at,
  bool completed = true,
}) =>
    PlayEvent(
      songId: song,
      title: song,
      artist: artist,
      album: album,
      genre: genre,
      atMs: at.millisecondsSinceEpoch,
      msPlayed: 180000,
      completed: completed,
    );

void main() {
  group('HistoryTimeline.groupByDay', () {
    test('empty input yields empty list', () {
      expect(HistoryTimeline.groupByDay(const []), isEmpty);
    });

    test('events on the same day bucket together, newest-first within a day', () {
      final days = HistoryTimeline.groupByDay([
        _ev(song: 'early', at: DateTime(2026, 6, 14, 9)),
        _ev(song: 'late', at: DateTime(2026, 6, 14, 18)),
        _ev(song: 'mid', at: DateTime(2026, 6, 14, 12)),
      ]);
      expect(days, hasLength(1));
      expect(
        days.single.events.map((e) => e.songId).toList(),
        ['late', 'mid', 'early'],
      );
    });

    test('different days produce separate buckets, newest day first', () {
      final days = HistoryTimeline.groupByDay([
        _ev(song: 'old', at: DateTime(2026, 6, 13, 10)),
        _ev(song: 'new', at: DateTime(2026, 6, 14, 10)),
      ]);
      expect(days, hasLength(2));
      expect(days.first.date, DateTime(2026, 6, 14));
      expect(days.first.events.single.songId, 'new');
      expect(days.last.date, DateTime(2026, 6, 13));
      expect(days.last.events.single.songId, 'old');
    });

    test('23:59 and 00:01 the next day land in different buckets', () {
      final days = HistoryTimeline.groupByDay([
        _ev(song: 'late', at: DateTime(2026, 6, 14, 23, 59)),
        _ev(song: 'after_midnight', at: DateTime(2026, 6, 15, 0, 1)),
      ]);
      expect(days, hasLength(2));
      expect(days.first.date, DateTime(2026, 6, 15));
      expect(days.last.date, DateTime(2026, 6, 14));
    });

    test('skips are included alongside plays', () {
      final days = HistoryTimeline.groupByDay([
        _ev(song: 'played', at: DateTime(2026, 6, 14, 9)),
        _ev(song: 'skipped', at: DateTime(2026, 6, 14, 10), completed: false),
      ]);
      expect(days.single.events, hasLength(2));
      expect(days.single.events.first.songId, 'skipped');
      expect(days.single.events.first.completed, isFalse);
    });
  });
}

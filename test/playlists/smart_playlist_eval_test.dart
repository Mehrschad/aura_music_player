import 'package:aura_music_player/domain/library/smart_playlist.dart';
import 'package:aura_music_player/domain/library/smart_playlist_eval.dart';
import 'package:aura_music_player/domain/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2025, 1, 1);

Song _s(
  String id, {
  String title = 'Song',
  String genre = 'Rock',
  int year = 2000,
  int seconds = 200,
  int playCount = 0,
  bool hasLyrics = false,
  int addedDaysAgo = 5,
}) =>
    Song(
      id: id,
      title: title,
      artist: 'Artist',
      album: 'Album',
      albumId: 'al',
      artistId: 'ar',
      duration: Duration(seconds: seconds),
      filePath: '/m/$id',
      dateAdded: _now.subtract(Duration(days: addedDaysAgo)),
      genre: genre,
      year: year,
      playCount: playCount,
      hasLyrics: hasLyrics,
    );

SmartPlaylist _sp(List<SmartRule> rules,
        {RuleMatch match = RuleMatch.all,
        RuleField sort = RuleField.title,
        bool desc = false,
        SmartLimit limit = SmartLimit.none}) =>
    SmartPlaylist(
        id: 'x',
        name: 'x',
        rules: rules,
        match: match,
        sortField: sort,
        sortDescending: desc,
        limit: limit);

List<String> _ids(List<Song> s) => s.map((e) => e.id).toList();

void main() {
  final songs = [
    _s('a', title: 'Apple', genre: 'Rock', year: 1999, seconds: 300, playCount: 10, hasLyrics: true),
    _s('b', title: 'Banana', genre: 'Pop', year: 2010, seconds: 150, playCount: 2),
    _s('c', title: 'Cherry', genre: 'Rock', year: 2020, seconds: 600, playCount: 0, hasLyrics: true, addedDaysAgo: 60),
  ];

  test('text contains', () {
    final r = const SmartRule(
        field: RuleField.title, op: RuleOperator.contains, value: 'err');
    expect(_ids(evaluateSmartPlaylist(_sp([r]), songs, now: _now)), ['c']);
  });

  test('integer greaterThan', () {
    final r = const SmartRule(
        field: RuleField.year, op: RuleOperator.greaterThan, value: '2005');
    expect(_ids(evaluateSmartPlaylist(_sp([r]), songs, now: _now)), ['b', 'c']);
  });

  test('duration inRange (seconds)', () {
    final r = const SmartRule(
        field: RuleField.duration,
        op: RuleOperator.inRange,
        value: '200',
        value2: '400');
    expect(_ids(evaluateSmartPlaylist(_sp([r]), songs, now: _now)), ['a']);
  });

  test('date lessThan N days = recently added', () {
    final r = const SmartRule(
        field: RuleField.dateAdded, op: RuleOperator.lessThan, value: '30');
    // a,b added 5 days ago; c added 60 days ago.
    expect(_ids(evaluateSmartPlaylist(_sp([r]), songs, now: _now)), ['a', 'b']);
  });

  test('boolean is true', () {
    final r = const SmartRule(
        field: RuleField.hasLyrics, op: RuleOperator.is_, value: 'true');
    expect(_ids(evaluateSmartPlaylist(_sp([r]), songs, now: _now)), ['a', 'c']);
  });

  test('AND vs OR', () {
    final rules = [
      const SmartRule(field: RuleField.genre, op: RuleOperator.is_, value: 'Rock'),
      const SmartRule(field: RuleField.hasLyrics, op: RuleOperator.is_, value: 'true'),
    ];
    expect(_ids(evaluateSmartPlaylist(_sp(rules, match: RuleMatch.all), songs, now: _now)),
        ['a', 'c']);
    expect(
        _ids(evaluateSmartPlaylist(_sp(rules, match: RuleMatch.any), songs, now: _now)),
        ['a', 'c']); // b is Pop & no lyrics
  });

  test('sort descending by playCount + limit by songs', () {
    final sp = _sp(const [],
        sort: RuleField.playCount,
        desc: true,
        limit: SmartLimit(kind: SmartLimitKind.songs, value: 2));
    expect(_ids(evaluateSmartPlaylist(sp, songs, now: _now)), ['a', 'b']);
  });

  test('limit by minutes accumulates until cap', () {
    // sort by duration asc: b(150s) a(300s) c(600s). Cap 8 min = 480s.
    final sp = _sp(const [],
        sort: RuleField.duration,
        limit: SmartLimit(kind: SmartLimitKind.minutes, value: 8));
    expect(_ids(evaluateSmartPlaylist(sp, songs, now: _now)), ['b', 'a']);
  });
}

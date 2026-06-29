import '../models/play_event.dart';
import '../models/song.dart';

/// Time window the stats screen aggregates over.
enum StatsPeriod { today, week, month, year, allTime }

/// A ranked entry in a "top" list (artist / album / song / genre).
class StatEntry {
  const StatEntry({
    required this.key,
    required this.label,
    required this.plays,
    required this.listened,
  });

  /// Stable identity (song id, or the name itself for artist/album/genre).
  final String key;
  final String label;
  final int plays;
  final Duration listened;
}

/// The headline numbers shown at the top of the stats screen.
class StatsOverview {
  const StatsOverview({
    required this.totalPlays,
    required this.totalListening,
    required this.uniqueTracks,
    required this.uniqueArtists,
    required this.uniqueAlbums,
  });

  static const StatsOverview empty = StatsOverview(
    totalPlays: 0,
    totalListening: Duration.zero,
    uniqueTracks: 0,
    uniqueArtists: 0,
    uniqueAlbums: 0,
  );

  final int totalPlays;
  final Duration totalListening;
  final int uniqueTracks;
  final int uniqueArtists;
  final int uniqueAlbums;
}

/// Pure listening-stats aggregation over a list of [PlayEvent]s. No Flutter, no
/// I/O — every function takes an injectable [now] so tests stay deterministic.
abstract final class StatsLogic {
  const StatsLogic._();

  /// Inclusive start of [period] relative to [now]. AllTime → epoch 0.
  static DateTime periodStart(StatsPeriod period, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return switch (period) {
      StatsPeriod.today => day,
      StatsPeriod.week => day.subtract(Duration(days: now.weekday - 1)),
      StatsPeriod.month => DateTime(now.year, now.month),
      StatsPeriod.year => DateTime(now.year),
      StatsPeriod.allTime => DateTime.fromMillisecondsSinceEpoch(0),
    };
  }

  /// Events that fall within [period] (only completed plays count toward stats).
  static List<PlayEvent> inPeriod(
    List<PlayEvent> events,
    StatsPeriod period,
    DateTime now,
  ) {
    final startMs = periodStart(period, now).millisecondsSinceEpoch;
    return [
      for (final e in events)
        if (e.completed && e.atMs >= startMs) e,
    ];
  }

  static StatsOverview overview(List<PlayEvent> plays) {
    if (plays.isEmpty) return StatsOverview.empty;
    final tracks = <String>{};
    final artists = <String>{};
    final albums = <String>{};
    var ms = 0;
    for (final e in plays) {
      tracks.add(e.songId);
      if (e.artist.isNotEmpty) artists.add(e.artist);
      if (e.album.isNotEmpty) albums.add(e.album);
      ms += e.msPlayed;
    }
    return StatsOverview(
      totalPlays: plays.length,
      totalListening: Duration(milliseconds: ms),
      uniqueTracks: tracks.length,
      uniqueArtists: artists.length,
      uniqueAlbums: albums.length,
    );
  }

  static List<StatEntry> topArtists(List<PlayEvent> plays, {int limit = 10}) =>
      _rank(plays, limit, (e) => e.artist, (e) => e.artist);

  static List<StatEntry> topAlbums(List<PlayEvent> plays, {int limit = 10}) =>
      _rank(plays, limit, (e) => e.album, (e) => e.album);

  static List<StatEntry> topGenres(List<PlayEvent> plays, {int limit = 8}) =>
      _rank(plays, limit, (e) => e.genre ?? '', (e) => e.genre ?? '');

  /// Top songs. [labelFor] resolves a display title from the song id; falls
  /// back to the id when unknown.
  static List<StatEntry> topSongs(
    List<PlayEvent> plays, {
    int limit = 10,
    String Function(String id)? labelFor,
  }) =>
      _rank(plays, limit, (e) => e.songId,
          (e) => labelFor?.call(e.songId) ?? e.songId);

  /// Minutes listened per calendar day for the last [days] days (heatmap data),
  /// keyed by date-only `DateTime`. Always contains exactly [days] keys.
  static Map<DateTime, int> heatmap(
    List<PlayEvent> plays, {
    int days = 365,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final map = <DateTime, int>{};
    for (var i = 0; i < days; i++) {
      map[today.subtract(Duration(days: i))] = 0;
    }
    final earliest = today.subtract(Duration(days: days - 1));
    for (final e in plays) {
      final d = e.at;
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(earliest)) continue;
      map[day] = (map[day] ?? 0) + (e.msPlayed ~/ 60000);
    }
    return map;
  }

  /// Minutes listened per hour-of-day (24 buckets, index = hour).
  static List<int> timeOfDay(List<PlayEvent> plays) {
    final buckets = List<int>.filled(24, 0);
    for (final e in plays) {
      buckets[e.at.hour] += e.msPlayed ~/ 60000;
    }
    return buckets;
  }

  /// Minutes listened per weekday (7 buckets, index 0 = Monday).
  static List<int> dayOfWeek(List<PlayEvent> plays) {
    final buckets = List<int>.filled(7, 0);
    for (final e in plays) {
      buckets[e.at.weekday - 1] += e.msPlayed ~/ 60000;
    }
    return buckets;
  }

  /// Current streak of consecutive days (ending today or yesterday) that each
  /// had at least one minute of listening.
  static int currentStreak(List<PlayEvent> plays, DateTime now) {
    final daysWithPlay = <DateTime>{};
    for (final e in plays) {
      if (e.msPlayed < 60000) continue;
      final d = e.at;
      daysWithPlay.add(DateTime(d.year, d.month, d.day));
    }
    if (daysWithPlay.isEmpty) return 0;

    final today = DateTime(now.year, now.month, now.day);
    // Allow the streak to "count" from today or yesterday.
    var cursor = today;
    if (!daysWithPlay.contains(today)) {
      final yesterday = today.subtract(const Duration(days: 1));
      if (!daysWithPlay.contains(yesterday)) return 0;
      cursor = yesterday;
    }
    var streak = 0;
    while (daysWithPlay.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// "Forgotten gems": tracks added more than [olderThanDays] days ago with
  /// fewer than [maxPlays] plays, oldest first.
  static List<Song> forgottenGems(
    List<Song> songs, {
    required DateTime now,
    int olderThanDays = 30,
    int maxPlays = 2,
  }) {
    final cutoff = now.subtract(Duration(days: olderThanDays));
    final gems = [
      for (final s in songs)
        if (s.playCount < maxPlays && s.dateAdded.isBefore(cutoff)) s,
    ];
    gems.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
    return gems;
  }

  // ── internals ──────────────────────────────────────────────────────────────

  static List<StatEntry> _rank(
    List<PlayEvent> plays,
    int limit,
    String Function(PlayEvent) keyOf,
    String Function(PlayEvent) labelOf,
  ) {
    final counts = <String, int>{};
    final ms = <String, int>{};
    final labels = <String, String>{};
    for (final e in plays) {
      final k = keyOf(e);
      if (k.isEmpty) continue;
      counts[k] = (counts[k] ?? 0) + 1;
      ms[k] = (ms[k] ?? 0) + e.msPlayed;
      labels[k] ??= labelOf(e);
    }
    final entries = [
      for (final k in counts.keys)
        StatEntry(
          key: k,
          label: labels[k] ?? k,
          plays: counts[k]!,
          listened: Duration(milliseconds: ms[k]!),
        ),
    ];
    // Most plays first; ties broken by total time then label for determinism.
    entries.sort((a, b) {
      final byPlays = b.plays.compareTo(a.plays);
      if (byPlays != 0) return byPlays;
      final byTime = b.listened.compareTo(a.listened);
      if (byTime != 0) return byTime;
      return a.label.compareTo(b.label);
    });
    return entries.take(limit).toList();
  }
}

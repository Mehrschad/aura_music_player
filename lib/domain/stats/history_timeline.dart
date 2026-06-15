import '../models/play_event.dart';

/// One calendar day of listening history, newest events first.
class HistoryDay {
  const HistoryDay(this.date, this.events);

  /// Midnight (local) of the day these events fall on.
  final DateTime date;
  final List<PlayEvent> events;
}

/// Pure grouping of play events into day buckets for the history timeline.
class HistoryTimeline {
  /// Groups [events] by local calendar day, days ordered newest-first and the
  /// events within each day newest-first. Includes skips as well as plays.
  static List<HistoryDay> groupByDay(List<PlayEvent> events) {
    final sorted = [...events]..sort((a, b) => b.atMs.compareTo(a.atMs));
    final days = <DateTime, List<PlayEvent>>{};
    for (final e in sorted) {
      final d = e.at;
      final key = DateTime(d.year, d.month, d.day);
      (days[key] ??= <PlayEvent>[]).add(e);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) HistoryDay(k, days[k]!)];
  }
}

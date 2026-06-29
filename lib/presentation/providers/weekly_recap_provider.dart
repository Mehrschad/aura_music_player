import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stats_providers.dart';

/// A lightweight summary of the last 7 days of listening — a mini "wrapped" for
/// the home. Computed live from the play history.
class WeeklyRecap {
  const WeeklyRecap({
    required this.plays,
    required this.minutes,
    required this.distinctArtists,
    required this.topArtist,
    required this.topArtistPlays,
  });

  final int plays;
  final int minutes;
  final int distinctArtists;
  final String? topArtist;
  final int topArtistPlays;

  bool get hasData => plays > 0;

  static const WeeklyRecap empty = WeeklyRecap(
    plays: 0,
    minutes: 0,
    distinctArtists: 0,
    topArtist: null,
    topArtistPlays: 0,
  );
}

/// The user's last-7-days recap, recomputed whenever the history changes.
final weeklyRecapProvider = Provider<WeeklyRecap>((ref) {
  final history = ref.watch(playHistoryProvider);
  if (history.isEmpty) return WeeklyRecap.empty;
  final cutoff = DateTime.now()
      .subtract(const Duration(days: 7))
      .millisecondsSinceEpoch;

  var plays = 0;
  var ms = 0;
  final artistPlays = <String, int>{};
  for (final e in history) {
    if (!e.completed || e.atMs < cutoff) continue;
    plays++;
    ms += e.msPlayed;
    if (e.artist.isNotEmpty) {
      artistPlays[e.artist] = (artistPlays[e.artist] ?? 0) + 1;
    }
  }
  if (plays == 0) return WeeklyRecap.empty;

  String? top;
  var topN = 0;
  artistPlays.forEach((artist, count) {
    if (count > topN) {
      topN = count;
      top = artist;
    }
  });

  return WeeklyRecap(
    plays: plays,
    minutes: ms ~/ 60000,
    distinctArtists: artistPlays.length,
    topArtist: top,
    topArtistPlays: topN,
  );
});

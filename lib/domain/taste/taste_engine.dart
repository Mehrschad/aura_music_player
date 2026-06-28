import 'dart:math' as math;

import '../models/play_event.dart';
import '../models/song.dart';
import 'taste_profile.dart';

/// A library song scored for recommendation, with a human-readable [reason].
class ScoredSong {
  const ScoredSong({
    required this.song,
    required this.score,
    required this.reason,
  });

  final Song song;
  final double score;
  final String reason;
}

/// The taste & recommendation brain. Pure, deterministic, on-device — no cloud,
/// no ML runtime, fully explainable. Two responsibilities:
///   1. [profileFrom] — turn raw signals into a time-decayed [TasteProfile].
///   2. [recommend] — score the user's *own library* against that profile and
///      return a diversified, lightly-explored list (content-based filtering).
///
/// "Intelligence" here is the signal design, not a black box:
///   • skips count as *negative* evidence (most players ignore them);
///   • everything decays with a half-life so taste reflects the present mood;
///   • recommendations diversify per-artist, fold in time-of-day context, and
///     inject a little daily-seeded exploration to avoid a filter bubble.
class TasteEngine {
  const TasteEngine._();

  /// Evidence older than this contributes half as much; ~a month keeps the
  /// profile responsive to a changing mood while still remembering staples.
  static const Duration defaultHalfLife = Duration(days: 30);

  // ── Profile ────────────────────────────────────────────────────────────────

  static TasteProfile profileFrom({
    required List<PlayEvent> history,
    required Map<String, Song> songsById,
    Set<String> favoriteArtists = const {},
    Set<String> favoriteGenres = const {},
    Set<String> dislikedArtists = const {},
    DateTime? now,
    Duration halfLife = defaultHalfLife,
  }) {
    final ref = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final hl = halfLife.inMilliseconds.toDouble();

    final artist = <String, double>{};
    final genre = <String, double>{};
    final decade = <int, double>{};
    final hour = List<double>.filled(24, 0);
    var plays = 0;

    for (final e in history) {
      final age = ref - e.atMs;
      if (age < 0) continue;
      final decay = math.pow(0.5, age / hl).toDouble();

      // Completed play = strong positive; a skip is graded negative evidence —
      // the earlier the skip, the stronger the dislike.
      final double value;
      if (e.completed) {
        plays++;
        value = 1.0;
        hour[e.at.hour] += decay;
      } else {
        value = -0.6;
      }
      final w = decay * value;

      if (e.artist.isNotEmpty) {
        artist[e.artist] = (artist[e.artist] ?? 0) + w;
      }
      final g = e.genre;
      if (g != null && g.isNotEmpty) {
        genre[g] = (genre[g] ?? 0) + w;
      }
      final year = songsById[e.songId]?.year;
      if (year != null && year > 1900) {
        final dec = (year ~/ 10) * 10;
        decade[dec] = (decade[dec] ?? 0) + w;
      }
    }

    // Explicit signals are a firm thumb on the scale, independent of recency.
    for (final a in favoriteArtists) {
      artist[a] = (artist[a] ?? 0) + 3.0;
    }
    for (final g in favoriteGenres) {
      genre[g] = (genre[g] ?? 0) + 2.0;
    }
    // "Not interested" pushes an artist's affinity down so similar tracks drop
    // too — the engine learns from the rejection, not just hides one song.
    for (final a in dislikedArtists) {
      artist[a] = (artist[a] ?? 0) - 2.0;
    }

    return TasteProfile(
      artistAffinity: _normalizeSigned(artist),
      genreAffinity: _normalizeSigned(genre),
      decadeAffinity: _normalizeSignedInt(decade),
      hourAffinity: _normalizePositive(hour),
      playCount: plays,
    );
  }

  /// Divide by the largest magnitude so values land in [-1, 1] keeping sign.
  static Map<String, double> _normalizeSigned(Map<String, double> raw) {
    var maxAbs = 0.0;
    for (final v in raw.values) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs == 0) return const {};
    return {for (final e in raw.entries) e.key: e.value / maxAbs};
  }

  static Map<int, double> _normalizeSignedInt(Map<int, double> raw) {
    var maxAbs = 0.0;
    for (final v in raw.values) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs == 0) return const {};
    return {for (final e in raw.entries) e.key: e.value / maxAbs};
  }

  static List<double> _normalizePositive(List<double> raw) {
    var max = 0.0;
    for (final v in raw) {
      if (v > max) max = v;
    }
    if (max == 0) return raw;
    return [for (final v in raw) v / max];
  }

  // ── Scoring ──────────────────────────────────────────────────────────────

  /// Recommendation score for [song] against [profile]. Higher = better fit.
  /// Weights are tuned so the artist signal leads, genre and era support, and
  /// explicit love / freshness adjust at the margin.
  static double scoreSong({
    required Song song,
    required TasteProfile profile,
    bool isFavorite = false,
    int? rating,
    int? lastPlayedDaysAgo,
    int playCount = 0,
    int? currentHour,
    double discoveryBias = 0.5,
  }) {
    var s = 0.0;
    s += 0.45 * (profile.artistAffinity[song.artist] ?? 0);

    final g = song.genre;
    if (g != null && g.isNotEmpty) {
      s += 0.25 * (profile.genreAffinity[g] ?? 0);
    }
    final y = song.year;
    if (y != null && y > 1900) {
      s += 0.12 * (profile.decadeAffinity[(y ~/ 10) * 10] ?? 0);
    }
    if (currentHour != null &&
        currentHour >= 0 &&
        currentHour < profile.hourAffinity.length) {
      s += 0.08 * profile.hourAffinity[currentHour];
    }

    if (isFavorite) s += 0.25;
    if (rating != null) s += ((rating - 3) / 2.0) * 0.20;

    // Freshness: fatigue what was just played; gently resurface liked-but-stale.
    if (lastPlayedDaysAgo != null) {
      if (lastPlayedDaysAgo < 2) {
        s -= 0.30;
      } else if (lastPlayedDaysAgo > 30) {
        s += 0.06;
      }
    }
    // Familiar ↔ new tilt (discoveryBias: 0 = familiar, 0.5 = balanced, 1 = new).
    // A never-played song gains more as the user leans "new"; a well-worn one
    // gains more as they lean "familiar".
    if (playCount == 0) {
      s += discoveryBias * 0.16;
    } else {
      final familiarity = (playCount > 20 ? 20 : playCount) / 20.0;
      s += (1.0 - discoveryBias) * 0.16 * familiarity;
    }

    return s;
  }

  // ── Recommend ────────────────────────────────────────────────────────────

  static List<ScoredSong> recommend({
    required List<Song> library,
    required TasteProfile profile,
    Set<String> favoriteIds = const {},
    Map<String, int> ratings = const {},
    int? currentHour,
    int limit = 30,
    int maxPerArtist = 3,
    int daySeed = 0,
    double discoveryBias = 0.5,
    DateTime? now,
  }) {
    if (profile.isEmpty) return const [];
    final today = now ?? DateTime.now();

    final scored = <ScoredSong>[];
    for (final song in library) {
      final lastDays = song.lastPlayed == null
          ? null
          : today.difference(song.lastPlayed!).inDays;
      var s = scoreSong(
        song: song,
        profile: profile,
        isFavorite: favoriteIds.contains(song.id),
        rating: ratings[song.id],
        lastPlayedDaysAgo: lastDays,
        playCount: song.playCount,
        currentHour: currentHour,
        discoveryBias: discoveryBias,
      );
      if (s <= 0) continue;
      // Deterministic daily exploration jitter — same all day, fresh tomorrow.
      s += _jitter(song.id, daySeed) * 0.06;
      scored.add(ScoredSong(song: song, score: s, reason: _reason(song, profile)));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Diversify: cap how many of any one artist reach the final list.
    final perArtist = <String, int>{};
    final out = <ScoredSong>[];
    for (final cand in scored) {
      final a = cand.song.artist;
      final c = perArtist[a] ?? 0;
      if (c >= maxPerArtist) continue;
      perArtist[a] = c + 1;
      out.add(cand);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Explains the top facet driving a pick, e.g. "Because you love Radiohead".
  static String _reason(Song song, TasteProfile profile) {
    final artistAff = profile.artistAffinity[song.artist] ?? 0;
    final genreAff =
        song.genre == null ? 0.0 : (profile.genreAffinity[song.genre!] ?? 0);
    if (artistAff >= 0.5 && artistAff >= genreAff) {
      return 'Because you listen to ${song.artist}';
    }
    if (genreAff >= 0.4 && song.genre != null) {
      return 'More ${song.genre}';
    }
    if (song.playCount == 0) return 'Something new for you';
    return 'Picked for you';
  }

  /// Stable per-(song, day) pseudo-random value in [0, 1) via FNV-1a.
  static double _jitter(String songId, int daySeed) {
    var hash = 0x811c9dc5 ^ daySeed;
    for (final c in songId.codeUnits) {
      hash = (hash ^ c) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash & 0xFFFF) / 0x10000;
  }
}

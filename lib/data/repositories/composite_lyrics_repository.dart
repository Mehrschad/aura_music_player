import 'dart:async';

import '../../domain/models/lyrics.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../local/lyrics_cache/sidecar_lrc_repository.dart';

/// The outcome of a full lookup: the lyrics (or null) plus whether any source
/// failed *transiently* (error / timeout) along the way. Callers that persist
/// negative results (the offline prefetcher's "miss" markers) must not treat
/// an errored lookup as a confirmed miss — that poisons the cache for songs
/// that merely hit a flaky network moment.
typedef LyricsLookup = ({Lyrics? lyrics, bool hadErrors});

/// The resolver chain that makes lyric lookup fast and high-hit-rate.
///
/// Order of operations:
///   1. **Sidecar** (`Song.lrc` next to the file) — instant, offline, and
///      authoritative (the user put it there). A *synced* sidecar short-circuits
///      everything and returns immediately.
///   2. **Primary tier** ([_network], e.g. LRCLIB + NetEase + QQ) — raced in
///      parallel with a per-source [timeout]. The race **early-exits on the
///      first synced result** — one fast source answering means the user sees
///      lyrics in well under a second instead of waiting for the slowest
///      racer. If nothing synced arrives, the richest surviving result wins
///      (word-level › translated › plain). An empty round caused by errors or
///      timeouts (a transient miss, not a genuine "no match") is retried up to
///      [maxAttempts] times.
///   3. **Fallback tier** ([_fallback], e.g. lyrics.ovh) — tried only when the
///      primary tier finds nothing, so a plain-text source can still rescue
///      the track.
///   4. A plain sidecar (no timings) is used only if every network tier is dry.
///
/// Caching and the user-override layer live above this in the provider, so this
/// repository stays a pure "best available lyrics for a song, right now" source.
class CompositeLyricsRepository implements LyricsRepository {
  CompositeLyricsRepository({
    required List<LyricsRepository> network,
    List<LyricsRepository> fallback = const [],
    SidecarLrcRepository sidecar = const SidecarLrcRepository(),
    this.timeout = const Duration(seconds: 10),
    this.maxAttempts = 2,
  })  : _network = network,
        _fallback = fallback,
        _sidecar = sidecar;

  final SidecarLrcRepository _sidecar;
  final List<LyricsRepository> _network;
  final List<LyricsRepository> _fallback;

  /// Per-source network deadline. A slow provider can't hold up the others.
  final Duration timeout;

  /// How many times to re-run the primary tier when it fails *transiently*
  /// (error/timeout) rather than returning a clean "no match".
  final int maxAttempts;

  @override
  Future<Lyrics?> lyricsFor(Song song) async =>
      (await lookupWithStatus(song)).lyrics;

  /// Full lookup with transient-failure visibility — see [LyricsLookup].
  Future<LyricsLookup> lookupWithStatus(Song song) async {
    // 1. Sidecar — fastest and offline. A synced sidecar wins outright.
    Lyrics? plainFallback;
    final side = await _sidecar.lyricsFor(song);
    if (side != null && !side.isEmpty) {
      if (side.synced) return (lyrics: side, hadErrors: false);
      plainFallback = side;
    }

    var hadErrors = false;

    // 2. Primary tier, with automatic retry on transient failures. A clean
    //    miss (every source answered "no match") won't improve on a repeat,
    //    so we only retry when at least one source errored or timed out.
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final (best, anyError) = await _race(_network, song);
      if (best != null) return (lyrics: best, hadErrors: false);
      hadErrors = hadErrors || anyError;
      if (!anyError) break;
    }

    // 3. Fallback tier — one pass, only reached when the primary is dry.
    if (_fallback.isNotEmpty) {
      final (fb, fbError) = await _race(_fallback, song);
      if (fb != null) return (lyrics: fb, hadErrors: false);
      hadErrors = hadErrors || fbError;
    }

    // 4. Plain sidecar as the final safety net.
    if (plainFallback != null) {
      return (lyrics: plainFallback, hadErrors: false);
    }
    return (lyrics: null, hadErrors: hadErrors);
  }

  /// Races [sources] in parallel. Completes with the **first synced result**
  /// as soon as one lands (latency = fastest hit, not slowest source); if no
  /// synced result arrives, completes when all sources finish with the richest
  /// surviving result. Also reports whether any source failed transiently.
  Future<(Lyrics?, bool)> _race(
      List<LyricsRepository> sources, Song song) {
    if (sources.isEmpty) return Future.value((null, false));
    final completer = Completer<(Lyrics?, bool)>();
    var pending = sources.length;
    var anyError = false;
    Lyrics? best;
    var bestRank = -1;

    for (final r in sources) {
      r
          .lyricsFor(song)
          .timeout(timeout)
          .then<void>((l) {
            if (l == null || l.isEmpty) return;
            final rank = _rank(l);
            if (rank > bestRank) {
              bestRank = rank;
              best = l;
            }
            // Early exit: a synced result is what the player needs — ship it
            // now rather than waiting out slower racers for marginal extras.
            if (l.synced && !completer.isCompleted) {
              completer.complete((l, anyError));
            }
          })
          .catchError((_) {
            anyError = true;
          })
          .whenComplete(() {
            pending--;
            if (pending == 0 && !completer.isCompleted) {
              completer.complete((best, anyError));
            }
          });
    }
    return completer.future;
  }

  static int _rank(Lyrics l) {
    var r = 0;
    if (l.synced) r += 4;
    if (l.hasWordTimings) r += 2;
    if (l.hasTranslations) r += 1;
    return r;
  }
}

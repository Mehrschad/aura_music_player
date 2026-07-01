import '../../domain/models/lyrics.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../local/lyrics_cache/sidecar_lrc_repository.dart';

/// The resolver chain that makes lyric lookup both fast and high-hit-rate.
///
/// Order of operations:
///   1. **Sidecar** (`Song.lrc` next to the file) — instant, offline, and
///      authoritative (the user put it there). A *synced* sidecar short-circuits
///      everything and returns immediately.
///   2. **Primary tier** ([_network], e.g. LRCLIB + NetEase) — the quality
///      sources are raced *in parallel* with a per-source [timeout]; whichever
///      come back are ranked (synced › word-level › translated) and the best is
///      returned. Parallelism means latency is the slowest single source, not
///      their sum. If the tier comes back empty *because a source errored or
///      timed out* (a transient miss, not a genuine "no match"), it's retried up
///      to [maxAttempts] times — one flaky request no longer means "no lyrics".
///   3. **Fallback tier** ([_fallback], e.g. lyrics.ovh) — tried only when the
///      primary tier finds nothing, so a plain-text source can still rescue the
///      track. Raced the same way.
///   4. A plain sidecar (no timings) is used only if every network tier is dry.
///
/// Caching and the user-override layer live above this in the provider, so this
/// repository stays a pure "best available lyrics for a song, right now" source.
class CompositeLyricsRepository implements LyricsRepository {
  CompositeLyricsRepository({
    required List<LyricsRepository> network,
    List<LyricsRepository> fallback = const [],
    SidecarLrcRepository sidecar = const SidecarLrcRepository(),
    this.timeout = const Duration(seconds: 6),
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
  Future<Lyrics?> lyricsFor(Song song) async {
    // 1. Sidecar — fastest and offline. A synced sidecar wins outright.
    Lyrics? plainFallback;
    final side = await _sidecar.lyricsFor(song);
    if (side != null && !side.isEmpty) {
      if (side.synced) return side;
      plainFallback = side;
    }

    // 2. Primary tier, with automatic retry on transient failures. A clean miss
    //    (every source answered "no match") won't improve on a repeat, so we
    //    only retry when at least one source errored or timed out.
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final (best, anyError) = await _race(_network, song);
      if (best != null) return best;
      if (!anyError) break;
    }

    // 3. Fallback tier — one pass, only reached when the primary is dry.
    if (_fallback.isNotEmpty) {
      final (fb, _) = await _race(_fallback, song);
      if (fb != null) return fb;
    }

    // 4. Plain sidecar as the final safety net.
    return plainFallback;
  }

  /// Races [sources] in parallel and returns the richest result, plus whether
  /// any source failed transiently (so the caller can decide to retry).
  Future<(Lyrics?, bool)> _race(
      List<LyricsRepository> sources, Song song) async {
    if (sources.isEmpty) return (null, false);
    var anyError = false;
    final results = await Future.wait(
      sources.map(
        (r) => r.lyricsFor(song).timeout(timeout, onTimeout: () {
          anyError = true;
          return null;
        }).catchError((_) {
          anyError = true;
          return null;
        }),
      ),
    );

    Lyrics? best;
    var bestRank = -1;
    for (final l in results) {
      if (l == null || l.isEmpty) continue;
      final rank = _rank(l);
      if (rank > bestRank) {
        bestRank = rank;
        best = l;
      }
    }
    return (best, anyError);
  }

  static int _rank(Lyrics l) {
    var r = 0;
    if (l.synced) r += 4;
    if (l.hasWordTimings) r += 2;
    if (l.hasTranslations) r += 1;
    return r;
  }
}

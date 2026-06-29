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
///   2. **Network race** — every remote source ([_network], e.g. LRCLIB +
///      NetEase) is queried *in parallel* with a per-source [timeout]; whichever
///      come back are ranked by quality (synced › word-level › translated) and
///      the best is returned. Parallelism means total latency is the slowest
///      single source, not their sum.
///   3. A plain sidecar (no timings) is used only if the network yields nothing.
///
/// Caching and the user-override layer live above this in the provider, so this
/// repository stays a pure "best available lyrics for a song, right now" source.
class CompositeLyricsRepository implements LyricsRepository {
  CompositeLyricsRepository({
    required List<LyricsRepository> network,
    SidecarLrcRepository sidecar = const SidecarLrcRepository(),
    this.timeout = const Duration(seconds: 6),
  })  : _network = network,
        _sidecar = sidecar;

  final SidecarLrcRepository _sidecar;
  final List<LyricsRepository> _network;

  /// Per-source network deadline. A slow provider can't hold up the others.
  final Duration timeout;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    // 1. Sidecar — fastest and offline. A synced sidecar wins outright.
    Lyrics? plainFallback;
    final side = await _sidecar.lyricsFor(song);
    if (side != null && !side.isEmpty) {
      if (side.synced) return side;
      plainFallback = side;
    }

    // 2. Race all network sources in parallel; each is isolated so one failure
    //    or timeout can't sink the rest.
    final results = await Future.wait(
      _network.map(
        (r) => r
            .lyricsFor(song)
            .timeout(timeout, onTimeout: () => null)
            .catchError((_) => null),
      ),
    );

    // 3. Rank the survivors and take the richest. Synced beats plain; among
    //    synced, word-level karaoke beats translated beats bare.
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

    return best ?? plainFallback;
  }

  static int _rank(Lyrics l) {
    var r = 0;
    if (l.synced) r += 4;
    if (l.hasWordTimings) r += 2;
    if (l.hasTranslations) r += 1;
    return r;
  }
}

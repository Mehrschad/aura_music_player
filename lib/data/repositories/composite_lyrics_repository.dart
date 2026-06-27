import '../../domain/models/lyrics.dart';
import '../../domain/models/song.dart';
import '../../domain/repositories/lyrics_repository.dart';
import '../local/lyrics_cache/embedded_lyrics_repository.dart';
import '../local/lyrics_cache/sidecar_lrc_repository.dart';

/// The resolver chain that makes lyric lookup both fast and high-hit-rate.
///
/// Order of operations:
///   1. **Local, offline sources** in order — a sidecar `Song.lrc` next to the
///      file (user-authored, authoritative) then **embedded** in-file lyrics
///      (ID3 USLT / FLAC Vorbis comments). Any *synced* local hit short-circuits
///      everything and returns immediately — zero network, instant.
///   2. **Network race** — every remote source ([_network], e.g. LRCLIB +
///      NetEase) is queried *in parallel* with a per-source [timeout]; whichever
///      come back are ranked by quality (synced › word-level › translated) and
///      the best is returned. Parallelism means total latency is the slowest
///      single source, not their sum.
///   3. A plain (un-timed) local result is used only if the network yields
///      nothing.
///
/// Caching and the user-override layer live above this in the provider, so this
/// repository stays a pure "best available lyrics for a song, right now" source.
class CompositeLyricsRepository implements LyricsRepository {
  CompositeLyricsRepository({
    required List<LyricsRepository> network,
    List<LyricsRepository>? local,
    this.timeout = const Duration(seconds: 6),
  })  : _network = network,
        _local = local ??
            const [
              SidecarLrcRepository(),
              EmbeddedLyricsRepository(),
            ];

  /// Offline sources tried first, in order; a synced hit short-circuits.
  final List<LyricsRepository> _local;
  final List<LyricsRepository> _network;

  /// Per-source network deadline. A slow provider can't hold up the others.
  final Duration timeout;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    // 1. Local offline sources — fastest. A synced local hit wins outright; a
    //    plain one is held as a fallback in case the network finds nothing.
    Lyrics? plainFallback;
    for (final source in _local) {
      final local = await source.lyricsFor(song);
      if (local != null && !local.isEmpty) {
        if (local.synced) return local;
        plainFallback ??= local;
      }
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

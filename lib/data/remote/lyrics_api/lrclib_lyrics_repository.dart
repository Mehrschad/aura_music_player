import 'package:dio/dio.dart';

import '../../../core/utils/background.dart';
import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/lyrics/lyrics_match.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';

/// Fetches lyrics from LRCLIB (https://lrclib.net) — free, no API key, synced
/// LRC preferred. Runs a bounded lookup ladder, stopping at the first hit:
///
///   1. `/api/get` exact — raw artist + title + album + duration (LRCLIB
///      enforces a ±2s duration match server-side).
///   2. `/api/get` cleaned, no album — mis-tagged albums are the most common
///      reason an otherwise-perfect exact match misses.
///   3. `/api/search` by artist+title fields, walked through progressively
///      looser [queryVariants] (cleaned → bracket-stripped → dash-tail cut →
///      lead artist), each result set scored by [matchScore].
///   4. `/api/search` free-text `q=` — LRCLIB's own tokenizer sometimes finds
///      what the fielded search misses.
///
/// Every step is individually error-isolated: a failed request falls through
/// to the next rung rather than sinking the whole lookup.
class LrcLibLyricsRepository implements LyricsRepository {
  LrcLibLyricsRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://lrclib.net',
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
              headers: const {'User-Agent': 'Aura (https://github.com/aura)'},
            ));

  final Dio _dio;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    // 1. Exact match with the raw tags.
    var hit = await _get({
      'artist_name': song.artist,
      'track_name': song.title,
      'album_name': song.album,
      'duration': song.duration.inSeconds,
    });
    if (hit != null) return hit;

    // 2. Exact match, cleaned tags, no album.
    hit = await _get({
      'artist_name': cleanForQuery(song.artist),
      'track_name': cleanForQuery(song.title),
      'duration': song.duration.inSeconds,
    });
    if (hit != null) return hit;

    // 3. Fielded fuzzy search over the variant ladder (capped to keep the
    //    total lookup bounded — the variants are deduped, loosest last).
    for (final (t, a) in queryVariants(song.title, song.artist).take(3)) {
      hit = await _searchBest(song, {
        'track_name': t,
        if (a.isNotEmpty) 'artist_name': a,
      });
      if (hit != null) return hit;
    }

    // 4. Free-text search as the last rung.
    final q = '${cleanForQuery(song.title)} ${cleanForQuery(song.artist)}'
        .trim();
    if (q.isEmpty) return null;
    return _searchBest(song, {'q': q});
  }

  /// One `/api/get` attempt; null on any miss or error.
  Future<Lyrics?> _get(Map<String, dynamic> params) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/get',
        queryParameters: params,
      );
      return _fromPayload(res.data);
    } on DioException {
      return null;
    }
  }

  /// One `/api/search` attempt: scores every record (normalized title/artist
  /// similarity blended with duration proximity), preferring synced among
  /// near-ties, and returns the best above the accept threshold.
  Future<Lyrics?> _searchBest(Song song, Map<String, dynamic> params) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/search',
        queryParameters: params,
      );
      final results = res.data ?? const [];
      Map<String, dynamic>? best;
      var bestScore = kMatchAcceptThreshold;
      for (final item in results.cast<Map<String, dynamic>>()) {
        var score = matchScore(
          queryTitle: song.title,
          queryArtist: song.artist,
          queryDurationSec: song.duration.inSeconds,
          candidateTitle: item['trackName'] as String? ?? '',
          candidateArtist: item['artistName'] as String? ?? '',
          candidateDurationSec: (item['duration'] as num?)?.round() ?? 0,
        );
        // Nudge synced records ahead of equally-scored plain ones.
        final hasSynced =
            (item['syncedLyrics'] as String?)?.isNotEmpty ?? false;
        if (hasSynced) score += 0.02;
        if (score >= bestScore) {
          bestScore = score;
          best = item;
        }
      }
      return _fromPayload(best);
    } on DioException {
      return null;
    }
  }

  Future<Lyrics?> _fromPayload(Map<String, dynamic>? data) async {
    if (data == null) return null;
    final synced = data['syncedLyrics'] as String?;
    if (synced != null && synced.trim().isNotEmpty) {
      // Parse off the main thread — synced LRC can be large.
      return runOffMainThread(parseLrc, synced);
    }
    final plain = data['plainLyrics'] as String?;
    if (plain != null && plain.trim().isNotEmpty) return parsePlainLyrics(plain);
    return null;
  }
}

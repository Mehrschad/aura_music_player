import 'package:dio/dio.dart';

import '../../../core/utils/background.dart';
import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/lyrics/lyrics_match.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';

/// Fetches lyrics from LRCLIB (https://lrclib.net) — free, no API key, synced
/// LRC preferred. Matches by artist + title + album + duration.
///
/// This is real and works on device/desktop (dio is pure-Dart). It isn't the
/// active source in the running sample app (that's [SampleLyricsRepository]);
/// on device, wire a composite that checks the Isar cache first, then embedded
/// tags, then this, caching the result permanently:
///
/// ```dart
/// final cached = await cache.read(song);            // Isar
/// if (cached != null) return cached;
/// final embedded = await tagReader.lyrics(song);    // USLT / Vorbis LYRICS
/// final result = embedded ?? await lrcLib.lyricsFor(song);
/// if (result != null) await cache.write(song, result);
/// return result;
/// ```
///
/// Genius (key-based plain-text fallback) layers in the same way behind this.
class LrcLibLyricsRepository implements LyricsRepository {
  LrcLibLyricsRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://lrclib.net',
              headers: const {'User-Agent': 'Aura (https://github.com/aura)'},
            ));

  final Dio _dio;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    // Exact match first (LRCLIB enforces a ±2s duration match server-side).
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/get',
        queryParameters: {
          'artist_name': song.artist,
          'track_name': song.title,
          'album_name': song.album,
          'duration': song.duration.inSeconds,
        },
      );
      final lyrics = await _fromPayload(res.data);
      if (lyrics != null) return lyrics;
    } on DioException {
      // Fall through to fuzzy search on any miss/error.
    }

    // Fuzzy fallback: search by title+artist and pick the best-scoring record
    // (normalized title/artist similarity blended with duration proximity),
    // preferring synced over plain among near-ties.
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/search',
        queryParameters: {
          'artist_name': song.artist,
          'track_name': song.title,
        },
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
        final hasSynced = (item['syncedLyrics'] as String?)?.isNotEmpty ?? false;
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

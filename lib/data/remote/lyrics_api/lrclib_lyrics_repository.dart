import 'package:dio/dio.dart';

import '../../../core/utils/background.dart';
import '../../../domain/lyrics/lrc_parser.dart';
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

  /// Duration fuzz when matching (±5 seconds), per the spec.
  static const int _durationToleranceSeconds = 5;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    // Exact match first.
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

    // Fuzzy fallback: search and pick the closest duration within tolerance.
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
      var bestDelta = _durationToleranceSeconds + 1;
      for (final item in results.cast<Map<String, dynamic>>()) {
        final dur = (item['duration'] as num?)?.round() ?? -1000;
        final delta = (dur - song.duration.inSeconds).abs();
        if (delta <= _durationToleranceSeconds && delta < bestDelta) {
          best = item;
          bestDelta = delta;
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

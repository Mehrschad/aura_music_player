import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/utils/background.dart';
import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/lyrics/lyrics_match.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';

/// Fetches lyrics from NetEase Cloud Music via its public *legacy* endpoints,
/// which need no account, token, or API key — only a `Referer` header (and a
/// throwaway `appver` cookie).
///
/// **Important**: these endpoints answer with `Content-Type: text/plain`, so
/// Dio's automatic JSON decoding never kicks in. The responses are fetched as
/// raw strings and decoded manually — asking Dio for a `Map` silently broke
/// every call (the cast failure escaped the DioException catch), which is why
/// this source used to contribute nothing.
///
/// NetEase returns standard synced LRC plus, for many tracks, a *translated*
/// LRC (`tlyric`) — folded into [LyricsLine.translation] to power the
/// dual-language view for free. All failures degrade to `null` — this source
/// is one racer in the composite, never a hard dependency.
class NeteaseLyricsRepository implements LyricsRepository {
  NeteaseLyricsRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://music.163.com',
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              // The API lies about its content type (text/plain) — take the
              // body as a string and decode it ourselves.
              responseType: ResponseType.plain,
              headers: const {
                'Referer': 'https://music.163.com',
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Cookie': 'appver=1.5.0.75771;',
              },
            ));

  final Dio _dio;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    final hit = await _findSongId(song);
    if (hit == null) return null;
    // Carry the search's blended match score through as confidence so the
    // resolver can prefer a well-matched result over a merely synced one.
    return (await _fetchLyric(hit.id))?.withConfidence(hit.score);
  }

  /// Decodes a body that may be a raw JSON string (the usual case here, since
  /// the server labels JSON as text/plain) or an already-decoded map.
  static Map<String, dynamic>? _decodeBody(Object? body) {
    if (body is Map<String, dynamic>) return body;
    if (body is! String || body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Searches NetEase and returns the best-scoring song id above the accept
  /// threshold, or null when nothing matches confidently. Tries the combined
  /// "title artist" query first, then title alone — the artist tag is the
  /// field most often romanized/aliased differently on NetEase, so dropping
  /// it rescues many real matches (the score check still guards identity).
  Future<({int id, double score})?> _findSongId(Song song) async {
    final title = cleanForQuery(song.title);
    final artist = cleanForQuery(song.artist);
    final keywords = <String>{
      '$title $artist'.trim(),
      title,
    }..removeWhere((k) => k.isEmpty);
    for (final kw in keywords) {
      final hit = await _searchId(kw, song);
      if (hit != null) return hit;
    }
    return null;
  }

  Future<({int id, double score})?> _searchId(String keyword, Song song) async {
    try {
      final res = await _dio.get<String>(
        '/api/search/get/',
        queryParameters: {
          's': keyword,
          'type': 1,
          'offset': 0,
          'total': true,
          'limit': 10,
        },
      );
      final data = _decodeBody(res.data);
      final songs = (data?['result']
              as Map<String, dynamic>?)?['songs'] as List<dynamic>?;
      if (songs == null || songs.isEmpty) return null;

      int? bestId;
      var bestScore = kMatchAcceptThreshold;
      for (final raw in songs.cast<Map<String, dynamic>>()) {
        final artists = (raw['artists'] as List<dynamic>?)
                ?.map((a) => (a as Map<String, dynamic>)['name'] as String? ?? '')
                .where((s) => s.isNotEmpty)
                .join(' ') ??
            '';
        final durMs = (raw['duration'] as num?)?.toInt() ?? 0;
        final score = matchScore(
          queryTitle: song.title,
          queryArtist: song.artist,
          queryDurationSec: song.duration.inSeconds,
          candidateTitle: raw['name'] as String? ?? '',
          candidateArtist: artists,
          candidateDurationSec: (durMs / 1000).round(),
        );
        if (score >= bestScore) {
          bestScore = score;
          bestId = (raw['id'] as num?)?.toInt();
        }
      }
      return bestId == null ? null : (id: bestId, score: bestScore);
    } on DioException {
      return null;
    }
  }

  Future<Lyrics?> _fetchLyric(int id) async {
    try {
      final res = await _dio.get<String>(
        '/api/song/lyric',
        queryParameters: {'os': 'pc', 'id': id, 'lv': -1, 'kv': -1, 'tv': -1},
      );
      final data = _decodeBody(res.data);
      if (data == null) return null;
      final lrc = (data['lrc'] as Map<String, dynamic>?)?['lyric'] as String?;
      if (lrc == null || lrc.trim().isEmpty) return null;

      // Parse off the main isolate — synced LRC can be large.
      final base = await runOffMainThread(parseLyrics, lrc);
      if (base.isEmpty) return null;

      // Fold in the translated LRC (tlyric) when present, by matching line
      // start times — this lights up the dual-language view at no extra cost.
      final tlrc =
          (data['tlyric'] as Map<String, dynamic>?)?['lyric'] as String?;
      if (base.synced && tlrc != null && tlrc.trim().isNotEmpty) {
        return mergeTranslations(
            base, await runOffMainThread(parseLyrics, tlrc));
      }
      return base;
    } on DioException {
      return null;
    }
  }
}

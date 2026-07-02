import 'package:dio/dio.dart';

import '../../../core/utils/background.dart';
import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/lyrics/lyrics_match.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';

/// Fetches lyrics from NetEase Cloud Music via its public *legacy* endpoints,
/// which need no account, token, or API key — only a `Referer` header (and a
/// throwaway `appver` cookie). Verified working by long-running open-source
/// plugins (e.g. MusicBee-NeteaseLyrics).
///
/// NetEase returns standard synced LRC plus, for many tracks, a *translated*
/// LRC (`tlyric`) — which we fold into [LyricsLine.translation] to power the
/// dual-language view for free. It has an enormous catalogue (especially Asian
/// and a great deal of Western pop), making it a strong complement to LRCLIB.
///
/// All failures degrade to `null` — this source is one racer in the composite,
/// never a hard dependency.
class NeteaseLyricsRepository implements LyricsRepository {
  NeteaseLyricsRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://music.163.com',
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
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
    final id = await _findSongId(song);
    if (id == null) return null;
    return _fetchLyric(id);
  }

  /// Searches NetEase and returns the best-scoring song id above the accept
  /// threshold, or null when nothing matches confidently. Tries the combined
  /// "title artist" query first, then title alone — the artist tag is the
  /// field most often romanized/aliased differently on NetEase, so dropping
  /// it rescues many real matches (the score check still guards identity).
  Future<int?> _findSongId(Song song) async {
    final title = cleanForQuery(song.title);
    final artist = cleanForQuery(song.artist);
    final keywords = <String>{
      '$title $artist'.trim(),
      title,
    }..removeWhere((k) => k.isEmpty);
    for (final kw in keywords) {
      final id = await _searchId(kw, song);
      if (id != null) return id;
    }
    return null;
  }

  Future<int?> _searchId(String keyword, Song song) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/search/get/',
        queryParameters: {
          's': keyword,
          'type': 1,
          'offset': 0,
          'total': true,
          'limit': 10,
        },
      );
      final songs = (res.data?['result']
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
      return bestId;
    } on DioException {
      return null;
    }
  }

  Future<Lyrics?> _fetchLyric(int id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/song/lyric',
        queryParameters: {'os': 'pc', 'id': id, 'lv': -1, 'kv': -1, 'tv': -1},
      );
      final data = res.data;
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

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/utils/background.dart';
import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/lyrics/lyrics_match.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';

/// Fetches lyrics from QQ Music via its public web endpoints (c.y.qq.com) —
/// HTTPS, no account or API key, only a `Referer` header. Returns standard
/// synced LRC and, for many tracks, a separate translated LRC (`trans`) that
/// folds into the dual-language view. Its catalogue overlaps neither LRCLIB
/// nor NetEase perfectly, so as a third racer it lifts the overall hit rate.
///
/// All failures degrade to `null` — one racer in the composite, never a hard
/// dependency.
class QQLyricsRepository implements LyricsRepository {
  QQLyricsRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              responseType: ResponseType.plain,
              headers: const {
                'Referer': 'https://y.qq.com/portal/player.html',
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            ));

  final Dio _dio;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    final mid = await _findSongMid(song);
    if (mid == null) return null;
    return _fetchLyric(mid);
  }

  /// Decodes a response body that may arrive as a raw JSON string or wrapped
  /// in a JSONP callback (`name({...})`), which these legacy endpoints emit
  /// depending on parameters.
  static Map<String, dynamic>? _decodeBody(Object? body) {
    if (body is Map<String, dynamic>) return body;
    if (body is! String) return null;
    var s = body.trim();
    final open = s.indexOf('(');
    if (open > 0 && s.endsWith(')') && !s.startsWith('{')) {
      s = s.substring(open + 1, s.length - 1);
    }
    try {
      final decoded = jsonDecode(s);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Searches QQ and returns the best-scoring song mid above the accept
  /// threshold. Tries "title artist", then title alone.
  Future<String?> _findSongMid(Song song) async {
    final title = cleanForQuery(song.title);
    final artist = cleanForQuery(song.artist);
    final keywords = <String>{'$title $artist'.trim(), title}
      ..removeWhere((k) => k.isEmpty);
    for (final kw in keywords) {
      final mid = await _searchMid(kw, song);
      if (mid != null) return mid;
    }
    return null;
  }

  /// Searches via the `smartbox_new.fcg` suggest endpoint — the older
  /// `client_search_cp` endpoint now returns HTTP 500 without login cookies,
  /// while smartbox still answers anonymously. It carries no track duration,
  /// so duration scores neutral and title/artist similarity decides.
  Future<String?> _searchMid(String keyword, Song song) async {
    try {
      final res = await _dio.get<String>(
        'https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg',
        queryParameters: {
          'is_xml': 0,
          'format': 'json',
          'key': keyword,
        },
      );
      final data = _decodeBody(res.data);
      final list = ((data?['data'] as Map<String, dynamic>?)?['song']
          as Map<String, dynamic>?)?['itemlist'] as List<dynamic>?;
      if (list == null || list.isEmpty) return null;

      String? bestMid;
      var bestScore = kMatchAcceptThreshold;
      for (final raw in list.cast<Map<String, dynamic>>()) {
        // Multi-artist entries come slash-separated ("A/B").
        final singer =
            (raw['singer'] as String? ?? '').replaceAll('/', ' ');
        final score = matchScore(
          queryTitle: song.title,
          queryArtist: song.artist,
          queryDurationSec: song.duration.inSeconds,
          candidateTitle: raw['name'] as String? ?? '',
          candidateArtist: singer,
          candidateDurationSec: 0, // smartbox has no duration → neutral
        );
        if (score >= bestScore) {
          bestScore = score;
          bestMid = raw['mid'] as String?;
        }
      }
      return bestMid;
    } on DioException {
      return null;
    }
  }

  Future<Lyrics?> _fetchLyric(String mid) async {
    try {
      final res = await _dio.get<String>(
        'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
        queryParameters: {
          'songmid': mid,
          'format': 'json',
          'g_tk': 5381,
          'loginUin': 0,
          'hostUin': 0,
          'inCharset': 'utf8',
          'outCharset': 'utf-8',
          'notice': 0,
          'platform': 'yqq',
        },
      );
      final data = _decodeBody(res.data);
      final lrc = _decodeBase64(data?['lyric'] as String?);
      if (lrc == null || lrc.trim().isEmpty) return null;

      final base = await runOffMainThread(parseLyrics, lrc);
      if (base.isEmpty) return null;

      final trans = _decodeBase64(data?['trans'] as String?);
      if (base.synced && trans != null && trans.trim().isNotEmpty) {
        return mergeTranslations(
            base, await runOffMainThread(parseLyrics, trans));
      }
      return base;
    } on DioException {
      return null;
    }
  }

  /// QQ ships lyric bodies base64-encoded; tolerate whitespace and bad data.
  static String? _decodeBase64(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return utf8.decode(
        base64Decode(raw.replaceAll(RegExp(r'\s'), '')),
        allowMalformed: true,
      );
    } on FormatException {
      return null;
    }
  }
}

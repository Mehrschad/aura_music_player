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
  /// threshold, or null when nothing matches confidently.
  Future<int?> _findSongId(Song song) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/search/get/',
        queryParameters: {
          's': '${song.title} ${song.artist}',
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
        // `yv` requests the word-by-word (YRC) lyric alongside the line-level
        // LRC, so one round-trip can yield true karaoke when it exists.
        queryParameters: {
          'os': 'pc',
          'id': id,
          'lv': -1,
          'kv': -1,
          'tv': -1,
          'yv': -1,
        },
      );
      final data = res.data;
      if (data == null) return null;

      // 1. Word-level (yrc) — the richest, drives per-word karaoke fill.
      final yrc = (data['yrc'] as Map<String, dynamic>?)?['lyric'] as String?;
      if (yrc != null && yrc.trim().isNotEmpty) {
        final word = await runOffMainThread(parseYrc, yrc);
        if (!word.isEmpty && word.hasWordTimings) {
          final yt =
              (data['ytlrc'] as Map<String, dynamic>?)?['lyric'] as String? ??
                  (data['tlyric'] as Map<String, dynamic>?)?['lyric'] as String?;
          if (yt != null && yt.trim().isNotEmpty) {
            return _withTranslations(word, await runOffMainThread(parseLyrics, yt));
          }
          return word;
        }
      }

      // 2. Standard line-level synced LRC (parse off the main isolate).
      final lrc = (data['lrc'] as Map<String, dynamic>?)?['lyric'] as String?;
      if (lrc == null || lrc.trim().isEmpty) return null;
      final base = await runOffMainThread(parseLyrics, lrc);
      if (base.isEmpty) return null;

      // Fold in the translated LRC (tlyric) when present, by matching line
      // start times — this lights up the dual-language view at no extra cost.
      final tlrc =
          (data['tlyric'] as Map<String, dynamic>?)?['lyric'] as String?;
      if (base.synced && tlrc != null && tlrc.trim().isNotEmpty) {
        return _withTranslations(base, await runOffMainThread(parseLyrics, tlrc));
      }
      return base;
    } on DioException {
      return null;
    }
  }

  /// Attaches [translated] lines onto [base] by exact start-time match.
  static Lyrics _withTranslations(Lyrics base, Lyrics translated) {
    if (!translated.synced || translated.isEmpty) return base;
    final byMs = <int, String>{
      for (final l in translated.lines)
        if (l.text.trim().isNotEmpty) l.time.inMilliseconds: l.text,
    };
    final merged = [
      for (final l in base.lines)
        LyricsLine(
          time: l.time,
          text: l.text,
          words: l.words,
          translation: byMs[l.time.inMilliseconds] ?? l.translation,
        ),
    ];
    return Lyrics(lines: merged, synced: base.synced, offset: base.offset);
  }
}

/// Line head of a YRC line: `[lineStartMs,lineDurationMs]`.
final RegExp _yrcLineHead = RegExp(r'^\[(\d+),(\d+)\]');

/// A YRC word timing tag: `(wordStartMs,wordDurationMs,0)`.
final RegExp _yrcWordTag = RegExp(r'\((\d+),(\d+),\d+\)');

/// Parses NetEase **YRC** (word-by-word) lyrics into timed lines with per-word
/// timings — the source for true karaoke fill. Each line is
/// `[start,dur](wStart,wDur,0)word(wStart,wDur,0)word…`; non-`[` lines (JSON
/// metadata) are skipped. Top-level + isolate-safe for `runOffMainThread`.
Lyrics parseYrc(String raw) {
  final out = <LyricsLine>[];
  for (final rawLine in raw.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || !line.startsWith('[')) continue;
    final head = _yrcLineHead.firstMatch(line);
    if (head == null) continue;
    final lineStart = int.parse(head.group(1)!);
    final body = line.substring(head.end);

    final tags = _yrcWordTag.allMatches(body).toList();
    if (tags.isEmpty) continue;
    final words = <LyricWord>[];
    final buffer = StringBuffer();
    for (var i = 0; i < tags.length; i++) {
      final m = tags[i];
      final wStart = int.parse(m.group(1)!);
      final textEnd = i + 1 < tags.length ? tags[i + 1].start : body.length;
      final text = body.substring(m.end, textEnd);
      if (text.isEmpty) continue;
      words.add(LyricWord(start: Duration(milliseconds: wStart), text: text));
      buffer.write(text);
    }
    final full = buffer.toString().trim();
    if (full.isEmpty) continue;
    out.add(LyricsLine(
      time: Duration(milliseconds: lineStart),
      text: full,
      words: words,
    ));
  }
  out.sort((a, b) => a.time.compareTo(b.time));
  return Lyrics(lines: out, synced: out.isNotEmpty);
}

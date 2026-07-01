import 'package:dio/dio.dart';

import '../../../domain/lyrics/lrc_parser.dart';
import '../../../domain/lyrics/lyrics_match.dart';
import '../../../domain/models/lyrics.dart';
import '../../../domain/models/song.dart';
import '../../../domain/repositories/lyrics_repository.dart';

/// Last-resort lyrics source: lyrics.ovh (https://api.lyrics.ovh) — free, no key,
/// plain-text only (no timing). Its coverage differs from LRCLIB/NetEase, so as
/// a third tier it rescues tracks the synced providers miss. A plain result is
/// still worth showing — the user gets the words even without the karaoke scroll.
///
/// All failures degrade to null: it's a fallback racer, never a hard dependency.
class LyricsOvhLyricsRepository implements LyricsRepository {
  LyricsOvhLyricsRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.lyrics.ovh',
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            ));

  final Dio _dio;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    // The endpoint is path-based (/v1/{artist}/{title}) and fairly literal, so
    // feed it cleaned artist/title — "(Remastered)" / "feat. X" tails otherwise
    // sink the match.
    final artist = cleanForQuery(song.artist);
    final title = cleanForQuery(song.title);
    if (artist.isEmpty || title.isEmpty) return null;

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
      );
      final raw = res.data?['lyrics'] as String?;
      if (raw == null || raw.trim().isEmpty) return null;
      // lyrics.ovh sometimes prefixes a "Paroles de la chanson … par …" header
      // and uses \r\n — parsePlainLyrics tolerates both; it's never timed.
      final lyrics = parsePlainLyrics(raw);
      return lyrics.isEmpty ? null : lyrics;
    } on DioException {
      return null;
    }
  }
}

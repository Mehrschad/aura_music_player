import 'dart:convert';

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
              // Decode manually — immune to mislabelled content types.
              responseType: ResponseType.plain,
            ));

  final Dio _dio;

  /// Confidence ceiling for this source. The endpoint echoes no track metadata,
  /// so a result can never be verified the way LRCLIB/NetEase/QQ hits are — it
  /// is trusted enough to show when nothing else answered, but must never
  /// outrank a source that proved its match.
  static const double _exactQueryConfidence = 0.62;
  static const double _loosenedQueryConfidence = 0.5;

  @override
  Future<Lyrics?> lyricsFor(Song song) async {
    // The endpoint is path-based (/v1/{artist}/{title}) and matches fairly
    // literally, so walk the same loosening ladder the other sources use rather
    // than giving up after one shot: raw tags, then cleaned, then the
    // bracket/dash-stripped title, then the lead artist alone.
    final variants = queryVariants(song.title, song.artist)
        .where((v) => v.$1.isNotEmpty && v.$2.isNotEmpty)
        .take(4)
        .toList();

    for (var i = 0; i < variants.length; i++) {
      final (title, artist) = variants[i];
      final lyrics = await _fetch(artist, title);
      if (lyrics != null) {
        // Only the first rung used the track's own tags verbatim; the looser
        // rungs traded precision for a hit, so they're rated lower.
        return lyrics.withConfidence(
            i == 0 ? _exactQueryConfidence : _loosenedQueryConfidence);
      }
    }
    return null;
  }

  Future<Lyrics?> _fetch(String artist, String title) async {
    try {
      final res = await _dio.get<String>(
        '/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
      );
      final body = res.data;
      if (body == null || body.isEmpty) return null;
      final Object? decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        return null;
      }
      if (decoded is! Map<String, dynamic>) return null;
      final raw = decoded['lyrics'] as String?;
      if (raw == null || raw.trim().isEmpty) return null;
      // lyrics.ovh sometimes prefixes a "Paroles de la chanson … par …" header
      // and uses \r\n — parsePlainLyrics tolerates both; it's never timed.
      final lyrics = parsePlainLyrics(raw);
      if (lyrics.isEmpty || !_looksLikeLyrics(lyrics)) return null;
      return lyrics;
    } on DioException {
      return null;
    }
  }

  /// Rejects the junk this endpoint occasionally returns in place of a 404 —
  /// an error sentence, or a one-liner that is really a "not found" notice
  /// rather than a song.
  static bool _looksLikeLyrics(Lyrics lyrics) {
    if (lyrics.lines.length < 2) return false;
    final head = lyrics.lines.first.text.toLowerCase();
    const rejects = [
      'no lyrics found',
      'not found',
      'error',
      'instrumental',
    ];
    return !rejects.any((r) => head.contains(r));
  }
}

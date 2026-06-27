import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/lyrics.dart';

/// Persists fetched lyrics to SharedPreferences so they work offline.
/// Key format: `lyrics_v1_<songId>`.
///
/// Tracks that were looked up but had no lyrics get a "miss" marker
/// (`lyrics_miss_v1_<songId>` → epoch ms) so the background prefetcher
/// doesn't re-query the API for them on every launch. Misses expire after
/// [missTtl] in case lyrics get published later.
class SharedPrefsLyricsCache {
  static const String _prefix = 'lyrics_v1_';
  static const String _missPrefix = 'lyrics_miss_v1_';

  /// How long a "no lyrics found" result is trusted before retrying.
  static const Duration missTtl = Duration(days: 14);

  Future<Lyrics?> read(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$songId');
    if (raw == null) return null;
    try {
      return _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// True when lyrics for [songId] are already stored (cheaper than [read]).
  Future<bool> contains(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_prefix$songId');
  }

  Future<void> write(String songId, Lyrics lyrics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$songId', jsonEncode(_toJson(lyrics)));
    await prefs.remove('$_missPrefix$songId');
  }

  /// Records that a lookup for [songId] found nothing, so the prefetcher can
  /// skip it until [missTtl] elapses.
  Future<void> markMiss(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        '$_missPrefix$songId', DateTime.now().millisecondsSinceEpoch);
  }

  /// True when a recent (within [missTtl]) lookup already came back empty.
  Future<bool> hasFreshMiss(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('$_missPrefix$songId');
    if (ms == null) return false;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ms));
    return age < missTtl;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_prefix) || k.startsWith(_missPrefix))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  static Map<String, dynamic> _toJson(Lyrics lyrics) => {
        'synced': lyrics.synced,
        'offset': lyrics.offset.inMilliseconds,
        'lines': lyrics.lines
            .map((l) => {
                  'ms': l.time.inMilliseconds,
                  'text': l.text,
                  if (l.translation != null) 'tr': l.translation,
                  // Per-word timings (karaoke) — persisted so word-level lyrics
                  // survive caching instead of degrading to line-level.
                  if (l.words.isNotEmpty)
                    'w': l.words
                        .map((w) => {'ms': w.start.inMilliseconds, 't': w.text})
                        .toList(),
                })
            .toList(),
      };

  static Lyrics _fromJson(Map<String, dynamic> j) {
    final lines = (j['lines'] as List)
        .cast<Map<String, dynamic>>()
        .map((l) => LyricsLine(
              time: Duration(milliseconds: (l['ms'] as num).toInt()),
              text: l['text'] as String,
              translation: l['tr'] as String?,
              words: (l['w'] as List?)
                      ?.cast<Map<String, dynamic>>()
                      .map((w) => LyricWord(
                            start:
                                Duration(milliseconds: (w['ms'] as num).toInt()),
                            text: w['t'] as String,
                          ))
                      .toList() ??
                  const [],
            ))
        .toList();
    return Lyrics(
      lines: lines,
      synced: j['synced'] as bool? ?? false,
      offset: Duration(milliseconds: (j['offset'] as num?)?.toInt() ?? 0),
    );
  }
}

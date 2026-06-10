import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/models/lyrics.dart';

/// Persists fetched lyrics to SharedPreferences so they work offline.
/// Key format: `lyrics_v1_<songId>`.
class SharedPrefsLyricsCache {
  static const String _prefix = 'lyrics_v1_';

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

  Future<void> write(String songId, Lyrics lyrics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$songId', jsonEncode(_toJson(lyrics)));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
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
            ))
        .toList();
    return Lyrics(
      lines: lines,
      synced: j['synced'] as bool? ?? false,
      offset: Duration(milliseconds: (j['offset'] as num?)?.toInt() ?? 0),
    );
  }
}

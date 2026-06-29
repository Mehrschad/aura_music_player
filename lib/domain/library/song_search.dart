import '../models/song.dart';

/// A lightweight, pure full-text matcher over songs.
///
/// Searches title, artist, album, and filename, case-insensitively. Results
/// are ranked: a title hit outranks an artist hit, which outranks album, which
/// outranks filename; within a tier a prefix match outranks a mid-string
/// match. Lyrics search (which needs the lyrics store from step 7) layers in
/// later via the same ranking.
List<Song> searchSongs(List<Song> songs, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final scored = <_Scored>[];
  for (final s in songs) {
    final score = _score(s, q);
    if (score > 0) scored.add(_Scored(s, score));
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
  });
  return scored.map((e) => e.song).toList();
}

/// True when every char of [q] appears in [text], in order (not necessarily
/// contiguous). Both must already be lowercase. Empty [q] returns false here
/// (callers guard empty queries separately).
bool isSubsequence(String q, String text) {
  if (q.isEmpty) return false;
  var i = 0;
  for (var j = 0; j < text.length && i < q.length; j++) {
    if (text[j] == q[i]) i++;
  }
  return i == q.length;
}

int _score(Song s, String q) {
  int fieldScore(String? value, int tierWeight) {
    if (value == null) return 0;
    final v = value.toLowerCase();
    if (v.contains(q)) {
      final prefixBonus = v.startsWith(q) ? 1 : 0;
      return tierWeight + prefixBonus; // exact/substring tier
    }
    // Fuzzy fallback ranks well below any substring hit.
    if (q.length >= 2 && isSubsequence(q, v)) {
      return (tierWeight ~/ 10) + 1; // title=5, artist=4, album=3, file=2
    }
    return 0;
  }

  // Tier weights leave room for the prefix bonus without overlap.
  final title = fieldScore(s.title, 40);
  final artist = fieldScore(s.artist, 30);
  final album = fieldScore(s.album, 20);
  final file = fieldScore(s.filePath, 10);
  return [title, artist, album, file].fold(0, (a, b) => a > b ? a : b);
}

class _Scored {
  const _Scored(this.song, this.score);
  final Song song;
  final int score;
}

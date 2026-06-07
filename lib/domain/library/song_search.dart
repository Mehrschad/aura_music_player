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

int _score(Song s, String q) {
  int fieldScore(String? value, int tierWeight) {
    if (value == null) return 0;
    final v = value.toLowerCase();
    if (!v.contains(q)) return 0;
    final prefixBonus = v.startsWith(q) ? 1 : 0;
    return tierWeight + prefixBonus;
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

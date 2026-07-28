import '../models/song.dart';

/// Suggests library songs that fit the "taste" of a playlist — songs by the
/// same artists, in the same genres, and from the same eras as the tracks
/// already in it. Pure and deterministic: same inputs, same order.
///
/// Scoring (per candidate not already in the playlist):
///   • same artist as a playlist track — strongest signal,
///   • shared genre — medium,
///   • same decade — light nudge,
///   • the song's own rating — a small quality tie-breaker.
/// Results are capped to [perArtistCap] songs per artist so one prolific artist
/// can't fill the whole list, then trimmed to [limit].
List<Song> suggestForPlaylist(
  List<Song> playlistSongs,
  List<Song> library, {
  int limit = 15,
  int perArtistCap = 3,
}) {
  if (playlistSongs.isEmpty || library.isEmpty) return const [];

  final inPlaylist = {for (final s in playlistSongs) s.id};
  final artistWeight = <String, int>{};
  final genreWeight = <String, int>{};
  final decadeWeight = <int, int>{};
  for (final s in playlistSongs) {
    artistWeight[s.artistId] = (artistWeight[s.artistId] ?? 0) + 1;
    final g = (s.genre ?? '').trim().toLowerCase();
    if (g.isNotEmpty) genreWeight[g] = (genreWeight[g] ?? 0) + 1;
    if (s.year != null) {
      final decade = (s.year! ~/ 10) * 10;
      decadeWeight[decade] = (decadeWeight[decade] ?? 0) + 1;
    }
  }

  final scored = <(Song, double)>[];
  for (final s in library) {
    if (inPlaylist.contains(s.id)) continue;
    var score = (artistWeight[s.artistId] ?? 0) * 3.0;
    final g = (s.genre ?? '').trim().toLowerCase();
    if (g.isNotEmpty) score += (genreWeight[g] ?? 0) * 1.5;
    if (s.year != null) {
      final decade = (s.year! ~/ 10) * 10;
      score += (decadeWeight[decade] ?? 0) * 0.4;
    }
    if (score <= 0) continue; // no overlap → not a "similar" pick
    score += (s.rating ?? 0) * 0.2;
    scored.add((s, score));
  }

  // Highest score first; ties broken by title so the order is stable.
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    return a.$1.title.toLowerCase().compareTo(b.$1.title.toLowerCase());
  });

  final out = <Song>[];
  final perArtist = <String, int>{};
  for (final (song, _) in scored) {
    final used = perArtist[song.artistId] ?? 0;
    if (used >= perArtistCap) continue;
    perArtist[song.artistId] = used + 1;
    out.add(song);
    if (out.length >= limit) break;
  }
  return out;
}

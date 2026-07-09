import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/library/song_search.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';
import 'library_providers.dart';
import 'lyrics_providers.dart';
import 'playlist_providers.dart';

/// Which result types the Search page is currently showing.
enum SearchScope { all, songs, artists, albums, playlists }

/// The active result-type filter. Reset to [SearchScope.all] whenever a fresh
/// query is typed (handled in the page).
final searchScopeProvider = StateProvider<SearchScope>((ref) => SearchScope.all);

/// The kind of the single strongest match, used to render the "Top result" hero.
enum SearchKind { song, artist, album, playlist }

/// The top-result hero payload: the best cross-type match for the query.
class SearchTop {
  const SearchTop(this.kind, this.value);
  final SearchKind kind;

  /// A [Song], [Artist], [Album] or [Playlist] per [kind].
  final Object value;
}

/// All library matches for the current query, grouped by type and already
/// ranked (songs by [searchSongs]; the rest by name relevance).
class SearchBundle {
  const SearchBundle({
    required this.songs,
    required this.artists,
    required this.albums,
    required this.playlists,
  });

  static const empty = SearchBundle(
      songs: [], artists: [], albums: [], playlists: []);

  final List<Song> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  bool get isEmpty =>
      songs.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;
}

/// Ranks name matches: an exact hit first, then a prefix hit, then a plain
/// substring, then a subsequence (fuzzy) — mirroring [searchSongs]'s ordering
/// so every section feels consistent. Non-matches return a negative score.
int _nameScore(String name, String q) {
  final n = name.toLowerCase();
  if (n == q) return 100;
  if (n.startsWith(q)) return 80 - (n.length - q.length).clamp(0, 40);
  if (n.contains(q)) return 40;
  if (q.length >= 2 && isSubsequence(q, n)) return 10;
  return -1;
}

List<T> _rankByName<T>(Iterable<T> items, String q, String Function(T) name) {
  final scored = <(int, T)>[];
  for (final it in items) {
    final s = _nameScore(name(it), q);
    if (s > 0) scored.add((s, it));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final e in scored) e.$2];
}

/// The grouped library matches for the live query. Songs come from the shared
/// [searchResultsProvider]; artists, albums and playlists are name-ranked here.
final searchBundleProvider = Provider<SearchBundle>((ref) {
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (q.isEmpty) return SearchBundle.empty;

  final songs = ref.watch(searchResultsProvider).valueOrNull ?? const <Song>[];
  final artists = _rankByName(
    ref.watch(artistsProvider).valueOrNull ?? const <Artist>[],
    q,
    (a) => a.name,
  );
  // Albums also match on their artist, so a query like "beatles" surfaces them.
  final albums = _rankByName(
    ref.watch(albumsProvider).valueOrNull ?? const <Album>[],
    q,
    (a) => '${a.name} ${a.artist}',
  );
  final playlists = _rankByName(
    ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[],
    q,
    (p) => p.name,
  );

  return SearchBundle(
    songs: songs,
    artists: artists,
    albums: albums,
    playlists: playlists,
  );
});

/// The single best match across all types — the "Top result" hero. Prefers a
/// strong entity (artist/album/playlist whose name starts with the query) over
/// a song, the way listeners expect ("coldplay" → the artist, not a track), but
/// falls back to the top song otherwise.
final searchTopResultProvider = Provider<SearchTop?>((ref) {
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (q.isEmpty) return null;
  final b = ref.watch(searchBundleProvider);

  ({SearchTop top, int score})? best;
  void consider(SearchKind kind, Object? value, String name, int kindBonus) {
    if (value == null) return;
    final s = _nameScore(name, q);
    if (s <= 0) return;
    final score = s + kindBonus;
    if (best == null || score > best!.score) {
      best = (top: SearchTop(kind, value), score: score);
    }
  }

  // Entities get a small bonus so a clean artist/album name wins over an equal
  // song title, but a much stronger song (exact title) can still take the top.
  consider(SearchKind.artist, b.artists.isEmpty ? null : b.artists.first,
      b.artists.isEmpty ? '' : b.artists.first.name, 12);
  consider(SearchKind.album, b.albums.isEmpty ? null : b.albums.first,
      b.albums.isEmpty ? '' : b.albums.first.name, 8);
  consider(SearchKind.playlist, b.playlists.isEmpty ? null : b.playlists.first,
      b.playlists.isEmpty ? '' : b.playlists.first.name, 8);
  consider(SearchKind.song, b.songs.isEmpty ? null : b.songs.first,
      b.songs.isEmpty ? '' : b.songs.first.title, 0);

  return best?.top;
});

/// All cached lyric text, keyed by song id (lowercased). Built once per session
/// on first use; the offline prefetcher keeps the cache growing in the
/// background, so coverage improves the longer the app runs.
final lyricsCorpusProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(lyricsCacheProvider).allText();
});

/// Songs whose *lyrics* contain the query — "search inside lyrics". Guarded to
/// 3+ characters so a stray letter doesn't match half the library, and capped
/// so a common word stays fast to render.
final lyricsSearchProvider = FutureProvider<List<Song>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (q.length < 3) return const [];
  final corpus = await ref.watch(lyricsCorpusProvider.future);
  if (corpus.isEmpty) return const [];
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  final byId = {for (final s in songs) s.id: s};

  final out = <Song>[];
  for (final entry in corpus.entries) {
    if (entry.value.contains(q)) {
      final s = byId[entry.key];
      if (s != null) out.add(s);
    }
    if (out.length >= 30) break;
  }
  return out;
});

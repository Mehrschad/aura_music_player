import '../models/play_event.dart';
import '../models/song.dart';
import 'taste_engine.dart';
import 'taste_profile.dart';

/// What kind of intelligent collection this is (drives the card accent/icon).
enum SmartCollectionKind {
  forYou,
  mix,
  mood,
  heavyRotation,
  hiddenGems,
  rediscover,
  artist,
}

/// An *ephemeral* auto-generated collection shown on the home — a "For You" mix,
/// "Heavy Rotation", "Hidden Gems", etc. These are recomputed live from taste
/// and are NEVER persisted; only if the user explicitly saves one does it become
/// a real playlist in their library.
class SmartCollection {
  const SmartCollection({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.songs,
  });

  final String id;
  final SmartCollectionKind kind;
  final String title;
  final String subtitle;
  final List<Song> songs;

  bool get isEmpty => songs.isEmpty;
  List<String> get songIds => [for (final s in songs) s.id];
}

/// Builds the home's intelligent collections from the taste signals. Pure and
/// deterministic — same inputs, same shelves. A collection is only emitted when
/// it has enough songs to feel intentional ([_minSongs]).
List<SmartCollection> buildSmartCollections({
  required List<Song> library,
  required TasteProfile profile,
  required List<ScoredSong> recommendations,
  required List<PlayEvent> history,
  required Set<String> favoriteIds,
  DateTime? now,
}) {
  if (library.isEmpty || profile.isEmpty) return const [];
  const minSongs = 5;
  const maxSongs = 40;
  final today = now ?? DateTime.now();
  final byId = <String, Song>{for (final s in library) s.id: s};
  final out = <SmartCollection>[];

  // 1. Your Mix — the top blended recommendations.
  final forYou = [for (final r in recommendations) r.song].take(maxSongs).toList();
  if (forYou.length >= minSongs) {
    out.add(SmartCollection(
      id: 'forYou',
      kind: SmartCollectionKind.forYou,
      title: 'Your Mix',
      subtitle: 'Handpicked for your taste',
      songs: forYou,
    ));
  }

  // 1b. Daily Mixes — one per top genre, ordered by taste.
  out.addAll(
      _genreMixes(library, profile, recommendations, minSongs, maxSongs));
  // 1c. Mood mixes — energetic / chill / focus, inferred on-device from bpm
  //     and genre (no audio analysis or network needed).
  out.addAll(_moodMixes(library, recommendations, minSongs, maxSongs));

  // 2. Heavy Rotation — most completed plays in the last 30 days.
  final cutoff = today.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
  final counts = <String, int>{};
  for (final e in history) {
    if (e.completed && e.atMs >= cutoff && byId.containsKey(e.songId)) {
      counts[e.songId] = (counts[e.songId] ?? 0) + 1;
    }
  }
  final heavy = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final heavySongs = [for (final e in heavy.take(maxSongs)) byId[e.key]!];
  if (heavySongs.length >= minSongs) {
    out.add(SmartCollection(
      id: 'heavy',
      kind: SmartCollectionKind.heavyRotation,
      title: 'Heavy Rotation',
      subtitle: 'On repeat lately',
      songs: heavySongs,
    ));
  }

  // 3. Hidden Gems — recommended songs the user has barely (or never) played:
  //    on-taste, but overlooked. This is the "you might love these" shelf.
  final gems = [
    for (final r in recommendations)
      if (r.song.playCount <= 2 && !favoriteIds.contains(r.song.id)) r.song,
  ].take(maxSongs).toList();
  if (gems.length >= minSongs) {
    out.add(SmartCollection(
      id: 'gems',
      kind: SmartCollectionKind.hiddenGems,
      title: 'Hidden Gems',
      subtitle: 'On your wavelength, overlooked',
      songs: gems,
    ));
  }

  // 4. Rediscover — songs the user once played a lot but hasn't touched in a
  //    while, and still align with current taste.
  final rediscover = <Song>[
    for (final s in library)
      if (s.playCount >= 3 &&
          s.lastPlayed != null &&
          today.difference(s.lastPlayed!).inDays >= 30 &&
          (profile.artistAffinity[s.artist] ?? 0) > 0)
        s,
  ]..sort((a, b) => (profile.artistAffinity[b.artist] ?? 0)
      .compareTo(profile.artistAffinity[a.artist] ?? 0));
  if (rediscover.length >= minSongs) {
    out.add(SmartCollection(
      id: 'rediscover',
      kind: SmartCollectionKind.rediscover,
      title: 'Rediscover',
      subtitle: "Favourites you've drifted from",
      songs: rediscover.take(maxSongs).toList(),
    ));
  }

  // 5. Because you listen to {top artist} — a deep-cut shelf for a top artist.
  for (final entry in profile.topArtists(3)) {
    final name = entry.key;
    final songs = [for (final s in library) if (s.artist == name) s];
    if (songs.length >= minSongs) {
      out.add(SmartCollection(
        id: 'artist_$name',
        kind: SmartCollectionKind.artist,
        title: name,
        subtitle: 'Because you listen to $name',
        songs: songs.take(maxSongs).toList(),
      ));
      break; // one artist shelf is enough on the home
    }
  }

  return out;
}

/// Builds a sort key map from the recommendation order so mixes lead with the
/// most on-taste tracks, then fall back to play count.
Map<String, int> _recRank(List<ScoredSong> recs) =>
    {for (var i = 0; i < recs.length; i++) recs[i].song.id: i};

int _byRankThenPlays(Song a, Song b, Map<String, int> rank) {
  final ra = rank[a.id] ?? (1 << 30);
  final rb = rank[b.id] ?? (1 << 30);
  if (ra != rb) return ra.compareTo(rb);
  return b.playCount.compareTo(a.playCount);
}

/// Daily Mixes: one collection per the user's top genres.
List<SmartCollection> _genreMixes(
  List<Song> library,
  TasteProfile profile,
  List<ScoredSong> recs,
  int minSongs,
  int maxSongs,
) {
  final rank = _recRank(recs);
  final out = <SmartCollection>[];
  for (final entry in profile.topGenres(2)) {
    final genre = entry.key;
    final lower = genre.toLowerCase();
    final inGenre = [
      for (final s in library)
        if ((s.genre ?? '').toLowerCase() == lower) s,
    ];
    if (inGenre.length < minSongs) continue;
    inGenre.sort((a, b) => _byRankThenPlays(a, b, rank));
    out.add(SmartCollection(
      id: 'genre_$lower',
      kind: SmartCollectionKind.mix,
      title: '$genre Mix',
      subtitle: 'A mix of your $genre',
      songs: inGenre.take(maxSongs).toList(),
    ));
  }
  return out;
}

/// Coarse, on-device mood inference from tags only — BPM (when present) plus
/// genre keywords. Returns null when nothing recognisable matches.
enum _Mood { energetic, chill, focus }

_Mood? _moodOf(Song s) {
  final g = (s.genre ?? '').toLowerCase();
  bool has(List<String> ks) => ks.any(g.contains);
  final focusG = has([
    'classical', 'ambient', 'instrumental', 'study', 'focus', 'piano',
    'soundtrack', 'score', 'meditat'
  ]);
  final chillG = has([
    'chill', 'lo-fi', 'lofi', 'jazz', 'soul', 'acoustic', 'sleep',
    'downtempo', 'r&b', 'rnb', 'folk'
  ]);
  final energeticG = has([
    'dance', 'electro', 'edm', 'house', 'techno', 'trance', 'rock', 'metal',
    'punk', 'hip hop', 'hip-hop', 'rap', 'drum', 'dubstep', 'workout', 'party',
    'pop'
  ]);

  final bpm = s.bpm;
  if (bpm != null && bpm > 0) {
    if (bpm >= 125) return _Mood.energetic;
    if (bpm <= 90) return focusG ? _Mood.focus : _Mood.chill;
  }
  if (energeticG) return _Mood.energetic;
  if (focusG) return _Mood.focus;
  if (chillG) return _Mood.chill;
  return null;
}

/// Mood mixes for whichever buckets are populated enough.
List<SmartCollection> _moodMixes(
  List<Song> library,
  List<ScoredSong> recs,
  int minSongs,
  int maxSongs,
) {
  final rank = _recRank(recs);
  final buckets = <_Mood, List<Song>>{};
  for (final s in library) {
    final m = _moodOf(s);
    if (m == null) continue;
    (buckets[m] ??= <Song>[]).add(s);
  }
  const meta = <_Mood, (String, String, String)>{
    _Mood.energetic: ('mood_energetic', 'Energetic', 'High-energy picks'),
    _Mood.chill: ('mood_chill', 'Chill', 'Laid-back and easy'),
    _Mood.focus: ('mood_focus', 'Focus', 'Calm, for concentration'),
  };
  final out = <SmartCollection>[];
  for (final m in _Mood.values) {
    final songs = buckets[m];
    if (songs == null || songs.length < minSongs) continue;
    songs.sort((a, b) => _byRankThenPlays(a, b, rank));
    final (id, title, subtitle) = meta[m]!;
    out.add(SmartCollection(
      id: id,
      kind: SmartCollectionKind.mood,
      title: title,
      subtitle: subtitle,
      songs: songs.take(maxSongs).toList(),
    ));
  }
  return out;
}

import '../models/play_event.dart';
import '../models/song.dart';
import 'taste_engine.dart';
import 'taste_profile.dart';

/// What kind of intelligent collection this is (drives the card accent/icon).
enum SmartCollectionKind { forYou, heavyRotation, hiddenGems, rediscover, artist }

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

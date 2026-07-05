import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';
import '../../domain/taste/smart_collection.dart';
import 'favorites_providers.dart';
import 'library_providers.dart';
import 'playlist_providers.dart';
import 'smart_collections_provider.dart';
import 'taste_providers.dart';
import 'top_charts_provider.dart';

/// One quick-access tile in the home's "Top Picks" grid — a named shortcut that
/// plays a ready-made list (recent, your mix, an artist, an album, a playlist…).
class TopPick {
  const TopPick(this.id, this.title, this.icon, this.songs);

  final String id;
  final String title;
  final IconData icon;
  final List<Song> songs;

  /// A representative song for the tile's cover (the first), if any.
  Song? get cover => songs.isEmpty ? null : songs.first;
}

/// Assembles up to eight "Top Picks" shortcuts spanning content types — recent,
/// your mix, a top artist, a top album, top tracks, a recent playlist, a
/// time-of-day mood, and favourites — each only added when it has songs.
final topPicksProvider = Provider<List<TopPick>>((ref) {
  final out = <TopPick>[];
  final allSongs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  if (allSongs.isEmpty) return const [];
  final byId = <String, Song>{for (final s in allSongs) s.id: s};

  final recent = ref.watch(jumpBackInProvider);
  if (recent.isNotEmpty) {
    out.add(TopPick('recent', 'Jump back in', Icons.replay_rounded, recent));
  }

  final mix = ref.watch(forYouSongsProvider);
  if (mix.length >= 5) {
    out.add(TopPick('mix', 'Your Mix', Icons.auto_awesome, mix));
  }

  // Top artist → their tracks.
  final topArtists = ref.watch(topArtistsProvider);
  if (topArtists.isNotEmpty) {
    final a = topArtists.first;
    final songs = [for (final s in allSongs) if (s.artistId == a.id) s];
    if (songs.length >= 3) {
      out.add(TopPick('artist_${a.id}', a.name, Icons.person_rounded, songs));
    }
  }

  // Top album → its tracks.
  final topAlbums = ref.watch(topAlbumsProvider);
  if (topAlbums.isNotEmpty) {
    final al = topAlbums.first;
    final songs = [for (final s in allSongs) if (s.albumId == al.id) s];
    if (songs.length >= 3) {
      out.add(TopPick('album_${al.id}', al.name, Icons.album_rounded, songs));
    }
  }

  // Top tracks.
  final heavy = ref.watch(topTracksProvider);
  if (heavy.length >= 5) {
    out.add(TopPick(
        'heavy', 'Heavy Rotation', Icons.local_fire_department_rounded, heavy));
  }

  // A recent user playlist → its tracks.
  final playlists =
      ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[];
  if (playlists.isNotEmpty) {
    final p = playlists.first;
    final songs = [
      for (final id in p.songIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    if (songs.length >= 3) {
      out.add(TopPick('pl_${p.id}', p.name, Icons.queue_music_rounded, songs));
    }
  }

  // Contextual mood — the bucket that fits the current hour.
  final collections = ref.watch(smartCollectionsProvider);
  final moods = <String, SmartCollection>{
    for (final c in collections)
      if (c.kind == SmartCollectionKind.mood) c.id: c,
  };
  if (moods.isNotEmpty) {
    final hour = DateTime.now().hour;
    final pref = (hour >= 5 && hour < 11)
        ? 'mood_focus'
        : (hour >= 22 || hour < 5)
            ? 'mood_chill'
            : 'mood_energetic';
    final m = moods[pref] ?? moods.values.first;
    out.add(TopPick(m.id, m.title, Icons.waves_rounded, m.songs));
  }

  final favIds = ref.watch(favoritesProvider);
  if (favIds.isNotEmpty) {
    final favSongs = [for (final s in allSongs) if (favIds.contains(s.id)) s];
    if (favSongs.length >= 3) {
      out.add(TopPick('fav', 'Favorites', Icons.favorite_rounded, favSongs));
    }
  }

  final onThis = ref.watch(onThisDayProvider);
  if (onThis.length >= 5) {
    out.add(
        TopPick('onthis', 'On this day', Icons.calendar_today_rounded, onThis));
  }

  return out.take(8).toList();
});

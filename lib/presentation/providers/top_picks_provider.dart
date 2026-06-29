import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/song.dart';
import '../../domain/taste/smart_collection.dart';
import 'favorites_providers.dart';
import 'library_providers.dart';
import 'smart_collections_provider.dart';
import 'taste_providers.dart';
import 'top_charts_provider.dart';

/// One quick-access tile in the home's "Top Picks" grid — a named shortcut that
/// plays a ready-made list (recent, your mix, a mood, favourites…).
class TopPick {
  const TopPick(this.id, this.title, this.icon, this.songs);

  final String id;
  final String title;
  final IconData icon;
  final List<Song> songs;

  /// A representative song for the tile's cover (the first), if any.
  Song? get cover => songs.isEmpty ? null : songs.first;
}

/// Assembles the up-to-six "Top Picks" shortcuts from existing surfaces, in
/// priority order, including a **time-of-day-aware mood** pick — a small nod to
/// a context-aware home. Each pick only appears when it has enough songs.
final topPicksProvider = Provider<List<TopPick>>((ref) {
  final out = <TopPick>[];

  final recent = ref.watch(jumpBackInProvider);
  if (recent.isNotEmpty) {
    out.add(TopPick('recent', 'Jump back in', Icons.replay_rounded, recent));
  }

  final mix = ref.watch(forYouSongsProvider);
  if (mix.length >= 5) {
    out.add(TopPick('mix', 'Your Mix', Icons.auto_awesome, mix));
  }

  // Contextual mood — pick the bucket that fits the current hour.
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

  final heavy = ref.watch(topTracksProvider);
  if (heavy.length >= 5) {
    out.add(TopPick(
        'heavy', 'Heavy Rotation', Icons.local_fire_department_rounded, heavy));
  }

  final favIds = ref.watch(favoritesProvider);
  if (favIds.isNotEmpty) {
    final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
    final favSongs = [for (final s in songs) if (favIds.contains(s.id)) s];
    if (favSongs.length >= 3) {
      out.add(TopPick('fav', 'Favorites', Icons.favorite_rounded, favSongs));
    }
  }

  final onThis = ref.watch(onThisDayProvider);
  if (onThis.length >= 5) {
    out.add(
        TopPick('onthis', 'On this day', Icons.calendar_today_rounded, onThis));
  }

  return out.take(6).toList();
});

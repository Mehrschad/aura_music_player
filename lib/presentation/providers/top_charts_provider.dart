import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import 'library_providers.dart';
import 'stats_providers.dart';
import 'taste_providers.dart';

/// "On this day" — tracks the user played around this date in previous years.
/// Often empty (needs a year+ of history); hidden gracefully when so.
final onThisDayProvider = Provider<List<Song>>((ref) {
  final history = ref.watch(playHistoryProvider);
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  if (history.isEmpty || songs.isEmpty) return const [];
  final byId = <String, Song>{for (final s in songs) s.id: s};
  final now = DateTime.now();
  final seen = <String>{};
  final out = <Song>[];
  for (final e in history) {
    if (!e.completed) continue;
    final d = e.at;
    if (d.year >= now.year) continue; // a prior year only
    if (d.month != now.month || (d.day - now.day).abs() > 2) continue;
    if (seen.contains(e.songId)) continue;
    final s = byId[e.songId];
    if (s != null) {
      seen.add(e.songId);
      out.add(s);
    }
  }
  return out.take(20).toList();
});

/// "Jump back in" — recently played tracks, newest first, for quick resume.
final jumpBackInProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  final played = [for (final s in songs) if (s.lastPlayed != null) s]
    ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
  return played.take(12).toList();
});

/// Most-played tracks (by lifetime play count), highest first.
final topTracksProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  final played = [for (final s in songs) if (s.playCount > 0) s]
    ..sort((a, b) => b.playCount.compareTo(a.playCount));
  return played.take(15).toList();
});

/// Top albums by summed play count of their tracks.
final topAlbumsProvider = Provider<List<Album>>((ref) {
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  final albums = ref.watch(albumsProvider).valueOrNull ?? const <Album>[];
  if (albums.isEmpty) return const [];
  final plays = <String, int>{};
  for (final s in songs) {
    if (s.playCount > 0) plays[s.albumId] = (plays[s.albumId] ?? 0) + s.playCount;
  }
  final byId = <String, Album>{for (final a in albums) a.id: a};
  final ranked = plays.entries.where((e) => byId.containsKey(e.key)).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(15)) byId[e.key]!];
});

/// Top artists by summed play count of their tracks — the user's most-listened
/// artists from their history.
final topArtistsProvider = Provider<List<Artist>>((ref) {
  final songs = ref.watch(songsProvider).valueOrNull ?? const <Song>[];
  final artists = ref.watch(artistsProvider).valueOrNull ?? const <Artist>[];
  if (artists.isEmpty) return const [];
  final plays = <String, int>{};
  for (final s in songs) {
    if (s.playCount > 0) {
      plays[s.artistId] = (plays[s.artistId] ?? 0) + s.playCount;
    }
  }
  final byId = <String, Artist>{for (final a in artists) a.id: a};
  final ranked = plays.entries.where((e) => byId.containsKey(e.key)).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(15)) byId[e.key]!];
});

/// **Suggested** artists — drawn from the recommendation engine (artists whose
/// tracks the taste model surfaces) but *excluding* the user's already-top
/// artists, so this rail is about discovery, not repetition. Empty until there
/// is enough taste data for recommendations to exist.
final suggestedArtistsProvider = Provider<List<Artist>>((ref) {
  final recs = ref.watch(recommendationsProvider);
  if (recs.isEmpty) return const [];
  final artists = ref.watch(artistsProvider).valueOrNull ?? const <Artist>[];
  if (artists.isEmpty) return const [];

  final topIds = {for (final a in ref.watch(topArtistsProvider)) a.id};
  final byId = <String, Artist>{for (final a in artists) a.id: a};

  final seen = <String>{};
  final out = <Artist>[];
  for (final r in recs) {
    final id = r.song.artistId;
    if (id.isEmpty || topIds.contains(id) || seen.contains(id)) continue;
    seen.add(id);
    final artist = byId[id];
    if (artist != null) {
      out.add(artist);
      if (out.length >= 12) break;
    }
  }
  return out;
});

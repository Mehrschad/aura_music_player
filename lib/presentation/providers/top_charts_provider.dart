import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import 'library_providers.dart';

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

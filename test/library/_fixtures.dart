import 'package:aura_music_player/domain/models/song.dart';

/// Test fixture builder.
Song song({
  required String id,
  String title = 'Title',
  String artist = 'Artist',
  String album = 'Album',
  String albumId = 'al',
  String artistId = 'ar',
  int secs = 200,
  DateTime? added,
  int? year,
  int plays = 0,
  DateTime? lastPlayed,
  String? genre,
  int? rating,
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    album: album,
    albumId: albumId,
    artistId: artistId,
    duration: Duration(seconds: secs),
    filePath: '/m/$id.flac',
    dateAdded: added ?? DateTime(2024),
    year: year,
    genre: genre,
    playCount: plays,
    lastPlayed: lastPlayed,
    rating: rating,
  );
}
